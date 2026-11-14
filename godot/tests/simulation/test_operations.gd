extends "res://tests/simulation/test_case.gd"
## Scan/sample progression, duplicate rewards, recharging, transmission and station deployment.

func test_scan_requires_interaction_range() -> void:
	var s: Dictionary = launched()
	var target: Vector3 = site(s, "minerals").position
	var outside: Dictionary = at(s, target - Vector3(6.1, 0, 0))
	var after: Dictionary = engine.act(outside, "scan")
	unchanged_except_log(after, outside, "out of range")
	check(engine.act(at(s, target - Vector3(6.0, 0, 0)), "scan").sites[1].scanned, "works at exactly 6 m")

func test_scan_rewards_once() -> void:
	var before: Dictionary = at(launched(), site(launched(), "minerals").position)
	var once: Dictionary = engine.act(before, "scan")
	eq(once.science_collected, 15, "scan science")
	near(once.energy, before.energy - 4.0, "scan energy")
	eq(site(once, "minerals").finding, "probable", "preliminary evidence")
	var twice: Dictionary = engine.act(once, "scan")
	unchanged_except_log(twice, once, "duplicate scan gives nothing")

func test_scan_without_power_records_nothing() -> void:
	var low: Dictionary = with_energy(at(launched(), site(launched(), "minerals").position), 3.9)
	unchanged_except_log(engine.act(low, "scan"), low, "insufficient power")

func test_sample_rules() -> void:
	var scanner_scanned: Dictionary = investigate(launched(SCANNER), "minerals", ["scan"])
	var no_drill: Dictionary = engine.act(scanner_scanned, "sample")
	unchanged_except_log(no_drill, scanner_scanned, "needs a drill")
	check("drill" in last_log(no_drill), "explains the drill")

	var unscanned: Dictionary = at(launched(), site(launched(), "minerals").position)
	unchanged_except_log(engine.act(unscanned, "sample"), unscanned, "needs a scan first")

	var scanned: Dictionary = engine.act(unscanned, "scan")
	var sampled: Dictionary = engine.act(scanned, "sample")
	eq(sampled.science_collected, 40, "scan + sample science")
	near(sampled.energy, scanned.energy - 8.0, "sample energy")
	check(site(sampled, "minerals").sampled, "sampled")
	unchanged_except_log(engine.act(sampled, "sample"), sampled, "duplicate sample gives nothing")

func test_total_science_capped_however_often_actions_repeat() -> void:
	var s: Dictionary = launched()
	for kind in ["ice", "minerals", "geology"]:
		s = investigate(s, kind, ["scan", "scan", "sample", "sample", "scan"])
	eq(s.science_collected, 120, "3 x (15 + 25)")

func test_solar_recharge_needs_sunlight() -> void:
	var shaded: Dictionary = with_energy(at(launched(), Vector3(-18.01, 0, 0)), 20.0)
	unchanged_except_log(engine.act(shaded, "recharge"), shaded, "x < -18 is shaded")
	var boundary: Dictionary = engine.act(with_energy(at(launched(), Vector3(-18, 0, 0)), 20.0), "recharge")
	near(boundary.energy, 60.0, "x = -18 is lit; +40")
	near(engine.act(with_energy(launched(), 90.0), "recharge").energy, 100.0, "capped at capacity")
	var full: Dictionary = launched()
	unchanged_except_log(engine.act(full, "recharge"), full, "already full")
	var solar: Dictionary = launched()
	for i in range(5): solar = engine.act(with_energy(solar, 0.0), "recharge")
	eq(solar.fuel_cells, 0, "solar never uses fuel cells")

func test_fuel_cells_are_finite_and_work_in_shade() -> void:
	var s: Dictionary = at(launched(FUEL_SCANNER), Vector3(-60, 0, 0))
	for used in range(1, 4):
		s = engine.act(with_energy(s, 0.0), "recharge")
		near(s.energy, 40.0, "fuel cell %d" % used)
		eq(s.fuel_cells, 3 - used, "supplies left")
	var empty: Dictionary = with_energy(s, 0.0)
	unchanged_except_log(engine.act(empty, "recharge"), empty, "no supplies left")

func test_transmit_returns_onboard_science_once() -> void:
	var nothing: Dictionary = launched()
	unchanged_except_log(engine.act(nothing, "transmit"), nothing, "nothing to send")
	var scanned: Dictionary = investigate(launched(), "minerals", ["scan"])
	var sent: Dictionary = engine.act(scanned, "transmit")
	eq(sent.science_returned, 15, "returned")
	near(sent.energy, scanned.energy - 3.0, "transmit energy")
	unchanged_except_log(engine.act(sent, "transmit"), sent, "second transmit")
	var low: Dictionary = with_energy(scanned, 2.9)
	unchanged_except_log(engine.act(low, "transmit"), low, "insufficient power keeps science onboard")

func test_station_deployment_rules_and_persistence() -> void:
	var shaded: Dictionary = at(launched(), Vector3(-30, 0, 5))
	unchanged_except_log(engine.act(shaded, "deploy"), shaded, "needs sunlight")
	var low: Dictionary = with_energy(launched(), 11.9)
	unchanged_except_log(engine.act(low, "deploy"), low, "needs power")

	var placed: Dictionary = engine.act(at(launched(), Vector3(4, 1.2, -3)), "deploy")
	check(placed.outpost_deployed, "deployed")
	eq(placed.outpost_position, Vector3(4, 1.2, -3), "records the rover position")
	near(placed.energy, 100.0 - 12.0, "deploy energy")
	var driven: Dictionary = placed
	for p in [Vector3(10, 0, -3), Vector3(10, 0, 10), Vector3(-5, 0, 20)]: driven = engine.move_rover(driven, p)
	eq(driven.outpost_position, Vector3(4, 1.2, -3), "rover moves do not move the station")
	var again: Dictionary = engine.act(at(driven, Vector3(30, 0, 30)), "deploy")
	eq(again.outpost_position, Vector3(4, 1.2, -3), "repeat deployment elsewhere is rejected")
	eq(engine.act(again, "finish").outpost_position, Vector3(4, 1.2, -3), "persists into the closed mission")
