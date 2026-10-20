extends HeroSkill
## Nyx - PHASE: blink forward (stops at walls) and detonate a hex burst on arrival.


func activate() -> void:
	var dir: Vector2 = player.move_or_aim_direction()
	var dist: float = player.ray_distance(dir, float(param("distance", 72.0)))
	FX.burst("puff", player.global_position)
	player.global_position += dir * dist
	player.grant_invulnerability(0.25)
	FX.burst("explosion", player.global_position, 0.0, 0.8)
	FX.shake(2.0)
	var info: HitInfo = HitInfo.make(Damage.compute(int(param("damage", 8)), damage_mult(), false), Vector2.ZERO, true,
			player.global_position)
	info.element = "hex"
	info.status_chance = 1.0
	Combat.melee(player.global_position, dir, float(param("radius", 34.0)), 360.0, info)
