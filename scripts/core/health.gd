class_name Health
extends Node
## HP + regenerating armor + post-hit invulnerability.

signal changed(hp: int, max_hp: int, armor: int, max_armor: int)
signal damaged(amount: int, info: HitInfo)
signal died

@export var max_hp: int = 10
@export var max_armor: int = 0
@export var invuln_time: float = 0.0
@export var armor_regen_delay: float = 3.5
@export var armor_regen_interval: float = 1.2

var hp: int = 10
var armor: int = 0
var dead: bool = false
var invulnerable: bool = false # external override (dash, skills, cutscenes)
var regen_mult: float = 1.0
var _invuln_left: float = 0.0
var _since_hit: float = 0.0
var _regen_acc: float = 0.0


func setup(p_max_hp: int, p_max_armor: int = 0, p_invuln: float = 0.0) -> void:
	max_hp = p_max_hp
	max_armor = p_max_armor
	invuln_time = p_invuln
	hp = max_hp
	armor = max_armor
	dead = false
	changed.emit(hp, max_hp, armor, max_armor)


func _process(delta: float) -> void:
	if _invuln_left > 0.0:
		_invuln_left -= delta
	if max_armor <= 0 or dead or armor >= max_armor:
		return
	_since_hit += delta
	if _since_hit >= armor_regen_delay / regen_mult:
		_regen_acc += delta
		if _regen_acc >= armor_regen_interval / regen_mult:
			_regen_acc = 0.0
			armor += 1
			changed.emit(hp, max_hp, armor, max_armor)


func is_invulnerable() -> bool:
	return invulnerable or _invuln_left > 0.0


## Applies damage. Returns the amount actually taken (0 if blocked / dead).
func take(info: HitInfo) -> int:
	if dead or is_invulnerable() or info.damage <= 0:
		return 0
	var split: Vector2i = Damage.absorb(info.damage, armor)
	armor -= split.x
	hp = maxi(hp - split.y, 0)
	_since_hit = 0.0
	_regen_acc = 0.0
	_invuln_left = invuln_time
	changed.emit(hp, max_hp, armor, max_armor)
	damaged.emit(info.damage, info)
	if hp <= 0:
		dead = true
		died.emit()
	return info.damage


func heal(amount: int) -> int:
	if dead:
		return 0
	var before: int = hp
	hp = mini(hp + amount, max_hp)
	changed.emit(hp, max_hp, armor, max_armor)
	return hp - before


func restore_armor(amount: int) -> void:
	armor = mini(armor + amount, max_armor)
	changed.emit(hp, max_hp, armor, max_armor)


## `gain`: a higher maximum also raises current HP by the difference
## (equipment); a lower maximum always just clamps.
func set_max(p_max_hp: int, p_max_armor: int, gain: bool = false) -> void:
	var old_max: int = max_hp
	max_hp = maxi(p_max_hp, 1)
	if gain and max_hp > old_max and not dead:
		hp += max_hp - old_max
	max_armor = maxi(p_max_armor, 0)
	hp = mini(hp, max_hp)
	armor = mini(armor, max_armor)
	changed.emit(hp, max_hp, armor, max_armor)


func revive(p_hp: int) -> void:
	dead = false
	hp = clampi(p_hp, 1, max_hp)
	_invuln_left = 2.0
	changed.emit(hp, max_hp, armor, max_armor)


func ratio() -> float:
	return float(hp) / float(maxi(max_hp, 1))
