class_name StatusEffects
extends Node
## Elemental status effects on an enemy: burn (DoT), frost (slow), shock (stun), hex (vulnerable).

signal tick_damage(amount: int)

const DURATION: Dictionary = {"fire": 3.0, "frost": 2.2, "shock": 0.5, "hex": 3.0}
const TINT: Dictionary = {
	"fire": Color(1.0, 0.6, 0.4), "frost": Color(0.6, 0.8, 1.0),
	"shock": Color(1.0, 1.0, 0.6), "hex": Color(0.85, 0.6, 1.0),
}

var _left: Dictionary = {} # element -> seconds remaining
var _burn_acc: float = 0.0


func apply(element: String) -> void:
	if not DURATION.has(element):
		return
	_left[element] = DURATION[element]


func has(element: String) -> bool:
	return float(_left.get(element, 0.0)) > 0.0


func clear() -> void:
	_left.clear()


func _process(delta: float) -> void:
	for k: String in _left.keys():
		_left[k] = float(_left[k]) - delta
		if float(_left[k]) <= 0.0:
			_left.erase(k)
	if has("fire"):
		_burn_acc += delta
		if _burn_acc >= 0.5:
			_burn_acc = 0.0
			tick_damage.emit(1)
	else:
		_burn_acc = 0.0


func speed_mult() -> float:
	if has("shock"):
		return 0.0
	return 0.5 if has("frost") else 1.0


func damage_taken_mult() -> float:
	return 1.3 if has("hex") else 1.0


func tint() -> Color:
	for k: String in ["shock", "fire", "frost", "hex"]:
		if has(k):
			return TINT[k]
	return Color.WHITE
