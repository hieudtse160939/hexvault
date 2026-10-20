extends HeroPassive
## Cog - SCRAP RUSH: every kill shaves time off the skill cooldown.


func on_kill(_enemy: Node) -> void:
	player.reduce_skill_cooldown(float(param("seconds", 0.6)))
