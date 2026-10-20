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
	var title: Label = UiTheme.label("VICTORY!" if won else "RUN OVER", UiTheme.GOLD if won else UiTheme.RED, true)
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	if won:
		v.add_child(_centered("Ossifex is broken. The Hexvault falls silent... for now.", UiTheme.TEXT))
	var c: CharacterData = Db.character(str(summary.get("character", "ranger")))
	var secs: int = int(summary.get("time", 0))
	var lines: Array = [
		["Hero", "%s the %s" % [c.display_name, c.title] if c != null else "?"],
		["Floor reached", "%d / %d" % [int(summary.get("floor", 1)), RunState.TOTAL_FLOORS]],
		["Enemies defeated", str(summary.get("kills", 0))],
		["Elites defeated", str(summary.get("elites", 0))],
		["Rooms cleared", str(summary.get("rooms", 0))],
		["Time", "%d:%02d" % [secs / 60, secs % 60]],
		["Shards banked", "+%d" % int(summary.get("earned_shards", 0))],
		["Total shards", str(Profile.shards())],
	]
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	for l: Array in lines:
		grid.add_child(UiTheme.label(str(l[0]), UiTheme.DIM))
		grid.add_child(UiTheme.label(str(l[1]), UiTheme.ACCENT if str(l[0]).begins_with("Shards") else UiTheme.TEXT))
	var center: CenterContainer = CenterContainer.new()
	center.add_child(grid)
	v.add_child(center)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var hub_btn: Button = UiTheme.button("Return to Sanctum", func() -> void: Game.goto("hub"))
	row.add_child(hub_btn)
	row.add_child(UiTheme.button("Dive again", func() -> void: Game.start_run(str(summary.get("character", "ranger")))))
	Sfx.play_music("hub")
	if won:
		Sfx.play("victory")
	hub_btn.grab_focus.call_deferred()


func _centered(text: String, c: Color) -> Label:
	var l: Label = UiTheme.label(text, c)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
