class_name SolidProp
extends StaticBody2D
## Indestructible decorative obstacle (pillar, lamp, statue base).


static func create(sprite_key: String, pos: Vector2, box: Vector2, sprite_offset: Vector2) -> SolidProp:
	var p: SolidProp = SolidProp.new()
	p.position = pos
	p.collision_layer = Level.WORLD_MASK
	p.collision_mask = 0
	var cs: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = box
	cs.shape = shape
	cs.position = Vector2(0, 2)
	p.add_child(cs)
	var spr: AnimatedSprite2D = AnimatedSprite2D.new()
	spr.sprite_frames = SpriteLib.frames(sprite_key)
	spr.offset = sprite_offset
	spr.play(&"idle")
	p.add_child(spr)
	return p
