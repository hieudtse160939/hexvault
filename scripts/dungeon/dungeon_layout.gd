class_name DungeonLayout
extends RefCounted
## Abstract floor graph: rooms on a coarse grid plus door connections.

var seed_value: int = 0
var floor_index: int = 1
var grid_size: Vector2i = Vector2i(7, 7)
var rooms: Array[Dictionary] = [] # {id, cell: Vector2i, type, template_id, depth}
var edges: Array[Vector2i] = []   # pairs of room ids, x < y
var attempts: int = 1
var used_fallback: bool = false


func add_room(cell: Vector2i, type: String) -> int:
	var id: int = rooms.size()
	rooms.append({"id": id, "cell": cell, "type": type, "template_id": "", "depth": 0})
	return id


func connect_rooms(a: int, b: int) -> void:
	var e: Vector2i = Vector2i(mini(a, b), maxi(a, b))
	if not e in edges:
		edges.append(e)


func room_at(cell: Vector2i) -> int:
	for r: Dictionary in rooms:
		if r["cell"] == cell:
			return int(r["id"])
	return -1


func neighbors(id: int) -> PackedInt32Array:
	var out: PackedInt32Array = []
	for e: Vector2i in edges:
		if e.x == id:
			out.append(e.y)
		elif e.y == id:
			out.append(e.x)
	return out


func rooms_of_type(type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in rooms:
		if r["type"] == type:
			out.append(r)
	return out


func first_of_type(type: String) -> int:
	for r: Dictionary in rooms:
		if r["type"] == type:
			return int(r["id"])
	return -1


## BFS distances from `from_id` (-1 = unreachable).
func distances(from_id: int) -> PackedInt32Array:
	var dist: PackedInt32Array = []
	dist.resize(rooms.size())
	dist.fill(-1)
	if from_id < 0 or from_id >= rooms.size():
		return dist
	dist[from_id] = 0
	var queue: Array[int] = [from_id]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for n: int in neighbors(cur):
			if dist[n] == -1:
				dist[n] = dist[cur] + 1
				queue.append(n)
	return dist


## Direction (unit grid vector) from room a to room b; ZERO if not grid-adjacent.
func dir_between(a: int, b: int) -> Vector2i:
	var d: Vector2i = (rooms[b]["cell"] as Vector2i) - (rooms[a]["cell"] as Vector2i)
	if absi(d.x) + absi(d.y) != 1:
		return Vector2i.ZERO
	return d


func describe() -> String:
	var lines: PackedStringArray = []
	for y: int in grid_size.y:
		var row: String = ""
		for x: int in grid_size.x:
			var id: int = room_at(Vector2i(x, y))
			row += "." if id < 0 else str(rooms[id]["type"]).substr(0, 1).to_upper()
		lines.append(row)
	return "\n".join(lines)
