class_name Enemy
extends CharacterBody2D
## Data-driven enemy with a finite-state machine. One class covers every
## archetype; `data.behavior` selects the chase/attack logic.
##
## IDLE -> (sees player) -> CHASE -> (in range, cooldown ready) -> WINDUP
##   -> ATTACK -> RECOVER -> CHASE ...      any -> STAGGER (heavy hit) -> CHASE
## ranged/summoner may RETREAT when the player is too close. HP 0 -> DEAD.

signal died(enemy: Enemy)

enum S { IDLE, WANDER, CHASE, WINDUP, ATTACK, RECOVER, RETREAT, STAGGER, DEAD }

const REPATH_TIME: float = 0.4
const CONTACT_COOLDOWN: float = 0.7

var data: EnemyData
var elite: bool = false
var floor_index: int = 1
var difficulty: int = 0
var state: int = S.IDLE
var health: Health
var status: StatusEffects
var hurtbox: Hurtbox
var sprite: AnimatedSprite2D
var aggro: bool = false   # set by the room when it activates
var damage: int = 1
var move_speed: float = 40.0

var _t: float = 0.0              # time in current state
var _attack_cd: float = 0.0
var _contact_cd: float = 0.0
var _path: PackedVector2Array = []
var _path_i: int = 0
var _repath: float = 0.0
var _knock: Vector2 = Vector2.ZERO
var _lunge_dir: Vector2 = Vector2.ZERO
var _strafe_sign: float = 1.0
var _wander_target: Vector2 = Vector2.ZERO
var _telegraph: Line2D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _summons: Array[Enemy] = []
var _mat: ShaderMaterial
var _think: float = 0.0


static func create(d: EnemyData, is_elite: bool, floor_i: int, diff: int, seed_value: int) -> Enemy:
	var e: Enemy = Enemy.new()
	e.data = d
	e.elite = is_elite
	e.floor_index = floor_i
	e.difficulty = diff
	e._rng.seed = seed_value
	return e


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 1 << 2
	collision_mask = Level.WORLD_MASK | Level.BREAKABLE_MASK
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var el: Dictionary = Db.elite
	var hp: int = Damage.enemy_hp(data.hp, floor_index, difficulty)
	damage = Damage.enemy_damage(data.damage, difficulty)
	move_speed = data.speed
	if elite:
		hp = int(hp * float(el.get("hp_mult", 2.5)))
		damage += int(el.get("damage_add", 1))
		move_speed *= float(el.get("speed_mult", 1.1))
		scale = Vector2.ONE * float(el.get("scale", 1.25))
	var cs: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = maxf(data.radius - 2.0, 3.0)
	cs.shape = shape
	cs.position = Vector2(0, 3)
	add_child(cs)
	var sh: Sprite2D = Sprite2D.new()
	sh.texture = SpriteLib.still("prop_" + data.shadow)
	sh.position = Vector2(0, data.radius + (6.0 if data.flying else 1.0))
	sh.z_index = -1
	add_child(sh)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteLib.frames(data.sprite)
	sprite.play(&"idle")
	_mat = FX.make_flashable(sprite)
	if elite:
		_mat.set_shader_parameter("tint", Color(1.15, 0.95, 0.75))
	add_child(sprite)
	health = Health.new()
	add_child(health)
	health.setup(hp, 0, 0.0)
	health.died.connect(_on_died)
	status = StatusEffects.new()
	add_child(status)
	status.tick_damage.connect(_on_burn)
	hurtbox = Hurtbox.create(self, data.radius, false)
	add_child(hurtbox)
	_attack_cd = _rng.randf_range(0.4, data.attack_cooldown)
	_strafe_sign = 1.0 if _rng.randf() < 0.5 else -1.0
	_think = _rng.randf_range(0.0, 0.1)
	_repath = _rng.randf_range(0.0, REPATH_TIME)
	if elite:
		var label: Label = UiTheme.label("ELITE", UiTheme.GOLD, true)
		label.add_theme_font_override("font", SpriteLib.font())
		label.position = Vector2(-12, -data.radius - 18)
		label.scale = Vector2.ONE / scale
		add_child(label)


func is_alive() -> bool:
	return state != S.DEAD


func _player() -> Player:
	var lvl: Level = Level.current
	if lvl == null or lvl.player == null or not is_instance_valid(lvl.player) or not lvl.player.is_alive():
		return null
	return lvl.player


func _set_state(s: int) -> void:
	state = s
	_t = 0.0
	if _telegraph != null and s != S.WINDUP:
		_telegraph.queue_free()
		_telegraph = null


func _physics_process(delta: float) -> void:
	if state == S.DEAD:
		return
	_t += delta
	_attack_cd -= delta
	_contact_cd -= delta
	_repath -= delta
	var p: Player = _player()
	var slow: float = status.speed_mult()
	var desired: Vector2 = Vector2.ZERO
	match state:
		S.IDLE, S.WANDER:
			desired = _do_idle(p, delta)
		S.CHASE:
			desired = _do_chase(p, delta)
		S.RETREAT:
			desired = _do_retreat(p)
		S.WINDUP:
			_do_windup(p)
		S.ATTACK:
			desired = _do_attack(p, delta)
		S.RECOVER:
			if _t > _recover_time():
				_set_state(S.CHASE)
		S.STAGGER:
			if _t > 0.18:
				_set_state(S.CHASE)
	if state == S.ATTACK and _lunge_dir != Vector2.ZERO:
		velocity = desired # lunges ignore slow-down smoothing
	else:
		velocity = velocity.move_toward(desired * slow, 600.0 * delta)
	velocity += _separation() + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 500.0 * delta)
	var collided: bool = move_and_slide()
	if collided and state == S.ATTACK and data.behavior == "tank":
		_charge_impact()
	_contact_damage(p)
	_animate(p)
	_mat.set_shader_parameter("tint", status.tint() * (Color(1.15, 0.95, 0.75) if elite else Color.WHITE))


# --- states -------------------------------------------------------------------------
func _do_idle(p: Player, _delta: float) -> Vector2:
	if p != null and (aggro or global_position.distance_to(p.global_position) < data.detect_range * 0.6):
		if aggro or Level.current.line_clear(global_position, p.global_position):
			_set_state(S.CHASE)
			return Vector2.ZERO
	if state == S.IDLE and _t > 1.2:
		_wander_target = global_position + Vector2.from_angle(_rng.randf() * TAU) * 24.0
		_set_state(S.WANDER)
	if state == S.WANDER:
		if _t > 1.0 or global_position.distance_to(_wander_target) < 4.0:
			_set_state(S.IDLE)
		return (_wander_target - global_position).normalized() * move_speed * 0.4
	return Vector2.ZERO


func _do_chase(p: Player, _delta: float) -> Vector2:
	if p == null:
		_set_state(S.IDLE)
		return Vector2.ZERO
	var to_p: Vector2 = p.global_position - global_position
	var dist: float = to_p.length()
	var lvl: Level = Level.current
	var los: bool = lvl.line_clear(global_position, p.global_position)
	match data.behavior:
		"ranged", "summoner":
			var keep: float = float(data.get_extra("keep_distance", 90.0))
			if dist < keep * 0.55:
				_set_state(S.RETREAT)
				return Vector2.ZERO
			if _attack_cd <= 0.0 and dist < data.attack_range and los:
				_begin_windup(p)
				return Vector2.ZERO
			if los and dist < keep * 1.3:
				# strafe around the player at the preferred distance
				var tangent: Vector2 = to_p.orthogonal().normalized() * _strafe_sign
				var radial: Vector2 = to_p.normalized() * clampf((dist - keep) / keep, -1.0, 1.0)
				if _rng.randf() < 0.005:
					_strafe_sign = -_strafe_sign
				return (tangent * 0.7 + radial).normalized() * move_speed
		"flanker":
			if _attack_cd <= 0.0 and dist < data.attack_range and los:
				_begin_windup(p)
				return Vector2.ZERO
			if los and dist < 110.0:
				var tangent2: Vector2 = to_p.orthogonal().normalized() * _strafe_sign
				var radial2: Vector2 = to_p.normalized() * clampf((dist - 55.0) / 55.0, -1.0, 1.0)
				return (tangent2 + radial2 * 0.8).normalized() * move_speed
		_:
			if _attack_cd <= 0.0 and dist < data.attack_range and los:
				_begin_windup(p)
				return Vector2.ZERO
	return _steer_to(p.global_position, los) * move_speed


func _do_retreat(p: Player) -> Vector2:
	if p == null or _t > 1.1:
		_set_state(S.CHASE)
		return Vector2.ZERO
	var away: Vector2 = (global_position - p.global_position).normalized()
	return away * move_speed * 1.1


func _begin_windup(p: Player) -> void:
	_set_state(S.WINDUP)
	_lunge_dir = (p.global_position - global_position).normalized()
	sprite.play(&"attack")
	if data.behavior in ["tank", "flanker"]:
		_telegraph = Line2D.new()
		_telegraph.width = 1.0
		_telegraph.default_color = Color(1.0, 0.3, 0.35, 0.7)
		_telegraph.points = PackedVector2Array([Vector2.ZERO, _lunge_dir * (110.0 if data.behavior == "tank" else 70.0)])
		_telegraph.top_level = true
		_telegraph.global_position = global_position
		add_child(_telegraph)
		if data.behavior == "tank":
			Sfx.play("telegraph", -6.0, 0.0)


func _windup_time() -> float:
	match data.behavior:
		"tank":
			return 0.75
		"ranged":
			return 0.5
		"summoner":
			return 0.8
		"flanker":
			return 0.35
	return 0.35


func _recover_time() -> float:
	match data.behavior:
		"tank":
			return 0.9
		"flanker":
			return 0.5
	return 0.45


func _do_windup(p: Player) -> void:
	if _telegraph != null:
		_telegraph.global_position = global_position
		_telegraph.modulate.a = 0.5 + 0.5 * sin(_t * 40.0)
	if p != null and data.behavior in ["ranged", "summoner", "chaser"]:
		_lunge_dir = (p.global_position - global_position).normalized()
		if _telegraph != null:
			_telegraph.points = PackedVector2Array([Vector2.ZERO, _lunge_dir * 60.0])
	if _t >= _windup_time():
		_set_state(S.ATTACK)
		_attack_cd = data.attack_cooldown * _rng.randf_range(0.85, 1.15)
		match data.behavior:
			"ranged":
				_fire_volley(p)
				_set_state(S.RECOVER)
			"summoner":
				_summon(p)
				_set_state(S.RECOVER)


func _do_attack(_p: Player, _delta: float) -> Vector2:
	match data.behavior:
		"chaser":
			if _t > 0.28:
				_lunge_end()
				return Vector2.ZERO
			return _lunge_dir * move_speed * 3.6
		"flanker":
			if _t > 0.3:
				_lunge_end()
				return Vector2.ZERO
			return _lunge_dir * float(data.get_extra("lunge_speed", 220.0))
		"tank":
			if _t > 0.65:
				_lunge_end()
				return Vector2.ZERO
			return _lunge_dir * float(data.get_extra("charge_speed", 200.0))
	_lunge_end()
	return Vector2.ZERO


func _lunge_end() -> void:
	_lunge_dir = Vector2.ZERO
	_set_state(S.RECOVER)
	if elite and data.behavior == "chaser" and _rng.randf() < 0.5:
		_attack_cd = 0.2 # elite gloops chain a second hop


func _charge_impact() -> void:
	FX.shake(3.0)
	Sfx.play("hit")
	if elite or floor_index >= 2:
		_ring(8, 70.0)
	_lunge_dir = Vector2.ZERO
	_set_state(S.STAGGER)
	_t = -0.6 # stunned briefly after slamming a wall


# --- attacks ------------------------------------------------------------------------
func _shoot(dir: Vector2, speed: float, sprite_key: String) -> void:
	var lvl: Level = Level.current
	if lvl == null:
		return
	var pr: Projectile = lvl.pool.acquire()
	pr.from_player = false
	pr.damage = damage
	pr.knockback = 60.0
	pr.range_left = 320.0
	pr.radius = 2.5
	pr.impact_fx = "impact_red"
	lvl.pool.launch(pr, global_position + dir * 6.0, dir * speed, "proj_" + sprite_key)


func _fire_volley(p: Player) -> void:
	if p == null:
		return
	var dir: Vector2 = (p.global_position - global_position).normalized()
	var spd: float = float(data.get_extra("projectile_speed", 90.0))
	var key: String = str(data.get_extra("projectile", "orb_red"))
	var n: int = int(data.get_extra("volley", 1)) + (2 if elite else 0)
	for i: int in n:
		var ang: float = (float(i) - (n - 1) / 2.0) * deg_to_rad(14.0)
		_shoot(dir.rotated(ang), spd, key)
	Sfx.play("magic", -8.0)


func _ring(n: int, speed: float) -> void:
	for i: int in n:
		_shoot(Vector2.from_angle(i * TAU / n), speed, "orb_red")


func _summon(p: Player) -> void:
	var lvl: Level = Level.current
	if lvl == null:
		return
	_summons = _summons.filter(func(e: Enemy) -> bool: return is_instance_valid(e) and e.is_alive())
	var cap: int = int(data.get_extra("summon_cap", 4)) + (2 if elite else 0)
	var count: int = mini(int(data.get_extra("summon_count", 2)) + (1 if elite else 0), cap - _summons.size())
	var sd: EnemyData = Db.enemy(str(data.get_extra("summon", "skitter")))
	if count <= 0 or sd == null:
		if p != null:
			_shoot((p.global_position - global_position).normalized(), float(data.get_extra("projectile_speed", 80.0)), str(data.get_extra("projectile", "orb_vio")))
		return
	Sfx.play("spawn", -4.0)
	var room: Room = lvl.room_at_world(global_position)
	for i: int in count:
		var off: Vector2 = Vector2.from_angle(_rng.randf() * TAU) * 18.0
		var tile: Vector2i = Level.to_tile(global_position + off)
		if not lvl.is_walkable(tile):
			tile = Level.to_tile(global_position)
		var e: Enemy
		if room != null:
			e = room.spawn_enemy(sd, false, Level.to_world(tile), 0.5)
		else:
			# Outside a room controller (tests, hub, custom arenas): spawn directly.
			e = Enemy.create(sd, false, floor_index, difficulty, _rng.randi())
			e.position = Level.to_world(tile)
			e.aggro = true
			lvl.add_entity(e)
		_summons.append(e)


func _contact_damage(p: Player) -> void:
	if p == null or data.contact_damage <= 0 or _contact_cd > 0.0 or state == S.WINDUP:
		return
	var reach: float = data.radius * scale.x + 5.0
	if global_position.distance_to(p.global_position) < reach:
		var info: HitInfo = HitInfo.make(Damage.enemy_damage(data.contact_damage, difficulty) + (1 if elite else 0),
				(p.global_position - global_position).normalized() * 120.0, false, global_position)
		if p.receive_hit(info):
			_contact_cd = CONTACT_COOLDOWN


# --- movement helpers ------------------------------------------------------------------
func _steer_to(target: Vector2, los: bool) -> Vector2:
	if los:
		_path.clear()
		return (target - global_position).normalized()
	var lvl: Level = Level.current
	if _repath <= 0.0 or _path_i >= _path.size():
		_repath = REPATH_TIME
		_path = lvl.find_path(global_position, target)
		_path_i = 1 if _path.size() > 1 else 0
	while _path_i < _path.size() and global_position.distance_to(_path[_path_i]) < 5.0:
		_path_i += 1
	if _path_i < _path.size():
		return (_path[_path_i] - global_position).normalized()
	return (target - global_position).normalized()


func _separation() -> Vector2:
	_think -= get_physics_process_delta_time()
	if _think > 0.0:
		return Vector2.ZERO
	_think = 0.1
	var push: Vector2 = Vector2.ZERO
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if e == self:
			continue
		var n: Node2D = e as Node2D
		var off: Vector2 = global_position - n.global_position
		var d: float = off.length()
		if d > 0.01 and d < 14.0:
			push += off / d * (14.0 - d) * 4.0
	return push


func _animate(p: Player) -> void:
	if state in [S.WINDUP, S.ATTACK, S.STAGGER]:
		if state == S.WINDUP:
			sprite.position = Vector2(_rng.randf_range(-0.6, 0.6), 0).round()
		return
	sprite.position = Vector2.ZERO
	var want: StringName = &"move" if velocity.length() > 8.0 else &"idle"
	if sprite.animation != want and sprite.animation != &"hurt":
		sprite.play(want)
	elif sprite.animation == &"hurt" and not sprite.is_playing():
		sprite.play(want)
	var face_x: float = (p.global_position.x - global_position.x) if p != null else velocity.x
	if absf(face_x) > 1.0:
		sprite.flip_h = face_x < 0.0


# --- damage ----------------------------------------------------------------------------
func receive_hit(info: HitInfo) -> bool:
	if state == S.DEAD or not info.from_player:
		return false
	var amount: int = maxi(int(round(info.damage * status.damage_taken_mult())), 1)
	info.damage = amount
	health.take(info)
	if not aggro:
		aggro = true
	FX.flash(sprite)
	FX.damage_number(global_position, amount, info.crit)
	Sfx.play("crit" if info.crit else "hit", -3.0)
	var resist: float = clampf(data.knock_resist + (0.3 if elite else 0.0), 0.0, 1.0)
	_knock += info.knockback * (1.0 - resist)
	if info.element != "" and _rng.randf() < info.status_chance:
		status.apply(info.element)
	if state != S.DEAD and resist < 0.5 and info.knockback.length() > 80.0 and state in [S.CHASE, S.IDLE, S.WANDER]:
		_set_state(S.STAGGER)
	if state in [S.IDLE, S.WANDER]:
		_set_state(S.CHASE)
	return true


func _on_burn(amount: int) -> void:
	if state == S.DEAD:
		return
	health.take(HitInfo.make(amount, Vector2.ZERO, true, global_position))
	FX.damage_number(global_position, amount, false, Color("#f2b23a"))


func _on_died() -> void:
	_set_state(S.DEAD)
	_lunge_dir = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	hurtbox.set_deferred("monitorable", false)
	hurtbox.collision_layer = 0
	remove_from_group("enemies")
	sprite.play(&"death")
	Sfx.play("enemy_die", -2.0)
	FX.shake(1.5 if not elite else 4.0)
	FX.burst("puff", global_position)
	_drop_loot()
	var p: Player = _player()
	if p != null:
		p.on_enemy_killed()
	Events.enemy_killed.emit(self, elite)
	died.emit(self)
	var tw: Tween = create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


func _drop_loot() -> void:
	var el: Dictionary = Db.elite
	var coin_mult: float = float(el.get("coin_mult", 3)) if elite else 1.0
	var n: int = int(_rng.randi_range(data.coins.x, data.coins.y) * coin_mult)
	Pickup.spawn_coins(global_position, n)
	var shard_chance: float = float(el.get("shard_chance", 1.0)) if elite else data.shard_chance
	if _rng.randf() < shard_chance:
		Pickup.spawn(Pickup.Kind.SHARD, global_position, 2 if elite else 1)
	if _rng.randf() < (0.25 if elite else 0.04):
		Pickup.spawn(Pickup.Kind.HEART if _rng.randf() < 0.5 else Pickup.Kind.ARMOR, global_position, 1)
