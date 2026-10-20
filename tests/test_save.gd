extends "res://tests/test_case.gd"
## Save system: round trip, backup, corruption recovery, migration, schema repair,
## and the guarantee that dying never removes permanent unlocks.

const BASE: String = "user://test_profile.save"


func _clean() -> void:
	for s: String in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(BASE + s):
			DirAccess.remove_absolute(BASE + s)


func _write_raw(text: String) -> void:
	var f: FileAccess = FileAccess.open(BASE, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_round_trip() -> void:
	_clean()
	var d: Dictionary = SaveManager.profile_defaults()
	d["shards"] = 321
	(d["unlocked_weapons"] as Array).append("thornbow")
	assert_eq(SaveStore.write_atomic(BASE, d, 2), OK)
	var r: SaveStore.LoadResult = SaveStore.load_validated(BASE, SaveManager.profile_defaults(), 2)
	assert_eq(r.status, SaveStore.Status.OK)
	assert_eq(r.data["shards"], 321)
	assert_is(r.data["shards"], TYPE_INT, "ints survive JSON as ints")
	assert_has(r.data["unlocked_weapons"], "thornbow")
	_clean()


func test_missing_file_gives_defaults() -> void:
	_clean()
	var r: SaveStore.LoadResult = SaveStore.load_validated(BASE, SaveManager.profile_defaults(), 2)
	assert_eq(r.status, SaveStore.Status.MISSING)
	assert_eq(r.data["shards"], 0)


func test_backup_created_and_used_on_corruption() -> void:
	_clean()
	var d: Dictionary = SaveManager.profile_defaults()
	d["shards"] = 10
	SaveStore.write_atomic(BASE, d, 2)
	d["shards"] = 20
	SaveStore.write_atomic(BASE, d, 2)
	assert_true(FileAccess.file_exists(BASE + ".bak"), "backup of previous save")
	_write_raw("{\"format\":\"hexvault-save\",\"version\":2,\"sha256\":\"x\"}\n{\"shards\":999}")
	allow_errors()
	var r: SaveStore.LoadResult = SaveStore.load_validated(BASE, SaveManager.profile_defaults(), 2)
	assert_eq(r.status, SaveStore.Status.RECOVERED_FROM_BACKUP)
	assert_eq(r.data["shards"], 10, "tampered/corrupt main file rejected, backup used")
	assert_true(FileAccess.file_exists(BASE + ".corrupt"), "damaged file kept for diagnosis")
	_clean()


func test_truncated_file_without_backup_resets_safely() -> void:
	_clean()
	_write_raw("{\"format\":\"hexvault-sa")
	allow_errors()
	var r: SaveStore.LoadResult = SaveStore.load_validated(BASE, SaveManager.profile_defaults(), 2)
	assert_eq(r.status, SaveStore.Status.RESET_CORRUPT)
	assert_eq(r.data["shards"], 0)
	_clean()


func test_corrupt_save_never_overwrites_backup() -> void:
	_clean()
	var d: Dictionary = SaveManager.profile_defaults()
	d["shards"] = 50
	SaveStore.write_atomic(BASE, d, 2)
	d["shards"] = 60
	SaveStore.write_atomic(BASE, d, 2) # .bak = 50
	_write_raw("garbage")
	d["shards"] = 70
	SaveStore.write_atomic(BASE, d, 2) # main was invalid -> .bak must stay 50
	var bak: Dictionary = {}
	var data: Dictionary = SaveStore.decode(FileAccess.get_file_as_string(BASE + ".bak"), bak)
	assert_eq(int(data.get("shards", -1)), 50)
	_clean()


func test_migration_v1_to_v2() -> void:
	_clean()
	_write_raw(SaveStore.encode({"crystals": 40, "unlocked_heroes": ["ranger", "warden"]}, 1))
	var r: SaveStore.LoadResult = SaveStore.load_validated(BASE, SaveManager.profile_defaults(), 2,
			SaveManager.profile_migrations())
	assert_eq(r.status, SaveStore.Status.MIGRATED)
	assert_eq(r.data["shards"], 40)
	assert_has(r.data["unlocked_characters"], "warden")
	assert_false(r.data.has("crystals"))
	assert_true(r.data.has("quests"), "new fields get defaults")
	_clean()


func test_schema_repairs_wrong_types() -> void:
	var fixes: PackedStringArray = []
	var out: Dictionary = SaveStore.conform({"shards": "lots", "stats": {"kills": 5.0}},
			SaveManager.profile_defaults(), "", fixes)
	assert_eq(out["shards"], 0)
	assert_eq(out["stats"]["kills"], 5)
	assert_eq(out["stats"]["bosses"], 0)
	assert_gt(fixes.size(), 0)


func test_death_keeps_permanent_unlocks() -> void:
	var saved_auto: bool = Profile.autosave
	var saved_data: Dictionary = Profile.data.duplicate(true)
	Profile.autosave = false
	Profile.data = SaveManager.profile_defaults()
	Profile.data["shards"] = 1000
	assert_true(Profile.buy_weapon("thornbow"))
	# warden is in the Guild's free roster now; tinker is still bought with shards
	assert_false(Profile.buy_character("warden"), "roster heroes are free, nothing to buy")
	assert_true(Profile.buy_character("tinker"))
	var before: int = Profile.shards()
	var earned: int = Profile.bank_run({"shards": 12, "victory": false, "floor": 2})
	assert_eq(earned, 12)
	assert_true(Profile.is_weapon_unlocked("thornbow"), "weapon unlock survives death")
	assert_true(Profile.is_character_unlocked("tinker"), "character unlock survives death")
	assert_eq(Profile.shards(), before + 12, "run shards are banked even on death")
	assert_eq(Profile.stat("deaths"), 1)
	Profile.data = saved_data
	Profile.autosave = saved_auto


func test_dev_menu_self_test_passes() -> void:
	allow_errors()
	var rep: Dictionary = SaveManager.self_test()
	assert_true(rep["ok"], str(rep["lines"]))
