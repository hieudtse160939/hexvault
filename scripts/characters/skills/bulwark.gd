extends HeroSkill
## Bramble - BULWARK: a dome that blocks all damage and erases enemy bolts.

var _vis: Node2D = null


func activate() -> void:
	_vis = _make_dome(float(param("radius", 34.0)))
	player.add_child(_vis)


func tick(_delta: float) -> void:
	var lvl: Level = level()
	if lvl != null:
		lvl.pool.erase_hostile_in(player.global_position, float(param("radius", 34.0)))


func end() -> void:
	if _vis != null and is_instance_valid(_vis):
		_vis.queue_free()
	_vis = null


func keeps_invulnerable() -> bool:
	return is_active()


func _make_dome(r: float) -> Node2D:
	var n: Node2D = Node2D.new()
	var ring: Line2D = Line2D.new()
	var pts: PackedVector2Array = []
	for i: int in 25:
		pts.append(Vector2.from_angle(i * TAU / 24.0) * (r - 4.0))
	ring.points = pts
	ring.width = 1.0
	ring.default_color = Color("#6fb0ff")
	n.add_child(ring)
	var tw: Tween = n.create_tween().set_loops()
	tw.tween_property(ring, "modulate:a", 0.4, 0.25)
	tw.tween_property(ring, "modulate:a", 1.0, 0.25)
	return n
