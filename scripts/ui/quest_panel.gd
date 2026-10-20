class_name QuestPanel
extends Modal
## Quest lines (claimable tiers) and the achievement list.

var _content: VBoxContainer
var _tab: String = "quests"


func _ready() -> void:
	add_title("QUEST BOARD")
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(tabs)
	tabs.add_child(UiTheme.button("Quests", func() -> void:
		_tab = "quests"
		_rebuild()))
	tabs.add_child(UiTheme.button("Achievements", func() -> void:
		_tab = "achievements"
		_rebuild()))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(290, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	add_button("Close", queue_free)
	_rebuild()
	super._ready()


func _rebuild() -> void:
	for c: Node in _content.get_children():
		c.queue_free()
	if _tab == "quests":
		for id: String in Db.quest_order:
			var st: Dictionary = Profile.quest_status(id)
			var row: HBoxContainer = HBoxContainer.new()
			var v: VBoxContainer = VBoxContainer.new()
			v.custom_minimum_size = Vector2(200, 0)
			v.add_child(UiTheme.label(str(st["name"]), UiTheme.GOLD))
			v.add_child(UiTheme.label("%s  (%d/%d)" % [st["description"], st["progress"], st["goal"]], UiTheme.DIM))
			row.add_child(v)
			var b: Button = Button.new()
			b.focus_mode = Control.FOCUS_ALL
			if bool(st["complete_line"]):
				b.text = "Done"
				b.disabled = true
			else:
				b.text = "Claim %d" % int(st["reward"])
				b.disabled = not bool(st["done"])
			b.pressed.connect(func() -> void:
				if Profile.claim_quest(id):
					Sfx.play("boon")
					_rebuild())
			row.add_child(b)
			_content.add_child(row)
	else:
		var got: int = 0
		for id: String in Db.achievement_order:
			var a: Dictionary = Db.achievements[id]
			var have: bool = Profile.has_achievement(id)
			if have:
				got += 1
			var row2: HBoxContainer = HBoxContainer.new()
			var icon: TextureRect = TextureRect.new()
			icon.texture = SpriteLib.texture("icon_trophy" if have else "icon_lock")
			row2.add_child(icon)
			var v2: VBoxContainer = VBoxContainer.new()
			v2.add_child(UiTheme.label(str(a.get("name", id)), UiTheme.GOLD if have else UiTheme.TEXT))
			var prog: int = mini(Profile.stat(str(a.get("stat", ""))), int(a.get("goal", 1)))
			v2.add_child(UiTheme.label("%s  %s" % [a.get("description", ""), "" if have else "(%d/%d)" % [prog, int(a.get("goal", 1))]], UiTheme.DIM))
			row2.add_child(v2)
			_content.add_child(row2)
		var total: Label = UiTheme.label("%d / %d unlocked" % [got, Db.achievement_order.size()], UiTheme.ACCENT)
		_content.add_child(total)
	focus_first.call_deferred()
