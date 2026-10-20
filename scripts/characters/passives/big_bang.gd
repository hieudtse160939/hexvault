extends HeroPassive
## Brixa - BIG BANG: every explosion you cause is larger.


func modify(key: String, value: float) -> float:
	if key == "blast_mult":
		return value + float(param("radius", 0.35))
	return value
