extends Node
## Read-only game database. Loads data/*.json once and exposes typed definitions.

var weapons: Dictionary = {}      # id -> WeaponData
var weapon_order: PackedStringArray = []
var characters: Dictionary = {}   # id -> CharacterData
var character_order: PackedStringArray = []
var enemies: Dictionary = {}      # id -> EnemyData
var bosses: Dictionary = {}       # id -> Dictionary
var elite: Dictionary = {}
var boons: Dictionary = {}        # id -> Dictionary
var boon_order: PackedStringArray = []
var upgrades: Dictionary = {}     # id -> Dictionary
var upgrade_order: PackedStringArray = []
var achievements: Dictionary = {} # id -> Dictionary
var achievement_order: PackedStringArray = []
var quests: Dictionary = {}       # id -> Dictionary
var quest_order: PackedStringArray = []
var room_templates: Array[Dictionary] = []
var load_errors: PackedStringArray = []


func _ready() -> void:
	reload()


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Db: missing %s" % path)
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("Db: %s is not a JSON object" % path)
	return {}


func reload() -> void:
	load_errors.clear()
	weapons.clear(); weapon_order.clear()
	for d: Variant in read_json("res://data/weapons.json").get("weapons", []):
		if d is Dictionary:
			var w: WeaponData = WeaponData.from_dict(d)
			load_errors.append_array(w.validate())
			weapons[w.id] = w
			weapon_order.append(w.id)

	characters.clear(); character_order.clear()
	for d: Variant in read_json("res://data/characters.json").get("characters", []):
		if d is Dictionary:
			var c: CharacterData = CharacterData.from_dict(d)
			characters[c.id] = c
			character_order.append(c.id)

	var ed: Dictionary = read_json("res://data/enemies.json")
	enemies.clear()
	for d: Variant in ed.get("enemies", []):
		if d is Dictionary:
			var e: EnemyData = EnemyData.from_dict(d)
			enemies[e.id] = e
	bosses.clear()
	for d: Variant in ed.get("bosses", []):
		if d is Dictionary:
			bosses[str(d.get("id", ""))] = d
	var el: Variant = ed.get("elite", {})
	elite = el if el is Dictionary else {}

	var pd: Dictionary = read_json("res://data/progression.json")
	_index(pd.get("boons", []), boons, boon_order)
	_index(pd.get("upgrades", []), upgrades, upgrade_order)
	_index(pd.get("achievements", []), achievements, achievement_order)
	_index(pd.get("quests", []), quests, quest_order)

	room_templates.clear()
	for t: Variant in read_json("res://data/rooms.json").get("templates", []):
		if t is Dictionary:
			room_templates.append(t)
	_cross_validate()


func _index(src: Variant, into: Dictionary, order: PackedStringArray) -> void:
	into.clear(); order.clear()
	if not src is Array:
		return
	for d: Variant in src:
		if d is Dictionary:
			var id: String = str(d.get("id", ""))
			into[id] = d
			order.append(id)


func _cross_validate() -> void:
	for cid: String in character_order:
		var c: CharacterData = characters[cid]
		if not weapons.has(c.start_weapon):
			load_errors.append("character %s: unknown start weapon %s" % [cid, c.start_weapon])
		if not SpriteManifest.has_sprite(c.sprite):
			load_errors.append("character %s: unknown sprite %s" % [cid, c.sprite])
	for eid: String in enemies:
		var e: EnemyData = enemies[eid]
		if not SpriteManifest.has_sprite(e.sprite):
			load_errors.append("enemy %s: unknown sprite %s" % [eid, e.sprite])
	for wid: String in weapon_order:
		var w: WeaponData = weapons[wid]
		if not SpriteManifest.has_sprite("weapon_" + wid):
			load_errors.append("weapon %s: no sprite weapon_%s" % [wid, wid])
		if w.unlock.get("type", "") == "achievement" and not achievements.has(str(w.unlock.get("id", ""))):
			load_errors.append("weapon %s: unlock references unknown achievement" % wid)
	for t: Dictionary in room_templates:
		var rows: Variant = t.get("rows", [])
		if not rows is Array or (rows as Array).is_empty():
			load_errors.append("room %s has no rows" % t.get("id", "?"))
			continue
		var w0: int = str(rows[0]).length()
		for r: Variant in rows:
			if str(r).length() != w0:
				load_errors.append("room %s: ragged rows" % t.get("id", "?"))
				break
	if not load_errors.is_empty():
		for e: String in load_errors:
			push_warning("Db: " + e)


func weapon(id: String) -> WeaponData:
	return weapons.get(id, null)


func character(id: String) -> CharacterData:
	return characters.get(id, null)


func enemy(id: String) -> EnemyData:
	return enemies.get(id, null)


func templates_for(room_type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in room_templates:
		var types: Variant = t.get("types", [])
		if types is Array and room_type in types:
			out.append(t)
	return out
