extends HeroPassive
## Halvard - DEVOTION: clearing a room may restore health; armour regenerates faster.


func on_room_cleared() -> void:
	if randf() < float(param("chance", 0.5)) and player.health.hp < player.health.max_hp:
		player.heal(1)


func modify(key: String, value: float) -> float:
	if key == "armor_regen_mult":
		return value + float(param("regen", 0.25))
	return value
