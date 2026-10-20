class_name ProjectilePool
extends Node2D
## Owns and simulates every projectile on the level in one physics pass.
## Collision uses a ray from the previous to the next position each tick, so
## fast projectiles cannot tunnel through thin walls or small hurtboxes.

const PREALLOC: int = 96
const HARD_CAP: int = 900

var _free: Array[Projectile] = []
var _active: Array[Projectile] = []
var _query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()


func _ready() -> void:
	for i: int in PREALLOC:
		_free.append(_make())
	_query.collide_with_areas = true
	_query.collide_with_bodies = true


func _make() -> Projectile:
	var p: Projectile = Projectile.new()
	p.reset()
	add_child(p)
	return p


func active_count() -> int:
	return _active.size()


## Takes a projectile from the pool. Caller sets fields then calls launch().
func acquire() -> Projectile:
	if _active.size() >= HARD_CAP:
		# Recycle the oldest rather than allocate without bound.
		release(_active[0])
	var p: Projectile = _free.pop_back() if not _free.is_empty() else _make()
	p.reset()
	return p


func launch(p: Projectile, pos: Vector2, vel: Vector2, sprite_key: String) -> void:
	p.global_position = pos
	p.velocity = vel
	p.rotation = vel.angle()
	SpriteLib.apply(p, sprite_key)
	p.play(&"idle")
	p.active = true
	p.visible = true
	_active.append(p)


func release(p: Projectile) -> void:
	if not p.active:
		return
	p.reset()
	p.stop()
	_active.erase(p)
	_free.append(p)


func clear_all() -> void:
	for p: Projectile in _active.duplicate():
		release(p)


## Removes enemy projectiles inside a circle (deflects, shields). Returns count.
func erase_hostile_in(center: Vector2, radius: float, arc_dir: Vector2 = Vector2.ZERO, arc_half: float = PI) -> int:
	var n: int = 0
	for p: Projectile in _active.duplicate():
		if p.from_player:
			continue
		var off: Vector2 = p.global_position - center
		if off.length() > radius:
			continue
		if arc_dir != Vector2.ZERO and absf(arc_dir.angle_to(off)) > arc_half:
			continue
		FX.burst("impact_teal", p.global_position)
		release(p)
		n += 1
	return n


func _physics_process(delta: float) -> void:
	if _active.is_empty():
		return
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var lvl: Level = Level.current
	for p: Projectile in _active.duplicate():
		if not p.active:
			continue
		if p.homing > 0.0 and lvl != null:
			var target: Node2D = lvl.nearest_enemy(p.global_position, 140.0) if p.from_player else (lvl.player as Node2D)
			if target != null:
				var want: Vector2 = (target.global_position - p.global_position).normalized() * p.velocity.length()
				p.velocity = p.velocity.lerp(want, clampf(p.homing * delta, 0.0, 1.0))
				p.rotation = p.velocity.angle()
		var from: Vector2 = p.global_position
		var step: Vector2 = p.velocity * delta
		var to: Vector2 = from + step
		p.range_left -= step.length()
		_query.from = from
		_query.to = to + step.normalized() * p.radius
		_query.collision_mask = Level.WORLD_MASK | Level.BREAKABLE_MASK | (Hurtbox.LAYER_ENEMY if p.from_player else Hurtbox.LAYER_PLAYER)
		_query.exclude = p.hit_rids
		var hit: Dictionary = space.intersect_ray(_query)
		if hit.is_empty():
			p.global_position = to
			if p.range_left <= 0.0:
				_expire(p)
			continue
		var collider: Object = hit["collider"]
		var hit_pos: Vector2 = hit["position"]
		if collider is Hurtbox:
			var info: HitInfo = HitInfo.make(p.damage, p.velocity.normalized() * p.knockback, p.from_player, from)
			info.crit = p.crit
			info.element = p.element
			info.status_chance = p.status_chance
			info.source_id = p.source_id
			var landed: bool = (collider as Hurtbox).hit(info)
			if not landed:
				# Target ignored the hit (dashing, invulnerable): fly on through it.
				p.hit_rids.append(hit["rid"])
				p.global_position = to
				continue
			if p.explosion_radius > 0.0:
				Combat.explode(hit_pos, p.explosion_radius, p.explosion_damage, not p.from_player, p.from_player)
			if p.pierce > 0:
				p.pierce -= 1
				p.hit_rids.append(hit["rid"])
				p.global_position = to
				FX.burst(p.impact_fx, hit_pos)
				continue
			FX.burst(p.impact_fx, hit_pos)
			release(p)
			continue
		# Wall or breakable.
		if collider != null and collider.has_method("receive_hit"):
			var binfo: HitInfo = HitInfo.make(p.damage, Vector2.ZERO, p.from_player, from)
			collider.call("receive_hit", binfo)
		if p.explosion_radius > 0.0:
			Combat.explode(hit_pos, p.explosion_radius, p.explosion_damage, not p.from_player, p.from_player)
		FX.burst(p.impact_fx, hit_pos - p.velocity.normalized() * 2.0)
		release(p)


func _expire(p: Projectile) -> void:
	if p.explosion_radius > 0.0:
		Combat.explode(p.global_position, p.explosion_radius, p.explosion_damage, not p.from_player, p.from_player)
	release(p)
