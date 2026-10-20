extends HeroSkill
## Cog - DEPLOY: drop an autonomous turret for the skill duration.


func activate() -> void:
	var lvl: Level = level()
	if lvl != null:
		lvl.add_entity(Turret.create(player.global_position + player.aim_direction() * 10.0, player.character.skill_duration, player))
