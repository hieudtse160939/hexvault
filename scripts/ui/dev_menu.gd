extends PanelContainer
## Developer tools (F1 / `). Only reachable in debug builds.

var _out: Label
var _seed: LineEdit


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2(6, 40)
	var v: VBoxContainer = VBoxContainer.new()
	add_child(v)
	v.add_child(UiTheme.label("DEV MENU (F1)", UiTheme.GOLD))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	v.add_child(grid)
	grid.add_child(UiTheme.button("Save/Load test", _save_test))
	grid.add_child(UiTheme.button("God mode", func() -> void:
		Game.god_mode = not Game.god_mode
		_log("God mode: %s" % Game.god_mode)))
	grid.add_child(UiTheme.button("Full map debug", func() -> void:
		Game.debug_show_full_map = not Game.debug_show_full_map
		_log("Full map: %s" % Game.debug_show_full_map)))
	grid.add_child(UiTheme.button("+500 shards", func() -> void:
		Profile.add_shards(500)
		Profile.save()
		_log("Shards: %d" % Profile.shards())))
	grid.add_child(UiTheme.button("Kill room", _kill_all))
	grid.add_child(UiTheme.button("Skip to boss", func() -> void:
		if Game.is_in_run():
			Game.run.floor_index = RunState.TOTAL_FLOORS - 1
			Game.next_floor()
		else:
			_log("Start a run first")))
	grid.add_child(UiTheme.button("Stress test", _stress))
	grid.add_child(UiTheme.button("Reset profile", func() -> void:
		Profile.reset_to_defaults()
		_log("Profile reset")))
	var row: HBoxContainer = HBoxContainer.new()
	v.add_child(row)
	_seed = LineEdit.new()
	_seed.placeholder_text = "seed (0=random)"
	_seed.custom_minimum_size = Vector2(90, 0)
	_seed.text = str(Game.forced_seed)
	row.add_child(_seed)
	row.add_child(UiTheme.button("Set seed", func() -> void:
		Game.forced_seed = int(_seed.text)
		_log("Next run seed: %d" % Game.forced_seed)))
	_out = UiTheme.label("", UiTheme.TEXT)
	_out.custom_minimum_size = Vector2(200, 0)
	_out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_out)


func _log(t: String) -> void:
	_out.text = t
	print("[dev] ", t)


func _save_test() -> void:
	var rep: Dictionary = SaveManager.self_test()
	_log(("PASS" if rep["ok"] else "FAIL") + "\n" + "\n".join(rep["lines"]))


func _kill_all() -> void:
	var n: int = 0
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("receive_hit"):
			var h: HitInfo = HitInfo.make(99999, Vector2.ZERO, true, Vector2.ZERO)
			e.call("receive_hit", h)
			n += 1
	_log("Killed %d" % n)


## Spawns 40 enemies and a storm of projectiles, then measures real frame times.
func _stress() -> void:
	var lvl: Level = Level.current
	if lvl == null or lvl.player == null:
		_log("Enter a dungeon first")
		return
	var room: Room = lvl.room_at_world(lvl.player.global_position)
	if room == null:
		_log("Stand inside a room")
		return
	Game.god_mode = true
	var ids: Array = Db.enemies.keys()
	for i: int in 40:
		var t: Vector2i = room.rect.position + Vector2i(randi() % room.rect.size.x, randi() % room.rect.size.y)
		if lvl.is_walkable(t):
			var e: Enemy = Enemy.create(Db.enemy(str(ids[i % ids.size()])), false, 3, 0, i)
			e.position = Level.to_world(t)
			e.aggro = true
			lvl.add_entity(e)
	for i: int in 300:
		var p: Projectile = lvl.pool.acquire()
		p.from_player = i % 2 == 0
		p.range_left = 400.0
		lvl.pool.launch(p, lvl.player.global_position, Vector2.from_angle(i * 0.37) * 60.0, "proj_orb_red")
	var frames: PackedFloat32Array = []
	var last: int = Time.get_ticks_usec()
	for i: int in 180:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
	frames.sort()
	var avg: float = 0.0
	for f: float in frames:
		avg += f
	avg /= frames.size()
	var p95: float = frames[int(frames.size() * 0.95)]
	Game.god_mode = false
	_log("Stress: %d enemies, %d projectiles\navg %.2f ms  p95 %.2f ms  worst %.2f ms" % [
		get_tree().get_nodes_in_group("enemies").size(), lvl.pool.active_count(), avg, p95, frames[frames.size() - 1]])
