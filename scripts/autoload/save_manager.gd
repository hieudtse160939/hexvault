extends Node
## Owns the save file locations and the profile/settings schemas + migrations.

const PROFILE_VERSION: int = 4
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
		"selected_character": "duelist",
		"characters": {},  # id -> HeroProgress record (mastery, level, tree, skills, equipment)
		"difficulty_unlocked": 0,
		"seen_tutorial": false,
		# v4: Adventurers' Guild
		"guild_started": false,   # a New Game was started (enables Continue)
		"gold": 0,
		"items": {},              # uid -> item instance (exact rolls, never re-rolled)
		"bag": [],                # unequipped item uids
		"next_uid": 1,
		"missions": {},           # id -> {"completed": int, "attempts": int, "best_time": int}
		"expeditions": 0,         # expeditions finished (shop restock counter)
		"shop": {},               # {"restock": int, "stock": [{"item": inst, "price": int, "sold": bool}]}
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


## v2 had no per-character progress. Characters the player already owns start
## a mastery record; run counts are unknown so they start at 0 (never negative).
static func migrate_profile_v2(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var chars: Dictionary = {}
	var owned: Variant = out.get("unlocked_characters", [])
	if owned is Array:
		for id: Variant in owned:
			chars[str(id)] = {"xp": 0, "runs": 0, "wins": 0, "best_floor": 0}
	out["characters"] = chars
	return out


## v3 had no Guild: no gold, items, levels or missions. Existing players keep
## everything; a profile that already played runs can Continue straight into
## the Guild, and the selected hero moves to the playable roster if needed.
## Defaults for the new keys are added by SaveStore.conform afterwards.
static func migrate_profile_v3(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var stats: Dictionary = out.get("stats", {}) if out.get("stats", {}) is Dictionary else {}
	out["guild_started"] = int(stats.get("runs", 0)) > 0 or int(stats.get("runs_started", 0)) > 0
	out["gold"] = 0
	var chars: Variant = out.get("characters", {})
	if chars is Dictionary:
		for id: Variant in chars:
			if chars[id] is Dictionary:
				var rec: Dictionary = chars[id]
				rec["level"] = 1
				rec["exp"] = 0
				rec["sp"] = 0
	return out


func profile_migrations() -> Dictionary:
	return {1: migrate_profile_v1, 2: migrate_profile_v2, 3: migrate_profile_v3}


## Copies the current profile to profile.previous.save before a New Game
## replaces it. Returns the archive path ("" if there was nothing to keep).
func archive_profile() -> String:
	if not FileAccess.file_exists(profile_path):
		return ""
	var dst: String = profile_path.get_basename() + ".previous.save"
	if DirAccess.copy_absolute(profile_path, dst) != OK:
		push_warning("SaveManager: could not archive the profile")
		return ""
	return dst


func has_profile_file() -> bool:
	return FileAccess.file_exists(profile_path) or FileAccess.file_exists(profile_path + ".bak")


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
