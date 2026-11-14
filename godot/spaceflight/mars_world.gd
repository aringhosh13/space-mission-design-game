extends Node3D
## Aurora Delta: a FICTIONAL Mars landing region (procedural, original geometry; no NASA terrain data).
## Same API as Codex's scripts/lunar_world.gd so one surface controller can drive either world:
##   build(sites), terrain_height(x, z), update_mission(state), pulse(origin)
## Look inspired by public descriptions of Mars (reddish rusted dust, thin dusty sky, a smaller Sun,
## two small moons). Landforms near each signal hint at what it might be; they reveal no hidden truth.
const Contract = preload("res://shared/mission_contract.gd")

var marker_nodes: Dictionary = {}
var station: Node3D
var scanner_ring: MeshInstance3D
var scan_age: float = 2.0
var scan_origin: Vector3 = Vector3.ZERO
var craters: Array = [Vector3(52, 9, -40), Vector3(-58, 12, -30), Vector3(-20, 7, 60)]

func terrain_height(x: float, z: float) -> float:
	# Broad delta fan sloping gently toward the north-west, wind-aligned dunes and a few small craters.
	var height: float = 0.012 * (x - z) + sin(x * 0.028 + 0.6) * 1.1 + cos(z * 0.033) * 0.9
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
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 0.82   # dimmer than the lunar scene: Mars is ~1.5 AU from the Sun
	sun.rotation_degrees = Vector3(-34, 128, 0)
	sun.shadow_enabled = true
	add_child(sun)

func _terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var resolution: int = 96
	var extent: float = 110.0
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
	for i in range(260):
		var x: float = rng.randf_range(-96, 96)
		var z: float = rng.randf_range(-96, 96)
		if Vector2(x, z).length() < 8.0 or Vector2(x, z + 11.0).length() < 7.0: continue
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
		var radius: float = rng.randf_range(112.0, 126.0)
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
	# Near the ice signal: a scarp with a pale exposed band (fictional placement).
	var scarp := BoxMesh.new()
	scarp.size = Vector3(26, 6, 3)
	var wall := _mesh(self, scarp, Vector3(-52, terrain_height(-52, 33) + 1.5, 33), _material(Color("7b4a33")))
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
		_mesh(self, terrace, Vector3(50, terrain_height(50, 26) - 0.3 + step * 0.7, 26), _material(Color(0.78, 0.66, 0.52).lerp(Color(0.66, 0.5, 0.38), step * 0.25)))
	# Near the delta signal: thin stacked sediment layers.
	for layer in range(7):
		var sheet := BoxMesh.new()
		sheet.size = Vector3(18 - layer * 1.6, 0.55, 8 - layer * 0.5)
		_mesh(self, sheet, Vector3(10, terrain_height(10, -62) + 0.3 + layer * 0.55, -62), _material(layers[layer % layers.size()]))
	# Phobos and Deimos, Mars's two small moons, high in the sky (positions illustrative).
	var moon_material := _material(Color("8d8379"))
	for spec in [[Vector3(-120, 140, -260), 6.0], [Vector3(200, 180, -150), 2.5]]:
		var shape := SphereMesh.new()
		shape.radius = spec[1]
		shape.height = spec[1] * 1.6
		shape.radial_segments = 8
		shape.rings = 5
		_mesh(self, shape, spec[0], moon_material)

func build(sites: Array) -> void:
	_environment()
	_terrain()
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
	if scanner_ring == null: return
	scanner_ring.visible = scan_age < 1.6
	if scanner_ring.visible:
		var radius: float = 1.0 + scan_age * 11.0
		scanner_ring.scale = Vector3(radius, 1, radius)
		scanner_ring.position = Vector3(scan_origin.x, terrain_height(scan_origin.x, scan_origin.z) + 0.22, scan_origin.z)
		scanner_ring.material_override.albedo_color.a = 1.0 - scan_age / 1.6
