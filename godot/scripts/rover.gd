extends CharacterBody3D
## Frontend-owned physics/camera. The engine adapter alone authorizes travel and charges power.
signal attempted_move(proposed: Vector3)
var driving: bool = false
var can_drive: bool = true
var visual: Node3D
var wheels: Array[MeshInstance3D] = []
var camera: Camera3D
var yaw: float = 0.0
var pitch: float = 0.48
var camera_distance: float = 10.0
var view_target: Vector3 = Vector3.ZERO
var has_camera_target: bool = false
var drive_speed: float = 6.0

func _ready() -> void:
	floor_snap_length = 1.8
	floor_max_angle = deg_to_rad(52)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.7, 0.7, 2.4)
	collision.shape = shape
	collision.position.y = 0.65
	add_child(collision)
	visual = Node3D.new()
	add_child(visual)
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("ded9c5")
	body_material.metallic = 0.3
	var chassis := BoxMesh.new()
	chassis.size = Vector3(1.6, 0.55, 2.4)
	_add_mesh(chassis, Vector3(0, 0.8, 0), body_material)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("202737")
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color("244d83")
	blue.metallic = 0.4
	var solar := BoxMesh.new()
	solar.size = Vector3(1.8, 0.05, 1.4)
	_add_mesh(solar, Vector3(0, 1.13, 0.3), blue)
	for x in [-1.0, 1.0]:
		for z in [-0.85, 0.0, 0.85]:
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.42
			wheel_mesh.bottom_radius = 0.42
			wheel_mesh.height = 0.28
			wheel_mesh.radial_segments = 12
			var wheel: MeshInstance3D = _add_mesh(wheel_mesh, Vector3(x, 0.43, z), dark)
			wheel.rotation.z = PI / 2.0
			wheels.append(wheel)
	var mast := CylinderMesh.new()
	mast.top_radius = 0.05
	mast.bottom_radius = 0.05
	mast.height = 1.6
	_add_mesh(mast, Vector3(0, 1.7, -0.8), body_material)
	var camera_head := BoxMesh.new()
	camera_head.size = Vector3(0.55, 0.24, 0.3)
	_add_mesh(camera_head, Vector3(0, 2.5, -0.8), dark)
	var headlight := SpotLight3D.new()
	headlight.position = Vector3(0, 1.15, -1.15)
	headlight.light_color = Color("bedcf5")
	headlight.light_energy = 2.2
	headlight.spot_range = 24.0
	headlight.spot_angle = 38.0
	visual.add_child(headlight)
	camera = Camera3D.new()
	camera.far = 500.0
	camera.fov = 68.0
	camera.current = true
	get_parent().add_child.call_deferred(camera)

func _add_mesh(shape: Mesh, location: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material
	instance.position = location
	visual.add_child(instance)
	return instance

func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	if driving and can_drive:
		var keys := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if keys.length() > 1.0: keys = keys.normalized()
		direction = Vector3(keys.x, 0, keys.y).rotated(Vector3.UP, yaw)
	var target_speed: Vector3 = direction * drive_speed
	velocity.x = move_toward(velocity.x, target_speed.x, 20.0 * delta) if driving else 0.0
	velocity.z = move_toward(velocity.z, target_speed.z, 20.0 * delta) if driving else 0.0
	if not is_on_floor(): velocity.y -= 6.0 * delta
	else: velocity.y = -0.5
	var before: Vector3 = global_position
	move_and_slide()
	if global_position.distance_to(before) > 0.0001 and driving:
		attempted_move.emit(global_position)
	if direction.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), delta * 8.0)
		for wheel in wheels: wheel.rotate_y(direction.length() * drive_speed * delta)

func _process(delta: float) -> void:
	if camera == null or not camera.is_inside_tree(): return
	var target: Vector3 = global_position + Vector3(0, 1.3, 0)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * camera_distance
	if not has_camera_target:
		camera.global_position = target + offset
		has_camera_target = true
	else:
		camera.global_position = camera.global_position.lerp(target + offset, 1.0 - exp(-7.0 * delta))
	camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if not driving: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: camera_distance = maxf(6.0, camera_distance - 1.0)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera_distance = minf(18.0, camera_distance + 1.0)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.004
		pitch = clampf(pitch + event.relative.y * 0.003, 0.15, 1.05)
