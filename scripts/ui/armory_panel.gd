class_name ArmoryPanel
extends Modal
## Weapon unlocks. Unlocked weapons can appear in chests and shops.

var _list: VBoxContainer
var _info: Label


func _ready() -> void:
	add_title("ARMORY")
	add_text("Unlocked weapons can drop in chests and appear in shops.", UiTheme.DIM, 280)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(290, 140)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_info = add_text("", UiTheme.TEXT, 280)
	add_button("Close", queue_free)
	_rebuild()
	super._ready()


func _rebuild() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	for id: String in Db.weapon_order:
		var w: WeaponData = Db.weapon(id)
		var row: HBoxContainer = HBoxContainer.new()
		var icon: TextureRect = TextureRect.new()
		icon.texture = SpriteLib.still("weapon_" + id)
		icon.custom_minimum_size = Vector2(26, 12)
		row.add_child(icon)
		var name_l: Label = UiTheme.label(w.display_name, w.rarity_color())
		name_l.custom_minimum_size = Vector2(90, 0)
		row.add_child(name_l)
		var cat: Label = UiTheme.label(w.category.replace("_", " "), UiTheme.DIM)
		cat.custom_minimum_size = Vector2(70, 0)
		row.add_child(cat)
		var b: Button = Button.new()
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(80, 0)
		if Profile.is_weapon_unlocked(id):
			b.text = "Owned"
			b.disabled = true
		else:
			match str(w.unlock.get("type", "")):
				"shards":
					b.text = "%d shards" % int(w.unlock.get("cost", 0))
					b.disabled = Profile.shards() < int(w.unlock.get("cost", 0))
				"achievement":
					b.text = "Achievement"
					b.disabled = true
		b.pressed.connect(func() -> void:
			if Profile.buy_weapon(id):
				Sfx.play("buy")
				_rebuild()
			else:
				Sfx.play("ui_deny"))
		b.focus_entered.connect(func() -> void: _describe(w))
		b.mouse_entered.connect(func() -> void: _describe(w))
		row.add_child(b)
		_list.add_child(row)


func _describe(w: WeaponData) -> void:
	var ammo: String = "infinite" if w.magazine <= 0 else "%d mag, %.1fs reload" % [w.magazine, w.reload_time]
	var extra: String = ""
	if w.unlock.get("type", "") == "achievement":
		extra = "\nUnlock: " + str(Db.achievements.get(str(w.unlock.get("id", "")), {}).get("name", "?"))
	_info.text = "%s - %s\nDMG %d  RATE %.1f/s  %s%s" % [w.display_name, w.description, w.damage * w.pellets, 1.0 / w.fire_interval, ammo, extra]
