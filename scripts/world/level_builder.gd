class_name LevelBuilder
extends RefCounted
## Turns an abstract DungeonLayout into tiles, walls, props, doors and Room nodes.
##
## Each layout cell is CELL_W x CELL_H tiles. A room interior is centred in its
## cell; rooms in the same grid row/column share a centre line, so straight
## 3-wide corridors always line up with the 3-wide centred doors.

const CELL_W: int = 33
const CELL_H: int = 27


static func room_rect(cell: Vector2i, t: RoomTemplate) -> Rect2i:
	var c: Vector2i = Vector2i(cell.x * CELL_W + CELL_W / 2, cell.y * CELL_H + CELL_H / 2)
	return Rect2i(c - Vector2i((t.width - 1) / 2, (t.height - 1) / 2), Vector2i(t.width, t.height))


static func _template_by_id(id: String) -> RoomTemplate:
	for d: Dictionary in Db.room_templates:
		if str(d.get("id", "")) == id:
			return RoomTemplate.from_dict(d)
	return null


static func build(level: Level, layout: DungeonLayout) -> void:
	level.layout = layout
	level.rng.seed = hash([layout.seed_value, layout.floor_index, "level"])
	var corridor: Dictionary = {}
	var runes: Dictionary = {}
	var room_nodes: Dictionary = {} # id -> Room
	# 1. rooms
	for r: Dictionary in layout.rooms:
		var t: RoomTemplate = _template_by_id(str(r["template_id"]))
		if t == null:
			push_error("LevelBuilder: missing template %s" % r["template_id"])
			continue
		var rect: Rect2i = room_rect(r["cell"], t)
		var room: Room = Room.new()
		room.room_id = int(r["id"])
		room.room_type = str(r["type"])
		room.depth = int(r["depth"])
		room.rect = rect
		room.template = t
		room.floor_index = layout.floor_index
		room.name = "Room%d_%s" % [room.room_id, room.room_type]
		for y: int in t.height:
			for x: int in t.width:
				var tile: Vector2i = rect.position + Vector2i(x, y)
				var ch: String = t.char_at(x, y)
				if ch == "#":
					continue
				level.floor_tiles[tile] = true
				if ch == "r":
					runes[tile] = true
		for c: Vector2i in t.cells_with("E"):
			room.spawn_tiles.append(rect.position + c)
		var s: Array[Vector2i] = t.cells_with("S")
		room.special_tile = rect.position + (s[0] if not s.is_empty() else Vector2i((t.width - 1) / 2, (t.height - 1) / 2))
		var ch_cells: Array[Vector2i] = t.cells_with("C")
		room.chest_tile = rect.position + (ch_cells[0] if not ch_cells.is_empty() else Vector2i((t.width - 1) / 2, (t.height - 1) / 2))
		room_nodes[room.room_id] = room
		level.rooms.append(room)
		level.add_child(room)
	# 2. corridors + doors
	for e: Vector2i in layout.edges:
		var a: Room = room_nodes.get(e.x, null)
		var b: Room = room_nodes.get(e.y, null)
		if a == null or b == null:
			continue
		var d: Vector2i = layout.dir_between(e.x, e.y)
		if d.x < 0 or d.y < 0: # normalise so a is left/top of b
			var tmp: Room = a
			a = b
			b = tmp
			d = -d
		if d.x == 1:
			var cy: int = a.rect.position.y + (a.rect.size.y - 1) / 2
			var x0: int = a.rect.end.x
			var x1: int = b.rect.position.x - 1
			for x: int in range(x0, x1 + 1):
				for o: int in [-1, 0, 1]:
					var t2: Vector2i = Vector2i(x, cy + o)
					level.floor_tiles[t2] = true
					if x != x0 and x != x1:
						corridor[t2] = true
			a.add_door([Vector2i(x0, cy - 1), Vector2i(x0, cy), Vector2i(x0, cy + 1)], Vector2i(1, 0))
			b.add_door([Vector2i(x1, cy - 1), Vector2i(x1, cy), Vector2i(x1, cy + 1)], Vector2i(-1, 0))
		else:
			var cx: int = a.rect.position.x + (a.rect.size.x - 1) / 2
			var y0: int = a.rect.end.y
			var y1: int = b.rect.position.y - 1
			for y: int in range(y0, y1 + 1):
				for o: int in [-1, 0, 1]:
					var t3: Vector2i = Vector2i(cx + o, y)
					level.floor_tiles[t3] = true
					if y != y0 and y != y1:
						corridor[t3] = true
			a.add_door([Vector2i(cx - 1, y0), Vector2i(cx, y0), Vector2i(cx + 1, y0)], Vector2i(0, 1))
			b.add_door([Vector2i(cx - 1, y1), Vector2i(cx, y1), Vector2i(cx + 1, y1)], Vector2i(0, -1))
	paint(level, corridor, runes, layout.floor_index >= (Game.run.total_floors if Game.run != null else RunState.TOTAL_FLOORS))
	level.build_nav()
	# 3. props from template glyphs
	for room: Room in level.rooms:
		var t4: RoomTemplate = room.template
		for y: int in t4.height:
			for x: int in t4.width:
				var tile: Vector2i = room.rect.position + Vector2i(x, y)
				match t4.char_at(x, y):
					"P":
						level.add_entity(SolidProp.create("prop_pillar", Level.to_world(tile), Vector2(12, 10), Vector2(0, -8)))
						level.set_solid(tile, true)
					"L":
						level.add_entity(SolidProp.create("prop_lamp", Level.to_world(tile), Vector2(8, 6), Vector2.ZERO))
						level.set_solid(tile, true)
					"X":
						level.add_entity(Breakable.create(Breakable.Kind.CRATE, tile))
						level.set_solid(tile, true)
					"B":
						level.add_entity(Breakable.create(Breakable.Kind.BARREL, tile))
						level.set_solid(tile, true)
	for room: Room in level.rooms:
		room.setup_contents(level)


## Floor variants, corridor tiles, and walls (with south-facing faces) around all floor.
static func paint(level: Level, corridor: Dictionary, runes: Dictionary, boss_floor: bool) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = level.rng.seed
	var walls: Dictionary = {}
	for t: Vector2i in level.floor_tiles:
		var idx: int
		if corridor.has(t):
			idx = Tiles.CORRIDOR_CRACKED if rng.randf() < 0.12 else Tiles.CORRIDOR
		elif runes.has(t):
			idx = Tiles.BOSS_RUNE if boss_floor else Tiles.FLOOR_RUNE
		else:
			var roll: float = rng.randf()
			idx = Tiles.FLOOR_CRACKED if roll < 0.06 else Tiles.FLOOR[rng.randi_range(0, 3)]
		level.floor_layer.set_cell(t, 0, Tiles.coords(idx))
		for dy: int in [-1, 0, 1]:
			for dx: int in [-1, 0, 1]:
				var n: Vector2i = t + Vector2i(dx, dy)
				if not level.floor_tiles.has(n):
					walls[n] = true
	# Wall faces two tiles tall would look better, but one-tile faces keep
	# collision exactly on the tile grid, which the navigation relies on.
	for w: Vector2i in walls:
		var below_floor: bool = level.floor_tiles.has(w + Vector2i(0, 1))
		var idx2: int = Tiles.WALL_TOP
		if below_floor:
			var r: float = rng.randf()
			if r < 0.07:
				idx2 = Tiles.WALL_LAMP
			elif r < 0.11:
				idx2 = Tiles.WALL_BANNER
			else:
				idx2 = Tiles.WALL_FACE[rng.randi_range(0, 1)]
		level.wall_layer.set_cell(w, 0, Tiles.coords(idx2))
