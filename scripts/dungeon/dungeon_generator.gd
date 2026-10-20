class_name DungeonGenerator
extends RefCounted
## Constrained, seeded floor generation with validation and a guaranteed fallback.
##
## 1. Randomised DFS lays a simple main path (start -> ... -> boss/exit).
## 2. Special rooms branch off main-path rooms into free neighbouring cells,
##    optionally behind one extra combat room.
## 3. Some main-path combat rooms are promoted to elite rooms.
## 4. Every candidate is validated; failures retry with a derived seed, and after
##    MAX_ATTEMPTS a deterministic linear layout is returned.
## Same (seed, floor, config, templates) -> identical layout.

const MAX_ATTEMPTS: int = 24
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const TERMINAL_TYPES: PackedStringArray = ["boss", "exit"]


## Per-floor generation parameters. Floors beyond the table reuse the last row.
static func floor_config(floor_index: int, total_floors: int = 3) -> Dictionary:
	var boss: bool = floor_index >= total_floors
	match floor_index:
		1:
			return {"main_length": 6, "specials": ["treasure", "shop"], "guarded": 1,
				"elites": 1, "terminal": "boss" if boss else "exit", "grid": Vector2i(7, 7)}
		2:
			return {"main_length": 7, "specials": ["treasure", "heal", "event", "shop"], "guarded": 2,
				"elites": 2, "terminal": "boss" if boss else "exit", "grid": Vector2i(7, 7)}
	return {"main_length": 6, "specials": ["shop", "heal", "treasure"], "guarded": 1,
		"elites": 1, "terminal": "boss" if boss else "exit", "grid": Vector2i(7, 7)}


static func derive_seed(base_seed: int, floor_index: int, attempt: int) -> int:
	return hash([base_seed, floor_index, attempt, "hexvault"])


## templates: Array of {id, types:[...]} (defaults to Db.room_templates).
static func generate(base_seed: int, floor_index: int, config: Dictionary,
		templates: Array = []) -> DungeonLayout:
	var tpl: Array = templates
	for attempt: int in MAX_ATTEMPTS:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = derive_seed(base_seed, floor_index, attempt)
		var layout: DungeonLayout = _try_build(rng, base_seed, floor_index, config, tpl)
		if layout == null:
			continue
		layout.attempts = attempt + 1
		if validate(layout, config, tpl).is_empty():
			return layout
	var fb: DungeonLayout = fallback(base_seed, floor_index, config, tpl)
	fb.attempts = MAX_ATTEMPTS
	return fb


static func _in_grid(c: Vector2i, size: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


static func _shuffled_dirs(rng: RandomNumberGenerator) -> Array[Vector2i]:
	var d: Array[Vector2i] = DIRS.duplicate()
	for i: int in range(d.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Vector2i = d[i]
		d[i] = d[j]
		d[j] = t
	return d


## Iterative randomised DFS for a simple path of exactly `length` cells.
static func _main_path(rng: RandomNumberGenerator, start: Vector2i, length: int, size: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [start]
	var options: Array = [_shuffled_dirs(rng)]
	var budget: int = 4000
	while path.size() < length and budget > 0:
		budget -= 1
		if path.is_empty():
			break
		var opts: Array = options[options.size() - 1]
		if opts.is_empty():
			path.pop_back()
			options.pop_back()
			continue
		var d: Vector2i = opts.pop_back()
		var nxt: Vector2i = path[path.size() - 1] + d
		if not _in_grid(nxt, size) or nxt in path:
			continue
		# Keep the main path from touching itself sideways: only the previous
		# cell may be adjacent. This leaves room for branches and keeps it readable.
		var touches: int = 0
		for dd: Vector2i in DIRS:
			if (nxt + dd) in path:
				touches += 1
		if touches > 1:
			continue
		path.append(nxt)
		options.append(_shuffled_dirs(rng))
	if path.size() != length:
		var empty: Array[Vector2i] = []
		return empty
	return path


static func _try_build(rng: RandomNumberGenerator, base_seed: int, floor_index: int,
		config: Dictionary, templates: Array) -> DungeonLayout:
	var size: Vector2i = config.get("grid", Vector2i(7, 7))
	var length: int = int(config.get("main_length", 6))
	var start: Vector2i = Vector2i(size.x / 2, size.y / 2)
	var path: Array[Vector2i] = _main_path(rng, start, length, size)
	if path.is_empty():
		return null
	var L: DungeonLayout = DungeonLayout.new()
	L.seed_value = base_seed
	L.floor_index = floor_index
	L.grid_size = size
	var prev: int = -1
	for i: int in path.size():
		var type: String = "combat"
		if i == 0:
			type = "start"
		elif i == path.size() - 1:
			type = str(config.get("terminal", "exit"))
		var id: int = L.add_room(path[i], type)
		if prev >= 0:
			L.connect_rooms(prev, id)
		prev = id
	# Elites: promote main-path combat rooms that are at least 2 steps from start.
	var promotable: Array[int] = []
	for i: int in range(2, path.size() - 1):
		promotable.append(i)
	for k: int in int(config.get("elites", 0)):
		if promotable.is_empty():
			break
		var pick: int = promotable[rng.randi_range(0, promotable.size() - 1)]
		promotable.erase(pick)
		L.rooms[pick]["type"] = "elite"
	# Branches for specials.
	var guarded_left: int = int(config.get("guarded", 0))
	for special: Variant in config.get("specials", []):
		var anchors: Array[int] = []
		for r: Dictionary in L.rooms:
			if not str(r["type"]) in TERMINAL_TYPES and str(r["type"]) in ["start", "combat", "elite"]:
				anchors.append(int(r["id"]))
		var placed: bool = false
		var tries: int = 0
		while not placed and tries < 30 and not anchors.is_empty():
			tries += 1
			var anchor: int = anchors[rng.randi_range(0, anchors.size() - 1)]
			var ac: Vector2i = L.rooms[anchor]["cell"]
			for d: Vector2i in _shuffled_dirs(rng):
				var c1: Vector2i = ac + d
				if not _in_grid(c1, size) or L.room_at(c1) >= 0:
					continue
				if guarded_left > 0:
					# special sits behind a combat room: anchor -> combat -> special
					var c2: Vector2i = c1 + d
					var alt: Array[Vector2i] = [c2, c1 + Vector2i(d.y, d.x), c1 - Vector2i(d.y, d.x)]
					for c in alt:
						if _in_grid(c, size) and L.room_at(c) < 0 and c != c1:
							var mid: int = L.add_room(c1, "combat")
							L.connect_rooms(anchor, mid)
							var sp: int = L.add_room(c, str(special))
							L.connect_rooms(mid, sp)
							guarded_left -= 1
							placed = true
							break
					if placed:
						break
				else:
					var sp2: int = L.add_room(c1, str(special))
					L.connect_rooms(anchor, sp2)
					placed = true
					break
		if not placed:
			return null
	_assign_templates(L, rng, templates)
	var dist: PackedInt32Array = L.distances(0)
	for r: Dictionary in L.rooms:
		r["depth"] = dist[int(r["id"])]
	return L


static func _assign_templates(L: DungeonLayout, rng: RandomNumberGenerator, templates: Array) -> void:
	for r: Dictionary in L.rooms:
		var options: Array = []
		for t: Variant in templates:
			if t is Dictionary and str(r["type"]) in (t as Dictionary).get("types", []):
				options.append(str((t as Dictionary)["id"]))
		r["template_id"] = options[rng.randi_range(0, options.size() - 1)] if not options.is_empty() else ""


## Returns a list of problems (empty = valid).
static func validate(L: DungeonLayout, config: Dictionary, templates: Array) -> PackedStringArray:
	var errs: PackedStringArray = []
	if L.rooms.is_empty():
		errs.append("no rooms")
		return errs
	var seen: Dictionary = {}
	for r: Dictionary in L.rooms:
		var c: Vector2i = r["cell"]
		if not _in_grid(c, L.grid_size):
			errs.append("room %d outside grid" % r["id"])
		if seen.has(c):
			errs.append("two rooms share cell %s" % c)
		seen[c] = true
		if str(r["template_id"]).is_empty():
			errs.append("room %d (%s) has no template" % [r["id"], r["type"]])
	for e: Vector2i in L.edges:
		if L.dir_between(e.x, e.y) == Vector2i.ZERO:
			errs.append("edge %s joins non-adjacent rooms" % e)
	var starts: Array[Dictionary] = L.rooms_of_type("start")
	if starts.size() != 1:
		errs.append("expected exactly one start room, got %d" % starts.size())
		return errs
	var terminal: String = str(config.get("terminal", "exit"))
	var terms: Array[Dictionary] = L.rooms_of_type(terminal)
	if terms.size() != 1:
		errs.append("expected exactly one %s room, got %d" % [terminal, terms.size()])
		return errs
	var dist: PackedInt32Array = L.distances(int(starts[0]["id"]))
	for i: int in dist.size():
		if dist[i] < 0:
			errs.append("room %d (%s) unreachable" % [i, L.rooms[i]["type"]])
	var tid: int = int(terms[0]["id"])
	if L.neighbors(tid).size() != 1:
		errs.append("%s room must be a dead end" % terminal)
	if dist[tid] < 3:
		errs.append("%s room too close to start" % terminal)
	for sp: Variant in config.get("specials", []):
		if L.rooms_of_type(str(sp)).is_empty():
			errs.append("missing special room %s" % sp)
	var known: Dictionary = {}
	for t: Variant in templates:
		if t is Dictionary:
			known[str((t as Dictionary)["id"])] = (t as Dictionary).get("types", [])
	for r: Dictionary in L.rooms:
		var tid2: String = str(r["template_id"])
		if not tid2.is_empty() and (not known.has(tid2) or not str(r["type"]) in known[tid2]):
			errs.append("room %d template %s does not fit type %s" % [r["id"], tid2, r["type"]])
	return errs


## Deterministic, always-valid layout used if every attempt fails.
static func fallback(base_seed: int, floor_index: int, config: Dictionary, templates: Array) -> DungeonLayout:
	var L: DungeonLayout = DungeonLayout.new()
	L.seed_value = base_seed
	L.floor_index = floor_index
	L.grid_size = Vector2i(7, 7)
	L.used_fallback = true
	var y: int = 3
	var prev: int = -1
	var length: int = clampi(int(config.get("main_length", 6)), 4, 7)
	for x: int in length:
		var type: String = "combat"
		if x == 0:
			type = "start"
		elif x == length - 1:
			type = str(config.get("terminal", "exit"))
		elif x == 2 and int(config.get("elites", 0)) > 0:
			type = "elite"
		var id: int = L.add_room(Vector2i(x, y), type)
		if prev >= 0:
			L.connect_rooms(prev, id)
		prev = id
	var specials: Array = config.get("specials", [])
	for i: int in specials.size():
		var col: int = 1 + (i / 2)
		var row: int = y - 1 if i % 2 == 0 else y + 1
		var sp: int = L.add_room(Vector2i(col, row), str(specials[i]))
		L.connect_rooms(L.room_at(Vector2i(col, y)), sp)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = derive_seed(base_seed, floor_index, 9999)
	_assign_templates(L, rng, templates)
	var dist: PackedInt32Array = L.distances(0)
	for r: Dictionary in L.rooms:
		r["depth"] = dist[int(r["id"])]
	return L
