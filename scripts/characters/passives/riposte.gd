extends HeroPassive
## Kaida - RIPOSTE: hits landed within a moment after a dash always crit.

var _window: float = 0.0


func on_dash() -> void:
	_window = float(param("window", 1.0))


func tick(delta: float) -> void:
	_window = maxf(_window - delta, 0.0)


func modify_outgoing(info: HitInfo, _target: Node) -> void:
	if _window > 0.0 and not info.crit:
		info.crit = true
		info.damage = int(ceil(info.damage * float(param("crit_mult", 1.75))))
