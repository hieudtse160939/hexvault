class_name WeaponData
extends Resource
## Immutable definition of one weapon. Built from data/weapons.json by Db.

const RARITY_COLORS: Dictionary = {
	"common": Color("#c4c4dc"), "rare": Color("#6fb0ff"),
	"epic": Color("#a965ef"), "legendary": Color("#f2b23a"),
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var category: String = ""
@export var rarity: String = "common"
@export var pattern: String = "single" # single | spread | melee | hitscan | chain
@export var damage: int = 1
@export var fire_interval: float = 0.3
@export var projectile_speed: float = 250.0
@export var weapon_range: float = 200.0
@export var spread_deg: float = 0.0
@export var pellets: int = 1
@export var magazine: int = 0 # 0 = infinite, no reload
@export var reload_time: float = 0.0
@export var crit_chance: float = 0.0
@export var knockback: float = 40.0
@export var pierce: int = 0
@export var homing: float = 0.0
@export var element: String = "" # fire | frost | shock | hex
@export var status_chance: float = 0.0
@export var explosion_radius: float = 0.0
@export var explosion_damage: int = 0
@export var chain: int = 0
@export var deflect: bool = false
@export var projectile: String = "bullet"
@export var speed_jitter: float = 0.0
@export var shake: float = 0.5
@export var beam_color: String = "white"
@export var sfx: String = ""
@export var unlock: Dictionary = {}


static func from_dict(d: Dictionary) -> WeaponData:
	var w: WeaponData = WeaponData.new()
	w.id = str(d.get("id", ""))
	w.display_name = str(d.get("name", w.id))
	w.description = str(d.get("description", ""))
	w.category = str(d.get("category", ""))
	w.rarity = str(d.get("rarity", "common"))
	w.pattern = str(d.get("pattern", "single"))
	w.damage = int(d.get("damage", 1))
	w.fire_interval = float(d.get("fire_interval", 0.3))
	w.projectile_speed = float(d.get("projectile_speed", 250.0))
	w.weapon_range = float(d.get("range", 200.0))
	w.spread_deg = float(d.get("spread_deg", 0.0))
	w.pellets = int(d.get("pellets", 1))
	w.magazine = int(d.get("magazine", 0))
	w.reload_time = float(d.get("reload_time", 0.0))
	w.crit_chance = float(d.get("crit_chance", 0.0))
	w.knockback = float(d.get("knockback", 40.0))
	w.pierce = int(d.get("pierce", 0))
	w.homing = float(d.get("homing", 0.0))
	w.element = str(d.get("element", ""))
	w.status_chance = float(d.get("status_chance", 0.0))
	w.explosion_radius = float(d.get("explosion_radius", 0.0))
	w.explosion_damage = int(d.get("explosion_damage", 0))
	w.chain = int(d.get("chain", 0))
	w.deflect = bool(d.get("deflect", false))
	w.projectile = str(d.get("projectile", "bullet"))
	w.speed_jitter = float(d.get("speed_jitter", 0.0))
	w.shake = float(d.get("shake", 0.5))
	w.beam_color = str(d.get("beam_color", "white"))
	w.sfx = str(d.get("sfx", ""))
	var u: Variant = d.get("unlock", {})
	w.unlock = u if u is Dictionary else {}
	return w


func rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


func uses_ammo() -> bool:
	return magazine > 0


## Returns a list of human-readable problems with this definition (empty = valid).
func validate() -> PackedStringArray:
	var errs: PackedStringArray = []
	if id.is_empty():
		errs.append("weapon without id")
	if not pattern in ["single", "spread", "melee", "hitscan", "chain"]:
		errs.append("%s: unknown pattern %s" % [id, pattern])
	if not RARITY_COLORS.has(rarity):
		errs.append("%s: unknown rarity %s" % [id, rarity])
	if damage <= 0:
		errs.append("%s: damage must be > 0" % id)
	if fire_interval <= 0.0:
		errs.append("%s: fire_interval must be > 0" % id)
	if weapon_range <= 0.0:
		errs.append("%s: range must be > 0" % id)
	if pattern in ["single", "spread"] and projectile_speed <= 0.0:
		errs.append("%s: projectile weapon needs projectile_speed" % id)
	if magazine > 0 and reload_time <= 0.0:
		errs.append("%s: magazine weapon needs reload_time" % id)
	if not unlock.has("type"):
		errs.append("%s: unlock.type missing" % id)
	return errs
