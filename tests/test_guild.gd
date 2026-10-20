extends "res://tests/test_case.gd"
## The Adventurers' Guild loop through the real screens: main menu, New Game,
## Continue, character selection, the Guild map (spawn, walls, reachable
## services), mission board -> dungeon -> boss -> rewards -> back to the Guild
## -> another expedition; death returns to the Guild too.
## Numbers in messages refer to the brief's acceptance list (tests 1-28, 50-53).

var _saved: Dictionary
var _auto: bool
var _main: Node = null


func before_each() -> void:
	_auto = Profile.autosave
	_saved = Profile.data.duplicate(true)
	Profile.autosave = false
	Profile.data = SaveManager.profile_defaults()
	Profile.data["seen_tutorial"] = true


func after_each() -> void:
	Game.god_mode = false
	Profile.data = _saved
	Profile.autosave = _auto
	get_tree().paused = false
	Engine.time_scale = 1.0
	Game.run = null


func _boot() -> Node:
	_main = add_scene("res://scenes/main.tscn")
	await wait_frames(4)
	return _main


func _screen() -> Node:
	var s: Node = _main.get("_screen")
	if s is CanvasLayer and s.get_child_count() > 0:
		return s.get_child(0)
	return s


func _buttons(root: Node) -> Dictionary:
	var out: Dictionary = {}
	for b: Node in root.find_children("*", "Button", true, false):
		out[(b as Button).text] = b
	return out


func _find_button(root: Node, prefix: String) -> Button:
	for b: Node in root.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(prefix):
			return b
	return null


func _guild() -> Node:
	return get_tree().get_first_node_in_group("guild")


func _modal_of(guild: Node, type: Variant) -> Node:
	for c: Node in (guild.get("ui_root") as Control).get_children():
		if is_instance_of(c, type):
			return c
	return null


func _close_modals(root: Control) -> void:
	for c: Node in root.get_children():
		if c is Modal:
			c.queue_free()
	await wait_frames(2)
	get_tree().paused = false


# 1 2 3 5
func test_main_menu_and_continue_states() -> void:
	assert_eq(str(ProjectSettings.get_setting("application/run/main_scene")), "res://scenes/main.tscn", "1 project config")
	await _boot()
	assert_eq(Game.current_screen, "title", "2/3 main scene opens the main menu")
	var cont: Button = _find_button(_screen(), "Continue")
	assert_not_null(cont)
	assert_not_null(_find_button(_screen(), "New Game"))
	assert_not_null(_find_button(_screen(), "Settings"))
	assert_true(cont.disabled, "5 no save: Continue is disabled")
	cont.pressed.emit()
	await wait_frames(2)
	assert_eq(Game.current_screen, "title", "5 Continue does nothing without a save")
	Profile.new_game("necromancer")
	Game.goto("title")
	await wait_frames(3)
	cont = _find_button(_screen(), "Continue")
	assert_false(cont.disabled, "5 save exists: Continue enabled")
	assert_string_contains(cont.text, "Morrow")
	cont.pressed.emit()
	await wait_frames(4)
	assert_eq(Game.current_screen, "hub", "Continue enters the Guild")
	assert_eq((_guild().get("player") as Player).character.id, "necromancer", "saved hero restored")
	_main.queue_free()
	await wait_frames(2)


# 4 6 7 8 9
func test_new_game_selection_enters_guild_with_correct_hero() -> void:
	await _boot()
	_find_button(_screen(), "New Game").pressed.emit()
	await wait_frames(3)
	assert_eq(Game.current_screen, "select", "4 New Game opens character selection")
	var sel: Node = _screen()
	assert_eq((sel.get("_previews") as Dictionary).size(), 5, "6 five heroes shown with their sprites")
	sel.call("_show", "assassin")
	_find_button(sel, "Begin").pressed.emit()
	await wait_frames(4)
	assert_eq(Game.current_screen, "hub", "8 Guild loads")
	assert_true(Profile.has_game())
	assert_eq(Profile.selected_hero(), "assassin")
	var g: Node = _guild()
	var p: Player = g.get("player")
	assert_eq(p.character.id, "assassin")
	assert_eq(p.character.sprite, "hero_assassin", "7 the hero's own sheet")
	for a: String in ["idle", "run", "dash", "skill", "hurt", "death"]:
		assert_true(p.body.sprite_frames.has_animation(a), "7 animation %s" % a)
		assert_gt(p.body.sprite_frames.get_frame_count(a), 0)
		assert_not_null(p.body.sprite_frames.get_frame_texture(a, 0))
	var w: Weapon = p.current_weapon()
	assert_not_null(w, "starter weapon equipped")
	assert_eq(w.data.id, Db.character("assassin").start_weapon)
	assert_eq(str(Inventory.equipped_in(Profile.data, "assassin", "weapon").get("base", "")), "w_thornbow", "starting gear is a real item")
	var lvl: Level = g.get("level")
	assert_true(lvl.is_walkable(Level.to_tile(p.global_position)), "9 spawn on floor")
	assert_true(_free_at(lvl, p.global_position), "9 spawn not inside furniture")
	_main.queue_free()
	await wait_frames(2)


func _free_at(lvl: Level, pos: Vector2) -> bool:
	var q: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var c: CircleShape2D = CircleShape2D.new()
	c.radius = 4.0
	q.shape = c
	q.transform = Transform2D(0.0, pos + Vector2(0, 4))
	q.collision_mask = Level.WORLD_MASK
	return lvl.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


# 10 11
func test_guild_walls_block_and_every_service_is_reachable() -> void:
	await _boot()
	Profile.new_game("duelist")
	Game.goto("hub")
	await wait_physics_frames(3)
	var g: Node = _guild()
	var lvl: Level = g.get("level")
	var p: Player = g.get("player")
	# 10: walk into the west wall for a second
	p.global_position = Level.to_world(Vector2i(1, 10))
	press_action("move_left")
	await wait_seconds(1.0)
	release_action("move_left")
	assert_gt(p.global_position.x, 8.0, "10 wall stops the hero")
	assert_true(lvl.floor_tiles.has(Level.to_tile(p.global_position)))
	# 11: flood fill the walkable space the hero's collider fits in, from the spawn
	var start: Vector2 = Level.to_world(g.SPAWN)
	var step: float = 4.0
	var seen: Dictionary = {}
	var queue: Array[Vector2] = [start]
	seen[start] = true
	while not queue.is_empty():
		var cur: Vector2 = queue.pop_back()
		for d: Vector2 in [Vector2(step, 0), Vector2(-step, 0), Vector2(0, step), Vector2(0, -step)]:
			var n: Vector2 = cur + d
			if seen.has(n) or not lvl.floor_tiles.has(Level.to_tile(n)) or not _free_at(lvl, n):
				continue
			seen[n] = true
			queue.append(n)
	assert_gt(seen.size(), 500)
	var stations: Dictionary = g.get("stations")
	assert_gt(stations.size(), 8)
	for title: String in stations:
		var s: HubStation = stations[title]
		var best: Vector2 = Vector2.INF
		for pt: Vector2 in seen:
			if pt.distance_to(s.global_position) < Player.INTERACT_RANGE - 2.0 and lvl.tiles_clear(pt, s.global_position):
				best = pt
				break
		assert_ne(best, Vector2.INF, "11 %s reachable" % title)
		if best == Vector2.INF:
			continue
		# stand there and let the real interaction detection pick something
		p.global_position = best
		await wait_physics_frames(2)
		assert_true(p.has_interact_target(), "11 %s gives an interaction prompt" % title)
	_main.queue_free()
	await wait_frames(2)


# 13 14 + training dummy
func test_equipment_station_shop_and_training_dummy() -> void:
	await _boot()
	Profile.new_game("warden")
	Profile.data["gold"] = 5000
	Game.goto("hub")
	await wait_physics_frames(3)
	var g: Node = _guild()
	var p: Player = g.get("player")
	var stations: Dictionary = g.get("stations")
	(stations["Equipment"] as HubStation).interact(p)
	await wait_frames(2)
	var inv: InventoryPanel = _modal_of(g, InventoryPanel)
	assert_not_null(inv, "13 the equipment station opens the real inventory")
	assert_true(get_tree().paused, "game paused under the menu")
	assert_false(p.input_enabled, "no movement/attacks behind the menu")
	var uid: String = Profile.give_item(ItemGen.generate("x_copper_ring", 1, "common", RandomNumberGenerator.new()))
	inv.refresh()
	inv.select(uid)
	var atk0: float = float(HeroStats.for_hero(Profile.data, "warden")["attack"])
	inv.call("_on_main")
	assert_eq(Inventory.owner_of(Profile.data, uid), "warden", "13 Equip button equips")
	assert_gt(float(HeroStats.for_hero(Profile.data, "warden")["attack"]), atk0)
	inv.call("_on_main")
	assert_has(Inventory.bag(Profile.data), uid, "13 Unequip button unequips")
	var w0: Weapon = p.current_weapon()
	var ammo0: int = w0.ammo
	press_action("fire")   # the click that closes the menu is still held
	inv.queue_free()
	await wait_physics_frames(4)
	assert_false(get_tree().paused)
	assert_true(p.input_enabled)
	assert_eq(w0.ammo, ammo0, "closing a menu with the fire button never fires")
	release_action("fire")
	await wait_physics_frames(2)
	press_action("fire")
	await wait_physics_frames(3)
	release_action("fire")
	assert_lt(w0.ammo, ammo0, "a fresh press fires again")
	(stations["Guild Shop"] as HubStation).interact(p)
	await wait_frames(2)
	var shop: ShopPanel = _modal_of(g, ShopPanel)
	assert_not_null(shop, "14 shop opens")
	var bag0: int = Inventory.bag(Profile.data).size()
	var price: int = int((Profile.shop_stock()[0] as Dictionary)["price"])
	shop.call("_pick", 0)
	shop.call("_on_buy")
	shop.call("_on_buy")
	assert_eq(Profile.gold(), 5000 - price, "14 charged once")
	assert_eq(Inventory.bag(Profile.data).size(), bag0 + 1, "14 one item delivered")
	shop.queue_free()
	await wait_frames(2)
	# training dummy takes real weapon hits
	var dummy: TrainingDummy = (g.get("dummies") as Array)[0]
	p.global_position = dummy.global_position + Vector2(-30, -4)
	await wait_physics_frames(2)
	var w: Weapon = p.current_weapon()
	for i: int in 30:
		w.try_fire((dummy.global_position + Vector2(0, -6) - p.global_position).normalized())
		await wait_physics_frames(3)
	assert_gt(dummy.total, 0, "dummy registers damage")
	assert_gt(dummy.dps(), 0.0)
	assert_eq(Game.current_screen, "hub", "training never launches a mission")
	_main.queue_free()
	await wait_frames(2)


func _kill_everything() -> void:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("receive_hit") and bool(e.call("is_alive")):
			e.call("receive_hit", HitInfo.make(99999, Vector2.ZERO, true, Vector2.ZERO))


func _clear_floor(fl: Node) -> void:
	var lvl: Level = fl.get("level")
	for room: Room in lvl.rooms:
		if room.room_type not in ["combat", "elite"]:
			continue
		lvl.player.global_position = Level.to_world(room.rect.get_center())
		await wait_physics_frames(3)
		var guard: int = 0
		while not room.cleared and guard < 900:
			guard += 1
			_kill_everything()
			await wait_physics_frames(2)
			get_tree().paused = false
		assert_true(room.cleared, "24 room %d cleared" % room.room_id)
		assert_true(room._barriers.is_empty(), "25 doors open after the fight")
		var root: Control = fl.get("ui_root")
		for c: Node in root.get_children():
			if c is BoonChoice:
				(c as BoonChoice).chosen.emit((c as BoonChoice).choices[0])
				c.queue_free()
		await wait_frames(1)
		get_tree().paused = false


func _collect_all_loot(p: Player) -> int:
	var n: int = 0
	var picks: Array[ItemPickup] = []
	for c: Node in Level.current.entities.get_children():
		if c is ItemPickup and not (c as ItemPickup).collected:
			picks.append(c)
	for pick: ItemPickup in picks:
		if not is_instance_valid(pick):
			n += 1    # already walked over while reaching another drop
			continue
		p.global_position = pick.global_position
		await wait_physics_frames(2)  # walking onto it collects it
		if not is_instance_valid(pick) or pick.try_collect(p):
			n += 1
	return n


# 12 15 16-28 52 53
func test_expedition_loop_victory_return_and_rerun() -> void:
	await _boot()
	Profile.new_game("pyromancer")
	Game.goto("hub")
	await wait_physics_frames(3)
	Game.god_mode = true
	var g: Node = _guild()
	var p: Player = g.get("player")
	(g.get("stations")["Mission Board"] as HubStation).interact(p)
	await wait_frames(2)
	var board: MissionBoard = _modal_of(g, MissionBoard)
	assert_not_null(board, "12 mission board opens")
	board.set("_sel", "ember_vault")
	board.refresh()
	assert_true((board.get("_go") as Button).disabled, "locked mission cannot launch")
	board.set("_sel", "forgotten_catacombs")
	board.refresh()
	board.call("_on_go")
	await wait_frames(10)
	assert_eq(Game.current_screen, "dungeon", "15/16 the mission launches the dungeon")
	assert_eq(Game.run.mission_id, "forgotten_catacombs")
	assert_eq(Game.run.total_floors, 2)
	var gold0: int = Profile.gold()
	var exp_rec: Dictionary = Profile.character_record("pyromancer")
	var lvl_before: int = int(exp_rec["level"]) * 100000 + int(exp_rec["exp"])
	for f: int in range(1, 3):
		var fl: Node = get_tree().get_first_node_in_group("dungeon_floor")
		assert_not_null(fl)
		assert_ne(str(fl.call("objective_text")), "", "HUD objective present")
		var lvl: Level = fl.get("level")
		if f == 1:
			var p1: Player = lvl.player
			var start: Vector2 = p1.global_position
			press_action("move_right")
			await wait_seconds(0.4)
			release_action("move_right")
			assert_gt(p1.global_position.x, start.x + 5.0, "17 movement works")
		await _clear_floor(fl)
		if f == 1:
			var portal: Portal = null
			for n: Node in lvl.entities.get_children():
				if n is Portal:
					portal = n
			assert_not_null(portal, "25 exit portal")
			portal.interact(lvl.player)
			await wait_seconds(0.8)
		else:
			var boss_room: Room = null
			for r: Room in lvl.rooms:
				if r.room_type == "boss":
					boss_room = r
			lvl.player.global_position = Level.to_world(boss_room.rect.get_center() + Vector2i(0, 4))
			assert_true(await wait_until(func() -> bool: return boss_room.boss != null and is_instance_valid(boss_room.boss), 5.0), "boss spawned")
			await wait_seconds(0.3)
			boss_room.boss.receive_hit(HitInfo.make(9999999, Vector2.ZERO, true, Vector2.ZERO))
			assert_true(await wait_until(func() -> bool: return boss_room.cleared, 4.0), "26 boss defeated")
			await wait_seconds(0.5)
			var bag0: int = Inventory.bag(Profile.data).size()
			var picked: int = await _collect_all_loot(lvl.player)
			assert_gt(picked, 0, "22/23 boss loot spawned and collected")
			assert_gt(Inventory.bag(Profile.data).size(), bag0, "loot in the real inventory")
			assert_true(await wait_until(func() -> bool:
				for n2: Node in lvl.entities.get_children():
					if n2 is Portal and (n2 as Portal).mode == Portal.Mode.VICTORY:
						return true
				return false, 4.0), "victory portal")
			for n3: Node in lvl.entities.get_children():
				if n3 is Portal:
					(n3 as Portal).interact(lvl.player)
			await wait_seconds(0.8)
	assert_eq(Game.current_screen, "results", "27 completion summary")
	assert_true(bool(Game.last_summary["victory"]))
	assert_true(Profile.mission_completed("forgotten_catacombs"), "42 mission marked complete")
	assert_true(Profile.mission_unlocked("ember_vault"))
	assert_gt(Profile.gold(), gold0, "24 rewards granted")
	assert_gt(int(exp_rec["level"]) * 100000 + int(exp_rec["exp"]), lvl_before, "39 experience gained")
	var gold_after: int = Profile.gold()
	_find_button(_screen(), "Return to the Guild").pressed.emit()
	await wait_frames(4)
	assert_eq(Game.current_screen, "hub", "28 back in the Guild")
	assert_null(Game.run, "run-only state reset")
	assert_eq(Profile.gold(), gold_after, "no rewards granted twice on return")
	assert_eq((_guild().get("player") as Player).character.id, "pyromancer", "same hero")
	assert_true(Game.start_mission("ember_vault"), "53 another expedition starts")
	await wait_frames(8)
	assert_eq(Game.current_screen, "dungeon")
	assert_eq(Game.run.total_floors, 3)
	_main.queue_free()
	await wait_frames(2)


# 27 death path
func test_death_returns_to_guild_and_keeps_progress() -> void:
	await _boot()
	Profile.new_game("duelist")
	Game.start_mission("forgotten_catacombs", 31337)
	await wait_frames(8)
	var fl: Node = get_tree().get_first_node_in_group("dungeon_floor")
	var p: Player = fl.get("player")
	Game.run.coins = 50
	var item_uid: String = Profile.give_item(ItemGen.make_book("book_veil"))
	p.health.invulnerable = false
	p.health.take(HitInfo.make(9999, Vector2.ZERO, false, Vector2.ZERO))
	assert_false(p.is_alive())
	var w: Weapon = p.current_weapon()
	assert_false(w.visible, "dead hero's weapon is gone")
	assert_true(await wait_until(func() -> bool:
		for c: Node in (fl.get("ui_root") as Control).get_children():
			if c is DeathScreen:
				return true
		return false, 4.0), "death screen")
	p.health.take(HitInfo.make(9999, Vector2.ZERO, false, Vector2.ZERO))
	var ds: DeathScreen = null
	for c2: Node in (fl.get("ui_root") as Control).get_children():
		if c2 is DeathScreen:
			ds = c2
	assert_eq(_count_death_screens(fl), 1, "one death event")
	var g0: int = Profile.gold()
	ds.give_up.emit()
	await wait_frames(4)
	assert_eq(Game.current_screen, "results")
	assert_false(bool(Game.last_summary["victory"]))
	assert_eq(Profile.gold(), g0 + 25, "half of the coins kept on defeat")
	assert_false(Profile.mission_completed("forgotten_catacombs"))
	assert_false(Inventory.item(Profile.data, item_uid).is_empty(), "items found are kept")
	Game.return_to_guild()
	await wait_frames(4)
	assert_eq(Game.current_screen, "hub", "return to the Guild after death")
	_main.queue_free()
	await wait_frames(2)


func _count_death_screens(fl: Node) -> int:
	var n: int = 0
	for c: Node in (fl.get("ui_root") as Control).get_children():
		if c is DeathScreen:
			n += 1
	return n


# 20 enemy cooldowns
func test_enemy_attacks_respect_cooldowns() -> void:
	var lvl: Level = Level.new()
	add_child_autofree(lvl)
	for y: int in range(-6, 7):
		for x: int in range(-6, 7):
			lvl.floor_tiles[Vector2i(x, y)] = true
	lvl.build_nav()
	var p: Player = Player.create(Db.character("warden"))
	lvl.player = p
	lvl.add_entity(p)
	var melee: EnemyData = null
	for id: String in Db.enemies:
		if (Db.enemies[id] as EnemyData).behavior == "chaser":
			melee = Db.enemies[id]
	assert_not_null(melee)
	var e: Enemy = Enemy.create(melee, false, 1, 0, 3)
	e.position = Vector2(14, 0)
	e.aggro = true
	lvl.add_entity(e)
	await wait_frames(1)
	p.health.setup(999, 0, 0.0)
	var hits: Array = [0]
	p.health.damaged.connect(func(_a: int, _i: HitInfo) -> void: hits[0] += 1)
	await wait_seconds(3.0)
	assert_gt(hits[0], 0, "19 enemy damages the player")
	var min_cd: float = minf(melee.attack_cooldown, Enemy.CONTACT_COOLDOWN)
	assert_lte(hits[0], int(3.0 / min_cd) + 2, "20 hits limited by cooldowns, not every frame")


func assert_lte(a: int, b: int, msg: String) -> void:
	assert_true(a <= b, "%s (%d <= %d)" % [msg, a, b])
