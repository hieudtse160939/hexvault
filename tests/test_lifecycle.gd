extends "res://tests/test_case.gd"
## App lifecycle: focus loss pauses a run, pause/resume, abandon keeps progress.

var _saved: Dictionary
var _auto: bool


func before_each() -> void:
	_auto = Profile.autosave
	_saved = Profile.data.duplicate(true)
	Profile.autosave = false
	Profile.data = SaveManager.profile_defaults()
	Profile.data["seen_tutorial"] = true


func after_each() -> void:
	Profile.data = _saved
	Profile.autosave = _auto
	get_tree().paused = false


func _modals(fl: Node) -> Array:
	var out: Array = []
	var root: Control = fl.get("ui_root")
	for c: Node in root.get_children():
		if c is Modal:
			out.append(c)
	return out


func test_focus_loss_pauses_run_and_resume_works() -> void:
	var main: Node = add_scene("res://scenes/main.tscn")
	await wait_frames(3)
	Game.start_run("ranger", 99)
	await wait_frames(10)
	var fl: Node = get_tree().get_first_node_in_group("dungeon_floor")
	assert_not_null(fl)
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await wait_frames(2)
	assert_true(get_tree().paused, "losing focus pauses the game")
	var pm: Array = _modals(fl)
	assert_eq(pm.size(), 1, "pause menu shown")
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await wait_frames(2)
	assert_eq(_modals(fl).size(), 1, "a second focus loss does not stack menus")
	(pm[0] as PauseMenu)._close()
	await wait_frames(2)
	assert_false(get_tree().paused, "resume unpauses")
	main.queue_free()
	await wait_frames(2)


func test_abandon_run_banks_and_returns_results() -> void:
	var main: Node = add_scene("res://scenes/main.tscn")
	await wait_frames(3)
	Game.start_run("ranger", 5)
	await wait_frames(10)
	Game.run.shards = 7
	Game.abandon_run()
	await wait_frames(5)
	assert_eq(Game.current_screen, "results")
	assert_eq(Profile.shards(), 7, "abandoning still banks collected shards")
	assert_eq(Profile.stat("deaths"), 1)
	main.queue_free()
	await wait_frames(2)
