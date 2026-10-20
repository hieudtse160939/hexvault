extends "res://tests/test_case.gd"
## Character framework: data validity for every hero, skill/passive modules
## running in a live arena, mastery progression and the v2->v3 save migration.
## Adding a hero to data/characters.json automatically puts it under these tests.

var _saved_autosave: bool
var _saved_data: Dictionary


func before_each() -> void:
	_saved_autosave = Profile.autosave
	_saved_data = Profile.data.duplicate(true)
	Profile.autosave = false
	Game.run = RunState.new()
	Game.god_mode = false


func after_each() -> void:
	Profile.data = _saved_data
	Profile.autosave = _saved_autosave
	Game.run = null


func _arena() -> Level:
	var lvl: Level = Level.new()
	for y: int in 14:
		for x: int in 24:
			lvl.floor_tiles[Vector2i(x, y)] = true
	add_child_autofree(lvl)
	LevelBuilder.paint(lvl, {}, {}, false)
	lvl.build_nav()
	return lvl


func _spawn(lvl: Level, id: String, tile: Vector2i) -> Player:
	var c: CharacterData = Db.character(id)
	Game.run.character_id = id
	Game.run.weapons = [c.start_weapon]
	var p: Player = Player.create(c)
	p.position = Level.to_world(tile)
	lvl.player = p
	lvl.add_entity(p)
	p.load_run_weapons(Game.run)
	p.input_enabled = false
	return p


func test_every_character_is_valid() -> void:
	assert_gt(Db.character_order.size(), 0, "characters loaded")
	for id: String in Db.character_order:
		var c: CharacterData = Db.character(id)
		assert_eq(Array(c.validate()), [], "%s: schema" % id)
		assert_eq(Array(Db.character_problems(c)), [], "%s: references" % id)
		assert_true(Db.classes.has(c.class_id), "%s: class exists" % id)


func test_ids_unique_and_classes_used() -> void:
	var seen: Dictionary = {}
	for id: String in Db.character_order:
		assert_false(seen.has(id), "duplicate id " + id)
		seen[id] = true
	for cid: String in Db.class_order:
		assert_true((Db.classes[cid] as ClassData).archetype != "", "class %s has an archetype" % cid)


func test_legacy_flat_character_entry_still_parses() -> void:
	var c: CharacterData = CharacterData.from_dict({"id": "old", "name": "Old", "max_hp": 7, "speed": 90,
		"skill": "overclock", "skill_cooldown": 9.0, "skill_duration": 2.0, "skill_icon": "icon_skill_overclock"})
	assert_eq(c.max_hp, 7)
	assert_eq(c.skill, "overclock")
	assert_almost_eq(c.skill_cooldown, 9.0)
	assert_almost_eq(c.skill_duration, 2.0)


func test_every_skill_and_passive_runs_in_an_arena() -> void:
	var lvl: Level = _arena()
	for id: String in Db.character_order:
		var p: Player = _spawn(lvl, id, Vector2i(6, 6))
		var e: Enemy = Enemy.create(Db.enemy("golem"), false, 1, 0, 3)
		e.position = Level.to_world(Vector2i(12, 6))
		e.aggro = true
		lvl.add_entity(e)
		await wait_physics_frames(3)
		assert_not_null(p.skill, "%s: skill module" % id)
		assert_not_null(p.passive, "%s: passive module" % id)
		assert_eq((p.skill.get_script() as Script).resource_path, CharacterModules.skill_path(p.character.skill), "%s: skill script" % id)
		assert_true(p.try_skill(), "%s: skill activates" % id)
		assert_gt(p.skill_cd_left, 0.0, "%s: cooldown started" % id)
		assert_false(p.try_skill(), "%s: cannot recast during cooldown" % id)
		# run through the whole active duration plus a margin
		var frames: int = int(ceil((p.character.skill_duration + 0.3) * 60.0))
		await wait_physics_frames(mini(frames, 900))
		assert_almost_eq(p.skill_active_left, 0.0, 0.001, "%s: skill ended" % id)
		assert_false(p.skill.keeps_invulnerable(), "%s: no lingering invulnerability" % id)
		# passive hooks must be callable for every hero
		p.passive.on_room_entered()
		p.passive.on_dash()
		p.on_enemy_killed(e if is_instance_valid(e) else null)
		p.passive.on_room_cleared()
		assert_true(p.is_alive(), "%s: survived its own skill" % id)
		if is_instance_valid(e):
			e.queue_free()
		p.queue_free()
		await wait_physics_frames(2)
		for n: Node in lvl.entities.get_children():
			if n is Turret or n is Enemy:
				n.queue_free()
		lvl.pool.clear_all()
		await wait_physics_frames(1)


func test_skill_cooldown_reduction_applies() -> void:
	var lvl: Level = _arena()
	var p: Player = _spawn(lvl, "ranger", Vector2i(5, 5))
	await wait_physics_frames(2)
	var base: float = p.skill_cooldown_total()
	p._mods["cooldown_mult"] = -0.5
	assert_almost_eq(p.skill_cooldown_total(), base * 0.5, 0.001)
	p._mods["cooldown_mult"] = -5.0
	assert_almost_eq(p.skill_cooldown_total(), base * 0.35, 0.001, "floored at 35 %")


func test_mastery_levels_from_run_xp() -> void:
	Profile.data["characters"] = {}
	assert_eq(Profile.mastery_level("ranger"), 1)
	var lost: Dictionary = {"victory": false, "floor": 2, "rooms": 10, "character": "ranger", "shards": 0}
	Profile.bank_run(lost)    # 2*20 + 10*4 = 80 xp
	assert_eq(int(Profile.character_record("ranger")["xp"]), 80)
	assert_eq(Profile.mastery_level("ranger"), 1)
	var won: Dictionary = {"victory": true, "floor": 3, "rooms": 20, "character": "ranger", "shards": 0}
	Profile.bank_run(won)     # +60 +80 +60 = 200 -> 280 xp
	assert_eq(Profile.mastery_level("ranger"), 2)
	assert_almost_eq(float(Profile.mastery_bonus("ranger").get("crit", 0.0)), 0.03, 0.0001)
	assert_eq(int(Profile.character_record("ranger")["wins"]), 1)
	assert_eq(Profile.mastery_next_xp("ranger"), 300)


func test_mastery_bonus_reaches_player_stats() -> void:
	Profile.data["characters"] = {"warden": {"xp": 400, "runs": 3, "wins": 0, "best_floor": 2}}
	var lvl: Level = _arena()
	var p: Player = _spawn(lvl, "warden", Vector2i(5, 5))
	await wait_physics_frames(2)
	assert_eq(Profile.mastery_level("warden"), 3)
	assert_eq(p.health.max_hp, Db.character("warden").max_hp + 1 + int(Profile.upgrade_bonus("max_hp")), "level 2 +1 HP")


func test_profile_v2_migrates_to_character_records() -> void:
	var v2: Dictionary = {"shards": 50, "unlocked_characters": ["ranger", "tinker"], "selected_character": "tinker"}
	var out: Dictionary = SaveManager.migrate_profile_v2(v2)
	assert_true(out.has("characters"))
	assert_has(out["characters"], "tinker")
	assert_eq(int((out["characters"] as Dictionary)["tinker"]["xp"]), 0)
	assert_eq(int(out["shards"]), 50, "nothing else lost")


func test_stonehide_blocks_first_hit_per_room() -> void:
	var lvl: Level = _arena()
	var p: Player = _spawn(lvl, "warden", Vector2i(5, 5))
	await wait_physics_frames(2)
	var hp: int = p.health.hp + p.health.armor
	assert_false(p.receive_hit(HitInfo.make(2, Vector2.ZERO, false, Vector2.ZERO)), "first hit blocked")
	assert_eq(p.health.hp + p.health.armor, hp)
	p.health.invulnerable = false
	p._invuln_left = 0.0
	await wait_physics_frames(1)
	assert_true(p.receive_hit(HitInfo.make(2, Vector2.ZERO, false, Vector2.ZERO)), "second hit lands")
	p.passive.on_room_entered()
	p.health.invulnerable = false
	await wait_seconds(0.9)
	assert_false(p.receive_hit(HitInfo.make(1, Vector2.ZERO, false, Vector2.ZERO)), "recharged in a new room")
