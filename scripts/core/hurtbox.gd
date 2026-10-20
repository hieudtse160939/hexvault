class_name Hurtbox
extends Area2D
## Hittable region. Forwards hits to `receiver.receive_hit(info) -> bool`.

const LAYER_PLAYER: int = 1 << 3  # layer 4
const LAYER_ENEMY: int = 1 << 4   # layer 5

var receiver: Node = null


static func create(owner_node: Node, radius: float, is_player: bool) -> Hurtbox:
	var h: Hurtbox = Hurtbox.new()
	h.receiver = owner_node
	h.collision_layer = LAYER_PLAYER if is_player else LAYER_ENEMY
	h.collision_mask = 0
	h.monitoring = false
	h.monitorable = true
	var cs: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	cs.shape = shape
	h.add_child(cs)
	return h


func hit(info: HitInfo) -> bool:
	if receiver != null and is_instance_valid(receiver) and receiver.has_method("receive_hit"):
		return bool(receiver.call("receive_hit", info))
	return false
