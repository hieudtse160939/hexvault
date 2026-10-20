class_name Weapon
extends Node2D
## A held weapon instance: sprite, cooldown, magazine and the firing patterns.
## Behaviour is entirely driven by its WeaponData; there is no per-weapon script.

signal fired
signal ammo_changed(current: int, maximum: int, reloading: bool)

var data: WeaponData
var ammo: int = 0
var reloading: bool = false
var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _sprite: Sprite2D
var _kick: float = 0.0
var _aim: Vector2 = Vector2.RIGHT
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Supplier of modifiers (the Player); must implement weapon_mod(key) -> float.
var owner_actor: Node = null


func setup(d: WeaponData, ammo_left: int = -1) -> void:
	data = d
	ammo = d.magazine if ammo_left < 0 else mini(ammo_left, d.magazine)
	_rng.randomize()
	if _sprite == null:
		_sprite = Sprite2D.new()
		add_child(_sprite)
	SpriteLib.apply(_sprite, "weapon_" + d.id)
	var pv: Vector2 = SpriteLib.pivot("weapon_" + d.id)
	var fs: Vector2i = SpriteLib.frame_size("weapon_" + d.id)
	_sprite.centered = false
	_sprite.offset = -pv
	_sprite.position = Vector2.ZERO
	if fs.x <= 0:
		push_warning("weapon sprite missing for " + d.id)
	_emit_ammo()


func _mod(key: String) -> float:
	if owner_actor != null and owner_actor.has_method("weapon_mod"):
		return float(owner_actor.call("weapon_mod", key))
	return 0.0


func set_aim(dir: Vector2) -> void:
	if dir.length_squared() < 0.0001:
		return
	_aim = dir.normalized()
	rotation = _aim.angle()
	_sprite.flip_v = _aim.x < 0.0
	_sprite.offset.y = -SpriteLib.pivot("weapon_" + data.id).y if not _sprite.flip_v else -(SpriteLib.frame_size("weapon_" + data.id).y - SpriteLib.pivot("weapon_" + data.id).y)
	# Behind the body only when aiming nearly straight up; otherwise the
	# (now larger) HD bodies would hide the gun for most upward angles.
	z_index = -1 if _aim.y < -0.7 else 1


func muzzle_position() -> Vector2:
	var key: String = "weapon_" + data.id
	var mz: Vector2 = SpriteLib.muzzle(key)
	if mz != Vector2.INF:
		return global_position + _aim * maxf((mz.x - SpriteLib.pivot(key).x) / SpriteLib.density(key), 4.0)
	var reach: float = SpriteLib.frame_size_world(key).x - SpriteLib.pivot_world(key).x
	return global_position + _aim * maxf(reach - 2.0, 4.0)


func _process(delta: float) -> void:
	if data == null:
		return
	_cooldown -= delta
	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			reloading = false
			ammo = data.magazine
			Sfx.play("reload", -4.0, 0.0)
			_emit_ammo()
	_kick = move_toward(_kick, 0.0, delta * 40.0)
	_sprite.position = Vector2(-_kick, 0)


func start_reload() -> void:
	if data == null or not data.uses_ammo() or reloading or ammo >= data.magazine:
		return
	reloading = true
	_reload_left = data.reload_time * maxf(1.0 + _mod("reload_mult"), 0.2)
	Sfx.play("reload", -6.0, 0.0)
	_emit_ammo()


func reload_progress() -> float:
	if not reloading or data == null:
		return 1.0
	return 1.0 - _reload_left / maxf(data.reload_time, 0.01)


func _emit_ammo() -> void:
	ammo_changed.emit(ammo, data.magazine if data != null else 0, reloading)


## Attempts to fire toward `dir`. Returns true if a shot happened.
func try_fire(dir: Vector2, from_player: bool = true) -> bool:
	if data == null or _cooldown > 0.0 or reloading:
		return false
	var free_ammo: bool = _mod("free_ammo") > 0.0
	if data.uses_ammo() and ammo <= 0 and not free_ammo:
		Sfx.play("empty", -4.0, 0.0)
		start_reload()
		return false
	set_aim(dir)
	var rate: float = 1.0 + _mod("fire_rate_mult")
	_cooldown = data.fire_interval / maxf(rate, 0.1)
	if data.uses_ammo() and not free_ammo:
		ammo -= 1
	_fire_pattern(from_player)
	Sfx.play(data.sfx)
	FX.shake(data.shake)
	_kick = 3.0 if data.pattern != "melee" else 0.0
	fired.emit()
	_emit_ammo()
	if data.uses_ammo() and ammo <= 0 and not free_ammo:
		start_reload()
	return true


func _make_info(from_player: bool) -> HitInfo:
	var crit: bool = _rng.randf() < data.crit_chance + _mod("crit")
	var dmg: int = Damage.compute(data.damage, 1.0 + _mod("damage_mult"), crit)
	var info: HitInfo = HitInfo.make(dmg, _aim * data.knockback, from_player, global_position)
	info.crit = crit
	info.element = data.element
	info.status_chance = data.status_chance
	info.source_id = data.id
	return info


func _fire_pattern(from_player: bool) -> void:
	var lvl: Level = Level.current
	if lvl == null:
		return
	var origin: Vector2 = muzzle_position()
	match data.pattern:
		"melee":
			var info: HitInfo = _make_info(from_player)
			Combat.melee(global_position, _aim, data.weapon_range, data.spread_deg, info)
			FX.burst("slash", global_position + _aim * 10.0, _aim.angle())
			if data.deflect:
				var n: int = lvl.pool.erase_hostile_in(global_position, data.weapon_range + 4.0, _aim, deg_to_rad(data.spread_deg) / 2.0)
				if n > 0:
					Sfx.play("hit", -2.0)
		"hitscan":
			var info2: HitInfo = _make_info(from_player)
			var pierce: int = data.pierce + int(_mod("pierce"))
			var end: Vector2 = Combat.hitscan(origin, _aim, data.weapon_range, pierce, info2)
			FX.beam(PackedVector2Array([origin, end]), Color(PaletteColors.get_color(data.beam_color)), 1.0 if data.fire_interval < 0.2 else 2.0)
			FX.burst("muzzle", origin, _aim.angle())
		"chain":
			var info3: HitInfo = _make_info(from_player)
			var pts: PackedVector2Array = Combat.chain(origin, data.weapon_range, data.chain, info3)
			if pts.size() > 1:
				FX.lightning(pts)
			else:
				FX.lightning(PackedVector2Array([origin, origin + _aim * 30.0]))
		_:
			var shots: int = data.pellets + (int(_mod("extra_shots")) if data.pattern == "single" else 0)
			for i: int in shots:
				var spread: float = deg_to_rad(data.spread_deg)
				var ang: float
				if data.pattern == "spread":
					ang = -spread / 2.0 + spread * (float(i) + _rng.randf_range(0.2, 0.8)) / float(shots)
				elif shots > 1:
					ang = (float(i) - (shots - 1) / 2.0) * deg_to_rad(8.0) + _rng.randf_range(-spread, spread) / 2.0
				else:
					ang = _rng.randf_range(-spread, spread) / 2.0
				var dir: Vector2 = _aim.rotated(ang)
				var speed: float = data.projectile_speed * (1.0 + _rng.randf_range(-data.speed_jitter, data.speed_jitter))
				var p: Projectile = lvl.pool.acquire()
				var info4: HitInfo = _make_info(from_player)
				p.from_player = from_player
				p.damage = info4.damage
				p.crit = info4.crit
				p.knockback = data.knockback
				p.pierce = data.pierce + int(_mod("pierce"))
				p.homing = data.homing
				p.range_left = data.weapon_range
				p.element = data.element
				p.status_chance = data.status_chance
				p.explosion_radius = data.explosion_radius
				p.explosion_damage = Damage.compute(data.explosion_damage, 1.0 + _mod("damage_mult"), false) if data.explosion_damage > 0 else 0
				p.radius = 3.0 if data.projectile.begins_with("orb") else 1.5
				p.source_id = data.id
				p.impact_fx = "impact_teal" if data.element in ["frost", "hex", "shock"] else "impact"
				lvl.pool.launch(p, origin, dir * speed, "proj_" + data.projectile)
			FX.burst("muzzle", origin, _aim.angle())
