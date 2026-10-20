extends Node
## Automated visual tour for QA. Launch with:
##   godot --path . -- --tour=<absolute output dir>
## Visits title, hub, a dungeon floor, a fight, the debug map and the boss,
## saving a PNG at each step plus tour_report.json (frame timings, errors).

var out_dir: String = ""
var report: Dictionary = {"shots": [], "frame_ms": {}}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = out_dir.path_join(name + ".png")
	img.save_png(path)
	report["shots"].append(path)
	print("[tour] shot ", path, " ", img.get_size())


func _measure(label: String, frames: int) -> void:
	var times: PackedFloat32Array = []
	var last: int = Time.get_ticks_usec()
	for i: int in frames:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	var avg: float = 0.0
	for t: float in times:
		avg += t
	report["frame_ms"][label] = {"avg": avg / times.size(), "p95": times[int(times.size() * 0.95)], "max": times[times.size() - 1]}


func _player() -> Player:
	return Level.current.player if Level.current != null else null


func _teleport_to(room_type: String) -> Room:
	var lvl: Level = Level.current
	for r: Room in lvl.rooms:
		if r.room_type == room_type:
			_player().global_position = Level.to_world(r.rect.get_center() + Vector2i(0, 2))
			return r
	return null


func _run() -> void:
	Profile.autosave = false
	Profile.data["seen_tutorial"] = true
	Settings.data["show_fps"] = true
	await _frames(20)
	await _shot("01_title")
	Game.goto("hub")
	await _frames(40)
	await _shot("02_hub")
	Game.start_run("ranger", 777)
	await _frames(40)
	await _shot("03_dungeon_start")
	Game.god_mode = true
	var room: Room = _teleport_to("combat")
	await _frames(70)
	await _shot("04_combat_spawn")
	# Fire at enemies for a while (simulated input).
	Input.action_press("fire")
	Controls.device = Controls.Device.GAMEPAD
	Settings.data["aim_assist"] = true
	await _measure("combat", 120)
	await _shot("05_combat_fire")
	Input.action_release("fire")
	Game.debug_show_full_map = true
	var fl: Node = get_tree().get_first_node_in_group("dungeon_floor")
	(fl.get("minimap") as Minimap).toggle_expanded()
	await _frames(5)
	await _shot("06_debug_map")
	(fl.get("minimap") as Minimap).toggle_expanded()
	_teleport_to("shop")
	Game.god_mode = true
	await _frames(45)
	await _shot("07_shop")
	Game.run.floor_index = RunState.TOTAL_FLOORS - 1
	Game.next_floor()
	await _frames(30)
	_teleport_to("boss")
	await _frames(150)
	await _shot("08_boss")
	Input.action_press("fire")
	await _measure("boss", 180)
	await _shot("09_boss_fight")
	Input.action_release("fire")
	var f: FileAccess = FileAccess.open(out_dir.path_join("tour_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, " "))
	f.close()
	print("[tour] done")
	get_tree().quit()
