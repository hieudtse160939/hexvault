extends Node2D
## Screen: the Adventurers' Guild hall, the game's home base.
##
## A walkable interior (same Level / tile / collision systems as the dungeon)
## with the Guild services as interaction points:
##   Reception (receptionist) - rank, level, progress, shortcuts to every service
##   Mission Board / Expedition Gate - pick a mission, launches the real dungeon
##   Equipment (weapon rack) - the real inventory and equipment screen
##   Skill Library (bookshelf) - skill tree and active skill
##   Guild Shop (shopkeeper) - buy with gold, sell from the inventory
##   Training Grounds - dummies that take real hits and show DPS
##   Hero Shrine, Rune Forge, Quest Board - roster, permanent upgrades, quests

## The building itself is data: data/maps/guild.json (rooms, furniture, NPCs,
## lights, station positions), built by MapLoader. This script only wires the
## services behind each station id.

const MAP_ID: String = "guild"

var map: Dictionary = {}
var SPAWN: Vector2i = Vector2i(20, 24)   # from the map file

var level: Level
var player: Player
var camera: GameCamera
var ui_root: Control
var stations: Dictionary = {}    # name -> HubStation (tests, tour)
var dummies: Array[TrainingDummy] = []
var _modal: Control = null
var _hero_label: Label
var _gold_label: Label
var _exp_bar: ProgressBar
var _hint: Label
var _keys: Label
var _portrait: TextureRect
var _rank_label: Label
var _shard_label: Label
var _sp_label: Label
var _arrival: bool = false


func setup(args: Dictionary) -> void:
	_arrival = bool(args.get("arrival", false))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("guild")
	Game.run = null
	level = Level.new()
	add_child(level)
	map = MapLoader.load_map(MAP_ID)
	SPAWN = Vector2i(int(map["spawn"][0]), int(map["spawn"][1]))
	MapLoader.build(level, map, self)
	var sel: String = Profile.selected_hero()
	if not Profile.is_character_unlocked(sel) or not Db.is_playable(sel):
		sel = str(Db.guild.get("default_hero", "duelist"))
		Profile.select_hero(sel)
	Profile.ensure_starter_kit(sel)
	_spawn_player(sel)
	_build_stations()
	camera = GameCamera.new()
	camera.target = player
	add_child(camera)
	camera.make_current()
	camera.snap_to_target()
	_build_ui()
	Sfx.play_music("hub")
	if not bool(Profile.data["seen_tutorial"]):
		_show_tutorial()
	elif _arrival:
		Events.toast.emit("Welcome to the Adventurers' Guild!")


static func tile_world(x: float, y: float) -> Vector2:
	return Vector2(x * Level.TILE, y * Level.TILE)


func _build_stations() -> void:
	var actions: Dictionary = {
		"reception": _open_reception, "missions": _open_missions, "gate": _open_missions,
		"equipment": _open_equipment, "skills": _open_skills, "shop": _open_shop,
		"heroes": _open_heroes, "forge": _open_forge, "quests": _open_quests,
	}
	for st: Variant in map.get("stations", []):
		var d: Dictionary = st
		var cb: Callable = actions.get(str(d["id"]), Callable())
		if not cb.is_valid():
			push_warning("Guild map: no service for station '%s'" % d["id"])
			continue
		var b: Array = d.get("box", [12, 6])
		var s2: HubStation = HubStation.create(str(d["title"]), str(d["prompt"]), str(d["sprite"]), MapLoader.at(d["at"]), cb, Vector2(float(b[0]), float(b[1])))
		level.add_entity(s2)
		stations[str(d["title"])] = s2
		if str(d["id"]) == "quests":
			s2.badge = Profile.claimable_quests
	for dp: Variant in map.get("dummies", []):
		var dm: TrainingDummy = TrainingDummy.create(MapLoader.at(dp))
		level.add_entity(dm)
		dummies.append(dm)


func _spawn_player(id: String) -> void:
	var pos: Vector2 = Level.to_world(SPAWN)
	if player != null:
		pos = player.global_position
		player.queue_free()
	player = Player.create(Db.character(id))
	player.position = pos
	level.player = player
	level.add_entity(player)
	var tmp: RunState = RunState.new()
	var w_item: Dictionary = Inventory.equipped_in(Profile.data, id, "weapon")
	var w_id: String = str(ItemGen.template(str(w_item.get("base", ""))).get("weapon", ""))
	tmp.weapons = [w_id if Db.weapon(w_id) != null else Db.character(id).start_weapon]
	player.load_run_weapons(tmp)
	if camera != null:
		camera.target = player


# --- UI -----------------------------------------------------------------------------------
func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = UiTheme.get_theme()
	layer.add_child(ui_root)
	SafeArea.apply(ui_root)
	# --- adventurer plate (top left): portrait, name + level, rank, experience, purse
	var plate: PanelContainer = PanelContainer.new()
	plate.position = Vector2(4, 4)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", UiTheme.guild_box())
	ui_root.add_child(plate)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	plate.add_child(row)
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.box(Color("#1a120e"), UiTheme.GOLD, 1, 0))
	row.add_child(frame)
	var clip: Control = Control.new()   # plain Control: no layout, fixed 26 x 26 window
	clip.custom_minimum_size = Vector2(26, 26)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(clip)
	_portrait = TextureRect.new()
	clip.add_child(_portrait)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)
	_hero_label = UiTheme.label("", UiTheme.TEXT, true)
	col.add_child(_hero_label)
	_rank_label = UiTheme.label("", UiTheme.GOLD, true)
	col.add_child(_rank_label)
	_exp_bar = ProgressBar.new()
	_exp_bar.custom_minimum_size = Vector2(96, 3)
	_exp_bar.show_percentage = false
	_exp_bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.GOLD, UiTheme.GOLD, 0, 0))
	_exp_bar.add_theme_stylebox_override("background", UiTheme.box(UiTheme.INK, UiTheme.INK, 0, 0))
	col.add_child(_exp_bar)
	var purse: HBoxContainer = HBoxContainer.new()
	purse.add_theme_constant_override("separation", 2)
	col.add_child(purse)
	var coin: TextureRect = TextureRect.new()
	coin.texture = SpriteLib.texture("icon_coin")
	purse.add_child(coin)
	_gold_label = UiTheme.label("", UiTheme.GOLD, true)
	purse.add_child(_gold_label)
	var shard: TextureRect = TextureRect.new()
	shard.texture = SpriteLib.texture("icon_shard")
	purse.add_child(shard)
	_shard_label = UiTheme.label("", UiTheme.ACCENT, true)
	purse.add_child(_shard_label)
	_sp_label = UiTheme.label("", Color("#b4fff0"), true)
	col.add_child(_sp_label)
	_hint = UiTheme.label("", UiTheme.TEXT, true)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_top = -44
	_hint.offset_bottom = -34
	ui_root.add_child(_hint)
	Events.interact_hint.connect(func(t: String) -> void:
		_hint.text = "" if t.is_empty() else "Press %s: %s" % [Controls.action_label("interact"), t])
	_keys = UiTheme.label("", UiTheme.DIM, true)
	_keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_keys.offset_left = 4
	_keys.offset_top = -12
	ui_root.add_child(_keys)
	var touch: TouchControls = TouchControls.new()
	touch.player = player
	touch.pause_pressed.connect(_open_menu)
	ui_root.add_child(touch)
	# --- quick access (top right): every service is also a station in the hall
	var bar: HBoxContainer = HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.offset_top = 4
	bar.offset_right = -4
	bar.add_theme_constant_override("separation", 2)
	ui_root.add_child(bar)
	for spec: Array in [["Missions", "icon_scroll", _open_missions], ["Bag", "icon_item_armor", _open_equipment],
			["Skills", "icon_item_book", _open_skills], ["Menu", "", _open_menu]]:
		var b: Button = UiTheme.button(str(spec[0]), spec[2])
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", UiTheme.guild_box(1))
		if str(spec[1]) != "":
			var ic: TextureRect = TextureRect.new()
			SpriteLib.fit_icon(ic, str(spec[1]), 0.62)
			b.icon = ic.texture
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 10)
			ic.free()
		bar.add_child(b)


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var rec: Dictionary = Profile.character_record(player.character.id)
	var lvl: int = int(rec["level"])
	_hero_label.text = "%s  Lv %d" % [player.character.display_name, lvl]
	_rank_label.text = "%s-rank adventurer" % Profile.guild_rank()
	if _portrait.texture == null or _portrait.get_meta("hero", "") != player.character.id:
		_portrait.set_meta("hero", player.character.id)
		SpriteLib.fit_icon(_portrait, player.character.sprite, 2.2)
		# head and shoulders: the head sits about a third down the hero frame
		_portrait.position = Vector2(13.0 - _portrait.size.x / 2.0, 15.0 - _portrait.size.y * 0.36)
	_exp_bar.max_value = HeroProgress.xp_to_next(lvl)
	_exp_bar.value = int(rec["exp"]) if lvl < HeroProgress.max_level() else _exp_bar.max_value
	_keys.text = "%s Inventory   %s Interact   %s Pause" % [Controls.action_label("inventory"), Controls.action_label("interact"), Controls.action_label("pause")]
	_gold_label.text = str(Profile.gold())
	_shard_label.text = str(Profile.shards())
	_sp_label.text = ("%d skill point%s to spend" % [int(rec["sp"]), "" if int(rec["sp"]) == 1 else "s"]) if int(rec["sp"]) > 0 else ""


func _unhandled_input(event: InputEvent) -> void:
	if _modal != null:
		return
	if event.is_action_pressed("pause"):
		_open_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		_open_equipment()
		get_viewport().set_input_as_handled()


func _show(c: Control) -> void:
	if _modal != null and is_instance_valid(_modal):
		return
	_modal = c
	if c is Modal:   # guild menus wear the hall's wood-and-brass frame
		(c as Modal).panel.add_theme_stylebox_override("panel", UiTheme.guild_box(2, 6))
	player.input_enabled = false
	get_tree().paused = true
	ui_root.add_child(c)
	c.tree_exited.connect(func() -> void:
		_modal = null
		if is_instance_valid(player):
			player.input_enabled = true
			player.fire_lock = true
			player.refresh_equipment()
		if is_inside_tree():
			get_tree().paused = false)


func is_modal_open() -> bool:
	return _modal != null and is_instance_valid(_modal)


func _open_menu() -> void:
	var m: Modal = Modal.new()
	m.add_title("ADVENTURERS' GUILD")
	m.add_button("Resume", m.queue_free)
	m.add_button("Settings", func() -> void: m.add_child(SettingsPanel.new()))
	m.add_button("Save and return to title", func() -> void:
		Profile.save()
		get_tree().paused = false
		Game.goto("title"))
	_show(m)


func _open_reception() -> void:
	var hero: String = Profile.selected_hero()
	var c: CharacterData = Db.character(hero)
	var rec: Dictionary = Profile.character_record(hero)
	var m: Modal = Modal.new()
	m.add_title("GUILD RECEPTION")
	var next: String = ""
	for id: String in Db.mission_order:
		if Profile.mission_unlocked(id) and not Profile.mission_completed(id):
			next = str(Db.mission(id).get("name", id))
			break
	m.add_text("\"Welcome back, %s! You are a %s-rank adventurer, level %d.\"" % [c.display_name, Profile.guild_rank(), int(rec["level"])], UiTheme.TEXT, 280)
	m.add_text("Missions completed: %d.  %s" % [Profile.missions_completed_total(),
		("Next posting: %s." % next) if next != "" else "Every posting is cleared - try them again for better loot!"], UiTheme.DIM, 280)
	if int(rec["sp"]) > 0:
		m.add_text("You have %d unspent skill point(s): visit the Skill Library." % int(rec["sp"]), UiTheme.ACCENT, 280)
	m.add_button("Mission board", func() -> void:
		m.queue_free()
		_open_missions.call_deferred())
	m.add_button("Equipment", func() -> void:
		m.queue_free()
		_open_equipment.call_deferred())
	m.add_button("Skills", func() -> void:
		m.queue_free()
		_open_skills.call_deferred())
	m.add_button("Goodbye", m.queue_free)
	_show(m)


func _open_missions() -> void:
	_show(MissionBoard.new())


func _open_equipment() -> void:
	_show(InventoryPanel.new())


func _open_skills() -> void:
	_show(SkillTreePanel.new())


func _open_shop() -> void:
	_show(ShopPanel.new())


func _open_heroes() -> void:
	var p: HeroSelect = HeroSelect.new()
	p.selected.connect(func(id: String) -> void:
		if Profile.select_hero(id):
			Profile.save()
			_spawn_player(id))
	_show(p)


func _open_forge() -> void:
	_show(ForgePanel.new())


func _open_quests() -> void:
	_show(QuestPanel.new())


func _show_tutorial() -> void:
	var m: Modal = Modal.new()
	m.add_title("THE ADVENTURERS' GUILD")
	var lines: String
	if Controls.touch_ui_enabled():
		lines = "Left stick: move.  Right pad: aim & attack.\nButtons: skill, dash, swap, use."
	else:
		lines = "WASD move - Mouse aim - LMB attack\nRMB/Q skill - Space dash - Tab swap weapon\nE interact - I inventory - R reload - M map - Esc pause\nGamepad fully supported."
	m.add_text(lines, UiTheme.TEXT, 280)
	m.add_text("Talk to the receptionist, gear up at the Equipment rack, try your attacks on the training dummies, then pick an expedition at the Mission Board.", UiTheme.DIM, 280)
	m.add_button("Got it", func() -> void:
		Profile.data["seen_tutorial"] = true
		Profile.save()
		m.queue_free())
	_show(m)
