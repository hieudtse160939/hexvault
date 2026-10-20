class_name Breakable
extends StaticBody2D
## Crates (break, may drop coins) and explosive barrels (chain-react, hurt everyone nearby).

enum Kind { CRATE, BARREL }

var kind: int = Kind.CRATE
var tile: Vector2i
var hp: int = 3
var _sprite: AnimatedSprite2D
var _broken: bool = false


static func create(k: int, t: Vector2i) -> Breakable:
	var b: Breakable = Breakable.new()
	b.kind = k
	b.tile = t
	b.position = Level.to_world(t)
	b.hp = 3 if k == Kind.CRATE else 2
	b.collision_layer = Level.BREAKABLE_MASK
	b.collision_mask = 0
	var cs: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(14, 12)
	cs.shape = shape
	cs.position = Vector2(0, 1)
	b.add_child(cs)
	b._sprite = AnimatedSprite2D.new()
	b._sprite.sprite_frames = SpriteLib.frames("prop_crate" if k == Kind.CRATE else "prop_barrel")
	b._sprite.play(&"idle")
	b.add_child(b._sprite)
	b.add_to_group("breakables")
	return b


func receive_hit(info: HitInfo) -> bool:
	if _broken:
		return false
	hp -= maxi(info.damage, 1)
	FX.flash(_sprite)
	if hp <= 0:
		smash()
	return true


func smash() -> void:
	if _broken:
		return
	_broken = true
	var lvl: Level = Level.current
	if lvl != null:
		lvl.set_solid(tile, false)
	collision_layer = 0
	if kind == Kind.BARREL:
		Sfx.play("explosion")
		# Barrels hurt enemies and the player alike; deferred so chain reactions
		# do not recurse inside a physics query callback.
		Combat.explode.call_deferred(global_position, 30.0, 6, true, true)
		queue_free()
		return
	Sfx.play("crate_break")
	_sprite.play(&"break")
	FX.puff(global_position)
	if lvl != null and lvl.rng.randf() < 0.35:
		Pickup.spawn_coins(global_position, lvl.rng.randi_range(1, 3))
	z_index = -1
	var tw: Tween = create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)
