extends HeroSkill
## Ignis - FLAME NOVA: a ring of burning orbs bursts out in every direction.


func activate() -> void:
	var lvl: Level = level()
	if lvl == null:
		return
	var n: int = int(param("count", 16))
	var dmg: int = Damage.compute(int(param("damage", 3)), damage_mult(), false)
	for i: int in n:
		var dir: Vector2 = Vector2.from_angle(TAU * i / n)
		var p: Projectile = lvl.pool.acquire()
		p.from_player = true
		p.damage = dmg
		p.element = "fire"
		p.status_chance = 1.0
		p.knockback = 30.0
		p.range_left = float(param("range", 140.0))
		lvl.pool.launch(p, player.global_position + dir * 6.0, dir * float(param("speed", 170.0)), "proj_orb_amber")
	FX.burst("explosion", player.global_position, 0.0, 1.2)
	FX.shake(3.0)
	Sfx.play("explosion", -4.0)
