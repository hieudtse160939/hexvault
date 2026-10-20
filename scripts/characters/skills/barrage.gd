extends HeroSkill
## Brixa - BARRAGE: call down a rain of shells around the aim point.

var _tick: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func activate() -> void:
	_tick = 0.0
	_rng.randomize()


func tick(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = float(param("interval", 0.2))
	var center: Vector2 = player.global_position + player.aim_direction() * float(param("distance", 80.0))
	var off: Vector2 = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, float(param("spread", 46.0)))
	var r: float = float(param("radius", 22.0)) * maxf(1.0 + player.weapon_mod("blast_mult"), 0.2)
	Combat.explode(center + off, r, Damage.compute(int(param("damage", 5)), damage_mult(), false), false, true)
