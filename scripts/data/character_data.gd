class_name CharacterData
extends Resource
## Playable hero definition, built from data/characters.json.

@export var id: String = ""
@export var display_name: String = ""
@export var title: String = ""
@export var description: String = ""
@export var sprite: String = ""
@export var max_hp: int = 6
@export var max_armor: int = 4
@export var speed: float = 96.0
@export var start_weapon: String = ""
@export var skill: String = ""
@export var skill_cooldown: float = 10.0
@export var skill_duration: float = 1.0
@export var skill_icon: String = ""
@export var unlock: Dictionary = {}


static func from_dict(d: Dictionary) -> CharacterData:
	var c: CharacterData = CharacterData.new()
	c.id = str(d.get("id", ""))
	c.display_name = str(d.get("name", c.id))
	c.title = str(d.get("title", ""))
	c.description = str(d.get("description", ""))
	c.sprite = str(d.get("sprite", ""))
	c.max_hp = int(d.get("max_hp", 6))
	c.max_armor = int(d.get("max_armor", 4))
	c.speed = float(d.get("speed", 96.0))
	c.start_weapon = str(d.get("start_weapon", ""))
	c.skill = str(d.get("skill", ""))
	c.skill_cooldown = float(d.get("skill_cooldown", 10.0))
	c.skill_duration = float(d.get("skill_duration", 1.0))
	c.skill_icon = str(d.get("skill_icon", ""))
	var u: Variant = d.get("unlock", {})
	c.unlock = u if u is Dictionary else {}
	return c
