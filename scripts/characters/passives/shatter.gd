extends HeroPassive
## Rime - SHATTER: frozen enemies take critical hits far more often.


func modify_outgoing(info: HitInfo, target: Node) -> void:
	if info.crit:
		return
	var st: StatusEffects = target.get("status") as StatusEffects
	if st != null and st.has("frost") and randf() < float(param("chance", 0.35)):
		info.crit = true
		info.damage = int(ceil(info.damage * float(param("crit_mult", 1.75))))
