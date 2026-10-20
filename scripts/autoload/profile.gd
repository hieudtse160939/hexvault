extends Node
## Permanent progression. Everything here survives death; run state lives in Game.run.

var data: Dictionary = {}
var autosave: bool = true


func _ready() -> void:
	data = SaveManager.load_profile()
	repair()


## Validates the loaded profile: item ownership, hero selection. Never re-rolls items.
func repair() -> PackedStringArray:
	var fixes: PackedStringArray = Inventory.sanitize(data)
	if not Db.is_playable(str(data.get("selected_character", ""))) and not Db.roster.is_empty():
		data["selected_character"] = str(Db.guild.get("default_hero", Db.roster[0]))
		fixes.append("selected hero moved to the playable roster")
	for f: String in fixes:
		push_warning("Profile: " + f)
	return fixes


func save() -> bool:
	if not autosave:
		return true
	return SaveManager.save_profile(data)


func reset_to_defaults() -> void:
	data = SaveManager.profile_defaults()
	save()


# --- currency ------------------------------------------------------------
func shards() -> int:
	return int(data["shards"])


func add_shards(amount: int) -> void:
	data["shards"] = shards() + amount
	if amount > 0:
		add_stat("shards_earned", amount)


func spend_shards(amount: int) -> bool:
	if amount < 0 or shards() < amount:
		return false
	data["shards"] = shards() - amount
	save()
	return true


# --- unlocks -------------------------------------------------------------
func is_character_unlocked(id: String) -> bool:
	var c: CharacterData = Db.character(id)
	if c == null:
		return false
	if Db.is_playable(id):
		return true  # the Guild roster is playable from the start
	if str(c.unlock.get("type", "")) == "default":
		return true
	if str(c.unlock.get("type", "")) == "achievement":
		return has_achievement(str(c.unlock.get("id", ""))) or id in data["unlocked_characters"]
	return id in data["unlocked_characters"]


func is_weapon_unlocked(id: String) -> bool:
	var w: WeaponData = Db.weapon(id)
	if w == null:
		return false
	match str(w.unlock.get("type", "")):
		"default":
			return true
		"achievement":
			return has_achievement(str(w.unlock.get("id", "")))
	return id in data["unlocked_weapons"]


func buy_character(id: String) -> bool:
	var c: CharacterData = Db.character(id)
	if c == null or is_character_unlocked(id) or str(c.unlock.get("type", "")) != "shards":
		return false
	if not spend_shards(int(c.unlock.get("cost", 0))):
		return false
	(data["unlocked_characters"] as Array).append(id)
	save()
	return true


func buy_weapon(id: String) -> bool:
	var w: WeaponData = Db.weapon(id)
	if w == null or is_weapon_unlocked(id) or str(w.unlock.get("type", "")) != "shards":
		return false
	if not spend_shards(int(w.unlock.get("cost", 0))):
		return false
	(data["unlocked_weapons"] as Array).append(id)
	save()
	return true


func unlocked_weapon_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in Db.weapon_order:
		if is_weapon_unlocked(id):
			out.append(id)
	return out


# --- character mastery ---------------------------------------------------
## Per-hero progress record (created on first use).
func character_record(id: String) -> Dictionary:
	return HeroProgress.record(data, id)


## Mastery level reached (1 = base). Thresholds come from the character's data.
func mastery_level(id: String) -> int:
	var c: CharacterData = Db.character(id)
	if c == null:
		return 1
	var xp: int = int(character_record(id).get("xp", 0))
	var lvl: int = 1
	for m: Variant in c.mastery:
		if m is Dictionary and xp >= int((m as Dictionary).get("xp", 0)):
			lvl = int((m as Dictionary).get("level", lvl))
	return lvl


## XP needed for the next mastery level, or -1 at max.
func mastery_next_xp(id: String) -> int:
	var c: CharacterData = Db.character(id)
	if c == null:
		return -1
	var xp: int = int(character_record(id).get("xp", 0))
	for m: Variant in c.mastery:
		if m is Dictionary and xp < int((m as Dictionary).get("xp", 0)):
			return int((m as Dictionary).get("xp", 0))
	return -1


## Sum of all stat bonuses unlocked by the hero's mastery level.
func mastery_bonus(id: String) -> Dictionary:
	var out: Dictionary = {}
	var c: CharacterData = Db.character(id)
	if c == null:
		return out
	var lvl: int = mastery_level(id)
	for m: Variant in c.mastery:
		if not m is Dictionary or int((m as Dictionary).get("level", 99)) > lvl:
			continue
		var bonus: Variant = (m as Dictionary).get("bonus", {})
		if bonus is Dictionary:
			for k: String in bonus:
				out[k] = float(out.get(k, 0.0)) + float(bonus[k])
	return out


## XP for one run: depth reached, rooms cleared, a victory bonus.
static func run_xp(summary: Dictionary) -> int:
	return int(summary.get("floor", 0)) * 20 + int(summary.get("rooms", 0)) * 4 + (60 if bool(summary.get("victory", false)) else 0)


# --- permanent upgrades ----------------------------------------------------
func upgrade_level(id: String) -> int:
	return int((data["upgrades"] as Dictionary).get(id, 0))


func upgrade_cost(id: String) -> int:
	var u: Dictionary = Db.upgrades.get(id, {})
	var costs: Array = u.get("costs", [])
	var lvl: int = upgrade_level(id)
	return int(costs[lvl]) if lvl < costs.size() else -1


func buy_upgrade(id: String) -> bool:
	var cost: int = upgrade_cost(id)
	if cost < 0 or not spend_shards(cost):
		return false
	(data["upgrades"] as Dictionary)[id] = upgrade_level(id) + 1
	save()
	return true


## Total bonus granted by an upgrade at its current level.
func upgrade_bonus(id: String) -> float:
	var u: Dictionary = Db.upgrades.get(id, {})
	return float(u.get("per_level", 0.0)) * upgrade_level(id)


# --- stats, achievements, quests ---------------------------------------------
func stat(name: String) -> int:
	return int((data["stats"] as Dictionary).get(name, 0))


func add_stat(name: String, amount: int = 1) -> void:
	var s: Dictionary = data["stats"]
	s[name] = int(s.get(name, 0)) + amount
	_check_achievements()


func set_stat_max(name: String, value: int) -> void:
	var s: Dictionary = data["stats"]
	if value > int(s.get(name, 0)):
		s[name] = value
		_check_achievements()


func has_achievement(id: String) -> bool:
	return (data["achievements"] as Dictionary).has(id)


func _check_achievements() -> void:
	for id: String in Db.achievement_order:
		if has_achievement(id):
			continue
		var a: Dictionary = Db.achievements[id]
		if stat(str(a.get("stat", ""))) >= int(a.get("goal", 1)):
			(data["achievements"] as Dictionary)[id] = int(Time.get_unix_time_from_system())
			data["shards"] = shards() + int(a.get("reward", 0))
			Events.achievement_unlocked.emit(id)
			Events.toast.emit("Achievement: %s (+%d shards)" % [a.get("name", id), int(a.get("reward", 0))])


func quest_tier(id: String) -> int:
	return int((data["quests"] as Dictionary).get(id, 0))


## Returns {name, description, progress, goal, reward, done, complete_line}.
func quest_status(id: String) -> Dictionary:
	var q: Dictionary = Db.quests.get(id, {})
	var goals: Array = q.get("goals", [])
	var rewards: Array = q.get("rewards", [])
	var tier: int = quest_tier(id)
	if tier >= goals.size():
		return {"name": q.get("name", id), "description": "All tiers complete!", "progress": 1,
			"goal": 1, "reward": 0, "done": false, "complete_line": true}
	var goal: int = int(goals[tier])
	var progress: int = mini(stat(str(q.get("stat", ""))), goal)
	return {
		"name": "%s %s" % [q.get("name", id), ["I", "II", "III", "IV", "V"][mini(tier, 4)]],
		"description": str(q.get("description", "")).format({"goal": goal}),
		"progress": progress, "goal": goal, "reward": int(rewards[tier]) if tier < rewards.size() else 0,
		"done": progress >= goal, "complete_line": false,
	}


func claim_quest(id: String) -> bool:
	var st: Dictionary = quest_status(id)
	if not bool(st["done"]):
		return false
	(data["quests"] as Dictionary)[id] = quest_tier(id) + 1
	data["shards"] = shards() + int(st["reward"])
	save()
	return true


func claimable_quests() -> int:
	var n: int = 0
	for id: String in Db.quest_order:
		if bool(quest_status(id)["done"]):
			n += 1
	return n


# --- run banking ---------------------------------------------------------------
## Called once when a run ends (death, victory or abandon). Banks shards and
## stats. Permanent unlocks are never removed here.
func bank_run(summary: Dictionary) -> int:
	var mult: float = 1.0 + upgrade_bonus("shard_find")
	var earned: int = int(round(int(summary.get("shards", 0)) * mult))
	add_shards(earned)
	add_stat("runs")
	if bool(summary.get("victory", false)):
		add_stat("wins")
		data["difficulty_unlocked"] = maxi(int(data["difficulty_unlocked"]), 1)
	else:
		add_stat("deaths")
	set_stat_max("max_floor", int(summary.get("floor", 0)))
	var cid: String = str(summary.get("character", ""))
	if cid != "" and Db.character(cid) != null:
		var rec: Dictionary = character_record(cid)
		var before: int = mastery_level(cid)
		rec["xp"] = int(rec.get("xp", 0)) + run_xp(summary)
		rec["runs"] = int(rec.get("runs", 0)) + 1
		if bool(summary.get("victory", false)):
			rec["wins"] = int(rec.get("wins", 0)) + 1
		rec["best_floor"] = maxi(int(rec.get("best_floor", 0)), int(summary.get("floor", 0)))
		if mastery_level(cid) > before:
			Events.toast.emit("%s reached mastery %d!" % [Db.character(cid).display_name, mastery_level(cid)])
	_bank_guild_rewards(summary)
	earned += int(summary.get("mission_shards", 0))
	save()
	return earned


## Guild side of banking (called once per run by bank_run). Reward policy:
##  - items and experience are already permanent when found / earned;
##  - run coins become gold: all of them on victory, `death_gold_keep` on defeat;
##  - mission rewards (gold, experience, shards) and completion only on victory.
## Writes gold_earned / mission_* back into the summary for the results screen.
func _bank_guild_rewards(summary: Dictionary) -> void:
	var won: bool = bool(summary.get("victory", false))
	var keep: float = 1.0 if won else float(Db.guild.get("death_gold_keep", 0.5))
	var gold_e: int = int(floor(float(summary.get("coins", 0)) * keep))
	var mid: String = str(summary.get("mission", ""))
	var m: Dictionary = Db.mission(mid)
	summary["mission_gold"] = 0
	summary["mission_exp"] = 0
	summary["mission_shards"] = 0
	summary["mission_first_clear"] = false
	if won and not m.is_empty():
		var rw: Dictionary = m.get("rewards", {})
		var rec: Dictionary = mission_record(mid)
		summary["mission_first_clear"] = int(rec.get("completed", 0)) == 0
		rec["completed"] = int(rec.get("completed", 0)) + 1
		var t: int = int(summary.get("time", 0))
		if int(rec.get("best_time", 0)) <= 0 or t < int(rec["best_time"]):
			rec["best_time"] = t
		summary["mission_gold"] = int(rw.get("gold", 0))
		summary["mission_exp"] = int(rw.get("xp", 0))
		summary["mission_shards"] = int(rw.get("shards", 0))
		add_shards(int(summary["mission_shards"]))
		var cid: String = str(summary.get("character", ""))
		summary["levels"] = int(summary.get("levels", 0)) + grant_exp(cid, int(summary["mission_exp"]))
	summary["gold_earned"] = gold_e + int(summary["mission_gold"])
	add_gold(int(summary["gold_earned"]))
	data["expeditions"] = int(data.get("expeditions", 0)) + 1


# --- Adventurers' Guild ------------------------------------------------------------
## True when there is a game to Continue.
func has_game() -> bool:
	return bool(data.get("guild_started", false))


## Starts a fresh game with `hero`. The previous profile is first copied to
## profile.previous.save (SaveManager.archive_profile), so nothing is silently lost.
func new_game(hero: String) -> void:
	if autosave:
		SaveManager.archive_profile()
	var keep_tutorial: bool = bool(data.get("seen_tutorial", false))
	data = SaveManager.profile_defaults()
	data["seen_tutorial"] = keep_tutorial
	data["guild_started"] = true
	data["gold"] = int(Db.guild.get("start_gold", 0))
	select_hero(hero)
	save()


## Makes `hero` the active adventurer and hands out its starting gear once.
func select_hero(hero: String) -> bool:
	if Db.character(hero) == null or not is_character_unlocked(hero):
		return false
	data["selected_character"] = hero
	ensure_starter_kit(hero)
	return true


func selected_hero() -> String:
	return str(data.get("selected_character", Db.guild.get("default_hero", "duelist")))


## The hero's own start weapon as a Common weapon item, equipped. Given once.
func ensure_starter_kit(hero: String) -> void:
	var rec: Dictionary = character_record(hero)
	if bool(rec.get("starter_kit", false)):
		return
	rec["starter_kit"] = true
	var c: CharacterData = Db.character(hero)
	if c == null:
		return
	for tid: String in Db.item_template_order:
		var t: Dictionary = Db.item_templates[tid]
		if str(t.get("weapon", "")) == c.start_weapon:
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = hash([hero, "starter"])
			var inst: Dictionary = ItemGen.generate(tid, 1, str((t.get("rarity", ["common"]) as Array)[0]), rng)
			var uid: String = Inventory.add(data, inst)
			if uid != "" and Inventory.equipment(data, hero).get("weapon", "") == "":
				Inventory.equip(data, hero, uid)
			return


func gold() -> int:
	return int(data.get("gold", 0))


func add_gold(amount: int) -> void:
	if amount == 0:
		return
	data["gold"] = maxi(gold() + amount, 0)
	Events.gold_changed.emit(gold())


func spend_gold(amount: int) -> bool:
	if amount < 0 or gold() < amount:
		return false
	data["gold"] = gold() - amount
	Events.gold_changed.emit(gold())
	return true


func hero_level(hero: String) -> int:
	return int(character_record(hero)["level"])


## Grants experience to a hero; announces level-ups. Returns levels gained.
func grant_exp(hero: String, amount: int) -> int:
	if Db.character(hero) == null or amount <= 0:
		return 0
	var rec: Dictionary = character_record(hero)
	var gained: int = HeroProgress.add_exp(rec, amount)
	Events.hero_exp_changed.emit(hero)
	if gained > 0:
		Events.hero_leveled.emit(hero, int(rec["level"]))
		Events.toast.emit("%s reached level %d! (+%d skill point%s)" % [Db.character(hero).display_name, int(rec["level"]), gained, "" if gained == 1 else "s"])
	return gained


## Adds a found/bought item. Returns its uid ("" if the bag is full).
func give_item(inst: Dictionary) -> String:
	var uid: String = Inventory.add(data, inst)
	if uid != "":
		Events.inventory_changed.emit()
	return uid


# --- missions ------------------------------------------------------------------------
func mission_record(id: String) -> Dictionary:
	var all: Dictionary = data["missions"]
	if not all.has(id) or not all[id] is Dictionary:
		all[id] = {"completed": 0, "attempts": 0, "best_time": 0}
	return all[id]


func mission_completed(id: String) -> bool:
	return (data["missions"] as Dictionary).has(id) and int(mission_record(id).get("completed", 0)) > 0


func mission_unlocked(id: String) -> bool:
	var m: Dictionary = Db.mission(id)
	if m.is_empty():
		return false
	var req: String = str((m.get("unlock", {}) as Dictionary).get("mission", ""))
	return req == "" or mission_completed(req)


func missions_completed_total() -> int:
	var n: int = 0
	for id: String in (data["missions"] as Dictionary):
		n += int(mission_record(id).get("completed", 0))
	return n


func guild_rank() -> String:
	var name: String = "Copper"
	for r: Variant in Db.guild.get("ranks", []):
		if r is Dictionary and missions_completed_total() >= int((r as Dictionary).get("missions", 0)):
			name = str((r as Dictionary).get("name", name))
	return name


# --- guild shop -----------------------------------------------------------------------
## Current stock; rolled once per restock and saved, so reloading never re-rolls it.
func shop_stock() -> Array:
	var shop: Dictionary = data["shop"]
	var restock: int = int(data.get("expeditions", 0))
	if int(shop.get("restock", -1)) != restock or not shop.get("stock") is Array:
		shop["restock"] = restock
		shop["stock"] = roll_shop(restock)
	return shop["stock"]


func roll_shop(restock: int) -> Array:
	var cfg: Dictionary = Db.items_cfg.get("shop", {})
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(["guild_shop", restock, int(data.get("next_uid", 1))])
	var ilvl: int = maxi(1, hero_level(selected_hero()))
	var out: Array = []
	var bonus: float = float((Db.items_cfg.get("loot_tables", {}) as Dictionary).get("shop", {}).get("rarity_bonus", 0.0))
	var slots: Array = Db.items_cfg.get("slots", [])
	for i: int in int(cfg.get("stock", 6)):
		var inst: Dictionary = ItemGen.random_equipment(rng, ilvl, bonus, "common", str(slots[i % slots.size()]))
		if not inst.is_empty():
			out.append({"item": inst, "price": maxi(int(round(float(inst["value"]) * float(cfg.get("price_mult", 3.0)))), 1), "sold": false})
	for j: int in int(cfg.get("books", 2)):
		var b: Dictionary = ItemGen.random_book(rng, ilvl + 2)
		if not b.is_empty():
			out.append({"item": b, "price": maxi(int(round(float(b["value"]) * float(cfg.get("price_mult", 3.0)))), 1), "sold": false})
	return out


## Buys stock entry `index`. Returns "" on success or the reason it failed.
## A sold entry can never be bought again, so repeated clicks charge once.
func buy_from_shop(index: int) -> String:
	var stock: Array = shop_stock()
	if index < 0 or index >= stock.size():
		return "No such item"
	var e: Dictionary = stock[index]
	if bool(e.get("sold", false)):
		return "Already sold"
	var price: int = int(e.get("price", 0))
	if price < 0:
		return "Invalid price"
	if Inventory.is_full(data):
		return "Bag full"
	if gold() < price:
		return "Not enough gold"
	spend_gold(price)
	e["sold"] = true
	give_item(e["item"])
	save()
	return ""


func sell_item(uid: String) -> int:
	var g: int = Inventory.sell(data, uid)
	if g > 0:
		Events.gold_changed.emit(gold())
		Events.inventory_changed.emit()
		save()
	return g
