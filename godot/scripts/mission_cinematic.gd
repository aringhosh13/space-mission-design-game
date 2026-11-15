extends CanvasLayer
## Skippable native 3D briefings. Presentation only: never changes planning or mission state.
signal finished(reason: String)
const MOON = preload("res://data/terrain/lola_south_pole.tres")
const MARS = preload("res://data/terrain/mola_jezero.tres")
const ShipModel = preload("res://spaceflight/ship_model.gd")
const LunarWorld = preload("res://scripts/lunar_world.gd")
const MarsWorld = preload("res://spaceflight/mars_world.gd")
const Rover = preload("res://scripts/rover.gd")
const EarthReturn = preload("res://scripts/earth_return_reference.gd")
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
var world: Node3D
var earth_reference: Node3D
var provenance: Label
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
	viewport.msaa_3d = Viewport.MSAA_4X
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
	provenance = label("Illustrative cinematic · NASA-derived terrain, compressed scales · power model is not flight validated", Vector2(44, 690), Vector2(1100, 22), 11, Color("90a8ad"))
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
	return world.terrain_height(point.x, point.y)

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
	if kind == "earth-return":
		earth_reference = EarthReturn.new()
		stage.add_child(earth_reference)
		camera = earth_reference.camera
		return
	world = MarsWorld.new() if context.get("body", "moon") == "mars" else LunarWorld.new()
	world.configure_extent(220.0 if context.get("body", "moon") == "mars" else 150.0)
	stage.add_child(world)
	world.build([])
	# Cinematic scenery is the same renderer, geometry, shader, light and sky as gameplay.
	for node in world.find_children("*", "Label3D", true, false): node.visible = false
	rover = Rover.new()
	rover.presentation_only = true
	stage.add_child(rover)
	rover.position = Vector3(0, height_at(Vector2.ZERO), 0)
	var ship: Node3D = ShipModel.new()
	stage.add_child(ship)
	ship.landing_gear(true)
	ship.position = Vector3(0, height_at(Vector2(0, -11)) + 2.62, -11)
	ship.rotation.y = 0.6
	route = Node3D.new()
	stage.add_child(route)
	var points: Array = context.get("plan", {}).get("outbound", [])
	if points.is_empty(): points = [Vector2(0.5, 0.5), Vector2(0.6, 0.42), Vector2(0.78, 0.32)]
	var previous := Vector3.ZERO
	for i in range(points.size()):
		var point: Vector2 = points[i] * 960.0 - Vector2.ONE * 480
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
	camera.far = 1500
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
	provenance.text = "Historical reference: Artemis I · 11 December 2022 · NASA mission reports · geometry and timing illustrated" if mode == "earth-return" else "In-engine scene · NASA-derived terrain at game scale · planning model is illustrative"
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
	if kind == "earth-return":
		earth_reference.animate(shot, t)
		return
	# The rover holds still: a camera tour must not suggest collision-free scripted driving.
	var ground: float = height_at(Vector2.ZERO)
	var target := Vector3(0, ground + 1.0, 0)
	var at: Vector3
	var ease: float = smoothstep(0, 1, t)
	if shot == 0:
		at = Vector3(11 - ease * 4, ground + 4.5, 12 + ease * 3)
	elif shot == 1:
		target = Vector3(0, ground + 1.2, -5)
		at = Vector3(17 - ease * 3, ground + 6, -3 - ease * 4)
	else:
		target = Vector3(12, height_at(Vector2(12, -10)), -10)
		at = Vector3(45 - ease * 10, ground + 40 + ease * 12, 40)
	# Keep the tracking camera above local relief on both worlds.
	at.y = maxf(at.y, height_at(Vector2(at.x, at.z)) + 2.5)
	camera.position = at
	camera.look_at(target, Vector3.UP)
	camera.fov = 58
	route.visible = kind == "solution"  # Do not invent an unearned route in the results scene.

func _set_caption(shot: int) -> void:
	if kind == "earth-return":
		chapter.text = "REAL MISSION REFERENCE / ARTEMIS I (2022) / %d OF 3" % (shot + 1)
		heading.text = EarthReturn.TITLES[shot]
		caption.text = EarthReturn.CAPTIONS[shot]
		return
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
