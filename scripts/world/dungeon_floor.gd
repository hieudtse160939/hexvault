extends Node2D
## Screen: one dungeon floor of a run.

const REVIVE_COST: int = 40

var floor_index: int = 1
var level: Level
var player: Player
var camera: GameCamera
var ui_layer: CanvasLayer
var ui_root: Control
var hud: Hud
var minimap: Minimap
var touch: TouchControls
var _modal: Control = null
var _hit_stop_left: float = 0.0
var _objective_t: float = 0.0
var _objective: String = ""


func setup(args: Dictionary) -> void:
	floor_index = int(args.get("floor", 1))


func _ready() -> void:
	add_to_group("dungeon_floor")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var run: RunState = Game.run
	if run == null:
		Game.start_run(Profile.selected_hero())
		return
	run.floor_index = floor_index
	Profile.set_stat_max("max_floor", floor_index)
	var cfg: Dictionary = DungeonGenerator.floor_config(floor_index, run.total_floors)
	var layout: DungeonLayout = DungeonGenerator.generate(run.seed_value, floor_index, cfg, Db.room_templates)
	if layout.used_fallback:
		push_warning("Dungeon: fallback layout used for seed %d floor %d" % [run.seed_value, floor_index])
	level = Level.new()
	level.name = "Level"
	add_child(level)
	LevelBuilder.build(level, layout)
	var c: CharacterData = Db.character(run.character_id)
	player = Player.create(c)
	var start: Room = null
	for r: Room in level.rooms:
		if r.room_type == "start":
			start = r
	player.position = start.center_world() if start != null else Vector2.ZERO
	level.player = player
	level.add_entity(player)
	player.load_run_weapons(run)
	player.died.connect(_on_player_died)
	camera = GameCamera.new()
	camera.target = player
	add_child(camera)
	camera.make_current()
	camera.snap_to_target()
	_build_ui()
	Events.hit_stop.connect(_on_hit_stop)
	Sfx.play_music("dungeon")
	Events.floor_started.emit(floor_index)
	Events.toast.emit("Floor %d-%d   seed %d" % [1, floor_index, run.seed_value] if OS.is_debug_build() else "Floor %d" % floor_index)


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = UiTheme.get_theme()
	ui_layer.add_child(ui_root)
	SafeArea.apply(ui_root)
	hud = Hud.new()
	hud.player = player
	ui_root.add_child(hud)
	minimap = Minimap.new()
	minimap.level = level
	ui_root.add_child(minimap)
	touch = TouchControls.new()
	touch.player = player
	touch.pause_pressed.connect(request_pause)
	ui_root.add_child(touch)


func _process(delta: float) -> void:
	_objective_t -= delta
	if _objective_t <= 0.0:
		_objective_t = 0.25
		var o: String = objective_text()
		if o != _objective:
			_objective = o
			Events.objective_changed.emit(o)
	if _hit_stop_left > 0.0:
		_hit_stop_left -= delta / maxf(Engine.time_scale, 0.01)
		if _hit_stop_left <= 0.0:
			Engine.time_scale = 1.0


## The player's current goal on this floor (shown in the HUD).
func objective_text() -> String:
	if level == null or Game.run == null:
		return ""
	var run: RunState = Game.run
	var r: Room = level.active_room
	if r != null and r.active:
		if r.room_type == "boss":
			return "Defeat the boss!"
		return "Defeat the enemies (%d left)" % maxi(r._alive + r._pending, 1)
	for n: Node in level.entities.get_children():
		if n is Portal and (n as Portal).mode == Portal.Mode.VICTORY and not (n as Portal).used:
			return "Boss defeated! Take the portal home"
	var head: String = ("%s  F%d/%d" % [str(Db.mission(run.mission_id).get("name", "Expedition")), run.floor_index, run.total_floors])
	if run.floor_index >= run.total_floors:
		return head + "\nFind and defeat the boss"
	return head + "\nFind the portal to descend"


func _on_hit_stop(duration: float) -> void:
	_hit_stop_left = maxf(_hit_stop_left, duration)
	Engine.time_scale = 0.05


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _modal == null:
		request_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and _modal == null and player != null and player.is_alive():
		_show_modal(InventoryPanel.new())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_map"):
		minimap.toggle_expanded()
		get_viewport().set_input_as_handled()


func request_pause() -> void:
	if _modal != null or player == null or not player.is_alive():
		return
	var pm: PauseMenu = PauseMenu.new()
	pm.closed.connect(func() -> void: _modal = null)
	_show_modal(pm)


func _show_modal(c: Control) -> void:
	_modal = c
	get_tree().paused = true
	ui_root.add_child(c)
	c.tree_exited.connect(func() -> void:
		if is_instance_valid(player):
			player.fire_lock = true
		if _modal == c:
			_modal = null
		if is_inside_tree():
			get_tree().paused = false)


## Offers a choice of three boons (elite rewards, event room).
func offer_boons(title: String) -> void:
	if _modal != null:
		await get_tree().create_timer(0.5).timeout
		if _modal != null:
			return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([Game.run.seed_value, floor_index, Game.run.rooms_cleared, Game.run.boons.size(), title])
	var ids: Array = Array(Db.boon_order).duplicate()
	var choice: Array[String] = []
	while choice.size() < 3 and not ids.is_empty():
		var i: int = rng.randi_range(0, ids.size() - 1)
		choice.append(str(ids[i]))
		ids.remove_at(i)
	var bc: BoonChoice = BoonChoice.new()
	bc.title = title
	bc.choices = choice
	bc.chosen.connect(func(id: String) -> void:
		Game.run.add_boon(id)
		player.recompute_stats()
		var mods: Dictionary = Db.boons.get(id, {}).get("mods", {})
		if mods.has("heal"):
			player.heal(int(mods["heal"]))
		Sfx.play("boon")
		Events.toast.emit("Boon: %s" % Db.boons[id]["name"]))
	Sfx.play("boon")
	_show_modal(bc)


func _on_player_died() -> void:
	await get_tree().create_timer(1.4).timeout
	var ds: DeathScreen = DeathScreen.new()
	ds.can_revive = not Game.run.revive_used and Profile.shards() >= REVIVE_COST
	ds.revive_cost = REVIVE_COST
	ds.revive_used = Game.run.revive_used
	ds.revive.connect(func() -> void:
		if Profile.spend_shards(REVIVE_COST):
			Game.run.revive_used = true
			player.revive())
	ds.give_up.connect(func() -> void: Game.end_run(false))
	_show_modal(ds)
