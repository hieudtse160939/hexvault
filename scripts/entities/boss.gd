class_name Boss
extends CharacterBody2D
## Ossifex, the Clockwork Lich. Three phases, every attack telegraphed and dodgeable:
##  P1: gear burst rings (gapped), aimed fan volleys, telegraphed hand slams.
##  P2 (<=60%): adds spiral barrage, telegraphed charge, summons minions.
##  P3 (<=30%): enraged visuals, faster cadence, telegraphed laser sweep.
## Phase transitions grant brief invulnerability and clear the arena of bullets.

signal defeated

enum A { IDLE, ATTACK, TRANSITION, DEAD }

var def: Dictionary = {}
var room: Room
var difficulty: int = 0
var health: Health
var hurtbox: Hurtbox
var sprite: AnimatedSprite2D
var phase: int = 1
var state: int = A.IDLE
var display_name: String = "Ossifex"

var _mat: ShaderMaterial
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _idle_left: float = 1.0
var _move_target: Vector2 = Vector2.ZERO
var _move_t: float = 0.0
var _contact_cd: float = 0.0
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_left: float = 0.0
var _last_attack: String = ""
var _laser: Line2D = null


static func create(d: Dictionary, r: Room, diff: int) -> Boss:
	var b: Boss = Boss.new()
	b.def = d
	b.room = r
	b.difficulty = diff
	b._rng.seed = hash([r.room_id, r.floor_index, "boss"])
	return b


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	display_name = str(def.get("name", "Ossifex"))
	collision_layer = 1 << 2
	collision_mask = Level.WORLD_MASK
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 10.0
	cs.shape = shape
	cs.position = Vector2(0, 10)
	add_child(cs)
	var sh: Sprite2D = Sprite2D.new()
	SpriteLib.apply(sh, "prop_shadow_l")
	sh.position = Vector2(0, 24)
	sh.z_index = -1
	add_child(sh)
	sprite = AnimatedSprite2D.new()
	SpriteLib.apply(sprite, "enemy_ossifex")
	sprite.play(&"idle")
	_mat = FX.make_flashable(sprite)
	add_child(sprite)
	health = Health.new()
	add_child(health)
	var hp: int = int(round(int(def.get("hp", 500)) * (1.0 + 0.5 * difficulty)))
	health.setup(hp, 0, 0.0)
	health.died.connect(_on_died)
	hurtbox = Hurtbox.create(self, 14.0, false)
	hurtbox.position = Vector2(0, 2)
	add_child(hurtbox)
	_move_target = global_position
	_emit_health()


func is_alive() -> bool:
	return state != A.DEAD


func _player() -> Player:
	var lvl: Level = Level.current
	if lvl == null or lvl.player == null or not lvl.player.is_alive():
		return null
	return lvl.player


func _emit_health() -> void:
	Events.boss_health_changed.emit(health.hp, health.max_hp, display_name)


func _physics_process(delta: float) -> void:
	if state == A.DEAD:
		return
	_contact_cd -= delta
	var p: Player = _player()
	if _charge_left > 0.0:
		_charge_left -= delta
		velocity = _charge_dir * 190.0
		if move_and_slide():
			_charge_left = 0.0
			FX.shake(5.0)
			_ring(12 + phase * 2, 65.0, 0.0)
	else:
		_drift(delta, p)
	if p != null and _contact_cd <= 0.0 and global_position.distance_to(p.global_position) < 18.0:
		if p.receive_hit(HitInfo.make(2, (p.global_position - global_position).normalized() * 160.0, false, global_position)):
			_contact_cd = 1.0
	if state == A.IDLE:
		_idle_left -= delta
		if _idle_left <= 0.0 and p != null:
			_choose_attack(p)
	if p != null:
		sprite.flip_h = p.global_position.x < global_position.x


func _drift(delta: float, p: Player) -> void:
	_move_t -= delta
	if _move_t <= 0.0:
		_move_t = _rng.randf_range(1.5, 2.5)
		var c: Vector2 = room.center_world()
		var pick: Vector2 = c + Vector2(_rng.randf_range(-90, 90), _rng.randf_range(-60, 40))
		if p != null and pick.distance_to(p.global_position) < 70.0:
			pick = c + (c - p.global_position).normalized() * 50.0
		_move_target = pick
	var speed: float = float(def.get("speed", 28)) * (1.0 + 0.25 * (phase - 1))
	var v: Vector2 = (_move_target - global_position)
	velocity = v.normalized() * minf(speed, v.length() * 2.0) if state != A.TRANSITION else Vector2.ZERO
	move_and_slide()


func _anim(base: String) -> StringName:
	if phase >= 3 and sprite.sprite_frames.has_animation(base + "2"):
		return StringName(base + "2")
	return StringName(base)


func _cadence() -> float:
	return [0.0, 1.3, 1.0, 0.75][phase]


func _choose_attack(p: Player) -> void:
	var options: Array[String] = ["burst", "volley", "slam"]
	if phase >= 2:
		options.append_array(["spiral", "charge", "summon"])
	if phase >= 3:
		options.append_array(["laser", "laser"])
	options.erase(_last_attack)
	var pick: String = options[_rng.randi_range(0, options.size() - 1)]
	_last_attack = pick
	state = A.ATTACK
	match pick:
		"burst":
			_attack_burst()
		"volley":
			_attack_volley(p)
		"slam":
			_attack_slam(p)
		"spiral":
			_attack_spiral()
		"charge":
			_attack_charge(p)
		"summon":
			_attack_summon()
		"laser":
			_attack_laser(p)


func _done(extra: float = 0.0) -> void:
	if state == A.DEAD or state == A.TRANSITION:
		return
	state = A.IDLE
	_idle_left = _cadence() + extra
	sprite.play(_anim("idle"))


func _wait(t: float) -> Signal:
	return get_tree().create_timer(t, false).timeout


# --- bullets ------------------------------------------------------------------------
func _shoot(dir: Vector2, speed: float, key: String = "orb_red", from: Vector2 = Vector2.INF) -> void:
	var lvl: Level = Level.current
	if lvl == null or state == A.DEAD:
		return
	var pr: Projectile = lvl.pool.acquire()
	pr.from_player = false
	pr.damage = 1 + (1 if difficulty > 0 else 0)
	pr.knockback = 70.0
	pr.range_left = 420.0
	pr.radius = 2.5
	pr.impact_fx = "impact_red"
	var origin: Vector2 = (global_position + Vector2(0, 2)) if from == Vector2.INF else from
	lvl.pool.launch(pr, origin + dir * 10.0, dir * speed, "proj_" + key)


func _ring(n: int, speed: float, offset: float) -> void:
	for i: int in n:
		_shoot(Vector2.from_angle(offset + i * TAU / n), speed, "orb_red")


# --- attacks ------------------------------------------------------------------------
func _attack_burst() -> void:
	sprite.play(_anim("cast"))
	Sfx.play("telegraph", -4.0)
	await _wait(0.5)
	var rings: int = 2 + (1 if phase >= 3 else 0)
	for r: int in rings:
		if state == A.DEAD:
			return
		_ring(14 + phase * 2, 62.0 + phase * 6.0, r * 0.2)
		Sfx.play("magic", -4.0)
		await _wait(0.45)
	_done()


func _attack_volley(p: Player) -> void:
	sprite.play(_anim("cast"))
	await _wait(0.4)
	for k: int in 3 + phase - 1:
		if state == A.DEAD:
			return
		var target: Player = _player()
		if target == null:
			break
		var dir: Vector2 = (target.global_position - global_position).normalized()
		for i: int in 5:
			_shoot(dir.rotated((i - 2) * deg_to_rad(11.0)), 105.0, "orb_amber")
		Sfx.play("shoot_shotgun", -6.0)
		await _wait(0.42 - phase * 0.05)
	_done()


func _attack_slam(p: Player) -> void:
	sprite.play(&"slam")
	var targets: Array[Vector2] = [p.global_position]
	for i: int in phase:
		targets.append(room.center_world() + Vector2(_rng.randf_range(-100, 100), _rng.randf_range(-70, 60)))
	for t: Vector2 in targets:
		Telegraph.circle(t, 24.0, 0.95, func(at: Vector2) -> void:
			FX.burst("explosion", at)
			FX.shake(3.0)
			Sfx.play("explosion", -4.0)
			var pl: Player = _player()
			if pl != null and pl.global_position.distance_to(at) < 24.0:
				pl.receive_hit(HitInfo.make(2, (pl.global_position - at).normalized() * 180.0, false, at))
			if phase >= 2:
				for k: int in 6:
					_shoot(Vector2.from_angle(k * TAU / 6.0), 70.0, "orb_red", at))
	Sfx.play("telegraph")
	await _wait(1.3)
	_done()


func _attack_spiral() -> void:
	sprite.play(_anim("cast"))
	await _wait(0.4)
	var arms: int = 3 if phase < 3 else 4
	var t: float = 0.0
	var ang: float = _rng.randf() * TAU
	while t < 2.6 and state == A.ATTACK:
		for a: int in arms:
			_shoot(Vector2.from_angle(ang + a * TAU / arms), 70.0, "orb_vio")
		ang += 0.28
		t += 0.13
		await _wait(0.13)
	_done(0.3)


func _attack_charge(p: Player) -> void:
	sprite.play(&"slam")
	_charge_dir = (p.global_position - global_position).normalized()
	var line: Line2D = Line2D.new()
	line.width = 3.0
	line.default_color = Color(1, 0.25, 0.3, 0.5)
	line.points = PackedVector2Array([Vector2.ZERO, _charge_dir * 260.0])
	add_child(line)
	Sfx.play("telegraph")
	await _wait(0.85)
	line.queue_free()
	if state != A.ATTACK:
		return
	_charge_left = 0.9
	Sfx.play("dash")
	await _wait(1.0)
	_done()


func _attack_summon() -> void:
	sprite.play(_anim("cast"))
	var minions: int = get_tree().get_nodes_in_group("enemies").size() - 1
	if minions >= 4:
		_done(-0.5)
		return
	for i: int in 2 + (1 if phase >= 3 else 0):
		var id: String = "skitter" if _rng.randf() < 0.5 else "gloop"
		var pos: Vector2 = room.center_world() + Vector2(_rng.randf_range(-80, 80), _rng.randf_range(-50, 50))
		var lvl: Level = Level.current
		if lvl != null and lvl.is_walkable(Level.to_tile(pos)):
			room.spawn_enemy(Db.enemy(id), false, pos, 0.8)
	await _wait(1.0)
	_done()


func _attack_laser(p: Player) -> void:
	sprite.play(_anim("cast"))
	var start_ang: float = (p.global_position - global_position).angle() - deg_to_rad(55.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var sweep: float = deg_to_rad(110.0) * (1.0 if start_ang < (p.global_position - global_position).angle() else -1.0)
	_laser = Line2D.new()
	_laser.width = 1.0
	_laser.default_color = Color(1, 0.3, 0.35, 0.6)
	add_child(_laser)
	_laser.points = PackedVector2Array([Vector2.ZERO, Vector2.from_angle(start_ang) * 300.0])
	Sfx.play("telegraph")
	# Telegraph: thin blinking line along the starting angle for 0.9 s.
	var t: float = 0.0
	while t < 0.9 and state == A.ATTACK:
		_laser.modulate.a = 0.4 + 0.6 * sin(t * 30.0)
		t += 0.05
		await _wait(0.05)
	if state != A.ATTACK:
		return
	_laser.width = 5.0
	_laser.default_color = Color("#ff9aa2")
	_laser.modulate.a = 1.0
	Sfx.play("laser")
	t = 0.0
	var dur: float = 1.6
	var hit_cd: float = 0.0
	while t < dur and state == A.ATTACK:
		var ang: float = start_ang + sweep * (t / dur)
		var dir: Vector2 = Vector2.from_angle(ang)
		var end: Vector2 = Combat.hitscan(global_position, dir, 300.0, 0, HitInfo.make(0, Vector2.ZERO, false, global_position))
		_laser.points = PackedVector2Array([Vector2.ZERO, end - global_position])
		var pl: Player = _player()
		hit_cd -= 0.04
		if pl != null and hit_cd <= 0.0 and Geometry2D.get_closest_point_to_segment(pl.global_position, global_position, end).distance_to(pl.global_position) < 6.0:
			if pl.receive_hit(HitInfo.make(2, dir.orthogonal() * 120.0, false, global_position)):
				hit_cd = 0.5
		t += 0.04
		await _wait(0.04)
	if _laser != null:
		_laser.queue_free()
		_laser = null
	_done(0.3)


# --- damage / phases -------------------------------------------------------------------
func receive_hit(info: HitInfo) -> bool:
	if state == A.DEAD or not info.from_player:
		return false
	if state == A.TRANSITION:
		FX.burst("impact_teal", global_position)
		return true # absorbs the shot but takes no damage
	health.take(info)
	FX.flash(sprite)
	FX.damage_number(global_position + Vector2(0, -10), info.damage, info.crit)
	Sfx.play("crit" if info.crit else "hit", -4.0)
	_emit_health()
	_check_phase()
	return true


func _check_phase() -> void:
	var phases: Array = def.get("phases", [1.0, 0.6, 0.3])
	var r: float = health.ratio()
	var want: int = 1
	for i: int in phases.size():
		if r <= float(phases[i]):
			want = i + 1
	if want > phase and state != A.DEAD:
		_enter_phase(want)


func _enter_phase(p: int) -> void:
	phase = p
	state = A.TRANSITION
	_charge_left = 0.0
	if _laser != null:
		_laser.queue_free()
		_laser = null
	Events.boss_phase_changed.emit(phase)
	sprite.play(&"phase")
	Sfx.play("boss_phase")
	FX.shake(8.0)
	FX.hit_stop(0.12)
	var lvl: Level = Level.current
	if lvl != null:
		lvl.pool.erase_hostile_in(global_position, 600.0)
	FX.float_text(global_position + Vector2(0, -26), "PHASE %d" % phase, UiTheme.RED)
	await _wait(1.4)
	if state == A.DEAD:
		return
	state = A.IDLE
	_idle_left = 0.6
	sprite.play(_anim("idle"))


func _on_died() -> void:
	state = A.DEAD
	_charge_left = 0.0
	if _laser != null:
		_laser.queue_free()
	collision_layer = 0
	hurtbox.collision_layer = 0
	remove_from_group("enemies")
	Events.boss_health_changed.emit(0, health.max_hp, display_name)
	var lvl: Level = Level.current
	if lvl != null:
		lvl.pool.erase_hostile_in(global_position, 800.0)
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			if e is Enemy:
				(e as Enemy).health.take(HitInfo.make(9999, Vector2.ZERO, true, global_position))
	sprite.play(&"death")
	Sfx.play("boss_roar")
	FX.shake(10.0)
	FX.hit_stop(0.25)
	for i: int in 6:
		get_tree().create_timer(i * 0.18, false).timeout.connect(func() -> void:
			FX.burst("explosion", global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))))
	Events.boss_killed.emit(str(def.get("id", "ossifex")))
	Events.enemy_killed.emit(self, true)
	defeated.emit()
	Sfx.play_music("dungeon")
