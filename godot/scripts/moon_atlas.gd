extends CanvasLayer
## Interactive whole-Moon overview from the bundled NASA LOLA elevation grid.
## Picking a point only places a survey marker; it never teleports the rover or confirms a deposit.
const ELEVATION = preload("res://data/terrain/lola_global.tres")
signal close_requested
signal survey_selected(latitude: float, longitude: float)
@export var start_hidden: bool = true
var panel: Control
var viewport: SubViewport
var globe: Node3D
var camera: Camera3D
var pin: MeshInstance3D
var selection: Label
var drag: bool = false
var dragged: float = 0.0
var zoom: float = 10.5

func _ready() -> void:
	layer = 30
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var background := ColorRect.new()
	background.color = Color("030a13")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(background)
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	panel.add_child(container)
	container.gui_input.connect(_map_input)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	container.add_child(viewport)
	var space := Node3D.new()
	viewport.add_child(space)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("030a13")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("8e9dad")
	settings.ambient_light_energy = 0.5
	environment.environment = settings
	space.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, -35, 0)
	light.light_energy = 1.8
	space.add_child(light)
	globe = Node3D.new()
	globe.rotation = Vector3(0.3, -PI * 0.5, 0)
	space.add_child(globe)
	_build_globe()
	pin = MeshInstance3D.new()
	var pin_mesh := SphereMesh.new()
	pin_mesh.radius = 0.055
	pin_mesh.height = 0.11
	pin.mesh = pin_mesh
	var pin_material := StandardMaterial3D.new()
	pin_material.albedo_color = Color("ffce77")
	pin_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pin.material_override = pin_material
	globe.add_child(pin)
	camera = Camera3D.new()
	camera.position = Vector3(0, 0, zoom)
	camera.current = true
	camera.fov = 48
	space.add_child(camera)
	_label("LUNAR SURVEY ATLAS", Vector2(32, 22), 28, Color("e2e9db"))
	_label("NASA LRO / LOLA  ·  GLOBAL ELEVATION OVERVIEW", Vector2(34, 61), 13, Color("9fc8cf"))
	selection = _label("", Vector2(34, 106), 17, Color("f3c582"))
	selection.size = Vector2(340, 200)
	selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label("Drag to rotate  ·  Wheel to zoom  ·  Click to place a survey marker  ·  M / Esc to return", Vector2(34, 650), 15, Color("e2e9db"))
	_label("Global view only; detailed driving is regional. Relief exaggerated ×15. Local distances and relief are compressed.", Vector2(34, 683), 12, Color("93a8b5"))
	var close := Button.new()
	close.text = "RETURN TO MISSION  [M]"
	close.position = Vector2(997, 24)
	close.size = Vector2(250, 42)
	close.pressed.connect(_request_close)
	panel.add_child(close)
	_select(-88.0, 30.0)
	if start_hidden: hide_map()

func _label(text: String, position: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return label

static func point(latitude: float, longitude: float, radius: float) -> Vector3:
	var lat: float = deg_to_rad(latitude)
	var lon: float = deg_to_rad(fposmod(longitude, 360.0))
	return Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)) * radius

func _build_globe() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(96):
		for col in range(192):
			for corner in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var lat: float = 90.0 - (row + corner.y) / 96.0 * 180.0
				var lon: float = (col + corner.x) / 192.0 * 360.0
				var elevation: float = ELEVATION.elevation_at(lat, lon)
				var shade: float = clampf(0.48 + elevation / 22000.0, 0.22, 0.85)
				surface.set_color(Color(shade * 0.96, shade * 0.98, shade))
				surface.add_vertex(point(lat, lon, 3.5 * (1.0 + elevation / 1737400.0 * 15.0)))
	surface.index()
	surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = material
	globe.add_child(mesh)

func show_map() -> void:
	panel.visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_map() -> void:
	panel.visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	drag = false

func is_open() -> bool:
	return panel != null and panel.visible

func _request_close() -> void:
	if close_requested.has_connections(): close_requested.emit()
	else: get_tree().quit()

func _select(latitude: float, longitude: float) -> void:
	var elevation: float = ELEVATION.elevation_at(latitude, longitude)
	pin.position = point(latitude, longitude, 3.5 * (1.0 + elevation / 1737400.0 * 15.0) + 0.075)
	var display_latitude: float = snappedf(latitude, 0.01)
	var display_longitude: float = fposmod(snappedf(fposmod(longitude, 360.0), 0.01), 360.0)
	selection.text = "SURVEY MARKER\n%.2f° %s / %.2f° E\n\nLOLA elevation: %.0f m\nReference sphere: 1737.4 km\n\nMarker selection is for planning. Resource locations remain fictional." % [absf(display_latitude), "N" if display_latitude >= 0.0 else "S", display_longitude, elevation]
	survey_selected.emit(latitude, fposmod(longitude, 360.0))

func _pick(screen: Vector2) -> void:
	var origin: Vector3 = globe.to_local(camera.project_ray_origin(screen))
	var direction: Vector3 = (globe.global_basis.inverse() * camera.project_ray_normal(screen)).normalized()
	var b: float = origin.dot(direction)
	var discriminant: float = b * b - origin.length_squared() + 3.5 * 3.5
	if discriminant < 0.0: return
	var hit: Vector3 = origin + direction * (-b - sqrt(discriminant))
	_select(rad_to_deg(asin(clampf(hit.normalized().y, -1.0, 1.0))), rad_to_deg(atan2(hit.z, hit.x)))

func _map_input(event: InputEvent) -> void:
	if not is_open(): return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: dragged = 0.0
			elif dragged < 5.0: _pick(event.position)
			drag = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom + (-0.5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.5), 6.0, 16.0)
			camera.position.z = zoom
	elif event is InputEventMouseMotion and drag:
		dragged += event.relative.length()
		globe.rotation.y += event.relative.x * 0.006
		globe.rotation.x = clampf(globe.rotation.x + event.relative.y * 0.006, -PI, PI)

func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_M, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		_request_close()
