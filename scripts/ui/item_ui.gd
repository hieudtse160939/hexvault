class_name ItemUi
extends RefCounted
## Shared widgets for item screens (inventory, shop, results).


## A square button showing the item's icon, rarity frame and rarity letter.
static func slot_button(inst: Dictionary, size: float, on_press: Callable, empty_text: String = "") -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	if inst.is_empty():
		b.text = empty_text
		b.add_theme_font_size_override("font_size", 8)
		b.modulate = Color(1, 1, 1, 0.55)
	else:
		var col: Color = ItemGen.rarity_color(str(inst.get("rarity", "common")))
		b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.NIGHT, col))
		b.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.DUSK, col))
		b.add_theme_stylebox_override("focus", UiTheme.box(UiTheme.DUSK, UiTheme.TEXT))
		var icon: TextureRect = TextureRect.new()
		SpriteLib.fit_icon(icon, ItemPickup.icon_key(inst))
		var s: Vector2 = icon.size
		var k: float = minf(1.0, (size - 4.0) / maxf(maxf(s.x, s.y), 1.0))
		icon.custom_minimum_size = s * k
		icon.size = s * k
		icon.position = (Vector2(size, size) - icon.size) / 2.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		var tag: Label = UiTheme.label(str(ItemGen.rarity(str(inst.get("rarity", "common"))).get("tag", "")), col, true)
		tag.position = Vector2(1, -2)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tag)
		b.tooltip_text = ItemGen.label(inst)
	if on_press.is_valid():
		b.pressed.connect(func() -> void:
			Sfx.play("ui_click")
			on_press.call())
	return b


## "+3 Attack" style differences between two final stat blocks, green/red.
static func diff_lines(before: Dictionary, after: Dictionary) -> Array:
	var out: Array = []   # [text, color]
	for k: String in HeroStats.KEYS:
		var d: float = float(after.get(k, 0.0)) - float(before.get(k, 0.0))
		if absf(d) < 0.0005:
			continue
		var txt: String
		if k in ["crit_chance", "attack_speed", "move_speed", "skill_haste", "skill_power", "crit_damage"]:
			txt = "%s%d%% %s" % ["+" if d > 0 else "", roundi(d * 100.0), HeroStats.LABELS[k]]
		else:
			txt = "%s%s %s" % ["+" if d > 0 else "", ("%.1f" % d) if absf(d - roundf(d)) > 0.05 else str(roundi(d)), HeroStats.LABELS[k]]
		out.append([txt, UiTheme.GREEN if d > 0 else UiTheme.RED])
	return out


static func header(inst: Dictionary) -> String:
	if inst.is_empty():
		return ""
	var r: Dictionary = ItemGen.rarity(str(inst.get("rarity", "common")))
	if str(inst.get("kind", "")) == "book":
		return "%s\n%s Skill Book" % [str(inst.get("name", "?")), str(r.get("name", ""))]
	return "%s\n%s %s  -  item level %d" % [str(inst.get("name", "?")), str(r.get("name", "")),
		str((Db.items_cfg.get("slot_names", {}) as Dictionary).get(str(inst.get("slot", "")), "")), int(inst.get("ilvl", 1))]


static func small_label(text: String, color: Color = UiTheme.TEXT, width: float = 0.0) -> Label:
	var l: Label = UiTheme.label(text, color)
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
	return l
