class_name EventStatue
extends Interactable
## Event room: "Blood Pact" - offer 2 HP (never lethal) for a choice of boons.

var used: bool = false


func _ready() -> void:
	super._ready()
	var s: Sprite2D = Sprite2D.new()
	SpriteLib.apply(s, "prop_statue")
	s.offset = Vector2(0, -8)
	add_child(s)
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = Level.WORLD_MASK
	var cs: CollisionShape2D = CollisionShape2D.new()
	var sh: RectangleShape2D = RectangleShape2D.new()
	sh.size = Vector2(12, 6)
	cs.shape = sh
	cs.position = Vector2(0, 5)
	body.add_child(cs)
	add_child(body)
	set_caption("Pact Idol", UiTheme.ACCENT, 10.0)


func can_interact(p: Player) -> bool:
	return not used and p.health.hp > 1


func interact_text() -> String:
	return "Blood Pact: pay 2 HP for a boon"


func interact(p: Player) -> void:
	used = true
	var cost: int = mini(2, p.health.hp - 1)
	p.health.hp -= cost
	p.health.changed.emit(p.health.hp, p.health.max_hp, p.health.armor, p.health.max_armor)
	FX.flash(p.body, UiTheme.RED, 0.3)
	FX.float_text(p.global_position, "-%d HP" % cost, UiTheme.RED)
	Sfx.play("boss_phase", -10.0)
	set_caption("Spent", UiTheme.DIM, 10.0)
	var floor_node: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if floor_node != null:
		floor_node.call("offer_boons", "The idol accepts your blood")
