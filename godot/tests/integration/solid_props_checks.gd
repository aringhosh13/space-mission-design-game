extends SceneTree
## Real CharacterBody sweeps through representative built props, not just collider-node counts.
const Moon = preload("res://scripts/lunar_world.gd")
const Mars = preload("res://spaceflight/mars_world.gd")
const Rover = preload("res://scripts/rover.gd")
const MissionEngine = preload("res://simulation/mission_engine.gd")
const Film = preload("res://scripts/mission_cinematic.gd")
class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var mutex := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_notify: bool, _kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		mutex.lock()
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
		mutex.unlock()
	func _log_message(_message: String, _error: bool) -> void: pass
var failures: Array[String] = []
var checks: int = 0
var catcher := ErrorCatcher.new()
func _initialize() -> void:
	OS.add_logger(catcher)
	run.call_deferred()
func frames(count: int = 3) -> void:
	for i in range(count): await physics_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func sweep(rover: CharacterBody3D, centre: Vector3, expected: StaticBody3D) -> bool:
	rover.position = centre - Vector3(6, 0.6, 0)
	var hit: KinematicCollision3D = rover.move_and_collide(Vector3(12, 0, 0), true)
	return hit != null and hit.get_collider() == expected and hit.get_travel().x < 6
func run() -> void:
	var engine = MissionEngine.new()
	for id in ["moon", "mars"]:
		var scene := Node3D.new()
		root.add_child(scene)
		var world: Node3D = Moon.new() if id == "moon" else Mars.new()
		world.configure_extent(150 if id == "moon" else 220)
		scene.add_child(world)
		var state: Dictionary = engine.act(engine.create_surface_mission({"battery":"extended", "power":"solar", "instrument":"drill"}, 42, id), "launch")
		world.build(state.sites)
		var rover: CharacterBody3D = Rover.new()
		scene.add_child(rover)
		rover.set_physics_process(false)
		rover.set_process(false)
		rover.collision_mask = 2 # Props only: a terrain hit must not falsely pass this regression.
		await frames()
		var rocks: Array[Node] = world.find_children("Rock_*", "MeshInstance3D", false, false)
		check(rocks.size() > 200, id + ": test covers the actual scattered rocks")
		for rock in rocks:
			check(rock.has_meta("solid_body"), id + ": every visible rock has collision")
		for i in range(0, mini(rocks.size(), 100), 13):
			var rock: MeshInstance3D = rocks[i]
			var body: StaticBody3D = rock.get_meta("solid_body").get_ref()
			check(body.global_basis.get_scale().is_equal_approx(Vector3.ONE), id + ": nonuniform visual scale is baked into vertices")
			check(sweep(rover, rock.global_position, body), id + ": rover cannot sweep through a scaled/rotated rock")
		for body in world.station.find_children("SolidCollision*", "StaticBody3D", true, false):
			check(body.collision_layer == 0, id + ": undeployed station has no ghost collision")
		state.outpost_deployed = true
		state.outpost_position = Vector3(20, 0, 16)
		var before: Dictionary = state.duplicate(true)
		world.update_mission(state)
		await frames()
		var hardware: Node3D = world.station.get_child(0)
		var module: MeshInstance3D = hardware.get_child(0)
		var station_body: StaticBody3D = module.get_meta("solid_body").get_ref()
		check(sweep(rover, module.global_position, station_body), id + ": deployed station stops the rover")
		check(state == before, id + ": rendering/collision cannot change the mission state")
		check(hardware.position.z == -5 and world.station.position.x == 20, id + ": deployed hardware leaves the operator footprint clear and keeps the anchor")
		scene.queue_free()
		await frames()
	# Presentation uses the exact renderer and rover geometry, with input/physics disabled.
	var film: Node = Film.new()
	root.add_child(film)
	for id in ["moon", "mars"]:
		film.play("problem", {"body": id})
		check(film.world.get_script() == (Moon if id == "moon" else Mars), id + ": cinematic reuses game renderer")
		check(film.rover.get_script() == Rover and film.rover.presentation_only and not film.rover.is_physics_processing(), id + ": exact game rover, no hidden driving")
		film.stop("cancelled")
	film.queue_free()
	await frames()
	OS.remove_logger(catcher)
	failures.append_array(catcher.errors)
	for failure in failures: print("FAIL: ", failure)
	print("%s: solid props and shared cinematic scenery (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
