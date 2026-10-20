class_name HeroSkill
extends RefCounted
## Base class of an active hero skill. One instance lives on the Player.
##
## A skill is a script in scripts/characters/skills/<id>.gd; the id comes from
## the character's data ("skill": {"id": ...}), so adding a skill never touches
## Player. The Player owns cooldown and duration timing and calls:
##   can_activate() -> activate() -> tick(delta) each frame while active -> end()
## modify(key, value) lets an active skill change player/weapon modifiers
## (keys as in Player.weapon_mod: damage_mult, fire_rate_mult, free_ammo, crit...).

var player: Player
var def: Dictionary = {}       # the character's "skill" block
var params: Dictionary = {}    # def["params"]


func setup(p: Player, skill_def: Dictionary) -> void:
	player = p
	def = skill_def
	var pr: Variant = skill_def.get("params", {})
	params = pr if pr is Dictionary else {}


func param(key: String, default: Variant) -> Variant:
	return params.get(key, default)


func is_active() -> bool:
	return player != null and player.skill_active_left > 0.0


func can_activate() -> bool:
	return true


func activate() -> void:
	pass


func tick(_delta: float) -> void:
	pass


func end() -> void:
	pass


func modify(_key: String, value: float) -> float:
	return value


## True while the skill should keep the player invulnerable (e.g. a dome).
func keeps_invulnerable() -> bool:
	return false


## True while enemies should lose track of the player (stealth).
func hides_player() -> bool:
	return false


## Called for every player hit before it lands on an enemy (while active).
func modify_outgoing(_info: HitInfo, _target: Node) -> void:
	pass


func level() -> Level:
	return Level.current


## Skill damage scales with Attack (damage_mult) and Skill Damage (skill tree).
func damage_mult() -> float:
	return (1.0 + player.weapon_mod("damage_mult")) * (1.0 + player.weapon_mod("skill_power"))
