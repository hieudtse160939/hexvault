class_name CharacterData
extends Resource
## Playable hero definition, built from data/characters.json (schema v2).
##
## Logic lives in data + modules: the active skill and the passive are
## scripts found by id (see CharacterModules); stats are plain numbers the
## Player folds into its modifiers. Legacy flat entries (v1: "skill",
## "skill_cooldown", "max_hp" at top level) are still accepted.

## Stat keys a character may set; anything else in "stats" is a data error.
const STAT_KEYS: PackedStringArray = [
	"max_hp", "max_armor", "speed", "crit", "damage_mult", "fire_rate_mult", "reload_mult",
	"cooldown_mult", "dash_cd_mult", "dodge", "pierce", "magnet", "coin_mult", "armor_regen_mult", "blast_mult", "move_speed_mult",
]

@export var id: String = ""
@export var display_name: String = ""
@export var title: String = ""
@export var class_id: String = ""
@export var description: String = ""
@export var difficulty: int = 1            # 1 easy .. 3 hard
@export var sprite: String = ""
@export var max_hp: int = 6
@export var max_armor: int = 4
@export var speed: float = 96.0
@export var stats: Dictionary = {}         # extra stat modifiers (STAT_KEYS minus the three above)
@export var start_weapon: String = ""
@export var skill_def: Dictionary = {}     # {id, name, description, cooldown, duration, params, icon}
@export var passive_def: Dictionary = {}   # {id, name, description, params}
@export var unlock: Dictionary = {}
@export var mastery: Array = []            # [{level, xp, bonus: {stat: v}, text}]
@export var tags: PackedStringArray = []


# Convenience accessors kept for older call sites.
var skill: String:
	get:
		return str(skill_def.get("id", ""))
var skill_cooldown: float:
	get:
		return float(skill_def.get("cooldown", 10.0))
var skill_duration: float:
	get:
		return float(skill_def.get("duration", 0.0))
var skill_icon: String:
	get:
		return str(skill_def.get("icon", ""))


static func from_dict(d: Dictionary) -> CharacterData:
	var c: CharacterData = CharacterData.new()
	c.id = str(d.get("id", ""))
	c.display_name = str(d.get("name", c.id))
	c.title = str(d.get("title", ""))
	c.class_id = str(d.get("class", ""))
	c.description = str(d.get("description", ""))
	c.difficulty = clampi(int(d.get("difficulty", 1)), 1, 3)
	c.sprite = str(d.get("sprite", ""))
	var st: Dictionary = d.get("stats", {}) if d.get("stats", {}) is Dictionary else {}
	c.max_hp = int(st.get("max_hp", d.get("max_hp", 6)))
	c.max_armor = int(st.get("max_armor", d.get("max_armor", 4)))
	c.speed = float(st.get("speed", d.get("speed", 96.0)))
	for k: String in st:
		if k not in ["max_hp", "max_armor", "speed"]:
			c.stats[k] = st[k]
	c.start_weapon = str(d.get("start_weapon", ""))
	var sk: Variant = d.get("skill", {})
	if sk is Dictionary:
		c.skill_def = (sk as Dictionary).duplicate(true)
	else:  # v1 flat layout
		c.skill_def = {"id": str(sk), "cooldown": float(d.get("skill_cooldown", 10.0)),
			"duration": float(d.get("skill_duration", 1.0)), "icon": str(d.get("skill_icon", ""))}
	var ps: Variant = d.get("passive", {})
	c.passive_def = (ps as Dictionary).duplicate(true) if ps is Dictionary else {}
	var u: Variant = d.get("unlock", {})
	c.unlock = u if u is Dictionary else {}
	var m: Variant = d.get("mastery", [])
	c.mastery = m if m is Array else []
	var t: Variant = d.get("tags", [])
	if t is Array:
		for x: Variant in t:
			c.tags.append(str(x))
	return c


func stat(key: String, default: float = 0.0) -> float:
	match key:
		"max_hp":
			return float(max_hp)
		"max_armor":
			return float(max_armor)
		"speed":
			return speed
	return float(stats.get(key, default))


func skill_name() -> String:
	return str(skill_def.get("name", skill.capitalize()))


func passive_name() -> String:
	return str(passive_def.get("name", str(passive_def.get("id", "")).capitalize()))


## Data problems (empty array = valid). Cross-references are checked by Db.
func validate() -> PackedStringArray:
	var out: PackedStringArray = []
	if id == "":
		out.append("character without id")
	if skill == "":
		out.append("%s: no skill id" % id)
	if skill_cooldown <= 0.0:
		out.append("%s: skill cooldown must be > 0" % id)
	for k: String in stats:
		if k not in STAT_KEYS:
			out.append("%s: unknown stat '%s'" % [id, k])
	if max_hp <= 0:
		out.append("%s: max_hp must be > 0" % id)
	var last: int = 1
	for m: Variant in mastery:
		if not m is Dictionary or int((m as Dictionary).get("level", 0)) <= last:
			out.append("%s: mastery levels must be increasing dictionaries" % id)
			break
		last = int((m as Dictionary).get("level", 0))
	return out
