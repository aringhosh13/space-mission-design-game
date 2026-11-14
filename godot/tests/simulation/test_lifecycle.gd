extends "res://tests/simulation/test_case.gd"
## Immutability, closed missions, reports, reproducibility and site layout.

const ALL_ACTIONS: Array[String] = ["launch", "scan", "sample", "recharge", "transmit", "deploy", "finish", "teleport"]

func _sample_states() -> Array:
	var surface: Dictionary = launched()
	var scanned: Dictionary = investigate(surface, "minerals", ["scan"])
	return [engine.create_mission(DRILL, 3), surface, scanned, with_energy(scanned, 2.0),
		engine.act(scanned, "deploy"), engine.act(scanned, "finish")]

func test_inputs_are_never_mutated() -> void:
	for state in _sample_states():
		var snapshot: Dictionary = state.duplicate(true)
		for action in ALL_ACTIONS:
			var next: Dictionary = engine.act(state, action)
			check(not is_same(next, state), "act returns a new dictionary")
			if not next.sites.is_empty(): check(not is_same(next.sites, state.sites), "sites are not shared")
		for p in [Vector3(1, 0, 0), Vector3(500, 0, 0), Vector3(NAN, 0, 0)]: engine.move_rover(state, p)
		engine.get_report(state)
		eq(state, snapshot, "input unchanged in phase %s" % state.phase)

func test_review_does_not_mutate_config() -> void:
	var config: Dictionary = OVERWEIGHT.duplicate()
	engine.review_design(config)
	engine.create_mission(config, 1)
	eq(config, OVERWEIGHT, "config unchanged")

func test_closed_mission_rejects_every_change() -> void:
	var done: Dictionary = engine.act(launched(), "finish")
	eq(done.phase, "complete", "closed")
	for action in ALL_ACTIONS: eq(engine.act(done, action), done, "%s after finish" % action)
	eq(engine.move_rover(done, Vector3(3, 0, 3)), done, "move after finish")

func test_unknown_command_and_bounded_log() -> void:
	var before: Dictionary = launched()
	var after: Dictionary = engine.act(before, "teleport")
	unchanged_except_log(after, before, "unknown command")
	check("Unrecognised" in last_log(after), "explains")
	var s: Dictionary = before
	for i in range(20): s = engine.act(s, "transmit")
	eq(s.log.size(), Rules.MAX_LOG_LINES, "log bounded")

func test_report_score_and_losses() -> void:
	var lost: Dictionary = engine.act(investigate(launched(SCANNER), "minerals", ["scan"]), "finish")
	var report: Dictionary = engine.get_report(lost)
	eq(report.score, 0, "nothing returned, no station")
	eq(report.science_lost, 15, "untransmitted science lost")
	eq(report.outpost_operational, false, "no station")

	var s: Dictionary = investigate(launched(SCANNER), "minerals", ["scan"])
	s = run_actions(at(s, Vector3(0, 0, 0)), ["transmit", "deploy", "finish"])
	eq(engine.get_report(s).score, 39, "15/120 x 70 = 8.75, + 30 station")

	var full: Dictionary = launched()
	for kind in ["ice", "minerals", "geology"]: full = investigate(full, kind)
	full = run_actions(at(with_energy(full, 100.0), Vector3.ZERO), ["transmit", "deploy", "finish"])
	report = engine.get_report(full)
	eq(report.score, 100, "everything returned plus station")
	eq(report.science_returned, 120, "all science")
	eq(report.confirmed_sites + report.ruled_out_sites, 3, "every site settled")
	for key in ["score", "confirmed_sites", "ruled_out_sites", "science_returned", "science_lost", "outpost_operational"]:
		check(report.has(key), "report has %s" % key)

func test_replay_reproduces_state() -> void:
	var script: Array = []
	for i in range(1, 40): script.append(Vector3(i, 0, -i * 0.6))
	var run_once := func() -> Dictionary:
		var s: Dictionary = launched(DRILL, 2026)
		for p in script: s = engine.move_rover(s, p)
		s = investigate(s, "minerals")
		return run_actions(s, ["transmit", "recharge", "deploy", "finish"])
	eq(run_once.call(), run_once.call(), "same seed and inputs, same state")

func test_site_layouts_are_seeded_and_playable() -> void:
	check(engine.create_mission(DRILL, 1).sites != engine.create_mission(DRILL, 2).sites, "seeds differ")
	for mission_seed in range(-200, 800):
		var sites: Array = engine.create_mission(DRILL, mission_seed).sites
		eq(sites.size(), 3, "three sites")
		for entry in sites:
			check(absf(entry.position.x) <= 78.0 and absf(entry.position.z) <= 78.0, "inside map")
			check(Engine_.flat_distance(entry.position, Vector3.ZERO) > 6.0, "not in range of the landing point")
		check(site({"sites": sites}, "ice").position.x < -18.0, "ice signal in the shadow")
		for i in range(3):
			for j in range(i + 1, 3):
				check(Engine_.flat_distance(sites[i].position, sites[j].position) > 12.0, "at most one site in range")
