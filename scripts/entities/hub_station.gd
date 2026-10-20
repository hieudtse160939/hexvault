class_name HubStation
extends Interactable
## A hub object that opens a menu when used.

var title: String = ""
var prompt: String = ""
var sprite_key: String = ""
var on_use: Callable = Callable()
var badge: Callable = Callable() # optional: returns int notifications (quests ready)
var box: Vector2 = Vector2(12, 6)  # collision footprint (world units), centred on the base
var flip: bool = false
var _badge_label: Label
var sprite: AnimatedSprite2D


static func create(t: String, p: String, sprite_name: String, pos: Vector2, cb: Callable, footprint: Vector2 = Vector2(12, 6)) -> HubStation:
	var s: HubStation = HubStation.new()
	s.title = t
	s.prompt = p
	s.sprite_key = sprite_name
	s.position = pos
	s.on_use = cb
	s.box = footprint
	return s


func _ready() -> void:
	super._ready()
	var spr: AnimatedSprite2D = AnimatedSprite2D.new()
	SpriteLib.apply(spr, sprite_key)
	spr.play(&"idle" if spr.sprite_frames.has_animation(&"idle") else spr.sprite_frames.get_animation_names()[0])
	var top: float = -16.0
	if SpriteLib.is_hd(sprite_key):
		# HD art stands on its pivot (feet / base) at the node origin + 5
		spr.position = Vector2(0, 5) - SpriteLib.pivot_from_centre_world(sprite_key)
		top = 5.0 - SpriteLib.pivot_world(sprite_key).y
	elif SpriteLib.frame_size(sprite_key).y > 16:
		spr.offset = Vector2(0, -8)
	spr.flip_h = flip
	sprite = spr
	add_child(spr)
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = Level.WORLD_MASK
	var cs: CollisionShape2D = CollisionShape2D.new()
	var sh: RectangleShape2D = RectangleShape2D.new()
	sh.size = box
	cs.shape = sh
	cs.position = Vector2(0, 5 - box.y / 2.0 + 3.0)
	body.add_child(cs)
	add_child(body)
	set_caption(title, UiTheme.GOLD, 10.0)
	_badge_label = UiTheme.label("", UiTheme.RED, true)
	_badge_label.position = Vector2(6, top - 6)
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
