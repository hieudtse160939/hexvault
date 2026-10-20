class_name Combat
extends RefCounted
## Stateless combat queries: explosions, hitscan rays, chain lightning, melee arcs.


static func _space() -> PhysicsDirectSpaceState2D:
	var lvl: Level = Level.current
	return lvl.get_world_2d().direct_space_state if lvl != null else null


## Circle query returning hurtboxes/breakables hit by an area effect.
static func _circle(center: Vector2, radius: float, mask: int) -> Array[Dictionary]:
	var space: PhysicsDirectSpaceState2D = _space()
	if space == null:
		return []
	var q: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	q.shape = shape
	q.transform = Transform2D(0.0, center)
	q.collision_mask = mask
	q.collide_with_areas = true
	q.collide_with_bodies = true
	return space.intersect_shape(q, 64)


static func explode(center: Vector2, radius: float, damage: int, hurts_player: bool, hurts_enemies: bool) -> void:
	FX.burst("explosion", center)
	FX.shake(4.0)
	Sfx.play("explosion")
	var mask: int = Level.BREAKABLE_MASK
	if hurts_player:
		mask |= Hurtbox.LAYER_PLAYER
	if hurts_enemies:
		mask |= Hurtbox.LAYER_ENEMY
	var seen: Dictionary = {}
	for r: Dictionary in _circle(center, radius, mask):
		var c: Object = r["collider"]
		if c == null or seen.has(c):
			continue
		seen[c] = true
		var pos: Vector2 = (c as Node2D).global_position if c is Node2D else center
		var info: HitInfo = HitInfo.make(damage, (pos - center).normalized() * 140.0, not hurts_player, center)
		info.element = "fire"
		info.status_chance = 0.5
		if c is Hurtbox:
			(c as Hurtbox).hit(info)
		elif c.has_method("receive_hit"):
			c.call("receive_hit", info)


## Piercing instant ray. Returns the end point (for drawing the beam).
static func hitscan(from: Vector2, dir: Vector2, length: float, pierce: int, template: HitInfo) -> Vector2:
	var space: PhysicsDirectSpaceState2D = _space()
	var end: Vector2 = from + dir * length
	if space == null:
		return end
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, end,
			Level.WORLD_MASK | Level.BREAKABLE_MASK | (Hurtbox.LAYER_ENEMY if template.from_player else Hurtbox.LAYER_PLAYER))
	q.collide_with_areas = true
	var exclude: Array[RID] = []
	var left: int = pierce + 1
	for i: int in 24:
		q.exclude = exclude
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			return end
		var c: Object = hit["collider"]
		var pos: Vector2 = hit["position"]
		if c is Hurtbox:
			var info: HitInfo = _clone(template)
			info.knockback = dir * template.knockback.length()
			if (c as Hurtbox).hit(info):
				left -= 1
				FX.burst("impact_teal", pos)
			exclude.append(hit["rid"])
			if left <= 0:
				return pos
			continue
		if c != null and c.has_method("receive_hit"):
			c.call("receive_hit", _clone(template))
		FX.burst("impact", pos)
		return pos
	return end


## Lightning that jumps from the origin to the nearest enemy, then chains.
## Returns the list of points for the bolt visual.
static func chain(from: Vector2, length: float, jumps: int, template: HitInfo) -> PackedVector2Array:
	var pts: PackedVector2Array = [from]
	var lvl: Level = Level.current
	if lvl == null:
		return pts
	var hit_list: Array = []
	var cur: Vector2 = from
	var reach: float = length
	for i: int in jumps + 1:
		var target: Node2D = lvl.nearest_enemy(cur, reach, true, hit_list)
		if target == null:
			break
		hit_list.append(target)
		pts.append(target.global_position)
		if target.has_method("receive_hit"):
			var info: HitInfo = _clone(template)
			info.knockback = (target.global_position - cur).normalized() * template.knockback.length()
			target.call("receive_hit", info)
		cur = target.global_position
		reach = 80.0
	return pts


## Melee arc sweep. Returns number of targets hit.
static func melee(center: Vector2, dir: Vector2, reach: float, arc_deg: float, template: HitInfo) -> int:
	var mask: int = Level.BREAKABLE_MASK | (Hurtbox.LAYER_ENEMY if template.from_player else Hurtbox.LAYER_PLAYER)
	var half: float = deg_to_rad(arc_deg) / 2.0
	var count: int = 0
	var seen: Dictionary = {}
	for r: Dictionary in _circle(center, reach, mask):
		var c: Object = r["collider"]
		if c == null or seen.has(c) or not c is Node2D:
			continue
		seen[c] = true
		var off: Vector2 = (c as Node2D).global_position - center
		if off.length() > 6.0 and absf(dir.angle_to(off)) > half:
			continue
		var info: HitInfo = _clone(template)
		info.knockback = (off.normalized() if off.length() > 0.1 else dir) * template.knockback.length()
		var landed: bool = false
		if c is Hurtbox:
			landed = (c as Hurtbox).hit(info)
		elif c.has_method("receive_hit"):
			landed = bool(c.call("receive_hit", info))
		if landed:
			count += 1
	return count


static func _clone(t: HitInfo) -> HitInfo:
	var h: HitInfo = HitInfo.make(t.damage, t.knockback, t.from_player, t.source_position)
	h.crit = t.crit
	h.element = t.element
	h.status_chance = t.status_chance
	h.source_id = t.source_id
	return h
