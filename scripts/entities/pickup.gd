class_name Pickup
extends Node2D
## Coins, shards, hearts and armor. Pops out, then is pulled toward the player.

enum Kind { COIN, SHARD, HEART, ARMOR }

const SPRITES: Dictionary = {Kind.COIN: "pickup_coin", Kind.SHARD: "pickup_shard", Kind.HEART: "pickup_heart", Kind.ARMOR: "pickup_armor"}
const BASE_MAGNET: float = 34.0
const COLLECT_DIST: float = 7.0

var kind: int = Kind.COIN
var value: int = 1
var _vel: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _sprite: AnimatedSprite2D


static func spawn(k: int, pos: Vector2, v: int) -> Pickup:
	var lvl: Level = Level.current
	if lvl == null:
		return null
	var p: Pickup = Pickup.new()
	p.kind = k
	p.value = v
	p.position = pos
	p._vel = Vector2.from_angle(randf() * TAU) * randf_range(30.0, 70.0)
	lvl.add_entity(p)
	return p


static func spawn_coins(pos: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	var nodes: int = clampi(amount, 1, 6)
	var each: int = amount / nodes
	var rest: int = amount - each * nodes
	for i: int in nodes:
		spawn(Kind.COIN, pos, each + (1 if i < rest else 0))


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = SpriteLib.frames(SPRITES[kind])
	_sprite.play(&"idle")
	_sprite.frame = randi() % maxi(_sprite.sprite_frames.get_frame_count(&"idle"), 1)
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	_age += delta
	var lvl: Level = Level.current
	var p: Player = lvl.player if lvl != null else null
	if _age < 0.35:
		var nxt: Vector2 = position + _vel * delta
		if lvl != null and lvl.is_walkable(Level.to_tile(nxt)):
			position = nxt
		_vel *= 0.9
		_sprite.position.y = -sin(_age / 0.35 * PI) * 6.0
		return
	_sprite.position.y = sin(_age * 4.0) * 1.0
	if p == null or not p.is_alive():
		return
	if kind == Kind.HEART and p.health.hp >= p.health.max_hp:
		return
	if kind == Kind.ARMOR and p.health.armor >= p.health.max_armor:
		return
	var magnet: float = BASE_MAGNET
	if Game.run != null and Game.run.boon_total("magnet") > 0.0:
		magnet = 140.0
	var d: float = global_position.distance_to(p.global_position)
	if d < COLLECT_DIST:
		_collect(p)
	elif d < magnet or (kind in [Kind.COIN, Kind.SHARD] and lvl.active_room != null and lvl.active_room.cleared and d < 160.0):
		global_position = global_position.move_toward(p.global_position, (220.0 + 400.0 / maxf(d, 8.0)) * delta)


func _collect(p: Player) -> void:
	var run: RunState = Game.run
	match kind:
		Kind.COIN:
			var v: int = int(round(value * (1.0 + (run.boon_total("coin_mult") if run != null else 0.0))))
			if run != null:
				run.coins += v
				Events.coins_changed.emit(run.coins)
			Sfx.play("coin", -6.0)
		Kind.SHARD:
			if run != null:
				run.shards += value
				Events.run_shards_changed.emit(run.shards)
			FX.float_text(global_position, "+%d" % value, Color("#4fe0d0"))
			Sfx.play("shard", -3.0)
		Kind.HEART:
			p.heal(value * 2)
		Kind.ARMOR:
			p.health.restore_armor(value * 2)
			Sfx.play("heal", -4.0)
	FX.burst("sparkle", global_position)
	queue_free()
