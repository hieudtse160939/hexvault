class_name SafeArea
extends RefCounted
## Insets a full-rect Control so HUD elements avoid notches / rounded corners.
## Converts the OS safe area (screen pixels) into viewport (canvas) units.


static func apply(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vp: Viewport = c.get_viewport()
	if vp == null or DisplayServer.get_name() == "headless":
		return
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var win: Vector2i = DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
		return
	var vis: Vector2 = vp.get_visible_rect().size
	var sx: float = vis.x / float(win.x)
	var sy: float = vis.y / float(win.y)
	var win_pos: Vector2i = DisplayServer.window_get_position()
	var left: float = maxf(float(safe.position.x - win_pos.x), 0.0) * sx
	var top: float = maxf(float(safe.position.y - win_pos.y), 0.0) * sy
	var right: float = maxf(float((win_pos.x + win.x) - (safe.position.x + safe.size.x)), 0.0) * sx
	var bottom: float = maxf(float((win_pos.y + win.y) - (safe.position.y + safe.size.y)), 0.0) * sy
	# On desktop the "safe area" is the whole usable display, not the window: ignore.
	if not OS.has_feature("mobile"):
		return
	c.offset_left = left
	c.offset_top = top
	c.offset_right = -right
	c.offset_bottom = -bottom
