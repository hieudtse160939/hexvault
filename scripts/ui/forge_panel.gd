class_name ForgePanel
extends Modal
## Permanent upgrades bought with shards.

var _list: VBoxContainer


func _ready() -> void:
	add_title("RUNE FORGE")
	add_text("Permanent upgrades apply to every hero, every run.", UiTheme.DIM, 280)
	_list = VBoxContainer.new()
	box.add_child(_list)
	add_button("Close", queue_free)
	_rebuild()
	super._ready()


func _rebuild() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	for id: String in Db.upgrade_order:
		var u: Dictionary = Db.upgrades[id]
		var row: HBoxContainer = HBoxContainer.new()
		var icon: TextureRect = TextureRect.new()
		icon.texture = SpriteLib.texture(str(u.get("icon", "icon_shard")))
		row.add_child(icon)
		var lvl: int = Profile.upgrade_level(id)
		var max_lvl: int = (u.get("costs", []) as Array).size()
		var name_l: Label = UiTheme.label("%s %s" % [u.get("name", id), "*".repeat(lvl) + "-".repeat(max_lvl - lvl)], UiTheme.TEXT)
		name_l.custom_minimum_size = Vector2(120, 0)
		name_l.tooltip_text = str(u.get("description", ""))
		row.add_child(name_l)
		var desc: Label = UiTheme.label(str(u.get("description", "")), UiTheme.DIM)
		desc.custom_minimum_size = Vector2(110, 0)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(desc)
		var cost: int = Profile.upgrade_cost(id)
		var b: Button = Button.new()
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(56, 0)
		b.text = "MAX" if cost < 0 else "%d" % cost
		b.disabled = cost < 0 or Profile.shards() < cost
		b.pressed.connect(func() -> void:
			if Profile.buy_upgrade(id):
				Sfx.play("buy")
				_rebuild()
			else:
				Sfx.play("ui_deny"))
		row.add_child(b)
		_list.add_child(row)
	focus_first.call_deferred()
