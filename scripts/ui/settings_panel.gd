class_name SettingsPanel
extends Modal
## Audio / video / effects / controls settings. Changes apply and save immediately.


func _ready() -> void:
	add_title("SETTINGS")
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 3)
	scroll.add_child(grid)
	_section(grid, "Audio")
	_slider(grid, "Master", "master_volume", 0.0, 1.0, 0.05)
	_slider(grid, "Music", "music_volume", 0.0, 1.0, 0.05)
	_slider(grid, "Effects", "sfx_volume", 0.0, 1.0, 0.05)
	_section(grid, "Video")
	if not OS.has_feature("mobile"):
		_toggle(grid, "Fullscreen", "fullscreen")
	_toggle(grid, "V-Sync", "vsync")
	_choice(grid, "FPS cap", "max_fps", [[0, "Unlimited"], [30, "30"], [60, "60"], [120, "120"]])
	_toggle(grid, "Show FPS", "show_fps")
	_section(grid, "Effects")
	_slider(grid, "Screen shake", "screen_shake", 0.0, 1.5, 0.1)
	_toggle(grid, "Reduced effects", "reduced_effects")
	_toggle(grid, "Damage numbers", "damage_numbers")
	_section(grid, "Controls")
	_toggle(grid, "Aim assist", "aim_assist")
	_choice(grid, "Touch controls", "touch_controls", [["auto", "Auto"], ["on", "On"], ["off", "Off"]])
	_slider(grid, "Touch UI scale", "ui_scale", 0.6, 1.6, 0.1)
	_slider(grid, "Touch opacity", "touch_opacity", 0.2, 1.0, 0.1)
	if int(Profile.data["difficulty_unlocked"]) > 0:
		_section(grid, "Game")
		_choice(grid, "Difficulty", "difficulty", [[0, "Normal"], [1, "Heroic"]])
	add_button("Back", queue_free)
	super._ready()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		queue_free()


func _section(grid: GridContainer, text: String) -> void:
	grid.add_child(UiTheme.label(text.to_upper(), UiTheme.GOLD))
	grid.add_child(Control.new())


func _slider(grid: GridContainer, text: String, key: String, lo: float, hi: float, step: float) -> void:
	grid.add_child(UiTheme.label(text))
	var row: HBoxContainer = HBoxContainer.new()
	var s: HSlider = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_value(key))
	s.custom_minimum_size = Vector2(90, 10)
	s.focus_mode = Control.FOCUS_ALL
	var val: Label = UiTheme.label("%d%%" % int(round(s.value * 100)), UiTheme.DIM)
	s.value_changed.connect(func(v: float) -> void:
		val.text = "%d%%" % int(round(v * 100))
		Settings.set_value(key, v, false))
	s.drag_ended.connect(func(_c: bool) -> void: SaveManager.save_settings(Settings.data))
	s.focus_exited.connect(func() -> void: SaveManager.save_settings(Settings.data))
	row.add_child(s)
	row.add_child(val)
	grid.add_child(row)


func _toggle(grid: GridContainer, text: String, key: String) -> void:
	grid.add_child(UiTheme.label(text))
	var c: CheckBox = CheckBox.new()
	c.button_pressed = bool(Settings.get_value(key))
	c.text = "On" if c.button_pressed else "Off"
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(func(on: bool) -> void:
		c.text = "On" if on else "Off"
		Sfx.play("ui_click")
		Settings.set_value(key, on))
	grid.add_child(c)


func _choice(grid: GridContainer, text: String, key: String, options: Array) -> void:
	grid.add_child(UiTheme.label(text))
	var b: Button = Button.new()
	b.focus_mode = Control.FOCUS_ALL
	var idx: Array[int] = [0]
	for i: int in options.size():
		if str(options[i][0]) == str(Settings.get_value(key)):
			idx[0] = i
	b.text = str(options[idx[0]][1])
	b.pressed.connect(func() -> void:
		idx[0] = (idx[0] + 1) % options.size()
		b.text = str(options[idx[0]][1])
		Sfx.play("ui_click")
		Settings.set_value(key, options[idx[0]][0]))
	grid.add_child(b)
