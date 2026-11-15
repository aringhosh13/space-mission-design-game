extends RefCounted
## Pure spaceship flight model (Claude-owned). No Nodes, input, physics engine, rendering or wall-clock time.
## step() returns a NEW ship Dictionary and never mutates its input.
##
## Mechanics:
## - Steering turns the ship (yaw and pitch). Velocity is kept between steps: there is no drag in space,
##   so a ship coasts until it thrusts or brakes.
## - Thrust and braking burn fuel. Each burn is integrated with the Tsiolkovsky rocket equation,
##   dv = ve * ln(m0 / m1), so the same fuel gives the same delta-v however a burn is split across frames,
##   and a heavier ship (cargo, rover, samples, fuel) gets less delta-v from the same fuel.
## - Braking fires against the current velocity and never reverses the ship.
##
## The rocket equation is real physics. Every number below (masses, thrust, exhaust velocity, turn rate) is a
## FICTIONAL BALANCING VALUE for a compressed game map; game units ("u") are not kilometres.

const DRY_MASS: float = 900.0             # kg: hull, engine, crew cabin (fictional)
const MAX_THRUST: float = 18000.0         # N at full throttle (fictional)
const EXHAUST_VELOCITY: float = 1000.0    # u/s effective exhaust velocity (fictional)
const TURN_RATE: float = 1.25             # rad/s at full steering input
const PITCH_LIMIT: float = 1.3            # rad; the ship cannot flip over the vertical
const FUEL_LOADS: Dictionary = {"light": 450.0, "standard": 650.0, "full": 850.0}  # kg of propellant

static func create(fuel: float, cargo_mass: float, position: Vector3 = Vector3.ZERO, yaw: float = 0.0) -> Dictionary:
	return {
		"position": position,
		"velocity": Vector3.ZERO,
		"yaw": yaw,
		"pitch": 0.0,
		"fuel": maxf(0.0, fuel),
		"fuel_capacity": maxf(0.0, fuel),
		"dry_mass": DRY_MASS,
		"cargo_mass": maxf(0.0, cargo_mass),
		"throttle": 0.0,       # thrust actually produced last step, 0..1 (drives engine effects)
		"braking": 0.0,        # brake thrust actually produced last step, 0..1
		"fuel_used": 0.0,
		"distance_flown": 0.0,
	}

static func total_mass(ship: Dictionary) -> float:
	return float(ship.dry_mass) + float(ship.cargo_mass) + float(ship.fuel)

static func forward(ship: Dictionary) -> Vector3:
	return Basis.from_euler(Vector3(float(ship.pitch), float(ship.yaw), 0.0)) * Vector3.FORWARD

static func speed(ship: Dictionary) -> float:
	return (ship.velocity as Vector3).length()

## Delta-v left if every kilogram of fuel were burned at the current mass (rocket equation).
static func delta_v_remaining(ship: Dictionary) -> float:
	return delta_v_for_fuel(total_mass(ship), float(ship.fuel))

static func delta_v_for_fuel(mass: float, fuel: float) -> float:
	if fuel <= 0.0 or mass <= fuel: return 0.0
	return EXHAUST_VELOCITY * log(mass / (mass - fuel))

## Fuel needed to change velocity by dv starting from the given total mass.
static func fuel_for_delta_v(mass: float, dv: float) -> float:
	if dv <= 0.0: return 0.0
	return mass * (1.0 - exp(-dv / EXHAUST_VELOCITY))

## Advance one step. input keys (all optional): thrust 0..1, brake 0..1, yaw -1..1 (right positive),
## pitch -1..1 (up positive).
static func step(ship: Dictionary, input: Dictionary, dt: float) -> Dictionary:
	var s: Dictionary = ship.duplicate(true)
	s.throttle = 0.0
	s.braking = 0.0
	if not is_finite(dt) or dt <= 0.0: return s
	var thrust: float = _axis(input.get("thrust", 0.0), 0.0, 1.0)
	var brake: float = _axis(input.get("brake", 0.0), 0.0, 1.0)
	var yaw_input: float = _axis(input.get("yaw", 0.0), -1.0, 1.0)
	var pitch_input: float = _axis(input.get("pitch", 0.0), -1.0, 1.0)

	s.yaw = wrapf(float(s.yaw) - yaw_input * TURN_RATE * dt, -PI, PI)
	s.pitch = clampf(float(s.pitch) + pitch_input * TURN_RATE * dt, -PITCH_LIMIT, PITCH_LIMIT)
	var velocity: Vector3 = s.velocity

	if thrust > 0.0 and float(s.fuel) > 0.0:
		var burn: float = minf(float(s.fuel), MAX_THRUST * thrust * dt / EXHAUST_VELOCITY)
		var m0: float = total_mass(s)
		velocity += forward(s) * EXHAUST_VELOCITY * log(m0 / (m0 - burn))
		s.fuel = float(s.fuel) - burn
		s.fuel_used = float(s.fuel_used) + burn
		s.throttle = thrust * burn / (MAX_THRUST * thrust * dt / EXHAUST_VELOCITY)

	var current_speed: float = velocity.length()
	if brake > 0.0 and float(s.fuel) > 0.0 and current_speed > 0.0:
		var m0: float = total_mass(s)
		var max_burn: float = minf(float(s.fuel), MAX_THRUST * brake * dt / EXHAUST_VELOCITY)
		var dv: float = minf(current_speed, EXHAUST_VELOCITY * log(m0 / (m0 - max_burn)))
		var burn: float = fuel_for_delta_v(m0, dv)
		velocity -= velocity / current_speed * dv
		if dv >= current_speed - 0.000001: velocity = Vector3.ZERO
		s.fuel = maxf(0.0, float(s.fuel) - burn)
		s.fuel_used = float(s.fuel_used) + burn
		s.braking = brake * burn / (MAX_THRUST * brake * dt / EXHAUST_VELOCITY)

	s.velocity = velocity
	s.position = (s.position as Vector3) + velocity * dt
	s.distance_flown = float(s.distance_flown) + velocity.length() * dt
	return s

static func _axis(value: Variant, low: float, high: float) -> float:
	var number: float = float(value) if (value is float or value is int) else 0.0
	if not is_finite(number): return 0.0
	return clampf(number, low, high)
