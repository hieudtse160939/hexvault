extends HeroPassive
## Volt - STATIC: every fifth hit releases a lightning chain from the target.

var _count: int = 0


func modify_outgoing(info: HitInfo, target: Node) -> void:
	if info.element == "shock" and info.source_id == "static":
		return
	_count += 1
	if _count < int(param("every", 5)):
		return
	_count = 0
	var t: HitInfo = HitInfo.make(maxi(1, info.damage / 2), Vector2.ZERO, true, (target as Node2D).global_position)
	t.element = "shock"
	t.status_chance = 0.5
	t.source_id = "static"
	Combat.chain.call_deferred((target as Node2D).global_position, 80.0, int(param("jumps", 2)), t)
