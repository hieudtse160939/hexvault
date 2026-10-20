class_name Inventory
extends RefCounted
## Item ownership rules on a profile Dictionary (Profile.data or a test copy).
##
## Layout (save v4):
##   d["items"]      uid -> instance (see ItemGen)
##   d["bag"]        [uid, ...]          unequipped items, in pickup order
##   d["next_uid"]   int                 next instance number
##   d["characters"][hero]["equipment"]  slot -> uid
## An item is either in the bag or equipped in exactly one slot of one hero,
## never both; sanitize() repairs any save that breaks this.


static func capacity() -> int:
	return int(Db.items_cfg.get("inventory_capacity", 40))


static func item(d: Dictionary, uid: String) -> Dictionary:
	return (d.get("items", {}) as Dictionary).get(uid, {})


static func bag(d: Dictionary) -> Array:
	return d.get("bag", [])


static func is_full(d: Dictionary) -> bool:
	return bag(d).size() >= capacity()


## Adds a new instance to the bag and gives it a unique id. Returns the uid,
## or "" when the bag is full or the instance is invalid.
static func add(d: Dictionary, inst: Dictionary) -> String:
	if inst.is_empty() or not ItemGen.problems(inst).is_empty() or is_full(d):
		return ""
	var n: int = int(d.get("next_uid", 1))
	var uid: String = "it%06d" % n
	while (d["items"] as Dictionary).has(uid):
		n += 1
		uid = "it%06d" % n
	d["next_uid"] = n + 1
	var copy: Dictionary = inst.duplicate(true)
	copy["uid"] = uid
	(d["items"] as Dictionary)[uid] = copy
	(d["bag"] as Array).append(uid)
	return uid


## Removes an unequipped item from the profile entirely. Returns true if it was in the bag.
static func remove(d: Dictionary, uid: String) -> bool:
	var b: Array = bag(d)
	if not uid in b:
		return false
	b.erase(uid)
	(d["items"] as Dictionary).erase(uid)
	return true


static func equipment(d: Dictionary, hero: String) -> Dictionary:
	return HeroProgress.record(d, hero)["equipment"]


## Hero id wearing this item, or "".
static func owner_of(d: Dictionary, uid: String) -> String:
	var chars: Dictionary = d.get("characters", {})
	for hid: String in chars:
		var eq: Variant = (chars[hid] as Dictionary).get("equipment", {}) if chars[hid] is Dictionary else {}
		if eq is Dictionary and uid in (eq as Dictionary).values():
			return hid
	return ""


static func can_equip(d: Dictionary, hero: String, uid: String) -> bool:
	var inst: Dictionary = item(d, uid)
	if inst.is_empty() or str(inst.get("kind", "")) != "equipment" or not uid in bag(d):
		return false
	return str(inst.get("slot", "")) in (Db.items_cfg.get("slots", []) as Array) and Db.character(hero) != null


## Moves a bag item into its slot; the item previously there returns to the bag.
static func equip(d: Dictionary, hero: String, uid: String) -> bool:
	if not can_equip(d, hero, uid):
		return false
	var slot: String = str(item(d, uid)["slot"])
	var eq: Dictionary = equipment(d, hero)
	var b: Array = bag(d)
	var idx: int = b.find(uid)
	b.remove_at(idx)
	if eq.has(slot) and str(eq[slot]) != "":
		b.insert(idx, str(eq[slot]))   # displaced item takes the freed bag position
	eq[slot] = uid
	return true


static func unequip(d: Dictionary, hero: String, slot: String) -> bool:
	var eq: Dictionary = equipment(d, hero)
	if not eq.has(slot) or str(eq[slot]) == "" or is_full(d):
		return false
	(d["bag"] as Array).append(str(eq[slot]))
	eq.erase(slot)
	return true


## Sells a bag item. Returns the gold gained (0 if it is not in the bag).
static func sell(d: Dictionary, uid: String) -> int:
	var inst: Dictionary = item(d, uid)
	if inst.is_empty() or not uid in bag(d):
		return 0
	var gold: int = int(round(float(inst.get("value", 1)) * float((Db.items_cfg.get("shop", {}) as Dictionary).get("sell_mult", 1.0))))
	remove(d, uid)
	d["gold"] = int(d.get("gold", 0)) + gold
	return gold


static func equipped_items(d: Dictionary, hero: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var eq: Dictionary = equipment(d, hero)
	for slot: Variant in Db.items_cfg.get("slots", []):
		var uid: String = str(eq.get(slot, ""))
		if uid != "" and not item(d, uid).is_empty():
			out.append(item(d, uid))
	return out


static func equipped_in(d: Dictionary, hero: String, slot: String) -> Dictionary:
	return item(d, str(equipment(d, hero).get(slot, "")))


## Repairs ownership after loading: drops invalid instances and dangling
## references, makes every item appear exactly once. Returns the fixes made.
static func sanitize(d: Dictionary) -> PackedStringArray:
	var fixes: PackedStringArray = []
	if not d.get("items") is Dictionary:
		d["items"] = {}
	if not d.get("bag") is Array:
		d["bag"] = []
	var items: Dictionary = d["items"]
	for uid: Variant in items.keys():
		var inst: Variant = items[uid]
		if not inst is Dictionary or not ItemGen.problems(inst).is_empty():
			items.erase(uid)
			fixes.append("dropped invalid item %s" % uid)
			continue
		(inst as Dictionary)["uid"] = str(uid)
		(inst as Dictionary)["ilvl"] = int((inst as Dictionary).get("ilvl", 1))
	var seen: Dictionary = {}
	var chars: Dictionary = d.get("characters", {})
	for hid: String in chars:
		if not chars[hid] is Dictionary:
			continue
		var eq: Variant = (chars[hid] as Dictionary).get("equipment", {})
		if not eq is Dictionary:
			continue
		for slot: Variant in (eq as Dictionary).keys():
			var uid2: String = str(eq[slot])
			var inst2: Dictionary = items.get(uid2, {})
			if inst2.is_empty() or seen.has(uid2) or str(inst2.get("slot", "")) != str(slot):
				(eq as Dictionary).erase(slot)
				fixes.append("unequipped bad reference %s" % uid2)  # a real item lands back in the bag below
				continue
			seen[uid2] = true
	var new_bag: Array = []
	for uid3: Variant in d["bag"]:
		var u: String = str(uid3)
		if items.has(u) and not seen.has(u):
			new_bag.append(u)
			seen[u] = true
		else:
			fixes.append("removed duplicate/dangling bag entry %s" % u)
	for uid4: Variant in items:
		if not seen.has(str(uid4)):
			new_bag.append(str(uid4))
			fixes.append("returned orphan %s to bag" % uid4)
	d["bag"] = new_bag
	var max_n: int = 0
	for uid5: Variant in items:
		max_n = maxi(max_n, str(uid5).trim_prefix("it").to_int())
	d["next_uid"] = maxi(int(d.get("next_uid", 1)), max_n + 1)
	return fixes
