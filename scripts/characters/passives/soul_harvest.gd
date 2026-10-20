extends HeroPassive
## Morrow - SOUL HARVEST: kills sometimes raise a short-lived wisp.


func on_kill(_enemy: Node) -> void:
	if randf() >= float(param("chance", 0.25)):
		return
	var lvl: Level = Level.current
	if lvl != null:
		lvl.add_entity(Wisp.create(player, randf() * TAU, float(param("duration", 4.0))))
