extends "res://tests/test_case.gd"
## Data files: schema validity, cross references, room template navigability.


func test_database_loads_without_errors() -> void:
	Db.reload()
	assert_eq(Db.load_errors, PackedStringArray(), "data cross-validation errors")
	assert_gt(Db.weapons.size(), 8)
	assert_gt(Db.characters.size(), 2)
	assert_gt(Db.enemies.size(), 4)


func test_every_weapon_is_valid() -> void:
	for id: String in Db.weapon_order:
		var w: WeaponData = Db.weapon(id)
		assert_eq(w.validate(), PackedStringArray(), "weapon %s" % id)


func test_weapon_categories_cover_design() -> void:
	var cats: Dictionary = {}
	for id: String in Db.weapon_order:
		cats[Db.weapon(id).category] = true
	for c: String in ["pistol", "shotgun", "assault_rifle", "sniper", "bow", "melee", "magic", "explosive", "experimental"]:
		assert_true(cats.has(c), "category %s present" % c)


func test_all_room_templates_navigable() -> void:
	for d: Dictionary in Db.room_templates:
		var t: RoomTemplate = RoomTemplate.from_dict(d)
		assert_eq(t.validate(), PackedStringArray(), "template %s" % t.id)


func test_every_room_type_has_a_template() -> void:
	for ty: String in ["start", "combat", "elite", "treasure", "shop", "heal", "event", "exit", "boss"]:
		assert_false(Db.templates_for(ty).is_empty(), "type %s" % ty)


func test_special_rooms_have_centre_marker() -> void:
	for ty: String in ["shop", "heal", "event", "exit", "boss", "start"]:
		for d: Dictionary in Db.templates_for(ty):
			var t: RoomTemplate = RoomTemplate.from_dict(d)
			assert_eq(t.cells_with("S").size(), 1, "%s needs one S marker" % t.id)


func test_enemy_sprites_have_required_animations() -> void:
	for id: String in Db.enemies:
		var e: EnemyData = Db.enemy(id)
		var sf: SpriteFrames = SpriteLib.frames(e.sprite)
		for anim: String in ["idle", "move", "attack", "hurt", "death"]:
			assert_true(sf.has_animation(anim), "%s has %s" % [id, anim])


func test_hero_sprites_have_required_animations() -> void:
	for id: String in Db.character_order:
		var sf: SpriteFrames = SpriteLib.frames(Db.character(id).sprite)
		for anim: String in ["idle", "run", "hurt", "dash", "skill", "death"]:
			assert_true(sf.has_animation(anim), "%s has %s" % [id, anim])
			assert_gt(sf.get_frame_count(anim), 0)
		assert_gt(sf.get_frame_count("run"), 3, "run is a real cycle, not a still")
