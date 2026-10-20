class_name Modal
extends Control
## Base for full-screen overlays: dims the game, centres a panel, keeps working
## while the tree is paused, and gives the first button keyboard/gamepad focus.

var panel: PanelContainer
var box: VBoxContainer


func _init() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	center.add_child(panel)
	box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)


func add_title(text: String, color: Color = UiTheme.GOLD) -> Label:
	var l: Label = UiTheme.label(text, color, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	return l


func add_text(text: String, color: Color = UiTheme.TEXT, width: float = 220.0) -> Label:
	var l: Label = UiTheme.label(text, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	return l


func add_button(text: String, cb: Callable) -> Button:
	var b: Button = UiTheme.button(text, cb)
	box.add_child(b)
	return b


func focus_first() -> void:
	for c: Node in find_children("*", "Button", true, false):
		var b: Button = c as Button
		if b != null and not b.disabled and b.is_visible_in_tree():
			b.grab_focus()
			return


func _ready() -> void:
	focus_first.call_deferred()
