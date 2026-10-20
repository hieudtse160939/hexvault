extends Node
## User settings: audio, video, effects, controls. Persisted separately from the profile
## so a damaged profile never wipes preferences (and vice versa).

var data: Dictionary = {}


func _ready() -> void:
	data = SaveManager.load_settings()
	_ensure_buses()
	apply()


func get_value(key: String) -> Variant:
	return data.get(key, SaveManager.settings_defaults().get(key))


func set_value(key: String, value: Variant, persist: bool = true) -> void:
	data[key] = value
	apply()
	if persist:
		SaveManager.save_settings(data)
	Events.settings_changed.emit()


func shake_scale() -> float:
	return float(get_value("screen_shake")) * (0.35 if reduced_effects() else 1.0)


func reduced_effects() -> bool:
	return bool(get_value("reduced_effects"))


func _ensure_buses() -> void:
	for bus_name: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")


static func _db(v: float) -> float:
	return linear_to_db(maxf(v, 0.0001))


func apply() -> void:
	AudioServer.set_bus_volume_db(0, _db(float(get_value("master_volume"))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _db(float(get_value("music_volume"))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), _db(float(get_value("sfx_volume"))))
	Engine.max_fps = int(get_value("max_fps"))
	if DisplayServer.get_name() == "headless":
		return
	var is_mobile: bool = OS.has_feature("mobile")
	if not is_mobile:
		var want_fs: bool = bool(get_value("fullscreen"))
		var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
		var is_fs: bool = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if want_fs != is_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_fs else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(get_value("vsync")) else DisplayServer.VSYNC_DISABLED)
