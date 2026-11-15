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

## Place the camera at its follow position right away (call after the target has its first transform),
## so the first HUD update never projects through an unplaced camera.
func snap_now() -> void:
	_initialised = false
	_follow(0.0)

func _desired() -> Vector3:
	var basis: Basis = target.global_transform.basis
	return target.global_position + basis.z * distance + Vector3.UP * height

func _follow(delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree() or not is_inside_tree(): return
	var weight: float = 1.0 - exp(-stiffness * delta)
	if not _initialised:
		global_position = _desired()
		_initialised = true
	else:
		global_position = global_position.lerp(_desired(), weight)
	var look_point: Vector3 = target.global_position - target.global_transform.basis.z * 8.0
	var to_look: Vector3 = look_point - global_position
	if to_look.length() > 0.01:
		# Avoid a degenerate up vector when looking straight up or down.
		var up: Vector3 = Vector3.UP if absf(to_look.normalized().dot(Vector3.UP)) < 0.999 else Vector3.FORWARD
		look_at(look_point, up)
	fov = lerpf(fov, base_fov + clampf(speed_hint * 0.12, 0.0, 14.0), weight)

func is_ready_to_project() -> bool:
	return _initialised and is_inside_tree()

func _process(delta: float) -> void:
	_follow(delta)
