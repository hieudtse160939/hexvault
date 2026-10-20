class_name HeroSelect
extends Modal
## Character selection and unlocking.

signal selected(id: String)

var _detail: Label
var _action: Button
var _current: String = ""
var _preview: AnimatedSprite2D
var _row: HBoxContainer


func _ready() -> void:
	add_title("HERO SHRINE")
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_row)
	var holder: Control = Control.new()
	holder.custom_minimum_size = Vector2(240, 34)
	box.add_child(holder)
	_preview = AnimatedSprite2D.new()
	_preview.position = Vector2(120, 16)
	holder.add_child(_preview)
	_detail = add_text("", UiTheme.TEXT, 240)
	_action = add_button("", _on_action)
	add_button("Close", queue_free)
	_rebuild()
	_show(str(Profile.data["selected_character"]))
	super._ready()


func _rebuild() -> void:
	for c: Node in _row.get_children():
		c.queue_free()
	for id: String in Db.character_order:
		var c: CharacterData = Db.character(id)
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(40, 30)
		b.icon = SpriteLib.still(c.sprite)
		b.expand_icon = false
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.focus_mode = Control.FOCUS_ALL
		if not Profile.is_character_unlocked(id):
			b.modulate = Color(0.45, 0.45, 0.55)
		b.pressed.connect(func() -> void:
			Sfx.play("ui_click")
			_show(id))
		b.focus_entered.connect(func() -> void: _show(id))
		_row.add_child(b)


func _show(id: String) -> void:
	_current = id
	var c: CharacterData = Db.character(id)
	SpriteLib.apply(_preview, c.sprite, 2.0)
	_preview.play(&"run")
	var w: WeaponData = Db.weapon(c.start_weapon)
	var txt: String = "%s the %s\nHP %d  Armor %d  Speed %d\nStarts with: %s\n%s" % [
		c.display_name, c.title, c.max_hp, c.max_armor, int(c.speed), w.display_name if w != null else "?", c.description]
	_detail.text = txt
	if Profile.is_character_unlocked(id):
		_action.text = "Selected" if str(Profile.data["selected_character"]) == id else "Select"
		_action.disabled = false
	else:
		match str(c.unlock.get("type", "")):
			"shards":
				var cost: int = int(c.unlock.get("cost", 0))
				_action.text = "Unlock (%d shards)" % cost
				_action.disabled = Profile.shards() < cost
			"achievement":
				var a: Dictionary = Db.achievements.get(str(c.unlock.get("id", "")), {})
				_action.text = "Locked: %s" % a.get("name", "?")
				_action.disabled = true


func _on_action() -> void:
	if Profile.is_character_unlocked(_current):
		selected.emit(_current)
		Sfx.play("boon")
		_show(_current)
	elif Profile.buy_character(_current):
		Sfx.play("buy")
		_rebuild()
		_show(_current)
	else:
		Sfx.play("ui_deny")
