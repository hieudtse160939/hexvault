class_name Damage
extends RefCounted
## Pure damage maths, unit-tested in tests/test_damage.gd.

const CRIT_MULT: float = 2.0


## base * mult, doubled on crit, never below 1.
static func compute(base: int, mult: float, crit: bool) -> int:
	var v: float = float(base) * maxf(mult, 0.0)
	if crit:
		v *= CRIT_MULT
	return maxi(int(round(v)), 1)


## Splits incoming damage between armor and health.
## Returns Vector2i(armor_lost, hp_lost).
static func absorb(amount: int, armor: int) -> Vector2i:
	if amount <= 0:
		return Vector2i.ZERO
	var to_armor: int = mini(amount, maxi(armor, 0))
	return Vector2i(to_armor, amount - to_armor)


## Enemy stat scaling by floor (1-based) and difficulty tier (0 = normal).
static func enemy_hp(base: int, floor_index: int, difficulty: int) -> int:
	var f: float = 1.0 + 0.22 * float(maxi(floor_index - 1, 0))
	var d: float = 1.0 + 0.5 * float(difficulty)
	return maxi(int(round(base * f * d)), 1)


static func enemy_damage(base: int, difficulty: int) -> int:
	return base + (1 if difficulty > 0 and base > 0 else 0)
