extends "res://tests/test_case.gd"
## Dungeon generation: determinism, connectivity, constraints, fallback.

const SEEDS: int = 300


func _templates() -> Array:
	return Db.read_json("res://data/rooms.json").get("templates", [])


func _signature(L: DungeonLayout) -> String:
	var parts: PackedStringArray = []
	for r: Dictionary in L.rooms:
		parts.append("%s@%s:%s" % [r["type"], r["cell"], r["template_id"]])
	for e: Vector2i in L.edges:
		parts.append(str(e))
	return "|".join(parts)


func test_same_seed_gives_identical_layout() -> void:
	var t: Array = _templates()
	for s: int in [1, 42, 9001, -77, 123456789]:
		for f: int in [1, 2, 3]:
			var cfg: Dictionary = DungeonGenerator.floor_config(f)
			var a: DungeonLayout = DungeonGenerator.generate(s, f, cfg, t)
			var b: DungeonLayout = DungeonGenerator.generate(s, f, cfg, t)
			assert_eq(_signature(a), _signature(b), "seed %d floor %d must be deterministic" % [s, f])


func test_different_seeds_vary() -> void:
	var t: Array = _templates()
	var sigs: Dictionary = {}
	for s: int in 40:
		sigs[_signature(DungeonGenerator.generate(s, 1, DungeonGenerator.floor_config(1), t))] = true
	assert_gt(sigs.size(), 30, "40 seeds should give mostly distinct layouts")


func test_hundreds_of_seeds_are_valid_and_connected() -> void:
	var t: Array = _templates()
	var fallbacks: int = 0
	for s: int in SEEDS:
		for f: int in [1, 2, 3]:
			var cfg: Dictionary = DungeonGenerator.floor_config(f)
			var L: DungeonLayout = DungeonGenerator.generate(s * 7919 + 3, f, cfg, t)
			var errs: PackedStringArray = DungeonGenerator.validate(L, cfg, t)
			if not errs.is_empty():
				fail("seed %d floor %d invalid: %s\n%s" % [s, f, errs, L.describe()])
				return
			if L.used_fallback:
				fallbacks += 1
			var dist: PackedInt32Array = L.distances(L.first_of_type("start"))
			for d: int in dist:
				assert_true(d >= 0, "every room reachable")
	assert_lt(fallbacks, SEEDS * 3 / 20, "fallback should be rare (<5%%), got %d" % fallbacks)


func test_boss_floor_has_reachable_dead_end_boss() -> void:
	var t: Array = _templates()
	var cfg: Dictionary = DungeonGenerator.floor_config(3)
	assert_eq(cfg["terminal"], "boss")
	for s: int in 50:
		var L: DungeonLayout = DungeonGenerator.generate(s, 3, cfg, t)
		var boss: int = L.first_of_type("boss")
		assert_true(boss >= 0, "boss room exists")
		assert_eq(L.neighbors(boss).size(), 1, "boss room has one entrance")
		assert_gt(L.distances(0)[boss], 2, "boss is not next to start")


func test_specials_present_per_config() -> void:
	var t: Array = _templates()
	for f: int in [1, 2, 3]:
		var cfg: Dictionary = DungeonGenerator.floor_config(f)
		var L: DungeonLayout = DungeonGenerator.generate(555, f, cfg, t)
		for sp: Variant in cfg["specials"]:
			assert_false(L.rooms_of_type(str(sp)).is_empty(), "floor %d has %s" % [f, sp])


func test_fallback_layout_is_valid() -> void:
	var t: Array = _templates()
	for f: int in [1, 2, 3]:
		var cfg: Dictionary = DungeonGenerator.floor_config(f)
		var L: DungeonLayout = DungeonGenerator.fallback(1, f, cfg, t)
		assert_eq(DungeonGenerator.validate(L, cfg, t), PackedStringArray(), "fallback floor %d" % f)


func test_impossible_config_falls_back_instead_of_failing() -> void:
	var t: Array = _templates()
	var cfg: Dictionary = DungeonGenerator.floor_config(1)
	cfg["main_length"] = 40 # cannot fit a 40-room simple path with branch rules on 7x7
	var L: DungeonLayout = DungeonGenerator.generate(3, 1, cfg, t)
	assert_true(L.used_fallback, "generator must fall back")
	assert_false(L.rooms.is_empty())
