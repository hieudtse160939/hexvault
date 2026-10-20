class_name RoomTemplate
extends RefCounted
## Parsed ASCII room interior (see data/rooms.json legend).
## Border walls and doors are added by the builder; doors are 3 tiles wide and
## centred on each side, so interiors must have odd width and height.

const SOLID: String = "#PL"
const BREAKABLE: String = "XB"

var id: String = ""
var types: PackedStringArray = []
var rows: PackedStringArray = []
var width: int = 0
var height: int = 0


static func from_dict(d: Dictionary) -> RoomTemplate:
	var t: RoomTemplate = RoomTemplate.new()
	t.id = str(d.get("id", ""))
	for ty: Variant in d.get("types", []):
		t.types.append(str(ty))
	for r: Variant in d.get("rows", []):
		t.rows.append(str(r))
	t.height = t.rows.size()
	t.width = t.rows[0].length() if t.height > 0 else 0
	return t


func char_at(x: int, y: int) -> String:
	if y < 0 or y >= height or x < 0 or x >= rows[y].length():
		return "#"
	return rows[y][x]


func is_solid(x: int, y: int) -> bool:
	return SOLID.contains(char_at(x, y))


## Walkable without breaking anything.
func is_open(x: int, y: int) -> bool:
	var c: String = char_at(x, y)
	return not SOLID.contains(c) and not BREAKABLE.contains(c)


func cells_with(ch: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in height:
		for x: int in width:
			if rows[y][x] == ch:
				out.append(Vector2i(x, y))
	return out


## Interior cells adjacent to each door (3 wide, centred), keyed by direction.
func door_approach(dir: Vector2i) -> Array[Vector2i]:
	var cx: int = (width - 1) / 2
	var cy: int = (height - 1) / 2
	var out: Array[Vector2i] = []
	for o: int in [-1, 0, 1]:
		match dir:
			Vector2i(0, -1):
				out.append(Vector2i(cx + o, 0))
			Vector2i(0, 1):
				out.append(Vector2i(cx + o, height - 1))
			Vector2i(-1, 0):
				out.append(Vector2i(0, cy + o))
			Vector2i(1, 0):
				out.append(Vector2i(width - 1, cy + o))
	return out


## Returns problems (empty = valid): odd sizes, ragged rows, blocked door
## approaches, and open floor that cannot be reached from the doors.
func validate() -> PackedStringArray:
	var errs: PackedStringArray = []
	if height == 0 or width == 0:
		errs.append("%s: empty" % id)
		return errs
	for r: String in rows:
		if r.length() != width:
			errs.append("%s: ragged rows" % id)
			return errs
	if width % 2 == 0 or height % 2 == 0:
		errs.append("%s: size %dx%d must be odd" % [id, width, height])
	var all_doors: Array[Vector2i] = []
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		for c: Vector2i in door_approach(d):
			if not is_open(c.x, c.y):
				errs.append("%s: door approach %s blocked" % [id, c])
			all_doors.append(c)
	# Flood fill from the first door approach over open cells.
	var seen: Dictionary = {}
	var stack: Array[Vector2i] = [all_doors[0]]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if seen.has(c) or not is_open(c.x, c.y):
			continue
		seen[c] = true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x >= 0 and n.y >= 0 and n.x < width and n.y < height:
				stack.append(n)
	for y: int in height:
		for x: int in width:
			if is_open(x, y) and not seen.has(Vector2i(x, y)):
				errs.append("%s: open cell (%d,%d) unreachable" % [id, x, y])
				return errs
	return errs
