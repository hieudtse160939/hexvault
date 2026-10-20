extends HeroPassive
## Nyx - HEXBLOOD: hits on hexed enemies deal extra damage.


func modify_outgoing(info: HitInfo, target: Node) -> void:
	var st: StatusEffects = target.get("status") as StatusEffects
	if st != null and st.has("hex"):
		info.damage = int(ceil(info.damage * (1.0 + float(param("bonus", 0.3)))))
