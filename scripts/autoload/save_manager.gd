extends Node
## Owns the save file locations and the profile/settings schemas + migrations.

const PROFILE_VERSION: int = 2
const SETTINGS_VERSION: int = 1

var profile_path: String = "user://profile.save"
var settings_path: String = "user://settings.save"
var last_profile_load: SaveStore.LoadResult = null


static func profile_defaults() -> Dictionary:
	return {
		"shards": 0,
		"unlocked_characters": ["ranger"],
		"unlocked_weapons": [],
		"upgrades": {},
		"achievements": {},
		"stats": {
			"kills": 0, "elites": 0, "bosses": 0, "runs": 0, "wins": 0, "deaths": 0,
			"max_floor": 0, "chests": 0, "coins_spent": 0, "flawless_rooms": 0,
			"rooms_cleared": 0, "floors_cleared": 0, "shards_earned": 0,
		},
		"quests": {},
		"selected_character": "ranger",
		"difficulty_unlocked": 0,
		"seen_tutorial": false,
	}


static func settings_defaults() -> Dictionary:
	return {
		"master_volume": 0.8, "music_volume": 0.6, "sfx_volume": 0.8,
		"screen_shake": 1.0, "reduced_effects": false, "damage_numbers": true,
		"fullscreen": false, "vsync": true, "show_fps": false, "max_fps": 0,
		"aim_assist": true, "touch_controls": "auto", "ui_scale": 1.0, "touch_opacity": 0.7,
		"difficulty": 0,
	}


## v1 stored permanent currency as "crystals" and had no quests/stats.flawless_rooms.
static func migrate_profile_v1(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	if out.has("crystals"):
		out["shards"] = int(out["crystals"])
		out.erase("crystals")
	if out.has("unlocked_heroes"):
		out["unlocked_characters"] = out["unlocked_heroes"]
		out.erase("unlocked_heroes")
	return out


func profile_migrations() -> Dictionary:
	return {1: migrate_profile_v1}


func load_profile() -> Dictionary:
	var r: SaveStore.LoadResult = SaveStore.load_validated(profile_path, profile_defaults(),
			PROFILE_VERSION, profile_migrations())
	last_profile_load = r
	if r.status in [SaveStore.Status.RECOVERED_FROM_BACKUP, SaveStore.Status.RESET_CORRUPT]:
		push_warning("SaveManager: " + r.message)
		Events.save_status.emit(false, r.message)
	return r.data


func save_profile(data: Dictionary) -> bool:
	var err: Error = SaveStore.write_atomic(profile_path, data, PROFILE_VERSION)
	if err != OK:
		push_error("SaveManager: profile save failed: %s" % error_string(err))
		Events.save_status.emit(false, "Save failed: %s" % error_string(err))
		return false
	Events.save_status.emit(true, "Saved")
	return true


func load_settings() -> Dictionary:
	return SaveStore.load_validated(settings_path, settings_defaults(), SETTINGS_VERSION).data


func save_settings(data: Dictionary) -> bool:
	return SaveStore.write_atomic(settings_path, data, SETTINGS_VERSION) == OK


## Development self-test used by the dev menu: exercises write, read-back,
## corruption recovery and migration against throwaway files. Returns a report.
func self_test() -> Dictionary:
	var base: String = "user://selftest.save"
	var lines: PackedStringArray = []
	var ok: bool = true
	for suffix: String in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(base + suffix):
			DirAccess.remove_absolute(base + suffix)
	var d: Dictionary = profile_defaults()
	d["shards"] = 123
	ok = ok and SaveStore.write_atomic(base, d, PROFILE_VERSION) == OK
	d["shards"] = 456
	ok = ok and SaveStore.write_atomic(base, d, PROFILE_VERSION) == OK
	var r1: SaveStore.LoadResult = SaveStore.load_validated(base, profile_defaults(), PROFILE_VERSION)
	var pass1: bool = r1.status == SaveStore.Status.OK and int(r1.data["shards"]) == 456
	lines.append("write+read: %s" % ("PASS" if pass1 else "FAIL"))
	# Corrupt the main file; loader must fall back to the backup (123).
	var f: FileAccess = FileAccess.open(base, FileAccess.WRITE)
	f.store_string("{garbage")
	f.close()
	var r2: SaveStore.LoadResult = SaveStore.load_validated(base, profile_defaults(), PROFILE_VERSION)
	var pass2: bool = r2.status == SaveStore.Status.RECOVERED_FROM_BACKUP and int(r2.data["shards"]) == 123
	lines.append("corrupt->backup: %s" % ("PASS" if pass2 else "FAIL"))
	# Migration from a hand-written v1 file.
	var v1: Dictionary = {"crystals": 77, "unlocked_heroes": ["ranger", "warden"]}
	f = FileAccess.open(base, FileAccess.WRITE)
	f.store_string(SaveStore.encode(v1, 1))
	f.close()
	var r3: SaveStore.LoadResult = SaveStore.load_validated(base, profile_defaults(), PROFILE_VERSION,
			profile_migrations())
	var pass3: bool = int(r3.data["shards"]) == 77 and "warden" in r3.data["unlocked_characters"]
	lines.append("migrate v1->v2: %s" % ("PASS" if pass3 else "FAIL"))
	for suffix: String in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(base + suffix):
			DirAccess.remove_absolute(base + suffix)
	ok = ok and pass1 and pass2 and pass3
	return {"ok": ok, "lines": lines}
