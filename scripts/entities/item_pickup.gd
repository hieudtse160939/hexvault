class_name ItemPickup
extends Node2D
## A dropped equipment piece or skill book. Pops out of the enemy/chest, shows
## its rarity (beam colour AND a letter tag), and is collected by walking over
## it: the instance goes straight into the permanent inventory exactly once.

const COLLECT_DIST: float = 9.0
const POP_TIME: float = 0.45

var item: Dictionary = {}
var collected: bool = false
var _age: float = 0.0
var _vel: Vector2 = Vector2.ZERO
var _icon: Sprite2D
var _full_warned: bool = false


## Rolls a loot table (data/items.json) for the current run and spawns the drops.
static func drop_table(table_id: String, pos: Vector2, rng: RandomNumberGenerator) -> Array[ItemPickup]:
	var out: Array[ItemPickup] = []
	var run: RunState = Game.run
	var lvl: Level = Level.current
	if lvl == null:
		return out
	var ilvl: int = run.drop_level() if run != null else 1
	var bonus: float = run.rarity_bonus if run != null else 0.0
	var luck: float = lvl.player.luck if lvl.player != null and is_instance_valid(lvl.player) else 0.0
	for inst: Dictionary in ItemGen.roll_table(table_id, rng, ilvl, bonus, luck):
		out.append(spawn(inst, pos, rng))
	return out


static func spawn(inst: Dictionary, pos: Vector2, rng: RandomNumberGenerator = null) -> ItemPickup:
	var p: ItemPickup = ItemPickup.new()
	p.item = inst
	p.position = pos
	var ang: float = (rng.randf() if rng != null else randf()) * TAU
	p._vel = Vector2.from_angle(ang) * 55.0
	if Level.current != null:
		Level.current.add_entity(p)
	return p


func _ready() -> void:
	z_index = 2
	_icon = Sprite2D.new()
	var key: String = ItemPickup.icon_key(item)
	_icon.texture = SpriteLib.texture(key)
	if _icon.texture != null:
		# fit inside 14 world units whatever the art density
		var world: Vector2 = Vector2(_icon.texture.get_size()) / SpriteLib.density(key)
		_icon.scale = Vector2.ONE / SpriteLib.density(key) * minf(1.0, 14.0 / maxf(world.x, world.y))
	if SpriteLib.is_hd(key):
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		FX.make_flashable(_icon)
	add_child(_icon)
	var col: Color = ItemGen.rarity_color(str(item.get("rarity", "common")))
	var tag: Label = UiTheme.label(str(ItemGen.rarity(str(item.get("rarity", "common"))).get("tag", "?")), col, true)
	tag.add_theme_font_override("font", SpriteLib.font())
	tag.position = Vector2(5, -14)
	add_child(tag)
	if ItemGen.rarity_tier(str(item.get("rarity", "common"))) >= 2 and not Settings.reduced_effects():
		FX.burst("sparkle", global_position)


## Icon for an item: the weapon sprite, a slot icon, or a shared fallback.
static func icon_key(inst: Dictionary) -> String:
	if str(inst.get("kind", "")) == "book":
		return "icon_item_book" if SpriteManifest.has_image("icon_item_book") else "icon_scroll"
	var t: Dictionary = ItemGen.template(str(inst.get("base", "")))
	if t.has("weapon") and SpriteManifest.has_sprite("weapon_" + str(t["weapon"])):
		return "weapon_" + str(t["weapon"])
	var slot: String = str(inst.get("slot", ""))
	if SpriteManifest.has_image("icon_item_" + slot):
		return "icon_item_" + slot
	return {"helmet": "icon_shield", "armor": "icon_shield", "gloves": "icon_boon_reload",
		"boots": "icon_boon_haste", "accessory": "icon_boon_crit"}.get(slot, "icon_scroll")


func _draw() -> void:
	var col: Color = ItemGen.rarity_color(str(item.get("rarity", "common")))
	draw_circle(Vector2(0, 5), 5.0, Color(col, 0.25))
	draw_rect(Rect2(-1, -26, 2, 24), Color(col, 0.35 + 0.15 * sin(_age * 4.0)))


func _physics_process(delta: float) -> void:
	if collected:
		return
	_age += delta
	queue_redraw()
	if _age < POP_TIME:
		var nxt: Vector2 = position + _vel * delta
		if Level.current != null and Level.current.is_walkable(Level.to_tile(nxt)):
			position = nxt
		_vel *= 0.88
		_icon.position.y = -sin(_age / POP_TIME * PI) * 8.0
		return
	_icon.position.y = -2.0 + sin(_age * 3.0) * 1.5
	var lvl: Level = Level.current
	var p: Player = lvl.player if lvl != null else null
	if p == null or not is_instance_valid(p) or not p.is_alive():
		return
	if global_position.distance_to(p.global_position) < COLLECT_DIST:
		try_collect(p)


## Moves the item into the inventory. Returns true once; later calls do nothing.
func try_collect(_p: Player) -> bool:
	if collected:
		return false
	var uid: String = Profile.give_item(item)
	if uid == "":
		if not _full_warned:
			_full_warned = true
			FX.float_text(global_position, "BAG FULL", UiTheme.RED)
			Events.toast.emit("Bag full (%d/%d): sell or salvage items in the Guild." % [Inventory.bag(Profile.data).size(), Inventory.capacity()])
		return false
	collected = true
	if Game.run != null:
		Game.run.loot.append(Inventory.item(Profile.data, uid).duplicate(true))
	Events.item_found.emit(Inventory.item(Profile.data, uid))
	Events.toast.emit("Found %s" % ItemGen.label(item))
	FX.float_text(global_position, str(item.get("name", "")), ItemGen.rarity_color(str(item.get("rarity", "common"))))
	Sfx.play("boon" if ItemGen.rarity_tier(str(item.get("rarity", "common"))) >= 3 else "shard", -3.0)
	queue_free()
	return true
