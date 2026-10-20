class_name ShopPanel
extends Modal
## Guild shop. Stock is rolled per expedition and saved (Profile.shop_stock),
## bought with gold; a sold entry cannot be bought twice. Selling happens in the
## inventory (opened from here).

var _sel: int = -1
var _list: VBoxContainer
var _gold: Label
var _detail: Label
var _buy: Button
var _busy: bool = false


func _ready() -> void:
	add_title("GUILD SHOP")
	_gold = UiTheme.label("", UiTheme.GOLD)
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_gold)
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	box.add_child(body)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(196, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	scroll.add_child(_list)
	var right: VBoxContainer = VBoxContainer.new()
	body.add_child(right)
	var ds: ScrollContainer = ScrollContainer.new()
	ds.custom_minimum_size = Vector2(150, 130)
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(ds)
	_detail = ItemUi.small_label("", UiTheme.TEXT, 144)
	ds.add_child(_detail)
	_buy = UiTheme.button("Buy", _on_buy)
	right.add_child(_buy)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	row.add_child(UiTheme.button("Sell items", func() -> void:
		var inv: InventoryPanel = InventoryPanel.new()
		inv.tree_exited.connect(refresh)
		add_child(inv)))
	row.add_child(UiTheme.button("Close", queue_free))
	add_text("Stock restocks after every expedition.", UiTheme.DIM, 300)
	refresh()
	super._ready()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


func refresh() -> void:
	if not is_inside_tree():
		return
	_gold.text = "Gold: %d     Bag %d/%d" % [Profile.gold(), Inventory.bag(Profile.data).size(), Inventory.capacity()]
	for ch: Node in _list.get_children():
		ch.queue_free()
	var stock: Array = Profile.shop_stock()
	for i: int in stock.size():
		var e: Dictionary = stock[i]
		var inst: Dictionary = e["item"]
		var line: HBoxContainer = HBoxContainer.new()
		line.add_child(ItemUi.slot_button(inst, 18.0, func() -> void: _pick(i)))
		var sold: bool = bool(e.get("sold", false))
		var b: Button = UiTheme.button("%s  %s" % [ItemGen.label(inst), "SOLD" if sold else "%dg" % int(e["price"])], func() -> void: _pick(i))
		b.add_theme_color_override("font_color", UiTheme.DIM if sold else ItemGen.rarity_color(str(inst.get("rarity", "common"))))
		b.custom_minimum_size = Vector2(170, 0)
		b.clip_text = true
		if i == _sel:
			b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.DUSK, UiTheme.TEXT))
		line.add_child(b)
		_list.add_child(line)
	_show()


func _pick(i: int) -> void:
	_sel = i
	refresh()


func _show() -> void:
	var stock: Array = Profile.shop_stock()
	if _sel < 0 or _sel >= stock.size():
		_detail.text = "Pick an item to inspect it."
		_buy.visible = false
		return
	var e: Dictionary = stock[_sel]
	var inst: Dictionary = e["item"]
	var lines: PackedStringArray = [ItemUi.header(inst)]
	lines.append_array(ItemGen.describe(inst))
	if str(inst.get("kind", "")) == "equipment":
		var hero: String = Profile.selected_hero()
		var cur: Dictionary = Inventory.equipped_in(Profile.data, hero, str(inst.get("slot", "")))
		var before: Dictionary = HeroStats.for_hero(Profile.data, hero)
		var items: Array = []
		for it: Dictionary in Inventory.equipped_items(Profile.data, hero):
			if str(it.get("slot", "")) != str(inst.get("slot", "")):
				items.append(it)
		items.append(inst)
		var rec: Dictionary = Profile.character_record(hero)
		var after: Dictionary = HeroStats.compute(Db.character(hero), int(rec["level"]), items, HeroProgress.tree_bonus(hero, rec))
		lines.append("vs %s:" % (cur.get("name", "empty slot")))
		for dl: Array in ItemUi.diff_lines(before, after):
			lines.append("  " + str(dl[0]))
	_detail.text = "\n".join(lines)
	_buy.visible = true
	var sold: bool = bool(e.get("sold", false))
	_buy.text = "Sold out" if sold else "Buy (%dg)" % int(e["price"])
	_buy.disabled = sold or Profile.gold() < int(e["price"]) or Inventory.is_full(Profile.data)


func _on_buy() -> void:
	if _busy:
		return
	_busy = true
	var name: String = ItemGen.label((Profile.shop_stock()[_sel] as Dictionary)["item"]) if _sel >= 0 and _sel < Profile.shop_stock().size() else ""
	var err: String = Profile.buy_from_shop(_sel)
	if err == "":
		Sfx.play("buy")
		Events.toast.emit("Bought %s" % name)
	else:
		Sfx.play("ui_deny")
		Events.toast.emit(err)
	_busy = false
	refresh()
