extends "res://tests/simulation/test_case.gd"
## Hidden seeded false positives, integer finding confidence and no rerolls.

const RANK: Dictionary = {"unconfirmed": 0, "probable": 1, "confirmed": 2, "ruled-out": 2}

func _within(value: int, bounds: Vector2i) -> bool:
	return value >= bounds.x and value <= bounds.y

func test_orbital_findings_start_unconfirmed_in_range() -> void:
	for mission_seed in range(300):
		for entry in engine.create_mission(DRILL, mission_seed).sites:
			eq(entry.finding, "unconfirmed", "finding")
			check(entry.confidence is int and _within(entry.confidence, Evidence.ORBITAL), "orbital confidence %s" % entry.confidence)

func test_transitions_follow_the_hidden_truth() -> void:
	for mission_seed in range(300):
		var s: Dictionary = launched(DRILL, mission_seed)
		for kind in ["ice", "minerals", "geology"]:
			var fake: bool = Evidence.is_false_positive(mission_seed, site(s, kind))
			s = investigate(s, kind, ["scan"])
			eq(site(s, kind).finding, "probable", "scan -> probable")
			check(_within(site(s, kind).confidence, Evidence.SCAN_FALSE_POSITIVE if fake else Evidence.SCAN_GENUINE), "scan confidence range")
			s = investigate(s, kind, ["sample"])
			eq(site(s, kind).finding, "ruled-out" if fake else "confirmed", "sample settles it")
			check(_within(site(s, kind).confidence, Evidence.RULED_OUT if fake else Evidence.CONFIRMED), "sample confidence range")

func test_scanner_only_stops_at_probable_and_sample_before_scan_changes_nothing() -> void:
	eq(site(investigate(launched(SCANNER), "ice"), "ice").finding, "probable", "no drill")
	var before: Dictionary = launched()
	eq(site(investigate(before, "ice", ["sample"]), "ice"), site(before, "ice"), "no scan yet")

func test_findings_never_move_backward_over_random_play() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var s: Dictionary = launched(DRILL, 11)
	var actions: Array[String] = ["scan", "sample", "recharge", "transmit"]
	for i in range(2000):
		var previous: Dictionary = s
		if rng.randf() < 0.3:
			var target: Dictionary = s.sites[rng.randi_range(0, 2)]
			s = engine.move_rover(s, s.position.move_toward(target.position, 6.0))
		elif rng.randf() < 0.6:
			s = engine.act(s, actions[rng.randi_range(0, actions.size() - 1)])
		else:
			s = engine.move_rover(s, s.position + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)))
		for k in range(s.sites.size()):
			var a: Dictionary = previous.sites[k]
			var b: Dictionary = s.sites[k]
			check(RANK[b.finding] >= RANK[a.finding], "finding moved backward")
			if RANK[a.finding] == 2: check(a == b, "settled site changed")
			check(b.confidence is int and b.confidence >= 0 and b.confidence <= 100, "confidence integer 0-100")

func test_geology_is_never_a_false_positive() -> void:
	for mission_seed in range(2000): check(not truth(mission_seed, "geology"), "geology seed %d" % mission_seed)

func test_ice_and_mineral_false_positive_rates() -> void:
	for kind in ["ice", "minerals"]:
		var fakes: int = 0
		for mission_seed in range(2000):
			if truth(mission_seed, kind): fakes += 1
		var rate: float = fakes / 2000.0
		check(absf(rate - Evidence.FALSE_POSITIVE_CHANCE[kind]) < 0.05, "%s rate %.3f" % [kind, rate])

func test_same_seed_same_outcomes_in_separate_missions() -> void:
	for mission_seed in [0, 7, 42, 99, 12345]:
		var a: Dictionary = launched(DRILL, mission_seed)
		var b: Dictionary = launched(DRILL, mission_seed)
		for kind in ["ice", "minerals", "geology"]:
			a = investigate(a, kind)
			b = investigate(b, kind)
		eq(a.sites, b.sites, "seed %d" % mission_seed)

func test_outcomes_do_not_depend_on_visit_order_or_equipment() -> void:
	for mission_seed in [1, 5, 77, 314]:
		var forward: Dictionary = launched(DRILL, mission_seed)
		var backward: Dictionary = launched(DRILL, mission_seed)
		for kind in ["ice", "minerals", "geology"]: forward = investigate(forward, kind)
		for kind in ["geology", "minerals", "ice"]: backward = investigate(backward, kind)
		eq(backward.sites, forward.sites, "order seed %d" % mission_seed)
		var scanner_only: Dictionary = launched(SCANNER, mission_seed)
		var drill_scan: Dictionary = launched(DRILL, mission_seed)
		for kind in ["ice", "minerals", "geology"]:
			scanner_only = investigate(scanner_only, kind, ["scan"])
			drill_scan = investigate(drill_scan, kind, ["scan"])
		eq(scanner_only.sites, drill_scan.sites, "design seed %d" % mission_seed)

func test_revisits_and_repeats_cannot_reroll() -> void:
	var mission_seed: int = find_seed(func(n: int) -> bool: return truth(n, "ice"))
	var s: Dictionary = investigate(launched(DRILL, mission_seed), "ice")
	var settled: Dictionary = site(s, "ice").duplicate(true)
	eq(settled.finding, "ruled-out", "false positive found")
	s = engine.move_rover(s, s.position + Vector3(20, 0, 0))
	var science: int = s.science_collected
	s = investigate(s, "ice", ["scan", "sample", "scan", "sample"])
	eq(site(s, "ice"), settled, "revisit leaves the result")
	eq(s.science_collected, science, "no repeated science")

func test_ruled_out_signal_still_earns_science() -> void:
	var mission_seed: int = find_seed(func(n: int) -> bool: return truth(n, "minerals"))
	var s: Dictionary = investigate(launched(DRILL, mission_seed), "minerals")
	eq(site(s, "minerals").finding, "ruled-out", "ruled out")
	eq(s.science_collected, 40, "full scan + sample science")
	var report: Dictionary = engine.get_report(engine.act(s, "finish"))
	eq(report.confirmed_sites, 0, "not confirmed")
	eq(report.ruled_out_sites, 1, "ruled out counted")

func test_hidden_truth_is_not_stored_in_state() -> void:
	var s: Dictionary = launched()
	for entry in s.sites:
		eq(entry.keys().size(), 8, "site keys: id, name, kind, position, scanned, sampled, finding, confidence")
		for key in entry: check(not str(key) in ["truth", "false_positive", "genuine"], "no hidden truth key")
