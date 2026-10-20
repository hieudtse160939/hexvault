class_name Turret
extends Node2D
## Tinker skill: stationary auto-turret that fires at the nearest visible enemy.

var life: float = 10.0
var owner_player: Player = null
var _cd: float = 0.0
var _sprite: AnimatedSprite2D


static func create(pos: Vector2, duration: float, p: Player) -> Turret:
	var t: Turret = Turret.new()
	t.position = pos
	t.life = duration
	t.owner_player = p
	return t


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = SpriteLib.frames("turret")
	_sprite.play(&"idle")
	add_child(_sprite)
	FX.burst("puff", global_position)


func _physics_process(delta: float) -> void:
	life -= delta
	_cd -= delta
	if life <= 0.0:
		FX.burst("puff", global_position)
		queue_free()
		return
	if life < 2.0:
		visible = fmod(life, 0.2) > 0.1
	var lvl: Level = Level.current
	if lvl == null or _cd > 0.0:
		return
	var target: Node2D = lvl.nearest_enemy(global_position, 170.0, true)
	if target == null:
		return
	_cd = 0.22
	var dir: Vector2 = (target.global_position - global_position).normalized()
	_sprite.flip_h = dir.x < 0.0
	var p: Projectile = lvl.pool.acquire()
	p.from_player = true
	var mult: float = 1.0 + (owner_player.weapon_mod("damage_mult") if owner_player != null and is_instance_valid(owner_player) else 0.0)
	p.damage = Damage.compute(2, mult, false)
	p.knockback = 20.0
	p.range_left = 200.0
	lvl.pool.launch(p, global_position + dir * 8.0 + Vector2(0, -2), dir * 300.0, "proj_bullet")
	Sfx.play("shoot_rifle", -10.0)
