extends HeroPassive
## Bramble - STONEHIDE: the first hit taken in each room is blocked; armour regenerates faster.

var _charged: bool = true


func on_room_entered() -> void:
	_charged = true


func negate_hit(_info: HitInfo) -> bool:
	if not _charged:
		return false
	_charged = false
	FX.float_text(player.global_position, "BLOCKED", Color("#6fb0ff"))
	Sfx.play("door_lock", -4.0)
	return true


func modify(key: String, value: float) -> float:
	if key == "armor_regen_mult":
		return value + float(param("regen", 0.4))
	return value
