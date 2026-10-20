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

const W: int = 34   # interior size in tiles
const H: int = 22
const SPAWN: Vector2i = Vector2i(17, 15)
const STAGE: Rect2i = Rect2i(2, 15, 9, 6)      # training ring
const RUG: Rect2i = Rect2i(16, 6, 2, 16)       # runner from the reception to the gate

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
var _arrival: bool = false


func setup(args: Dictionary) -> void:
	_arrival = bool(args.get("arrival", false))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("guild")
	Game.run = null
	level = Level.new()
	add_child(level)
	for y: int in range(1, H + 1):
		for x: int in range(1, W + 1):
			level.floor_tiles[Vector2i(x, y)] = true
	_paint()
	level.build_nav()
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


# --- map ------------------------------------------------------------------------------
func _paint() -> void:
	for t: Vector2i in level.floor_tiles:
		var idx: int = Tiles.GUILD_WOOD[(t.x * 7 + t.y * 13) % 2]
		if STAGE.has_point(t):
			idx = Tiles.GUILD_STAGE
		elif RUG.has_point(t):
			idx = Tiles.GUILD_RUG
		level.floor_layer.set_cell(t, 0, Tiles.coords(idx))
	var walls: Dictionary = {}
	for t2: Vector2i in level.floor_tiles:
		for dy: int in [-1, 0, 1]:
			for dx: int in [-1, 0, 1]:
				var n: Vector2i = t2 + Vector2i(dx, dy)
				if not level.floor_tiles.has(n):
					walls[n] = true
	for w: Vector2i in walls:
		var face: bool = level.floor_tiles.has(w + Vector2i(0, 1))
		var idx2: int = Tiles.WALL_TOP
		if face:
			idx2 = Tiles.GUILD_WALL
			if w.x == 13 or w.x == 21:
				idx2 = Tiles.GUILD_WALL_BANNER
			elif w.x % 6 == 3:
				idx2 = Tiles.GUILD_WALL_LANTERN
			elif w.x == 30 or w.x == 6:
				idx2 = Tiles.GUILD_WALL_MAP
		level.wall_layer.set_cell(w, 0, Tiles.coords(idx2))


func _decor(key: String, pos: Vector2, box: Vector2) -> void:
	var p: SolidProp = SolidProp.create(key, pos, box, Vector2.ZERO)
	var spr: AnimatedSprite2D = p.get_child(1) as AnimatedSprite2D
	if spr != null and SpriteLib.is_hd(key):
		spr.position = Vector2(0, 5) - SpriteLib.pivot_from_centre_world(key)
	(p.get_child(0) as CollisionShape2D).position = Vector2(0, 5 - box.y / 2.0 + 2.0)
	level.add_entity(p)


func _npc(sprite: String, pos: Vector2, name_text: String, flip: bool) -> void:
	var n: Node2D = Node2D.new()
	n.position = pos
	var s: AnimatedSprite2D = AnimatedSprite2D.new()
	SpriteLib.apply(s, sprite)
	s.play(&"idle")
	s.flip_h = flip
	s.position = Vector2(0, Player.FEET_Y) - SpriteLib.pivot_from_centre_world(sprite)
	n.add_child(s)
	var l: Label = UiTheme.label(name_text, Color("#b4fff0"), true)
	l.add_theme_font_override("font", SpriteLib.font())
	l.position = Vector2(-name_text.length() * 3.0, -32)
	l.z_index = 25
	n.add_child(l)
	level.add_entity(n)


func _station(title: String, prompt: String, sprite: String, pos: Vector2, cb: Callable, box: Vector2) -> HubStation:
	var s: HubStation = HubStation.create(title, prompt, sprite, pos, cb, box)
	level.add_entity(s)
	stations[title] = s
	return s


func _build_stations() -> void:
	# A. reception: receptionist behind the counter, the counter is the service point
	_npc("hero_cryomancer", tile_world(17, 2.6), "Rime, Receptionist", false)
	_station("Reception", "Talk to the receptionist", "guild_counter", tile_world(17, 4.4), _open_reception, Vector2(38, 7))
	# B. mission board + expedition gate
	_station("Mission Board", "Choose an expedition", "guild_board", tile_world(9.5, 3.4), _open_missions, Vector2(18, 6))
	_station("Expedition Gate", "Set out on an expedition", "prop_portal", tile_world(17, 21.2), _open_missions, Vector2(10, 4))
	# C. equipment + skills
	_station("Equipment", "Manage equipment and inventory", "guild_rack", tile_world(25, 3.6), _open_equipment, Vector2(14, 6))
	_station("Skill Library", "Skill tree and active skill", "guild_shelf", tile_world(29.5, 3.4), _open_skills, Vector2(14, 6))
	# D. shop
	_npc("hero_tinker", tile_world(30.5, 9.6), "Cog, Merchant", true)
	_station("Guild Shop", "Buy and sell equipment", "guild_table", tile_world(30.5, 11.4), _open_shop, Vector2(22, 7))
	# E. training grounds
	for p: Vector2 in [tile_world(4.5, 17.5), tile_world(8.5, 17.5)]:
		var d: TrainingDummy = TrainingDummy.create(p)
		level.add_entity(d)
		dummies.append(d)
	var sign_l: Label = UiTheme.label("TRAINING GROUNDS", UiTheme.GOLD, true)
	sign_l.add_theme_font_override("font", SpriteLib.font())
	sign_l.position = tile_world(3.6, 15.1)
	level.fx_layer.add_child(sign_l)
	# F. roster, upgrades, quests
	_station("Hero Shrine", "Switch adventurer", "prop_statue", tile_world(25, 18), _open_heroes, Vector2(12, 6))
	_station("Rune Forge", "Permanent upgrades (shards)", "prop_fountain", tile_world(29, 18), _open_forge, Vector2(12, 6))
	var board: HubStation = _station("Quest Board", "Quests & achievements", "prop_pedestal", tile_world(33, 14), _open_quests, Vector2(12, 6))
	board.badge = Profile.claimable_quests
	# G. gathering hall + storage (decor with collision)
	for p2: Vector2 in [tile_world(11, 10), tile_world(23, 10), tile_world(11, 13), tile_world(23, 13)]:
		_decor("guild_table", p2, Vector2(22, 7))
	for x: float in [3.0, 4.0]:
		_decor("guild_shelf", tile_world(x + 0.5, 2.4), Vector2(14, 6))
	_decor("guild_rack", tile_world(13.5, 2.6), Vector2(14, 6))
	for p3: Vector2 in [tile_world(1.6, 1.8), tile_world(33.4, 1.8), tile_world(1.6, 12), tile_world(14.5, 21), tile_world(19.5, 21)]:
		_decor("guild_plant", p3, Vector2(8, 4))
	for p4: Vector2 in [tile_world(33.3, 20.6), tile_world(32.3, 21.0), tile_world(33.4, 9.0), tile_world(1.6, 6.0)]:
		_decor("prop_barrel", p4, Vector2(10, 6))
	for p5: Vector2 in [tile_world(32.4, 20.0), tile_world(26.5, 7.5), tile_world(1.6, 7.0)]:
		_decor("prop_crate", p5, Vector2(12, 8))
	# timber pillars framing the central hall
	for p6: Vector2 in [tile_world(13.5, 7.5), tile_world(20.5, 7.5), tile_world(13.5, 17.5), tile_world(20.5, 17.5)]:
		_decor("prop_pillar", p6, Vector2(10, 6))


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
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(4, 4)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	panel.add_child(col)
	_hero_label = UiTheme.label("", UiTheme.TEXT, true)
	col.add_child(_hero_label)
	_exp_bar = ProgressBar.new()
	_exp_bar.custom_minimum_size = Vector2(110, 3)
	_exp_bar.show_percentage = false
	_exp_bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.GOLD, UiTheme.GOLD, 0, 0))
	_exp_bar.add_theme_stylebox_override("background", UiTheme.box(UiTheme.INK, UiTheme.INK, 0, 0))
	col.add_child(_exp_bar)
	_gold_label = UiTheme.label("", UiTheme.GOLD, true)
	col.add_child(_gold_label)
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
	var menu_btn: Button = UiTheme.button("Menu", _open_menu)
	menu_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu_btn.offset_left = -40
	menu_btn.offset_top = 4
	menu_btn.offset_right = -4
	menu_btn.focus_mode = Control.FOCUS_NONE
	ui_root.add_child(menu_btn)
	var bag_btn: Button = UiTheme.button("Bag", _open_equipment)
	bag_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	bag_btn.offset_left = -72
	bag_btn.offset_top = 4
	bag_btn.offset_right = -44
	bag_btn.focus_mode = Control.FOCUS_NONE
	ui_root.add_child(bag_btn)


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var rec: Dictionary = Profile.character_record(player.character.id)
	var lvl: int = int(rec["level"])
	_hero_label.text = "%s  Lv %d  -  %s rank" % [player.character.display_name, lvl, Profile.guild_rank()]
	_exp_bar.max_value = HeroProgress.xp_to_next(lvl)
	_exp_bar.value = int(rec["exp"]) if lvl < HeroProgress.max_level() else _exp_bar.max_value
	_keys.text = "%s Inventory   %s Interact   %s Pause" % [Controls.action_label("inventory"), Controls.action_label("interact"), Controls.action_label("pause")]
	_gold_label.text = "Gold %d    Shards %d%s" % [Profile.gold(), Profile.shards(),
		("    %d skill pt" % int(rec["sp"])) if int(rec["sp"]) > 0 else ""]


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
