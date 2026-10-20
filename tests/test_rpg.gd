extends "res://tests/test_case.gd"
## Adventurers' Guild RPG systems: randomized equipment, rarity, affixes,
## derived stats, inventory rules, experience, skill tree, skill books, shop,
## rewards and persistence. Numbers in comments refer to the acceptance list
## of the implementation brief (tests 29-49).

const TMP: String = "user://test_rpg_profile.save"
const HERO: String = "duelist"

var _saved: Dictionary
var _auto: bool


func before_each() -> void:
	_auto = Profile.autosave
	_saved = Profile.data.duplicate(true)
	Profile.autosave = false
	Profile.data = SaveManager.profile_defaults()
	Profile.data["guild_started"] = true


func after_each() -> void:
	Profile.data = _saved
	Profile.autosave = _auto
	Game.run = null
	for s: String in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(TMP + s):
			DirAccess.remove_absolute(TMP + s)


## A mission run without loading the dungeon screen.
func _fake_run(mission: String) -> RunState:
	var r: RunState = RunState.new()
	r.character_id = HERO
	r.mission_id = mission
	r.total_floors = int(Db.mission(mission)["floors"])
	r.started_msec = Time.get_ticks_msec()
	Game.run = r
	return r


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## A known item: an Iron Helm at a fixed seed.
func _item(template: String = "x_copper_ring", rarity: String = "common", seed_value: int = 7, ilvl: int = 1) -> Dictionary:
	return ItemGen.generate(template, ilvl, rarity, _rng(seed_value))


func test_data_is_consistent() -> void:
	assert_eq(Db.rpg_problems().size(), 0, str(Db.rpg_problems()))
	assert_eq(Db.roster.size(), 5, "five playable heroes")
	for id: String in Db.roster:
		assert_not_null(Db.character(id), id)
		assert_true(Profile.is_character_unlocked(id), "%s playable from the start" % id)
	for slot: String in ["weapon", "helmet", "armor", "gloves", "boots", "accessory"]:
		assert_gt(ItemGen.templates_for(1, slot).size(), 0, "templates for %s" % slot)


# 29
func test_generation_produces_valid_instances() -> void:
	var r: RandomNumberGenerator = _rng(1)
	for i: int in 300:
		var inst: Dictionary = ItemGen.random_equipment(r, 1 + i % 20, float(i % 3))
		assert_false(inst.is_empty())
		assert_eq(ItemGen.problems(inst).size(), 0, str(ItemGen.problems(inst)))
		assert_gt(int(inst["value"]), 0)
		var t: Dictionary = ItemGen.template(str(inst["base"]))
		assert_true(ItemGen.template_allows(t, int(inst["ilvl"]), str(inst["rarity"])), "rarity/level allowed by the template")
		var rr: Array = ItemGen.rarity(str(inst["rarity"]))["affixes"]
		assert_between((inst["affixes"] as Array).size(), 0, int(rr[1]))
		var ids: Dictionary = {}
		for a: Dictionary in inst["affixes"]:
			assert_false(ids.has(a["id"]), "no duplicate affix")
			ids[a["id"]] = true
			assert_has(Db.affixes[a["id"]]["slots"], inst["slot"], "affix allowed on this slot")
	var uid: String = Inventory.add(Profile.data, ItemGen.random_equipment(r, 3))
	assert_string_contains(uid, "it")
	assert_eq(str(Inventory.item(Profile.data, uid)["uid"]), uid)


# 30
func test_rolls_stay_inside_configured_ranges() -> void:
	var n: int = 0
	for tid: String in Db.item_template_order:
		var t: Dictionary = Db.item_templates[tid]
		for rid: String in ["common", "uncommon", "rare", "epic", "legendary"]:
			for ilvl: int in [1, 5, 12, 30]:
				if not ItemGen.template_allows(t, ilvl, rid):
					continue
				for s: int in 4:
					var inst: Dictionary = ItemGen.generate(tid, ilvl, rid, _rng(hash([tid, rid, ilvl, s])))
					for k: String in inst["stats"]:
						var b: Vector2 = ItemGen.value_bounds(k, t["base"][k], ilvl, rid)
						assert_between(float(inst["stats"][k]), b.x, b.y, "%s %s %s" % [tid, rid, k])
						n += 1
					for a: Dictionary in inst["affixes"]:
						var ad: Dictionary = Db.affixes[a["id"]]
						var b2: Vector2 = ItemGen.value_bounds(str(ad["stat"]), ad["range"], ilvl, rid)
						assert_between(float(a["value"]), b2.x, b2.y, "%s affix %s" % [tid, a["id"]])
						var sd: Dictionary = ItemGen.stat_def(str(ad["stat"]))
						assert_between(float(a["value"]), float(sd["min"]), float(sd["max"]))
	assert_gt(n, 200, "checked many rolls")


# 31
func test_rarity_follows_configuration() -> void:
	var r: RandomNumberGenerator = _rng(99)
	var counts: Dictionary = {}
	for i: int in 6000:
		var id: String = ItemGen.pick_rarity(r, 0.0)
		counts[id] = int(counts.get(id, 0)) + 1
	assert_gt(int(counts.get("common", 0)), int(counts.get("uncommon", 0)))
	assert_gt(int(counts.get("uncommon", 0)), int(counts.get("rare", 0)))
	assert_gt(int(counts.get("rare", 0)), int(counts.get("legendary", 0)))
	assert_lt(float(counts.get("legendary", 0)) / 6000.0, 0.03, "legendaries are rare")
	for i2: int in 300:
		assert_gt(ItemGen.rarity_tier(ItemGen.pick_rarity(r, 0.5, 2)) + 1, 2, "min rarity respected")
	# a rarity bonus shifts weight toward higher tiers
	var w0: PackedFloat32Array = ItemGen.rarity_weights(0.0)
	var w1: PackedFloat32Array = ItemGen.rarity_weights(1.0)
	assert_gt(w1[4] / w1[0], w0[4] / w0[0])
	# boss table guarantees rare+ equipment
	for i3: int in 40:
		for inst: Dictionary in ItemGen.roll_table("boss", r, 5):
			if inst["kind"] == "equipment":
				assert_true(ItemGen.rarity_tier(str(inst["rarity"])) >= 2, "boss loot is rare or better")


# 32
func test_instances_can_roll_differently_and_seeds_repeat() -> void:
	var seen: Dictionary = {}
	for s: int in 40:
		seen[str(_item("w_ember_blade", "rare", s, 5)["stats"]) + str(_item("w_ember_blade", "rare", s, 5)["affixes"])] = true
	assert_gt(seen.size(), 1, "different rolls across seeds")
	assert_eq(_item("w_ember_blade", "epic", 1234, 6), _item("w_ember_blade", "epic", 1234, 6), "same seed, same item")


# 33 / 34 / 35
func test_equipping_changes_stats_and_never_stacks() -> void:
	var base: Dictionary = HeroStats.for_hero(Profile.data, HERO)
	var inst: Dictionary = _item("x_copper_ring", "common", 3)
	var atk: float = float(inst["stats"]["attack"])
	assert_gt(atk, 0.0)
	var uid: String = Inventory.add(Profile.data, inst)
	assert_true(Inventory.equip(Profile.data, HERO, uid))
	var on: Dictionary = HeroStats.for_hero(Profile.data, HERO)
	assert_almost_eq(float(on["attack"]), float(base["attack"]) + atk, 0.001, "attack = base + ring")
	assert_true(Inventory.unequip(Profile.data, HERO, "accessory"))
	assert_almost_eq(float(HeroStats.for_hero(Profile.data, HERO)["attack"]), float(base["attack"]), 0.001, "unequip restores")
	for i: int in 10:
		Inventory.equip(Profile.data, HERO, uid)
		Inventory.unequip(Profile.data, HERO, "accessory")
	assert_eq(HeroStats.for_hero(Profile.data, HERO), base, "10 equip cycles leave no residue")
	Inventory.equip(Profile.data, HERO, uid)
	for j: int in 5:
		Inventory.equip(Profile.data, HERO, uid)  # already equipped: refused, no double count
	assert_almost_eq(float(HeroStats.for_hero(Profile.data, HERO)["attack"]), float(base["attack"]) + atk, 0.001)


func test_brief_example_base_10_weapon_5_accessory_2() -> void:
	var c: CharacterData = Db.character(HERO)
	var weapon: Dictionary = {"kind": "equipment", "slot": "weapon", "stats": {"attack": 5.0}, "affixes": []}
	var acc: Dictionary = {"kind": "equipment", "slot": "accessory", "stats": {"attack": 2.0}, "affixes": []}
	assert_almost_eq(float(HeroStats.compute(c, 1, [weapon, acc])["attack"]), 17.0, 0.001)
	assert_almost_eq(float(HeroStats.compute(c, 1, [acc])["attack"]), 12.0, 0.001)


func test_player_combat_uses_final_stats() -> void:
	var lvl: Level = Level.new()
	add_child_autofree(lvl)
	var p: Player = Player.create(Db.character(HERO))
	lvl.add_entity(p)
	await wait_frames(1)
	var dm0: float = p.weapon_mod("damage_mult")
	var hp0: int = p.health.max_hp
	var inst: Dictionary = {"kind": "equipment", "base": "a_padded_tunic", "slot": "armor", "ilvl": 1, "rarity": "common",
		"name": "Test Tunic", "value": 5, "stats": {"defense": 3.0, "max_hp": 2.0}, "affixes": []}
	var ring: Dictionary = {"kind": "equipment", "base": "x_copper_ring", "slot": "accessory", "ilvl": 1, "rarity": "common",
		"name": "Test Ring", "value": 5, "stats": {"attack": 5.0}, "affixes": []}
	Inventory.equip(Profile.data, HERO, Inventory.add(Profile.data, ring))
	p.refresh_equipment()
	assert_almost_eq(p.weapon_mod("damage_mult"), dm0 + 0.5, 0.001, "+5 attack on base 10 = +50% damage")
	Inventory.equip(Profile.data, HERO, Inventory.add(Profile.data, inst))
	var hp_before: int = p.health.hp
	p.refresh_equipment()
	assert_eq(p.health.max_hp, hp0 + 2)
	assert_eq(p.health.hp, hp_before + 2, "raising max HP also raises current HP")
	assert_almost_eq(p.defense, 3.0, 0.001)
	Inventory.unequip(Profile.data, HERO, "armor")
	p.refresh_equipment()
	assert_eq(p.health.max_hp, hp0)
	assert_lte_hp(p)


func assert_lte_hp(p: Player) -> void:
	assert_true(p.health.hp <= p.health.max_hp, "current HP clamped to the new max")


func test_stat_bounds_and_defense_math() -> void:
	var c: CharacterData = Db.character(HERO)
	var crazy: Dictionary = {"kind": "equipment", "slot": "accessory", "stats": {"crit_chance": 5.0, "attack_speed": 9.0, "move_speed": 9.0, "crit_damage": 20.0}, "affixes": []}
	var s: Dictionary = HeroStats.compute(c, 1, [crazy])
	assert_eq(float(s["crit_chance"]), 0.75)
	assert_eq(float(s["attack_speed"]), 1.0)
	assert_eq(float(s["move_speed"]), 0.5)
	assert_eq(float(s["crit_damage"]), 4.0)
	assert_eq(Damage.mitigate(4, 0.0, 0.5), 4, "no defense, no change")
	assert_eq(Damage.mitigate(4, 40.0, 0.99, 40.0, 0.6), 2, "50% of 4")
	assert_eq(Damage.mitigate(1, 40.0, 0.4, 40.0, 0.6), 1, "fraction kept as chance (hit)")
	assert_eq(Damage.mitigate(1, 40.0, 0.6, 40.0, 0.6), 0, "fraction kept as chance (blocked)")
	assert_almost_eq(Damage.defense_reduction(1000.0, 40.0, 0.6), 0.6, 0.0001, "capped")
	assert_eq(Damage.compute(3, 1.0, true, 2.5), 8, "crit damage multiplier")


# 36 / 37
func test_incompatible_and_replacement() -> void:
	var book: String = Inventory.add(Profile.data, ItemGen.make_book("book_veil"))
	assert_false(Inventory.equip(Profile.data, HERO, book), "books cannot be equipped")
	assert_false(Inventory.equip(Profile.data, HERO, "it999999"), "unknown item")
	var a: String = Inventory.add(Profile.data, _item("h_leather_cap", "common", 1))
	var b: String = Inventory.add(Profile.data, _item("h_leather_cap", "rare", 2))
	assert_true(Inventory.equip(Profile.data, HERO, a))
	assert_false(Inventory.equip(Profile.data, "assassin", a), "already worn by another hero")
	assert_true(Inventory.equip(Profile.data, HERO, b))
	assert_eq(str(Inventory.equipment(Profile.data, HERO)["helmet"]), b)
	assert_has(Inventory.bag(Profile.data), a, "replaced item returns to the bag")
	assert_does_not_have(Inventory.bag(Profile.data), b)
	assert_eq(Inventory.bag(Profile.data).size(), 2, "book + displaced helm, nothing duplicated")
	assert_eq(Inventory.sanitize(Profile.data).size(), 0, "state is already consistent")


func test_bag_capacity() -> void:
	for i: int in Inventory.capacity():
		assert_ne(Inventory.add(Profile.data, _item("x_copper_ring", "common", i)), "")
	assert_eq(Inventory.add(Profile.data, _item()), "", "full bag refuses")


# 38
func test_pickup_cannot_duplicate() -> void:
	var lvl: Level = Level.new()
	add_child_autofree(lvl)
	var p: Player = Player.create(Db.character(HERO))
	lvl.player = p
	lvl.add_entity(p)
	var pick: ItemPickup = ItemPickup.spawn(_item("b_travel_boots", "uncommon", 5), Vector2.ZERO)
	await wait_frames(1)
	assert_true(pick.try_collect(p))
	assert_false(pick.try_collect(p), "second collect does nothing")
	assert_eq(Inventory.bag(Profile.data).size(), 1)
	await wait_frames(1)
	assert_false(is_instance_valid(pick), "pickup removed from the world")


# 39 / 40
func test_experience_and_level_thresholds() -> void:
	var rec: Dictionary = Profile.character_record(HERO)
	assert_eq(int(rec["level"]), 1)
	assert_eq(Profile.grant_exp(HERO, 10), 0)
	assert_eq(int(rec["exp"]), 10)
	var need: int = HeroProgress.xp_to_next(1) - 10 + HeroProgress.xp_to_next(2) + 5
	assert_eq(Profile.grant_exp(HERO, need), 2, "one reward crosses two thresholds")
	assert_eq(int(rec["level"]), 3)
	assert_eq(int(rec["exp"]), 5)
	assert_eq(int(rec["sp"]), 2, "a skill point per level")
	assert_gt(HeroProgress.xp_to_next(5), HeroProgress.xp_to_next(4), "thresholds grow")
	Profile.grant_exp(HERO, 10_000_000)
	assert_eq(int(rec["level"]), HeroProgress.max_level(), "capped at max level")
	var lv1: Dictionary = HeroStats.base(Db.character(HERO), 1)
	var lv10: Dictionary = HeroStats.base(Db.character(HERO), 10)
	assert_gt(float(lv10["attack"]), float(lv1["attack"]), "level growth")


func test_kill_grants_exp_once() -> void:
	_fake_run("forgotten_catacombs")
	var e: Enemy = Enemy.create(Db.enemy(Db.enemies.keys()[0]), false, 1, 0, 1)
	var lvl: Level = Level.new()
	add_child_autofree(lvl)
	lvl.add_entity(e)
	await wait_frames(1)
	var before: int = int(Profile.character_record(HERO)["exp"]) + 1000 * Profile.hero_level(HERO)
	e.health.take(HitInfo.make(99999, Vector2.ZERO, true, Vector2.ZERO))
	var after1: int = int(Profile.character_record(HERO)["exp"]) + 1000 * Profile.hero_level(HERO)
	assert_gt(after1, before, "kill gives experience")
	e.health.take(HitInfo.make(99999, Vector2.ZERO, true, Vector2.ZERO))
	e.receive_hit(HitInfo.make(99999, Vector2.ZERO, true, Vector2.ZERO))
	assert_eq(int(Profile.character_record(HERO)["exp"]) + 1000 * Profile.hero_level(HERO), after1, "dead enemy gives nothing more")
	assert_eq(Game.run.kills, 1)


# 41 / 42
func test_rewards_once_and_mission_progression() -> void:
	assert_true(Profile.mission_unlocked("forgotten_catacombs"))
	assert_false(Profile.mission_unlocked("ember_vault"), "locked until the first mission is done")
	var r: RunState = _fake_run("forgotten_catacombs")
	r.coins = 30
	var g0: int = Profile.gold()
	r.victory = true
	var summary: Dictionary = r.summary()
	Profile.bank_run(summary)
	var rw: Dictionary = Db.mission("forgotten_catacombs")["rewards"]
	assert_eq(Profile.gold(), g0 + 30 + int(rw["gold"]), "coins + mission gold")
	r.ended = true
	Game.end_run(true)   # run already ended: must not bank again
	assert_eq(Profile.gold(), g0 + 30 + int(rw["gold"]), "no double reward")
	assert_true(Profile.mission_completed("forgotten_catacombs"))
	assert_true(Profile.mission_unlocked("ember_vault"))
	assert_eq(int(Profile.mission_record("forgotten_catacombs")["completed"]), 1)
	# defeat: only part of the coins, no mission reward, no completion
	var g1: int = Profile.gold()
	Profile.bank_run({"victory": false, "coins": 41, "mission": "ember_vault", "character": HERO, "floor": 1})
	assert_eq(Profile.gold(), g1 + int(floor(41 * float(Db.guild["death_gold_keep"]))))
	assert_false(Profile.mission_completed("ember_vault"))


func test_skill_tree_and_books() -> void:
	var rec: Dictionary = Profile.character_record(HERO)
	var nodes: Array = HeroProgress.tree_nodes(HERO)
	var first: String = str(nodes[0]["id"])
	var second: String = str(nodes[1]["id"])
	assert_eq(HeroProgress.learn_block(HERO, rec, first), "No skill points")
	rec["sp"] = 3
	assert_ne(HeroProgress.learn_block(HERO, rec, second), "", "needs the node above")
	var before: Dictionary = HeroStats.for_hero(Profile.data, HERO)
	assert_true(HeroProgress.learn(HERO, rec, first))
	assert_true(HeroProgress.learn(HERO, rec, second))
	assert_eq(int(rec["sp"]), 1)
	var after: Dictionary = HeroStats.for_hero(Profile.data, HERO)
	assert_ne(after, before, "talents change final stats")
	assert_eq(HeroProgress.reset_tree(rec), 2)
	assert_eq(int(rec["sp"]), 3)
	assert_eq(HeroStats.for_hero(Profile.data, HERO), before, "reset removes every bonus")
	# skill book: learn, equip in the skill slot, cannot read twice
	var uid: String = Inventory.add(Profile.data, ItemGen.make_book("book_flame_nova"))
	assert_eq(HeroProgress.read_book(Profile.data, HERO, uid), "")
	assert_has(HeroProgress.known_skills(HERO, rec), "flame_nova")
	assert_true(Inventory.item(Profile.data, uid).is_empty(), "book consumed")
	var uid2: String = Inventory.add(Profile.data, ItemGen.make_book("book_flame_nova"))
	assert_eq(HeroProgress.read_book(Profile.data, HERO, uid2), "Already known")
	assert_true(HeroProgress.set_active_skill(HERO, rec, "flame_nova"))
	assert_eq(str(HeroProgress.active_skill_def(HERO, rec)["id"]), "flame_nova")
	assert_false(HeroProgress.set_active_skill(HERO, rec, "barrage"), "unknown skills cannot be slotted")
	var pts: String = Inventory.add(Profile.data, ItemGen.make_book("book_insight"))
	assert_eq(HeroProgress.read_book(Profile.data, HERO, pts), "")
	assert_eq(int(rec["sp"]), 4)


func test_learned_skill_works_in_combat() -> void:
	var rec: Dictionary = Profile.character_record(HERO)
	rec["skills"] = ["flame_nova"]
	rec["active_skill"] = "flame_nova"
	var lvl: Level = Level.new()
	add_child_autofree(lvl)
	var p: Player = Player.create(Db.character(HERO))
	lvl.player = p
	lvl.add_entity(p)
	await wait_frames(1)
	assert_eq(str(p.skill_def["id"]), "flame_nova")
	assert_true(p.try_skill(), "learned skill fires")
	assert_gt(p.skill_cd_left, 0.0, "enters cooldown")
	assert_false(p.try_skill(), "not again while cooling down")
	p.skill_cd_left = 0.01
	await wait_physics_frames(3)
	assert_eq(p.skill_cd_left, 0.0)
	assert_true(p.try_skill(), "available again after the cooldown")


func test_shop_and_selling() -> void:
	var stock: Array = Profile.shop_stock()
	assert_gt(stock.size(), 5)
	assert_eq(Profile.shop_stock(), stock, "stock is stable until the next expedition")
	var price: int = int(stock[0]["price"])
	assert_gt(price, 0)
	Profile.data["gold"] = price - 1
	assert_eq(Profile.buy_from_shop(0), "Not enough gold")
	assert_eq(Inventory.bag(Profile.data).size(), 0)
	Profile.data["gold"] = price * 2 + 5
	assert_eq(Profile.buy_from_shop(0), "")
	assert_eq(Profile.gold(), price + 5, "charged exactly once")
	assert_eq(Profile.buy_from_shop(0), "Already sold", "repeat purchase refused")
	assert_eq(Profile.gold(), price + 5)
	assert_eq(Inventory.bag(Profile.data).size(), 1, "item delivered once")
	var uid: String = str(Inventory.bag(Profile.data)[0])
	var value: int = int(Inventory.item(Profile.data, uid)["value"])
	assert_eq(Profile.sell_item(uid), value)
	assert_eq(Profile.sell_item(uid), 0, "cannot sell an item no longer owned")
	assert_eq(Profile.gold(), price + 5 + value)
	Profile.data["expeditions"] = 1
	assert_ne(Profile.shop_stock(), stock, "restocks after an expedition")


# 43-48
func test_save_load_keeps_exact_items_equipment_progress() -> void:
	Profile.select_hero(HERO)
	var r: RandomNumberGenerator = _rng(2024)
	var uids: Array = []
	for i: int in 8:
		uids.append(Inventory.add(Profile.data, ItemGen.random_equipment(r, 4, 1.0)))
	uids.append(Inventory.add(Profile.data, ItemGen.make_book("book_veil")))
	var helm: String = Inventory.add(Profile.data, _item("h_iron_helm", "epic", 11, 6))
	Inventory.equip(Profile.data, HERO, helm)
	Profile.data["gold"] = 321
	Profile.grant_exp(HERO, 200)
	Profile.mission_record("forgotten_catacombs")["completed"] = 2
	var snapshot: Dictionary = Profile.data.duplicate(true)
	assert_eq(SaveStore.write_atomic(TMP, Profile.data, SaveManager.PROFILE_VERSION), OK, "43 save created")
	var res: SaveStore.LoadResult = SaveStore.load_validated(TMP, SaveManager.profile_defaults(), SaveManager.PROFILE_VERSION, SaveManager.profile_migrations())
	assert_eq(res.status, SaveStore.Status.OK, "44 save loads")
	var d: Dictionary = res.data
	assert_eq(Inventory.sanitize(d).size(), 0, "loaded inventory is consistent")
	assert_eq(Inventory.bag(d), Inventory.bag(snapshot), "45 bag survives")
	assert_eq(str(Inventory.equipment(d, HERO)["helmet"]), helm, "46 equipment survives")
	for uid: Variant in (snapshot["items"] as Dictionary):
		var a: Dictionary = snapshot["items"][uid]
		var b: Dictionary = d["items"][uid]
		assert_eq(str(b["name"]), str(a["name"]))
		assert_eq(str(b["rarity"]), str(a["rarity"]))
		assert_eq(ItemGen.totals(b), ItemGen.totals(a), "47 exact rolls for %s" % uid)
		assert_eq(str(b.get("affixes", [])), str(a.get("affixes", [])), "47 affixes")
	assert_eq(int(d["gold"]), 321, "48 currency")
	assert_eq(int(HeroProgress.record(d, HERO)["level"]), int(HeroProgress.record(snapshot, HERO)["level"]), "48 level")
	assert_eq(int(HeroProgress.record(d, HERO)["exp"]), int(HeroProgress.record(snapshot, HERO)["exp"]))
	assert_eq(int((d["missions"]["forgotten_catacombs"] as Dictionary)["completed"]), 2, "42 mission progress persists")
	assert_eq(HeroStats.for_hero(d, HERO), HeroStats.for_hero(snapshot, HERO), "same final stats after reload")


# 49
func test_missing_corrupt_and_invalid_saves() -> void:
	var miss: SaveStore.LoadResult = SaveStore.load_validated(TMP, SaveManager.profile_defaults(), SaveManager.PROFILE_VERSION)
	assert_eq(miss.status, SaveStore.Status.MISSING)
	assert_false(bool(miss.data["guild_started"]), "no save: nothing to continue")
	var f: FileAccess = FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string("{definitely not a save")
	f.close()
	var bad: SaveStore.LoadResult = SaveStore.load_validated(TMP, SaveManager.profile_defaults(), SaveManager.PROFILE_VERSION)
	assert_eq(bad.status, SaveStore.Status.RESET_CORRUPT, "corrupt file without backup resets safely")
	assert_true(FileAccess.file_exists(TMP + ".corrupt"), "damaged file kept")
	# hand-broken inventory: dangling refs, duplicates, unknown items
	var d: Dictionary = SaveManager.profile_defaults()
	var good: String = Inventory.add(d, _item())
	d["items"]["it777777"] = {"kind": "equipment", "base": "no_such_item", "rarity": "common"}
	d["bag"].append(good)
	d["bag"].append("ghost")
	HeroProgress.record(d, HERO)["equipment"] = {"accessory": good, "helmet": "it777777"}
	var fixes: PackedStringArray = Inventory.sanitize(d)
	assert_gt(fixes.size(), 0)
	assert_false((d["items"] as Dictionary).has("it777777"), "invalid item dropped")
	assert_does_not_have(Inventory.bag(d), good, "equipped item is not also in the bag")
	assert_does_not_have(Inventory.bag(d), "ghost")
	assert_eq(Inventory.owner_of(d, good), HERO)


func test_migration_v3_to_v4() -> void:
	var v3: Dictionary = {"shards": 80, "unlocked_characters": ["ranger"], "selected_character": "ranger",
		"characters": {"ranger": {"xp": 120, "runs": 3, "wins": 1, "best_floor": 3}},
		"stats": {"runs": 3}}
	var f: FileAccess = FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(SaveStore.encode(v3, 3))
	f.close()
	var r: SaveStore.LoadResult = SaveStore.load_validated(TMP, SaveManager.profile_defaults(), SaveManager.PROFILE_VERSION, SaveManager.profile_migrations())
	assert_eq(r.status, SaveStore.Status.MIGRATED)
	assert_eq(int(r.data["shards"]), 80, "currency kept")
	assert_true(bool(r.data["guild_started"]), "an existing player can Continue")
	assert_eq(int(r.data["gold"]), 0)
	assert_eq(int(r.data["characters"]["ranger"]["xp"]), 120, "mastery kept")
	assert_eq(int(r.data["characters"]["ranger"]["level"]), 1)
	assert_true(r.data["items"] is Dictionary and r.data["bag"] is Array)
