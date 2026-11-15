extends CharacterBody3D
## Frontend-owned physics/camera. The engine adapter alone authorizes travel and charges power.
signal attempted_move(proposed: Vector3)
signal impact_reported(impact_speed: float)
var driving: bool = false
var presentation_only: bool = false
var can_drive: bool = true
var visual: Node3D
var wheels: Array[MeshInstance3D] = []
var camera: Camera3D
var yaw: float = 0.0
var pitch: float = 0.35
var camera_distance: float = 11.5
var view_target: Vector3 = Vector3.ZERO
var has_camera_target: bool = false
var drive_speed: float = 6.0
var integrity: float = 100.0
var condition_speed_factor: float = 1.0
var _impact_cooldown: float = 0.0
var _impact_flash: float = 0.0
var _body_material: StandardMaterial3D
var _footprint: CollisionShape3D

## The engine owns integrity; the rover only applies its visual and mobility consequences.
func set_condition(value: float) -> void:
	integrity = clampf(value, 35.0, 100.0)
	condition_speed_factor = lerpf(0.8, 1.0, (integrity - 35.0) / 65.0)

func _report_impact(speed: float) -> void:
	if not driving or speed < 5.0 or _impact_cooldown > 0.0: return
	_impact_cooldown = 1.0
	_impact_flash = 0.35
	impact_reported.emit(speed)

func _ready() -> void:
	floor_snap_length = 1.8
	floor_max_angle = deg_to_rad(52)
	var collision := CollisionShape3D.new()
	_footprint = collision
	var shape := BoxShape3D.new()
	# Include wheels and place the bottom at wheel level, rather than burying them in the floor.
	shape.size = Vector3(2.3, 1.25, 2.6)
	collision.shape = shape
	collision.position.y = 0.635
	add_child(collision)
	visual = Node3D.new()
	add_child(visual)
	var body_material := StandardMaterial3D.new()
	_body_material = body_material
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
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color("8b9296")
	trim.metallic = 0.7
	var solar := BoxMesh.new()
	solar.size = Vector3(1.8, 0.05, 1.4)
	_add_mesh(solar, Vector3(0, 1.13, 0.3), blue)
	# Panel divisions and suspension arms make the vehicle readable at gameplay distance.
	for x in [-0.6, 0.0, 0.6]:
		var divider := BoxMesh.new()
		divider.size = Vector3(0.025, 0.012, 1.4)
		_add_mesh(divider, Vector3(x, 1.165, 0.3), trim)
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
			var axle := CylinderMesh.new()
			axle.top_radius = 0.07
			axle.bottom_radius = 0.07
			axle.height = 0.5
			_add_mesh(axle, Vector3(x * 0.78, 0.5, z), trim).rotation.z = PI / 2.0
			var hub_mesh := CylinderMesh.new()
			hub_mesh.top_radius = 0.18
			hub_mesh.bottom_radius = 0.18
			hub_mesh.height = 0.03
			_add_mesh(hub_mesh, Vector3(x * 1.16, 0.43, z), trim).rotation.z = PI / 2.0
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
	if presentation_only:
		collision_layer = 0
		collision_mask = 0
		set_physics_process(false)
		set_process(false)
		set_process_unhandled_input(false)
		return
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
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	var direction := Vector3.ZERO
	if driving and can_drive:
		var keys := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if keys.length() > 1.0: keys = keys.normalized()
		direction = Vector3(keys.x, 0, keys.y).rotated(Vector3.UP, yaw)
	var target_speed: Vector3 = direction * drive_speed * condition_speed_factor
	velocity.x = move_toward(velocity.x, target_speed.x, 20.0 * delta) if driving else 0.0
	velocity.z = move_toward(velocity.z, target_speed.z, 20.0 * delta) if driving else 0.0
	if not is_on_floor(): velocity.y -= 6.0 * delta
	else: velocity.y = -0.5
	var before: Vector3 = global_position
	var airborne: bool = not is_on_floor()
	var approach_velocity: Vector3 = velocity
	move_and_slide()
	if airborne and is_on_floor(): _report_impact(maxf(0.0, -approach_velocity.y))
	for index in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(index)
		if collision.get_normal().y < 0.6:
			_report_impact(maxf(0.0, -approach_velocity.dot(collision.get_normal())))
	if global_position.distance_to(before) > 0.0001 and driving:
		attempted_move.emit(global_position)
	if direction.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), delta * 8.0)
		_footprint.rotation.y = visual.rotation.y
		var actual_distance: float = Vector2(global_position.x - before.x, global_position.z - before.z).length()
		for wheel in wheels: wheel.rotate_y(actual_distance / 0.42)
	if is_on_floor():
		var local_normal: Vector3 = get_floor_normal().rotated(Vector3.UP, -visual.rotation.y)
		visual.rotation.x = lerpf(visual.rotation.x, clampf(atan2(local_normal.z, local_normal.y), -0.3, 0.3), delta * 6.0)
		visual.rotation.z = lerpf(visual.rotation.z, clampf(-atan2(local_normal.x, local_normal.y), -0.3, 0.3), delta * 6.0)

func _process(delta: float) -> void:
	_impact_flash = maxf(0.0, _impact_flash - delta)
	if _body_material:
		var base := Color("ded9c5").lerp(Color("a98b60"), (100.0 - integrity) / 100.0)
		_body_material.albedo_color = base.lerp(Color("ffb252"), minf(1.0, _impact_flash * 3.0))
	if camera == null or not camera.is_inside_tree(): return
	var target: Vector3 = global_position + Vector3(0, 1.3, 0)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * camera_distance
	var desired: Vector3 = target + offset
	var query := PhysicsRayQueryParameters3D.create(target, desired, 1, [get_rid()])
	var collision: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not collision.is_empty(): desired = collision.position + collision.normal * 0.5
	if not has_camera_target:
		camera.global_position = desired
		has_camera_target = true
	else:
		camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-7.0 * delta))
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
