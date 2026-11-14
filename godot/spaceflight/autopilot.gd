extends RefCounted
## Simple approach autopilot used by tests and the demo's optional assist. It only produces the same
## inputs a player could (thrust, brake, steering) and goes through the same simulation, so it cannot
## bypass fuel, mass or landing rules.
const Ship = preload("res://simulation/ship_flight.gd")
const Travel = preload("res://simulation/travel.gd")
const Destinations = preload("res://simulation/destinations.gd")
const Pilot = preload("res://spaceflight/pilot_input.gd")

## Inputs to fly toward a destination at `cruise` u/s and stop inside its approach zone.
static func approach_input(ship: Dictionary, id: String, cruise: float = 60.0) -> Dictionary:
	var body: Dictionary = Destinations.get_def(id).space
	var to_body: Vector3 = body.position - (ship.position as Vector3)
	var distance: float = to_body.length() - float(body.radius) - float(body.approach_altitude) * 0.5
	var input: Dictionary = Pilot.align_toward(ship, to_body)
	var speed: float = Ship.speed(ship)
	var decel: float = Ship.MAX_THRUST / Ship.total_mass(ship)
	var stopping: float = speed * speed / (2.0 * decel) + speed * 0.4
	var aligned: bool = Ship.forward(ship).dot(to_body.normalized()) > 0.98
	var drifting: bool = speed > 0.5 and (ship.velocity as Vector3).normalized().dot(to_body.normalized()) < 0.9
	if distance <= stopping or distance < 2.0 or (drifting and speed > 3.0):
		input["brake"] = 1.0
	elif aligned and speed < cruise:
		input["thrust"] = 1.0
	return input
