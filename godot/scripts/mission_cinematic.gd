extends CanvasLayer
## Skippable native 3D briefings. Presentation only: never changes planning or mission state.
signal finished(reason: String)
const MOON = preload("res://data/terrain/lola_south_pole.tres")
const MARS = preload("res://data/terrain/mola_jezero.tres")
const ShipModel = preload("res://spaceflight/ship_model.gd")
const MOON_SHADER = preload("res://shaders/moon_surface.gdshader")
const SHOT_SECONDS: float = 6.0
var playing: bool = false
var elapsed: float = 0.0
var kind: String = "problem"
var context: Dictionary = {}
var panel: Control
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var caption: Label
var heading: Label
var chapter: Label
var data: Resource
var route: Node3D
var rover: Node3D
var _shot: int = -1
var skip_button: Button
var _previous_focus: WeakRef

func _ready() -> void:
	layer = 50
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	container.add_child(viewport)
	for rect in [Rect2(0, 0, 1280, 76), Rect2(0, 506, 1280, 214)]:
		var bar := ColorRect.new()
		bar.position = rect.position
		bar.size = rect.size
		bar.color = Color(0.005, 0.012, 0.022, 0.96)
		panel.add_child(bar)
	chapter = label("", Vector2(34, 24), Vector2(950, 35), 20, Color("a3c9d1"))
	heading = label("", Vector2(42, 524), Vector2(1120, 43), 30, Color("f0e8d4"))
	caption = label("", Vector2(44, 577), Vector2(1160, 88), 20, Color("d5e3df"))
	label("Illustrative cinematic · NASA-derived terrain, compressed scales · power model is not flight validated", Vector2(44, 690), Vector2(1100, 22), 11, Color("90a8ad"))
	var skip := Button.new()
	skip_button = skip
	skip.text = "SKIP / CONTINUE  [SPACE]"
	skip.position = Vector2(1005, 21)
	skip.size = Vector2(245, 36)
	skip.pressed.connect(func() -> void: stop("skipped"))
	panel.add_child(skip)
	panel.visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(false)

func label(text: String, at: Vector2, extent: Vector2, font_size: int, color: Color) -> Label:
	var item := Label.new()
	item.text = text
	item.position = at
	item.size = extent
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(item)
	return item

func height_at(point: Vector2) -> float:
	return (data.sample_uv(point.x / 160.0 + 0.5, point.y / 160.0 + 0.5) - data.sample_uv(0.5, 0.5)) * 0.001

func material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var finish := StandardMaterial3D.new()
	finish.albedo_color = color
	finish.roughness = 0.85
	if emissive:
		finish.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return finish

func mesh(parent: Node3D, shape: Mesh, at: Vector3, finish: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = shape
	item.position = at
	item.material_override = finish
	parent.add_child(item)
	return item

func _build_stage() -> void:
	if stage:
		viewport.remove_child(stage)
		stage.queue_free()
	stage = Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("070b15") if context.get("body", "moon") == "moon" else Color("805b47")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("8e9fac")
	settings.ambient_light_energy = 0.42
	environment.environment = settings
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, -55, 0)
	sun.light_color = Color("ffe8bf")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	stage.add_child(sun)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(64):
		for x in range(64):
			for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var point: Vector2 = (Vector2(x, z) + corner) / 64.0 * 160.0 - Vector2.ONE * 80.0
				surface.set_uv(point * 0.2)
				surface.add_vertex(Vector3(point.x, height_at(point), point.y))
	surface.index()
	surface.generate_normals()
	surface.generate_tangents()
	var ground: Material = material(Color("ae714e"))
	if context.get("body", "moon") == "moon":
		var shader_finish := ShaderMaterial.new()
		shader_finish.shader = MOON_SHADER
		ground = shader_finish
	mesh(stage, surface.commit(), Vector3.ZERO, ground)
	rover = Node3D.new()
	stage.add_child(rover)
	var body := BoxMesh.new()
	body.size = Vector3(2.5, 0.8, 3.5)
	mesh(rover, body, Vector3(0, 1.15, 0), material(Color("ddd9c5")))
	var solar := BoxMesh.new()
	solar.size = Vector3(3.0, 0.08, 2.2)
	mesh(rover, solar, Vector3(0, 1.65, 0.3), material(Color("285f88")))
	for x in [-1.45, 1.45]:
		for z in [-1.15, 0.0, 1.15]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.6
			wheel.bottom_radius = 0.6
			wheel.height = 0.35
			mesh(rover, wheel, Vector3(x, 0.6, z), material(Color("18212b"))).rotation.z = PI * 0.5
	var mast := CylinderMesh.new()
	mast.top_radius = 0.06
	mast.bottom_radius = 0.06
	mast.height = 2.0
	mesh(rover, mast, Vector3(0, 2.5, -1), material(Color("cbd3d1")))
	var ship: Node3D = ShipModel.new()
	stage.add_child(ship)
	ship.landing_gear(true)
	ship.position = Vector3(-20, height_at(Vector2(-20, 9)) + 2.62, 9)
	ship.rotation.y = 0.7
	route = Node3D.new()
	stage.add_child(route)
	var points: Array = context.get("plan", {}).get("outbound", [])
	if points.is_empty(): points = [Vector2(0.5, 0.5), Vector2(0.6, 0.42), Vector2(0.78, 0.32)]
	var previous := Vector3.ZERO
	for i in range(points.size()):
		var point: Vector2 = points[i] * 160.0 - Vector2.ONE * 80
		var here := Vector3(point.x, height_at(point) + 0.18, point.y)
		if i > 0:
			var segment := CylinderMesh.new()
			segment.top_radius = 0.13
			segment.bottom_radius = 0.13
			segment.height = previous.distance_to(here)
			var tube := mesh(route, segment, (previous + here) * 0.5, material(Color("f6cb7d"), true))
			var axis: Vector3 = (here - previous).normalized()
			var up: Vector3 = Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
			# Cylinder local Y follows the route segment.
			var right: Vector3 = up.cross(axis).normalized()
			tube.basis = Basis(right, axis, right.cross(axis).normalized())
		previous = here
	var marker := CylinderMesh.new()
	marker.top_radius = 0.16
	marker.bottom_radius = 0.5
	marker.height = 9
	mesh(stage, marker, previous + Vector3(0, 4.5, 0), material(Color("8ce6d3"), true))
	camera = Camera3D.new()
	camera.current = true
	camera.far = 400
	stage.add_child(camera)

func play(mode: String, payload: Dictionary = {}) -> void:
	if playing: stop("cancelled")
	kind = mode
	context = payload.duplicate(true)
	if context.get("body", "moon") not in ["moon", "mars"]: context["body"] = "moon"
	data = MARS if context.get("body", "moon") == "mars" else MOON
	elapsed = 0.0
	_shot = -1
	playing = true
	_build_stage()
	var focus: Control = get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null and not panel.is_ancestor_of(focus) else null
	panel.visible = true
	skip_button.grab_focus()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_process(true)
	_process(0.0)

func stop(reason: String = "cancelled") -> void:
	if not playing: return
	playing = false
	panel.visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(false)
	if _previous_focus != null:
		var focus: Control = _previous_focus.get_ref() as Control
		if focus != null and focus.is_inside_tree() and focus.is_visible_in_tree(): focus.grab_focus()
	finished.emit(reason)

func _process(delta: float) -> void:
	if not playing: return
	elapsed += delta
	if elapsed >= SHOT_SECONDS * 3:
		stop("complete")
		return
	var shot: int = mini(2, floori(elapsed / SHOT_SECONDS))
	var t: float = fposmod(elapsed, SHOT_SECONDS) / SHOT_SECONDS
	if shot != _shot:
		_shot = shot
		_set_caption(shot)
	var target := Vector3(0, 1, 0)
	var at: Vector3
	if shot == 0: at = Vector3(sin(t * 0.65 + 0.4) * 19, 7 + t * 3, cos(t * 0.65 + 0.4) * 19)
	elif shot == 1: at = Vector3(-24 + t * 9, 9, 22 - t * 7)
	else:
		target = Vector3(12, 0, -10)
		at = Vector3(30 - t * 12, 60 + t * 20, 38)
	camera.position = at
	camera.look_at(target, Vector3.UP)
	camera.fov = 55 if shot < 2 else 62
	route.visible = kind != "problem" or shot == 2
	var rover_x: float = t * 3.0 if kind == "solution" else 0.0
	rover.position = Vector3(rover_x, height_at(Vector2(rover_x, 0)), 0)

func _set_caption(shot: int) -> void:
	chapter.text = "BLUE HORIZON / %s / %d OF 3" % ["MISSION BRIEFING" if kind == "problem" else ("PLAN PRESENTATION" if kind == "solution" else "MISSION DEBRIEF"), shot + 1]
	if kind == "problem":
		heading.text = ["A DISCOVERY IS ONLY HALF THE JOURNEY", "THE ROVER MUST ALSO COME HOME", "YOUR TASK: DESIGN THE RETURN TRAVERSE"][shot]
		caption.text = ["A promising site lies beyond uneven terrain. The shortest line may cross slopes a rover cannot safely traverse.",
			"Our rover has limited energy. Its plan must cover the journey out, the return leg and a reserve.",
			"Compare routes using NASA elevation. Set your constraints, then present a candidate that passes the model. Reconnaissance remains essential."][shot]
	elif kind == "solution":
		var plan: Dictionary = context.get("plan", {})
		var remaining: float = float(plan.get("battery_wh", 0)) - float(plan.get("energy_wh", 0))
		heading.text = ["YOUR CANDIDATE RETURN TRAVERSE", "THE ENERGY AND SLOPE CHECK", "A PLAN FOR RECONNAISSANCE"][shot]
		caption.text = ["Both legs total %.1f km, using the %s elevation patch. Amber marks the selected candidate; it is a regional study, not a command sequence." % [float(plan.get("distance_m", 0)) / 1000.0, plan.get("source", "NASA")],
			"Modeled demand: %.0f Wh. Remaining: %.0f Wh (required reserve: %.0f Wh). Maximum sampled slope: %.1f°, within your %.1f° limit." % [plan.get("energy_wh", 0), remaining, float(plan.get("battery_wh", 0)) * float(plan.get("reserve", 0)), plan.get("max_slope_deg", 0), plan.get("slope_limit", 0)],
			"This candidate passes your stated model. Rocks, soil slip, shadows, thermal survival and communications still need checking. Now explore those trade-offs in the fictional expedition."][shot]
	else:
		var report: Dictionary = context.get("report", {})
		var complete: bool = bool(context.get("complete", false))
		heading.text = ["EVIDENCE RETURNED" if complete else "THE EXPEDITION'S RESULTS", "WHAT YOUR CHOICES ACHIEVED", "WHAT THE SOLUTION MEANS"][shot]
		caption.text = ["%d of %d objectives completed. %d science returned, including %d science from delivered sample cores." % [context.get("completed", 0), context.get("total", 12), report.get("science_returned", 0), report.get("delivered_science", 0)],
			"%d research stations established. Fuel used: %.0f kg; remaining: %.0f kg. The expedition %s." % [report.get("stations", 0), report.get("fuel_used", 0), report.get("fuel_left", 0), "returned to the Moon base" if report.get("home", false) else "ended away from the base"],
			"Reach the investigation site, collect evidence and preserve a path home: that is the planning problem. The field mission is fictional; the NASA-data planner remains a regional screening prototype, not a flight-approved solution."][shot]

func _input(event: InputEvent) -> void:
	# Capture cinematic keys before focused controls can consume/retrigger them.
	if playing and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		stop("skipped")
