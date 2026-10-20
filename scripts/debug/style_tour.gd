extends Node
## Visual QA of weapon-aware attacks: in the Guild training ground, each
## weapon attacks a dummy; frames are captured at windup, release and recovery
## with the camera zoomed in. Launch: godot --path . -- --style-tour=<abs dir>

const WEAPONS: Array = [["hex_staff", "pyromancer"], ["cinder_wand", "pyromancer"], ["wisp_lantern", "necromancer"],
	["thornbow", "assassin"], ["ember_blade", "duelist"], ["shadow_fang", "assassin"], ["wardpike", "warden"],
	["sunforge_mace", "warden"], ["rift_pistol", "assassin"]]

var out_dir: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _run() -> void:
	Profile.autosave = false
	Profile.data["seen_tutorial"] = true
	for pair: Array in WEAPONS:
		Profile.new_game(str(pair[1]))
		Game.goto("hub")
		for i: int in 15:
			await get_tree().process_frame
		var g: Node = get_tree().get_first_node_in_group("guild")
		var cam: Camera2D = g.get("camera")
		cam.zoom = Vector2(3, 3)
		Engine.time_scale = 1.0
		var p: Player = g.get("player")
		var dummy: Node2D = (g.get("dummies") as Array)[1]
		p.global_position = dummy.global_position + Vector2(-26, -2)
		var rs: RunState = RunState.new()
		rs.weapons = [str(pair[0])]
		p.load_run_weapons(rs)
		p.input_enabled = false
		cam.call("snap_to_target")
		for i2: int in 8:
			await get_tree().physics_frame
		cam.call("snap_to_target")
		var w: Weapon = p.current_weapon()
		var dir: Vector2 = (dummy.global_position + Vector2(0, -6) - p.global_position).normalized()
		p.set("_aim", dir)
		await _shot("%s_0_hold" % pair[0])
		Engine.time_scale = 0.05   # slow motion: capture each phase even if a screenshot takes 100+ ms
		w.try_fire(dir)
		var marks: Array = [[w._times.x * 0.6, "1_windup"], [w._times.x + w._times.y * 0.5 + 0.02, "2_release"], [w._times.x + w._times.y + w._times.z * 0.4, "3_recover"]]
		var game_t: Array = [0.0]
		for m: Array in marks:
			while game_t[0] < float(m[0]):
				await get_tree().process_frame
				game_t[0] += get_process_delta_time()
			await _shot("%s_%s" % [pair[0], m[1]])
		Engine.time_scale = 1.0
	print("[style-tour] done")
	get_tree().quit()
