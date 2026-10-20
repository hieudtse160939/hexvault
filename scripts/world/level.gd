class_name Level
extends Node2D
## Runtime container for one playable map (a dungeon floor or the hub).
## Owns tile layers, navigation grid, entity/projectile/FX layers and rooms.

const TILE: int = 16
const WORLD_MASK: int = 1        # layer 1
const BREAKABLE_MASK: int = 1 << 7

static var current: Level = null

var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var entities: Node2D            # y-sorted actors and props
var projectiles: Node2D
var fx_layer: Node2D
var rooms: Array[Room] = []
var nav: AStarGrid2D = AStarGrid2D.new()
var player: Player = null
var layout: DungeonLayout = null
var floor_tiles: Dictionary = {} # Vector2i -> true (walkable ground)
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var active_room: Room = null
var pool: ProjectilePool


func _init() -> void:
	floor_layer = TileMapLayer.new()
	floor_layer.name = "Floor"
	floor_layer.tile_set = Tiles.tileset()
	floor_layer.collision_enabled = false
	floor_layer.scale = Tiles.layer_scale()
	add_child(floor_layer)
	wall_layer = TileMapLayer.new()
	wall_layer.name = "Walls"
	wall_layer.tile_set = Tiles.tileset()
	wall_layer.scale = Tiles.layer_scale()
	add_child(wall_layer)
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	projectiles = Node2D.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	fx_layer = Node2D.new()
	fx_layer.name = "FX"
	fx_layer.z_index = 20
	add_child(fx_layer)
	pool = ProjectilePool.new()
	pool.name = "ProjectilePool"
	add_child(pool)


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


static func to_tile(world: Vector2) -> Vector2i:
	return Vector2i(floori(world.x / TILE), floori(world.y / TILE))


static func to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE + TILE / 2.0, tile.y * TILE + TILE / 2.0)


func is_walkable(tile: Vector2i) -> bool:
	return floor_tiles.has(tile) and nav.is_in_boundsv(tile) and not nav.is_point_solid(tile)


func build_nav() -> void:
	var rect: Rect2i = Rect2i()
	var first: bool = true
	for t: Vector2i in floor_tiles:
		if first:
			rect = Rect2i(t, Vector2i.ONE)
			first = false
		else:
			rect = rect.expand(t).expand(t + Vector2i.ONE)
	rect = rect.grow(1)
	nav.region = rect
	nav.cell_size = Vector2(TILE, TILE)
	nav.offset = Vector2(TILE / 2.0, TILE / 2.0)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nav.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nav.update()
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var t: Vector2i = Vector2i(x, y)
			if not floor_tiles.has(t):
				nav.set_point_solid(t, true)


func set_solid(tile: Vector2i, solid: bool) -> void:
	if nav.is_in_boundsv(tile):
		nav.set_point_solid(tile, solid)


## World-space path (tile centres) from a to b; empty if unreachable.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a: Vector2i = to_tile(from)
	var b: Vector2i = to_tile(to)
	if not nav.is_in_boundsv(a) or not nav.is_in_boundsv(b):
		return PackedVector2Array()
	if nav.is_point_solid(b):
		b = nearest_open(b, 3)
		if b == Vector2i(-99999, -99999):
			return PackedVector2Array()
	return nav.get_point_path(a, b, true)


func nearest_open(t: Vector2i, radius: int) -> Vector2i:
	for r: int in range(1, radius + 1):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				var c: Vector2i = t + Vector2i(dx, dy)
				if is_walkable(c):
					return c
	return Vector2i(-99999, -99999)


## True if the segment stays over walkable ground (no wall tile in between).
## Used for interaction checks, where the target's own collider must not count.
func tiles_clear(a: Vector2, b: Vector2) -> bool:
	var n: int = maxi(int(a.distance_to(b) / 4.0), 1)
	for i: int in range(1, n):
		if not floor_tiles.has(to_tile(a.lerp(b, float(i) / n))):
			return false
	return true


## True if nothing on the world/breakable layers blocks the segment.
func line_clear(a: Vector2, b: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(a, b, WORLD_MASK | BREAKABLE_MASK)
	return space.intersect_ray(q).is_empty()


func room_at_world(pos: Vector2) -> Room:
	var t: Vector2i = to_tile(pos)
	for r: Room in rooms:
		if r.contains_tile(t):
			return r
	return null


func add_entity(n: Node2D) -> void:
	entities.add_child(n)


func enemies() -> Array[Node]:
	return get_tree().get_nodes_in_group("enemies")


## Closest living enemy within `max_dist` of `pos` (optionally requiring line of sight).
func nearest_enemy(pos: Vector2, max_dist: float, need_los: bool = false, exclude: Array = []) -> Node2D:
	var best: Node2D = null
	var best_d: float = max_dist * max_dist
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		var n: Node2D = e as Node2D
		if n == null or n in exclude or not n.has_method("is_alive") or not bool(n.call("is_alive")):
			continue
		var d: float = pos.distance_squared_to(n.global_position)
		if d < best_d and (not need_los or line_clear(pos, n.global_position)):
			best = n
			best_d = d
	return best


func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var r: Room = room_at_world(player.global_position)
	if r != null and r != active_room:
		active_room = r
		r.on_player_enter(player)
		Events.room_entered.emit(r)
