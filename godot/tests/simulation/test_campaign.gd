extends "res://tests/simulation/test_case.gd"
## First Light campaign: progress, checkpoints, recovery and no duplicate rewards.
const Campaign = preload("res://simulation/campaign.gd")
const Expedition = preload("res://simulation/expedition.gd")
const Destinations = preload("res://simulation/destinations.gd")
const Travel = preload("res://simulation/travel.gd")
const DT: float = 1.0 / 30.0

func begun(campaign_seed: int = 42) -> Dictionary:
	return Campaign.begin(Campaign.create(DRILL, "standard", campaign_seed))

func land_with_assist(state: Dictionary, id: String) -> Dictionary:
	var s: Dictionary = Expedition.begin_landing(state, id, true)
	for i in range(8000):
		if s.phase != "landing": break
		s = Expedition.step_landing(s, {}, DT)
	return Campaign.evaluate(s)

## Pure-state helpers (the driven scene route tests the same journey without any of these).
func rover_to(state: Dictionary, position: Vector3) -> Dictionary:
	var s: Dictionary = state.duplicate(true)
	s.missions[s.location].position = position
	s.missions[s.location].energy = s.missions[s.location].max_energy
	return Campaign.evaluate(s)

func act(state: Dictionary, action: String) -> Dictionary:
	return Campaign.evaluate(Expedition.rover_act(state, action))

func site_pos(state: Dictionary, kind: String) -> Vector3:
	return site(Expedition.mission(state), kind).position

func park_above(state: Dictionary, id: String) -> Dictionary:
	var s: Dictionary = state.duplicate(true)
	var body: Dictionary = Destinations.get_def(id).space
	s.ship.position = body.position + Vector3.UP * (float(body.radius) + 30.0)
	s.ship.velocity = Vector3.ZERO
	return s

func pad(state: Dictionary) -> Vector3:
	return Destinations.get_def(state.location).pad + Vector3(0, 0, 4)

func completed(state: Dictionary) -> Array:
	return state.campaign.completed

func moon_chapter(campaign_seed: int = 42) -> Dictionary:
	var s: Dictionary = Campaign.evaluate(Expedition.disembark(land_with_assist(begun(campaign_seed), "moon")))
	s = rover_to(s, Destinations.surface_rules("moon").waypoints.ridge)
	s = act(rover_to(s, site_pos(s, "ice")), "scan")
	s = act(rover_to(s, site_pos(s, "geology")), "scan")
	s = act(rover_to(s, Destinations.surface_rules("moon").waypoints.station), "deploy")
	return Campaign.evaluate(Expedition.board(rover_to(s, pad(s))))

func mars_chapter(state: Dictionary) -> Dictionary:
	var s: Dictionary = Campaign.evaluate(Expedition.takeoff(state, "mars"))
	s = Campaign.evaluate(Expedition.disembark(land_with_assist(park_above(s, "mars"), "mars")))
	s = act(act(rover_to(s, site_pos(s, "geology")), "scan"), "sample")
	return s

func ride_out_storm(state: Dictionary) -> Dictionary:
	var s: Dictionary = state
	for i in range(int(60.0 / 0.5)):
		s.missions.mars = engine.advance_surface(s.missions.mars, 0.5)
		s = Campaign.evaluate(s)
		if "mars-storm" in completed(s): break
	return s

func test_campaign_needs_the_drill() -> void:
	check(not Campaign.review(SCANNER, "standard").warnings.is_empty(), "scanner-only blocked")
	check(Campaign.review(DRILL, "standard").warnings.is_empty(), "drill allowed")
	eq(Campaign.begin(Campaign.create(SCANNER, "standard", 1)).phase, "planning", "cannot begin")

func test_begins_in_lunar_orbit_ready_for_a_manual_landing() -> void:
	var s: Dictionary = begun()
	eq(s.phase, "flight", "in flight")
	eq(s.campaign.objective, "moon-landing", "first objective")
	check(Travel.guidance(s.ship, "moon").can_land, "already inside the Moon's approach zone")
	check(not s.campaign.flight_checkpoint.is_empty(), "recovery point for the first descent")
	check(not Campaign.BRIEFING.is_empty(), "short briefing")

func test_moon_chapter_completes_from_authoritative_actions() -> void:
	var s: Dictionary = moon_chapter()
	for id in ["moon-landing", "moon-ridge", "moon-ice", "moon-geology", "moon-station", "moon-return"]:
		check(id in completed(s), id)
	eq(s.campaign.objective, "mars-landing", "next: Mars")
	eq(s.campaign.chapter, "mars", "chapter advanced")
	eq(s.missions.moon.science_returned, 30, "ship relayed the two scans on boarding")

func test_ruling_a_signal_out_still_completes_an_objective() -> void:
	var fake_seed: int = find_seed(func(n: int) -> bool: return Evidence.is_false_positive(n, site(engine.create_surface_mission(DRILL, n, "moon"), "ice")))
	var s: Dictionary = Campaign.evaluate(Expedition.disembark(land_with_assist(begun(fake_seed), "moon")))
	s = act(act(rover_to(s, site_pos(s, "ice")), "scan"), "sample")
	eq(site(Expedition.mission(s), "ice").finding, "ruled-out", "false positive ruled out")
	check("moon-ice" in completed(s), "objective still complete")

func test_objectives_can_be_done_out_of_order_but_returns_wait_for_the_chapter() -> void:
	var s: Dictionary = Campaign.evaluate(Expedition.disembark(land_with_assist(begun(), "moon")))
	s = act(rover_to(s, site_pos(s, "geology")), "scan")
	check("moon-geology" in completed(s), "geology before the ridge counts")
	eq(s.campaign.objective, "moon-ridge", "current objective is the first unfinished one")
	var early: Dictionary = Campaign.evaluate(Expedition.board(rover_to(s, pad(s))))
	check(not "moon-return" in completed(early), "boarding early does not finish the chapter")

func test_mars_chapter_storm_and_delivery() -> void:
	var s: Dictionary = mars_chapter(moon_chapter())
	for id in ["mars-landing", "mars-layers", "mars-core"]: check(id in completed(s), id)
	eq(s.campaign.objective, "mars-storm", "storm objective")
	check(s.missions.mars.weather.next_storm_at <= s.missions.mars.elapsed_seconds + Campaign.STORM_FORECAST_SECONDS + 0.001, "storm forecast soon, no long wait")
	s = ride_out_storm(s)
	check("mars-storm" in completed(s), "storm weathered (outdoors is fine)")
	s = Campaign.evaluate(Expedition.board(rover_to(s, pad(s))))
	eq(s.cores.size(), 1, "one core aboard")
	s = Campaign.evaluate(Expedition.takeoff(s, "moon"))
	s = land_with_assist(park_above(s, "moon"), "moon")
	check("mars-return" in completed(s), "core delivered")
	eq(s.delivered_science, 35, "35 science delivered")
	s = Campaign.evaluate(Expedition.finish(s))
	check(Campaign.is_complete(s), "campaign complete")
	var summary: Dictionary = Campaign.summary(s)
	eq(summary.completed, summary.total, "summary counts every objective")

func test_surface_recovery_returns_to_the_checkpoint_without_changing_evidence() -> void:
	var s: Dictionary = mars_chapter(moon_chapter())
	s = rover_to(s, Destinations.surface_rules("mars").shelter.position)
	check("mars-shelter" in s.campaign.reached, "shelter checkpoint saved")
	var lost: Dictionary = s.duplicate(true)
	lost.missions.mars.position = Vector3(200, 0, 200)
	lost.missions.mars.energy = 1.0
	var r: Dictionary = Campaign.recover(lost)
	eq(r.missions.mars.position, s.campaign.checkpoint.position, "back at the checkpoint")
	near(r.missions.mars.energy, 0.6 * r.missions.mars.max_energy, "battery topped up")
	for key in ["science_collected", "science_returned", "sites", "outpost_deployed", "outpost_position"]:
		eq(r.missions.mars[key], lost.missions.mars[key], "%s unchanged" % key)
	eq(r.missions.moon, lost.missions.moon, "Moon untouched")
	eq(r.campaign.completed, lost.campaign.completed, "progress kept")
	eq(r.cores, lost.cores, "no cores created")
	eq(r.campaign.recoveries, 1, "recovery counted")
	var twice: Dictionary = Campaign.recover(Campaign.recover(r))
	eq(twice.missions.mars.science_collected, lost.missions.mars.science_collected, "repeated recovery adds nothing")

func test_flight_and_landing_recovery() -> void:
	var s: Dictionary = Campaign.evaluate(Expedition.takeoff(moon_chapter(), "mars"))
	var start: Dictionary = s.campaign.flight_checkpoint.ship
	var drifted: Dictionary = s.duplicate(true)
	drifted.ship.position = Vector3(3000, 0, 0)
	drifted.ship.velocity = Vector3(80, 0, 0)
	drifted.ship.fuel = 5.0
	var r: Dictionary = Campaign.recover(drifted)
	eq(r.ship, start, "flight leg restarts just after the ascent")
	eq(r.missions, drifted.missions, "missions untouched")
	var descending: Dictionary = Expedition.begin_landing(park_above(s, "mars"), "mars")
	var fuel_after_burn: float = descending.ship.fuel
	var crashed: Dictionary = descending
	for i in range(4000):
		if crashed.landing.status != "descending": break
		crashed = Expedition.step_landing(crashed, {"throttle": 0.0}, DT)
	var retried: Dictionary = Campaign.recover(crashed)
	eq(retried.landing.status, "descending", "descent restarts from the approach")
	eq(retried.ship.fuel, fuel_after_burn, "no extra fuel charged")

func test_recovery_after_delivery_never_duplicates_science_or_cores() -> void:
	var s: Dictionary = ride_out_storm(mars_chapter(moon_chapter()))
	s = Campaign.evaluate(Expedition.takeoff(Expedition.board(rover_to(s, pad(s))), "moon"))
	s = Campaign.evaluate(Expedition.disembark(land_with_assist(park_above(s, "moon"), "moon")))
	var delivered: int = s.delivered_science
	for i in range(3): s = Campaign.recover(s)
	eq(s.delivered_science, delivered, "delivered science unchanged")
	eq(s.delivered.size(), 1, "one delivered core")
	eq(s.cores, [], "no cores reappear")
	s = Campaign.evaluate(Expedition.board(rover_to(s, pad(s))))
	eq(s.delivered.size(), 1, "re-boarding at home creates nothing")

func test_checkpoint_beacons_reflect_progress() -> void:
	var s: Dictionary = Campaign.evaluate(Expedition.disembark(land_with_assist(begun(), "moon")))
	var beacons: Array = Campaign.checkpoints_for(s, "moon")
	var by_id: Dictionary = {}
	for b in beacons: by_id[b.id] = b
	for key in ["id", "title", "position", "completed", "active"]: check(beacons[0].has(key), "beacon has %s" % key)
	check(by_id["moon-landing"].completed, "landing done")
	check(by_id["moon-ridge"].active, "ridge active")
	eq(by_id["moon-ridge"].position, Destinations.surface_rules("moon").waypoints.ridge, "ridge waypoint")
	eq(by_id["moon-ice"].position, site_pos(s, "ice"), "ice beacon at the real site position")
	var mars_beacons: Array = Campaign.checkpoints_for(mars_chapter(moon_chapter()), "mars")
	check(mars_beacons.any(func(b: Dictionary) -> bool: return b.id == "mars-shelter"), "shelter beacon on Mars")

func test_campaign_functions_are_pure_and_reproducible() -> void:
	var s: Dictionary = mars_chapter(moon_chapter())
	var snapshot: Dictionary = s.duplicate(true)
	Campaign.evaluate(s)
	Campaign.recover(s)
	Campaign.checkpoints_for(s, "mars")
	eq(s, snapshot, "inputs unchanged")
	eq(mars_chapter(moon_chapter(9)), mars_chapter(moon_chapter(9)), "same seed and actions, same campaign")

func test_agreed_expedition_entry_points() -> void:
	var s: Dictionary = Campaign.evaluate(Expedition.disembark(land_with_assist(begun(), "moon")))
	eq(Expedition.checkpoint_list(s), Campaign.checkpoints_for(s, "moon"), "checkpoint_list = current location's beacons")
	var lost: Dictionary = s.duplicate(true)
	lost.missions.moon.position = Vector3(100, 0, 100)
	eq(Expedition.recover_checkpoint(lost), Campaign.recover(lost), "recover_checkpoint = campaign recovery")
	var plain: Dictionary = Expedition.begin(Expedition.create(DRILL, "standard", 1))
	eq(Expedition.recover_checkpoint(plain), plain, "no campaign: nothing changes")
	eq(Expedition.checkpoint_list(plain), [], "no campaign: no beacons")
