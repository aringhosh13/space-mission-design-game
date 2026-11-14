extends Node3D
## Original fictional lunar landscape. Rendering never determines hidden resource outcomes.
const Contract = preload("res://shared/mission_contract.gd")
const Landmarks = preload("res://scripts/moon_landmarks.gd")
const SURFACE_SHADER = preload("res://shaders/moon_surface.gdshader")
const EARTH_SHADER = preload("res://shaders/earth.gdshader")
var marker_nodes: Dictionary = {}
var station: Node3D
var landmarks: Node3D
var scanner_ring: MeshInstance3D
var scan_age: float = 2.0
var scan_origin: Vector3 = Vector3.ZERO
var terrain_noise := FastNoiseLite.new()
var craters: Array[Vector3] = [Vector3(-35, 13, -36), Vector3(32, 15, 22), Vector3(-54, 16, 36), Vector3(50, 10, -52), Vector3(5, 9, -59)]
var track_mesh: MultiMeshInstance3D
var track_cursor: int = 0
var track_count: int = 0
var last_track: Vector3 = Vector3.INF

func _init() -> void:
	terrain_noise.seed = 7163
	terrain_noise.frequency = 0.075
	terrain_noise.fractal_octaves = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 814
	for i in range(15):
		var point := Vector3(rng.randf_range(-90, 90), rng.randf_range(2.5, 5.5), rng.randf_range(-90, 90))
		if Vector2(point.x, point.z).length() > 16.0: craters.append(point)

func terrain_height(x: float, z: float) -> float:
	var height: float = sin(x * 0.035) * 1.9 + cos(z * 0.045) * 1.3
	# Broad hills remain driveable, with finer surface undulation above them.
	height += terrain_noise.get_noise_2d(x, z) * 0.85
	for crater in craters:
		var d: float = Vector2(x - crater.x, z - crater.z).length() / crater.y
		if d < 1.65:
			var depth: float = minf(crater.y * 0.25, 4.0)
			height += -depth * exp(-d * d * 2.7) + depth * 0.35 * exp(-pow((d - 1.0) * 4.0, 2.0))
	# Flatten the landing apron smoothly, preserving a continuous join to the terrain.
	var apron: float = 1.0 - smoothstep(5.0, 17.0, Vector2(x + 5.0, z - 3.0).length())
	return lerpf(height, 1.0, apron * 0.92)

func presentation_for(point: Vector3) -> Dictionary:
	var region: String = "LANDING FLATS"
	if point.x < -18.0: region = "WESTERN SHADOW BASIN"
	elif point.x > 18.0 and point.z < 5.0: region = "SUNLIT SURVEY RIDGE"
	elif point.z > 20.0: region = "EJECTA FIELDS"
	var gradient := Vector2(terrain_height(point.x + 0.5, point.z) - terrain_height(point.x - 0.5, point.z),
		terrain_height(point.x, point.z + 0.5) - terrain_height(point.x, point.z - 0.5))
	return {"region": region, "exposure": "SHADOW" if point.x < -18.0 else "SUNLIGHT",
		"slope": rad_to_deg(atan(gradient.length())), "base_distance": Vector2(point.x + 9.0, point.z - 5.0).length()}

func get_landing_anchor() -> Marker3D:
	return landmarks.get_node("LandingAnchor") as Marker3D

func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.95
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

func build(sites: Array) -> void:
	name = "MoonSurface"
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("02040a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("94a4be")
	environment.ambient_light_energy = 0.20
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff1da")
	sun.light_energy = 1.05
	sun.rotation_degrees = Vector3(-19, -42, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	var resolution: int = 128
	var extent: float = 110.0
	for x_index in range(resolution):
		for z_index in range(resolution):
			var x: float = -extent + x_index * extent * 2.0 / resolution
			var z: float = -extent + z_index * extent * 2.0 / resolution
			var step_size: float = extent * 2.0 / resolution
			var points: Array[Vector3] = [Vector3(x, terrain_height(x, z), z),
				Vector3(x + step_size, terrain_height(x + step_size, z), z),
				Vector3(x, terrain_height(x, z + step_size), z + step_size),
				Vector3(x + step_size, terrain_height(x + step_size, z + step_size), z + step_size)]
			for index in [0, 1, 2, 1, 3, 2]:
				var point: Vector3 = points[index]
				surface.set_uv(Vector2(point.x, point.z) * 0.2)
				surface.add_vertex(point)
	surface.index()
	surface.generate_normals()
	surface.generate_tangents()
	var ground_material := ShaderMaterial.new()
	ground_material.shader = SURFACE_SHADER
	var terrain := _mesh(self, surface.commit(), Vector3.ZERO, ground_material)
	terrain.name = "Regolith"
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	var collision := CollisionShape3D.new()
	collision.shape = terrain.mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 289
	var rock_material := _material(Color("45464b"))
	# Shared irregular rock meshes limit draw-resource duplication.
	var rock_shapes: Array[ArrayMesh] = []
	for variant in range(6): rock_shapes.append(_rock_shape(variant))
	for i in range(290):
		var x: float = rng.randf_range(-94, 94)
		var z: float = rng.randf_range(-94, 94)
		if Vector2(x + 5, z - 3).length() < 15.0: continue
		var radius: float = rng.randf_range(0.2, 0.9)
		if i % 18 == 0: radius *= 2.1
		var rock := _mesh(self, rock_shapes[i % 6], Vector3(x, terrain_height(x, z) - radius * 0.14, z), rock_material)
		rock.rotation.y = rng.randf() * TAU
		rock.scale = Vector3(radius * rng.randf_range(0.9, 1.6), radius * 0.8, radius)
		if i % 8 == 0:
			var rock_body := StaticBody3D.new()
			var rock_collision := CollisionShape3D.new()
			rock_collision.shape = rock_shapes[i % 6].create_convex_shape()
			rock_body.add_child(rock_collision)
			rock.add_child(rock_body)
	_build_horizon(ground_material)
	_build_sky(rng)
	landmarks = Landmarks.new()
	landmarks.name = "LandingSite"
	add_child(landmarks)
	landmarks.build(self)
	_build_signals(sites)
	_build_station()
	_build_tracks()
	var scan_material := _material(Color("8ce9d2"), 0.7)
	scan_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	scan_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	scanner_ring = _mesh(self, ArrayMesh.new(), Vector3.ZERO, scan_material)
	scanner_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scanner_ring.visible = false

func _rock_shape(variant: int) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.7
	sphere.radial_segments = 7
	sphere.rings = 4
	var arrays: Array = sphere.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(points.size()):
		var p: Vector3 = points[i]
		points[i] = p * (0.86 + sin(p.x * 9.0 + p.z * 7.0 + variant) * 0.14 + cos(p.y * 8.0 + variant) * 0.10)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var normals := SurfaceTool.new()
	normals.create_from(mesh, 0)
	normals.generate_normals()
	return normals.commit()

func _build_horizon(finish: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	var segments: int = 160
	for i in range(segments):
		for band in range(8):
			var corners: Array[Vector3] = []
			for offset in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var angle: float = (float(i) + offset.x) / float(segments) * TAU
				var fraction: float = (float(band) + offset.y) / 8.0
				var radius: float = 100.0 + fraction * 100.0
				var x: float = sin(angle) * radius
				var z: float = cos(angle) * radius
				var peaks: float = 10.0 + sin(angle * 7.0) * 4.0 + cos(angle * 13.0) * 2.5 + sin(angle * 29.0)
				var ridge: float = pow(sin(fraction * PI), 1.6) * peaks
				corners.append(Vector3(x, lerpf(terrain_height(x, z), -6.0, fraction) + ridge, z))
			for index in [0, 1, 2, 1, 3, 2]: surface.add_vertex(corners[index])
	surface.index()
	surface.generate_normals()
	_mesh(self, surface.commit(), Vector3.ZERO, finish).name = "DistantCraterRims"

func _build_sky(rng: RandomNumberGenerator) -> void:
	var star_material := _material(Color("a4b9d0"), 0.7)
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.075
	star_mesh.height = 0.15
	star_mesh.radial_segments = 4
	star_mesh.rings = 2
	for i in range(150):
		var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.22, 1), rng.randf_range(-1, 1)).normalized()
		_mesh(self, star_mesh, direction * 255.0, star_material)
	var earth_mesh := SphereMesh.new()
	earth_mesh.radius = 8.0
	earth_mesh.height = 16.0
	earth_mesh.radial_segments = 48
	earth_mesh.rings = 24
	var earth_material := ShaderMaterial.new()
	earth_material.shader = EARTH_SHADER
	_mesh(self, earth_mesh, Vector3(-65, 32, -150), earth_material).name = "EarthScenery"

func _build_signals(sites: Array) -> void:
	for site in sites:
		var node := Node3D.new()
		node.position = site.position
		node.position.y = terrain_height(node.position.x, node.position.z)
		var ring := TorusMesh.new()
		ring.inner_radius = 1.3
		ring.outer_radius = 1.39
		var marker := _mesh(node, ring, Vector3(0, 0.25, 0), _material(Color("f3c582"), 0.5))
		var label := Label3D.new()
		label.position.y = 2.8
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 30
		label.pixel_size = 0.011
		label.outline_size = 8
		node.add_child(label)
		var pole := CylinderMesh.new()
		pole.top_radius = 0.035
		pole.bottom_radius = 0.035
		pole.height = 1.0
		_mesh(node, pole, Vector3(1.6, 0.5, 0), _material(Color("90979b")))
		var flag := BoxMesh.new()
		flag.size = Vector3(0.45, 0.22, 0.02)
		_mesh(node, flag, Vector3(1.8, 0.9, 0), _material(Color("c1aa78")))
		add_child(node)
		marker_nodes[site.id] = {"node": node, "ring": marker, "label": label}

func _build_station() -> void:
	station = Node3D.new()
	station.visible = false
	var module := BoxMesh.new()
	module.size = Vector3(2.5, 1.5, 2.2)
	_mesh(station, module, Vector3(0, 0.85, 0), _material(Color("aaaeb0")))
	var panel := BoxMesh.new()
	panel.size = Vector3(5.0, 0.1, 2.0)
	_mesh(station, panel, Vector3(0, 1.9, 0), _material(Color("183d65")))
	var label := Label3D.new()
	label.text = "RESEARCH STATION"
	label.position.y = 3.5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	station.add_child(label)
	add_child(station)

func _build_tracks() -> void:
	track_mesh = MultiMeshInstance3D.new()
	track_mesh.multimesh = MultiMesh.new()
	track_mesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var stamp := BoxMesh.new()
	stamp.size = Vector3(0.30, 0.012, 0.45)
	track_mesh.multimesh.mesh = stamp
	track_mesh.multimesh.instance_count = 1024
	track_mesh.multimesh.visible_instance_count = 0
	track_mesh.material_override = _material(Color("25282c"))
	track_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(track_mesh)

func _record_track(point: Vector3) -> void:
	if not last_track.is_finite():
		last_track = point
		return
	var direction := Vector3(point.x - last_track.x, 0, point.z - last_track.z)
	if direction.length() < 0.65: return
	direction = direction.normalized()
	var side := Vector3(-direction.z, 0, direction.x)
	var rotation_y: float = atan2(direction.x, direction.z)
	for offset in [-0.94, 0.94]:
		var at: Vector3 = point + side * offset
		at.y = terrain_height(at.x, at.z) + 0.035
		track_mesh.multimesh.set_instance_transform(track_cursor, Transform3D(Basis(Vector3.UP, rotation_y), at))
		track_cursor = (track_cursor + 1) % 1024
		track_count = mini(1024, track_count + 1)
	track_mesh.multimesh.visible_instance_count = track_count
	last_track = point

func update_mission(state: Dictionary) -> void:
	for site in state.sites:
		var marker: Dictionary = marker_nodes[site.id]
		var color: Color = Contract.FINDING_COLORS[site.finding]
		marker.ring.material_override.albedo_color = color
		marker.ring.material_override.emission = color
		marker.label.modulate = color
		var distance: float = Contract.flat_distance(state.position, site.position)
		marker.label.visible = distance < 45.0
		marker.label.text = str(site.name) + "\n" + str(site.confidence) + "% · " + str(Contract.FINDING_LABELS[site.finding])
	station.visible = state.outpost_deployed and state.outpost_position != null
	if station.visible:
		station.position = state.outpost_position
		station.position.y = terrain_height(station.position.x, station.position.z)
	if state.phase == "surface": _record_track(state.position)
	elif state.phase == "planning":
		last_track = Vector3.INF
		track_cursor = 0
		track_count = 0
		track_mesh.multimesh.visible_instance_count = 0

func pulse(origin: Vector3) -> void:
	scan_origin = origin
	scan_age = 0.0

func _process(delta: float) -> void:
	scan_age += delta
	if scanner_ring == null: return
	scanner_ring.visible = scan_age < 1.6
	if not scanner_ring.visible: return
	var radius: float = 1.0 + scan_age * 11.0
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(64):
		var corners: Array[Vector3] = []
		for point in [Vector2(i, -0.06), Vector2(i + 1, -0.06), Vector2(i, 0.06), Vector2(i + 1, 0.06)]:
			var angle: float = point.x / 64.0 * TAU
			var x: float = scan_origin.x + sin(angle) * (radius + point.y)
			var z: float = scan_origin.z + cos(angle) * (radius + point.y)
			corners.append(Vector3(x, terrain_height(x, z) + 0.07, z))
		for index in [0, 1, 2, 1, 3, 2]: surface.add_vertex(corners[index])
	scanner_ring.mesh = surface.commit()
	scanner_ring.material_override.albedo_color.a = 1.0 - scan_age / 1.6
