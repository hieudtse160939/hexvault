extends Control
## Screen: New Game character selection. Shows the playable roster
## (data/guild.json "roster") with their real sprites, base stats and
## playstyle; confirming starts a fresh profile and enters the Guild.

const CARD: Vector2 = Vector2(76, 70)

var _current: String = ""
var _cards: HBoxContainer
var _name: Label
var _info: Label
var _stats: Label
var _start: Button
var _previews: Dictionary = {}   # id -> AnimatedSprite2D
var _t: float = 0.0
var _modal: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#120d16")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 8
	v.offset_bottom = -8
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	var title: Label = UiTheme.label("CHOOSE YOUR ADVENTURER", UiTheme.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	v.add_child(title)
	var sub: Label = UiTheme.label("Register with the Adventurers' Guild. You can recruit the others later at the Hero Shrine.", UiTheme.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 6)
	v.add_child(_cards)
	for id: String in Db.roster:
		_cards.add_child(_card(id))
	var detail: HBoxContainer = HBoxContainer.new()
	detail.alignment = BoxContainer.ALIGNMENT_CENTER
	detail.add_theme_constant_override("separation", 14)
	v.add_child(detail)
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(220, 0)
	detail.add_child(left)
	_name = UiTheme.label("", UiTheme.GOLD, true)
	left.add_child(_name)
	_info = ItemUi.small_label("", UiTheme.TEXT, 220)
	left.add_child(_info)
	_stats = ItemUi.small_label("", UiTheme.TEXT, 200)
	detail.add_child(_stats)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	_start = UiTheme.button("Begin the adventure", _on_start)
	row.add_child(_start)
	row.add_child(UiTheme.button("Back", func() -> void: Game.goto("title")))
	_show(Db.roster[0] if not Db.roster.is_empty() else "")
	Sfx.play_music("hub")
	_start.grab_focus.call_deferred()


func _card(id: String) -> Control:
	var c: CharacterData = Db.character(id)
	var b: Button = Button.new()
	b.custom_minimum_size = CARD
	b.clip_contents = true
	b.focus_mode = Control.FOCUS_ALL
	var spr: AnimatedSprite2D = AnimatedSprite2D.new()
	SpriteLib.apply(spr, c.sprite, 1.6)
	spr.play(&"idle")
	# stand the hero on the card's floor line using the sprite's feet pivot
	spr.position = Vector2(CARD.x / 2.0, CARD.y - 14.0) - SpriteLib.pivot_from_centre_world(c.sprite) * 1.6
	b.add_child(spr)
	_previews[id] = spr
	var l: Label = UiTheme.label(c.display_name, UiTheme.TEXT, true)
	l.position = Vector2(4, CARD.y - 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	b.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		_show(id))
	b.focus_entered.connect(func() -> void: _show(id))
	b.set_meta("hero", id)
	return b


func _show(id: String) -> void:
	var c: CharacterData = Db.character(id)
	if c == null:
		return
	_current = id
	for b: Node in _cards.get_children():
		var sel: bool = str(b.get_meta("hero", "")) == id
		(b as Button).add_theme_stylebox_override("normal", UiTheme.box(UiTheme.DUSK if sel else UiTheme.NIGHT, UiTheme.GOLD if sel else UiTheme.STONE))
	var cl: ClassData = Db.classes.get(c.class_id, null)
	_name.text = "%s - %s" % [c.display_name, c.title]
	var w: WeaponData = Db.weapon(c.start_weapon)
	_info.text = "%s  -  %s\n%s\n\nSkill: %s - %s\nPassive: %s - %s" % [
		cl.display_name if cl != null else "?", ["", "Easy", "Normal", "Hard"][c.difficulty], c.description,
		c.skill_name(), str(c.skill_def.get("description", "")), c.passive_name(), str(c.passive_def.get("description", ""))]
	var st: Dictionary = HeroStats.compute(c, 1, [], {})
	_stats.text = "Max HP  %d\nShield  %d\nSpeed   %d\nAttack  %d\nDefense %d\nCrit    %s\nWeapon: %s" % [
		int(st["max_hp"]), int(st["max_armor"]), int(c.speed), roundi(float(st["attack"])), roundi(float(st["defense"])),
		HeroStats.show("crit_chance", float(st["crit_chance"])), w.display_name if w != null else "?"]


func _process(delta: float) -> void:
	_t += delta
	for id: String in _previews:
		var s: AnimatedSprite2D = _previews[id]
		var want: StringName = &"run" if id == _current else &"idle"
		if s.animation != want:
			s.play(want)


func _on_start() -> void:
	if _modal != null or _current == "":
		return
	if Profile.has_game():
		var m: Modal = Modal.new()
		m.process_mode = Node.PROCESS_MODE_ALWAYS
		m.add_title("START A NEW GAME?", UiTheme.RED)
		m.add_text("Your current adventurer, items and gold will be replaced. The previous save is copied to profile.previous.save first.", UiTheme.TEXT, 260)
		m.add_button("Yes, start over", func() -> void:
			m.queue_free()
			_begin())
		m.add_button("Cancel", m.queue_free)
		_modal = m
		m.tree_exited.connect(func() -> void: _modal = null)
		add_child(m)
		return
	_begin()


func _begin() -> void:
	Profile.new_game(_current)
	Sfx.play("boon")
	Game.goto("hub", {"arrival": true})
