class_name ShopItem
extends Interactable
## A priced item on a pedestal in the shop room. Paid with run coins.

var item_type: String = "heart" # weapon | heart | armor | boon
var item_id: String = ""
var price: int = 10
var sold: bool = false
var _icon: Sprite2D


static func create(type: String, id: String, cost: int, pos: Vector2) -> ShopItem:
	var s: ShopItem = ShopItem.new()
	s.item_type = type
	s.item_id = id
	s.price = cost
	s.position = pos
	return s


func _ready() -> void:
	super._ready()
	var ped: Sprite2D = Sprite2D.new()
	SpriteLib.apply(ped, "prop_pedestal")
	add_child(ped)
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = Level.WORLD_MASK
	var cs: CollisionShape2D = CollisionShape2D.new()
	var sh: RectangleShape2D = RectangleShape2D.new()
	sh.size = Vector2(10, 5)
	cs.shape = sh
	cs.position = Vector2(0, 5)
	body.add_child(cs)
	add_child(body)
	_icon = Sprite2D.new()
	_icon.position = Vector2(0, -6)
	match item_type:
		"weapon":
			SpriteLib.apply(_icon, "weapon_" + item_id)
		"heart":
			_icon.texture = SpriteLib.texture("icon_heart")
		"armor":
			_icon.texture = SpriteLib.texture("icon_shield")
		"boon":
			_icon.texture = SpriteLib.texture(str(Db.boons.get(item_id, {}).get("icon", "icon_boon_power")))
	add_child(_icon)
	set_caption("%d" % price, UiTheme.GOLD, 9.0)


func _process(_delta: float) -> void:
	if not sold:
		_icon.position.y = -7.0 + sin(Time.get_ticks_msec() / 300.0) * 1.0


func _name() -> String:
	match item_type:
		"weapon":
			return Db.weapon(item_id).display_name
		"heart":
			return "Heal 3 HP"
		"armor":
			return "Full Armor"
		"boon":
			return str(Db.boons.get(item_id, {}).get("name", item_id))
	return item_id


func can_interact(_p: Player) -> bool:
	return not sold


func interact_text() -> String:
	return "Buy %s (%d coins)" % [_name(), price]


func interact(p: Player) -> void:
	var run: RunState = Game.run
	if run == null or sold:
		return
	if run.coins < price:
		Sfx.play("ui_deny")
		FX.float_text(global_position, "Not enough coins", UiTheme.RED)
		return
	run.coins -= price
	Events.coins_changed.emit(run.coins)
	Events.coins_spent.emit(price)
	Sfx.play("buy")
	sold = true
	_icon.visible = false
	set_caption("SOLD", UiTheme.DIM, 9.0)
	match item_type:
		"weapon":
			var dropped: String = p.give_weapon(item_id)
			if dropped != "":
				Level.current.add_entity(WeaponPickup.create(dropped, global_position + Vector2(0, 16)))
		"heart":
			p.heal(3)
		"armor":
			p.health.restore_armor(p.health.max_armor)
		"boon":
			run.add_boon(item_id)
			p.recompute_stats()
			if Db.boons.get(item_id, {}).get("mods", {}).has("heal"):
				p.heal(int(Db.boons[item_id]["mods"]["heal"]))
			FX.float_text(p.global_position, _name(), UiTheme.ACCENT)
