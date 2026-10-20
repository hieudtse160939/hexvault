extends "res://tests/test_case.gd"
## Damage maths and the Health component.


func test_compute_never_below_one() -> void:
	assert_eq(Damage.compute(1, 0.1, false), 1)
	assert_eq(Damage.compute(0, 1.0, false), 1)


func test_crit_doubles() -> void:
	assert_eq(Damage.compute(5, 1.0, true), 10)
	assert_eq(Damage.compute(5, 1.2, false), 6)


func test_armor_absorbs_first() -> void:
	assert_eq(Damage.absorb(3, 2), Vector2i(2, 1))
	assert_eq(Damage.absorb(1, 4), Vector2i(1, 0))
	assert_eq(Damage.absorb(2, 0), Vector2i(0, 2))


func test_enemy_scaling_grows_with_floor_and_difficulty() -> void:
	assert_eq(Damage.enemy_hp(10, 1, 0), 10)
	assert_gt(Damage.enemy_hp(10, 3, 0), Damage.enemy_hp(10, 2, 0))
	assert_gt(Damage.enemy_hp(10, 1, 1), 10)
	assert_eq(Damage.enemy_damage(1, 1), 2)
	assert_eq(Damage.enemy_damage(0, 1), 0, "harmless stays harmless")


func test_health_armor_invuln_and_death() -> void:
	var h: Health = autofree(Health.new())
	h.setup(3, 2, 0.5)
	watch_signals(h)
	assert_eq(h.take(HitInfo.make(1, Vector2.ZERO, false, Vector2.ZERO)), 1)
	assert_eq(h.armor, 1)
	assert_eq(h.hp, 3)
	assert_eq(h.take(HitInfo.make(5, Vector2.ZERO, false, Vector2.ZERO)), 0, "invulnerable right after a hit")
	h._invuln_left = 0.0
	h.take(HitInfo.make(5, Vector2.ZERO, false, Vector2.ZERO))
	assert_true(h.dead)
	assert_signal_emitted(h, "died")
	assert_eq(h.heal(2), 0, "dead cannot heal")
	h.revive(2)
	assert_false(h.dead)
	assert_eq(h.hp, 2)
