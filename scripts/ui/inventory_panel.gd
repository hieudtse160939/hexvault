class_name InventoryPanel
extends Modal
## Equipment station / inventory, laid out like the Guild UI reference:
## title plate, the hero between their six equipment slots, final stats, the
## bag grid, an item tooltip with rolls and comparison, and colour-coded
## EQUIP / UNEQUIP / SELL / CLOSE buttons. Everything acts on the real profile
## inventory (Inventory + Profile.data); HeroStats recomputes after each change.

signal changed

const COLS: int = 7
const CELL: float = 20.0
const LEFT_SLOTS: PackedStringArray = ["weapon", "accessory", "gloves"]
const RIGHT_SLOTS: PackedStringArray = ["helmet", "armor", "boots"]

var hero: String = ""
var _sel_uid: String = ""
var _left: VBoxContainer
var _right: VBoxContainer
var _doll: AnimatedSprite2D
var _stats_label: Label
var _stats_label2: Label
var _bag_grid: GridContainer
var _bag_label: Label
var _tip_title: Label
var _tip_sub: Label
var _tip_lines: VBoxContainer
var _tip_panel: PanelContainer
var _btn_equip: Button
var _btn_unequip: Button
var _btn_sell: Button
var _busy: bool = false


func _ready() -> void:
	if hero == "":
		hero = Profile.selected_hero()
	var c: CharacterData = Db.character(hero)
	panel.add_theme_stylebox_override("panel", UiTheme.guild_box(2, 6))
	# header: HEXVAULT plate, INVENTORY, close button
	var head: HBoxContainer = HBoxContainer.new()
	box.add_child(head)
	var lpad: Control = Control.new()
	lpad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(lpad)
	var plate: PanelContainer = PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiTheme.tex_box("ui_plate", 4) if SpriteManifest.has_image("ui_plate") else UiTheme.guild_box())
	head.add_child(plate)
	var t: Label = UiTheme.label("HEXVAULT", Color("#f2d27a"), true)
	t.add_theme_font_size_override("font_size", 16)
	plate.add_child(t)
	var rpad: Control = Control.new()
	rpad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(rpad)
	var x: Button = UiTheme.action_button("X", "red", queue_free)
	x.custom_minimum_size = Vector2(14, 14)
	head.add_child(x)
	var sub: Label = UiTheme.label("INVENTORY  -  %s  Lv %d" % [c.display_name if c != null else hero, Profile.hero_level(hero)], Color("#f2d27a"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	box.add_child(body)
	# hero between the equipment slots + final stats
	var doll_col: VBoxContainer = VBoxContainer.new()
	body.add_child(doll_col)
	var doll_row: HBoxContainer = HBoxContainer.new()
	doll_row.add_theme_constant_override("separation", 2)
	doll_col.add_child(doll_row)
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 2)
	doll_row.add_child(_left)
	var stage: PanelContainer = PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UiTheme.tex_box("ui_slot", 0) if SpriteManifest.has_image("ui_slot") else UiTheme.box(UiTheme.INK, UiTheme.STONE))
	doll_row.add_child(stage)
	var holder: Control = Control.new()
	holder.custom_minimum_size = Vector2(50, 66)
	holder.clip_contents = true
	stage.add_child(holder)
	_doll = AnimatedSprite2D.new()
	if c != null:
		SpriteLib.apply(_doll, c.sprite, 1.6)
		_doll.position = Vector2(25, 60) - SpriteLib.pivot_from_centre_world(c.sprite) * 1.6
		_doll.play(&"idle")
	holder.add_child(_doll)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 2)
	doll_row.add_child(_right)
	var stats_row: HBoxContainer = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 6)
	doll_col.add_child(stats_row)
	_stats_label = ItemUi.small_label("", UiTheme.TEXT)
	stats_row.add_child(_stats_label)
	_stats_label2 = ItemUi.small_label("", UiTheme.TEXT)
	stats_row.add_child(_stats_label2)
	# bag grid
	var mid: VBoxContainer = VBoxContainer.new()
	body.add_child(mid)
	_bag_label = UiTheme.label("", Color("#f2d27a"))
	mid.add_child(_bag_label)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(COLS * (CELL + 1) + 6, 6 * (CELL + 1))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = COLS
	_bag_grid.add_theme_constant_override("h_separation", 1)
	_bag_grid.add_theme_constant_override("v_separation", 1)
	scroll.add_child(_bag_grid)
	# tooltip
	_tip_panel = PanelContainer.new()
	_tip_panel.custom_minimum_size = Vector2(124, 0)
	_tip_panel.add_theme_stylebox_override("panel", UiTheme.tex_box("ui_tooltip", 4) if SpriteManifest.has_image("ui_tooltip") else UiTheme.box(UiTheme.INK, UiTheme.GOLD))
	body.add_child(_tip_panel)
	var tip: VBoxContainer = VBoxContainer.new()
	tip.add_theme_constant_override("separation", 1)
	_tip_panel.add_child(tip)
	_tip_title = ItemUi.small_label("", UiTheme.GOLD, 116)
	tip.add_child(_tip_title)
	_tip_sub = ItemUi.small_label("", UiTheme.DIM, 116)
	tip.add_child(_tip_sub)
	var tscroll: ScrollContainer = ScrollContainer.new()
	tscroll.custom_minimum_size = Vector2(118, 120)
	tscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tip.add_child(tscroll)
	_tip_lines = VBoxContainer.new()
	_tip_lines.add_theme_constant_override("separation", 0)
	tscroll.add_child(_tip_lines)
	# actions
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	_btn_equip = UiTheme.action_button("EQUIP", "green", _on_equip)
	row.add_child(_btn_equip)
	_btn_unequip = UiTheme.action_button("UNEQUIP", "blue", _on_unequip)
	row.add_child(_btn_unequip)
	_btn_sell = UiTheme.action_button("SELL", "gold", _on_sell)
	row.add_child(_btn_sell)
	row.add_child(UiTheme.action_button("CLOSE", "red", queue_free))
	refresh()
	super._ready()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		queue_free()


func _slot_cell(slot: String) -> Button:
	var d: Dictionary = Profile.data
	var inst: Dictionary = Inventory.equipped_in(d, hero, slot)
	var uid: String = str(inst.get("uid", ""))
	var name: String = str((Db.items_cfg.get("slot_names", {}) as Dictionary).get(slot, slot))
	var b: Button = ItemUi.slot_button(inst, 22.0, func() -> void: select(uid) if uid != "" else null, name.substr(0, 3))
	if inst.is_empty() and SpriteManifest.has_image("ui_slot"):
		b.add_theme_stylebox_override("normal", UiTheme.tex_box("ui_slot", 1))
		b.modulate = Color(1, 1, 1, 0.8)
	b.tooltip_text = name + (": " + str(inst.get("name", "")) if not inst.is_empty() else " (empty)")
	if uid != "" and uid == _sel_uid:
		b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.DUSK, UiTheme.TEXT))
	return b


func refresh() -> void:
	var d: Dictionary = Profile.data
	for col: VBoxContainer in [_left, _right]:
		for ch: Node in col.get_children():
			ch.queue_free()
	for s1: String in LEFT_SLOTS:
		_left.add_child(_slot_cell(s1))
	for s2: String in RIGHT_SLOTS:
		_right.add_child(_slot_cell(s2))
	var st: Dictionary = HeroStats.for_hero(d, hero)
	var a: PackedStringArray = []
	var b: PackedStringArray = []
	var keys: Array = ["attack", "defense", "max_hp", "max_armor", "crit_chance", "crit_damage", "attack_speed", "move_speed", "skill_haste", "luck"]
	var short: Dictionary = {"attack": "ATK", "defense": "DEF", "max_hp": "HP", "max_armor": "SHD", "crit_chance": "CRIT",
		"crit_damage": "C.DMG", "attack_speed": "A.SPD", "move_speed": "MOVE", "skill_haste": "HASTE", "luck": "LUCK"}
	for i: int in keys.size():
		var line: String = "%-5s %s" % [short[keys[i]], HeroStats.show(keys[i], float(st[keys[i]]))]
		(a if i % 2 == 0 else b).append(line)
	_stats_label.text = "\n".join(a)
	_stats_label2.text = "\n".join(b)
	for ch2: Node in _bag_grid.get_children():
		ch2.queue_free()
	var bag: Array = Inventory.bag(d)
	for i2: int in maxi(bag.size(), COLS * 6):
		if i2 < bag.size():
			var u: String = str(bag[i2])
			var cell: Button = ItemUi.slot_button(Inventory.item(d, u), CELL, func() -> void: select(u))
			if u == _sel_uid:
				cell.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.DUSK, UiTheme.TEXT))
			_bag_grid.add_child(cell)
		else:
			var e: Panel = Panel.new()
			e.custom_minimum_size = Vector2(CELL, CELL)
			if SpriteManifest.has_image("ui_slot"):
				e.add_theme_stylebox_override("panel", UiTheme.tex_box("ui_slot", 0))
			_bag_grid.add_child(e)
	_bag_label.text = "BAG %d/%d    GOLD %d" % [bag.size(), Inventory.capacity(), Profile.gold()]
	_show_detail()


func select(uid: String) -> void:
	_sel_uid = uid
	refresh()


func _show_detail() -> void:
	for ch: Node in _tip_lines.get_children():
		ch.queue_free()
	var d: Dictionary = Profile.data
	var inst: Dictionary = Inventory.item(d, _sel_uid)
	if inst.is_empty():
		_sel_uid = ""
		_tip_title.text = "Select an item"
		_tip_title.add_theme_color_override("font_color", UiTheme.DIM)
		_tip_sub.text = ""
		_tip_lines.add_child(ItemUi.small_label("Click an item in the bag or an equipped slot to see its rolls and compare it.", UiTheme.DIM, 114))
		_btn_equip.disabled = true
		_btn_unequip.disabled = true
		_btn_sell.disabled = true
		_btn_equip.text = "EQUIP"
		_btn_sell.text = "SELL"
		return
	var col: Color = ItemGen.rarity_color(str(inst.get("rarity", "common")))
	_tip_title.text = str(inst.get("name", "?")).to_upper() + "\n[" + str(ItemGen.rarity(str(inst.get("rarity", "common"))).get("name", "")).to_upper() + "]"
	_tip_title.add_theme_color_override("font_color", col)
	if str(inst.get("kind", "")) == "book":
		_tip_sub.text = "Skill book"
	else:
		_tip_sub.text = "%s  -  item level %d" % [str((Db.items_cfg.get("slot_names", {}) as Dictionary).get(str(inst.get("slot", "")), "")), int(inst.get("ilvl", 1))]
	for line: String in ItemGen.describe(inst):
		_tip_lines.add_child(ItemUi.small_label(line, Color("#b4fff0") if line.begins_with("*") else UiTheme.TEXT, 114))
	var equipped_by: String = Inventory.owner_of(d, _sel_uid)
	var in_bag: bool = _sel_uid in Inventory.bag(d)
	_btn_unequip.disabled = equipped_by != hero or Inventory.is_full(d)
	_btn_sell.disabled = not in_bag
	_btn_sell.text = "SELL %dg" % int(inst.get("value", 0))
	if str(inst.get("kind", "")) == "book":
		var bk: Dictionary = Db.books.get(str(inst.get("base", "")), {})
		var known: bool = str(bk.get("kind", "")) == "skill" and str(bk.get("skill", "")) in HeroProgress.known_skills(hero, Profile.character_record(hero))
		_btn_equip.text = "KNOWN" if known else "READ"
		_btn_equip.disabled = known or not in_bag
	else:
		_btn_equip.text = "EQUIP"
		_btn_equip.disabled = not Inventory.can_equip(d, hero, _sel_uid)
		if equipped_by != "":
			_tip_lines.add_child(ItemUi.small_label("Equipped" + (" by " + Db.character(equipped_by).display_name if equipped_by != hero else ""), UiTheme.ACCENT, 114))
		else:
			if not Inventory.style_allowed(hero, inst):
				_tip_lines.add_child(ItemUi.small_label("%s cannot use %s weapons." % [Db.character(hero).display_name, Inventory.weapon_style_of(inst)], UiTheme.RED, 114))
			var cur: Dictionary = Inventory.equipped_in(d, hero, str(inst.get("slot", "")))
			_tip_lines.add_child(ItemUi.small_label("vs %s:" % str(cur.get("name", "empty slot")), UiTheme.DIM, 114))
			var diffs: Array = ItemUi.diff_lines(HeroStats.for_hero(d, hero), HeroStats.preview_equip(d, hero, _sel_uid))
			if diffs.is_empty():
				_tip_lines.add_child(ItemUi.small_label("no change", UiTheme.DIM, 114))
			for dl: Array in diffs:
				_tip_lines.add_child(ItemUi.small_label(str(dl[0]), dl[1], 114))
		var desc: String = str(ItemGen.template(str(inst.get("base", ""))).get("description", ""))
		if desc != "":
			_tip_lines.add_child(ItemUi.small_label(desc, UiTheme.DIM, 114))


## Equip from the bag, read a book, or unequip what is worn (keyboard / tests).
func _on_main() -> void:
	if _sel_uid != "" and Inventory.owner_of(Profile.data, _sel_uid) == hero:
		_on_unequip()
	else:
		_on_equip()


func _on_equip() -> void:
	if _busy or _sel_uid == "":
		return
	_busy = true
	var d: Dictionary = Profile.data
	var inst: Dictionary = Inventory.item(d, _sel_uid)
	var ok: bool
	if str(inst.get("kind", "")) == "book":
		var err: String = HeroProgress.read_book(d, hero, _sel_uid)
		ok = err == ""
		Events.toast.emit(("Learned from %s! Choose it at the Skill Library." % inst.get("name", "")) if ok else err)
		if ok:
			_sel_uid = ""
	else:
		ok = Inventory.equip(d, hero, _sel_uid)
	_finish(ok)


func _on_unequip() -> void:
	if _busy or _sel_uid == "":
		return
	_busy = true
	var inst: Dictionary = Inventory.item(Profile.data, _sel_uid)
	_finish(Inventory.owner_of(Profile.data, _sel_uid) == hero and Inventory.unequip(Profile.data, hero, str(inst.get("slot", ""))))


func _finish(ok: bool) -> void:
	Sfx.play("buy" if ok else "ui_deny")
	if ok:
		_after_change()
	_busy = false
	refresh()


func _on_sell() -> void:
	if _busy or _sel_uid == "":
		return
	_busy = true
	var name: String = str(Inventory.item(Profile.data, _sel_uid).get("name", ""))
	var g: int = Profile.sell_item(_sel_uid)
	if g > 0:
		Sfx.play("coin")
		Events.toast.emit("Sold %s for %d gold" % [name, g])
		_sel_uid = ""
		_after_change()
	else:
		Sfx.play("ui_deny")
	_busy = false
	refresh()


func _after_change() -> void:
	Profile.save()
	Events.inventory_changed.emit()
	var lvl: Level = Level.current
	if lvl != null and lvl.player != null and is_instance_valid(lvl.player) and lvl.player.character.id == hero:
		lvl.player.refresh_equipment()
	changed.emit()
