extends RefCounted
## Illustrative instrument controls. No findings, science, mission resources or hidden signal truth.
static func create(mode: String, public_seed: int) -> Dictionary:
	return {"mode": mode, "tuning": 0.5, "target": 0.18 + posmod(public_seed, 65) / 100.0,
		"pressure": 50.0, "heat": 18.0, "progress": 0.0, "strength": 0.0, "cooling": false, "done": false}

static func step(original: Dictionary, controls: Dictionary, seconds: float) -> Dictionary:
	var s: Dictionary = original.duplicate(true)
	if s.done or not is_finite(seconds) or seconds <= 0: return s
	var dt: float = minf(seconds, 0.1)
	var held: bool = bool(controls.get("hold", false))
	if s.mode == "scan":
		var value: float = float(controls.get("value", s.tuning))
		if not is_finite(value): return s
		s.tuning = clampf(value, 0, 1)
		s.strength = clampf(1.0 - absf(s.tuning - s.target) / 0.13, 0, 1)
		if held and s.strength >= 0.65: s.progress = minf(1.0, s.progress + dt * 0.38)
	elif s.mode == "sample":
		var value: float = float(controls.get("value", s.pressure))
		if not is_finite(value): return s
		s.pressure = clampf(value, 0, 100)
		var running: bool = held and not s.cooling
		s.heat = clampf(s.heat + dt * (4 + s.pressure * 0.2 if running else -28), 0, 100)
		if s.heat >= 85: s.cooling = true
		elif s.heat <= 45: s.cooling = false
		if running and not s.cooling and s.pressure >= 25 and s.pressure <= 70:
			s.progress = minf(1.0, s.progress + dt * (0.16 + s.pressure * 0.0023))
	s.done = s.progress >= 1.0
	return s
