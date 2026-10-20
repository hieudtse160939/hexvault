extends HeroSkill
## Kaida - WHIRLWIND: spin with the blade, slashing everything around you
## every few frames while moving faster.

var _tick: float = 0.0


func activate() -> void:
	_tick = 0.0
	FX.float_text(player.global_position, "WHIRLWIND", Color("#e8455a"))


func tick(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = float(param("interval", 0.2))
	var info: HitInfo = HitInfo.make(Damage.compute(int(param("damage", 3)), damage_mult(), false),
			Vector2.ZERO, true, player.global_position)
	info.knockback = Vector2.ZERO
	Combat.melee(player.global_position, player.aim_direction(), float(param("radius", 30.0)), 360.0, info)
	FX.burst("slash", player.global_position, randf() * TAU, 1.3)
	Sfx.play("swing", -6.0)
	var lvl: Level = level()
	if lvl != null:
		lvl.pool.erase_hostile_in(player.global_position, float(param("radius", 30.0)) * 0.7)


func modify(key: String, value: float) -> float:
	if key == "move_speed_mult" and is_active():
		return value + float(param("speed", 0.4))
	return value
