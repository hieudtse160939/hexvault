extends "res://tests/test_case.gd"
## End-to-end: a complete run through the real screens, rooms, portals and boss.

var _saved: Dictionary
var _auto: bool


func before_each() -> void:
	_auto = Profile.autosave
	_saved = Profile.data.duplicate(true)
	Profile.autosave = false
	Profile.data = SaveManager.profile_defaults()
	Profile.data["seen_tutorial"] = true
	Game.god_mode = true


func after_each() -> void:
	Game.god_mode = false
	Profile.data = _saved
	Profile.autosave = _auto
	get_tree().paused = false
	Engine.time_scale = 1.0


func _floor_node() -> Node:
	return get_tree().get_first_node_in_group("dungeon_floor")


func _kill_everything() -> void:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("receive_hit") and e.has_method("is_alive") and bool(e.call("is_alive")):
			e.call("receive_hit", HitInfo.make(99999, Vector2.ZERO, true, Vector2.ZERO))


func _clear_room(lvl: Level, room: Room) -> bool:
	lvl.player.global_position = Level.to_world(room.rect.get_center())
	await wait_physics_frames(3)
	if not room.active:
		return room.cleared
	assert_false(room._barriers.is_empty(), "%s room locks its doors" % room.room_type)
	var guard: int = 0
	while not room.cleared and guard < 900:
		guard += 1
		_kill_everything()
		await wait_physics_frames(2)
		get_tree().paused = false # elite boon offers pause the tree; keep simulating
	return room.cleared


func _close_modals(floor_node: Node) -> void:
	var root: Control = floor_node.get("ui_root")
	if root == null:
		return
	for c: Node in root.get_children():
		if c is BoonChoice:
			var bc: BoonChoice = c
			bc.chosen.emit(bc.choices[0])
			bc.queue_free()
		elif c is Modal:
			c.queue_free()
	await wait_frames(2)
	get_tree().paused = false


func test_complete_run_to_victory() -> void:
	var main: Node = add_scene("res://scenes/main.tscn")
	assert_not_null(main)
	await wait_frames(5)
	Game.start_run("ranger", 4242)
	await wait_frames(10)
	for f: int in range(1, RunState.TOTAL_FLOORS + 1):
		var fl: Node = _floor_node()
		assert_not_null(fl, "dungeon floor %d loaded" % f)
		var lvl: Level = fl.get("level")
		assert_eq(Game.run.floor_index, f)
		for room: Room in lvl.rooms:
			if room.room_type in ["combat", "elite"]:
				var ok: bool = await _clear_room(lvl, room)
				assert_true(ok, "floor %d room %d (%s) cleared" % [f, room.room_id, room.room_type])
				assert_true(room._barriers.is_empty(), "doors unlocked after clear")
				await _close_modals(fl)
		if f < RunState.TOTAL_FLOORS:
			var portal: Portal = null
			for n: Node in lvl.entities.get_children():
				if n is Portal:
					portal = n
			assert_not_null(portal, "exit portal exists on floor %d" % f)
			portal.interact(lvl.player)
			await wait_seconds(0.8)
		else:
			var boss_room: Room = null
			for room2: Room in lvl.rooms:
				if room2.room_type == "boss":
					boss_room = room2
			assert_not_null(boss_room)
			lvl.player.global_position = Level.to_world(boss_room.rect.get_center() + Vector2i(0, 4))
			assert_true(await wait_until(func() -> bool: return boss_room.boss != null and is_instance_valid(boss_room.boss), 5.0), "boss spawned")
			await wait_seconds(0.5)
			var b: Boss = boss_room.boss
			for i: int in 6:
				b.health.take(HitInfo.make(b.health.max_hp / 3 + 1, Vector2.ZERO, true, Vector2.ZERO))
				b._emit_health()
				b._check_phase()
				await wait_seconds(1.6)
				if not b.is_alive():
					break
			if b.is_alive():
				b.receive_hit(HitInfo.make(999999, Vector2.ZERO, true, Vector2.ZERO))
			assert_false(b.is_alive(), "boss defeated")
			assert_true(boss_room.cleared)
			assert_true(await wait_until(func() -> bool:
				for n: Node in lvl.entities.get_children():
					if n is Portal and (n as Portal).mode == Portal.Mode.VICTORY:
						return true
				return false, 4.0), "victory portal spawned")
			for n2: Node in lvl.entities.get_children():
				if n2 is Portal:
					(n2 as Portal).interact(lvl.player)
			await wait_seconds(0.8)
	assert_eq(Game.current_screen, "results", "results screen shown")
	assert_true(bool(Game.last_summary.get("victory", false)), "run marked as victory")
	assert_eq(Profile.stat("wins"), 1)
	assert_eq(Profile.stat("bosses"), 1)
	assert_true(Profile.has_achievement("slayer_of_ossifex"))
	assert_true(Profile.is_weapon_unlocked("prism_lance"), "boss achievement unlocks the Prism Lance")
	assert_gt(Profile.stat("kills"), 10)
	assert_gt(Profile.shards(), 0, "shards banked")
	main.queue_free()
	await wait_frames(2)
