class_name Fountain
extends Interactable
## Healing room: restores HP and armor once.

var used: bool = false
var _sprite: AnimatedSprite2D


func _ready() -> void:
	super._ready()
	_sprite = AnimatedSprite2D.new()
	SpriteLib.apply(_sprite, "prop_fountain")
	_sprite.play(&"idle")
	add_child(_sprite)
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = Level.WORLD_MASK
	var cs: CollisionShape2D = CollisionShape2D.new()
	var sh: CircleShape2D = CircleShape2D.new()
	sh.radius = 6.0
	cs.shape = sh
	cs.position = Vector2(0, 3)
	body.add_child(cs)
	add_child(body)
	set_caption("Bloodspring", UiTheme.RED, 10.0)


func can_interact(_p: Player) -> bool:
	return not used


func interact_text() -> String:
	return "Drink (restore all HP)"


func interact(p: Player) -> void:
	used = true
	p.heal(p.health.max_hp)
	p.health.restore_armor(p.health.max_armor)
	_sprite.stop()
	_sprite.modulate = Color(0.6, 0.6, 0.7)
	set_caption("Dry", UiTheme.DIM, 10.0)
