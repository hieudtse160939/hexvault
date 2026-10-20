class_name HeroPassive
extends RefCounted
## Base class of a hero passive (always on). Script: scripts/characters/passives/<id>.gd.
## Every hook has a no-op default; a passive overrides only what it needs.

var player: Player
var def: Dictionary = {}
var params: Dictionary = {}


func setup(p: Player, passive_def: Dictionary) -> void:
	player = p
	def = passive_def
	var pr: Variant = passive_def.get("params", {})
	params = pr if pr is Dictionary else {}


func param(key: String, default: Variant) -> Variant:
	return params.get(key, default)


func tick(_delta: float) -> void:
	pass


## Adjust a modifier (see Player.weapon_mod keys, plus "cooldown_mult").
func modify(_key: String, value: float) -> float:
	return value


## Adjust an outgoing player hit just before it lands on `target`.
func modify_outgoing(_info: HitInfo, _target: Node) -> void:
	pass


## Return true to cancel an incoming hit completely.
func negate_hit(_info: HitInfo) -> bool:
	return false


func on_kill(_enemy: Node) -> void:
	pass


func on_damaged(_amount: int) -> void:
	pass


func on_dash() -> void:
	pass


func on_skill() -> void:
	pass


func on_room_entered() -> void:
	pass


func on_room_cleared() -> void:
	pass
