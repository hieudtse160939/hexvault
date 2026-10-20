extends HeroSkill
## Morrow - RAISE WISPS: three spirit wisps orbit you and shoot at enemies.


func activate() -> void:
	var lvl: Level = level()
	if lvl == null:
		return
	var n: int = int(param("count", 3))
	for i: int in n:
		lvl.add_entity(Wisp.create(player, TAU * i / n, player.skill_duration()))
	Sfx.play("spawn", -4.0)
