extends "res://tests/test_case.gd"
## Every project script must load and compile (autoloads present).


func _all_scripts(dir: String, out: PackedStringArray) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_all_scripts(dir.path_join(d), out)


func test_every_script_compiles() -> void:
	var files: PackedStringArray = []
	_all_scripts("res://scripts", files)
	assert_gt(files.size(), 40)
	for path: String in files:
		var s: GDScript = load(path) as GDScript
		assert_not_null(s, "%s loads" % path)
		if s != null:
			assert_true(s.can_instantiate(), "%s compiles" % path)
