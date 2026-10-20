class_name EnemyData
extends Resource
## Enemy archetype definition, built from data/enemies.json.

@export var id: String = ""
@export var display_name: String = ""
@export var sprite: String = ""
@export var behavior: String = "chaser" # chaser | ranged | flanker | tank | summoner
@export var hp: int = 10
@export var speed: float = 40.0
@export var contact_damage: int = 1
@export var damage: int = 1
@export var attack_range: float = 20.0
@export var attack_cooldown: float = 1.5
@export var detect_range: float = 200.0
@export var radius: float = 6.0
@export var knock_resist: float = 0.0
@export var cost: int = 1
@export var min_floor: int = 1
@export var coins: Vector2i = Vector2i(1, 2)
@export var shard_chance: float = 0.1
@export var shadow: String = "shadow_s"
@export var flying: bool = false
@export var extra: Dictionary = {} # behaviour-specific keys (projectile, lunge_speed, summon...)


static func from_dict(d: Dictionary) -> EnemyData:
	var e: EnemyData = EnemyData.new()
	e.id = str(d.get("id", ""))
	e.display_name = str(d.get("name", e.id))
	e.sprite = str(d.get("sprite", ""))
	e.behavior = str(d.get("behavior", "chaser"))
	e.hp = int(d.get("hp", 10))
	e.speed = float(d.get("speed", 40.0))
	e.contact_damage = int(d.get("contact_damage", 1))
	e.damage = int(d.get("damage", 1))
	e.attack_range = float(d.get("attack_range", 20.0))
	e.attack_cooldown = float(d.get("attack_cooldown", 1.5))
	e.detect_range = float(d.get("detect_range", 200.0))
	e.radius = float(d.get("radius", 6.0))
	e.knock_resist = float(d.get("knock_resist", 0.0))
	e.cost = int(d.get("cost", 1))
	e.min_floor = int(d.get("min_floor", 1))
	var c: Variant = d.get("coins", [1, 2])
	if c is Array and (c as Array).size() == 2:
		e.coins = Vector2i(int(c[0]), int(c[1]))
	e.shard_chance = float(d.get("shard_chance", 0.1))
	e.shadow = str(d.get("shadow", "shadow_s"))
	e.flying = bool(d.get("flying", false))
	e.extra = d.duplicate()
	return e


func get_extra(key: String, default: Variant) -> Variant:
	return extra.get(key, default)
