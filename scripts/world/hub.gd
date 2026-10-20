extends Node2D
## Screen: the Sanctum hub. Walk between stations; step into the portal to start a run.

const MAP: PackedStringArray = [
	"...........................",
	"...........................",
	"...........................",
	"....rrr.............rrr....",
	"....rrr.............rrr....",
	"...........................",
	"...........................",
	"..........rrrrrrr..........",
	"..........rrrrrrr..........",
	"..........rrrrrrr..........",
	"...........................",
	"...........................",
	"....rrr.............rrr....",
	"....rrr.............rrr....",
	"...........................",
	"...........................",
	"...........................",
]

var level: Level
var player: Player
var camera: GameCamera
var ui_root: Control
var _modal: Control = null
var _portal: Portal
var _hero_label: Label
var _shards_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Game.run = null
	level = Level.new()
	add_child(level)
	var runes: Dictionary = {}
	for y: int in MAP.size():
		for x: int in MAP[y].length():
			var t: Vector2i = Vector2i(x, y)
			level.floor_tiles[t] = true
			if MAP[y][x] == "r":
				runes[t] = true
	_paint_hub(runes)
	level.build_nav()
	var sel: String = str(Profile.data["selected_character"])
	if not Profile.is_character_unlocked(sel):
		sel = "ranger"
	_spawn_player(sel)
	var c: Vector2 = Level.to_world(Vector2i(13, 8))
	level.add_entity(HubStation.create("Hero Shrine", "Choose your hero", "prop_statue", Level.to_world(Vector2i(5, 4)), _open_heroes))
	level.add_entity(HubStation.create("Armory", "Unlock weapons", "prop_crate", Level.to_world(Vector2i(21, 4)), _open_armory))
	level.add_entity(HubStation.create("Rune Forge", "Permanent upgrades", "prop_fountain", Level.to_world(Vector2i(5, 13)), _open_forge))
	var board: HubStation = HubStation.create("Quest Board", "Quests & achievements", "prop_pedestal", Level.to_world(Vector2i(21, 13)), _open_quests)
	board.badge = Profile.claimable_quests
	level.add_entity(board)
	_portal = Portal.create(Portal.Mode.HUB_START, c)
	_portal.character_id = sel
	level.add_entity(_portal)
	for t: Vector2i in [Vector2i(1, 1), Vector2i(25, 1), Vector2i(1, 15), Vector2i(25, 15)]:
		level.add_entity(SolidProp.create("prop_lamp", Level.to_world(t), Vector2(8, 6), Vector2.ZERO))
		level.set_solid(t, true)
	camera = GameCamera.new()
	camera.target = player
	add_child(camera)
	camera.make_current()
	camera.snap_to_target()
	_build_ui()
	Sfx.play_music("hub")
	if not bool(Profile.data["seen_tutorial"]):
		_show_tutorial()


func _paint_hub(runes: Dictionary) -> void:
	var walls: Dictionary = {}
	for t: Vector2i in level.floor_tiles:
		level.floor_layer.set_cell(t, 0, Tiles.coords(Tiles.HUB_RUNE if runes.has(t) else Tiles.HUB_FLOOR))
		for dy: int in [-1, 0, 1]:
			for dx: int in [-1, 0, 1]:
				var n: Vector2i = t + Vector2i(dx, dy)
				if not level.floor_tiles.has(n):
					walls[n] = true
	for w: Vector2i in walls:
		var face: bool = level.floor_tiles.has(w + Vector2i(0, 1))
		var idx: int = Tiles.WALL_TOP
		if face:
			idx = Tiles.WALL_BANNER if w.x % 6 == 3 else (Tiles.WALL_LAMP if w.x % 6 == 0 else Tiles.WALL_FACE[w.x % 2])
		level.wall_layer.set_cell(w, 0, Tiles.coords(idx))


func _spawn_player(id: String) -> void:
	var pos: Vector2 = Level.to_world(Vector2i(13, 12))
	if player != null:
		pos = player.global_position
		player.queue_free()
	player = Player.create(Db.character(id))
	player.position = pos
	level.player = player
	level.add_entity(player)
	var tmp: RunState = RunState.new()
	tmp.weapons = [Db.character(id).start_weapon]
	player.load_run_weapons(tmp)
	if camera != null:
		camera.target = player
	if _portal != null:
		_portal.character_id = id


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
	var top: HBoxContainer = HBoxContainer.new()
	top.position = Vector2(4, 4)
	ui_root.add_child(top)
	var icon: TextureRect = TextureRect.new()
	icon.texture = SpriteLib.texture("icon_shard")
	top.add_child(icon)
	_shards_label = UiTheme.label("", UiTheme.ACCENT, true)
	top.add_child(_shards_label)
	_hero_label = UiTheme.label("", UiTheme.TEXT, true)
	_hero_label.position = Vector2(4, 22)
	ui_root.add_child(_hero_label)
	var hint: Label = UiTheme.label("", UiTheme.TEXT, true)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.offset_top = -44
	hint.offset_bottom = -34
	ui_root.add_child(hint)
	Events.interact_hint.connect(func(t: String) -> void:
		hint.text = ("" if t.is_empty() else ("[E] " if Controls.device == Controls.Device.KEYBOARD_MOUSE else ("(X) " if Controls.device == Controls.Device.GAMEPAD else "USE: ")) + t))
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


func _process(_delta: float) -> void:
	_shards_label.text = "%d shards" % Profile.shards()
	if player != null:
		_hero_label.text = "%s the %s" % [player.character.display_name, player.character.title]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _modal == null:
		_open_menu()
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
		if is_inside_tree():
			get_tree().paused = false)


func _open_menu() -> void:
	var m: Modal = Modal.new()
	m.add_title("SANCTUM")
	m.add_button("Resume", m.queue_free)
	m.add_button("Settings", func() -> void: m.add_child(SettingsPanel.new()))
	m.add_button("Title screen", func() -> void:
		get_tree().paused = false
		Game.goto("title"))
	_show(m)


func _open_heroes() -> void:
	var p: HeroSelect = HeroSelect.new()
	p.selected.connect(func(id: String) -> void:
		Profile.data["selected_character"] = id
		Profile.save()
		_spawn_player(id))
	_show(p)


func _open_armory() -> void:
	_show(ArmoryPanel.new())


func _open_forge() -> void:
	_show(ForgePanel.new())


func _open_quests() -> void:
	_show(QuestPanel.new())


func _show_tutorial() -> void:
	var m: Modal = Modal.new()
	m.add_title("WELCOME TO THE SANCTUM")
	var lines: String
	if Controls.touch_ui_enabled():
		lines = "Left stick: move.  Right pad: aim & shoot.\nButtons: skill, dash, swap, use."
	else:
		lines = "WASD move - Mouse aim - LMB shoot\nRMB/Q skill - Space dash - Tab swap\nE use - R reload - M map - Esc pause\nGamepad fully supported."
	m.add_text(lines, UiTheme.TEXT, 260)
	m.add_text("Visit the stations, then step into the portal to dive into the Hexvault.", UiTheme.DIM, 260)
	m.add_button("Got it", func() -> void:
		Profile.data["seen_tutorial"] = true
		Profile.save()
		m.queue_free())
	_show(m)
