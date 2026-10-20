class_name HeroStats
extends RefCounted
## Derived character statistics. The ONE place that defines the order:
##
##   1. Base     hero data + level growth (data/guild.json "leveling")
##   2. Flat     + every equipped item (base stats and affixes) + skill-tree flat ranks
##   3. Percent  attack *= 1 + attack_pct, defense *= 1 + defense_pct,
##               max_hp = round(max_hp * (1 + hp_pct))
##   4. Clamp    each stat to LIMITS
##
## Stats are always recomputed from these sources; nothing is ever added to a
## stored total, so equipping / unequipping any number of times cannot stack.
## Player.recompute_stats() turns the result into combat modifiers:
## damage x (attack / base attack), crit chance, crit multiplier, fire rate
## (attack speed), movement, skill cooldown (skill haste), incoming damage
## reduction (defense, see Damage.mitigate), max HP and shield.

const KEYS: PackedStringArray = [
	"attack", "defense", "max_hp", "max_armor", "crit_chance", "crit_damage",
	"attack_speed", "move_speed", "skill_haste", "skill_power", "luck",
]
const PCT_KEYS: PackedStringArray = ["attack_pct", "defense_pct", "hp_pct"]
const LIMITS: Dictionary = {
	"attack": Vector2(1.0, 9999.0), "defense": Vector2(0.0, 9999.0), "max_hp": Vector2(1.0, 999.0),
	"max_armor": Vector2(0.0, 99.0), "crit_chance": Vector2(0.0, 0.75), "crit_damage": Vector2(1.0, 4.0),
	"attack_speed": Vector2(-0.5, 1.0), "move_speed": Vector2(-0.3, 0.5), "skill_haste": Vector2(0.0, 0.5),
	"skill_power": Vector2(0.0, 3.0), "luck": Vector2(0.0, 200.0),
}


static func base_attack() -> float:
	return float((HeroStats._lv().get("base", {}) as Dictionary).get("attack", 10.0))


static func _lv() -> Dictionary:
	return Db.guild.get("leveling", {})


## Step 1: base stats of a hero at a level.
static func base(c: CharacterData, level: int) -> Dictionary:
	var lv: Dictionary = _lv()
	var b: Dictionary = lv.get("base", {})
	var g: Dictionary = lv.get("growth", {})
	var n: float = float(maxi(level - 1, 0))
	return {
		"attack": float(b.get("attack", 10.0)) + float(g.get("attack", 0.0)) * n,
		"defense": float(b.get("defense", 0.0)) + float(g.get("defense", 0.0)) * n,
		"max_hp": float(c.max_hp) + floor(float(g.get("max_hp", 0.0)) * n),
		"max_armor": float(c.max_armor),
		"crit_chance": float(b.get("crit_chance", 0.05)) + c.stat("crit"),
		"crit_damage": float(b.get("crit_damage", 2.0)),
		"attack_speed": c.stat("fire_rate_mult"),
		"move_speed": c.stat("move_speed_mult"),
		"skill_haste": -c.stat("cooldown_mult"),
		"skill_power": 0.0,
		"luck": 0.0,
	}


## Steps 1-4 from explicit sources (pure: used by tests and the comparison UI).
static func compute(c: CharacterData, level: int, items: Array, tree: Dictionary = {}) -> Dictionary:
	var s: Dictionary = base(c, level)
	var pct: Dictionary = {"attack_pct": 0.0, "defense_pct": 0.0, "hp_pct": 0.0}
	for inst: Variant in items:
		if inst is Dictionary:
			var t: Dictionary = ItemGen.totals(inst)
			for k: String in t:
				if s.has(k):
					s[k] = float(s[k]) + float(t[k])
	for k2: String in tree:
		if s.has(k2):
			s[k2] = float(s[k2]) + float(tree[k2])
		elif pct.has(k2):
			pct[k2] = float(pct[k2]) + float(tree[k2])
	s["attack"] = float(s["attack"]) * (1.0 + float(pct["attack_pct"]))
	s["defense"] = float(s["defense"]) * (1.0 + float(pct["defense_pct"]))
	s["max_hp"] = float(roundi(float(s["max_hp"]) * (1.0 + float(pct["hp_pct"]))))
	s["max_armor"] = float(roundi(float(s["max_armor"])))
	for k3: String in LIMITS:
		var lim: Vector2 = LIMITS[k3]
		s[k3] = clampf(float(s[k3]), lim.x, lim.y)
	return s


## Final stats of a hero in a profile (level, equipment, skill tree).
## `weapon_style`: style of the weapon in hand ("" = the equipped weapon item,
## else the hero's own start weapon); it decides weapon-specific talents.
static func for_hero(d: Dictionary, hero: String, weapon_style: String = "") -> Dictionary:
	var c: CharacterData = Db.character(hero)
	if c == null:
		return {}
	var rec: Dictionary = HeroProgress.record(d, hero)
	if weapon_style == "":
		weapon_style = equipped_style(d, hero)
	return compute(c, int(rec["level"]), Inventory.equipped_items(d, hero), HeroProgress.tree_bonus(hero, rec, weapon_style))


static func equipped_style(d: Dictionary, hero: String) -> String:
	var st: String = Inventory.weapon_style_of(Inventory.equipped_in(d, hero, "weapon"))
	if st == "":
		var c: CharacterData = Db.character(hero)
		var w: WeaponData = Db.weapon(c.start_weapon) if c != null else null
		st = w.style if w != null else ""
	return st


## Stats if `uid` were equipped instead of what is in its slot now (comparison UI).
static func preview_equip(d: Dictionary, hero: String, uid: String) -> Dictionary:
	var c: CharacterData = Db.character(hero)
	var inst: Dictionary = Inventory.item(d, uid)
	if c == null or inst.is_empty():
		return for_hero(d, hero)
	var slot: String = str(inst.get("slot", ""))
	var items: Array = []
	for it: Dictionary in Inventory.equipped_items(d, hero):
		if str(it.get("slot", "")) != slot:
			items.append(it)
	items.append(inst)
	var rec: Dictionary = HeroProgress.record(d, hero)
	var st: String = Inventory.weapon_style_of(inst) if str(inst.get("slot", "")) == "weapon" else equipped_style(d, hero)
	return compute(c, int(rec["level"]), items, HeroProgress.tree_bonus(hero, rec, st))


## Rounded display value.
static func show(stat: String, v: float) -> String:
	if stat in ["crit_chance", "attack_speed", "move_speed", "skill_haste", "skill_power"]:
		return "%d%%" % roundi(v * 100.0)
	if stat == "crit_damage":
		return "x%.2f" % v
	return str(roundi(v))


const LABELS: Dictionary = {
	"attack": "Attack", "defense": "Defense", "max_hp": "Max HP", "max_armor": "Shield",
	"crit_chance": "Crit Chance", "crit_damage": "Crit Damage", "attack_speed": "Attack Speed",
	"move_speed": "Move Speed", "skill_haste": "Skill Haste", "skill_power": "Skill Damage", "luck": "Luck",
}
