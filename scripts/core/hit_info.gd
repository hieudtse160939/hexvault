class_name HitInfo
extends RefCounted
## Everything a hurtbox needs to know about one hit.

var damage: int = 1
var knockback: Vector2 = Vector2.ZERO
var crit: bool = false
var element: String = ""
var status_chance: float = 0.0
var from_player: bool = true
var source_position: Vector2 = Vector2.ZERO
var source_id: String = ""


static func make(dmg: int, kb: Vector2, is_player: bool, pos: Vector2) -> HitInfo:
	var h: HitInfo = HitInfo.new()
	h.damage = dmg
	h.knockback = kb
	h.from_player = is_player
	h.source_position = pos
	return h
