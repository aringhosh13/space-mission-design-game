extends RefCounted
## Pure travel rules between worlds (Claude-owned): flight with collision avoidance, approach guidance,
## landing and takeoff. Bodies are fixed in the compressed map; there is no orbital mechanics or gravity
## in flight (a stated simplification). Every function returns new dictionaries and never mutates inputs.
const Ship = preload("res://simulation/ship_flight.gd")
const Destinations = preload("res://simulation/destinations.gd")

const SYSTEM_LIMIT: float = 4000.0   # u, navigation boundary of the compressed map
const SURFACE_CLEARANCE: float = 6.0 # u, the proximity guard keeps ships this far above a surface
const PLANNING_CRUISE: float = 60.0  # u/s, the cruise speed used for fuel estimates

## Ship step plus the proximity guard and system boundary.
static func fly(ship: Dictionary, input: Dictionary, dt: float) -> Dictionary:
	var s: Dictionary = Ship.step(ship, input, dt)
	for id in Destinations.ids():
		var body: Dictionary = Destinations.get_def(id).space
		var offset: Vector3 = (s.position as Vector3) - body.position
		var minimum: float = float(body.radius) + SURFACE_CLEARANCE
		if offset.length() < minimum:
			var normal: Vector3 = offset.normalized() if offset.length() > 0.001 else Vector3.UP
			s.position = body.position + normal * minimum
			var inward: float = (s.velocity as Vector3).dot(normal)
			if inward < 0.0: s.velocity = (s.velocity as Vector3) - normal * inward
	var p: Vector3 = s.position
	if absf(p.x) > SYSTEM_LIMIT or absf(p.y) > SYSTEM_LIMIT or absf(p.z) > SYSTEM_LIMIT:
		s.position = p.clamp(Vector3.ONE * -SYSTEM_LIMIT, Vector3.ONE * SYSTEM_LIMIT)
		s.velocity = Vector3.ZERO
	return s

static func altitude(ship: Dictionary, id: String) -> float:
	var body: Dictionary = Destinations.get_def(id).space
	return ((ship.position as Vector3) - body.position).length() - float(body.radius)

static func descent_fuel(ship: Dictionary, id: String) -> float:
	return Ship.fuel_for_delta_v(Ship.total_mass(ship), Destinations.descent_delta_v(id))

static func ascent_fuel(total_mass: float, id: String) -> float:
	return Ship.fuel_for_delta_v(total_mass, Destinations.ascent_delta_v(id))

## Everything the HUD and the landing decision need about one destination.
static func guidance(ship: Dictionary, id: String) -> Dictionary:
	var def: Dictionary = Destinations.get_def(id)
	var body: Dictionary = def.space
	var offset: Vector3 = body.position - (ship.position as Vector3)
	var distance: float = maxf(0.0, offset.length() - float(body.radius))
	var direction: Vector3 = offset.normalized() if offset.length() > 0.001 else Vector3.ZERO
	var closing: float = (ship.velocity as Vector3).dot(direction)
	var speed: float = Ship.speed(ship)
	var landable: bool = def.get("kind", "") == "explorable"
	var in_approach: bool = landable and distance <= float(body.approach_altitude)
	var speed_ok: bool = landable and speed <= float(body.landing_speed_limit)
	var fuel_needed: float = descent_fuel(ship, id) if landable else 0.0
	var fuel_ok: bool = float(ship.fuel) + 0.000001 >= fuel_needed
	var reasons: Array[String] = []
	if not landable: reasons.append("%s is a landmark, not a landing destination." % def.name)
	else:
		if not in_approach: reasons.append("Enter the approach zone: %d u above %s." % [int(body.approach_altitude), def.name])
		if not speed_ok: reasons.append("Slow below %.0f u/s to land (now %.1f)." % [float(body.landing_speed_limit), speed])
		if not fuel_ok: reasons.append("Not enough fuel for descent: %d kg needed." % ceili(fuel_needed))
	return {
		"id": id, "name": def.name, "distance": distance, "direction": direction,
		"closing_speed": closing, "eta": distance / closing if closing > 0.5 else -1.0,
		"landable": landable, "in_approach": in_approach, "speed_ok": speed_ok,
		"landing_fuel": fuel_needed, "fuel_ok": fuel_ok, "landing_speed_limit": float(body.get("landing_speed_limit", 0.0)),
		"can_land": landable and in_approach and speed_ok and fuel_ok, "reasons": reasons,
	}

## Land: pays descent fuel at the current mass and parks the ship on the pad (velocity zero).
static func land(ship: Dictionary, id: String) -> Dictionary:
	var g: Dictionary = guidance(ship, id)
	if not g.can_land: return {"ok": false, "ship": ship.duplicate(true), "reason": " ".join(g.reasons)}
	var s: Dictionary = ship.duplicate(true)
	var burn: float = descent_fuel(s, id)
	s.fuel = maxf(0.0, float(s.fuel) - burn)
	s.fuel_used = float(s.fuel_used) + burn
	s.velocity = Vector3.ZERO
	s.throttle = 0.0
	s.braking = 0.0
	return {"ok": true, "ship": s, "fuel_burned": burn, "reason": ""}

## Take off from a body: pays ascent fuel at the current mass and places the ship in the approach zone,
## pointing away from the surface toward `toward` (usually the next destination).
static func takeoff(ship: Dictionary, id: String, toward: Vector3 = Vector3.ZERO) -> Dictionary:
	var burn: float = ascent_fuel(Ship.total_mass(ship), id)
	if float(ship.fuel) + 0.000001 < burn:
		return {"ok": false, "ship": ship.duplicate(true), "fuel_needed": burn,
			"reason": "Not enough fuel to take off: %d kg needed, %d kg aboard." % [ceili(burn), floori(ship.fuel)]}
	var body: Dictionary = Destinations.get_def(id).space
	var heading: Vector3 = toward - body.position
	if heading.length() < 0.001: heading = Vector3.FORWARD
	heading = heading.normalized()
	var s: Dictionary = ship.duplicate(true)
	s.fuel = maxf(0.0, float(s.fuel) - burn)
	s.fuel_used = float(s.fuel_used) + burn
	s.position = body.position + heading * (float(body.radius) + float(body.approach_altitude) * 0.6)
	s.velocity = Vector3.ZERO
	s.yaw = atan2(-heading.x, -heading.z)
	s.pitch = clampf(asin(clampf(heading.y, -1.0, 1.0)), -Ship.PITCH_LIMIT, Ship.PITCH_LIMIT)
	return {"ok": true, "ship": s, "fuel_burned": burn, "reason": ""}

## Rough delta-v plan for: brake from current speed, land at `id`, and (if `id` is not home) take off
## again, cruise home at PLANNING_CRUISE (accelerate + brake) and land at home. Used for HUD warnings.
static func round_trip_delta_v(ship: Dictionary, id: String) -> float:
	var need: float = Ship.speed(ship) + Destinations.descent_delta_v(id)
	if id != Destinations.HOME:
		need += Destinations.ascent_delta_v(id) + 2.0 * PLANNING_CRUISE + Destinations.descent_delta_v(Destinations.HOME)
	return need
