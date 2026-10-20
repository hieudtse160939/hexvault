extends HeroPassive
## Sable - FIRST STRIKE: double damage against enemies at full health.


func modify_outgoing(info: HitInfo, target: Node) -> void:
	var h: Health = target.get("health") as Health
	if h != null and h.hp >= h.max_hp:
		info.damage = int(info.damage * float(param("mult", 2.0)))
