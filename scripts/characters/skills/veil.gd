extends HeroSkill
## Sable - VEIL: vanish. Enemies lose track of you, you move faster, and the
## first hit you land from the shadows deals triple damage and ends the veil.

var _ambush: bool = false


func activate() -> void:
	_ambush = true
	player.body.modulate.a = 0.35
	FX.burst("puff", player.global_position)
	Sfx.play("dash", -2.0)


func end() -> void:
	_ambush = false
	if player != null and is_instance_valid(player.body):
		player.body.modulate.a = 1.0


func hides_player() -> bool:
	return is_active() and _ambush


func modify(key: String, value: float) -> float:
	if key == "move_speed_mult" and is_active():
		return value + float(param("speed", 0.3))
	return value


func modify_outgoing(info: HitInfo, _target: Node) -> void:
	if not _ambush:
		return
	info.damage = int(info.damage * float(param("ambush_mult", 3.0)))
	info.crit = true
	_ambush = false
	player.body.modulate.a = 1.0
	FX.float_text(player.global_position, "AMBUSH", Color("#c4c4dc"))
