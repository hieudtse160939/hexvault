extends HeroSkill
## Vex - OVERCLOCK: fire rate +100% and no ammo use while active.


func activate() -> void:
	FX.float_text(player.global_position, "OVERCLOCK", Color("#f2b23a"))


func modify(key: String, value: float) -> float:
	if not is_active():
		return value
	match key:
		"fire_rate_mult":
			return value + float(param("fire_rate_bonus", 1.0))
		"free_ammo":
			return 1.0
	return value
