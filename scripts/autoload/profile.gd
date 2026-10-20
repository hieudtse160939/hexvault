extends Node
## Permanent progression. Everything here survives death; run state lives in Game.run.

var data: Dictionary = {}
var autosave: bool = true


func _ready() -> void:
	data = SaveManager.load_profile()


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
	save()
	return earned
