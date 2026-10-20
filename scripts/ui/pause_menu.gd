class_name PauseMenu
extends Modal
## Pause overlay: resume, settings, run info, abandon.

signal closed


func _ready() -> void:
	add_title("PAUSED")
	var run: RunState = Game.run
	if run != null:
		var c: CharacterData = Db.character(run.character_id)
		add_text("%s  -  Floor %d/%d  -  %d kills" % [c.display_name, run.floor_index, run.total_floors, run.kills], UiTheme.DIM)
		if not run.boons.is_empty():
			var names: PackedStringArray = []
			for id: String in run.boons:
				names.append("%s x%d" % [Db.boons[id]["name"], run.boons[id]] if int(run.boons[id]) > 1 else str(Db.boons[id]["name"]))
			add_text("Boons: " + ", ".join(names), UiTheme.ACCENT)
	add_button("Resume", _close)
	if run != null:
		add_button("Inventory", func() -> void: add_child(InventoryPanel.new()))
	add_button("Settings", func() -> void:
		var s: SettingsPanel = SettingsPanel.new()
		add_child(s))
	add_button("Retreat to the Guild", func() -> void:
		var confirm: Modal = Modal.new()
		confirm.add_title("Abandon this expedition?", UiTheme.RED)
		confirm.add_text("Items and experience are kept; it counts as a failed mission.", UiTheme.DIM)
		confirm.add_button("Yes, retreat", func() -> void:
			get_tree().paused = false
			Game.abandon_run())
		confirm.add_button("Cancel", confirm.queue_free)
		add_child(confirm))
	super._ready()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()
