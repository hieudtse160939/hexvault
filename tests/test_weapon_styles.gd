extends "res://tests/test_case.gd"
## Weapon-aware attacks: style profiles, windup -> release -> recovery timing,
## emission point, magic vs gunfire, facing, interruption, class weapon rules
## and weapon-specific talents.

var _saved: Dictionary
var _auto: bool


func before_each() -> void:
	_auto = Profile.autosave
	_saved = Profile.data.duplicate(true)
	Profile.autosave = false
	Profile.data = SaveManager.profile_defaults()
	Game.run = RunState.new()
	Game.god_mode = false


func after_each() -> void:
	Profile.data = _saved
	Profile.autosave = _auto
	Game.run = null
	Engine.time_scale = 1.0


func _arena() -> Level:
	var lvl: Level = Level.new()
	for y: int in 12:
		for x: int in 20:
			lvl.floor_tiles[Vector2i(x, y)] = true
	add_child_autofree(lvl)
	LevelBuilder.paint(lvl, {}, {}, false)
	lvl.build_nav()
	return lvl


func _armed(lvl: Level, weapon: String, hero: String = "duelist") -> Player:
	Game.run.weapons = [weapon]
	var p: Player = Player.create(Db.character(hero))
	p.position = Level.to_world(Vector2i(6, 5))
	lvl.player = p
	lvl.add_entity(p)
	p.load_run_weapons(Game.run)
	p.input_enabled = false
	return p


func _target(lvl: Level, tile: Vector2i = Vector2i(8, 5)) -> Enemy:
	var e: Enemy = Enemy.create(Db.enemy("golem"), false, 1, 0, 7)
	e.position = Level.to_world(tile)
	lvl.add_entity(e)
	return e


func test_every_weapon_has_a_style_profile() -> void:
	var seen: Dictionary = {}
	for id: String in Db.weapon_order:
		var w: WeaponData = Db.weapon(id)
		assert_true(Db.weapon_styles.has(w.style), "%s style %s" % [id, w.style])
		seen[w.style] = true
	for st: String in ["gun", "bow", "staff", "wand", "orb", "sword", "dagger", "spear", "heavy"]:
		assert_true(seen.has(st), "a weapon uses style %s" % st)
		var prof: Dictionary = Db.weapon_styles[st]
		if bool(prof.get("magic", false)):
			assert_ne(str(prof["release_fx"]), "muzzle", "%s is magic: no gun muzzle flash" % st)
			assert_ne(str(prof["motion"]), "recoil", "%s is magic: no gun recoil" % st)
	assert_eq(Db.weapon("hex_staff").style, "staff")
	assert_eq(Db.weapon("ember_blade").style, "sword")
	assert_eq(Db.weapon("thornbow").style, "bow")
	assert_eq(Db.weapon("shadow_fang").style, "dagger")


func test_staff_casts_from_the_tip_after_a_windup() -> void:
	var lvl: Level = _arena()
	var p: Player = _armed(lvl, "hex_staff", "pyromancer")
	await wait_physics_frames(2)
	var w: Weapon = p.current_weapon()
	assert_true(w.is_magic())
	assert_true(w.try_fire(Vector2.RIGHT))
	assert_eq(w.phase, Weapon.Phase.WINDUP, "staff starts by charging")
	assert_eq(lvl.pool.active_count(), 0, "no spell before the cast")
	await wait_physics_frames(3)
	assert_eq(p.body.animation, &"skill", "casting pose while charging")
	assert_almost_eq(w._kick, 0.0, 0.001, "no recoil on a staff")
	assert_true(await wait_until(func() -> bool: return w.attacks == 1, 1.0), "spell released")
	assert_eq(lvl.pool.active_count(), 1, "exactly one projectile")
	var proj: Node2D = null
	for c: Node in lvl.pool.get_children():
		if c is Projectile and (c as Node2D).visible:
			proj = c
	assert_not_null(proj)
	var tip: Vector2 = w.muzzle_position()
	assert_lt(proj.global_position.distance_to(tip), 14.0, "spell leaves from the staff tip")
	assert_gt(tip.x, p.global_position.x + 10.0, "tip is in front of the caster")
	assert_true(await wait_until(func() -> bool: return w.phase == Weapon.Phase.READY, 1.0), "recovers to ready")


func test_sword_hits_once_at_contact_not_on_press() -> void:
	var lvl: Level = _arena()
	var p: Player = _armed(lvl, "ember_blade")
	var e: Enemy = _target(lvl, Vector2i(7, 5))
	await wait_physics_frames(2)
	e.set_physics_process(false)
	var hits: Array = [0]
	e.health.damaged.connect(func(_a: int, _i: HitInfo) -> void: hits[0] += 1)
	var w: Weapon = p.current_weapon()
	var hp0: int = e.health.hp
	assert_true(w.try_fire(Vector2.RIGHT))
	assert_eq(e.health.hp, hp0, "no damage at button press (windup)")
	assert_true(await wait_until(func() -> bool: return hits[0] > 0, 1.0), "swing connects")
	await wait_seconds(0.4)
	assert_eq(hits[0], 1, "one swing = one hit")


func test_holding_the_button_does_not_restart_attacks() -> void:
	var lvl: Level = _arena()
	var p: Player = _armed(lvl, "sunforge_mace", "warden")
	await wait_physics_frames(2)
	var w: Weapon = p.current_weapon()
	var started: int = 0
	for i: int in 12:
		if w.try_fire(Vector2.RIGHT):
			started += 1
		await wait_physics_frames(1)
	assert_eq(started, 1, "one heavy attack in 0.2 s of holding")


func test_swap_interrupts_safely() -> void:
	var lvl: Level = _arena()
	Game.run.weapons = ["sunforge_mace", "rift_pistol"]
	var p: Player = Player.create(Db.character("warden"))
	p.position = Level.to_world(Vector2i(6, 5))
	lvl.player = p
	lvl.add_entity(p)
	p.load_run_weapons(Game.run)
	p.input_enabled = false
	var e: Enemy = _target(lvl, Vector2i(7, 5))
	await wait_physics_frames(2)
	e.set_physics_process(false)
	var hp0: int = e.health.hp
	var mace: Weapon = p.current_weapon()
	mace.try_fire(Vector2.RIGHT)
	p.swap_weapon()
	assert_eq(mace.phase, Weapon.Phase.READY)
	await wait_seconds(0.6)
	assert_eq(e.health.hp, hp0, "interrupted swing never lands")
	assert_eq(mace.attacks, 0)


func test_facing_left_emits_to_the_left() -> void:
	var lvl: Level = _arena()
	var p: Player = _armed(lvl, "cinder_wand", "pyromancer")
	await wait_physics_frames(2)
	var w: Weapon = p.current_weapon()
	w.try_fire(Vector2.LEFT)
	assert_true(await wait_until(func() -> bool: return w.attacks == 1, 1.0))
	assert_lt(w.muzzle_position().x, p.global_position.x - 4.0, "spell point on the left side")
	for c: Node in lvl.pool.get_children():
		if c is Projectile and (c as Node2D).visible:
			assert_lt((c as Projectile).velocity.x, 0.0, "projectile flies left")


func test_bow_shows_draw_then_release_frames() -> void:
	var lvl: Level = _arena()
	var p: Player = _armed(lvl, "thornbow", "assassin")
	await wait_physics_frames(2)
	var w: Weapon = p.current_weapon()
	var frames: SpriteFrames = SpriteLib.frames("weapon_thornbow")
	assert_true(frames.has_animation("draw") and frames.has_animation("release"), "bow has real draw/release frames")
	var spr: Sprite2D = w.get("_sprite")
	w.try_fire(Vector2.RIGHT)
	await wait_frames(2)
	var draw_tex: Array = []
	for i: int in frames.get_frame_count("draw"):
		draw_tex.append(frames.get_frame_texture("draw", i))
	assert_has(draw_tex, spr.texture, "drawing the string")
	assert_true(await wait_until(func() -> bool: return w.phase == Weapon.Phase.RECOVER, 1.0))
	await wait_frames(1)
	assert_eq(spr.texture, frames.get_frame_texture("release", 0), "string released, arrow gone")


func test_class_weapon_rules() -> void:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	var sword: String = Inventory.add(Profile.data, ItemGen.generate("w_ember_blade", 1, "common", r))
	var staff: String = Inventory.add(Profile.data, ItemGen.generate("w_hex_staff", 3, "rare", r))
	var helm: String = Inventory.add(Profile.data, ItemGen.generate("h_leather_cap", 1, "common", r))
	assert_false(Inventory.equip(Profile.data, "necromancer", sword), "necromancer cannot wield a sword")
	assert_true(Inventory.equip(Profile.data, "necromancer", staff))
	assert_true(Inventory.equip(Profile.data, "necromancer", helm), "armour has no class rule")
	for hid: String in Db.roster:
		var w: WeaponData = Db.weapon(Db.character(hid).start_weapon)
		var allowed: PackedStringArray = Db.allowed_styles(hid)
		assert_true(allowed.is_empty() or w.style in allowed, "%s can use its own start weapon" % hid)


func test_weapon_talents_only_with_matching_weapon() -> void:
	var rec: Dictionary = Profile.character_record("duelist")
	rec["tree"] = {"duelist_w0": 3}
	var with_sword: Dictionary = HeroStats.for_hero(Profile.data, "duelist", "sword")
	var with_gun: Dictionary = HeroStats.for_hero(Profile.data, "duelist", "gun")
	assert_almost_eq(float(with_sword["attack_speed"]) - float(with_gun["attack_speed"]), 0.15, 0.0001, "Blade Rhythm counts with a sword only")
	var lvl: Level = _arena()
	Game.run.weapons = ["ember_blade", "rift_pistol"]
	var p: Player = Player.create(Db.character("duelist"))
	p.position = Level.to_world(Vector2i(6, 5))
	lvl.player = p
	lvl.add_entity(p)
	p.load_run_weapons(Game.run)
	await wait_physics_frames(1)
	var fr_sword: float = p.weapon_mod("fire_rate_mult")
	p.swap_weapon()
	assert_almost_eq(fr_sword - p.weapon_mod("fire_rate_mult"), 0.15, 0.0001, "swapping to a gun drops the sword talent")
