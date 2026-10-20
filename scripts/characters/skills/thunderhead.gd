extends HeroSkill
## Volt - THUNDERHEAD: a storm follows you, striking nearby enemies with
## lightning that jumps to the next foe.

var _tick: float = 0.0


func activate() -> void:
	_tick = 0.0


func tick(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = float(param("interval", 0.4))
	var lvl: Level = level()
	if lvl == null:
		return
	var t: Node2D = lvl.nearest_enemy(player.global_position, float(param("range", 170.0)), false)
	if t == null:
		return
	var info: HitInfo = HitInfo.make(Damage.compute(int(param("damage", 5)), damage_mult(), false), Vector2.ZERO, true,
			t.global_position)
	info.element = "shock"
	info.status_chance = 0.6
	Combat.chain(t.global_position, 90.0, int(param("jumps", 2)), info)  # strikes t first, then jumps
	FX.burst("explosion", t.global_position, 0.0, 0.6)
	Sfx.play("zap", -4.0)
