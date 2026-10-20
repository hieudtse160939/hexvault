extends "res://tests/test_case.gd"
## Integration tests on a live scene tree with real physics frames.

var _saved_autosave: bool
var _counts: Dictionary = {}
var _conns: Array = []


## Counts emissions of a global signal; disconnected automatically after each test.
func _count(sig: Signal) -> void:
	var key: String = sig.get_name()
	_counts[key] = 0
	var cb: Callable = func(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
		_counts[key] = int(_counts[key]) + 1
	sig.connect(cb)
	_conns.append([sig, cb])


func _emitted(name: String) -> int:
	return int(_counts.get(name, 0))


func before_each() -> void:
	_saved_autosave = Profile.autosave
	Profile.autosave = false
	Game.run = RunState.new()
	Game.run.weapons = ["rift_pistol"]
	Game.god_mode = false


func after_each() -> void:
	for c: Array in _conns:
		(c[0] as Signal).disconnect(c[1])
	_conns.clear()
	_counts.clear()
	Profile.autosave = _saved_autosave
	Game.run = null
	Engine.time_scale = 1.0


## A 20x12 walled arena with its own Level.
func _arena() -> Level:
	var lvl: Level = Level.new()
	for y: int in 12:
		for x: int in 20:
			lvl.floor_tiles[Vector2i(x, y)] = true
	add_child_autofree(lvl)
	LevelBuilder.paint(lvl, {}, {}, false)
	lvl.build_nav()
	return lvl


func _player(lvl: Level, tile: Vector2i, id: String = "ranger") -> Player:
	var p: Player = Player.create(Db.character(id))
	p.position = Level.to_world(tile)
	lvl.player = p
	lvl.add_entity(p)
	p.load_run_weapons(Game.run)
	p.input_enabled = false
	return p


func _enemy(lvl: Level, id: String, tile: Vector2i) -> Enemy:
	var e: Enemy = Enemy.create(Db.enemy(id), false, 1, 0, 7)
	e.position = Level.to_world(tile)
	lvl.add_entity(e)
	return e


func test_player_cannot_walk_through_walls() -> void:
	var lvl: Level = _arena()
	var p: Player = _player(lvl, Vector2i(1, 5))
	await wait_physics_frames(2)
	for i: int in 60:
		p.velocity = Vector2(-200, 0)
		p.move_and_slide()
		await wait_physics_frames(1)
	assert_gt(p.global_position.x, 4.0, "stopped by the west wall (wall tile spans x<0)")
	assert_true(lvl.is_walkable(Level.to_tile(p.global_position)))


func test_projectile_weapon_damages_and_kills_enemy() -> void:
	var lvl: Level = _arena()
	var p: Player = _player(lvl, Vector2i(3, 5))
	var e: Enemy = _enemy(lvl, "gloop", Vector2i(10, 5))
	await wait_physics_frames(2)
	e.set_physics_process(false) # hold still
	_count(Events.enemy_killed)
	var start_hp: int = e.health.hp
	var w: Weapon = p.current_weapon()
	w.try_fire(Vector2.RIGHT)
	await wait_physics_frames(30)
	assert_lt(e.health.hp, start_hp, "bullet hit the enemy")
	for i: int in 40:
		w._cooldown = 0.0
		w.reloading = false
		w.ammo = 10
		w.try_fire(Vector2.RIGHT)
		await wait_physics_frames(4)
		if not e.is_alive():
			break
	assert_false(e.is_alive(), "enemy died")
	assert_gt(_emitted("enemy_killed"), 0, "kill event emitted")
	await wait_physics_frames(2)
	var coins: int = 0
	for n: Node in lvl.entities.get_children():
		if n is Pickup:
			coins += 1
	assert_gt(coins, 0, "enemy dropped loot")


func test_bullets_stop_at_walls() -> void:
	var lvl: Level = _arena()
	var p: Player = _player(lvl, Vector2i(10, 5))
	await wait_physics_frames(2)
	p.current_weapon().try_fire(Vector2.UP)
	await wait_physics_frames(2)
	assert_eq(lvl.pool.active_count(), 1)
	await wait_physics_frames(40)
	assert_eq(lvl.pool.active_count(), 0, "projectile released on wall impact")


func test_every_weapon_pattern_hurts_enemy() -> void:
	for wid: String in Db.weapon_order:
		var lvl: Level = _arena()
		Game.run.weapons = [wid]
		var p: Player = _player(lvl, Vector2i(6, 5))
		var e: Enemy = _enemy(lvl, "golem", Vector2i(8, 5))
		await wait_physics_frames(2)
		e.set_physics_process(false)
		var before: int = e.health.hp
		var w: Weapon = p.current_weapon()
		for i: int in 6:
			w._cooldown = 0.0
			w.try_fire(Vector2.RIGHT)
			await wait_physics_frames(6)
		assert_lt(e.health.hp, before, "%s (%s) damages a target 2 tiles away" % [wid, w.data.pattern])
		lvl.queue_free()
		await wait_physics_frames(1)


func test_dash_grants_invulnerability() -> void:
	var lvl: Level = _arena()
	var p: Player = _player(lvl, Vector2i(5, 5))
	await wait_physics_frames(2)
	assert_true(p.try_dash())
	var hit: bool = p.receive_hit(HitInfo.make(3, Vector2.ZERO, false, Vector2.ZERO))
	assert_false(hit, "dash i-frames block damage")
	await wait_physics_frames(20)
	assert_true(p.receive_hit(HitInfo.make(1, Vector2.ZERO, false, Vector2.ZERO)), "vulnerable after the dash")


func test_enemy_projectiles_hurt_player() -> void:
	var lvl: Level = _arena()
	var p: Player = _player(lvl, Vector2i(4, 5))
	var e: Enemy = _enemy(lvl, "sparkeye", Vector2i(12, 5))
	await wait_physics_frames(2)
	var before: int = p.health.hp + p.health.armor
	e._fire_volley(p)
	await wait_physics_frames(120)
	assert_lt(p.health.hp + p.health.armor, before, "enemy orb damaged the player")


func test_player_death_and_revive() -> void:
	var lvl: Level = _arena()
	var p: Player = _player(lvl, Vector2i(5, 5))
	await wait_physics_frames(2)
	watch_signals(p)
	for i: int in 20:
		p.health._invuln_left = 0.0
		p.receive_hit(HitInfo.make(5, Vector2.ZERO, false, Vector2.ZERO))
	assert_signal_emitted(p, "died")
	assert_false(p.is_alive())
	p.revive()
	assert_true(p.is_alive())
	assert_gt(p.health.hp, 0)


func test_all_enemy_archetypes_attack_player() -> void:
	for id: String in Db.enemies:
		var lvl: Level = _arena()
		var p: Player = _player(lvl, Vector2i(4, 5))
		p.health.setup(999, 0, 0.0)
		var e: Enemy = _enemy(lvl, id, Vector2i(9, 5))
		e.aggro = true
		await wait_physics_frames(2)
		var before: int = p.health.hp
		var summoned: bool = false
		for i: int in 600:
			await wait_physics_frames(1)
			if p.health.hp < before:
				break
			if get_tree().get_nodes_in_group("enemies").size() > 1:
				summoned = true
				break
		assert_true(p.health.hp < before or summoned, "%s threatens the player within 10s" % id)
		lvl.queue_free()
		await wait_physics_frames(1)


func test_boss_phases_and_defeat() -> void:
	var lvl: Level = _arena()
	var p: Player = _player(lvl, Vector2i(3, 10))
	p.health.setup(999, 0, 0.0)
	var room: Room = Room.new()
	room.rect = Rect2i(0, 0, 20, 12)
	room.special_tile = Vector2i(10, 6)
	room.template = RoomTemplate.from_dict(Db.templates_for("boss")[0])
	lvl.add_child(room)
	room._level = lvl
	var b: Boss = Boss.create(Db.bosses["ossifex"], room, 0)
	b.position = Level.to_world(Vector2i(10, 5))
	lvl.add_entity(b)
	await wait_physics_frames(2)
	watch_signals(b)
	_count(Events.boss_phase_changed)
	_count(Events.boss_killed)
	var maxhp: int = b.health.max_hp
	b.receive_hit(HitInfo.make(int(maxhp * 0.45), Vector2.ZERO, true, Vector2.ZERO))
	assert_eq(b.phase, 2, "phase 2 below 60%")
	assert_gt(_emitted("boss_phase_changed"), 0)
	assert_true(b.receive_hit(HitInfo.make(1, Vector2.ZERO, true, Vector2.ZERO)))
	var hp_during_transition: int = b.health.hp
	assert_eq(hp_during_transition, maxhp - int(maxhp * 0.45), "invulnerable while transitioning")
	await wait_seconds(1.6)
	b.receive_hit(HitInfo.make(int(maxhp * 0.3), Vector2.ZERO, true, Vector2.ZERO))
	assert_eq(b.phase, 3, "phase 3 below 30%")
	await wait_seconds(1.6)
	# Let it attack a little in phase 3 to exercise the patterns.
	await wait_seconds(2.0)
	b.receive_hit(HitInfo.make(maxhp, Vector2.ZERO, true, Vector2.ZERO))
	assert_false(b.is_alive())
	assert_signal_emitted(b, "defeated")
	assert_gt(_emitted("boss_killed"), 0)
	Sfx.stop_music()
