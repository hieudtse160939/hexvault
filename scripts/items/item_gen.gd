class_name ItemGen
extends RefCounted
## Generates equipment and skill-book instances from the templates in
## data/items.json. Pure functions of their inputs and the given RNG, so a
## seeded RandomNumberGenerator always produces the same item (tests, shops).
##
## An instance is a plain Dictionary (saved as-is in the profile):
##   {uid, kind: "equipment", base, slot, name, ilvl, rarity,
##    stats: {stat: value},              # rolled base stats of the template
##    affixes: [{id, stat, value}],      # rolled affixes
##    value}                             # sell value in gold
## Books: {uid, kind: "book", base, name, rarity, value}
## Templates are never modified; the uid is assigned when the item enters an
## inventory (see Inventory.add).


static func cfg() -> Dictionary:
	return Db.items_cfg


static func stat_def(stat: String) -> Dictionary:
	return (cfg().get("stats", {}) as Dictionary).get(stat, {})


static func is_pct(stat: String) -> bool:
	return str(stat_def(stat).get("format", "int")) == "pct"


static func rarity(id: String) -> Dictionary:
	var i: int = int(Db.rarity_index.get(id, 0))
	return Db.rarities[i] if i < Db.rarities.size() else {}


static func rarity_tier(id: String) -> int:
	return int(Db.rarity_index.get(id, 0))


static func rarity_color(id: String) -> Color:
	return Color(str(rarity(id).get("color", "#ffffff")))


# --- rarity -------------------------------------------------------------------------
## Weights of every rarity after a bonus that favours higher tiers:
## weight_i * (1 + bonus * i). Tiers outside [lo, hi] get 0.
static func rarity_weights(bonus: float, lo: int = 0, hi: int = 99) -> PackedFloat32Array:
	var w: PackedFloat32Array = []
	for i: int in Db.rarities.size():
		var base: float = float(Db.rarities[i].get("weight", 0))
		w.append(base * (1.0 + maxf(bonus, 0.0) * i) if i >= lo and i <= hi else 0.0)
	return w


static func pick_rarity(rng: RandomNumberGenerator, bonus: float = 0.0, lo: int = 0, hi: int = 99) -> String:
	var w: PackedFloat32Array = rarity_weights(bonus, lo, hi)
	var total: float = 0.0
	for x: float in w:
		total += x
	if total <= 0.0:
		return str(Db.rarities[clampi(lo, 0, Db.rarities.size() - 1)].get("id", "common"))
	var r: float = rng.randf() * total
	for i: int in w.size():
		r -= w[i]
		if r < 0.0 and w[i] > 0.0:
			return str(Db.rarities[i].get("id", "common"))
	for i: int in range(w.size() - 1, -1, -1):
		if w[i] > 0.0:
			return str(Db.rarities[i].get("id", "common"))
	return "common"


# --- templates -----------------------------------------------------------------------
static func template(id: String) -> Dictionary:
	return Db.item_templates.get(id, {})


static func template_allows(t: Dictionary, ilvl: int, rarity_id: String) -> bool:
	var lv: Array = t.get("level", [1, 99])
	if ilvl < int(lv[0]) or ilvl > int(lv[1]):
		return false
	var rr: Array = t.get("rarity", ["common", "legendary"])
	var tier: int = rarity_tier(rarity_id)
	return tier >= rarity_tier(str(rr[0])) and tier <= rarity_tier(str(rr[1]))


## Templates that can exist at this item level (optionally one slot only).
static func templates_for(ilvl: int, slot: String = "") -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in Db.item_template_order:
		var t: Dictionary = Db.item_templates[id]
		var lv: Array = t.get("level", [1, 99])
		if (slot == "" or str(t.get("slot", "")) == slot) and ilvl >= int(lv[0]) and ilvl <= int(lv[1]):
			out.append(id)
	return out


# --- rolling ----------------------------------------------------------------------------
static func level_scale(ilvl: int) -> float:
	return 1.0 + float((cfg().get("item_level", {}) as Dictionary).get("stat_per_level", 0.08)) * float(maxi(ilvl - 1, 0))


## One value inside `range`, scaled by item level and rarity, clamped to the stat's limits.
static func roll_value(stat: String, range_v: Array, ilvl: int, rarity_id: String, rng: RandomNumberGenerator) -> float:
	var lo: float = float(range_v[0])
	var hi: float = float(range_v[1]) if range_v.size() > 1 else lo
	var m: float = level_scale(ilvl) * float(rarity(rarity_id).get("stat_mult", 1.0))
	var v: float
	if is_pct(stat):
		# via a 3-decimal string: the stored double is exactly what JSON writes
		# back, so a save/load round trip never changes a roll
		v = ("%.3f" % (rng.randf_range(lo, hi) * m)).to_float()
	else:
		v = float(roundi(float(rng.randi_range(int(lo), int(hi))) * m))
	var d: Dictionary = stat_def(stat)
	return clampf(v, float(d.get("min", 0.0)), float(d.get("max", 9999.0)))


## Inclusive bounds a rolled value of `stat` may take (used by validation/tests).
static func value_bounds(stat: String, range_v: Array, ilvl: int, rarity_id: String) -> Vector2:
	var m: float = level_scale(ilvl) * float(rarity(rarity_id).get("stat_mult", 1.0))
	var lo: float = float(range_v[0]) * m
	var hi: float = float(range_v[range_v.size() - 1]) * m
	if not is_pct(stat):
		lo = float(roundi(lo))
		hi = float(roundi(hi))
	var d: Dictionary = stat_def(stat)
	return Vector2(clampf(lo, float(d.get("min", 0.0)), float(d.get("max", 9999.0))) - 0.0011,
			clampf(hi, float(d.get("min", 0.0)), float(d.get("max", 9999.0))) + 0.0011)


static func affixes_for(slot: String, ilvl: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in Db.affixes:
		var a: Dictionary = Db.affixes[id]
		if slot in (a.get("slots", []) as Array) and ilvl >= int(a.get("min_level", 1)):
			out.append(id)
	out.sort()
	return out


## Builds an equipment instance. Returns {} if the template cannot exist at
## that level/rarity (the caller picks another).
static func generate(template_id: String, ilvl: int, rarity_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var t: Dictionary = template(template_id)
	if t.is_empty():
		return {}
	ilvl = clampi(ilvl, 1, int((cfg().get("item_level", {}) as Dictionary).get("max", 30)))
	if not template_allows(t, ilvl, rarity_id):
		return {}
	var slot: String = str(t.get("slot", ""))
	var stats: Dictionary = {}
	var base: Dictionary = t.get("base", {})
	for k: String in base:
		var v: float = roll_value(k, base[k], ilvl, rarity_id, rng)
		if v != 0.0:
			stats[k] = v
	var rr: Array = rarity(rarity_id).get("affixes", [0, 0])
	var n_aff: int = rng.randi_range(int(rr[0]), int(rr[1]))
	var pool: PackedStringArray = affixes_for(slot, ilvl)
	var rolled: Array = []
	while rolled.size() < n_aff and not pool.is_empty():
		var i: int = rng.randi_range(0, pool.size() - 1)
		var a: Dictionary = Db.affixes[pool[i]]
		pool.remove_at(i)
		var stat: String = str(a.get("stat", ""))
		rolled.append({"id": str(a.get("id", "")), "stat": stat, "value": roll_value(stat, a.get("range", [0, 0]), ilvl, rarity_id, rng)})
	var inst: Dictionary = {
		"kind": "equipment", "base": template_id, "slot": slot, "ilvl": ilvl, "rarity": rarity_id,
		"stats": stats, "affixes": rolled,
	}
	inst["name"] = compose_name(t, rolled)
	inst["value"] = sell_value(inst)
	return inst


## "Prefix Base of Suffix" from the first prefix and the first suffix rolled.
static func compose_name(t: Dictionary, rolled: Array) -> String:
	var pre: String = ""
	var suf: String = ""
	for r: Variant in rolled:
		var a: Dictionary = Db.affixes.get(str((r as Dictionary).get("id", "")), {})
		if str(a.get("kind", "")) == "prefix" and pre == "":
			pre = str(a.get("name", ""))
		elif str(a.get("kind", "")) == "suffix" and suf == "":
			suf = str(a.get("name", ""))
	var n: String = str(t.get("name", "?"))
	if pre != "":
		n = pre + " " + n
	if suf != "":
		n += " " + suf
	return n


static func sell_value(inst: Dictionary) -> int:
	var base_v: float
	if str(inst.get("kind", "")) == "book":
		base_v = float(Db.books.get(str(inst.get("base", "")), {}).get("value", 20))
		return maxi(int(base_v), 1)
	base_v = float(template(str(inst.get("base", ""))).get("value", 5))
	var lv: float = 1.0 + float((cfg().get("item_level", {}) as Dictionary).get("value_per_level", 0.15)) * float(maxi(int(inst.get("ilvl", 1)) - 1, 0))
	return maxi(int(round(base_v * float(rarity(str(inst.get("rarity", "common"))).get("value_mult", 1.0)) * lv)), 1)


## A random equipment piece: rarity first, then a template that allows it.
static func random_equipment(rng: RandomNumberGenerator, ilvl: int, bonus: float = 0.0, min_rarity: String = "common", slot: String = "") -> Dictionary:
	var lo: int = rarity_tier(min_rarity)
	for attempt: int in 12:
		var rid: String = pick_rarity(rng, bonus, lo)
		var ids: PackedStringArray = []
		for id: String in templates_for(ilvl, slot):
			if template_allows(template(id), ilvl, rid):
				ids.append(id)
		if ids.is_empty():
			continue
		var inst: Dictionary = generate(ids[rng.randi_range(0, ids.size() - 1)], ilvl, rid, rng)
		if not inst.is_empty():
			return inst
	# Fallback: the first template that exists at this level, at its lowest rarity.
	for id: String in templates_for(ilvl, slot):
		var rr: Array = template(id).get("rarity", ["common"])
		var inst2: Dictionary = generate(id, ilvl, str(rr[0]), rng)
		if not inst2.is_empty():
			return inst2
	return {}


# --- books ------------------------------------------------------------------------------
static func make_book(book_id: String) -> Dictionary:
	var b: Dictionary = Db.books.get(book_id, {})
	if b.is_empty():
		return {}
	var inst: Dictionary = {"kind": "book", "base": book_id, "rarity": str(b.get("rarity", "rare")), "name": book_name(book_id)}
	inst["value"] = sell_value(inst)
	return inst


static func book_name(book_id: String) -> String:
	var b: Dictionary = Db.books.get(book_id, {})
	if b.has("name"):
		return str(b["name"])
	var sd: Dictionary = Db.skill_def_for(str(b.get("skill", "")))
	return "Tome: %s" % str(sd.get("name", str(b.get("skill", "?")).capitalize()))


static func random_book(rng: RandomNumberGenerator, ilvl: int) -> Dictionary:
	var ids: PackedStringArray = []
	for id: String in Db.book_order:
		if int(Db.books[id].get("level", 1)) <= ilvl:
			ids.append(id)
	if ids.is_empty():
		return {}
	return make_book(ids[rng.randi_range(0, ids.size() - 1)])


# --- loot tables --------------------------------------------------------------------------
## Rolls a loot table from data/items.json. `luck` is the hero's Luck stat.
## Returns the item instances to drop (possibly none).
static func roll_table(table_id: String, rng: RandomNumberGenerator, ilvl: int, extra_bonus: float = 0.0, luck: float = 0.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t: Dictionary = (cfg().get("loot_tables", {}) as Dictionary).get(table_id, {})
	if t.is_empty():
		return out
	var luck_mult: float = 1.0 + luck * float(cfg().get("luck_per_point", 0.01))
	var bonus: float = float(t.get("rarity_bonus", 0.0)) + extra_bonus + luck * float(cfg().get("luck_per_point", 0.01))
	for i: int in int(t.get("rolls", 1)):
		if rng.randf() < float(t.get("equipment", 0.0)) * luck_mult:
			var inst: Dictionary = random_equipment(rng, ilvl, bonus, str(t.get("min_rarity", "common")))
			if not inst.is_empty():
				out.append(inst)
	if rng.randf() < float(t.get("book", 0.0)) * luck_mult:
		var b: Dictionary = random_book(rng, ilvl)
		if not b.is_empty():
			out.append(b)
	return out


# --- presentation ---------------------------------------------------------------------------
static func format_stat(stat: String, v: float, signed: bool = true) -> String:
	var name: String = str(stat_def(stat).get("name", stat.capitalize()))
	if is_pct(stat):
		return "%s %s%d%%" % [name, ("+" if v >= 0.0 else "") if signed else "", roundi(v * 100.0)]
	return "%s %s%d" % [name, ("+" if v >= 0.0 else "") if signed else "", roundi(v)]


## Total of every stat on an instance (base stats + affixes).
static func totals(inst: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var st: Dictionary = inst.get("stats", {})
	for k: String in st:
		out[k] = float(out.get(k, 0.0)) + float(st[k])
	for a: Variant in inst.get("affixes", []):
		if a is Dictionary:
			var k2: String = str(a.get("stat", ""))
			out[k2] = float(out.get(k2, 0.0)) + float(a.get("value", 0.0))
	return out


## Human-readable lines: base stats, then affixes marked with "*".
static func describe(inst: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	if str(inst.get("kind", "")) == "book":
		var b: Dictionary = Db.books.get(str(inst.get("base", "")), {})
		if str(b.get("kind", "")) == "skill":
			var sd: Dictionary = Db.skill_def_for(str(b.get("skill", "")))
			lines.append("Teaches the active skill %s (%ds cooldown)." % [sd.get("name", "?"), int(float(sd.get("cooldown", 10)))])
			lines.append(str(sd.get("description", "")))
		else:
			lines.append(str(b.get("description", "")))
		return lines
	var st: Dictionary = inst.get("stats", {})
	for k: String in st:
		lines.append(format_stat(k, float(st[k])))
	for a: Variant in inst.get("affixes", []):
		if a is Dictionary:
			var ad: Dictionary = Db.affixes.get(str(a.get("id", "")), {})
			lines.append("* %s  (%s)" % [format_stat(str(a.get("stat", "")), float(a.get("value", 0.0))), ad.get("name", "")])
	return lines


## Short label with the rarity spelled out (rarity is never colour-only).
static func label(inst: Dictionary) -> String:
	return "[%s] %s" % [str(rarity(str(inst.get("rarity", "common"))).get("name", "?")), str(inst.get("name", "?"))]


## Structural validation of a saved instance. Returns problems (empty = valid).
static func problems(inst: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var kind: String = str(inst.get("kind", ""))
	if not Db.rarity_index.has(str(inst.get("rarity", ""))):
		out.append("unknown rarity")
	if kind == "book":
		if not Db.books.has(str(inst.get("base", ""))):
			out.append("unknown book")
		return out
	if kind != "equipment":
		out.append("unknown kind")
		return out
	var t: Dictionary = template(str(inst.get("base", "")))
	if t.is_empty():
		out.append("unknown template")
		return out
	if str(inst.get("slot", "")) != str(t.get("slot", "")):
		out.append("slot does not match template")
	for k: String in (inst.get("stats", {}) as Dictionary):
		if stat_def(k).is_empty():
			out.append("unknown stat %s" % k)
	for a: Variant in inst.get("affixes", []):
		if not a is Dictionary or not Db.affixes.has(str((a as Dictionary).get("id", ""))):
			out.append("unknown affix")
		elif not str(t.get("slot", "")) in (Db.affixes[str((a as Dictionary)["id"])].get("slots", []) as Array):
			out.append("affix %s not allowed on %s" % [(a as Dictionary)["id"], t.get("slot", "")])
	return out
