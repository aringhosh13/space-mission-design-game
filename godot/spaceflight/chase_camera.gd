extends Camera3D
## Smoothed third-person chase camera. Frame-rate independent (exponential smoothing).
## Set `target` to the node to follow. FOV widens slightly with speed to sell motion.

@export var distance: float = 17.0
@export var height: float = 5.0
@export var stiffness: float = 5.0
@export var base_fov: float = 66.0
var target: Node3D
var speed_hint: float = 0.0
var _initialised: bool = false

func _ready() -> void:
	near = 0.2
	far = 20000.0
	fov = base_fov

func snap() -> void:
	_initialised = false

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree(): return
	var basis: Basis = target.global_transform.basis
	var desired: Vector3 = target.global_position + basis.z * distance + Vector3.UP * height
	var weight: float = 1.0 - exp(-stiffness * delta)
	if not _initialised:
		global_position = desired
		_initialised = true
	else:
		global_position = global_position.lerp(desired, weight)
	var look_point: Vector3 = target.global_position - basis.z * 8.0
	if global_position.distance_to(look_point) > 0.01:
		look_at(look_point, Vector3.UP)
	fov = lerpf(fov, base_fov + clampf(speed_hint * 0.12, 0.0, 14.0), weight)
