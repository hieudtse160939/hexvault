class_name MapLoader
extends RefCounted
## Builds a hand-authored map (data/maps/<id>.json) into a Level: floor tiles
## from `rows` + `legend`, walls painted automatically around the floor, floor
## decals, solid props, NPCs, room labels, warm light pools and the ambient
## mood. Shared by every authored map (the Guild now; towns and regions later),
## so a new map is a data file plus the scene script that wires its services.

const FLOOR_TILES: Dictionary = {
	"guild_wood": -1,              # alternates Tiles.GUILD_WOOD variants
	"guild_rug": Tiles.GUILD_RUG,
	"guild_stage": Tiles.GUILD_STAGE,
	"stone": Tiles.HUB_FLOOR,
	"dungeon": Tiles.FLOOR[0],
	"grass": Tiles.GRASS,
}


static func load_map(id: String) -> Dictionary:
	return Db.read_json("res://data/maps/%s.json" % id)


## Tile coordinates (floats, x.5 = cell centre) -> world position.
static func at(v: Variant) -> Vector2:
	var a: Array = v
	return Vector2(float(a[0]) * Level.TILE, float(a[1]) * Level.TILE)


## Problems in a map file (unknown legend tiles, ragged rows, objects on walls).
static func problems(m: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var rows: Array = m.get("rows", [])
	if rows.is_empty():
		out.append("no rows")
		return out
	for r: Variant in rows:
		if str(r).length() != str(rows[0]).length():
			out.append("ragged rows")
			break
	var legend: Dictionary = m.get("legend", {})
	for k: String in legend:
		if not FLOOR_TILES.has(str(legend[k])):
			out.append("unknown floor tile %s" % legend[k])
	for key: String in ["stations", "props", "npcs", "decals", "overhead"]:
		for o: Variant in m.get(key, []):
			var p: Vector2 = at((o as Dictionary)["at"])
			if key in ["stations", "props", "npcs"] and not is_floor(m, Level.to_tile(p)):
				out.append("%s %s is not on the floor" % [key, (o as Dictionary).get("sprite", "")])
			var spr: String = str((o as Dictionary).get("sprite", ""))
			if spr != "" and not SpriteManifest.has_sprite(spr):
				out.append("%s: unknown sprite %s" % [key, spr])
	if not is_floor(m, Vector2i(int(m["spawn"][0]), int(m["spawn"][1]))):
		out.append("spawn is not on the floor")
	return out


static func is_floor(m: Dictionary, t: Vector2i) -> bool:
	var rows: Array = m.get("rows", [])
	if t.y < 0 or t.y >= rows.size() or t.x < 0 or t.x >= str(rows[t.y]).length():
		return false
	return (m.get("legend", {}) as Dictionary).has(str(rows[t.y])[t.x])


## Floors, walls, navigation, decals, props, NPCs, labels and lights.
## `parent` receives the CanvasModulate (it must not be inside the Level).
static func build(level: Level, m: Dictionary, parent: Node) -> void:
	var rows: Array = m["rows"]
	var legend: Dictionary = m.get("legend", {})
	for y: int in rows.size():
		var row: String = str(rows[y])
		for x: int in row.length():
			var ch: String = row[x]
			if not legend.has(ch):
				continue
			var t: Vector2i = Vector2i(x, y)
			level.floor_tiles[t] = true
			var idx: int = int(FLOOR_TILES.get(str(legend[ch]), Tiles.HUB_FLOOR))
			if idx < 0:
				idx = Tiles.GUILD_WOOD[(x * 7 + y * 13) % 2]
			level.floor_layer.set_cell(t, 0, Tiles.coords(idx))
	_paint_walls(level, bool(m.get("wall_lanterns", false)))
	level.build_nav()
	if m.has("mood"):
		var mood: CanvasModulate = CanvasModulate.new()
		var c: Array = m["mood"]
		mood.color = Color(float(c[0]), float(c[1]), float(c[2]))
		parent.add_child(mood)
	for d: Variant in m.get("decals", []):
		decal(level, str(d["sprite"]), at(d["at"]))
	for r: Variant in m.get("rails", []):
		var a0: Array = (r as Dictionary)["from"]
		var a1: Array = (r as Dictionary)["to"]
		var horiz: bool = int(a0[1]) == int(a1[1])
		if horiz:
			for x: int in range(int(a0[0]), int(a1[0]) + 1):
				rail(level, Vector2i(x, int(a0[1])), true)
		else:
			for y: int in range(int(a0[1]), int(a1[1]) + 1):
				rail(level, Vector2i(int(a0[0]), y), false)
	for p: Variant in m.get("props", []):
		var b: Array = (p as Dictionary).get("box", [10, 6])
		prop(level, str(p["sprite"]), at(p["at"]), Vector2(float(b[0]), float(b[1])))
	for n: Variant in m.get("npcs", []):
		var g: GuildNpc = GuildNpc.new()
		g.sprite_key = str(n["sprite"])
		g.display_name = str(n.get("name", ""))
		g.flip = bool(n.get("flip", false))
		g.bubble = str(n.get("bubble", ""))
		g.lines = PackedStringArray(n.get("lines", []))
		g.position = at(n["at"])
		level.add_entity(g)
	for o: Variant in m.get("overhead", []):   # hangs above actors (chandeliers)
		var s2: AnimatedSprite2D = AnimatedSprite2D.new()
		SpriteLib.apply(s2, str(o["sprite"]))
		s2.position = at(o["at"])
		s2.z_index = 30
		level.add_child(s2)
	for r: Variant in m.get("rooms", []):
		var l: Label = UiTheme.label(str(r["name"]), Color("#ffe2a0"), true)
		l.add_theme_font_override("font", SpriteLib.font())
		l.position = at(r["at"]) - Vector2(str(r["name"]).length() * 3.0, 0)
		l.modulate = Color(1, 1, 1, 0.75)
		level.fx_layer.add_child(l)
	for g: Variant in m.get("lights", []):
		glow(level, at(g["at"]), float(g.get("radius", 24)), Color(str(g.get("color", "#ffc870"))), float(g.get("strength", 0.35)))
	if bool(m.get("wall_lanterns", false)):
		for w: Vector2i in level.wall_layer.get_used_cells():
			if level.wall_layer.get_cell_atlas_coords(w) == Tiles.coords(Tiles.GUILD_WALL_LANTERN):
				glow(level, Level.to_world(w) + Vector2(0, 6), 26.0, Color("#ffc870"), 0.4)


static func _paint_walls(level: Level, lanterns: bool) -> void:
	var walls: Dictionary = {}
	for t: Vector2i in level.floor_tiles:
		for dy: int in [-1, 0, 1]:
			for dx: int in [-1, 0, 1]:
				var n: Vector2i = t + Vector2i(dx, dy)
				if not level.floor_tiles.has(n):
					walls[n] = true
	for w: Vector2i in walls:
		if _outdoor_only(level, w):
			level.wall_layer.set_cell(w, 0, Tiles.coords(Tiles.HEDGE))
			continue
		var face: bool = level.floor_tiles.has(w + Vector2i(0, 1))
		# tall north walls: the cell above a face is the upper storey (windows, banners)
		var upper: bool = not face and walls.has(w + Vector2i(0, 1)) and level.floor_tiles.has(w + Vector2i(0, 2)) and w.y <= 0
		if upper:
			var ui: int = Tiles.GUILD_WALL_WINDOW if w.x % 4 == 1 else (Tiles.GUILD_WALL_BANNER if w.x % 8 == 3 else Tiles.GUILD_WALL)
			level.wall_layer.set_cell(w, 0, Tiles.coords(ui))
			continue
		var idx: int = Tiles.GUILD_WALL_TOP
		if face:
			idx = Tiles.GUILD_WALL
			if w.x % 8 == 5:
				idx = Tiles.GUILD_WALL_BANNER
			elif lanterns and w.x % 6 == 3:
				idx = Tiles.GUILD_WALL_LANTERN
			elif w.y <= 1 and w.x % 5 == 2:
				idx = Tiles.GUILD_WALL_WINDOW   # windows along the outer north wall
			elif w.x % 11 == 7:
				idx = Tiles.GUILD_WALL_MAP
		level.wall_layer.set_cell(w, 0, Tiles.coords(idx))


## A wall cell that only borders grass becomes a hedge instead of a building wall.
static func _outdoor_only(level: Level, w: Vector2i) -> bool:
	var grass: bool = false
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			var n: Vector2i = w + Vector2i(dx, dy)
			if level.floor_tiles.has(n):
				if level.floor_layer.get_cell_atlas_coords(n) != Tiles.coords(Tiles.GRASS):
					return false
				grass = true
	return grass


## Low railing on one cell (solid, see-through): divides an open hall into areas.
static func rail(level: Level, cell: Vector2i, horizontal: bool) -> void:
	var b: StaticBody2D = StaticBody2D.new()
	b.collision_layer = Level.WORLD_MASK
	b.collision_mask = 0
	b.position = Level.to_world(cell)
	var cs: CollisionShape2D = CollisionShape2D.new()
	var sh: RectangleShape2D = RectangleShape2D.new()
	sh.size = Vector2(16, 5) if horizontal else Vector2(5, 16)
	cs.shape = sh
	cs.position = Vector2(0, 3) if horizontal else Vector2.ZERO
	b.add_child(cs)
	var key: String = "guild_rail_h" if horizontal else "guild_rail_v"
	var s: AnimatedSprite2D = AnimatedSprite2D.new()
	SpriteLib.apply(s, key)
	s.position = (Vector2(0, 6) if horizontal else Vector2(0, 8)) - SpriteLib.pivot_from_centre_world(key)
	b.add_child(s)
	level.add_entity(b)


## Floor decal above the tiles, below every actor (rugs, markings).
static func decal(level: Level, key: String, pos: Vector2) -> void:
	var s: Sprite2D = Sprite2D.new()
	SpriteLib.apply(s, key)
	s.position = pos
	level.add_child(s)
	level.move_child(s, level.floor_layer.get_index() + 1)


## Solid furniture standing on its base (HD art stands on its manifest pivot).
static func prop(level: Level, key: String, pos: Vector2, box: Vector2) -> SolidProp:
	var p: SolidProp = SolidProp.create(key, pos, box, Vector2.ZERO)
	var spr: AnimatedSprite2D = p.get_child(1) as AnimatedSprite2D
	if spr != null and SpriteLib.is_hd(key):
		spr.position = Vector2(0, 5) - SpriteLib.pivot_from_centre_world(key)
	(p.get_child(0) as CollisionShape2D).position = Vector2(0, 5 - box.y / 2.0 + 2.0)
	level.add_entity(p)
	return p


static func npc(level: Level, sprite: String, pos: Vector2, name_text: String, flip: bool) -> Node2D:
	var n: Node2D = Node2D.new()
	n.position = pos
	var s: AnimatedSprite2D = AnimatedSprite2D.new()
	SpriteLib.apply(s, sprite)
	s.play(&"idle")
	s.flip_h = flip
	s.position = Vector2(0, Player.FEET_Y) - SpriteLib.pivot_from_centre_world(sprite)
	n.add_child(s)
	var l: Label = UiTheme.label(name_text, Color("#b4fff0"), true)
	l.add_theme_font_override("font", SpriteLib.font())
	l.position = Vector2(-name_text.length() * 3.0, -32)
	l.z_index = 25
	n.add_child(l)
	level.add_entity(n)
	return n


static var _glow_tex: GradientTexture2D = null


## Warm light pool: additive radial glow (soft light is allowed for FX by the style guide).
static func glow(level: Level, pos: Vector2, radius: float, col: Color, strength: float) -> void:
	if _glow_tex == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 64
		_glow_tex.height = 64
	var sp: Sprite2D = Sprite2D.new()
	sp.texture = _glow_tex
	sp.position = pos
	sp.scale = Vector2.ONE * radius * 2.0 / 64.0
	sp.modulate = Color(col, strength)
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sp.material = mat
	sp.z_index = 15
	level.add_child(sp)
