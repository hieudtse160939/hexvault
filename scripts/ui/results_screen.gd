extends Control
## Screen: end-of-run summary (victory or defeat).

var summary: Dictionary = {}


func setup(args: Dictionary) -> void:
	summary = args


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#0b0912")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	var won: bool = bool(summary.get("victory", false))
	var m: Dictionary = Db.mission(str(summary.get("mission", "")))
	var title: Label = UiTheme.label(("MISSION COMPLETE!" if not m.is_empty() else "VICTORY!") if won else "EXPEDITION FAILED", UiTheme.GOLD if won else UiTheme.RED, true)
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	if not m.is_empty():
		v.add_child(_centered(str(m.get("name", "")) + ("  -  first clear!" if bool(summary.get("mission_first_clear", false)) else ""), UiTheme.ACCENT))
	if won:
		v.add_child(_centered("Ossifex is broken. The Guild will hear of this.", UiTheme.TEXT))
	else:
		v.add_child(_centered("You were carried back to the Guild. Items and experience are kept; %d%% of the coins." % roundi(float(Db.guild.get("death_gold_keep", 0.5)) * 100.0), UiTheme.DIM))
	var c: CharacterData = Db.character(str(summary.get("character", "")))
	var secs: int = int(summary.get("time", 0))
	var rec: Dictionary = Profile.character_record(c.id) if c != null else {}
	var lines: Array = [
		["Hero", "%s  Lv %d" % [c.display_name, int(rec.get("level", 1))] if c != null else "?"],
		["Floor reached", "%d / %d" % [int(summary.get("floor", 1)), int(summary.get("total_floors", RunState.TOTAL_FLOORS))]],
		["Enemies / elites", "%d / %d" % [int(summary.get("kills", 0)), int(summary.get("elites", 0))]],
		["Time", "%d:%02d" % [secs / 60, secs % 60]],
		["Experience", "+%d%s" % [int(summary.get("exp", 0)) + int(summary.get("mission_exp", 0)), ("  (+%d levels)" % int(summary.get("levels", 0))) if int(summary.get("levels", 0)) > 0 else ""]],
		["Gold", "+%d  (total %d)" % [int(summary.get("gold_earned", 0)), Profile.gold()]],
		["Shards", "+%d  (total %d)" % [int(summary.get("earned_shards", 0)), Profile.shards()]],
	]
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	for l: Array in lines:
		grid.add_child(UiTheme.label(str(l[0]), UiTheme.DIM))
		grid.add_child(UiTheme.label(str(l[1]), UiTheme.GOLD if str(l[0]) == "Gold" else UiTheme.TEXT))
	var center: CenterContainer = CenterContainer.new()
	center.add_child(grid)
	v.add_child(center)
	var loot: Array = summary.get("loot", [])
	v.add_child(_centered("Loot found: %d" % loot.size(), UiTheme.TEXT))
	var shown: int = 0
	for inst: Variant in loot:
		if shown >= 5:
			v.add_child(_centered("... and %d more (see the Equipment station)" % (loot.size() - shown), UiTheme.DIM))
			break
		if inst is Dictionary:
			v.add_child(_centered(ItemGen.label(inst), ItemGen.rarity_color(str((inst as Dictionary).get("rarity", "common")))))
			shown += 1
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var hub_btn: Button = UiTheme.button("Return to the Guild", Game.return_to_guild)
	row.add_child(hub_btn)
	if not m.is_empty():
		row.add_child(UiTheme.button("Retry mission", func() -> void: Game.start_mission(str(summary.get("mission", "")))))
	Sfx.play_music("hub")
	if won:
		Sfx.play("victory")
	hub_btn.grab_focus.call_deferred()


func _centered(text: String, c: Color) -> Label:
	var l: Label = UiTheme.label(text, c)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
