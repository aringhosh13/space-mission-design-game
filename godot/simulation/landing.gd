extends RefCounted
## Final-descent model for player-controlled landings (Claude-owned). Pure: no Nodes, input or wall clock.
##
## The ship starts 120 m above the destination's landing pad, slightly off to one side and descending.
## The player sets descent-engine throttle (0..1) and lateral RCS input (x/z, -1..1). Gravity is the real
## surface gravity (NASA: Moon ≈1.62 m/s², Mars ≈3.71 m/s²). Everything else (engine acceleration, RCS,
## start state, thrust allowance and the safe envelope) is a FICTIONAL, deliberately generous game value.
##
## Fuel: the descent burn is charged once by expedition.begin_landing() at the current mass. The final-descent
## thrust shown here draws from a time allowance included in that burn, so retries never charge fuel again.
## Assist: when on, a simple controller flies the descent; any player input overrides it on that axis.
const Destinations = preload("res://simulation/destinations.gd")
const Evidence = preload("res://simulation/evidence.gd")

const START_ALTITUDE: float = 120.0
const START_VERTICAL_SPEED: float = -6.0
const ALLOWANCE_SECONDS: float = 45.0   # seconds of full thrust available per attempt (fictional)
const RCS_ACCEL: float = 2.5            # m/s² lateral (fictional)
## Safe touchdown envelope (fictional, generous).
const MAX_TOUCHDOWN_SPEED: float = 3.0  # m/s downward
const MAX_LATERAL_SPEED: float = 2.0    # m/s
const PAD_RADIUS: float = 15.0          # m from the pad centre

static func gravity(id: String) -> float:
	return float(Destinations.get_def(id).get("gravity", 1.62))

## Full-throttle acceleration: at least 2.5 g of the destination, and never under 4.5 m/s² (fictional).
static func max_accel(id: String) -> float:
	return maxf(4.5, gravity(id) * 2.5)

## Deterministic start for a destination and seed; every retry starts from the same approach.
static func create(id: String, mission_seed: int, assist: bool = false, attempts: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = Evidence.stream_seed(mission_seed, id, "landing")
	var angle: float = rng.randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * rng.randf_range(14.0, 24.0)
	return {
		"destination": id, "altitude": START_ALTITUDE, "vertical_speed": START_VERTICAL_SPEED,
		"offset": offset, "lateral_velocity": -offset.normalized() * 1.0, "throttle": 0.0,
		"allowance": ALLOWANCE_SECONDS, "assist": assist, "status": "descending", "reason": "",
		"attempts": attempts, "fuel_charged": false, "elapsed": 0.0,
	}

## Throttle and RCS the assist would command.
static func assist_input(l: Dictionary) -> Dictionary:
	var id: String = str(l.destination)
	var altitude: float = float(l.altitude)
	var target_vs: float = -clampf(0.06 * altitude + 0.8, 0.8, 7.0)
	var throttle: float = clampf((gravity(id) + 1.6 * (target_vs - float(l.vertical_speed))) / max_accel(id), 0.0, 1.0)
	var desired_lateral: Vector2 = (-(l.offset as Vector2) * 0.22).limit_length(4.0)
	var command: Vector2 = ((desired_lateral - (l.lateral_velocity as Vector2)) * 1.4 / RCS_ACCEL).limit_length(1.0)
	return {"throttle": throttle, "x": command.x, "z": command.y}

## Advance the descent. input: {throttle 0..1, x -1..1, z -1..1}; missing keys mean "no input".
static func step(original: Dictionary, input: Dictionary, dt: float) -> Dictionary:
	var l: Dictionary = original.duplicate(true)
	if l.status != "descending" or not is_finite(dt) or dt <= 0.0: return l
	var id: String = str(l.destination)
	var throttle: Variant = input.get("throttle", null)
	var x: float = _axis(input.get("x", 0.0))
	var z: float = _axis(input.get("z", 0.0))
	if l.assist:
		var auto: Dictionary = assist_input(l)
		if throttle == null: throttle = auto.throttle
		if absf(x) < 0.01: x = auto.x
		if absf(z) < 0.01: z = auto.z
	var t: float = clampf(float(throttle) if (throttle is float or throttle is int) and is_finite(float(throttle)) else 0.0, 0.0, 1.0)
	if float(l.allowance) <= 0.0: t = 0.0
	l.throttle = t
	l.allowance = maxf(0.0, float(l.allowance) - t * dt)
	l.vertical_speed = float(l.vertical_speed) + (t * max_accel(id) - gravity(id)) * dt
	l.altitude = float(l.altitude) + float(l.vertical_speed) * dt
	l.lateral_velocity = (l.lateral_velocity as Vector2) + Vector2(x, z) * RCS_ACCEL * dt
	l.offset = (l.offset as Vector2) + (l.lateral_velocity as Vector2) * dt
	l.elapsed = float(l.elapsed) + dt
	if float(l.altitude) <= 0.0: _touchdown(l)
	return l

static func _touchdown(l: Dictionary) -> void:
	l.altitude = 0.0
	var problems: Array[String] = []
	if float(l.vertical_speed) < -MAX_TOUCHDOWN_SPEED:
		problems.append("descending at %.1f m/s (safe: under %.0f)" % [-float(l.vertical_speed), MAX_TOUCHDOWN_SPEED])
	if (l.lateral_velocity as Vector2).length() > MAX_LATERAL_SPEED:
		problems.append("drifting at %.1f m/s (safe: under %.0f)" % [(l.lateral_velocity as Vector2).length(), MAX_LATERAL_SPEED])
	if (l.offset as Vector2).length() > PAD_RADIUS:
		problems.append("%d m from the pad (safe: within %d)" % [roundi((l.offset as Vector2).length()), int(PAD_RADIUS)])
	if problems.is_empty():
		l.status = "landed"
		l.reason = "Touchdown inside the safe envelope."
	else:
		l.status = "failed"
		l.reason = "Unsafe touchdown: " + "; ".join(problems) + ". The ship aborted and climbed back to the approach point."
	l.vertical_speed = 0.0
	l.lateral_velocity = Vector2.ZERO
	l.throttle = 0.0

static func in_envelope(l: Dictionary) -> Dictionary:
	return {"vertical": float(l.vertical_speed) >= -MAX_TOUCHDOWN_SPEED,
		"lateral": (l.lateral_velocity as Vector2).length() <= MAX_LATERAL_SPEED,
		"pad": (l.offset as Vector2).length() <= PAD_RADIUS}

static func _axis(value: Variant) -> float:
	var number: float = float(value) if (value is float or value is int) else 0.0
	return clampf(number, -1.0, 1.0) if is_finite(number) else 0.0
