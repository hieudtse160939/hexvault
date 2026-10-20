class_name FX
extends RefCounted
## Visual feedback helpers. All respect Settings (reduced effects, damage numbers).

const FLASH_SHADER: Shader = preload("res://shaders/flash.gdshader")

static var camera: GameCamera = null


## Gives a CanvasItem the flash material (call once when building an actor).
static func make_flashable(item: CanvasItem) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = FLASH_SHADER
	item.material = m
	return m


static func flash(item: CanvasItem, color: Color = Color.WHITE, duration: float = 0.09) -> void:
	if item == null or not is_instance_valid(item):
		return
	var m: ShaderMaterial = item.material as ShaderMaterial
	if m == null:
		m = make_flashable(item)
	m.set_shader_parameter("flash_color", color)
	m.set_shader_parameter("flash", 1.0)
	var tw: Tween = item.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("flash", v), 1.0, 0.0, duration)


static func _layer() -> Node2D:
	var lvl: Level = Level.current
	return lvl.fx_layer if lvl != null else null


## One-shot animated effect from a sprite sheet ("fx_<name>").
static func burst(name: String, pos: Vector2, rot: float = 0.0, scale_mul: float = 1.0) -> void:
	var layer: Node2D = _layer()
	if layer == null:
		return
	if Settings.reduced_effects() and name in ["impact", "impact_teal", "impact_red", "muzzle", "sparkle", "sparkle_teal"]:
		return
	var s: AnimatedSprite2D = AnimatedSprite2D.new()
	s.sprite_frames = SpriteLib.frames("fx_" + name)
	s.global_position = pos
	s.rotation = rot
	s.scale = Vector2.ONE * scale_mul
	layer.add_child(s)
	s.animation_finished.connect(s.queue_free)
	s.play(&"idle")


static func puff(pos: Vector2) -> void:
	burst("puff", pos)


static func shake(strength: float) -> void:
	if camera != null and is_instance_valid(camera):
		camera.add_shake(strength * Settings.shake_scale())


static func hit_stop(duration: float) -> void:
	if Settings.reduced_effects():
		return
	Events.hit_stop.emit(duration)


static func damage_number(pos: Vector2, amount: int, crit: bool, color: Color = Color("#f4f1ff")) -> void:
	var layer: Node2D = _layer()
	if layer == null or not bool(Settings.get_value("damage_numbers")):
		return
	var l: Label = Label.new()
	l.text = str(amount) + ("!" if crit else "")
	l.add_theme_color_override("font_color", Color("#f2b23a") if crit else color)
	l.add_theme_color_override("font_outline_color", Color("#14101e"))
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_font_override("font", SpriteLib.font())
	l.add_theme_font_size_override("font_size", 8)
	l.position = pos + Vector2(randf_range(-4, 4) - 4, -14)
	l.z_index = 30
	layer.add_child(l)
	var tw: Tween = l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 10.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


## Short-lived line (hitscan beams, lightning).
static func beam(points: PackedVector2Array, color: Color, width: float = 1.0, life: float = 0.08) -> void:
	var layer: Node2D = _layer()
	if layer == null or points.size() < 2:
		return
	var line: Line2D = Line2D.new()
	line.points = points
	line.width = width
	line.default_color = color
	line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(line)
	var tw: Tween = line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, life)
	tw.tween_callback(line.queue_free)


## Jagged lightning between successive points.
static func lightning(points: PackedVector2Array) -> void:
	var jag: PackedVector2Array = []
	for i: int in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var n: Vector2 = (b - a).orthogonal().normalized()
		for k: int in 6:
			var t: float = float(k) / 6.0
			jag.append(a.lerp(b, t) + n * (randf_range(-4.0, 4.0) if k > 0 else 0.0))
	if not points.is_empty():
		jag.append(points[points.size() - 1])
	beam(jag, Color("#6fb0ff"), 1.0, 0.12)
	beam(jag, Color("#f4f1ff"), 1.0, 0.05)


## Floating world text (pickups, prompts).
static func float_text(pos: Vector2, text: String, color: Color) -> void:
	var layer: Node2D = _layer()
	if layer == null:
		return
	var l: Label = UiTheme.label(text, color, true)
	l.add_theme_font_override("font", SpriteLib.font())
	l.position = pos + Vector2(-text.length() * 3, -20)
	l.z_index = 30
	layer.add_child(l)
	var tw: Tween = l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 8.0, 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.tween_callback(l.queue_free)
