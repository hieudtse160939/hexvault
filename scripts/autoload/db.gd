extends Node
## Read-only game database. Loads data/*.json once and exposes typed definitions.

var weapons: Dictionary = {}      # id -> WeaponData
var weapon_order: PackedStringArray = []
var characters: Dictionary = {}   # id -> CharacterData
var character_order: PackedStringArray = []
var classes: Dictionary = {}      # id -> ClassData
var class_order: PackedStringArray = []
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

	classes.clear(); class_order.clear()
	for d: Variant in read_json("res://data/classes.json").get("classes", []):
		if d is Dictionary:
			var cl: ClassData = ClassData.from_dict(d)
			classes[cl.id] = cl
			class_order.append(cl.id)

	characters.clear(); character_order.clear()
	for d: Variant in read_json("res://data/characters.json").get("characters", []):
		if d is Dictionary:
			var c: CharacterData = CharacterData.from_dict(d)
			load_errors.append_array(c.validate())
			if characters.has(c.id):
				load_errors.append("duplicate character id %s" % c.id)
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
		load_errors.append_array(character_problems(characters[cid]))
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


## Cross-reference problems of one character (used at load and by tests/tools).
func character_problems(c: CharacterData) -> PackedStringArray:
	var out: PackedStringArray = []
	var cid: String = c.id
	if not weapons.has(c.start_weapon):
		out.append("character %s: unknown start weapon %s" % [cid, c.start_weapon])
	if not SpriteManifest.has_sprite(c.sprite):
		out.append("character %s: unknown sprite %s" % [cid, c.sprite])
	else:
		var anims: Dictionary = (SpriteManifest.sprites()[c.sprite] as Dictionary).get("anims", {})
		for a: String in ["idle", "run", "dash", "skill", "hurt", "death"]:
			if not anims.has(a):
				out.append("character %s: sprite lacks '%s' animation" % [cid, a])
	if not classes.has(c.class_id):
		out.append("character %s: unknown class %s" % [cid, c.class_id])
	if not CharacterModules.has_skill(c.skill):
		out.append("character %s: no script for skill %s" % [cid, c.skill])
	var pid: String = str(c.passive_def.get("id", ""))
	if pid == "" or not CharacterModules.has_passive(pid):
		out.append("character %s: no script for passive '%s'" % [cid, pid])
	if c.skill_icon != "" and not SpriteManifest.has_image(c.skill_icon):
		out.append("character %s: unknown skill icon %s" % [cid, c.skill_icon])
	match str(c.unlock.get("type", "")):
		"default", "shards":
			pass
		"achievement":
			if not achievements.has(str(c.unlock.get("id", ""))):
				out.append("character %s: unlock references unknown achievement" % cid)
		_:
			out.append("character %s: unknown unlock type" % cid)
	return out


func characters_in_class(class_id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in character_order:
		if (characters[id] as CharacterData).class_id == class_id:
			out.append(id)
	return out


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
