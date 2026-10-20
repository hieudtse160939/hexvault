class_name SaveStore
extends RefCounted
## Versioned, checksummed, crash-safe JSON storage.
##
## File layout (UTF-8, two parts separated by the first newline):
##   {"format":"hexvault-save","version":N,"sha256":"<hex of body>"}
##   <body JSON>
## Writing goes to <path>.tmp, is read back and verified, the previous valid
## file is copied to <path>.bak, then the tmp file replaces <path>.

const FORMAT: String = "hexvault-save"

enum Status { OK, MISSING, RECOVERED_FROM_BACKUP, RESET_CORRUPT, MIGRATED }


## Result of a load. `data` is always a schema-complete Dictionary.
class LoadResult:
	extends RefCounted
	var data: Dictionary = {}
	var status: int = Status.OK
	var from_version: int = 0
	var fixes: PackedStringArray = []
	var message: String = ""


static func encode(data: Dictionary, version: int) -> String:
	var body: String = JSON.stringify(data, "", true)
	var header: Dictionary = {"format": FORMAT, "version": version, "sha256": body.sha256_text()}
	return JSON.stringify(header) + "\n" + body


## Parses file text. Returns {} plus `out_err` on any structural/checksum problem.
static func decode(text: String, out: Dictionary) -> Dictionary:
	var nl: int = text.find("\n")
	if nl < 0:
		out["error"] = "no header"
		return {}
	var header_v: Variant = JSON.parse_string(text.substr(0, nl))
	if not header_v is Dictionary:
		out["error"] = "bad header"
		return {}
	var header: Dictionary = header_v
	if str(header.get("format", "")) != FORMAT:
		out["error"] = "wrong format"
		return {}
	var body: String = text.substr(nl + 1)
	if body.sha256_text() != str(header.get("sha256", "")):
		out["error"] = "checksum mismatch"
		return {}
	var data_v: Variant = JSON.parse_string(body)
	if not data_v is Dictionary:
		out["error"] = "body is not an object"
		return {}
	out["version"] = int(header.get("version", 0))
	return data_v


static func write_atomic(path: String, data: Dictionary, version: int) -> Error:
	var text: String = encode(data, version)
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.flush()
	f.close()
	# Verify what actually hit the disk before touching the real file.
	var check: Dictionary = {}
	decode(FileAccess.get_file_as_string(tmp), check)
	if check.has("error"):
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CORRUPT
	# Back up the current file only if it is itself valid.
	if FileAccess.file_exists(path):
		var cur: Dictionary = {}
		decode(FileAccess.get_file_as_string(path), cur)
		if not cur.has("error"):
			var cerr: Error = DirAccess.copy_absolute(path, path + ".bak")
			if cerr != OK:
				push_warning("SaveStore: backup failed (%s)" % error_string(cerr))
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path)


## Loads, recovers, migrates and schema-validates.
## `migrations`: { from_version:int -> Callable(Dictionary) -> Dictionary }.
static func load_validated(path: String, defaults: Dictionary, version: int,
		migrations: Dictionary = {}) -> LoadResult:
	var r: LoadResult = LoadResult.new()
	var raw: Dictionary = {}
	var meta: Dictionary = {}
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		r.status = Status.MISSING
		r.data = defaults.duplicate(true)
		r.message = "no save yet"
		return r
	if FileAccess.file_exists(path):
		raw = decode(FileAccess.get_file_as_string(path), meta)
	if meta.has("error") or not FileAccess.file_exists(path):
		var why: String = str(meta.get("error", "main file missing"))
		var bmeta: Dictionary = {}
		var braw: Dictionary = {}
		if FileAccess.file_exists(path + ".bak"):
			braw = decode(FileAccess.get_file_as_string(path + ".bak"), bmeta)
		if FileAccess.file_exists(path):
			# Keep the broken file for diagnosis instead of destroying it.
			DirAccess.copy_absolute(path, path + ".corrupt")
		if FileAccess.file_exists(path + ".bak") and not bmeta.has("error"):
			raw = braw
			meta = bmeta
			r.status = Status.RECOVERED_FROM_BACKUP
			r.message = "save damaged (%s); restored backup" % why
		else:
			r.status = Status.RESET_CORRUPT
			r.data = defaults.duplicate(true)
			r.message = "save damaged (%s) and no valid backup; starting fresh" % why
			return r
	var v: int = int(meta.get("version", 0))
	r.from_version = v
	if v > version:
		r.message = "save from a newer game version (%d > %d); loading known fields" % [v, version]
	while v < version:
		if migrations.has(v):
			var m: Callable = migrations[v]
			raw = m.call(raw)
			r.fixes.append("migrated v%d -> v%d" % [v, v + 1])
		v += 1
	if r.from_version < version and r.status == Status.OK:
		r.status = Status.MIGRATED
	r.data = conform(raw, defaults, "", r.fixes)
	return r


## Returns `data` reshaped to match `defaults`: missing or mistyped keys take the
## default; ints stored as JSON floats are converted back. Unknown keys are kept.
static func conform(data: Dictionary, defaults: Dictionary, prefix: String,
		fixes: PackedStringArray) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	for key: Variant in defaults:
		var dv: Variant = defaults[key]
		var name: String = prefix + str(key)
		if not out.has(key):
			out[key] = _copy(dv)
			fixes.append("added %s" % name)
			continue
		var cv: Variant = out[key]
		match typeof(dv):
			TYPE_INT:
				if typeof(cv) == TYPE_FLOAT:
					out[key] = int(cv)
				elif typeof(cv) != TYPE_INT:
					out[key] = dv
					fixes.append("reset %s" % name)
			TYPE_FLOAT:
				if typeof(cv) == TYPE_INT:
					out[key] = float(cv)
				elif typeof(cv) != TYPE_FLOAT:
					out[key] = dv
					fixes.append("reset %s" % name)
			TYPE_DICTIONARY:
				if typeof(cv) != TYPE_DICTIONARY:
					out[key] = _copy(dv)
					fixes.append("reset %s" % name)
				elif not (dv as Dictionary).is_empty():
					out[key] = conform(cv, dv, name + ".", fixes)
			_:
				if typeof(cv) != typeof(dv):
					out[key] = _copy(dv)
					fixes.append("reset %s" % name)
	return out


static func _copy(v: Variant) -> Variant:
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	if v is Array:
		return (v as Array).duplicate(true)
	return v
