extends RefCounted
## "First Light" story campaign rules (Claude-owned). Pure: no Nodes, input, rendering or wall clock.
##
## A fictional future expedition informed by NASA science; not a recreation of any real mission. Mission
## Control sends the crew to assess routes and resources for a future lunar research outpost (VIPER/Artemis
## south-pole science inspired), then to investigate an ancient-delta-inspired region on Mars (Perseverance
## science inspired) and fly sample cores home. Nothing here claims to find life or presents our sites,
## deposits or route as real NASA observations.
##
## Objectives complete from authoritative expedition state only, in any sensible order. Ruling a signal out
## is valid science: "scan" objectives need a scan, never a positive finding. Each completion saves a nearby
## checkpoint. recover() returns the rover, ship or descent to the last checkpoint and never changes
## science, findings, cores, deliveries, stations or completed objectives.
const Expedition = preload("res://simulation/expedition.gd")
const MissionEngine = preload("res://simulation/mission_engine.gd")
const Destinations = preload("res://simulation/destinations.gd")
const Ship = preload("res://simulation/ship_flight.gd")

const ID: String = "first-light"
const TITLE: String = "First Light"
const REACH_RADIUS: float = 10.0
const RECOVERY_ENERGY_FLOOR: float = 0.6   # recovery tops the battery up to 60% (fictional, forgiving)
const STORM_FORECAST_SECONDS: float = 12.0

const BRIEFING: Array[String] = [
	"Mission Control: Welcome to First Light. You're in lunar orbit above Shackleton Base.",
	"Your task: assess routes and resources for a future research outpost, then take the rover to Mars and bring evidence home.",
	"Ruling a signal out is good science too. Nothing here is a real NASA observation; the science goals are NASA-inspired.",
]

const OBJECTIVES: Array[Dictionary] = [
	{"id": "moon-landing", "chapter": "moon", "destination": "moon", "kind": "land", "title": "Land at Shackleton Base",
		"message": "Take manual control for final descent. Keep it slow and over the pad; the assist is there if you need it."},
	{"id": "moon-ridge", "chapter": "moon", "destination": "moon", "kind": "reach", "waypoint": "ridge", "title": "Reach the survey ridge",
		"message": "Drive to the sunlit ridge. It's a candidate route for future traverses and a good place to read the terrain."},
	{"id": "moon-ice", "chapter": "moon", "destination": "moon", "kind": "scan", "site_kind": "ice", "title": "Investigate the ice signal",
		"message": "Scan the signal in the shadowed basin. Polar ice in permanently shadowed regions is a key Artemis and VIPER science goal."},
	{"id": "moon-geology", "chapter": "moon", "destination": "moon", "kind": "scan", "site_kind": "geology", "title": "Investigate the exposed formation",
		"message": "Scan the exposed formation. Old surfaces help reconstruct the Moon's history."},
	{"id": "moon-station", "chapter": "moon", "destination": "moon", "kind": "station", "title": "Establish the research station",
		"message": "Deploy the relay/research station anywhere in sunlight. The beacon marks a suggested spot."},
	{"id": "moon-return", "chapter": "moon", "destination": "moon", "kind": "board", "title": "Return evidence to the ship",
		"message": "Drive back and board (G). The ship relays any data you haven't sent."},
	{"id": "mars-landing", "chapter": "mars", "destination": "mars", "kind": "land", "title": "Land at Aurora Delta",
		"message": "Take off for Mars. Aurora Delta is a fictional region inspired by ancient river-delta science. Land on the pad."},
	{"id": "mars-layers", "chapter": "mars", "destination": "mars", "kind": "scan", "site_kind": "geology", "title": "Scan the layered rock",
		"message": "Scan the layered delta front. Layers record how ancient environments changed, as Perseverance studies at Jezero."},
	{"id": "mars-core", "chapter": "mars", "destination": "mars", "kind": "sample_any", "title": "Collect a sample core",
		"message": "Drill a sample at a scanned site. Cores only count once they reach the Moon base."},
	{"id": "mars-storm", "chapter": "mars", "destination": "mars", "kind": "storm", "title": "Ride out the dust storm",
		"message": "A dust storm is building. Solar power drops in storms. Head for the shelter, use fuel cells, or carry on with a full battery."},
	{"id": "mars-return", "chapter": "home", "destination": "moon", "kind": "deliver", "from": "mars", "title": "Return the core to the Moon base",
		"message": "Board, take off and fly the core home. Land on the base pad to deliver it."},
	{"id": "debrief", "chapter": "home", "destination": "moon", "kind": "debrief", "title": "Debrief with Mission Control",
		"message": "Evidence delivered. End the expedition at the base to hear the debrief."},
]

static var _engine = MissionEngine.new()

# ------------------------------------------------------------------------------------------- setup

## Expedition review plus the campaign's own requirement (a drill for the Mars core).
static func review(config: Dictionary, fuel_load: String) -> Dictionary:
	var r: Dictionary = Expedition.review(config, fuel_load)
	if str(config.get("instrument", "")) != "drill":
		r.warnings.append("First Light needs the scanner + drill payload to collect a Mars core.")
	return r

static func create(config: Dictionary, fuel_load: String, campaign_seed: int) -> Dictionary:
	var s: Dictionary = Expedition.create(config, fuel_load, campaign_seed)
	s.log = ["First Light: in lunar orbit above Shackleton Base."]
	return s

## planning → flight in the Moon's approach zone, ready for the first manual landing.
static func begin(original: Dictionary) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.phase != "planning": return s
	var r: Dictionary = review(s.config, s.fuel_load)
	if not r.warnings.is_empty():
		s.log.push_front("Cannot begin. " + " ".join(r.warnings))
		return s
	var moon: Dictionary = Destinations.get_def("moon").space
	var arrival := Vector3(0.0, 0.25, 1.0).normalized()
	s.ship.position = moon.position + arrival * (float(moon.radius) + float(moon.approach_altitude) * 0.55)
	s.ship.velocity = Vector3.ZERO
	s.ship.yaw = atan2(arrival.x, arrival.z)
	s.ship.pitch = -0.2
	s.phase = "flight"
	s.location = ""
	s.rover_fuel_cells = int(Destinations.surface_rules("moon").fuel_cell_supplies) if str(s.config.power) == "fuel-cell" else 0
	s.campaign = {"id": ID, "chapter": "moon", "objective": OBJECTIVES[0].id, "completed": [], "reached": [],
		"checkpoint": {"objective": "start", "destination": "", "position": Vector3.ZERO},
		"flight_checkpoint": {"ship": s.ship.duplicate(true), "origin": "lunar orbit"},
		"storm_seen": false, "recoveries": 0, "message": OBJECTIVES[0].message, "message_id": 1}
	return s

# ------------------------------------------------------------------------------------------- progress

static func objective(id: String) -> Dictionary:
	for o in OBJECTIVES:
		if o.id == id: return o
	return {}

static func current(state: Dictionary) -> Dictionary:
	return objective(str(state.get("campaign", {}).get("objective", "")))

static func is_complete(state: Dictionary) -> bool:
	return state.has("campaign") and state.campaign.completed.size() == OBJECTIVES.size()

## Re-evaluate objectives from authoritative state. Call after any expedition change (cheap and pure).
static func evaluate(original: Dictionary) -> Dictionary:
	if not original.has("campaign"): return original.duplicate(true)
	var s: Dictionary = original.duplicate(true)
	var c: Dictionary = s.campaign
	# Track the shelter and storms (presentation checkpoint and storm objective).
	if s.phase == "surface" and s.location == "mars":
		var m: Dictionary = s.missions.mars
		if _engine.in_shelter(m) and not "mars-shelter" in c.reached:
			c.reached.append("mars-shelter")
			c.checkpoint = {"objective": "mars-shelter", "destination": "mars", "position": m.position}
			_message(c, "Checkpoint saved at the dust shelter: full recharges and free repairs here.")
		if c.objective == "mars-storm" and m.get("weather", {}).get("phase", "clear") == "storm":
			c.storm_seen = true
	var changed: bool = true
	while changed:
		changed = false
		for o in OBJECTIVES:
			if o.id in c.completed: continue
			if _done(s, o):
				c.completed.append(o.id)
				_checkpoint(s, o)
				changed = true
	var next: Dictionary = {}
	for o in OBJECTIVES:
		if not o.id in c.completed:
			next = o
			break
	var previous: String = str(c.objective)
	c.objective = next.get("id", "")
	c.chapter = next.get("chapter", "complete")
	if c.objective != previous:
		if next.is_empty(): _message(c, "Mission Control: First Light complete. Thank you, crew.")
		else: _message(c, str(next.message))
		if c.objective == "mars-storm" and s.missions.has("mars"):
			s.missions.mars = _engine.forecast_storm(s.missions.mars, STORM_FORECAST_SECONDS)
	return s

static func _done(s: Dictionary, o: Dictionary) -> bool:
	var dest: String = str(o.destination)
	var m: Dictionary = s.missions.get(dest, {})
	match str(o.kind):
		"land": return s.location == dest and s.phase in ["aboard", "surface", "complete"]
		"reach":
			if m.is_empty(): return false
			var waypoint: Vector3 = Destinations.surface_rules(dest).waypoints[o.waypoint]
			return MissionEngine.flat_distance(m.position, waypoint) <= REACH_RADIUS
		"scan":
			for site in m.get("sites", []):
				if site.kind == o.site_kind and site.scanned: return true
			return false
		"sample_any":
			for site in m.get("sites", []):
				if site.sampled: return true
			return false
		"station": return bool(m.get("outpost_deployed", false))
		"board":
			if not (s.phase == "aboard" and s.location == dest): return false
			for other in OBJECTIVES:
				if other.chapter == o.chapter and other.id != o.id and not other.id in s.campaign.completed: return false
			return true
		"storm": return bool(s.campaign.storm_seen) and m.get("weather", {}).get("phase", "") == "clear"
		"deliver":
			for core in s.delivered:
				if core.destination == o.from: return true
			return false
		"debrief":
			return s.phase == "complete" and s.location == Destinations.HOME and "mars-return" in s.campaign.completed
	return false

static func _checkpoint(s: Dictionary, o: Dictionary) -> void:
	var c: Dictionary = s.campaign
	var dest: String = str(o.destination)
	var position: Vector3 = Vector3.ZERO
	if s.missions.has(dest) and s.location == dest and s.phase == "surface": position = s.missions[dest].position
	c.checkpoint = {"objective": o.id, "destination": dest if s.location == dest else str(c.checkpoint.get("destination", "")), "position": position}
	_message(c, "Objective complete: %s. Checkpoint saved." % o.title)

static func _message(c: Dictionary, text: String) -> void:
	c.message = text
	c.message_id = int(c.get("message_id", 0)) + 1

# ------------------------------------------------------------------------------------------- recovery

## Return to the last checkpoint for the current phase. Never changes science, findings, cores,
## deliveries, stations or completed objectives.
static func recover(original: Dictionary) -> Dictionary:
	if not original.has("campaign"): return original.duplicate(true)
	var s: Dictionary = original.duplicate(true)
	var c: Dictionary = s.campaign
	match str(s.phase):
		"landing":
			s = Expedition.retry_landing(s)
		"flight":
			var snapshot: Dictionary = c.flight_checkpoint.get("ship", {})
			if snapshot.is_empty(): return s
			s.ship = snapshot.duplicate(true)
			s.log.push_front("Recovered to the start of this flight leg (%s)." % c.flight_checkpoint.get("origin", ""))
		"surface":
			var m: Dictionary = s.missions[s.location]
			var to: Vector3 = Vector3.ZERO
			if str(c.checkpoint.get("destination", "")) == s.location: to = c.checkpoint.position
			m.position = to
			m.energy = maxf(float(m.energy), float(m.max_energy) * RECOVERY_ENERGY_FLOOR)
			m.log.push_front("Recovered to the last checkpoint. Battery topped up to at least 60%.")
		_:
			return s
	s.campaign.recoveries = int(s.campaign.recoveries) + 1
	_message(s.campaign, "Recovered to the last checkpoint. Progress and evidence are kept.")
	return s

# ------------------------------------------------------------------------------------------- presentation

## Checkpoint beacons for a destination: [{id, title, position, completed, active}]. Presentation only.
static func checkpoints_for(state: Dictionary, destination: String) -> Array:
	if not state.has("campaign"): return []
	var c: Dictionary = state.campaign
	var rules: Dictionary = Destinations.surface_rules(destination)
	var m: Dictionary = state.missions.get(destination, {})
	var pad: Vector3 = Destinations.get_def(destination).pad
	var result: Array = []
	for o in OBJECTIVES:
		if o.destination != destination: continue
		var position: Variant = null
		match str(o.kind):
			"land", "board", "deliver", "debrief": position = pad
			"reach": position = rules.waypoints[o.waypoint]
			"station": position = rules.waypoints.get("station", null)
			"scan": position = _site_position(m, rules, str(o.site_kind))
			"sample_any": position = _site_position(m, rules, "geology")
			"storm": position = rules.get("shelter", {}).get("position", null)
		if position == null: continue
		result.append({"id": o.id, "title": o.title, "position": position, "completed": o.id in c.completed, "active": o.id == c.objective})
	if rules.has("shelter"):
		result.append({"id": "mars-shelter", "title": "Dust shelter", "position": rules.shelter.position,
			"completed": "mars-shelter" in c.reached, "active": false})
	return result

static func _site_position(m: Dictionary, rules: Dictionary, kind: String) -> Variant:
	for site in m.get("sites", rules.sites):
		if site.kind == kind: return site.position
	return null

static func summary(state: Dictionary) -> Dictionary:
	if not state.has("campaign"): return {}
	var titles: Array[String] = []
	for o in OBJECTIVES:
		titles.append(("✓ " if o.id in state.campaign.completed else "○ ") + o.title)
	return {"title": TITLE, "completed": state.campaign.completed.size(), "total": OBJECTIVES.size(),
		"complete": is_complete(state), "recoveries": int(state.campaign.recoveries), "objectives": titles}
