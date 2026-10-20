class_name MissionBoard
extends Modal
## Guild mission board: every mission in data/guild.json with its difficulty,
## level, objectives, rewards, unlock requirement and completion. "Embark"
## launches the real dungeon run for that mission (Game.start_mission).

signal embarked(mission_id: String)

var _sel: String = ""
var _list: VBoxContainer
var _detail: Label
var _go: Button


func _ready() -> void:
	add_title("MISSION BOARD")
	add_text("Guild rank: %s  -  %d missions completed" % [Profile.guild_rank(), Profile.missions_completed_total()], UiTheme.DIM, 300)
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	box.add_child(body)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(130, 0)
	body.add_child(_list)
	var right: VBoxContainer = VBoxContainer.new()
	body.add_child(right)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(200, 140)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_detail = ItemUi.small_label("", UiTheme.TEXT, 192)
	scroll.add_child(_detail)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_go = UiTheme.button("Embark", _on_go)
	row.add_child(_go)
	row.add_child(UiTheme.button("Close", queue_free))
	for id: String in Db.mission_order:
		if _sel == "" and Profile.mission_unlocked(id) and not Profile.mission_completed(id):
			_sel = id
	if _sel == "" and not Db.mission_order.is_empty():
		_sel = Db.mission_order[0]
	refresh()
	super._ready()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


func refresh() -> void:
	for ch: Node in _list.get_children():
		ch.queue_free()
	for id: String in Db.mission_order:
		var m: Dictionary = Db.mission(id)
		var unlocked: bool = Profile.mission_unlocked(id)
		var mark: String = "[done] " if Profile.mission_completed(id) else ("" if unlocked else "[locked] ")
		var b: Button = UiTheme.button(mark + str(m.get("name", id)), func() -> void:
			_sel = id
			refresh())
		if not unlocked:
			b.add_theme_color_override("font_color", UiTheme.DIM)
		if id == _sel:
			b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.DUSK, UiTheme.GOLD))
		_list.add_child(b)
	var m2: Dictionary = Db.mission(_sel)
	if m2.is_empty():
		_detail.text = "No missions posted."
		_go.disabled = true
		return
	var rw: Dictionary = m2.get("rewards", {})
	var rec: Dictionary = Profile.mission_record(_sel) if (Profile.data["missions"] as Dictionary).has(_sel) else {}
	var lines: PackedStringArray = [
		str(m2.get("name", "")).to_upper(),
		str(m2.get("description", "")),
		"",
		"Difficulty: %s     Recommended level: %d" % [m2.get("difficulty", "?"), int(m2.get("recommended_level", 1))],
		"Floors: %d" % int(m2.get("floors", 1)),
		"Objectives:",
	]
	for o: Variant in m2.get("objectives", []):
		lines.append("  - " + str(o))
	lines.append("Rewards on success: %d gold, %d exp, %d shards + loot (item level %d+)" % [int(rw.get("gold", 0)), int(rw.get("xp", 0)), int(rw.get("shards", 0)), int(m2.get("item_level", 1))])
	var req: String = str((m2.get("unlock", {}) as Dictionary).get("mission", ""))
	if req != "":
		lines.append("Requires: complete %s%s" % [Db.mission(req).get("name", req), "  (done)" if Profile.mission_completed(req) else ""])
	if not rec.is_empty():
		var bt: int = int(rec.get("best_time", 0))
		lines.append("Completed %d time(s) of %d attempt(s)%s" % [int(rec.get("completed", 0)), int(rec.get("attempts", 0)),
			("  -  best %d:%02d" % [bt / 60, bt % 60]) if bt > 0 else ""])
	var lvl: int = Profile.hero_level(Profile.selected_hero())
	if lvl < int(m2.get("recommended_level", 1)):
		lines.append("Your hero is level %d: this will be dangerous." % lvl)
	_detail.text = "\n".join(lines)
	_go.disabled = not Profile.mission_unlocked(_sel)
	_go.text = "Embark" if not _go.disabled else "Locked"


func _on_go() -> void:
	if _go.disabled or not Profile.mission_unlocked(_sel):
		Sfx.play("ui_deny")
		return
	_go.disabled = true   # one launch per press
	Sfx.play("portal")
	embarked.emit(_sel)
	get_tree().paused = false
	Profile.save()
	Game.start_mission(_sel)
