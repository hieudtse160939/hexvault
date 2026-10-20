class_name HeroProgress
extends RefCounted
## Per-hero long-term progress stored in the profile: level and experience,
## skill points and the skill tree, skills learned from books, the equipped
## active skill. Static functions on a profile Dictionary, like Inventory.
##
## Record (d["characters"][hero]):
##   xp, runs, wins, best_floor      mastery (banked per expedition, older system)
##   level, exp, sp                  hero level, experience into that level, unspent skill points
##   tree {node_id: rank}            skill tree ranks bought
##   skills [skill_id]               extra active skills learned from books
##   active_skill                    skill in the skill slot ("" = the hero's own)
##   equipment {slot: uid}           see Inventory

const RECORD_DEFAULTS: Dictionary = {
	"xp": 0, "runs": 0, "wins": 0, "best_floor": 0,
	"level": 1, "exp": 0, "sp": 0, "tree": {}, "skills": [], "active_skill": "", "equipment": {}, "starter_kit": false,
}


## The hero's record, created or completed with defaults on first access.
static func record(d: Dictionary, hero: String) -> Dictionary:
	if not d.get("characters") is Dictionary:
		d["characters"] = {}
	var all: Dictionary = d["characters"]
	if not all.has(hero) or not all[hero] is Dictionary:
		all[hero] = RECORD_DEFAULTS.duplicate(true)
	var rec: Dictionary = all[hero]
	for k: String in RECORD_DEFAULTS:
		var dv: Variant = RECORD_DEFAULTS[k]
		var numeric_ok: bool = typeof(dv) == TYPE_INT and rec.get(k) is float
		if not rec.has(k) or (typeof(rec[k]) != typeof(dv) and not numeric_ok):
			rec[k] = SaveStore._copy(dv)
	for k2: String in ["xp", "runs", "wins", "best_floor", "level", "exp", "sp"]:
		rec[k2] = int(rec[k2])
	return rec


# --- levels -----------------------------------------------------------------------
static func leveling() -> Dictionary:
	return Db.guild.get("leveling", {})


static func max_level() -> int:
	return int(leveling().get("max_level", 30))


## Experience needed to go from `level` to level + 1.
static func xp_to_next(level: int) -> int:
	var l: Dictionary = leveling()
	var n: int = maxi(level - 1, 0)
	return int(l.get("xp_base", 40)) + int(l.get("xp_linear", 25)) * n + int(l.get("xp_quad", 4)) * n * n


## Adds experience; handles several level-ups from one reward. Returns levels gained.
static func add_exp(rec: Dictionary, amount: int) -> int:
	if amount <= 0:
		return 0
	var gained: int = 0
	var lvl: int = int(rec.get("level", 1))
	var exp: int = int(rec.get("exp", 0)) + amount
	while lvl < max_level() and exp >= xp_to_next(lvl):
		exp -= xp_to_next(lvl)
		lvl += 1
		gained += 1
	if lvl >= max_level():
		exp = 0
	rec["level"] = lvl
	rec["exp"] = exp
	rec["sp"] = int(rec.get("sp", 0)) + gained * int(leveling().get("skill_points_per_level", 1))
	return gained


## Experience for killing an enemy (data/guild.json "xp").
static func enemy_xp(cost: int, elite: bool) -> int:
	var x: Dictionary = Db.guild.get("xp", {})
	var v: int = maxi(cost, 1) * int(x.get("per_enemy_cost", 3))
	return v * int(x.get("elite_mult", 3)) if elite else v


# --- skill tree ---------------------------------------------------------------------
static func tree_nodes(hero: String) -> Array:
	return Db.skill_trees.get(hero, [])


static func tree_node(hero: String, id: String) -> Dictionary:
	for n: Variant in tree_nodes(hero):
		if n is Dictionary and str((n as Dictionary).get("id", "")) == id:
			return n
	return {}


static func node_active(n: Dictionary, weapon_style: String) -> bool:
	var req: Variant = n.get("requires_weapon", [])
	return not (req is Array and not (req as Array).is_empty()) or weapon_style in (req as Array)


static func rank(rec: Dictionary, id: String) -> int:
	return int((rec.get("tree", {}) as Dictionary).get(id, 0))


## "" if the node can be bought now, otherwise the reason.
static func learn_block(hero: String, rec: Dictionary, id: String) -> String:
	var n: Dictionary = tree_node(hero, id)
	if n.is_empty():
		return "Unknown talent"
	if rank(rec, id) >= int(n.get("max_rank", 1)):
		return "Maxed"
	var req: Dictionary = n.get("requires", {})
	for rid: String in req:
		if rank(rec, rid) < int(req[rid]):
			return "Needs %s rank %d" % [tree_node(hero, rid).get("name", rid), int(req[rid])]
	if int(rec.get("sp", 0)) < 1:
		return "No skill points"
	return ""


static func learn(hero: String, rec: Dictionary, id: String) -> bool:
	if learn_block(hero, rec, id) != "":
		return false
	(rec["tree"] as Dictionary)[id] = rank(rec, id) + 1
	rec["sp"] = int(rec["sp"]) - 1
	return true


## Refunds every point spent in the tree. Returns the points refunded.
static func reset_tree(rec: Dictionary) -> int:
	var spent: int = 0
	for id: String in (rec.get("tree", {}) as Dictionary):
		spent += int(rec["tree"][id])
	rec["tree"] = {}
	rec["sp"] = int(rec.get("sp", 0)) + spent
	return spent


## Summed stat bonuses of every rank bought. Nodes with "requires_weapon"
## only count when `weapon_style` is one of their styles.
static func tree_bonus(hero: String, rec: Dictionary, weapon_style: String = "") -> Dictionary:
	var out: Dictionary = {}
	for n: Variant in tree_nodes(hero):
		if not n is Dictionary:
			continue
		if not node_active(n, weapon_style):
			continue
		var r: int = rank(rec, str((n as Dictionary).get("id", "")))
		if r <= 0:
			continue
		var per: Dictionary = (n as Dictionary).get("per_rank", {})
		for k: String in per:
			out[k] = float(out.get(k, 0.0)) + float(per[k]) * r
	return out


# --- active skills --------------------------------------------------------------------
static func known_skills(hero: String, rec: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var c: CharacterData = Db.character(hero)
	if c != null:
		out.append(c.skill)
	for s: Variant in rec.get("skills", []):
		if not str(s) in out and not Db.skill_def_for(str(s)).is_empty():
			out.append(str(s))
	return out


## The skill block for the hero's skill slot.
static func active_skill_def(hero: String, rec: Dictionary) -> Dictionary:
	var c: CharacterData = Db.character(hero)
	var want: String = str(rec.get("active_skill", ""))
	if want != "" and want in known_skills(hero, rec):
		var sd: Dictionary = Db.skill_def_for(want)
		if not sd.is_empty():
			return sd
	return c.skill_def if c != null else {}


static func set_active_skill(hero: String, rec: Dictionary, skill_id: String) -> bool:
	if not skill_id in known_skills(hero, rec):
		return false
	var c: CharacterData = Db.character(hero)
	rec["active_skill"] = "" if c != null and c.skill == skill_id else skill_id
	return true


## Reads a book from the bag. Returns "" on success or the reason it failed.
static func read_book(d: Dictionary, hero: String, uid: String) -> String:
	var inst: Dictionary = Inventory.item(d, uid)
	if inst.is_empty() or str(inst.get("kind", "")) != "book" or not uid in Inventory.bag(d):
		return "Not a book in your bag"
	var b: Dictionary = Db.books.get(str(inst.get("base", "")), {})
	var rec: Dictionary = record(d, hero)
	match str(b.get("kind", "")):
		"skill":
			var sid: String = str(b.get("skill", ""))
			if sid in known_skills(hero, rec):
				return "Already known"
			(rec["skills"] as Array).append(sid)
		"points":
			rec["sp"] = int(rec.get("sp", 0)) + int(b.get("points", 1))
		_:
			return "Unknown book"
	Inventory.remove(d, uid)
	return ""
