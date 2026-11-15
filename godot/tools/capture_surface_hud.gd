extends SceneTree
## Isolated HUD review fixtures; captures the game viewport only. Not a campaign playthrough.
## godot --path godot --script res://tools/capture_surface_hud.gd -- /absolute/output
const EngineAdapter = preload("res://simulation/mission_engine.gd")
const Surface = preload("res://spaceflight/surface_scene.gd")
const Game = preload("res://spaceflight/expedition_game.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(args[0])
	var engine = EngineAdapter.new()
	for id in ["moon", "mars"]:
		var state: Dictionary = engine.act(engine.create_surface_mission({"battery": "compact", "power": "solar", "instrument": "drill"}, 42, id), "launch")
		var info_owner: Node = Game.new()
		info_owner.expedition = {"location": id, "ship": {"fuel": 552}, "cores": []}
		var info: Dictionary = info_owner._surface_info()
		info_owner.free()
		info["objective"] = {"header": "FIRST LIGHT · %s CHAPTER · 2/12" % id.to_upper(), "title": "Investigate the ice signal", "distance": 169}
		var scene: Node3D = Surface.new()
		scene.setup(id, state, info)
		root.add_child(scene)
		for i in range(60): await physics_frame
		scene.set_checkpoints([{"id": "goal", "position": state.sites[0].position, "title": "Investigate the ice signal", "active": true, "completed": false}])
		scene._sync()
		# Preserve the actual full notes and every displayed log message after making the layout compact.
		if scene.hud.notes_label.text != info.notes: failures.append("Notes lost on " + id)
		for line in scene.state.log.slice(0, 3):
			if not scene.hud.log_label.text.contains(str(line)): failures.append("Log lost on " + id)
		if scene.hud.radar.base_position != scene.def.pad: failures.append("Wrong ship marker on " + id)
		for i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(args[0].path_join(id + "-compact-hud.png")) != OK: failures.append("Capture failed")
		# Actual button dispatches the same scan action as the keyboard.
		scene.state.position = scene.state.sites[0].position
		scene.hud.action_buttons[0].pressed.emit()
		if not scene.state.sites[0].scanned: failures.append("Scan button not connected on " + id)
		scene.queue_free()
		await process_frame
	for failure in failures: print("FAIL: ", failure)
	print("%s: compact surface HUD, retained information and scan actions" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
