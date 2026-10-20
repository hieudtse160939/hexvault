class_name CharacterModules
extends RefCounted
## Finds skill / passive scripts by id (convention over registration):
##   skill "overclock"  -> res://scripts/characters/skills/overclock.gd
##   passive "deadeye"  -> res://scripts/characters/passives/deadeye.gd

const SKILL_DIR: String = "res://scripts/characters/skills/"
const PASSIVE_DIR: String = "res://scripts/characters/passives/"


static func skill_path(id: String) -> String:
	return SKILL_DIR + id + ".gd"


static func passive_path(id: String) -> String:
	return PASSIVE_DIR + id + ".gd"


static func has_skill(id: String) -> bool:
	return id != "" and ResourceLoader.exists(skill_path(id))


static func has_passive(id: String) -> bool:
	return id != "" and ResourceLoader.exists(passive_path(id))


static func make_skill(p: Player, skill_def: Dictionary) -> HeroSkill:
	var id: String = str(skill_def.get("id", ""))
	var s: HeroSkill = null
	if has_skill(id):
		s = (load(skill_path(id)) as GDScript).new() as HeroSkill
	if s == null:
		push_warning("CharacterModules: no skill script for '%s'" % id)
		s = HeroSkill.new()
	s.setup(p, skill_def)
	return s


static func make_passive(p: Player, passive_def: Dictionary) -> HeroPassive:
	var id: String = str(passive_def.get("id", ""))
	var s: HeroPassive = null
	if has_passive(id):
		s = (load(passive_path(id)) as GDScript).new() as HeroPassive
	if s == null:
		if id != "":
			push_warning("CharacterModules: no passive script for '%s'" % id)
		s = HeroPassive.new()
	s.setup(p, passive_def)
	return s
