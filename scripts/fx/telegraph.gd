class_name Telegraph
extends Node2D
## Ground warning that fills up, then fires `on_done`. Used for boss slams and
## any attack that would otherwise be unreadable.

var radius: float = 24.0
var duration: float = 0.9
var color: Color = Color("#e8455a")
var on_done: Callable = Callable()
var _t: float = 0.0


static func circle(pos: Vector2, r: float, dur: float, done: Callable) -> Telegraph:
	var t: Telegraph = Telegraph.new()
	t.position = pos
	t.radius = r
	t.duration = dur
	t.on_done = done
	t.z_index = -1
	var lvl: Level = Level.current
	if lvl != null:
		lvl.fx_layer.add_child(t)
	return t


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= duration:
		if on_done.is_valid():
			on_done.call(global_position)
		queue_free()


func _draw() -> void:
	var k: float = clampf(_t / duration, 0.0, 1.0)
	var blink: float = 0.55 + 0.45 * sin(_t * (12.0 + 30.0 * k))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color, 0.9 * blink), 1.0, false)
	draw_circle(Vector2.ZERO, radius * k, Color(color, 0.25))
