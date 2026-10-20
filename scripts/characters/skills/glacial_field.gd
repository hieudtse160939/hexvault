extends HeroSkill
## Rime - GLACIAL FIELD: frost bursts out around you, chilling every enemy
## in range and shattering their bolts.


func activate() -> void:
	var lvl: Level = level()
	if lvl == null:
		return
	var r: float = float(param("radius", 80.0))
	lvl.pool.erase_hostile_in(player.global_position, r)
	for e: Node in lvl.enemies():
		var n: Node2D = e as Node2D
		if n == null or n.global_position.distance_to(player.global_position) > r:
			continue
		var st: StatusEffects = n.get("status") as StatusEffects
		if st != null:
			st.apply("frost")
		if n.has_method("receive_hit"):
			var info: HitInfo = HitInfo.make(Damage.compute(int(param("damage", 2)), damage_mult(), false),
					(n.global_position - player.global_position).normalized() * 60.0, true, player.global_position)
			info.element = "frost"
			info.status_chance = 1.0
			n.call("receive_hit", info)
	FX.burst("impact_teal", player.global_position, 0.0, 3.0)
	FX.shake(2.0)
	Sfx.play("magic", -2.0)
