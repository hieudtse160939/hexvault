class_name Minimap
extends Control
## Room-graph minimap (top-right). Press M / Back to expand. In debug mode
## (Game.debug_show_full_map) it reveals the full layout with types and seed,
## acting as the dungeon-generation debug visualisation.

const COLORS: Dictionary = {
	"start": Color("#7dc94a"), "combat": Color("#6b6b8f"), "elite": Color("#f2b23a"),
	"treasure": Color("#ffe28a"), "shop": Color("#4fe0d0"), "heal": Color("#e8455a"),
	"event": Color("#a965ef"), "exit": Color("#6fb0ff"), "boss": Color("#ff3355"),
}
const ICON: Dictionary = {"treasure": "$", "shop": "S", "heal": "+", "event": "?", "exit": ">", "boss": "!", "elite": "*"}

var level: Level
var expanded: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout()
	Events.room_entered.connect(func(_r: Node) -> void: queue_redraw())
	Events.room_cleared.connect(func(_r: Node, _f: bool) -> void: queue_redraw())
	get_viewport().size_changed.connect(_layout)


func toggle_expanded() -> void:
	expanded = not expanded
	_layout()


func _layout() -> void:
	if expanded:
		set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		custom_minimum_size = Vector2(220, 180)
		size = custom_minimum_size
		position = (get_parent_area_size() - size) / 2.0
	else:
		custom_minimum_size = Vector2.ZERO
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		size = Vector2(84, 70)
		position = Vector2(get_parent_area_size().x - size.x - 4, 4)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if level == null or level.layout == null:
		return
	var L: DungeonLayout = level.layout
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.08, 0.75 if expanded else 0.55))
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.STONE, false, 1.0)
	var debug: bool = Game.debug_show_full_map
	# Fit the bounding box of known rooms.
	var mn: Vector2i = Vector2i(999, 999)
	var mx: Vector2i = Vector2i(-999, -999)
	for r: Dictionary in L.rooms:
		var c: Vector2i = r["cell"]
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	var span: Vector2 = Vector2(mx - mn + Vector2i.ONE)
	var cell: float = floorf(minf((size.x - 8) / span.x, (size.y - 14) / span.y))
	var origin: Vector2 = ((size - Vector2(0, 10)) - span * cell) / 2.0
	var visible_ids: Dictionary = {}
	for room: Room in level.rooms:
		if debug or room.visited:
			visible_ids[room.room_id] = true
			for n: int in L.neighbors(room.room_id):
				visible_ids[n] = visible_ids.get(n, false) # discovered but not visited
	var font: Font = SpriteLib.font()
	for e: Vector2i in L.edges:
		if not (visible_ids.has(e.x) and visible_ids.has(e.y)):
			continue
		var a: Vector2 = origin + (Vector2(L.rooms[e.x]["cell"] - mn) + Vector2(0.5, 0.5)) * cell
		var b: Vector2 = origin + (Vector2(L.rooms[e.y]["cell"] - mn) + Vector2(0.5, 0.5)) * cell
		draw_line(a.round(), b.round(), UiTheme.DIM, 1.0)
	for room: Room in level.rooms:
		if not visible_ids.has(room.room_id):
			continue
		var r2: Dictionary = L.rooms[room.room_id]
		var p: Vector2 = origin + Vector2(Vector2i(r2["cell"]) - mn) * cell
		var inset: float = maxf(cell * 0.18, 1.0)
		var rect: Rect2 = Rect2((p + Vector2(inset, inset)).round(), Vector2(cell - inset * 2, cell - inset * 2).round())
		var col: Color = COLORS.get(room.room_type, UiTheme.STONE)
		var known: bool = bool(visible_ids[room.room_id]) or debug
		if not known:
			col = Color(col, 0.35)
		elif not room.cleared and room.is_combat():
			col = col.darkened(0.25)
		draw_rect(rect, col)
		if level.active_room == room:
			draw_rect(rect.grow(1), UiTheme.TEXT, false, 1.0)
		if (known or debug) and ICON.has(room.room_type) and cell >= 9:
			draw_string(font, rect.position + Vector2(rect.size.x / 2 - 2, rect.size.y / 2 + 4), str(ICON[room.room_type]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.INK)
	var label: String = "F%d" % L.floor_index
	if debug:
		label += " seed %d%s" % [L.seed_value, " FB" if L.used_fallback else ""]
	draw_string(font, Vector2(3, size.y - 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.DIM)
