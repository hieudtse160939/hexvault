class_name Room
extends Node2D
## Runtime controller for one room: locking doors, spawning waves, clearing,
## rewards, and the contents of special rooms.

signal room_cleared(room: Room)

const COMBAT_TYPES: PackedStringArray = ["combat", "elite", "boss"]

var room_id: int = 0
var room_type: String = "combat"
var depth: int = 0
var floor_index: int = 1
var rect: Rect2i
var template: RoomTemplate
var doors: Array[Dictionary] = []
var spawn_tiles: Array[Vector2i] = []
var special_tile: Vector2i
var chest_tile: Vector2i
var cleared: bool = false
var active: bool = false
var visited: bool = false

var _level: Level
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _waves: Array = []        # Array of Array[Dictionary{id, elite}]
var _wave_i: int = 0
var _alive: int = 0
var _pending: int = 0
var _barriers: Array[Node2D] = []
var _player: Player = null
var boss: Boss = null


func add_door(tiles: Array[Vector2i], dir: Vector2i) -> void:
	doors.append({"tiles": tiles, "dir": dir})


func contains_tile(t: Vector2i) -> bool:
	return rect.has_point(t)


func center_world() -> Vector2:
	return Level.to_world(special_tile)


func is_combat() -> bool:
	return room_type in COMBAT_TYPES


func setup_contents(level: Level) -> void:
	_level = level
	var seed_value: int = level.layout.seed_value if level.layout != null else 0
	_rng.seed = hash([seed_value, floor_index, room_id, "room"])
	cleared = not is_combat()
	var c: Vector2 = Level.to_world(special_tile)
	match room_type:
		"treasure":
			level.add_entity(Chest.create(Chest.Kind.WEAPON, Level.to_world(chest_tile), _rng.randi()))
		"shop":
			_build_shop(level, c)
		"heal":
			var f: Fountain = Fountain.new()
			f.position = c
			level.add_entity(f)
		"event":
			var s: EventStatue = EventStatue.new()
			s.position = c
			level.add_entity(s)
		"exit":
			level.add_entity(Portal.create(Portal.Mode.NEXT_FLOOR, c))
		"combat", "elite":
			_plan_waves()


func _build_shop(level: Level, c: Vector2) -> void:
	var offs: Array[Vector2] = [Vector2(-40, -6), Vector2(-14, -6), Vector2(14, -6), Vector2(40, -6)]
	var held: Array = Game.run.weapons if Game.run != null else []
	var w1: String = WeaponPickup.roll(_rng, floor_index, held)
	var w_price: int = {"common": 20, "rare": 35, "epic": 55, "legendary": 80}.get(Db.weapon(w1).rarity, 30)
	var boon_ids: PackedStringArray = Db.boon_order
	var boon: String = boon_ids[_rng.randi_range(0, boon_ids.size() - 1)]
	var items: Array = [
		["weapon", w1, w_price + floor_index * 5],
		["heart", "", 12 + floor_index * 3],
		["armor", "", 10 + floor_index * 2],
		["boon", boon, 40 + floor_index * 10],
	]
	for i: int in items.size():
		level.add_entity(ShopItem.create(str(items[i][0]), str(items[i][1]), int(items[i][2]), c + offs[i]))
	var keeper: Label = UiTheme.label("BRASS BAZAAR", UiTheme.GOLD, true)
	keeper.add_theme_font_override("font", SpriteLib.font())
	keeper.position = c + Vector2(-34, -44)
	level.fx_layer.add_child(keeper)


# --- waves ------------------------------------------------------------------------
func _enemy_pool() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for id: String in Db.enemies:
		var e: EnemyData = Db.enemies[id]
		if e.min_floor <= floor_index:
			out.append(e)
	return out


func _fill_wave(budget: int, max_count: int) -> Array[Dictionary]:
	var wave: Array[Dictionary] = []
	var pool: Array[EnemyData] = _enemy_pool()
	var guard: int = 0
	while budget > 0 and wave.size() < max_count and guard < 50:
		guard += 1
		var e: EnemyData = pool[_rng.randi_range(0, pool.size() - 1)]
		if e.cost > budget:
			continue
		budget -= e.cost
		wave.append({"id": e.id, "elite": false})
	return wave


func _plan_waves() -> void:
	var difficulty: int = Game.run.difficulty if Game.run != null else 0
	var budget: int = 4 + floor_index * 2 + depth / 2 + difficulty * 2
	_waves.clear()
	if room_type == "elite":
		var pool: Array[EnemyData] = _enemy_pool()
		var leader: EnemyData = pool[_rng.randi_range(0, pool.size() - 1)]
		var w1: Array[Dictionary] = [{"id": leader.id, "elite": true}]
		w1.append_array(_fill_wave(budget / 2, 4))
		_waves.append(w1)
		_waves.append(_fill_wave(budget, 7))
	else:
		var n: int = 2 if floor_index < 3 else 3
		for i: int in n:
			_waves.append(_fill_wave(budget + i, 8))


func on_player_enter(p: Player) -> void:
	_player = p
	if not visited:
		visited = true
	if cleared or active:
		return
	if room_type == "boss":
		_start_boss()
	elif room_type in ["combat", "elite"]:
		_activate()


func _activate() -> void:
	active = true
	_player.flawless_room = true
	_lock()
	_wave_i = 0
	get_tree().create_timer(0.45, false).timeout.connect(_spawn_wave)


func _lock() -> void:
	Sfx.play("door_lock")
	for d: Dictionary in doors:
		for t: Vector2i in d["tiles"]:
			var b: StaticBody2D = StaticBody2D.new()
			b.collision_layer = Level.WORLD_MASK
			b.position = Level.to_world(t)
			var cs: CollisionShape2D = CollisionShape2D.new()
			var sh: RectangleShape2D = RectangleShape2D.new()
			sh.size = Vector2(16, 16)
			cs.shape = sh
			b.add_child(cs)
			var s: AnimatedSprite2D = AnimatedSprite2D.new()
			SpriteLib.apply(s, "prop_barrier")
			s.play(&"idle")
			s.modulate.a = 0.85
			b.add_child(s)
			_level.add_child(b)
			_barriers.append(b)
			_level.set_solid(t, true)
	# Push the player inside if they are standing in a doorway.
	if _player != null and not rect.grow(-1).has_point(Level.to_tile(_player.global_position)):
		var inside: Vector2 = Level.to_world(Level.to_tile(_player.global_position).clamp(rect.position + Vector2i.ONE, rect.end - Vector2i(2, 2)))
		_player.global_position = inside


func _unlock() -> void:
	Sfx.play("door_open")
	for b: Node2D in _barriers:
		if is_instance_valid(b):
			b.queue_free()
	_barriers.clear()
	for d: Dictionary in doors:
		for t: Vector2i in d["tiles"]:
			_level.set_solid(t, false)


func _spawn_wave() -> void:
	if _wave_i >= _waves.size():
		_clear()
		return
	var wave: Array = _waves[_wave_i]
	_wave_i += 1
	var tiles: Array[Vector2i] = _spawn_candidates()
	for i: int in wave.size():
		var entry: Dictionary = wave[i]
		var d: EnemyData = Db.enemy(str(entry["id"]))
		if d == null or tiles.is_empty():
			continue
		var tile: Vector2i = tiles[i % tiles.size()]
		spawn_enemy(d, bool(entry["elite"]), Level.to_world(tile), 0.7)
	if _alive == 0 and _pending == 0:
		_spawn_wave()


## Floor tiles at least 4 tiles from the player, preferring E markers.
func _spawn_candidates() -> Array[Vector2i]:
	var ppos: Vector2i = Level.to_tile(_player.global_position) if _player != null else special_tile
	var marked: Array[Vector2i] = []
	for t: Vector2i in spawn_tiles:
		if _level.is_walkable(t) and (t - ppos).length() >= 4.0:
			marked.append(t)
	if marked.size() < 4:
		for y: int in range(rect.position.y + 1, rect.end.y - 1):
			for x: int in range(rect.position.x + 1, rect.end.x - 1):
				var t2: Vector2i = Vector2i(x, y)
				if _level.is_walkable(t2) and (t2 - ppos).length() >= 5.0 and not t2 in marked:
					marked.append(t2)
	# deterministic shuffle
	for i: int in range(marked.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Vector2i = marked[i]
		marked[i] = marked[j]
		marked[j] = tmp
	return marked


## Telegraphs a spawn rune, then adds the enemy. Returns the (not yet added) enemy.
func spawn_enemy(d: EnemyData, is_elite: bool, pos: Vector2, delay: float) -> Enemy:
	var difficulty: int = Game.run.difficulty if Game.run != null else 0
	var e: Enemy = Enemy.create(d, is_elite, floor_index, difficulty, _rng.randi())
	e.position = pos
	e.aggro = true
	_pending += 1
	var rune: AnimatedSprite2D = AnimatedSprite2D.new()
	SpriteLib.apply(rune, "prop_spawn_rune")
	rune.play(&"idle")
	rune.position = pos + Vector2(0, 4)
	_level.fx_layer.add_child(rune)
	Sfx.play("spawn", -10.0)
	get_tree().create_timer(delay, false).timeout.connect(func() -> void:
		rune.queue_free()
		_pending -= 1
		if not is_inside_tree():
			e.free()
			return
		_alive += 1
		e.died.connect(_on_enemy_died)
		_level.add_entity(e)
		FX.burst("puff", pos))
	return e


func _on_enemy_died(_e: Enemy) -> void:
	_alive -= 1
	if _alive <= 0 and _pending <= 0 and active:
		get_tree().create_timer(0.6, false).timeout.connect(_spawn_wave)


func _clear() -> void:
	if cleared:
		return
	active = false
	cleared = true
	_unlock()
	var flawless: bool = _player != null and _player.flawless_room
	Events.room_cleared.emit(self, flawless)
	room_cleared.emit(self)
	if flawless and room_type == "combat":
		FX.float_text(_player.global_position, "FLAWLESS", UiTheme.ACCENT)
	var c: Vector2 = Level.to_world(rect.get_center())
	if room_type == "elite":
		_level.add_entity(Chest.create(Chest.Kind.LOOT, c, _rng.randi()))
		var floor_node: Node = get_tree().get_first_node_in_group("dungeon_floor")
		if floor_node != null:
			floor_node.call_deferred("offer_boons", "Elite defeated")
	elif _rng.randf() < 0.3:
		Pickup.spawn(Pickup.Kind.HEART if _rng.randf() < 0.5 else Pickup.Kind.ARMOR, c, 1)
	if room_type == "combat" and _rng.randf() < 0.15:
		_level.add_entity(Chest.create(Chest.Kind.LOOT, c, _rng.randi()))


# --- boss ------------------------------------------------------------------------
func _start_boss() -> void:
	active = true
	_player.flawless_room = true
	_lock()
	Sfx.play_music("boss")
	Sfx.play("boss_roar")
	FX.shake(6.0)
	get_tree().create_timer(1.2, false).timeout.connect(func() -> void:
		boss = Boss.create(Db.bosses.get("ossifex", {}), self, Game.run.difficulty if Game.run != null else 0)
		boss.position = Level.to_world(special_tile) + Vector2(0, -40)
		boss.defeated.connect(_on_boss_defeated)
		_level.add_entity(boss))


func _on_boss_defeated() -> void:
	active = false
	cleared = true
	_unlock()
	Events.room_cleared.emit(self, _player != null and _player.flawless_room)
	var c: Vector2 = Level.to_world(special_tile)
	var b: Dictionary = Db.bosses.get("ossifex", {})
	Pickup.spawn(Pickup.Kind.SHARD, c + Vector2(-10, 0), int(b.get("shards", 50)) / 2)
	Pickup.spawn(Pickup.Kind.SHARD, c + Vector2(10, 0), int(b.get("shards", 50)) / 2)
	_level.add_entity(Chest.create(Chest.Kind.LOOT, c + Vector2(-30, 20), _rng.randi()))
	get_tree().create_timer(2.0, false).timeout.connect(func() -> void:
		_level.add_entity(Portal.create(Portal.Mode.VICTORY, c + Vector2(0, 30)))
		Sfx.play("victory"))
