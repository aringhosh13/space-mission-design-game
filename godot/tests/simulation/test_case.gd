extends RefCounted
## Base class for native simulation tests. Methods named test_* are run by run_tests.gd.
const Engine_ = preload("res://simulation/mission_engine.gd")
const Rules = preload("res://simulation/rules.gd")
const Evidence = preload("res://simulation/evidence.gd")

const DRILL: Dictionary = {"battery": "compact", "power": "solar", "instrument": "drill"}
const SCANNER: Dictionary = {"battery": "compact", "power": "solar", "instrument": "scanner"}
const FUEL_SCANNER: Dictionary = {"battery": "compact", "power": "fuel-cell", "instrument": "scanner"}
const OVERWEIGHT: Dictionary = {"battery": "extended", "power": "fuel-cell", "instrument": "drill"}

var engine = Engine_.new()
var failures: Array[String] = []
var assertions: int = 0
var current_test: String = ""

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition: failures.append("%s: %s" % [current_test, message])

func eq(actual: Variant, expected: Variant, message: String) -> void:
	check(typeof(actual) == typeof(expected) and actual == expected,
		"%s (expected %s, got %s)" % [message, var_to_str(expected), var_to_str(actual)])

func near(actual: float, expected: float, message: String, tolerance: float = 0.000001) -> void:
	check(absf(actual - expected) <= tolerance, "%s (expected %.9f, got %.9f)" % [message, expected, actual])

# ----------------------------------------------------------------------------------------- fixtures

func launched(config: Dictionary = DRILL, mission_seed: int = 42) -> Dictionary:
	var s: Dictionary = engine.act(engine.create_mission(config, mission_seed), "launch")
	assert(s.phase == "surface")
	return s

## Copy of a state with the rover somewhere else (the simulation is pure, so tests may build states).
func at(state: Dictionary, position: Vector3) -> Dictionary:
	var s: Dictionary = state.duplicate(true)
	s.position = position
	return s

func with_energy(state: Dictionary, energy: float) -> Dictionary:
	var s: Dictionary = state.duplicate(true)
	s.energy = energy
	return s

func site(state: Dictionary, kind: String) -> Dictionary:
	for entry in state.sites:
		if entry.kind == kind: return entry
	return {}

func run_actions(state: Dictionary, actions: Array) -> Dictionary:
	var s: Dictionary = state
	for action in actions: s = engine.act(s, action)
	return s

## Teleport onto a site with a full battery and run actions there.
func investigate(state: Dictionary, kind: String, actions: Array = ["scan", "sample"]) -> Dictionary:
	var s: Dictionary = with_energy(at(state, site(state, kind).position), float(state.max_energy))
	return run_actions(s, actions)

## Everything except the log, to assert that a rejected action changed nothing else.
func without_log(state: Dictionary) -> Dictionary:
	var s: Dictionary = state.duplicate(true)
	s.erase("log")
	return s

func unchanged_except_log(after: Dictionary, before: Dictionary, message: String) -> void:
	check(without_log(after) == without_log(before), message)

func last_log(state: Dictionary) -> String:
	return str(state.log[0]) if not state.log.is_empty() else ""

func find_seed(predicate: Callable) -> int:
	for candidate in range(10000):
		if predicate.call(candidate): return candidate
	return -1

func truth(mission_seed: int, kind: String) -> bool:
	return Evidence.is_false_positive(mission_seed, site(engine.create_mission(DRILL, mission_seed), kind))
