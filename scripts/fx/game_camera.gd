class_name GameCamera
extends Camera2D
## Follows a target with aim look-ahead and decaying trauma-based shake.

var target: Node2D = null
var look_ahead: float = 28.0
var _trauma: float = 0.0
var _noise_t: float = 0.0


func _ready() -> void:
	# Keep following while the tree is paused (menus open on top of the world),
	# otherwise smoothing freezes half-way and the view starts off-centre.
	process_mode = Node.PROCESS_MODE_ALWAYS
	position_smoothing_enabled = true
	position_smoothing_speed = 9.0
	snap_to_target.call_deferred()
	FX.camera = self
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS


func _exit_tree() -> void:
	if FX.camera == self:
		FX.camera = null


func add_shake(amount: float) -> void:
	_trauma = minf(_trauma + amount * 0.12, 1.0)


func snap_to_target() -> void:
	if target != null:
		global_position = target.global_position
		reset_smoothing()


func _physics_process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var aim: Vector2 = Vector2.ZERO
		if target.has_method("aim_direction"):
			aim = target.call("aim_direction")
		global_position = target.global_position + aim * look_ahead * 0.5
	_noise_t += delta * 40.0
	if _trauma > 0.0:
		_trauma = maxf(_trauma - delta * 1.6, 0.0)
		var s: float = _trauma * _trauma * 6.0
		offset = Vector2(sin(_noise_t * 1.3) * s, cos(_noise_t * 1.7) * s).round()
	else:
		offset = Vector2.ZERO
