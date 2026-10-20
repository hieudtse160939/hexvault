class_name Tiles
extends RefCounted
## Dungeon TileSet built in code from assets/tiles/dungeon.png.
## Atlas indices are the contract with tools/artgen/world.py::tileset().

const SIZE: int = 16
const COLS: int = 8
const FLOOR: Array[int] = [0, 1, 2, 3]
const FLOOR_CRACKED: int = 4
const FLOOR_RUNE: int = 5
const CORRIDOR: int = 6
const CORRIDOR_CRACKED: int = 7
const WALL_TOP: int = 8
const WALL_FACE: Array[int] = [9, 10]
const WALL_LAMP: int = 11
const WALL_BANNER: int = 12
const HUB_FLOOR: int = 13
const HUB_RUNE: int = 14
const BOSS_RUNE: int = 15
const SOLID_TILES: Array[int] = [8, 9, 10, 11, 12]

static var _tileset: TileSet = null


static func coords(index: int) -> Vector2i:
	return Vector2i(index % COLS, index / COLS)


static func tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(SIZE, SIZE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)  # "world"
	ts.set_physics_layer_collision_mask(0, 0)
	var src: TileSetAtlasSource = TileSetAtlasSource.new()
	src.texture = load("res://assets/tiles/dungeon.png") as Texture2D
	src.texture_region_size = Vector2i(SIZE, SIZE)
	ts.add_source(src, 0)
	var h: float = SIZE / 2.0
	var square: PackedVector2Array = [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]
	for i: int in 16:
		var c: Vector2i = coords(i)
		src.create_tile(c)
		if i in SOLID_TILES:
			var td: TileData = src.get_tile_data(c, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, square)
	_tileset = ts
	return ts
