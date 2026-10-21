class_name TrainingDummy
extends StaticBody2D
## Guild training dummy: takes real player hits (same hurtbox and damage
## pipeline as enemies), shows the damage numbers and a running DPS readout,
## never dies and never fights back.

const WINDOW: float = 5.0

var total: int = 0
var hits: int = 0
var _log: Array = []          # [time, damage]
var _time: float = 0.0
var _sprite: AnimatedSprite2D
var _label: Label


static func create(pos: Vector2) -> TrainingDummy:
	var d: TrainingDummy = TrainingDummy.new()
	d.position = pos
	return d


func _ready() -> void:
	collision_layer = Level.WORLD_MASK
	collision_mask = 0
	var cs: CollisionShape2D = CollisionShape2D.new()
	var sh: RectangleShape2D = RectangleShape2D.new()
	sh.size = Vector2(8, 5)
	cs.shape = sh
	cs.position = Vector2(0, 4)
	add_child(cs)
	_sprite = AnimatedSprite2D.new()
	SpriteLib.apply(_sprite, "guild_dummy")
	_sprite.position = Vector2(0, 6) - SpriteLib.pivot_from_centre_world("guild_dummy")
	_sprite.play(&"idle")
	_sprite.animation_finished.connect(func() -> void: _sprite.play(&"idle"))
	FX.make_flashable(_sprite)
	add_child(_sprite)
	var hb: Hurtbox = Hurtbox.create(self, 7.0, false)
	hb.position = Vector2(0, -6)
	add_child(hb)
	_label = UiTheme.label("", UiTheme.DIM, true)
	_label.add_theme_font_override("font", SpriteLib.font())
	_label.position = Vector2(-22, 9)
	_label.z_index = 25
	add_child(_label)


func is_alive() -> bool:
	return true


func receive_hit(info: HitInfo) -> bool:
	if not info.from_player:
		return false
	var lvl: Level = Level.current
	if lvl != null and lvl.player != null and is_instance_valid(lvl.player):
		lvl.player.modify_outgoing_hit(info, self)
	total += info.damage
	hits += 1
	_log.append([_time, info.damage])
	FX.flash(_sprite)
	FX.damage_number(global_position + Vector2(0, -14), info.damage, info.crit)
	Sfx.play("crit" if info.crit else "hit", -6.0)
	_sprite.play(&"hit")
	return true


func dps() -> float:
	var sum: int = 0
	for e: Array in _log:
		sum += int(e[1])
	return float(sum) / WINDOW


func _process(delta: float) -> void:
	_time += delta
	while not _log.is_empty() and _time - float(_log[0][0]) > WINDOW:
		_log.pop_front()
	_label.text = ("DPS %.1f" % dps()) if not _log.is_empty() else ""
