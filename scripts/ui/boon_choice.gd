class_name BoonChoice
extends Modal
## Reward screen: pick one of three run boons.

signal chosen(id: String)

var title: String = "Choose a boon"
var choices: Array[String] = []


func _ready() -> void:
	add_title(title.to_upper())
	add_text("Choose one blessing for this run", UiTheme.DIM)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for id: String in choices:
		var b: Dictionary = Db.boons.get(id, {})
		var card: Button = Button.new()
		card.custom_minimum_size = Vector2(96, 92)
		card.focus_mode = Control.FOCUS_ALL
		var v: VBoxContainer = VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 4
		v.offset_right = -4
		v.offset_top = 6
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon: TextureRect = TextureRect.new()
		icon.texture = SpriteLib.texture(str(b.get("icon", "icon_boon_power")))
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.custom_minimum_size = Vector2(16, 18)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(icon)
		var n: Label = UiTheme.label(str(b.get("name", id)), UiTheme.ACCENT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(n)
		var stacks: int = int(Game.run.boons.get(id, 0)) if Game.run != null else 0
		var d: Label = UiTheme.label(str(b.get("description", "")) + ("\n(owned x%d)" % stacks if stacks > 0 else ""), UiTheme.TEXT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.custom_minimum_size = Vector2(88, 0)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(d)
		card.add_child(v)
		card.pressed.connect(func() -> void:
			Sfx.play("ui_click")
			chosen.emit(id)
			queue_free())
		card.focus_entered.connect(func() -> void: Sfx.play("ui_move", -6.0))
		row.add_child(card)
	super._ready()
