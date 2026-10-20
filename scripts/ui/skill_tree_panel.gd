class_name SkillTreePanel
extends Modal
## Skill tree (data/skill_trees.json) and the active-skill slot.
## Talents cost one skill point per rank (earned on level-up or from a Tome of
## Insight); skills learned from books can be put in the skill slot here.

const RESET_COST_PER_POINT: int = 10

var hero: String = ""
var _sel: String = ""
var _sp: Label
var _cols: HBoxContainer
var _detail: Label
var _learn: Button
var _skills: VBoxContainer


func _ready() -> void:
	if hero == "":
		hero = Profile.selected_hero()
	var c: CharacterData = Db.character(hero)
	add_title("SKILLS - %s" % (c.display_name if c != null else hero))
	_sp = UiTheme.label("", UiTheme.ACCENT)
	_sp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_sp)
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	box.add_child(body)
	# branches side by side, scrolling both ways so trees can grow to hundreds of nodes
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(270, 150)
	body.add_child(scroll)
	_cols = HBoxContainer.new()
	_cols.add_theme_constant_override("separation", 4)
	scroll.add_child(_cols)
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(150, 0)
	body.add_child(right)
	_detail = ItemUi.small_label("", UiTheme.TEXT, 150)
	right.add_child(_detail)
	_learn = UiTheme.button("Learn", _on_learn)
	right.add_child(_learn)
	right.add_child(UiTheme.label("ACTIVE SKILL (Q / RMB)", UiTheme.GOLD))
	_skills = VBoxContainer.new()
	_skills.add_theme_constant_override("separation", 1)
	right.add_child(_skills)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	row.add_child(UiTheme.button("Reset talents", _on_reset))
	row.add_child(UiTheme.button("Close", queue_free))
	refresh()
	super._ready()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


func _rec() -> Dictionary:
	return Profile.character_record(hero)


func refresh() -> void:
	var rec: Dictionary = _rec()
	_sp.text = "Level %d  -  %d skill point%s" % [int(rec["level"]), int(rec["sp"]), "" if int(rec["sp"]) == 1 else "s"]
	for ch: Node in _cols.get_children():
		ch.queue_free()
	var branches: Dictionary = {}
	var order: PackedStringArray = []
	for n: Variant in HeroProgress.tree_nodes(hero):
		var br: String = str((n as Dictionary).get("branch", ""))
		if not branches.has(br):
			branches[br] = []
			order.append(br)
		(branches[br] as Array).append(n)
	for br2: String in order:
		var col: VBoxContainer = VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		col.add_child(UiTheme.label(br2.to_upper(), UiTheme.GOLD))
		for n2: Variant in branches[br2]:
			var nd: Dictionary = n2
			var id: String = str(nd["id"])
			var r: int = HeroProgress.rank(rec, id)
			var b: Button = UiTheme.button("%s %d/%d" % [nd.get("name", id), r, int(nd.get("max_rank", 1))], func() -> void:
				_sel = id
				refresh())
			b.custom_minimum_size = Vector2(84, 0)
			var block: String = HeroProgress.learn_block(hero, rec, id)
			if r >= int(nd.get("max_rank", 1)):
				b.add_theme_color_override("font_color", UiTheme.GOLD)
			elif r > 0:
				b.add_theme_color_override("font_color", UiTheme.ACCENT)
			elif block != "" and block != "No skill points":
				b.add_theme_color_override("font_color", UiTheme.DIM)
			if not HeroProgress.node_active(nd, HeroStats.equipped_style(Profile.data, hero)):
				b.modulate = Color(1, 1, 1, 0.55)   # weapon talent inactive with the current weapon
			if id == _sel:
				b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.DUSK, UiTheme.TEXT))
			col.add_child(b)
		_cols.add_child(col)
	var node: Dictionary = HeroProgress.tree_node(hero, _sel)
	if node.is_empty():
		_detail.text = "Pick a talent. Each rank costs 1 skill point. Talents deeper in a branch need the one above."
		_learn.visible = false
	else:
		var why: String = HeroProgress.learn_block(hero, rec, _sel)
		var req: Array = node.get("requires_weapon", [])
		var req_text: String = ""
		if not req.is_empty():
			req_text = "\nActive with: %s%s" % [", ".join(PackedStringArray(req)),
				"" if HeroProgress.node_active(node, HeroStats.equipped_style(Profile.data, hero)) else "  (inactive now)"]
		_detail.text = "%s  (rank %d/%d)\n%s%s%s" % [node.get("name", ""), HeroProgress.rank(rec, _sel), int(node.get("max_rank", 1)),
			node.get("description", ""), req_text, ("\n" + why) if why != "" else ""]
		_learn.visible = true
		_learn.disabled = why != ""
	for ch2: Node in _skills.get_children():
		ch2.queue_free()
	var active: String = str(HeroProgress.active_skill_def(hero, rec).get("id", ""))
	for sid: String in HeroProgress.known_skills(hero, rec):
		var sd: Dictionary = Db.skill_def_for(sid)
		var line: HBoxContainer = HBoxContainer.new()
		var icon: TextureRect = TextureRect.new()
		SpriteLib.fit_icon(icon, str(sd.get("icon", "")))
		line.add_child(icon)
		var sb: Button = UiTheme.button(("> " if sid == active else "") + str(sd.get("name", sid)), func() -> void:
			if HeroProgress.set_active_skill(hero, _rec(), sid):
				Sfx.play("boon")
				_after_change()
			refresh())
		sb.tooltip_text = "%s\n%ds cooldown" % [sd.get("description", ""), int(float(sd.get("cooldown", 10)))]
		if sid == active:
			sb.add_theme_color_override("font_color", UiTheme.ACCENT)
		line.add_child(sb)
		_skills.add_child(line)


func _on_learn() -> void:
	if HeroProgress.learn(hero, _rec(), _sel):
		Sfx.play("buy")
		_after_change()
	else:
		Sfx.play("ui_deny")
	refresh()


func _on_reset() -> void:
	var spent: int = 0
	var t: Dictionary = _rec()["tree"]
	for id: String in t:
		spent += int(t[id])
	if spent == 0 or not Profile.spend_gold(spent * RESET_COST_PER_POINT):
		Sfx.play("ui_deny")
		Events.toast.emit("Reset costs %d gold (%d per point)." % [spent * RESET_COST_PER_POINT, RESET_COST_PER_POINT] if spent > 0 else "No talents to reset.")
		return
	HeroProgress.reset_tree(_rec())
	Sfx.play("coin")
	_after_change()
	refresh()


func _after_change() -> void:
	Profile.save()
	var lvl: Level = Level.current
	if lvl != null and lvl.player != null and is_instance_valid(lvl.player) and lvl.player.character.id == hero:
		lvl.player.refresh_equipment()
