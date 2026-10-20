class_name Weapon
extends Node2D
## A held weapon instance: sprite, cooldown, magazine and the firing patterns.
## Behaviour is entirely driven by its WeaponData; there is no per-weapon script.
##
## Weapon-aware attacks: the weapon's `style` (data/weapons.json) selects an
## attack profile (data/weapon_styles.json). Every attack runs
##   READY -> WINDUP (anticipation: draw / charge / raise) -> release
##   [-> ACTIVE (melee swing; the hit lands at the middle of the swing)] -> RECOVER -> READY
## Projectiles and hits are created only at the release / contact moment, from
## the weapon's emission point (manifest `muzzle`) in its current pose. The
## motion of the weapon sprite is procedural per style (gun recoil, bow draw
## frames, staff raise-charge-thrust, sword arc, dagger stab, spear thrust,
## heavy overhead slam). Cooldowns stay in gameplay code, never in playback.

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

enum Phase { READY, WINDUP, ACTIVE, RECOVER }
const ELEMENT_COLORS: Dictionary = {"fire": Color("#f2a23a"), "frost": Color("#86d3df"), "hex": Color("#c78bff"), "shock": Color("#b4fff0")}

var style: Dictionary = {}       # attack profile
var phase: int = Phase.READY
var attacks: int = 0             # attacks released (tests / combo)
var _phase_t: float = 0.0
var _times: Vector3 = Vector3.ZERO   # windup, active, recover after attack speed
var _from_player: bool = true
var _hit_done: bool = false
var _combo: int = 0
var _burst_t: float = 0.0        # magic release ring
var _frames: SpriteFrames = null
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
	style = Db.weapon_style(d)
	_frames = SpriteLib.frames("weapon_" + d.id)
	phase = Phase.READY
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


## Aim follows the player, except during an attack: the direction is committed
## when the attack starts, so the release goes where the windup pointed.
func set_aim(dir: Vector2) -> void:
	if dir.length_squared() < 0.0001 or phase != Phase.READY:
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
		# emission point in the weapon's current pose (staff tip while it is raised, etc.)
		var d: float = SpriteLib.density(key)
		var local: Vector2 = Vector2(maxf((mz.x - SpriteLib.pivot(key).x) / d, 4.0), (mz.y - SpriteLib.pivot(key).y) / d)
		if _sprite.flip_v:
			local.y = -local.y
		return to_global(_sprite.position + local.rotated(_sprite.rotation))
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
	_update_attack(delta)
	_apply_motion()
	if _burst_t > 0.0:
		_burst_t = maxf(_burst_t - delta, 0.0)
	if is_magic():
		queue_redraw()


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


## Starts an attack toward `dir`. Returns true if an attack started. Holding
## the button calls this every frame; it only starts a new attack when the
## previous one finished and the cooldown elapsed, so nothing restarts per frame.
func try_fire(dir: Vector2, from_player: bool = true) -> bool:
	if data == null or _cooldown > 0.0 or reloading or phase != Phase.READY:
		return false
	var free_ammo: bool = _mod("free_ammo") > 0.0
	if data.uses_ammo() and ammo <= 0 and not free_ammo:
		Sfx.play("empty", -4.0, 0.0)
		start_reload()
		return false
	set_aim(dir)   # phase is READY here, so the new direction is applied
	var rate: float = maxf(1.0 + _mod("fire_rate_mult"), 0.1)
	_times = Vector3(float(style.get("windup", 0.0)), float(style.get("active", 0.0)), float(style.get("recover", 0.0))) / rate
	_cooldown = maxf(data.fire_interval / rate, _times.x + _times.y + _times.z * 0.5)
	if data.uses_ammo() and not free_ammo:
		ammo -= 1
	_from_player = from_player
	_hit_done = false
	_combo += 1
	_set_phase(Phase.WINDUP)
	if _times.x <= 0.0:
		_release()
	fired.emit()
	_emit_ammo()
	return true


func is_attacking() -> bool:
	return phase != Phase.READY


func is_magic() -> bool:
	return bool(style.get("magic", false))


## Safe interruption (weapon swap, death): no pending hit fires later.
func cancel_attack() -> void:
	_set_phase(Phase.READY)
	_hit_done = true
	_sprite.rotation = 0.0
	_sprite.position = Vector2.ZERO
	_show_frame("idle", 0)
	queue_redraw()


func _set_phase(p: int) -> void:
	phase = p
	_phase_t = 0.0


## End of windup: ranged attacks spawn their shot now; melee starts its swing.
func _release() -> void:
	if _times.y > 0.0:
		_set_phase(Phase.ACTIVE)
		Sfx.play(data.sfx)
		return
	_strike()
	_set_phase(Phase.RECOVER)


## The moment damage happens: projectile spawn, beam, or melee contact.
func _strike() -> void:
	if _hit_done:
		return
	_hit_done = true
	attacks += 1
	_fire_pattern(_from_player)
	if _times.y <= 0.0:
		Sfx.play(data.sfx)
	FX.shake(data.shake)
	var fx: String = str(style.get("release_fx", ""))
	if fx != "" and data.pattern != "melee":
		FX.burst(fx, muzzle_position(), _aim.angle())
	match str(style.get("motion", "")):
		"recoil":
			_kick = 3.0
		"slam":
			FX.burst("puff", global_position + _aim * 18.0)
			FX.shake(data.shake + 2.0)
	if is_magic():
		_burst_t = 0.2
	if data.uses_ammo() and ammo <= 0 and _mod("free_ammo") <= 0.0:
		start_reload()


func _update_attack(delta: float) -> void:
	if phase == Phase.READY:
		return
	_phase_t += delta
	match phase:
		Phase.WINDUP:
			if _phase_t >= _times.x:
				_release()
		Phase.ACTIVE:
			if not _hit_done and _phase_t >= _times.y * 0.5:
				_strike()
			if _phase_t >= _times.y:
				_set_phase(Phase.RECOVER)
		Phase.RECOVER:
			if _phase_t >= _times.z:
				_set_phase(Phase.READY)


## 0..1 progress of the current phase.
func _prog(t: float) -> float:
	return clampf(_phase_t / t, 0.0, 1.0) if t > 0.0 else 1.0


static func _ease(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


## Procedural pose per style, in the weapon's local frame (+x = aim).
## `up` turns local rotations so "raise" always means up on screen.
func _apply_motion() -> void:
	var up: float = -1.0 if _aim.x >= 0.0 else 1.0
	var rot: float = 0.0
	var off: Vector2 = Vector2.ZERO
	var w: float = _ease(_prog(_times.x))
	var a: float = _prog(_times.y)
	var r: float = 1.0 - _ease(_prog(_times.z))
	var side: float = 1.0 if _combo % 2 == 0 else -1.0
	match str(style.get("motion", "recoil")):
		"recoil":
			off.x = -_kick
		"draw":
			if phase == Phase.WINDUP:
				off.x = -1.5 * w
				_show_frame("draw", int(w * 2.99))
			elif phase == Phase.RECOVER:
				_show_frame("release", 0 if _prog(_times.z) < 0.5 else 1)
			else:
				_show_frame("idle", 0)
		"staff", "wand":
			var lift: float = 0.95 if style["motion"] == "staff" else 0.6
			match phase:
				Phase.WINDUP:
					# raise the staff while gathering power, then bring the tip down
					# onto the target line just as the spell leaves it
					rot = lift * sin(PI * w) * up
					off.x = -2.5 * sin(PI * w) + 2.0 * w
				Phase.RECOVER:
					rot = -0.12 * r * up
					off.x = 2.0 * r
		"orb":
			match phase:
				Phase.WINDUP:
					off = Vector2(-1.0 * w, 4.0 * w * up)
				Phase.RECOVER:
					off = Vector2(3.0 * r, 0.0)
		"swing":
			match phase:
				Phase.WINDUP:
					rot = 1.25 * w * up * side
				Phase.ACTIVE:
					rot = lerpf(1.25, -1.25, a) * up * side
				Phase.RECOVER:
					rot = -1.25 * r * up * side
		"stab":
			match phase:
				Phase.WINDUP:
					off.x = -3.0 * w
				Phase.ACTIVE:
					off.x = lerpf(-3.0, 8.0, a)
				Phase.RECOVER:
					off.x = 8.0 * r
		"thrust":
			match phase:
				Phase.WINDUP:
					off.x = -5.0 * w
				Phase.ACTIVE:
					off.x = lerpf(-5.0, 14.0, a)
				Phase.RECOVER:
					off.x = 14.0 * r
		"slam":
			match phase:
				Phase.WINDUP:
					rot = 2.1 * w * up
				Phase.ACTIVE:
					rot = lerpf(2.1, -0.5, a * a) * up
				Phase.RECOVER:
					rot = -0.5 * r * up
	_sprite.rotation = rot
	_sprite.position = off


func _show_frame(anim: String, i: int) -> void:
	if _frames == null or not _frames.has_animation(anim):
		anim = "idle"
		i = 0
	if _frames == null or not _frames.has_animation(anim):
		return
	var t: Texture2D = _frames.get_frame_texture(anim, clampi(i, 0, _frames.get_frame_count(anim) - 1))
	if _sprite.texture != t:
		_sprite.texture = t


## Spell feedback drawn at the staff tip: charge glow while casting, a ring on release.
func _draw() -> void:
	if not is_magic() or data == null:
		return
	var col: Color = ELEMENT_COLORS.get(data.element, Color("#4fe0d0"))
	var tip: Vector2 = to_local(muzzle_position())
	if phase == Phase.WINDUP:
		var k: float = _ease(_prog(_times.x))
		draw_circle(tip, 1.0 + 3.0 * k, Color(col, 0.35 + 0.4 * k))
		draw_circle(tip, 0.6 + 1.2 * k, Color(1, 1, 1, 0.8 * k))
	if _burst_t > 0.0:
		var b: float = 1.0 - _burst_t / 0.2
		draw_arc(tip, 2.0 + 7.0 * b, 0.0, TAU, 16, Color(col, 1.0 - b), 1.0)


func _make_info(from_player: bool) -> HitInfo:
	var crit: bool = _rng.randf() < data.crit_chance + _mod("crit")
	var cm: float = _mod("crit_mult")
	var dmg: int = Damage.compute(data.damage, 1.0 + _mod("damage_mult"), crit, cm if cm > 0.0 else Damage.CRIT_MULT)
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
			var mfx: String = str(style.get("release_fx", "slash"))
			if mfx != "":
				FX.burst(mfx, global_position + _aim * minf(data.weapon_range * 0.4, 14.0), _aim.angle())
			if data.deflect:
				var n: int = lvl.pool.erase_hostile_in(global_position, data.weapon_range + 4.0, _aim, deg_to_rad(data.spread_deg) / 2.0)
				if n > 0:
					Sfx.play("hit", -2.0)
		"hitscan":
			var info2: HitInfo = _make_info(from_player)
			var pierce: int = data.pierce + int(_mod("pierce"))
			var end: Vector2 = Combat.hitscan(origin, _aim, data.weapon_range, pierce, info2)
			FX.beam(PackedVector2Array([origin, end]), Color(PaletteColors.get_color(data.beam_color)), 1.0 if data.fire_interval < 0.2 else 2.0)
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
				p.explosion_radius = data.explosion_radius * maxf(1.0 + _mod("blast_mult"), 0.2)
				p.explosion_damage = Damage.compute(data.explosion_damage, 1.0 + _mod("damage_mult"), false) if data.explosion_damage > 0 else 0
				p.radius = 3.0 if data.projectile.begins_with("orb") else 1.5
				p.source_id = data.id
				p.impact_fx = "impact_teal" if data.element in ["frost", "hex", "shock"] else "impact"
				lvl.pool.launch(p, origin, dir * speed, "proj_" + data.projectile)
