extends Node3D
## MOLA-derived Jezero-region broad relief with fictional delta detail and compressed gameplay scales.
## Same API as Codex's scripts/lunar_world.gd so one surface controller can drive either world:
##   build(sites), terrain_height(x, z), update_mission(state), pulse(origin)
## Look inspired by public descriptions of Mars (reddish rusted dust, thin dusty sky, a smaller Sun,
## two small moons). Landforms near each signal hint at what it might be; they reveal no hidden truth.
const Contract = preload("res://shared/mission_contract.gd")
const Destinations = preload("res://simulation/destinations.gd")
const Beacons = preload("res://spaceflight/checkpoint_beacons.gd")
const ELEVATION = preload("res://data/terrain/mola_jezero.tres")
var elevation_origin: float = ELEVATION.sample_uv(0.5, 0.5)
## Same optional hooks as the lunar world: configure_extent(limit) before build(),
## update_checkpoints(list) and set_weather(weather) afterwards.

var marker_nodes: Dictionary = {}
var station: Node3D
var scanner_ring: MeshInstance3D
var scan_age: float = 2.0
var scan_origin: Vector3 = Vector3.ZERO
var craters: Array = [Vector3(52, 9, -40), Vector3(-58, 12, -30), Vector3(-20, 7, 60), Vector3(150, 14, -120), Vector3(-160, 16, -40), Vector3(90, 11, 160)]
var extent: float = 110.0
var environment: Environment
var sun: DirectionalLight3D
var dust: CPUParticles3D
var beacons: Node3D
var weather_phase: String = "clear"
var _route_points: Array[Vector3] = []

## Called before build(): the terrain covers the playable limit plus a horizon margin.
func configure_extent(limit: float) -> void:
	extent = maxf(110.0, limit + 30.0)

func terrain_height(x: float, z: float) -> float:
	# Broad delta fan sloping gently toward the north-west, wind-aligned dunes and a few small craters.
	var measured: float = ELEVATION.sample_uv(x / 960.0 + 0.5, z / 960.0 + 0.5)
	var height: float = (measured - elevation_origin) * 0.002
	height += 0.012 * (x - z) + sin(x * 0.028 + 0.6) * 1.1 + cos(z * 0.033) * 0.9
	var along: float = x * 0.82 + z * 0.57
	var dune: float = pow(abs(sin(along * 0.16 + sin(z * 0.05) * 1.5)), 3.0)
	height += dune * 0.9 * smoothstep(8.0, 30.0, Vector2(x, z).length())
	for crater: Vector3 in craters:
		var d: float = Vector2(x - crater.x, z - crater.z).length() / crater.y
		if d < 1.6:
			height += -2.2 * exp(-d * d * 2.8) + 0.9 * exp(-pow((d - 1.0) * 4.0, 2.0))
	return height

func _material(color: Color, roughness: float = 0.95, emission: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	if emission > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = emission
	return result

func _mesh(parent: Node, shape: Mesh, location: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material
	instance.position = location
	parent.add_child(instance)
	return instance

func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.46, 0.33, 0.25)
	sky_material.sky_horizon_color = Color(0.82, 0.62, 0.45)
	sky_material.ground_horizon_color = Color(0.66, 0.42, 0.28)
	sky_material.ground_bottom_color = Color(0.32, 0.18, 0.11)
	sky_material.sun_angle_max = 6.0
	sky_material.sun_curve = 0.25
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	environment = env
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.6, 0.5)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.55, 0.45)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.35
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 0.82   # dimmer than the lunar scene: Mars is ~1.5 AU from the Sun
	sun.rotation_degrees = Vector3(-34, 128, 0)
	sun.shadow_enabled = true
	add_child(sun)

func _terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var resolution: int = clampi(int(extent / 2.3), 96, 150)
	var step_size: float = extent * 2.0 / resolution
	for xi in range(resolution):
		for zi in range(resolution):
			var x: float = -extent + xi * step_size
			var z: float = -extent + zi * step_size
			var points: Array[Vector3] = [Vector3(x, terrain_height(x, z), z),
				Vector3(x + step_size, terrain_height(x + step_size, z), z),
				Vector3(x, terrain_height(x, z + step_size), z + step_size),
				Vector3(x + step_size, terrain_height(x + step_size, z + step_size), z + step_size)]
			for index in [0, 1, 2, 1, 3, 2]:
				var p: Vector3 = points[index]
				var band: float = 0.5 + 0.5 * sin(p.x * 0.31 + p.z * 0.17 + sin(p.z * 0.4))
				var dust := Color(0.52, 0.30, 0.20).lerp(Color(0.63, 0.40, 0.27), band)
				# Dark basaltic sand collects in dune troughs.
				var trough: float = clampf(1.0 - (p.y - (0.012 * (p.x - p.z))) * 0.6, 0.0, 1.0) * 0.35
				surface.set_color(dust.lerp(Color(0.36, 0.22, 0.17), trough))
				surface.add_vertex(p)
	surface.generate_normals()
	var ground_material := _material(Color.WHITE)
	ground_material.vertex_color_use_as_albedo = true
	var terrain := _mesh(self, surface.commit(), Vector3.ZERO, ground_material)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = terrain.mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)

func _rocks(rng: RandomNumberGenerator) -> void:
	var materials: Array[StandardMaterial3D] = [_material(Color("5a3326")), _material(Color("7a4630")), _material(Color("3d2b27"))]
	var span: float = extent - 14.0
	for i in range(mini(900, int(260.0 * pow(span / 96.0, 2.0)))):
		var x: float = rng.randf_range(-span, span)
		var z: float = rng.randf_range(-span, span)
		if Vector2(x, z).length() < 8.0 or Vector2(x, z + 11.0).length() < 7.0 or _near_route(x, z): continue
		var shape: Mesh
		if i % 3 == 0:
			var prism := PrismMesh.new()
			prism.size = Vector3(1, 1, 1)
			prism.left_to_right = rng.randf()
			shape = prism
		else:
			var box := BoxMesh.new()
			box.size = Vector3(1, 1, 1)
			shape = box
		var size: float = rng.randf_range(0.3, 1.4) * (2.2 if i % 23 == 0 else 1.0)
		var rock := _mesh(self, shape, Vector3(x, terrain_height(x, z) + size * 0.25, z), materials[i % materials.size()])
		rock.scale = Vector3(size * rng.randf_range(0.8, 1.8), size * rng.randf_range(0.5, 1.1), size * rng.randf_range(0.8, 1.6))
		rock.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		if i % 6 == 0:
			var rock_body := StaticBody3D.new()
			var rock_collision := CollisionShape3D.new()
			rock_collision.shape = shape.create_convex_shape()
			rock_body.add_child(rock_collision)
			rock.add_child(rock_body)

## Layered mesas on the horizon and landforms near each signal template.
func _landforms(rng: RandomNumberGenerator) -> void:
	var layers: Array[Color] = [Color("8a4f33"), Color("a8653f"), Color("c08156"), Color("93583a"), Color("b47450")]
	for i in range(22):
		var angle: float = float(i) / 22.0 * TAU + rng.randf_range(-0.08, 0.08)
		var radius: float = rng.randf_range(extent + 2.0, extent + 16.0)
		var centre := Vector3(sin(angle) * radius, -3.0, cos(angle) * radius)
		var width: float = rng.randf_range(14.0, 26.0)
		var y: float = centre.y
		for layer in range(rng.randi_range(3, 6)):
			var slab := CylinderMesh.new()
			slab.top_radius = width * (1.0 - layer * 0.12)
			slab.bottom_radius = width * (1.0 - layer * 0.12) + 1.5
			slab.height = rng.randf_range(2.5, 4.5)
			slab.radial_segments = 7
			_mesh(self, slab, Vector3(centre.x, y + slab.height * 0.5, centre.z), _material(layers[(i + layer) % layers.size()]))
			y += slab.height
	var rules: Dictionary = Destinations.surface_rules("mars")
	var at_kind: Dictionary = {}
	for template in rules.sites: at_kind[template.kind] = template.position
	var ice: Vector3 = at_kind.get("ice", Vector3(-44, 0, 26))
	var clay: Vector3 = at_kind.get("minerals", Vector3(41, 0, 21))
	var delta: Vector3 = at_kind.get("geology", Vector3(6, 0, -52))
	# Near the ice signal: a scarp with a pale exposed band (fictional placement).
	var scarp := BoxMesh.new()
	scarp.size = Vector3(26, 6, 3)
	var scarp_at := ice + Vector3(-9, 0, 9)
	var wall := _mesh(self, scarp, Vector3(scarp_at.x, terrain_height(scarp_at.x, scarp_at.z) + 1.5, scarp_at.z), _material(Color("7b4a33")))
	wall.rotation.y = 0.5
	var ice_band := BoxMesh.new()
	ice_band.size = Vector3(22, 1.2, 0.3)
	var band := _mesh(wall, ice_band, Vector3(0, 0.4, -1.6), _material(Color("cfe3ee"), 0.35, 0.15))
	band.rotation.y = 0.0
	# Near the clay signal: pale terraces.
	for step in range(4):
		var terrace := CylinderMesh.new()
		terrace.top_radius = 9.0 - step * 1.8
		terrace.bottom_radius = 9.6 - step * 1.8
		terrace.height = 0.7
		terrace.radial_segments = 9
		var terrace_at := clay + Vector3(10, 0, 6)
		_mesh(self, terrace, Vector3(terrace_at.x, terrain_height(terrace_at.x, terrace_at.z) - 0.3 + step * 0.7, terrace_at.z), _material(Color(0.78, 0.66, 0.52).lerp(Color(0.66, 0.5, 0.38), step * 0.25)))
	# Near the delta signal: thin stacked sediment layers.
	for layer in range(7):
		var sheet := BoxMesh.new()
		sheet.size = Vector3(18 - layer * 1.6, 0.55, 8 - layer * 0.5)
		var sheet_at := delta + Vector3(4, 0, -10)
		_mesh(self, sheet, Vector3(sheet_at.x, terrain_height(sheet_at.x, sheet_at.z) + 0.3 + layer * 0.55, sheet_at.z), _material(layers[layer % layers.size()]))
	# Phobos and Deimos, Mars's two small moons, high in the sky (positions illustrative).
	var moon_material := _material(Color("8d8379"))
	for spec in [[Vector3(-120, 140, -260), 6.0], [Vector3(200, 180, -150), 2.5]]:
		var shape := SphereMesh.new()
		shape.radius = spec[1]
		shape.height = spec[1] * 1.6
		shape.radial_segments = 8
		shape.rings = 5
		_mesh(self, shape, spec[0], moon_material)

## Rock-free corridors along the main routes, so every site and the shelter stay reachable by driving.
func _routes() -> void:
	var rules: Dictionary = Destinations.surface_rules("mars")
	var pad: Vector3 = Destinations.get_def("mars").pad
	_route_points = [Vector3.ZERO, pad]
	for template in rules.sites: _route_points.append(template.position)
	if rules.has("shelter"): _route_points.append(rules.shelter.position)

func _near_route(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	for i in range(_route_points.size()):
		for j in range(i + 1, _route_points.size()):
			var a := Vector2(_route_points[i].x, _route_points[i].z)
			var b := Vector2(_route_points[j].x, _route_points[j].z)
			var t: float = clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.001), 0.0, 1.0)
			if p.distance_to(a + (b - a) * t) < 9.0: return true
	return false

func _shelter_and_pad() -> void:
	var rules: Dictionary = Destinations.surface_rules("mars")
	if rules.has("shelter"):
		var at: Vector3 = rules.shelter.position
		var shelter := Node3D.new()
		shelter.position = Vector3(at.x, terrain_height(at.x, at.z), at.z)
		add_child(shelter)
		# Open canopy on pillars, so the rover and camera can see under it (presentation only).
		var roof := CylinderMesh.new()
		roof.top_radius = 4.0
		roof.bottom_radius = 7.5
		roof.height = 1.2
		roof.radial_segments = 16
		_mesh(shelter, roof, Vector3(0, 6.2, 0), _material(Color("e9e2d4"), 0.6))
		for k in range(6):
			var angle: float = TAU * k / 6.0
			var pillar := CylinderMesh.new()
			pillar.top_radius = 0.25
			pillar.bottom_radius = 0.3
			pillar.height = 6.0
			_mesh(shelter, pillar, Vector3(cos(angle) * 6.6, 3.0, sin(angle) * 6.6), _material(Color("9aa3ad"), 0.5))
		var floor_pad := CylinderMesh.new()
		floor_pad.top_radius = 7.0
		floor_pad.bottom_radius = 7.2
		floor_pad.height = 0.2
		_mesh(shelter, floor_pad, Vector3(0, 0.05, 0), _material(Color("6d625a")))
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0, 5.2, 0)
		lamp.light_color = Color("ffd9a0")
		lamp.light_energy = 1.6
		lamp.omni_range = 18.0
		shelter.add_child(lamp)
		var sign_label := Label3D.new()
		sign_label.text = "DUST SHELTER\nrecharge · repair"
		sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign_label.position.y = 7.5
		sign_label.font_size = 34
		sign_label.outline_size = 8
		shelter.add_child(sign_label)
	var pad: Vector3 = Destinations.get_def("mars").pad
	var ring := TorusMesh.new()
	ring.inner_radius = 6.0
	ring.outer_radius = 6.5
	ring.rings = 48
	_mesh(self, ring, Vector3(pad.x, terrain_height(pad.x, pad.z) + 0.1, pad.z), _material(Color("f3c582"), 0.8, 0.5))

func _dust() -> void:
	dust = CPUParticles3D.new()
	dust.amount = 900
	dust.lifetime = 4.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(40, 10, 40)
	dust.direction = Vector3(1, 0.05, 0.3)
	dust.spread = 25.0
	dust.initial_velocity_min = 6.0
	dust.initial_velocity_max = 12.0
	dust.gravity = Vector3.ZERO
	dust.scale_amount_min = 0.05
	dust.scale_amount_max = 0.14
	var mote := SphereMesh.new()
	mote.radius = 0.5
	mote.height = 1.0
	mote.radial_segments = 6
	mote.rings = 3
	var mote_material := StandardMaterial3D.new()
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_material.albedo_color = Color(0.78, 0.55, 0.38, 0.35)
	mote.material = mote_material
	dust.mesh = mote
	dust.emitting = false
	add_child(dust)

## Presentation of the simulation's weather: haze, dimmer sun and blowing dust. No physics effect.
func set_weather(weather: Dictionary) -> void:
	weather_phase = str(weather.get("phase", "clear"))
	if environment == null: return
	match weather_phase:
		"storm":
			environment.fog_density = 0.028
			environment.fog_light_color = Color(0.62, 0.42, 0.3)
			sun.light_energy = 0.35
			environment.ambient_light_energy = 0.26
		"warning":
			environment.fog_density = 0.009
			environment.fog_light_color = Color(0.68, 0.5, 0.38)
			sun.light_energy = 0.65
			environment.ambient_light_energy = 0.3
		_:
			environment.fog_density = 0.0045
			environment.fog_light_color = Color(0.7, 0.55, 0.45)
			sun.light_energy = 0.82
			environment.ambient_light_energy = 0.32
	if dust:
		dust.emitting = weather_phase != "clear"
		(dust.mesh.material as StandardMaterial3D).albedo_color.a = 0.38 if weather_phase == "storm" else 0.12

func update_checkpoints(checkpoints: Array) -> void:
	if beacons: beacons.update_checkpoints(checkpoints)

func build(sites: Array) -> void:
	_routes()
	_environment()
	_terrain()
	_shelter_and_pad()
	_dust()
	beacons = Beacons.new()
	beacons.height_at = terrain_height
	add_child(beacons)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977
	_rocks(rng)
	_landforms(rng)
	for site in sites:
		var node := Node3D.new()
		node.position = site.position
		node.position.y = terrain_height(node.position.x, node.position.z)
		var ring := TorusMesh.new()
		ring.inner_radius = 1.3
		ring.outer_radius = 1.45
		var marker := _mesh(node, ring, Vector3(0, 0.25, 0), _material(Color("f3c582"), 0.9, 0.6))
		var label := Label3D.new()
		label.position.y = 3.5
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 40
		label.pixel_size = 0.016
		label.outline_size = 10
		node.add_child(label)
		add_child(node)
		marker_nodes[site.id] = {"node": node, "ring": marker, "label": label}
	station = Node3D.new()
	station.visible = false
	var module := BoxMesh.new()
	module.size = Vector3(2.5, 1.5, 2.2)
	_mesh(station, module, Vector3(0, 0.85, 0), _material(Color("e4dccd")))
	var panel := BoxMesh.new()
	panel.size = Vector3(5.0, 0.1, 2.0)
	_mesh(station, panel, Vector3(0, 1.9, 0), _material(Color("284e89")))
	var station_name := Label3D.new()
	station_name.text = "RESEARCH STATION"
	station_name.position.y = 3.5
	station_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station_name.font_size = 32
	station.add_child(station_name)
	add_child(station)
	var scan_mesh := TorusMesh.new()
	scan_mesh.inner_radius = 0.95
	scan_mesh.outer_radius = 1.0
	var scan_material := _material(Color("8ce9d2"), 0.9, 1.0)
	scan_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	scanner_ring = _mesh(self, scan_mesh, Vector3.ZERO, scan_material)
	scanner_ring.visible = false

func update_mission(state: Dictionary) -> void:
	for site in state.sites:
		if not marker_nodes.has(site.id): continue
		var marker: Dictionary = marker_nodes[site.id]
		var color: Color = Contract.FINDING_COLORS[site.finding]
		marker.ring.material_override.albedo_color = color
		marker.ring.material_override.emission = color
		marker.label.modulate = color
		marker.label.text = str(site.name) + "\n" + str(site.confidence) + "% · " + str(Contract.FINDING_LABELS[site.finding])
	station.visible = state.outpost_deployed and state.outpost_position != null
	if station.visible:
		station.position = state.outpost_position
		station.position.y = terrain_height(station.position.x, station.position.z)

func pulse(origin: Vector3) -> void:
	scan_origin = origin
	scan_age = 0.0

func _process(delta: float) -> void:
	scan_age += delta
	if dust and dust.emitting:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera: dust.global_position = camera.global_position + Vector3(-12, -2, 0)
	if scanner_ring == null: return
	scanner_ring.visible = scan_age < 1.6
	if scanner_ring.visible:
		var radius: float = 1.0 + scan_age * 11.0
		scanner_ring.scale = Vector3(radius, 1, radius)
		scanner_ring.position = Vector3(scan_origin.x, terrain_height(scan_origin.x, scan_origin.z) + 0.22, scan_origin.z)
		scanner_ring.material_override.albedo_color.a = 1.0 - scan_age / 1.6
