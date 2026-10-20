class_name Interactable
extends Node2D
## Base for things the player can use with the interact action.
## Subclasses override can_interact / interact_text / interact.

var label: Label = null


func _ready() -> void:
	add_to_group("interactables")


func can_interact(_p: Player) -> bool:
	return true


func interact_text() -> String:
	return "Use"


func interact(_p: Player) -> void:
	pass


## Small world-space caption under/over the object (price tags, names).
func set_caption(text: String, color: Color = UiTheme.TEXT, y: float = 10.0) -> void:
	if label == null:
		label = UiTheme.label("", color, true)
		label.add_theme_font_override("font", SpriteLib.font())
		label.z_index = 25
		add_child(label)
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.position = Vector2(-text.length() * 3.0, y)
