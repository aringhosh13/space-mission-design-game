extends RefCounted
## Reads the flight keys into the input dictionary consumed by ship_flight.gd.
## Kept separate so tests and autopilots can supply inputs without a keyboard.

static func read() -> Dictionary:
	return {
		"thrust": 1.0 if _down([KEY_W, KEY_UP]) else 0.0,
		"brake": 1.0 if _down([KEY_S, KEY_DOWN]) else 0.0,
		"yaw": float(_down([KEY_D, KEY_RIGHT])) - float(_down([KEY_A, KEY_LEFT])),
		"pitch": float(_down([KEY_R])) - float(_down([KEY_F])),
	}

static func _down(keys: Array) -> bool:
	for key in keys:
		if Input.is_physical_key_pressed(key): return true
	return false

## Steering input that turns the ship toward a world-space direction (used by the C "align" assist).
## Returns yaw/pitch inputs in -1..1; the player still controls thrust and braking.
static func align_toward(ship: Dictionary, direction: Vector3) -> Dictionary:
	if direction.length() < 0.001: return {"yaw": 0.0, "pitch": 0.0}
	var d: Vector3 = direction.normalized()
	var desired_yaw: float = atan2(-d.x, -d.z)
	var desired_pitch: float = asin(clampf(d.y, -1.0, 1.0))
	var yaw_error: float = wrapf(desired_yaw - float(ship.yaw), -PI, PI)
	var pitch_error: float = desired_pitch - float(ship.pitch)
	# Right steering decreases yaw in ship_flight.gd, so a positive error needs negative input.
	return {"yaw": clampf(-yaw_error * 3.0, -1.0, 1.0), "pitch": clampf(pitch_error * 3.0, -1.0, 1.0)}
