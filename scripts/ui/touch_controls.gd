class_name TouchControls
extends Control
## Mobile on-screen controls. Hidden unless Controls.touch_ui_enabled().

signal pause_pressed

const JOY_RADIUS: float = 24.0

var player: Player

var _move_touch: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _move_pos: Vector2 = Vector2.ZERO
var _aim_touch: int = -1
var _aim_origin: Vector2 = Vector2.ZERO
var _aim_pos: Vector2 = Vector2.ZERO
var _buttons: Dictionary = {}  # name -> Rect2
var _held: Dictionary = {}     # touch index -> button name
var _interact_visible: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.interact_hint.connect(func(t: String) -> void:
		_interact_visible = not t.is_empty()
		queue_redraw())
	Events.settings_changed.connect(queue_redraw)
	Controls.device_changed.connect(func(_d: int) -> void: queue_redraw())


func _scale() -> float:
	return clampf(float(Settings.get_value("ui_scale")), 0.6, 1.6)


func _layout_buttons() -> void:
	var s: float = _scale()
	var w: Vector2 = size
	var b: float = 24.0 * s
	_buttons = {
		"attack": Rect2(Vector2(w.x - 70 * s, w.y - 70 * s), Vector2(56, 56) * s),
		"skill": Rect2(Vector2(w.x - 104 * s, w.y - 42 * s), Vector2(b, b)),
		"dash": Rect2(Vector2(w.x - 46 * s, w.y - 108 * s), Vector2(b, b)),
		"swap": Rect2(Vector2(w.x - 104 * s, w.y - 74 * s), Vector2(b, b)),
		"interact": Rect2(Vector2(w.x - 78 * s, w.y - 108 * s), Vector2(b, b)),
		"pause": Rect2(Vector2(w.x - 28 * s, 78), Vector2(b, b)),
	}


func _process(_delta: float) -> void:
	var on: bool = Controls.touch_ui_enabled()
	if visible != on:
		visible = on
		if not on:
			_release_all()
	if not on:
		return
	_layout_buttons()
	modulate.a = clampf(float(Settings.get_value("touch_opacity")), 0.2, 1.0)
	queue_redraw()


func _release_all() -> void:
	_move_touch = -1
	_aim_touch = -1
	_held.clear()
	Controls.touch_move = Vector2.ZERO
	Controls.touch_aim = Vector2.ZERO
	Controls.touch_fire = false


func _hit_button(pos: Vector2) -> String:
	for n: String in _buttons:
		if n == "interact" and not _interact_visible:
			continue
		var r: Rect2 = _buttons[n]
		if r.grow(4).has_point(pos):
			return n
	return ""


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		var pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * t.position
		if t.pressed:
			var btn: String = _hit_button(pos)
			if btn == "attack":
				_aim_touch = t.index
				_aim_origin = (_buttons["attack"] as Rect2).get_center()
				_aim_pos = pos
				Controls.touch_fire = true
				_update_aim()
			elif btn != "":
				_held[t.index] = btn
				_press(btn)
			elif pos.x < size.x * 0.45 and _move_touch == -1:
				_move_touch = t.index
				_move_origin = pos
				_move_pos = pos
			else:
				return
			get_viewport().set_input_as_handled()
		else:
			if t.index == _move_touch:
				_move_touch = -1
				Controls.touch_move = Vector2.ZERO
			elif t.index == _aim_touch:
				_aim_touch = -1
				Controls.touch_fire = false
				Controls.touch_aim = Vector2.ZERO
			_held.erase(t.index)
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		var pos2: Vector2 = get_global_transform_with_canvas().affine_inverse() * d.position
		if d.index == _move_touch:
			_move_pos = pos2
			var v: Vector2 = (_move_pos - _move_origin) / (JOY_RADIUS * _scale())
			# The base follows a finger that drags far, so the stick never "sticks".
			if v.length() > 1.0:
				_move_origin = _move_pos - v.normalized() * JOY_RADIUS * _scale()
				v = v.normalized()
			Controls.touch_move = v if v.length() > 0.15 else Vector2.ZERO
			get_viewport().set_input_as_handled()
		elif d.index == _aim_touch:
			_aim_pos = pos2
			_update_aim()
			get_viewport().set_input_as_handled()


func _update_aim() -> void:
	var v: Vector2 = _aim_pos - _aim_origin
	# Small drags = auto-aim (Controls.touch_aim zero lets aim assist pick a target).
	Controls.touch_aim = v.normalized() if v.length() > 10.0 * _scale() else Vector2.ZERO


func _press(btn: String) -> void:
	if player == null or not is_instance_valid(player):
		return
	match btn:
		"skill":
			player.try_skill()
		"dash":
			player.try_dash()
		"swap":
			player.swap_weapon()
		"interact":
			player.try_interact()
		"pause":
			pause_pressed.emit()


func _draw() -> void:
	if not visible:
		return
	var s: float = _scale()
	# movement stick (shown at rest bottom-left as a hint)
	var base_c: Vector2 = _move_origin if _move_touch != -1 else Vector2(56 * s, size.y - 56 * s)
	var base_tex: Texture2D = SpriteLib.texture("touch_joy_base")
	var knob_tex: Texture2D = SpriteLib.texture("touch_joy_knob")
	var bs: Vector2 = base_tex.get_size() * s
	draw_texture_rect(base_tex, Rect2(base_c - bs / 2.0, bs), false)
	var knob_c: Vector2 = base_c + Controls.touch_move * JOY_RADIUS * s
	var ks: Vector2 = knob_tex.get_size() * s
	draw_texture_rect(knob_tex, Rect2(knob_c - ks / 2.0, ks), false)
	for n: String in _buttons:
		if n == "interact" and not _interact_visible:
			continue
		var r: Rect2 = _buttons[n]
		var tex: Texture2D = SpriteLib.texture("touch_btn_" + n)
		var pressed: bool = n in _held.values() or (n == "attack" and _aim_touch != -1)
		draw_texture_rect(tex, r, false, Color(1, 1, 1, 1.0 if pressed else 0.8))
		if n == "skill" and player != null and is_instance_valid(player) and player.skill_cd_left > 0.0:
			var k: float = player.skill_cd_left / maxf(player.skill_cooldown_total(), 0.01)
			draw_rect(Rect2(r.position, Vector2(r.size.x, roundf(r.size.y * k))), Color(0, 0, 0, 0.6))
	if _aim_touch != -1 and Controls.touch_aim != Vector2.ZERO:
		var c: Vector2 = (_buttons["attack"] as Rect2).get_center()
		draw_line(c, c + Controls.touch_aim * 30.0 * s, UiTheme.RED, 1.0)
