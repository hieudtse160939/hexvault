class_name HubStation
extends Interactable
## A hub object that opens a menu when used.

var title: String = ""
var prompt: String = ""
var sprite_key: String = ""
var on_use: Callable = Callable()
var badge: Callable = Callable() # optional: returns int notifications (quests ready)
var _badge_label: Label


static func create(t: String, p: String, sprite: String, pos: Vector2, cb: Callable) -> HubStation:
	var s: HubStation = HubStation.new()
	s.title = t
	s.prompt = p
	s.sprite_key = sprite
	s.position = pos
	s.on_use = cb
	return s


func _ready() -> void:
	super._ready()
	var spr: AnimatedSprite2D = AnimatedSprite2D.new()
	spr.sprite_frames = SpriteLib.frames(sprite_key)
	spr.play(spr.sprite_frames.get_animation_names()[0])
	if SpriteLib.frame_size(sprite_key).y > 16:
		spr.offset = Vector2(0, -8)
	add_child(spr)
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = Level.WORLD_MASK
	var cs: CollisionShape2D = CollisionShape2D.new()
	var sh: RectangleShape2D = RectangleShape2D.new()
	sh.size = Vector2(12, 6)
	cs.shape = sh
	cs.position = Vector2(0, 5)
	body.add_child(cs)
	add_child(body)
	set_caption(title, UiTheme.GOLD, 10.0)
	_badge_label = UiTheme.label("", UiTheme.RED, true)
	_badge_label.position = Vector2(6, -22)
	add_child(_badge_label)


func _process(_delta: float) -> void:
	if badge.is_valid():
		var n: int = int(badge.call())
		_badge_label.text = "!" if n > 0 else ""


func interact_text() -> String:
	return prompt


func interact(_p: Player) -> void:
	if on_use.is_valid():
		on_use.call()
