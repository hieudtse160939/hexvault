class_name Projectile
extends AnimatedSprite2D
## One pooled projectile. Simulated by ProjectilePool (not by its own _process).

var active: bool = false
var velocity: Vector2 = Vector2.ZERO
var from_player: bool = true
var damage: int = 1
var crit: bool = false
var knockback: float = 40.0
var pierce: int = 0
var homing: float = 0.0
var range_left: float = 200.0
var element: String = ""
var status_chance: float = 0.0
var explosion_radius: float = 0.0
var explosion_damage: int = 0
var radius: float = 2.0
var source_id: String = ""
var hit_rids: Array[RID] = []
var impact_fx: String = "impact"


func reset() -> void:
	active = false
	visible = false
	velocity = Vector2.ZERO
	pierce = 0
	homing = 0.0
	crit = false
	element = ""
	status_chance = 0.0
	explosion_radius = 0.0
	explosion_damage = 0
	radius = 2.0
	hit_rids.clear()
	modulate = Color.WHITE
	scale = Vector2.ONE
