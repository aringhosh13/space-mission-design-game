extends Node3D
## Procedural spaceship visual (original geometry generated in code; no external assets).
## Faces -Z. Call set_engine(throttle, braking) every frame to drive the engine effects.
## Set landing_gear(true) on the pad and false in flight.

var flame: MeshInstance3D
var flame_material: StandardMaterial3D
var retro_flares: Array[MeshInstance3D] = []
var engine_light: OmniLight3D
var exhaust: CPUParticles3D
var legs: Node3D
var descent_flames: Array[MeshInstance3D] = []
var _descent: float = 0.0
var _flicker: float = 0.0
var _throttle: float = 0.0
var _braking: float = 0.0

func _ready() -> void:
	var hull := _material(Color("d9dde2"), 0.55, 0.35)
	var dark := _material(Color("2a3240"), 0.6, 0.5)
	var accent := _material(Color("e08a3c"), 0.2, 0.6)
	var glass := _material(Color("5fb6e8"), 0.1, 0.05)
	glass.emission_enabled = true
	glass.emission = Color("3a8fc4")
	glass.emission_energy_multiplier = 0.6

	var fuselage := CapsuleMesh.new()
	fuselage.radius = 1.05
	fuselage.height = 7.2
	_mesh(fuselage, Vector3.ZERO, hull, Vector3(PI / 2.0, 0, 0))
	var cockpit := SphereMesh.new()
	cockpit.radius = 0.8
	cockpit.height = 1.1
	_mesh(cockpit, Vector3(0, 0.65, -1.9), glass)
	var stripe := CylinderMesh.new()
	stripe.top_radius = 1.08
	stripe.bottom_radius = 1.08
	stripe.height = 0.35
	_mesh(stripe, Vector3(0, 0, 0.6), accent, Vector3(PI / 2.0, 0, 0))
	# Swept wings and fins.
	for side in [-1.0, 1.0]:
		var wing := BoxMesh.new()
		wing.size = Vector3(3.4, 0.16, 2.2)
		var w := _mesh(wing, Vector3(side * 2.3, -0.25, 1.2), hull)
		w.rotation = Vector3(0, side * 0.35, side * -0.08)
		var tip := BoxMesh.new()
		tip.size = Vector3(0.22, 0.9, 1.4)
		_mesh(tip, Vector3(side * 3.9, 0.1, 1.9), accent)
		var pod := CylinderMesh.new()
		pod.top_radius = 0.38
		pod.bottom_radius = 0.48
		pod.height = 2.4
		_mesh(pod, Vector3(side * 1.55, -0.55, 2.0), dark, Vector3(PI / 2.0, 0, 0))
	var fin := BoxMesh.new()
	fin.size = Vector3(0.16, 1.6, 1.8)
	_mesh(fin, Vector3(0, 1.3, 2.4), hull).rotation.x = -0.3
	# Main engine bell.
	var bell := CylinderMesh.new()
	bell.top_radius = 0.55
	bell.bottom_radius = 0.95
	bell.height = 1.2
	_mesh(bell, Vector3(0, 0, 4.0), dark, Vector3(PI / 2.0, 0, 0))

	# Engine flame: additive, unshaded cone scaled by throttle.
	flame_material = StandardMaterial3D.new()
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_material.albedo_color = Color(0.35, 0.6, 1.0, 0.55)
	flame_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.6
	cone.height = 1.0
	flame = MeshInstance3D.new()
	flame.mesh = cone
	flame.material_override = flame_material
	flame.rotation.x = PI / 2.0
	add_child(flame)

	# Retro thrusters near the nose glow when braking.
	for side in [-1.0, 1.0]:
		var flare_mesh := SphereMesh.new()
		flare_mesh.radius = 0.28
		flare_mesh.height = 0.56
		var flare := MeshInstance3D.new()
		flare.mesh = flare_mesh
		var flare_material := flame_material.duplicate() as StandardMaterial3D
		flare_material.albedo_color = Color(1.0, 0.6, 0.3, 0.9)
		flare.material_override = flare_material
		flare.position = Vector3(side * 0.95, 0.0, -3.0)
		flare.visible = false
		add_child(flare)
		retro_flares.append(flare)

	engine_light = OmniLight3D.new()
	engine_light.position = Vector3(0, 0, 5.2)
	engine_light.light_color = Color("8cc8ff")
	engine_light.omni_range = 14.0
	engine_light.light_energy = 0.0
	add_child(engine_light)

	exhaust = CPUParticles3D.new()
	exhaust.position = Vector3(0, 0, 4.7)
	exhaust.amount = 60
	exhaust.lifetime = 0.45
	exhaust.local_coords = false
	exhaust.direction = Vector3(0, 0, 1)
	exhaust.spread = 9.0
	exhaust.initial_velocity_min = 14.0
	exhaust.initial_velocity_max = 22.0
	exhaust.gravity = Vector3.ZERO
	exhaust.scale_amount_min = 0.12
	exhaust.scale_amount_max = 0.3
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 6
	puff.rings = 3
	var puff_material := flame_material.duplicate() as StandardMaterial3D
	puff_material.albedo_color = Color(0.45, 0.65, 1.0, 0.18)
	puff.material = puff_material
	exhaust.mesh = puff
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	exhaust.color_ramp = fade
	exhaust.emitting = false
	add_child(exhaust)

	# Downward descent thrusters (final descent), under the pods and the nose.
	for at in [Vector3(-1.55, -1.0, 2.0), Vector3(1.55, -1.0, 2.0), Vector3(0, -1.0, -2.4)]:
		var plume := CylinderMesh.new()
		plume.top_radius = 0.45
		plume.bottom_radius = 0.0
		plume.height = 1.0
		var down_flame := MeshInstance3D.new()
		down_flame.mesh = plume
		down_flame.material_override = flame_material
		down_flame.position = at
		down_flame.visible = false
		add_child(down_flame)
		descent_flames.append(down_flame)
	# Landing legs, shown on the pad.
	legs = Node3D.new()
	add_child(legs)
	for corner in [Vector3(-1.5, 0, -1.6), Vector3(1.5, 0, -1.6), Vector3(-1.7, 0, 2.4), Vector3(1.7, 0, 2.4)]:
		var strut := CylinderMesh.new()
		strut.top_radius = 0.09
		strut.bottom_radius = 0.09
		strut.height = 2.0
		var leg := MeshInstance3D.new()
		leg.mesh = strut
		leg.material_override = dark
		leg.position = corner + Vector3(0, -1.6, 0)
		leg.rotation.z = -signf(corner.x) * 0.35
		legs.add_child(leg)
		var foot := CylinderMesh.new()
		foot.top_radius = 0.35
		foot.bottom_radius = 0.42
		foot.height = 0.12
		var pad := MeshInstance3D.new()
		pad.mesh = foot
		pad.material_override = dark
		pad.position = corner + Vector3(signf(corner.x) * 0.33, -2.55, 0)
		legs.add_child(pad)
	legs.visible = false
	set_engine(0.0, 0.0)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

func _mesh(shape: Mesh, at: Vector3, material: Material, rotation_euler: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material
	instance.position = at
	instance.rotation = rotation_euler
	add_child(instance)
	return instance

## Throttle and braking are the values the simulation actually produced (0..1).
func set_engine(throttle: float, braking: float) -> void:
	_throttle = clampf(throttle, 0.0, 1.0)
	_braking = clampf(braking, 0.0, 1.0)
	if flame == null: return
	flame.visible = _throttle > 0.01
	exhaust.emitting = _throttle > 0.05
	for flare in retro_flares: flare.visible = _braking > 0.01
	_apply_flicker()

## Final-descent thrust 0..1: downward plumes and engine light.
func set_descent(throttle: float) -> void:
	_descent = clampf(throttle, 0.0, 1.0)
	for plume in descent_flames:
		plume.visible = _descent > 0.02
		var length: float = 0.6 + 3.2 * _descent
		plume.scale = Vector3(0.8 + 0.5 * _descent, length, 0.8 + 0.5 * _descent)
		plume.position.y = -1.0 - length * 0.5
	if engine_light: engine_light.light_energy = maxf(engine_light.light_energy, 3.0 * _descent)

func landing_gear(deployed: bool) -> void:
	if legs: legs.visible = deployed

func _apply_flicker() -> void:
	var wobble: float = 1.0 + 0.12 * sin(_flicker * 47.0) + 0.06 * sin(_flicker * 83.0)
	var length: float = (0.8 + 3.6 * _throttle) * wobble
	var width: float = 0.7 + 0.4 * _throttle
	flame.scale = Vector3(width, length, width)
	flame.position = Vector3(0, 0, 4.6 + length * 0.5)
	engine_light.light_energy = 3.5 * _throttle * wobble + 1.2 * _braking
	for flare in retro_flares: flare.scale = Vector3.ONE * (0.8 + 0.6 * _braking * wobble)

func _process(delta: float) -> void:
	_flicker += delta
	if flame and (_throttle > 0.01 or _braking > 0.01): _apply_flicker()
