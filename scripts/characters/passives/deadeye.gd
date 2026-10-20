extends HeroPassive
## Vex - DEADEYE: after standing still briefly, crit chance is greatly increased until you move.

var _still: float = 0.0


func tick(delta: float) -> void:
	if player.velocity.length() < 6.0:
		_still += delta
	else:
		_still = 0.0


func active() -> bool:
	return _still >= float(param("delay", 0.5))


func modify(key: String, value: float) -> float:
	if key == "crit" and active():
		return value + float(param("crit", 0.25))
	return value
