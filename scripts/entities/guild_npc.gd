class_name GuildNpc
extends Interactable
## A townsperson / adventurer in an authored map. Shows a speech bubble ("!" or
## "...") above the head; with dialogue lines it can be talked to (interact),
## which asks the map screen (group "guild") to show a dialogue box.

var sprite_key: String = ""
var display_name: String = ""
var lines: PackedStringArray = []
var bubble: String = ""
var flip: bool = false
var _line: int = 0
var _bubble_node: Node2D


func _ready() -> void:
	super._ready()
	var s: AnimatedSprite2D = AnimatedSprite2D.new()
	SpriteLib.apply(s, sprite_key)
	s.play(&"idle")
	s.flip_h = flip
	s.position = Vector2(0, Player.FEET_Y) - SpriteLib.pivot_from_centre_world(sprite_key)
	add_child(s)
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = Level.WORLD_MASK
	var cs: CollisionShape2D = CollisionShape2D.new()
	var sh: CircleShape2D = CircleShape2D.new()
	sh.radius = 4.0
	cs.shape = sh
	cs.position = Vector2(0, 4)
	body.add_child(cs)
	add_child(body)
	var l: Label = UiTheme.label(display_name, Color("#b4fff0"), true)
	l.add_theme_font_override("font", SpriteLib.font())
	l.position = Vector2(-display_name.length() * 3.0, 9)
	l.z_index = 25
	l.modulate = Color(1, 1, 1, 0.85)
	add_child(l)
	if bubble != "":
		_bubble_node = SpeechBubble.new()
		(_bubble_node as SpeechBubble).text = bubble
		_bubble_node.position = Vector2(0, -34)
		_bubble_node.z_index = 26
		add_child(_bubble_node)
		var tw: Tween = _bubble_node.create_tween().set_loops()
		tw.tween_property(_bubble_node, "position:y", -36.0, 0.6)
		tw.tween_property(_bubble_node, "position:y", -34.0, 0.6)


func can_interact(_p: Player) -> bool:
	return not lines.is_empty()


func interact_text() -> String:
	return "Talk to %s" % display_name.get_slice(",", 0)


func interact(_p: Player) -> void:
	if lines.is_empty():
		return
	var screen: Node = get_tree().get_first_node_in_group("guild")
	if screen != null and screen.has_method("show_dialogue"):
		screen.call("show_dialogue", display_name, lines[_line % lines.size()])
	_line += 1


## White speech bubble with a tail, drawn in world space ("!" or "...").
class SpeechBubble extends Node2D:
	var text: String = "!"

	func _draw() -> void:
		var f: Font = SpriteLib.font()
		var w: float = maxf(f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 6.0, 9.0)
		var r: Rect2 = Rect2(-w / 2.0, -10.0, w, 10.0)
		draw_rect(r.grow(1.0), Color("#14101e"))
		draw_rect(r, Color("#f4f1ff"))
		draw_colored_polygon(PackedVector2Array([Vector2(-2, 0), Vector2(2, 0), Vector2(0, 3)]), Color("#f4f1ff"))
		draw_string(f, Vector2(-w / 2.0 + 3.0, -2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#14101e"))
