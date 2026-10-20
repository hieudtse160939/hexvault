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
	var hero: String = "duelist"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tour-hero="):
			hero = a.substr(12)
	Game.goto("select")
	await _frames(20)
	var sel: Node = get_tree().root.find_children("*", "Control", true, false).filter(func(n: Node) -> bool: return n.has_method("_begin")).front()
	sel.call("_show", hero)
	await _frames(20)
	await _shot("02_character_select")
	Profile.new_game(hero)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4
	for i: int in 10:
		Profile.give_item(ItemGen.random_equipment(rng, 4, 1.5))
	Profile.give_item(ItemGen.make_book("book_flame_nova"))
	Profile.data["gold"] = 400
	Profile.grant_exp(hero, 300)
	Game.goto("hub")
	await _frames(40)
	await _shot("03_guild")
	var guild: Node = get_tree().get_first_node_in_group("guild")
	var p0: Player = guild.get("player")
	for spot: Array in [["04_guild_reception", Vector2i(17, 7)], ["05_guild_training", Vector2i(6, 15)], ["06_guild_shop_corner", Vector2i(28, 12)]]:
		p0.global_position = Level.to_world(spot[1])
		await _frames(30)
		await _shot(spot[0])
	for pair: Array in [["_open_reception", "07_reception"], ["_open_missions", "08_mission_board"],
			["_open_equipment", "09_inventory"], ["_open_shop", "10_shop"], ["_open_skills", "11_skill_tree"]]:
		guild.call(pair[0])
		await _frames(12)
		if pair[0] == "_open_equipment":
			var inv: Node = guild.get("_modal")
			inv.call("select", str(Inventory.bag(Profile.data)[0]))
			await _frames(4)
		if pair[0] == "_open_shop":
			guild.get("_modal").call("_pick", 1)
			await _frames(4)
		await _shot(pair[1])
		var m: Variant = guild.get("_modal")
		if m is Node and is_instance_valid(m):
			(m as Node).queue_free()
		await _frames(5)
	Game.start_mission("forgotten_catacombs", 777)
	await _frames(40)
	await _shot("12_dungeon_start")
	Game.god_mode = true
	var room: Room = _teleport_to("combat")
	await _frames(70)
	await _shot("13_combat_spawn")
	# Fire at enemies for a while (simulated input).
	Input.action_press("fire")
	Controls.device = Controls.Device.GAMEPAD
	Settings.data["aim_assist"] = true
	await _measure("combat", 120)
	await _shot("14_combat_fire")
	Input.action_release("fire")
	Game.debug_show_full_map = true
	var fl: Node = get_tree().get_first_node_in_group("dungeon_floor")
	(fl.get("minimap") as Minimap).toggle_expanded()
	await _frames(5)
	await _shot("15_debug_map")
	(fl.get("minimap") as Minimap).toggle_expanded()
	_teleport_to("shop")
	Game.god_mode = true
	await _frames(45)
	await _shot("16_dungeon_shop")
	Game.run.floor_index = Game.run.total_floors - 1
	Game.next_floor()
	await _frames(30)
	_teleport_to("boss")
	await _frames(150)
	await _shot("17_boss")
	Input.action_press("fire")
	await _measure("boss", 180)
	await _shot("18_boss_fight")
	Input.action_release("fire")
	# Stress: 40 enemies + 300 projectiles in the boss room.
	var lvl: Level = Level.current
	var ids: Array = Db.enemies.keys()
	var boss_room: Room = lvl.room_at_world(_player().global_position)
	for i: int in 40:
		var t: Vector2i = boss_room.rect.position + Vector2i(2 + (i * 7) % (boss_room.rect.size.x - 4), 2 + (i * 5) % (boss_room.rect.size.y - 4))
		if lvl.is_walkable(t):
			var e: Enemy = Enemy.create(Db.enemy(str(ids[i % ids.size()])), i % 10 == 0, 3, 0, i)
			e.position = Level.to_world(t)
			e.aggro = true
			lvl.add_entity(e)
	for i: int in 300:
		var pr: Projectile = lvl.pool.acquire()
		pr.from_player = i % 2 == 0
		pr.range_left = 600.0
		lvl.pool.launch(pr, _player().global_position, Vector2.from_angle(i * 0.37) * 40.0, "proj_orb_red")
	report["stress_entities"] = {"enemies": get_tree().get_nodes_in_group("enemies").size(), "projectiles": lvl.pool.active_count()}
	await _measure("stress", 300)
	await _shot("19_stress")
	for c: Node in lvl.entities.get_children():
		if c is ItemPickup:
			(c as ItemPickup).try_collect(_player())
	Game.end_run(true)
	await _frames(20)
	await _shot("20_results")
	Game.return_to_guild()
	await _frames(30)
	await _shot("21_back_in_guild")
	var f: FileAccess = FileAccess.open(out_dir.path_join("tour_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, " "))
	f.close()
	print("[tour] done")
	get_tree().quit()
