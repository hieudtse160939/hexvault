extends Node
## Root of the game. Holds the active screen and global overlays (toasts, FPS,
## dev menu) and pauses on focus loss.

var _screen: Node = null
var _overlay: CanvasLayer
var _fps_label: Label
var _toast_box: VBoxContainer
var _dev_menu: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.main = self
	get_window().min_size = Vector2i(480, 270)
	_overlay = CanvasLayer.new()
	_overlay.layer = 50
	add_child(_overlay)
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	_overlay.add_child(root)
	_fps_label = Label.new()
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_fps_label.offset_top = -12
	_fps_label.offset_left = 4
	_fps_label.add_theme_color_override("font_color", Color("#7dc94a"))
	root.add_child(_fps_label)
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_box.offset_top = 24
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_toast_box)
	Events.toast.connect(_on_toast)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	Game.goto("title")
	if "--smoke-dungeon" in args:
		Game.start_run("ranger", 12345)
	for a: String in args:
		if a.begins_with("--tour=") and OS.is_debug_build():
			var tour: Node = (load("res://scripts/debug/screenshot_tour.gd") as GDScript).new()
			tour.set("out_dir", a.substr(7))
			add_child(tour)


func set_screen(node: Node) -> void:
	if _screen != null:
		_screen.queue_free()
	if node is Control:
		# Controls need a CanvasLayer/Control parent to resolve full-rect anchors.
		var holder: CanvasLayer = CanvasLayer.new()
		holder.name = "ScreenUI"
		holder.add_child(node)
		_screen = holder
	else:
		_screen = node
	add_child(_screen)
	move_child(_screen, 0)


func _process(_delta: float) -> void:
	_fps_label.visible = bool(Settings.get_value("show_fps"))
	if _fps_label.visible:
		_fps_label.text = "%d FPS  %.1f ms" % [Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 1.0)]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_menu") and (OS.is_debug_build() or OS.has_feature("editor")):
		_toggle_dev_menu()
		get_viewport().set_input_as_handled()


func _toggle_dev_menu() -> void:
	if _dev_menu != null and is_instance_valid(_dev_menu):
		_dev_menu.queue_free()
		_dev_menu = null
		return
	_dev_menu = (load("res://scripts/ui/dev_menu.gd") as GDScript).new()
	(_overlay.get_child(0) as Control).add_child(_dev_menu)


func _exit_tree() -> void:
	# Drop static caches so the engine does not report them as leaks at exit.
	UiTheme._theme = null
	Tiles._tileset = null
	FX.camera = null


func _notification(what: int) -> void:
	# Pause automatically when the window/app loses focus during a run.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if Game.current_screen == "dungeon" and _screen != null and _screen.has_method("request_pause"):
			_screen.call("request_pause")
		Profile.save()


func _on_toast(text: String) -> void:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color("#ffe28a"))
	l.add_theme_color_override("font_outline_color", Color("#14101e"))
	l.add_theme_constant_override("outline_size", 2)
	_toast_box.add_child(l)
	var tw: Tween = l.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
