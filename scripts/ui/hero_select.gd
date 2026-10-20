class_name HeroSelect
extends Modal
## Hero Shrine: browse, inspect, unlock and pick heroes.
##
## Built for large rosters: a paged grid (PAGE_SIZE per page) filtered by
## archetype and a search string, with several sort orders. The detail pane
## shows everything a player needs to choose: class, difficulty, stats, the
## active skill, the passive, mastery progress and how to unlock.

signal selected(id: String)

const COLS: int = 5
const ROWS: int = 3
const PAGE_SIZE: int = COLS * ROWS
const SORTS: PackedStringArray = ["Default", "Name", "Class", "Difficulty", "Unlocked"]
const DIFFICULTY: PackedStringArray = ["", "Easy", "Normal", "Hard"]

var _current: String = ""
var _page: int = 0
var _sort: int = 0
var _archetype: String = ""          # "" = all
var _query: String = ""
var _ids: PackedStringArray = []     # filtered + sorted

var _grid: GridContainer
var _page_label: Label
var _count_label: Label
var _filter_btn: Button
var _sort_btn: Button
var _search: LineEdit
var _preview: AnimatedSprite2D
var _name: Label
var _class: Label
var _stats: Label
var _skill: Label
var _passive: Label
var _mastery: Label
var _action: Button


func _ready() -> void:
	add_title("HERO SHRINE")
	_count_label = UiTheme.label("", UiTheme.DIM)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_count_label)
	# filter / sort / search row
	var bar: HBoxContainer = HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(bar)
	_filter_btn = UiTheme.button("", _cycle_filter)
	bar.add_child(_filter_btn)
	_sort_btn = UiTheme.button("", _cycle_sort)
	bar.add_child(_sort_btn)
	_search = LineEdit.new()
	_search.placeholder_text = "search"
	_search.custom_minimum_size = Vector2(70, 0)
	_search.add_theme_font_override("font", SpriteLib.font())
	_search.add_theme_font_size_override("font_size", 8)
	_search.text_changed.connect(func(t: String) -> void:
		_query = t.strip_edges().to_lower()
		_page = 0
		_refresh_list())
	bar.add_child(_search)
	# body: grid + detail
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	box.add_child(body)
	var left: VBoxContainer = VBoxContainer.new()
	body.add_child(left)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	left.add_child(_grid)
	var pager: HBoxContainer = HBoxContainer.new()
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(pager)
	pager.add_child(UiTheme.button("<", func() -> void: _turn(-1)))
	_page_label = UiTheme.label("", UiTheme.DIM)
	pager.add_child(_page_label)
	pager.add_child(UiTheme.button(">", func() -> void: _turn(1)))
	body.add_child(_build_detail())
	# actions
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_action = UiTheme.button("", _on_action)
	row.add_child(_action)
	row.add_child(UiTheme.button("Close", queue_free))
	_current = str(Profile.data["selected_character"])
	_refresh_list()
	_show(_current)
	super._ready()


func _build_detail() -> Control:
	var v: VBoxContainer = VBoxContainer.new()
	v.custom_minimum_size = Vector2(196, 0)
	v.add_theme_constant_override("separation", 2)
	var head: HBoxContainer = HBoxContainer.new()
	v.add_child(head)
	var holder: Control = Control.new()
	holder.custom_minimum_size = Vector2(36, 44)
	holder.clip_contents = true
	head.add_child(holder)
	_preview = AnimatedSprite2D.new()
	_preview.position = Vector2(18, 20)
	holder.add_child(_preview)
	var names: VBoxContainer = VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(names)
	_name = UiTheme.label("", UiTheme.GOLD)
	names.add_child(_name)
	_class = UiTheme.label("", UiTheme.ACCENT)
	names.add_child(_class)
	# long text scrolls inside a fixed-height pane so actions stay on screen
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(196, 104)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var text: VBoxContainer = VBoxContainer.new()
	text.add_theme_constant_override("separation", 3)
	scroll.add_child(text)
	for l: String in ["_stats", "_skill", "_passive", "_mastery"]:
		var lab: Label = UiTheme.label("", UiTheme.TEXT)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(186, 0)
		set(l, lab)
		text.add_child(lab)
	_skill.add_theme_color_override("font_color", Color("#b4fff0"))
	_passive.add_theme_color_override("font_color", Color("#ffe28a"))
	_mastery.add_theme_color_override("font_color", UiTheme.DIM)
	return v


# --- list -----------------------------------------------------------------------
func _matches(c: CharacterData) -> bool:
	var cl: ClassData = Db.classes.get(c.class_id, null)
	if _archetype != "" and (cl == null or cl.archetype != _archetype):
		return false
	if _query == "":
		return true
	var hay: String = ("%s %s %s %s" % [c.display_name, c.title, c.id, cl.display_name if cl != null else ""]).to_lower()
	return hay.contains(_query)


func _refresh_list() -> void:
	var ids: Array[String] = []
	for id: String in Db.character_order:
		if _matches(Db.character(id)):
			ids.append(id)
	var order: Dictionary = {}
	for i: int in Db.character_order.size():
		order[Db.character_order[i]] = i
	match SORTS[_sort]:
		"Name":
			ids.sort_custom(func(a: String, b: String) -> bool: return Db.character(a).display_name < Db.character(b).display_name)
		"Class":
			ids.sort_custom(func(a: String, b: String) -> bool:
				var ka: String = Db.character(a).class_id + Db.character(a).display_name
				var kb: String = Db.character(b).class_id + Db.character(b).display_name
				return ka < kb)
		"Difficulty":
			ids.sort_custom(func(a: String, b: String) -> bool:
				var da: int = Db.character(a).difficulty
				var db: int = Db.character(b).difficulty
				return da < db or (da == db and int(order[a]) < int(order[b])))
		"Unlocked":
			ids.sort_custom(func(a: String, b: String) -> bool:
				var ua: bool = Profile.is_character_unlocked(a)
				var ub: bool = Profile.is_character_unlocked(b)
				return (ua and not ub) or (ua == ub and int(order[a]) < int(order[b])))
	_ids = PackedStringArray(ids)
	var pages: int = maxi(1, ceili(_ids.size() / float(PAGE_SIZE)))
	_page = clampi(_page, 0, pages - 1)
	_page_label.text = "%d/%d" % [_page + 1, pages]
	var unlocked: int = 0
	for id: String in Db.character_order:
		if Profile.is_character_unlocked(id):
			unlocked += 1
	_count_label.text = "%d heroes  -  %d unlocked  -  showing %d" % [Db.character_order.size(), unlocked, _ids.size()]
	_filter_btn.text = "Type: %s" % (_archetype.capitalize() if _archetype != "" else "All")
	_sort_btn.text = "Sort: %s" % SORTS[_sort]
	_rebuild_grid()


func _rebuild_grid() -> void:
	for c: Node in _grid.get_children():
		c.queue_free()
	for i: int in PAGE_SIZE:
		var idx: int = _page * PAGE_SIZE + i
		if idx >= _ids.size():
			var spacer: Control = Control.new()
			spacer.custom_minimum_size = Vector2(30, 30)
			_grid.add_child(spacer)
			continue
		var id: String = _ids[idx]
		var c: CharacterData = Db.character(id)
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(30, 30)
		b.focus_mode = Control.FOCUS_ALL
		b.tooltip_text = c.display_name
		var icon: TextureRect = TextureRect.new()
		SpriteLib.fit_icon(icon, c.sprite)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# show the upper body: hero frames are taller than the cell
		icon.position = Vector2(15, 15) - icon.size / 2.0 + Vector2(0, 2)
		b.add_child(icon)
		b.clip_contents = true
		if not Profile.is_character_unlocked(id):
			icon.modulate = Color(0.12, 0.1, 0.18)
		if id == str(Profile.data["selected_character"]):
			b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.DUSK, UiTheme.GOLD))
		b.pressed.connect(func() -> void:
			Sfx.play("ui_click")
			_show(id))
		b.focus_entered.connect(func() -> void: _show(id))
		_grid.add_child(b)


func _turn(d: int) -> void:
	var pages: int = maxi(1, ceili(_ids.size() / float(PAGE_SIZE)))
	_page = posmod(_page + d, pages)
	Sfx.play("ui_move")
	_refresh_list()


func _cycle_filter() -> void:
	var types: PackedStringArray = [""]
	for cid: String in Db.class_order:
		var a: String = (Db.classes[cid] as ClassData).archetype
		if a not in types:
			types.append(a)
	_archetype = types[(types.find(_archetype) + 1) % types.size()]
	_page = 0
	Sfx.play("ui_move")
	_refresh_list()


func _cycle_sort() -> void:
	_sort = (_sort + 1) % SORTS.size()
	Sfx.play("ui_move")
	_refresh_list()


# --- detail ---------------------------------------------------------------------
static func _bar(value: float, max_value: float, width: int = 10) -> String:
	var n: int = clampi(int(round(value / max_value * width)), 0, width)
	return "#".repeat(n) + "-".repeat(width - n)


func _show(id: String) -> void:
	var c: CharacterData = Db.character(id)
	if c == null:
		return
	_current = id
	SpriteLib.apply(_preview, c.sprite, 1.25 if SpriteLib.is_hd(c.sprite) else 2.0)
	_preview.play(&"idle")
	var unlocked: bool = Profile.is_character_unlocked(id)
	_preview.modulate = Color.WHITE if unlocked else Color(0.15, 0.12, 0.2)
	var cl: ClassData = Db.classes.get(c.class_id, null)
	_name.text = "%s - %s" % [c.display_name, c.title]
	_class.text = "%s (%s)  -  %s" % [cl.display_name if cl != null else "?", cl.archetype if cl != null else "?", DIFFICULTY[c.difficulty]]
	_class.add_theme_color_override("font_color", cl.color if cl != null else UiTheme.ACCENT)
	var w: WeaponData = Db.weapon(c.start_weapon)
	var extra: PackedStringArray = []
	for k: String in c.stats:
		extra.append("%s %+d%%" % [k.replace("_mult", "").replace("_", " "), int(round(float(c.stats[k]) * 100.0))])
	_stats.text = "HP    %s %d\nArmor %s %d\nSpeed %s %d\nWeapon: %s%s" % [
		_bar(c.max_hp, 10), c.max_hp, _bar(c.max_armor, 8), c.max_armor, _bar(c.speed - 70.0, 40.0), int(c.speed),
		w.display_name if w != null else "?", ("\n" + ", ".join(extra)) if not extra.is_empty() else ""]
	_skill.text = "SKILL  %s  (%ds)\n%s" % [c.skill_name(), int(c.skill_cooldown), str(c.skill_def.get("description", ""))]
	_passive.text = "PASSIVE  %s\n%s" % [c.passive_name(), str(c.passive_def.get("description", ""))]
	var lvl: int = Profile.mastery_level(id)
	var nxt: int = Profile.mastery_next_xp(id)
	var rec: Dictionary = Profile.character_record(id)
	var next_text: String = ""
	for m: Variant in c.mastery:
		if m is Dictionary and int((m as Dictionary).get("level", 0)) == lvl + 1:
			next_text = " next: %s" % str((m as Dictionary).get("text", ""))
	_mastery.text = "Mastery %d  %s%s\n%s" % [lvl, ("%d/%d xp" % [int(rec.get("xp", 0)), nxt]) if nxt > 0 else "MAX",
		next_text, c.description]
	if unlocked:
		_action.text = "Selected" if str(Profile.data["selected_character"]) == id else "Select"
		_action.disabled = false
	else:
		match str(c.unlock.get("type", "")):
			"shards":
				var cost: int = int(c.unlock.get("cost", 0))
				_action.text = "Unlock (%d shards)" % cost
				_action.disabled = Profile.shards() < cost
			"achievement":
				var a: Dictionary = Db.achievements.get(str(c.unlock.get("id", "")), {})
				_action.text = "Locked: %s" % a.get("name", "?")
				_action.disabled = true
			_:
				_action.text = "Locked"
				_action.disabled = true


func _on_action() -> void:
	if Profile.is_character_unlocked(_current):
		selected.emit(_current)
		Sfx.play("boon")
		_refresh_list()
		_show(_current)
	elif Profile.buy_character(_current):
		Sfx.play("buy")
		_refresh_list()
		_show(_current)
	else:
		Sfx.play("ui_deny")
