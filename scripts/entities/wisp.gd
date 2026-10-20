class_name Wisp
extends Node2D
## Necromancer summon: a spirit that orbits its owner and shoots the nearest
## visible enemy. Fades out when its time is up.

var owner_player: Player = null
var life: float = 8.0
var angle: float = 0.0
var _cd: float = 0.0
var _sprite: AnimatedSprite2D


static func create(p: Player, start_angle: float, duration: float) -> Wisp:
	var w: Wisp = Wisp.new()
	w.owner_player = p
	w.angle = start_angle
	w.life = duration
	w.position = p.global_position + Vector2.from_angle(start_angle) * 18.0
	return w


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	SpriteLib.apply(_sprite, "proj_orb_teal", 1.6)
	_sprite.modulate = Color(0.6, 1.0, 0.7, 0.9)
	_sprite.play(&"idle")
	add_child(_sprite)
	_cd = randf_range(0.1, 0.5)
	FX.burst("sparkle_teal", global_position)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0 or owner_player == null or not is_instance_valid(owner_player) or not owner_player.is_alive():
		FX.burst("puff", global_position)
		queue_free()
		return
	if life < 1.0:
		_sprite.modulate.a = life
	angle += delta * 2.6
	var target_pos: Vector2 = owner_player.global_position + Vector2.from_angle(angle) * 18.0 + Vector2(0, -6)
	global_position = global_position.lerp(target_pos, minf(delta * 10.0, 1.0))
	_cd -= delta
	var lvl: Level = Level.current
	if lvl == null or _cd > 0.0:
		return
	var t: Node2D = lvl.nearest_enemy(global_position, 150.0, true)
	if t == null:
		return
	_cd = 0.55
	var dir: Vector2 = (t.global_position - global_position).normalized()
	var p: Projectile = lvl.pool.acquire()
	p.from_player = true
	p.damage = Damage.compute(2, 1.0 + owner_player.weapon_mod("damage_mult"), false)
	p.knockback = 15.0
	p.homing = 3.0
	p.range_left = 180.0
	p.element = "hex"
	p.status_chance = 0.15
	lvl.pool.launch(p, global_position, dir * 180.0, "proj_orb_teal")
	Sfx.play("magic", -14.0)
