extends "res://tests/simulation/test_case.gd"
## Stage 4: the expedition loop and its consequences.
const Expedition = preload("res://simulation/expedition.gd")
const Ship = preload("res://simulation/ship_flight.gd")
const Travel = preload("res://simulation/travel.gd")
const Destinations = preload("res://simulation/destinations.gd")
const Autopilot = preload("res://spaceflight/autopilot.gd")


func started(config: Dictionary = DRILL, fuel_load: String = "standard", expedition_seed: int = 42) -> Dictionary:
	return Expedition.begin(Expedition.create(config, fuel_load, expedition_seed))

## Put the rover somewhere on the current destination (pure state, so tests may place it).
func rover_at(state: Dictionary, position: Vector3, energy: float = -1.0) -> Dictionary:
	var s: Dictionary = state.duplicate(true)
	s.missions[s.location].position = position
	if energy >= 0.0: s.missions[s.location].energy = energy
	return s

func at_pad(state: Dictionary) -> Dictionary:
	return rover_at(state, Destinations.get_def(state.location).pad + Vector3(0, 0, 4))

func investigate_here(state: Dictionary, kind: String, actions: Array = ["scan", "sample"]) -> Dictionary:
	var m: Dictionary = Expedition.mission(state)
	var s: Dictionary = rover_at(state, site(m, kind).position, float(m.max_energy))
	for action in actions: s = Expedition.rover_act(s, action)
	return s

## Fly with player-equivalent inputs until landing is possible; returns {} if it never is.
func fly_and_land(state: Dictionary, id: String, cruise: float = 60.0, dt: float = 1.0 / 30.0) -> Dictionary:
	var s: Dictionary = state
	for i in range(8000):
		if Travel.guidance(s.ship, id).can_land: return Expedition.land(s, id)
		s = Expedition.fly(s, Autopilot.approach_input(s.ship, id, cruise), dt)
	return {}

func park_above(state: Dictionary, id: String) -> Dictionary:
	var s: Dictionary = state.duplicate(true)
	var body: Dictionary = Destinations.get_def(id).space
	s.ship.position = body.position + Vector3.UP * (float(body.radius) + 30.0)
	s.ship.velocity = Vector3.ZERO
	return s

func test_review_combines_rover_fuel_mass_and_delta_v() -> void:
	var r: Dictionary = Expedition.review(DRILL, "standard")
	eq(r.rover_mass, 87, "rover payload mass from the design review")
	near(r.ship_mass, 900.0 + 87.0 + 650.0, "ship mass")
	near(r.delta_v, 1000.0 * log(1637.0 / 987.0), "rocket-equation delta-v")
	check(r.margin > 60.0 and r.advice.is_empty(), "standard load: comfortable margin")
	var light: Dictionary = Expedition.review(DRILL, "light")
	check(light.margin < 0.0 and not light.advice.is_empty(), "light load: warned it is short at 60 u/s")
	check(light.warnings.is_empty(), "but it is a legal choice")
	var heavier: Dictionary = Expedition.review({"battery": "compact", "power": "solar", "instrument": "drill"}, "full")
	check(heavier.delta_v > r.delta_v, "more fuel, more delta-v")
	check(not Expedition.review(DRILL, "huge").warnings.is_empty(), "unknown fuel load")

func test_invalid_designs_cannot_begin() -> void:
	var s: Dictionary = Expedition.begin(Expedition.create(OVERWEIGHT, "standard", 1))
	eq(s.phase, "planning", "blocked")
	check(s.log[0].begins_with("Cannot begin"), "explains")

func test_begin_deploys_rover_on_the_moon_with_a_v1_lunar_mission() -> void:
	var s: Dictionary = started()
	eq(s.phase, "surface", "on the surface")
	eq(s.location, "moon", "at home")
	eq(Expedition.mission(s).phase, "surface", "rover mission launched")
	eq(Expedition.mission(s).sites[0].id, "a", "lunar contract v1 sites")

func test_boarding_requires_the_rover_at_the_ship() -> void:
	var far: Dictionary = Expedition.board(started())
	eq(far.phase, "surface", "too far from the pad")
	var drained: Dictionary = at_pad(rover_at(started(), Vector3.ZERO, 12.0))
	drained = at_pad(drained)
	drained.missions.moon.energy = 12.0
	var aboard: Dictionary = Expedition.board(drained)
	eq(aboard.phase, "aboard", "boarded")
	eq(aboard.cores, [], "no cores from the Moon (data can be transmitted)")
	eq(aboard.missions.moon.energy, aboard.missions.moon.max_energy, "ship recharges the stowed rover")

func test_takeoff_burns_ascent_fuel_or_strands_the_ship() -> void:
	var aboard: Dictionary = Expedition.board(at_pad(started()))
	var flying: Dictionary = Expedition.takeoff(aboard, "mars")
	eq(flying.phase, "flight", "in flight")
	near(aboard.ship.fuel - flying.ship.fuel, Travel.ascent_fuel(Ship.total_mass(aboard.ship), "moon"), "ascent fuel at current mass")
	var dry: Dictionary = aboard.duplicate(true)
	dry.ship.fuel = 10.0
	var stranded: Dictionary = Expedition.takeoff(dry, "mars")
	eq(stranded.phase, "aboard", "still on the pad")
	check(stranded.stranded and "Stranded" in stranded.log[0], "stranded and told why")

func test_landing_on_mars_creates_a_mars_mission_and_carries_fuel_cells_over() -> void:
	var s: Dictionary = started(FUEL_SCANNER)  # fuel cells + drill would exceed the budget
	s = rover_at(s, Vector3(-60, 0, 0), 5.0)
	s = Expedition.rover_act(s, "recharge")   # uses one of three shared fuel cells, in the lunar shadow
	eq(Expedition.mission(s).fuel_cells, 2, "one cell used on the Moon")
	s = Expedition.takeoff(Expedition.board(at_pad(s)), "mars")
	check(Expedition.land(s, "mars").log[0].begins_with("Landing refused"), "cannot land from the Moon's orbit")
	s = Expedition.land(park_above(s, "mars"), "mars")
	eq(s.phase, "aboard", "landed")
	eq(s.location, "mars", "on Mars")
	s = Expedition.disembark(s)
	eq(Expedition.mission(s).destination, "mars", "Mars mission")
	eq(Expedition.mission(s).fuel_cells, 2, "the same physical supply on Mars")
	check("mars" in s.visited, "visited")

func test_mars_samples_become_cores_that_add_mass_and_cost_fuel() -> void:
	var s: Dictionary = Expedition.land(park_above(Expedition.takeoff(Expedition.board(at_pad(started())), "mars"), "mars"), "mars")
	s = Expedition.disembark(s)
	for kind in ["ice", "minerals"]: s = investigate_here(s, kind)
	s = investigate_here(s, "geology", ["scan"])
	var empty_hold: float = Ship.total_mass(Expedition.board(at_pad(Expedition.disembark(Expedition.land(park_above(Expedition.takeoff(Expedition.board(at_pad(started())), "mars"), "mars"), "mars")))).ship)
	var aboard: Dictionary = Expedition.board(at_pad(s))
	eq(aboard.cores.size(), 2, "two sealed cores")
	near(Ship.total_mass(aboard.ship) - empty_hold, 12.0, "6 kg per core")
	check(Travel.ascent_fuel(Ship.total_mass(aboard.ship), "mars") > Travel.ascent_fuel(empty_hold, "mars"), "cores raise ascent fuel")
	var again: Dictionary = Expedition.board(at_pad(Expedition.disembark(aboard)))
	eq(again.cores.size(), 2, "re-boarding does not duplicate cores")

func test_delivering_cores_home_counts_sample_science() -> void:
	var s: Dictionary = Expedition.disembark(Expedition.land(park_above(Expedition.takeoff(Expedition.board(at_pad(started())), "mars"), "mars"), "mars"))
	s = investigate_here(s, "minerals")
	s = Expedition.rover_act(rover_at(s, Vector3.ZERO, 100.0), "transmit")
	s = Expedition.takeoff(Expedition.board(at_pad(s)), "moon")
	var before_home: Dictionary = Expedition.report(s)
	eq(before_home.cores_lost_science, 35, "core still in flight")
	s = Expedition.land(park_above(s, "moon"), "moon")
	eq(s.delivered_science, 35, "core delivered")
	eq(s.cores, [], "hold emptied")
	near(s.ship.cargo_mass, s.rover_mass, "cargo back to the rover alone")
	var r: Dictionary = Expedition.report(Expedition.finish(s))
	eq(r.science_returned, 20 + 35, "20 radioed + 35 delivered")
	check(r.home and not r.stranded, "ended at home")

func test_report_names_concrete_losses() -> void:
	var s: Dictionary = Expedition.disembark(Expedition.land(park_above(Expedition.takeoff(Expedition.board(at_pad(started())), "mars"), "mars"), "mars"))
	s = investigate_here(s, "ice")
	var r: Dictionary = Expedition.report(Expedition.finish(s))
	var text: String = " ".join(r.feedback)
	check("never stowed aboard" in text, "sample left on Mars")
	check("never transmitted" in text, "untransmitted data")
	check("away from the Moon base" in text, "ended away from home")
	eq(r.destinations.mars.samples_left_behind, 1, "counted")
	eq(r.science_possible, 120 + 165, "Moon + Mars possible science")

func test_expedition_score_principle() -> void:
	var s: Dictionary = started()
	s = Expedition.rover_act(rover_at(s, Vector3.ZERO), "deploy")
	var r: Dictionary = Expedition.report(Expedition.finish(s))
	eq(r.stations, 1, "one station")
	eq(r.score, 15, "15 per station, no science")

func test_closed_expedition_and_wrong_phase_actions_change_nothing_that_matters() -> void:
	var done: Dictionary = Expedition.finish(started())
	eq(done.phase, "complete", "closed")
	for next in [Expedition.board(done), Expedition.takeoff(done, "mars"), Expedition.rover_act(done, "scan"),
			Expedition.land(done, "mars"), Expedition.disembark(done), Expedition.fly(done, {"thrust": 1.0}, 1.0)]:
		eq(next.phase, "complete", "still complete")
		eq(next.ship, done.ship, "ship unchanged")
		eq(next.missions, done.missions, "missions unchanged")
	eq(Expedition.rover_move(started().duplicate(true), Vector3(1, 0, 0)).phase, "surface", "moves allowed on the surface")
	var aboard: Dictionary = Expedition.board(at_pad(started()))
	eq(Expedition.rover_move(aboard, Vector3(5, 0, 5)).missions, aboard.missions, "no driving while stowed")

func test_functions_never_mutate_inputs() -> void:
	var s: Dictionary = Expedition.board(at_pad(started()))
	var snapshot: Dictionary = s.duplicate(true)
	Expedition.takeoff(s, "mars")
	Expedition.disembark(s)
	Expedition.finish(s)
	Expedition.report(s)
	Expedition.rover_act(s, "scan")
	eq(s, snapshot, "aboard state unchanged")
	var flying: Dictionary = Expedition.takeoff(s, "mars")
	var flying_snapshot: Dictionary = flying.duplicate(true)
	Expedition.fly(flying, {"thrust": 1.0}, 0.5)
	Expedition.land(park_above(flying, "mars"), "mars")
	eq(flying, flying_snapshot, "flight state unchanged")

func _full_loop(fuel_load: String, cruise: float, expedition_seed: int = 7) -> Dictionary:
	var s: Dictionary = started(DRILL, fuel_load, expedition_seed)
	s = investigate_here(s, "minerals")
	s = Expedition.rover_act(rover_at(s, Vector3.ZERO, 100.0), "transmit")
	s = Expedition.takeoff(Expedition.board(at_pad(s)), "mars")
	var landed: Dictionary = fly_and_land(s, "mars", cruise)
	if landed.is_empty(): return Expedition.finish(s)
	s = Expedition.disembark(landed)
	for kind in ["ice", "minerals", "geology"]: s = investigate_here(s, kind)
	s = Expedition.rover_act(rover_at(s, Vector3.ZERO, 100.0), "transmit")
	s = Expedition.board(at_pad(s))
	var up: Dictionary = Expedition.takeoff(s, "moon")
	if up.phase != "flight": return Expedition.finish(up)
	var home: Dictionary = fly_and_land(up, "moon", cruise)
	if home.is_empty(): return Expedition.finish(up)
	return Expedition.finish(home)

func test_full_loop_with_standard_fuel_returns_evidence_home() -> void:
	var r: Dictionary = Expedition.report(_full_loop("standard", 60.0))
	check(r.home, "back at the Moon base")
	eq(r.delivered_science, 3 * 35, "three Mars cores delivered")
	eq(r.science_returned, 40 + 60 + 105, "Moon data + Mars data + Mars cores")
	check(r.fuel_left > 0.0, "fuel to spare")

func test_light_fuel_fails_at_60_but_succeeds_cruising_slowly() -> void:
	var fast: Dictionary = Expedition.report(_full_loop("light", 60.0))
	check(not fast.home, "light load at 60 u/s does not make it home")
	var slow: Dictionary = Expedition.report(_full_loop("light", 25.0))
	check(slow.home and slow.delivered_science == 105, "the same ship makes it at 25 u/s")

func test_same_seed_and_inputs_reproduce_the_expedition() -> void:
	eq(Expedition.report(_full_loop("standard", 60.0, 11)), Expedition.report(_full_loop("standard", 60.0, 11)), "reproducible")
