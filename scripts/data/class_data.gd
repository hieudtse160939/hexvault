class_name ClassData
extends Resource
## A hero class (archetype family) from data/classes.json. Several characters
## share a class; the class carries grouping, colour and a short pitch, never
## gameplay logic (that lives on each character's skill and passive).

@export var id: String = ""
@export var display_name: String = ""
@export var archetype: String = ""       # melee, ranged, magic, summoner, mobility, support, tech, hybrid
@export var description: String = ""
@export var color: Color = Color.WHITE
@export var weapon_styles: PackedStringArray = []  # styles this class can equip; empty = any


static func from_dict(d: Dictionary) -> ClassData:
	var c: ClassData = ClassData.new()
	c.id = str(d.get("id", ""))
	c.display_name = str(d.get("name", c.id))
	c.archetype = str(d.get("archetype", ""))
	c.description = str(d.get("description", ""))
	c.color = Color(str(d.get("color", "#ffffff")))
	var ws: Variant = d.get("weapons", [])
	if ws is Array:
		for s: Variant in ws:
			c.weapon_styles.append(str(s))
	return c
