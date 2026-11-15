extends SceneTree
## Isolated UI/data review fixtures, not a claimed human playthrough.
const Surface = preload("res://spaceflight/surface_scene.gd")
const EngineAdapter = preload("res://simulation/mission_engine.gd")
const Labels = preload("res://scripts/world_labels.gd")
const Game = preload("res://spaceflight/expedition_game.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func capture(path: String) -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path) == OK, "Capture failed")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1: quit(1); return
	DirAccess.make_dir_recursive_absolute(args[0])
	var engine = EngineAdapter.new()
	for body in ["moon", "mars"]:
		var state: Dictionary = engine.act(engine.create_surface_mission({"battery": "compact", "power": "solar", "instrument": "drill"}, 42, body), "launch")
		var scene: Node3D = Surface.new()
		scene.setup(body, state, {"ship_fuel": 552, "cores": 0, "objective": {"header": "LABEL REGRESSION FIXTURE", "title": "Return to the base"}})
		root.add_child(scene)
		await frames(60)
		var checkpoints: Array = []
		for i in range(7): checkpoints.append({"id": "same-pad-%d" % i, "title": "Return to base %d" % i, "position": scene.def.pad, "active": i == 3, "completed": i < 3})
		scene.set_checkpoints(checkpoints)
		await frames(10)
		var rects: Array[Rect2] = Labels.update(scene.world, scene.rover.camera)
		for i in range(rects.size()):
			for j in range(i + 1, rects.size()): check(not rects[i].intersects(rects[j]), "Annotation overlap on " + body)
		if body == "moon":
			var inactive: int = 0
			for entry in scene.world.checkpoint_nodes.values():
				if entry.label.get_meta("annotation_enabled", true) == false: inactive += 1
			check(inactive == 6, "Colocated inactive checkpoint titles must be hidden")
		await capture(args[0].path_join(body + "-labels.png"))
		var previous: Dictionary = scene.state.duplicate(true)
		scene.toggle_planner()
		await frames(10)
		scene.planner.film.stop("skipped")
		check(scene.paused and not scene.rover.driving, "Planning must pause driving")
		check(scene.state == previous, "Planning must not change mission resources")
		check(scene.planner.selected.outbound.size() > 1, "NASA planner must produce a candidate")
		scene.planner.export_route()
		check(FileAccess.file_exists("user://traverse-" + body + ".geojson"), "Route export must exist")
		await capture(args[0].path_join(body + "-planner.png"))
		scene.planner.battery.value = 100
		check(not scene.planner.selected.feasible, "Insufficient budget must not approve the route")
		scene.planner.close_requested.emit()
		await frames(2)
		check(not scene.paused and scene.rover.driving, "Closing planner restores driving")
		scene.queue_free()
		await frames(2)
	# Long debrief and planning screens must stay reachable through a bounded scroll area.
	var game: Node = load("res://scenes/spaceflight/campaign.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	var ui: Node = game.ui
	await capture(args[0].path_join("planning-menu.png"))
	check(ui.content.get_parent() is ScrollContainer, "Menus must use a scroll container")
	var fuel: String = ui.selected("fuel")
	ui.choice.emit("planner", "")
	check(game.study_planner.is_open(), "Planning tool must open before launching a mission")
	game.study_planner.close_requested.emit()
	check(ui.active == "planning" and ui.selected("fuel") == fuel, "Closing study lab preserves loadout")
	game.queue_free()
	await frames(2)
	for failure in failures: print("FAIL: ", failure)
	print("%s: labels, planning pause/resources, budget refusal, export and menu bounds" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
