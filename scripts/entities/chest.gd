class_name Chest
extends Interactable
## Opens to reveal a weapon (weapon chest) or coins + supplies (loot chest).

enum Kind { WEAPON, LOOT }

var kind: int = Kind.LOOT
var opened: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sprite: AnimatedSprite2D


static func create(k: int, pos: Vector2, seed_value: int) -> Chest:
	var c: Chest = Chest.new()
	c.kind = k
	c.position = pos
	c.rng.seed = seed_value
	return c


func _ready() -> void:
	super._ready()
	_sprite = AnimatedSprite2D.new()
	SpriteLib.apply(_sprite, "prop_chest")
	_sprite.play(&"closed")
	if kind == Kind.WEAPON:
		_sprite.modulate = Color(0.85, 1.0, 1.15)
	add_child(_sprite)
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = Level.WORLD_MASK
	var cs: CollisionShape2D = CollisionShape2D.new()
	var sh: RectangleShape2D = RectangleShape2D.new()
	sh.size = Vector2(12, 7)
	cs.shape = sh
	cs.position = Vector2(0, 4)
	body.add_child(cs)
	add_child(body)


func can_interact(_p: Player) -> bool:
	return not opened


func interact_text() -> String:
	return "Open chest"


func interact(_p: Player) -> void:
	if opened:
		return
	opened = true
	_sprite.play(&"open")
	Sfx.play("chest")
	FX.burst("sparkle", global_position + Vector2(0, -6))
	Events.chest_opened.emit()
	var lvl: Level = Level.current
	if lvl == null:
		return
	var floor_i: int = Game.run.floor_index if Game.run != null else 1
	if kind == Kind.WEAPON:
		var held: Array = Game.run.weapons if Game.run != null else []
		var id: String = WeaponPickup.roll(rng, floor_i, held)
		lvl.add_entity(WeaponPickup.create(id, global_position + Vector2(0, 14)))
	else:
		Pickup.spawn_coins(global_position + Vector2(0, 6), rng.randi_range(6, 12) + floor_i * 3)
		if rng.randf() < 0.6:
			Pickup.spawn(Pickup.Kind.HEART if rng.randf() < 0.5 else Pickup.Kind.ARMOR, global_position + Vector2(0, 8), 1)
		if rng.randf() < 0.5:
			Pickup.spawn(Pickup.Kind.SHARD, global_position + Vector2(0, 8), 1 + floor_i)
