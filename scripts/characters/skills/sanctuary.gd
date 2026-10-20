extends HeroSkill
## Halvard - SANCTUARY: holy light heals, refills armour, grants a moment of
## invulnerability and blasts nearby enemies away.


func activate() -> void:
	player.heal(int(param("heal", 2)))
	player.health.restore_armor(player.health.max_armor)
	player.grant_invulnerability(float(param("invuln", 1.5)))
	var lvl: Level = level()
	if lvl != null:
		lvl.pool.erase_hostile_in(player.global_position, float(param("radius", 44.0)))
	var info: HitInfo = HitInfo.make(Damage.compute(int(param("damage", 4)), damage_mult(), false), Vector2.ZERO, true,
			player.global_position)
	info.knockback = Vector2.ZERO
	Combat.melee(player.global_position, Vector2.RIGHT, float(param("radius", 44.0)), 360.0, info)
	FX.burst("impact", player.global_position, 0.0, 3.0)
	FX.float_text(player.global_position, "SANCTUARY", Color("#ffe28a"))
	Sfx.play("heal")
