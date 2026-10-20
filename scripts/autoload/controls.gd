extends Node
## Input actions, active-device tracking and the touch input bridge.
##
## Actions are registered in code so the bindings live in one reviewable place.
## Keys use physical keycodes so WASD stays WASD on AZERTY/QWERTZ layouts.

enum Device { KEYBOARD_MOUSE, GAMEPAD, TOUCH }

signal device_changed(device: int)

const DEADZONE: float = 0.2

var device: int = Device.KEYBOARD_MOUSE
## Written by the on-screen controls (ui/touch_controls.gd).
var touch_move: Vector2 = Vector2.ZERO
var touch_aim: Vector2 = Vector2.ZERO
var touch_fire: bool = false
var _touch_seen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	register_actions()
	if DisplayServer.is_touchscreen_available() and OS.has_feature("mobile"):
		_set_device(Device.TOUCH)


static func _key(code: Key) -> InputEventKey:
	var e: InputEventKey = InputEventKey.new()
	e.physical_keycode = code
	return e


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = button
	return e


static func _pad(button: JoyButton) -> InputEventJoypadButton:
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	e.button_index = button
	return e


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e: InputEventJoypadMotion = InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


static func bindings() -> Dictionary:
	return {
		"move_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _pad(JOY_BUTTON_DPAD_LEFT)],
		"move_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _pad(JOY_BUTTON_DPAD_RIGHT)],
		"move_up": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _pad(JOY_BUTTON_DPAD_UP)],
		"move_down": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _pad(JOY_BUTTON_DPAD_DOWN)],
		"aim_left": [_axis(JOY_AXIS_RIGHT_X, -1.0)],
		"aim_right": [_axis(JOY_AXIS_RIGHT_X, 1.0)],
		"aim_up": [_axis(JOY_AXIS_RIGHT_Y, -1.0)],
		"aim_down": [_axis(JOY_AXIS_RIGHT_Y, 1.0)],
		"fire": [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_J), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"skill": [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_Q), _key(KEY_K), _pad(JOY_BUTTON_LEFT_SHOULDER)],
		"dash": [_key(KEY_SPACE), _key(KEY_SHIFT), _pad(JOY_BUTTON_A), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		"swap_weapon": [_key(KEY_TAB), _key(KEY_X), _mouse(MOUSE_BUTTON_WHEEL_UP), _mouse(MOUSE_BUTTON_WHEEL_DOWN), _pad(JOY_BUTTON_Y)],
		"interact": [_key(KEY_E), _key(KEY_F), _pad(JOY_BUTTON_X)],
		"reload": [_key(KEY_R), _pad(JOY_BUTTON_B)],
		"pause": [_key(KEY_ESCAPE), _key(KEY_P), _pad(JOY_BUTTON_START)],
		"toggle_map": [_key(KEY_M), _pad(JOY_BUTTON_BACK)],
		"inventory": [_key(KEY_I), _key(KEY_C), _pad(JOY_BUTTON_RIGHT_SHOULDER)],
		"dev_menu": [_key(KEY_F1), _key(KEY_QUOTELEFT)],
	}


static func register_actions() -> void:
	var b: Dictionary = bindings()
	for action: String in b:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, DEADZONE if action.begins_with("move") or action.begins_with("aim") else 0.5)
		for ev: InputEvent in b[action]:
			InputMap.action_add_event(action, ev)
	# Gamepad confirm/cancel for menus on top of Godot's built-in ui_* actions.
	InputMap.action_add_event("ui_accept", _pad(JOY_BUTTON_A))
	InputMap.action_add_event("ui_cancel", _pad(JOY_BUTTON_B))


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch_seen = true
		_set_device(Device.TOUCH)
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		_set_device(Device.GAMEPAD)
	elif event is InputEventKey or (event is InputEventMouseButton and not _from_touch(event)):
		_set_device(Device.KEYBOARD_MOUSE)
	elif event is InputEventMouseMotion and not _from_touch(event) and (event as InputEventMouseMotion).relative.length() > 2.0:
		_set_device(Device.KEYBOARD_MOUSE)


func _from_touch(_event: InputEvent) -> bool:
	# Emulated mouse events arrive right after touches on mobile; ignore them there.
	return OS.has_feature("mobile") or (device == Device.TOUCH and _touch_seen)


func _set_device(d: int) -> void:
	if d != device:
		device = d
		device_changed.emit(d)


## Whether to show on-screen touch controls, honouring the user setting.
func touch_ui_enabled() -> bool:
	match str(Settings.get_value("touch_controls")):
		"on":
			return true
		"off":
			return false
	return OS.has_feature("mobile") or device == Device.TOUCH


func move_vector() -> Vector2:
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_move.length() > v.length():
		v = touch_move
	return v.limit_length(1.0)


## Stick/touch aim direction, or ZERO when the player is not actively aiming that way.
func stick_aim() -> Vector2:
	if device == Device.TOUCH:
		return touch_aim
	var v: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	return v if v.length() > 0.3 else Vector2.ZERO


func fire_held() -> bool:
	if device == Device.TOUCH:
		return touch_fire
	return Input.is_action_pressed("fire")


## Prompt text for an action on the active device, read from the actual
## InputMap binding ("E", "X button", "USE") so prompts never show a key that
## is not bound.
func action_label(action: String) -> String:
	if device == Device.TOUCH:
		return "USE" if action == "interact" else action.capitalize()
	if not InputMap.has_action(action):
		return "?"
	for ev: InputEvent in InputMap.action_get_events(action):
		if device == Device.GAMEPAD and ev is InputEventJoypadButton:
			return {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
				JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "Back",
				JOY_BUTTON_START: "Start"}.get((ev as InputEventJoypadButton).button_index, "Pad")
		if device == Device.KEYBOARD_MOUSE and ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
		if device == Device.KEYBOARD_MOUSE and ev is InputEventMouseButton:
			return {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB"}.get((ev as InputEventMouseButton).button_index, "Mouse")
	return "?"
