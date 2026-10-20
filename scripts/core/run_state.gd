class_name RunState
extends RefCounted
## Temporary state for one dungeon run. Discarded when the run ends; only the
## summary is banked into Profile.

const TOTAL_FLOORS: int = 3   # floors of a run without a mission (free dive, tests)

var mission_id: String = ""          # Guild mission this expedition belongs to ("" = free dive)
var total_floors: int = TOTAL_FLOORS
var item_level: int = 1              # base item level of drops (mission item_level + floor - 1)
var rarity_bonus: float = 0.0        # mission loot quality bonus
var loot: Array[Dictionary] = []     # copies of items found this run (summary)
var exp_gained: int = 0
var levels_gained: int = 0
var seed_value: int = 0
var character_id: String = "ranger"
var difficulty: int = 0
var floor_index: int = 1
var coins: int = 0
var shards: int = 0
var weapons: Array[String] = []      # held weapon ids (max 2)
var weapon_ammo: Dictionary = {}     # id -> ammo left in magazine
var boons: Dictionary = {}           # boon id -> stacks
var hp: int = -1                     # carried between floors (-1 = full)
var armor: int = -1
var kills: int = 0
var elites: int = 0
var rooms_cleared: int = 0
var damage_taken: int = 0
var started_msec: int = 0
var revive_used: bool = false
var ended: bool = false
var victory: bool = false


func boon_total(key: String) -> float:
	var total: float = 0.0
	for id: String in boons:
		var b: Dictionary = Db.boons.get(id, {})
		var mods: Dictionary = b.get("mods", {})
		total += float(mods.get(key, 0.0)) * int(boons[id])
	return total


func add_boon(id: String) -> void:
	boons[id] = int(boons.get(id, 0)) + 1


func elapsed_seconds() -> int:
	return (Time.get_ticks_msec() - started_msec) / 1000


func summary() -> Dictionary:
	return {
		"victory": victory, "floor": floor_index, "kills": kills, "elites": elites,
		"coins": coins, "shards": shards, "rooms": rooms_cleared, "time": elapsed_seconds(),
		"character": character_id, "seed": seed_value, "boons": boons.duplicate(),
		"mission": mission_id, "total_floors": total_floors, "loot": loot.duplicate(true),
		"exp": exp_gained, "levels": levels_gained,
	}


## Item level of drops on the current floor.
func drop_level() -> int:
	return maxi(item_level + floor_index - 1, 1)
