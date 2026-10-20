class_name InventoryPanel
extends Modal
## Equipment station / inventory. Works on the real profile inventory
## (Inventory + Profile.data): every button changes owned items, and the
## final stats are recomputed by HeroStats after each change.
##
## Left: equipment slots + final stats. Middle: the bag. Right: the selected
## item with its rolls and the stat changes if it were equipped.

signal changed

const COLS: int = 7
const CELL: float = 22.0

var hero: String = ""
var _sel_uid: String = ""
var _slots_box: VBoxContainer
var _stats_label: Label
var _bag_grid: GridContainer
var _bag_label: Label
var _gold_label: Label
var _detail_title: Label
var _detail_lines: VBoxContainer
var _btn_main: Button
var _btn_sell: Button
var _busy: bool = false


func _ready() -> void:
	if hero == "":
		hero = Profile.selected_hero()
	var c: CharacterData = Db.character(hero)
	add_title("EQUIPMENT - %s  Lv %d" % [c.display_name if c != null else hero, Profile.hero_level(hero)])
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	box.add_child(body)
	# left: slots + stats
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(118, 0)
	body.add_child(left)
	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 1)
	left.add_child(_slots_box)
	_stats_label = ItemUi.small_label("", UiTheme.TEXT, 118)
	left.add_child(_stats_label)
	# middle: bag
	var mid: VBoxContainer = VBoxContainer.new()
	body.add_child(mid)
	_bag_label = UiTheme.label("", UiTheme.DIM)
	mid.add_child(_bag_label)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(COLS * (CELL + 1) + 6, 5 * (CELL + 1))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = COLS
	_bag_grid.add_theme_constant_override("h_separation", 1)
	_bag_grid.add_theme_constant_override("v_separation", 1)
	scroll.add_child(_bag_grid)
	_gold_label = UiTheme.label("", UiTheme.GOLD)
	mid.add_child(_gold_label)
	# right: detail
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(140, 0)
	body.add_child(right)
	_detail_title = ItemUi.small_label("", UiTheme.GOLD, 140)
	right.add_child(_detail_title)
	var dscroll: ScrollContainer = ScrollContainer.new()
	dscroll.custom_minimum_size = Vector2(140, 104)
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(dscroll)
	_detail_lines = VBoxContainer.new()
	_detail_lines.add_theme_constant_override("separation", 0)
	dscroll.add_child(_detail_lines)
	var acts: HBoxContainer = HBoxContainer.new()
	right.add_child(acts)
	_btn_main = UiTheme.button("Equip", _on_main)
	acts.add_child(_btn_main)
	_btn_sell = UiTheme.button("Sell", _on_sell)
	acts.add_child(_btn_sell)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	row.add_child(UiTheme.button("Close", queue_free))
	refresh()
	super._ready()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		queue_free()


func refresh() -> void:
	var d: Dictionary = Profile.data
	for ch: Node in _slots_box.get_children():
		ch.queue_free()
	for slot: Variant in Db.items_cfg.get("slots", []):
		var inst: Dictionary = Inventory.equipped_in(d, hero, str(slot))
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var uid: String = str(inst.get("uid", ""))
		row.add_child(ItemUi.slot_button(inst, 16.0, func() -> void: select(uid) if uid != "" else null, ""))
		var name: String = str(inst.get("name", "- empty -")) if not inst.is_empty() else "- %s -" % str((Db.items_cfg.get("slot_names", {}) as Dictionary).get(str(slot), slot))
		var l: Label = UiTheme.label(name, ItemGen.rarity_color(str(inst.get("rarity", "common"))) if not inst.is_empty() else UiTheme.DIM)
		l.clip_text = true
		l.custom_minimum_size = Vector2(96, 0)
		row.add_child(l)
		_slots_box.add_child(row)
	var st: Dictionary = HeroStats.for_hero(d, hero)
	var parts: PackedStringArray = []
	for k: String in ["attack", "defense", "max_hp", "max_armor", "crit_chance", "crit_damage", "attack_speed", "move_speed", "skill_haste", "luck"]:
		parts.append("%-12s %s" % [HeroStats.LABELS[k], HeroStats.show(k, float(st[k]))])
	_stats_label.text = "\n".join(parts)
	for ch2: Node in _bag_grid.get_children():
		ch2.queue_free()
	var bag: Array = Inventory.bag(d)
	for i: int in maxi(bag.size(), COLS * 5):
		if i < bag.size():
			var u: String = str(bag[i])
			var b: Button = ItemUi.slot_button(Inventory.item(d, u), CELL, func() -> void: select(u))
			if u == _sel_uid:
				b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.DUSK, UiTheme.TEXT))
			_bag_grid.add_child(b)
		else:
			var e: Control = Control.new()
			e.custom_minimum_size = Vector2(CELL, CELL)
			_bag_grid.add_child(e)
	_bag_label.text = "Bag %d / %d" % [bag.size(), Inventory.capacity()]
	_gold_label.text = "Gold %d" % Profile.gold()
	_show_detail()


func select(uid: String) -> void:
	_sel_uid = uid
	refresh()


func _show_detail() -> void:
	for ch: Node in _detail_lines.get_children():
		ch.queue_free()
	var d: Dictionary = Profile.data
	var inst: Dictionary = Inventory.item(d, _sel_uid)
	_btn_main.visible = not inst.is_empty()
	_btn_sell.visible = not inst.is_empty()
	if inst.is_empty():
		_sel_uid = ""
		_detail_title.text = "Select an item"
		_detail_title.add_theme_color_override("font_color", UiTheme.DIM)
		_detail_lines.add_child(ItemUi.small_label("Click a bag item to see its rolls and compare it with what you wear.", UiTheme.DIM, 136))
		return
	_detail_title.text = ItemUi.header(inst)
	_detail_title.add_theme_color_override("font_color", ItemGen.rarity_color(str(inst.get("rarity", "common"))))
	for line: String in ItemGen.describe(inst):
		_detail_lines.add_child(ItemUi.small_label(line, Color("#b4fff0") if line.begins_with("*") else UiTheme.TEXT, 136))
	var equipped_by: String = Inventory.owner_of(d, _sel_uid)
	var in_bag: bool = _sel_uid in Inventory.bag(d)
	if str(inst.get("kind", "")) == "book":
		var b: Dictionary = Db.books.get(str(inst.get("base", "")), {})
		var known: bool = str(b.get("kind", "")) == "skill" and str(b.get("skill", "")) in HeroProgress.known_skills(hero, Profile.character_record(hero))
		_btn_main.text = "Already known" if known else "Read"
		_btn_main.disabled = known or not in_bag
	elif equipped_by != "":
		_btn_main.text = "Unequip"
		_btn_main.disabled = equipped_by != hero or Inventory.is_full(d)
		_detail_lines.add_child(ItemUi.small_label("Equipped" + (" by " + Db.character(equipped_by).display_name if equipped_by != hero else ""), UiTheme.ACCENT, 136))
	else:
		_btn_main.text = "Equip"
		_btn_main.disabled = not Inventory.can_equip(d, hero, _sel_uid)
		var cur: Dictionary = Inventory.equipped_in(d, hero, str(inst.get("slot", "")))
		_detail_lines.add_child(ItemUi.small_label("If equipped%s:" % ((" (replaces %s)" % cur.get("name", "")) if not cur.is_empty() else ""), UiTheme.DIM, 136))
		var diffs: Array = ItemUi.diff_lines(HeroStats.for_hero(d, hero), HeroStats.preview_equip(d, hero, _sel_uid))
		if diffs.is_empty():
			_detail_lines.add_child(ItemUi.small_label("no change", UiTheme.DIM, 136))
		for dl: Array in diffs:
			_detail_lines.add_child(ItemUi.small_label(str(dl[0]), dl[1], 136))
	_btn_sell.text = "Sell %dg" % int(inst.get("value", 0))
	_btn_sell.disabled = not in_bag


func _on_main() -> void:
	if _busy or _sel_uid == "":
		return
	_busy = true
	var d: Dictionary = Profile.data
	var inst: Dictionary = Inventory.item(d, _sel_uid)
	var ok: bool = false
	if str(inst.get("kind", "")) == "book":
		var err: String = HeroProgress.read_book(d, hero, _sel_uid)
		ok = err == ""
		Events.toast.emit(("Learned from %s! Choose it at the Skill Tree." % inst.get("name", "")) if ok else err)
		if ok:
			_sel_uid = ""
	elif Inventory.owner_of(d, _sel_uid) == hero:
		ok = Inventory.unequip(d, hero, str(inst.get("slot", "")))
	else:
		ok = Inventory.equip(d, hero, _sel_uid)
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
