extends RefCounted
## Pure expedition simulation (Claude-owned): the Moon → Mars → Moon loop with consequences.
## No Nodes, input, rendering or wall-clock time. Every function returns a NEW state and never mutates input.
##
## phase: planning → surface ⇄ aboard ⇄ flight → complete
##   begin            planning → surface on the Moon (home base), rover deployed
##   rover_move/act   surface: drive and investigate (delegates to mission_engine.gd for that destination)
##   board            surface → aboard: rover within boarding range of the ship; sampled sites at
##                    sample-return destinations become sealed cores in the cargo hold (they add mass)
##   disembark        aboard → surface at the same destination
##   takeoff          aboard → flight: pays ascent fuel at the current mass (stranded if short)
##   fly              flight: ship physics with the proximity guard
##   land             flight → aboard: pays descent fuel; landing at home delivers carried cores (legacy, instant)
##   begin_landing    flight → landing: pays descent fuel ONCE, then the player flies the final descent
##   landing_step     landing → aboard on a safe touchdown (same delivery as land); unsafe → status failed
##   retry_landing    restart the final descent from the approach point; never charges fuel again
##   finish           any → complete
##
## Consequences: fuel load and rover payload set ship mass and delta-v (rocket equation); every sample core
## adds mass for the flight home; Mars solar power is weaker, so fuel cells (one shared supply) matter;
## only a drill yields sample science, and on Mars it only counts once cores reach home; transmitted data
## counts at once. All numbers are fictional except the labelled NASA facts in destinations.gd.
const MissionEngine = preload("res://simulation/mission_engine.gd")
const Design = preload("res://simulation/design.gd")
const Ship = preload("res://simulation/ship_flight.gd")
const Travel = preload("res://simulation/travel.gd")
const Destinations = preload("res://simulation/destinations.gd")
const Landing = preload("res://simulation/landing.gd")

const MAX_LOG_LINES: int = 10
const SCORE_SCIENCE_WEIGHT: float = 70.0
const SCORE_PER_STATION: float = 15.0   # up to two stations (Moon and Mars)

static var _engine = MissionEngine.new()

# ------------------------------------------------------------------------------------------- planning

## Combined review: rover equipment (budget/mass), fuel load, ship mass, delta-v and a rough round-trip need.
static func review(config: Dictionary, fuel_load: String) -> Dictionary:
	var rover: Dictionary = Design.review(config)
	var warnings: Array[String] = rover.warnings.duplicate()
	var fuel: float = float(Ship.FUEL_LOADS.get(fuel_load, -1.0))
	if fuel < 0.0:
		warnings.append("Choose a fuel load: light, standard or full.")
		fuel = 0.0
	var ship: Dictionary = Ship.create(fuel, float(rover.mass))
	var mass: float = Ship.total_mass(ship)
	var need: float = mars_round_trip_delta_v()
	var budget: float = Ship.delta_v_remaining(ship)
	var advice: Array[String] = []
	if budget < need:
		advice.append("Estimated Δv is %d u/s short of a Mars round trip at %d u/s cruise. Cruise slower or carry more fuel." % [ceili(need - budget), roundi(Travel.PLANNING_CRUISE)])
	elif budget - need < 60.0:
		advice.append("Thin margin: sample cores and extra manoeuvres will eat into %d u/s of spare Δv." % roundi(budget - need))
	return {"advice": advice, "rover": rover, "fuel_load": fuel_load, "fuel": fuel, "rover_mass": rover.mass, "ship_mass": mass,
		"delta_v": budget, "round_trip_delta_v": need, "margin": budget - need, "warnings": warnings}

## Delta-v for Moon ascent, cruise to Mars (accelerate + brake), Mars descent and ascent, cruise home and
## Moon descent, at Travel.PLANNING_CRUISE. A planning estimate: real piloting usually needs more.
static func mars_round_trip_delta_v() -> float:
	var cruise: float = 2.0 * Travel.PLANNING_CRUISE
	return Destinations.ascent_delta_v("moon") + cruise + Destinations.descent_delta_v("mars") \
		+ Destinations.ascent_delta_v("mars") + cruise + Destinations.descent_delta_v("moon")

static func create(config: Dictionary, fuel_load: String, expedition_seed: int) -> Dictionary:
	var r: Dictionary = review(config, fuel_load)
	return {
		"seed": expedition_seed, "phase": "planning", "location": Destinations.HOME,
		"config": config.duplicate(true), "fuel_load": fuel_load, "rover_mass": float(r.rover_mass),
		"ship": Ship.create(float(r.fuel), float(r.rover_mass)),
		"missions": {}, "rover_fuel_cells": 0, "cores": [], "collected": [], "delivered": [],
		"delivered_science": 0, "visited": [], "stranded": false,
		"log": ["Expedition planned. Explore the Moon, then fly to Mars and bring evidence home."],
	}

static func begin(original: Dictionary) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase != "planning": return _note(s, "The expedition has already begun.")
	var r: Dictionary = review(s.config, s.fuel_load)
	if not r.warnings.is_empty(): return _note(s, "Cannot begin. " + " ".join(r.warnings))
	s.phase = "surface"
	s.location = Destinations.HOME
	s.rover_fuel_cells = int(Destinations.surface_rules(Destinations.HOME).fuel_cell_supplies) if str(s.config.power) == "fuel-cell" else 0
	_ensure_mission(s, Destinations.HOME)
	s.visited.append(Destinations.HOME)
	return _note(s, "Rover deployed at the Moon base. The ship waits on the pad.")

# ------------------------------------------------------------------------------------------- surface

static func mission(state: Dictionary) -> Dictionary:
	return state.missions.get(state.location, {})

static func rover_move(original: Dictionary, proposed: Vector3) -> Dictionary:
	if original.phase != "surface": return original.duplicate(true)
	var s: Dictionary = original.duplicate(true)
	s.missions[s.location] = _engine.move_rover(s.missions[s.location], proposed)
	return s

static func rover_act(original: Dictionary, action: String) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase != "surface": return _note(s, "Deploy the rover before surface operations.")
	if action in ["launch", "finish"]: return _note(s, "Use the ship to leave; end the expedition from the menu.")
	s.missions[s.location] = _engine.act(s.missions[s.location], action)
	return s

static func board_distance(state: Dictionary) -> float:
	var m: Dictionary = mission(state)
	if m.is_empty(): return INF
	return MissionEngine.flat_distance(m.position, Destinations.get_def(state.location).pad)

static func board(original: Dictionary) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase != "surface": return _note(s, "The rover is not on the surface.")
	var def: Dictionary = Destinations.get_def(s.location)
	if board_distance(s) > float(def.boarding_range):
		return _note(s, "Drive within %d m of the ship to board." % int(def.boarding_range))
	var m: Dictionary = s.missions[s.location]
	var rules: Dictionary = Destinations.surface_rules(s.location)
	var stowed: int = 0
	if rules.get("sample_return", false):
		for site in m.sites:
			var key: String = "%s:%s" % [s.location, site.id]
			if site.sampled and not key in s.collected:
				s.collected.append(key)
				s.cores.append({"id": key, "destination": s.location, "site_id": site.id, "name": site.name,
					"finding": site.finding, "science": int(rules.sample_science), "mass": float(rules.core_mass)})
				stowed += 1
	s.rover_fuel_cells = int(m.fuel_cells)
	# The ship recharges the stowed rover's battery, repairs it and relays any untransmitted data
	# (fictional conveniences that keep the campaign forgiving). Sample cores still travel physically.
	m.energy = float(m.max_energy)
	if m.has("integrity"): m.integrity = 100.0
	var sendable: int = _transmittable(m, rules)
	if sendable > int(m.science_returned): m.science_returned = sendable
	s.phase = "aboard"
	_update_cargo(s)
	return _note(s, "Rover stowed%s. Ship mass %d kg." % [
		" with %d sealed sample core%s" % [stowed, "" if stowed == 1 else "s"] if stowed > 0 else "", roundi(Ship.total_mass(s.ship))])

static func disembark(original: Dictionary) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase != "aboard": return _note(s, "Land before deploying the rover.")
	_ensure_mission(s, s.location)
	var m: Dictionary = s.missions[s.location]
	m.position = Vector3.ZERO
	m.fuel_cells = s.rover_fuel_cells
	s.phase = "surface"
	return _note(s, "Rover deployed on %s." % Destinations.get_def(s.location).name)

# ------------------------------------------------------------------------------------------- flight

static func takeoff(original: Dictionary, toward_id: String) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase != "aboard": return _note(s, "Board the ship before takeoff.")
	var target: Dictionary = Destinations.get_def(toward_id)
	var toward: Vector3 = target.space.position if not target.is_empty() else Vector3.ZERO
	var result: Dictionary = Travel.takeoff(s.ship, s.location, toward)
	if not result.ok:
		s.stranded = true
		return _note(s, "Stranded on %s. %s" % [Destinations.get_def(s.location).name, result.reason])
	s.ship = result.ship
	s.stranded = false
	var origin: String = s.location
	if s.has("campaign"):
		# Campaign checkpoint for this flight leg: recovery restarts the leg from just after the ascent.
		s.campaign.flight_checkpoint = {"ship": s.ship.duplicate(true), "origin": Destinations.get_def(origin).name}
	s.location = ""
	s.phase = "flight"
	return _note(s, "Lifted off from %s: ascent burned %d kg." % [Destinations.get_def(origin).name, roundi(result.fuel_burned)])

static func fly(original: Dictionary, input: Dictionary, dt: float) -> Dictionary:
	if original.phase != "flight": return original.duplicate(true)
	var s: Dictionary = original.duplicate(true)
	s.ship = Travel.fly(s.ship, input, dt)
	return s

static func land(original: Dictionary, id: String) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase != "flight": return _note(s, "Not in flight.")
	var result: Dictionary = Travel.land(s.ship, id)
	if not result.ok: return _note(s, "Landing refused. " + result.reason)
	s.ship = result.ship
	return _touch_down(s, id, "Landed on %s: descent burned %d kg." % [Destinations.get_def(id).name, roundi(result.fuel_burned)])

## Start the player-controlled final descent. The whole descent burn is charged here, once.
static func begin_landing(original: Dictionary, id: String, assist: bool = false) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase != "flight": return _note(s, "Not in flight.")
	var result: Dictionary = Travel.land(s.ship, id)
	if not result.ok: return _note(s, "Landing refused. " + result.reason)
	s.ship = result.ship
	s.phase = "landing"
	s.landing = Landing.create(id, int(s.seed), assist)
	s.landing.fuel_charged = true
	return _note(s, "Descent burn: %d kg. Final descent to the %s pad." % [roundi(result.fuel_burned), Destinations.get_def(id).name])

static func landing_step(original: Dictionary, input: Dictionary, dt: float) -> Dictionary:
	if original.phase != "landing": return original.duplicate(true)
	var s: Dictionary = original.duplicate(true)
	var before: String = str(s.landing.status)
	s.landing = Landing.step(s.landing, input, dt)
	if s.landing.status == "landed":
		var id: String = str(s.landing.destination)
		var attempts: int = int(s.landing.attempts)
		s.erase("landing")
		return _touch_down(s, id, "Touchdown on %s%s." % [Destinations.get_def(id).name, "" if attempts <= 1 else " (attempt %d)" % attempts])
	if s.landing.status == "failed" and before != "failed": _note(s, str(s.landing.reason))
	return s

static func retry_landing(original: Dictionary) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase != "landing": return s
	var l: Dictionary = s.landing
	s.landing = Landing.create(str(l.destination), int(s.seed), bool(l.assist), int(l.attempts) + 1)
	s.landing.fuel_charged = true
	return _note(s, "Back at the approach point. Try the descent again.")

static func set_landing_assist(original: Dictionary, on: bool) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase == "landing": s.landing.assist = on
	return s

static func _touch_down(s: Dictionary, id: String, message: String) -> Dictionary:
	s.ship.velocity = Vector3.ZERO
	s.location = id
	s.phase = "aboard"
	if not id in s.visited: s.visited.append(id)
	if bool(Destinations.get_def(id).get("home", false)) and not s.cores.is_empty():
		var science: int = 0
		for core in s.cores: science += int(core.science)
		s.delivered.append_array(s.cores)
		s.delivered_science = int(s.delivered_science) + science
		message += " Delivered %d sample core%s: +%d science." % [s.cores.size(), "" if s.cores.size() == 1 else "s", science]
		s.cores = []
		_update_cargo(s)
	return _note(s, message)

static func finish(original: Dictionary) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase == "complete": return s
	if s.phase == "planning": return _note(s, "The expedition has not begun.")
	s.erase("landing")
	s.phase = "complete"
	return _note(s, "Expedition closed. Preparing the debrief.")

# ------------------------------------------------------------------------------------------- report

static func report(state: Dictionary) -> Dictionary:
	var destinations: Dictionary = {}
	var transmitted: int = 0
	var possible: int = 0
	var stations: int = 0
	var feedback: Array[String] = []
	for id in Destinations.ids():
		if not Destinations.is_explorable(id): continue
		var rules: Dictionary = Destinations.surface_rules(id)
		possible += 3 * (int(rules.scan_science) + int(rules.sample_science))
		if not state.missions.has(id): continue
		var m: Dictionary = state.missions[id]
		var r: Dictionary = _engine.get_report(m)
		transmitted += int(m.science_returned)
		if m.outpost_deployed: stations += 1
		var left_behind: int = 0
		if rules.get("sample_return", false):
			for site in m.sites:
				if site.sampled and not ("%s:%s" % [id, site.id]) in state.collected: left_behind += 1
		destinations[id] = {"name": Destinations.get_def(id).name, "transmitted": int(m.science_returned),
			"confirmed_sites": r.confirmed_sites, "ruled_out_sites": r.ruled_out_sites,
			"station": m.outpost_deployed, "samples_left_behind": left_behind,
			"untransmitted": maxi(0, _transmittable(m, rules) - int(m.science_returned))}
	var cores_lost: int = 0
	for core in state.cores: cores_lost += int(core.science)
	var returned: int = transmitted + int(state.delivered_science)
	var share: float = minf(1.0, float(returned) / float(possible)) if possible > 0 else 0.0
	var score: int = clampi(roundi(share * SCORE_SCIENCE_WEIGHT + mini(stations, 2) * SCORE_PER_STATION), 0, 100)
	var at_home: bool = state.phase != "planning" and state.location == Destinations.HOME
	feedback.append("%d of %d possible science reached Earth: %d as transmitted data, %d in sample cores flown home." % [
		returned, possible, transmitted, int(state.delivered_science)])
	if cores_lost > 0: feedback.append("%d sample core%s (%d science) never reached the Moon base." % [state.cores.size(), "" if state.cores.size() == 1 else "s", cores_lost])
	for id in destinations:
		var d: Dictionary = destinations[id]
		if d.samples_left_behind > 0: feedback.append("%d sampled site%s on %s were never stowed aboard." % [d.samples_left_behind, "" if d.samples_left_behind == 1 else "s", d.name])
		if d.untransmitted > 0: feedback.append("%d science on %s was collected but never transmitted." % [d.untransmitted, d.name])
		feedback.append("%s: %d confirmed, %d ruled out, station %s." % [d.name, d.confirmed_sites, d.ruled_out_sites, "operational" if d.station else "not deployed"])
	if not "mars" in state.visited: feedback.append("Mars was never reached.")
	if not at_home and state.phase != "planning":
		feedback.append("The expedition ended away from the Moon base%s." % (" (stranded without ascent fuel)" if state.stranded else ""))
	feedback.append("Fuel: %d kg used, %d kg left (%s load)." % [roundi(state.ship.fuel_used), roundi(state.ship.fuel), state.fuel_load])
	feedback.append("Scores and equipment values are fictional; labelled facts come from NASA.")
	return {"score": score, "science_returned": returned, "science_possible": possible, "transmitted": transmitted,
		"delivered_science": int(state.delivered_science), "cores_lost_science": cores_lost, "stations": stations,
		"visited": state.visited.duplicate(), "home": at_home, "stranded": state.stranded,
		"fuel_used": float(state.ship.fuel_used), "fuel_left": float(state.ship.fuel),
		"destinations": destinations, "feedback": feedback}

# ------------------------------------------------------------------------------------------- helpers

static func _transmittable(m: Dictionary, rules: Dictionary) -> int:
	if not rules.get("sample_return", false): return int(m.science_collected)
	var total: int = 0
	for site in m.sites:
		if site.scanned: total += int(rules.scan_science)
	return total

static func _ensure_mission(s: Dictionary, id: String) -> void:
	if s.missions.has(id): return
	var m: Dictionary = _engine.act(_engine.create_surface_mission(s.config, int(s.seed), id), "launch")
	m.fuel_cells = int(s.rover_fuel_cells)
	s.missions[id] = m

static func _update_cargo(s: Dictionary) -> void:
	var cores_mass: float = 0.0
	for core in s.cores: cores_mass += float(core.mass)
	s.ship.cargo_mass = float(s.rover_mass) + cores_mass

static func _note(s: Dictionary, message: String) -> Dictionary:
	s.log.push_front(message)
	if s.log.size() > MAX_LOG_LINES: s.log.resize(MAX_LOG_LINES)
	return s
