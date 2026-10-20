extends HeroPassive
## Ignis - KINDLING: hits can ignite; burning enemies explode when they die.


func modify_outgoing(info: HitInfo, _target: Node) -> void:
	if info.element == "" and randf() < float(param("ignite", 0.2)):
		info.element = "fire"
		info.status_chance = 1.0


func on_kill(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var st: StatusEffects = enemy.get("status") as StatusEffects
	if st != null and st.has("fire"):
		Combat.explode((enemy as Node2D).global_position, float(param("radius", 26.0)), int(param("damage", 3)), false, true)
