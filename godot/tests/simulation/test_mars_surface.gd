extends "res://tests/simulation/test_case.gd"
## Stage 3: destination-aware surface missions (Mars) without changing the lunar contract.
const Destinations = preload("res://simulation/destinations.gd")

func mars(config: Dictionary = DRILL, mission_seed: int = 42) -> Dictionary:
	return engine.act(engine.create_surface_mission(config, mission_seed, "mars"), "launch")

func test_lunar_contract_is_unchanged() -> void:
	var v1: Dictionary = engine.create_mission(DRILL, 42)
	for key in ["destination", "integrity", "impact_cooldown", "elapsed_seconds", "weather"]:
		check(not v1.has(key), "create_mission keeps the v1 schema (no %s)" % key)
	eq(v1.sites[0].position.x < -30.0 and v1.sites[0].position.x > -40.0, true, "v1 sites keep the ±78 m layout")
	eq(engine.surface_rules(v1), Rules.MOON, "v1 states use the original lunar rules")
	near(engine.move_rover(engine.act(v1, "launch"), Vector3(200, 0, 0)).position.x, 78.0, "v1 missions stay clamped to ±78 m")
	var region: Dictionary = engine.create_surface_mission(DRILL, 42, "moon")
	eq(region.destination, "moon", "destination recorded")
	check(float(engine.surface_rules(region).map_limit) > 78.0, "expanded lunar survey region for spaceflight")
	eq(region.integrity, 100.0, "campaign fields present on destination missions")

func test_landmarks_and_unknown_destinations_have_no_surface_mission() -> void:
	eq(engine.create_surface_mission(DRILL, 1, "earth"), {}, "Earth is a landmark")
	eq(engine.create_surface_mission(DRILL, 1, "pluto"), {}, "unknown")

func test_mars_mission_uses_its_own_sites_and_rules() -> void:
	var s: Dictionary = mars()
	eq(s.destination, "mars", "destination")
	eq(s.phase, "surface", "launches with a valid design")
	var ids: Array = []
	for entry in s.sites: ids.append(entry.id)
	eq(ids, ["mars-a", "mars-b", "mars-c"], "distinct site ids")
	check("Aurora Delta" in s.log[1], "Mars briefing")
	for entry in s.sites: check(entry.finding == "unconfirmed" and entry.confidence >= 15 and entry.confidence <= 30, "orbital evidence")

func test_mars_driving_costs_more_per_metre() -> void:
	near(engine.move_rover(mars(), Vector3(10, 0, 0)).energy, 100.0 - 2.0, "0.2 per metre on Mars")
	near(engine.move_rover(launched(), Vector3(10, 0, 0)).energy, 100.0 - 1.6, "0.16 per metre on the Moon")

func test_mars_solar_power_is_weaker_but_works_everywhere() -> void:
	var west: Dictionary = engine.act(with_energy(at(mars(), Vector3(-70, 0, 0)), 10.0), "recharge")
	near(west.energy, 10.0 + 40.0 * 0.43, "solar 43% of the Moon's output, no shadow zone")
	var cells: Dictionary = engine.act(with_energy(at(mars(FUEL_SCANNER), Vector3(-70, 0, 0)), 10.0), "recharge")
	near(cells.energy, 50.0, "fuel cells deliver full output on Mars")

func test_mars_science_is_worth_more_but_samples_must_be_flown_home() -> void:
	var s: Dictionary = investigate(mars(), "minerals")
	eq(s.science_collected, 55, "scan 20 + sample 35")
	var sent: Dictionary = engine.act(s, "transmit")
	eq(sent.science_returned, 20, "only scan data is radioed home")
	near(sent.energy, s.energy - 6.0, "longer relay costs more")
	var again: Dictionary = engine.act(sent, "transmit")
	unchanged_except_log(again, sent, "sample science cannot be transmitted")
	check("flown home" in last_log(again), "explains sample return")
	var report: Dictionary = engine.get_report(engine.act(sent, "finish"))
	eq(report.science_returned, 20, "report counts transmitted data")

func test_mars_evidence_is_independent_of_the_moon() -> void:
	var same: int = 0
	var fakes: int = 0
	for mission_seed in range(600):
		var moon_fake: bool = Evidence.is_false_positive(mission_seed, site(engine.create_mission(DRILL, mission_seed), "ice"))
		var mars_fake: bool = Evidence.is_false_positive(mission_seed, site(engine.create_surface_mission(DRILL, mission_seed, "mars"), "ice"))
		if moon_fake == mars_fake: same += 1
		if mars_fake: fakes += 1
	check(same < 500, "outcomes are not copied between worlds (%d/600 equal)" % same)
	check(absf(fakes / 600.0 - 0.35) < 0.07, "Mars ice false-positive rate %.2f" % (fakes / 600.0))

func test_mars_findings_are_reproducible_and_never_reroll() -> void:
	var a: Dictionary = mars(DRILL, 9)
	var b: Dictionary = mars(DRILL, 9)
	for kind in ["ice", "minerals", "geology"]:
		a = investigate(a, kind)
		b = investigate(b, kind, ["scan", "sample", "scan", "sample"])
	eq(a.sites, b.sites, "same seed, same results, repeats ignored")

func test_mars_layouts_are_playable() -> void:
	var rules: Dictionary = Destinations.surface_rules("mars")
	var pad: Vector3 = Destinations.get_def("mars").pad
	for mission_seed in range(500):
		var sites: Array = engine.create_surface_mission(DRILL, mission_seed, "mars").sites
		for entry in sites:
			check(absf(entry.position.x) <= float(rules.map_limit) and absf(entry.position.z) <= float(rules.map_limit), "inside the Mars region")
			check(Engine_.flat_distance(entry.position, Vector3.ZERO) > 6.0 and Engine_.flat_distance(entry.position, pad) > 6.0, "clear of landing point and pad")
		for i in range(3):
			for j in range(i + 1, 3):
				check(Engine_.flat_distance(sites[i].position, sites[j].position) > 2.0 * float(rules.interaction_range), "one site in range at a time")

func test_mars_report_scales_to_its_science() -> void:
	var s: Dictionary = mars()
	for kind in ["ice", "minerals", "geology"]: s = investigate(s, kind, ["scan"])
	s = run_actions(at(with_energy(s, 100.0), Vector3.ZERO), ["transmit", "deploy", "finish"])
	eq(engine.get_report(s).score, roundi(60.0 / 165.0 * 70.0 + 30.0), "60 of 165 possible science, plus station")
