class_name WeaponPickup
extends Interactable
## A weapon lying on the floor. Picking it up swaps it with the held one.

var weapon_id: String = ""
var _sprite: Sprite2D
var _t: float = 0.0


static func create(id: String, pos: Vector2) -> WeaponPickup:
	var w: WeaponPickup = WeaponPickup.new()
	w.weapon_id = id
	w.position = pos
	return w


func _ready() -> void:
	super._ready()
	var d: WeaponData = Db.weapon(weapon_id)
	_sprite = Sprite2D.new()
	SpriteLib.apply(_sprite, "weapon_" + weapon_id)
	add_child(_sprite)
	var glow: Sprite2D = Sprite2D.new()
	SpriteLib.apply(glow, "prop_shadow_m")
	glow.position = Vector2(0, 8)
	glow.z_index = -1
	add_child(glow)
	if d != null:
		set_caption(d.display_name, d.rarity_color(), 8.0)
		label.visible = false


func _process(delta: float) -> void:
	_t += delta
	_sprite.position.y = sin(_t * 3.0) * 1.5 - 2.0
	var lvl: Level = Level.current
	if lvl != null and lvl.player != null and label != null:
		label.visible = global_position.distance_to(lvl.player.global_position) < 40.0


func interact_text() -> String:
	var d: WeaponData = Db.weapon(weapon_id)
	return "Take %s" % (d.display_name if d != null else weapon_id)


func interact(p: Player) -> void:
	var dropped: String = p.give_weapon(weapon_id)
	Sfx.play("reload")
	FX.burst("sparkle_teal", global_position)
	if dropped != "":
		var lvl: Level = Level.current
		if lvl != null:
			lvl.add_entity(WeaponPickup.create(dropped, global_position))
	queue_free()


## Random weapon id weighted by rarity, from weapons the profile has unlocked.
static func roll(rng: RandomNumberGenerator, floor_index: int, exclude: Array = []) -> String:
	var weights: Dictionary = {"common": 10.0, "rare": 7.0, "epic": 2.5 + floor_index, "legendary": 0.5 + floor_index * 0.5}
	var pool: Array[String] = []
	var ws: Array[float] = []
	var total: float = 0.0
	for id: String in Profile.unlocked_weapon_ids():
		if id in exclude:
			continue
		var w: float = float(weights.get(Db.weapon(id).rarity, 1.0))
		pool.append(id)
		ws.append(w)
		total += w
	if pool.is_empty():
		return "rift_pistol"
	var r: float = rng.randf() * total
	for i: int in pool.size():
		r -= ws[i]
		if r <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]
