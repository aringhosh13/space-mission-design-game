extends RefCounted
## Scientific confidence and reproducible false positives (native port of the TypeScript evidence model).
##
## `confidence` is the integer 0–100 certainty in a site's current `finding`, NOT the probability that
## the resource exists.
##
##   finding       reached by                        confidence (fictional ranges)
##   unconfirmed   orbital survey, mission creation  15–30
##   probable      scan (preliminary evidence)       genuine 50–70, false positive 35–55 (overlapping)
##   confirmed     sample of a genuine signal        85–95
##   ruled-out     sample of a false positive        80–95
##
## Transitions only move forward, once each: unconfirmed --scan--> probable --sample--> confirmed | ruled-out.
##
## Whether a signal is genuine is a pure function of (mission seed, site id). It is never stored in the
## mission state or drawn from a shared random stream, so revisiting, repeating actions, visiting in a
## different order, choosing different equipment, replaying, or running at another frame rate cannot
## reroll it. Each draw uses its own RandomNumberGenerator seeded from a 32-bit FNV-1a hash.
##
## Native outcomes intentionally differ from the TypeScript engine's (different PRNG and hash input);
## they are reproducible within Godot. All chances and ranges are FICTIONAL BALANCING VALUES.

const FALSE_POSITIVE_CHANCE: Dictionary = {"ice": 0.35, "minerals": 0.30, "geology": 0.0}
const ORBITAL: Vector2i = Vector2i(15, 30)
const SCAN_GENUINE: Vector2i = Vector2i(50, 70)
const SCAN_FALSE_POSITIVE: Vector2i = Vector2i(35, 55)
const CONFIRMED: Vector2i = Vector2i(85, 95)
const RULED_OUT: Vector2i = Vector2i(80, 95)

## 32-bit FNV-1a over the UTF-8 bytes of "seed|site id|purpose".
static func stream_seed(mission_seed: int, site_id: String, purpose: String) -> int:
	var h: int = 0x811c9dc5
	for byte in ("%d|%s|%s" % [mission_seed, site_id, purpose]).to_utf8_buffer():
		h = ((h ^ byte) * 0x01000193) & 0xffffffff
	return h

static func _rng(mission_seed: int, site_id: String, purpose: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = stream_seed(mission_seed, site_id, purpose)
	return rng

static func _draw(mission_seed: int, site_id: String, purpose: String, bounds: Vector2i) -> int:
	return _rng(mission_seed, site_id, purpose).randi_range(bounds.x, bounds.y)

static func is_false_positive(mission_seed: int, site: Dictionary) -> bool:
	var chance: float = float(FALSE_POSITIVE_CHANCE.get(str(site.kind), 0.0))
	return _rng(mission_seed, str(site.id), "truth").randf() < chance

static func orbital(mission_seed: int, site_id: String) -> Dictionary:
	return {"finding": "unconfirmed", "confidence": _draw(mission_seed, site_id, "orbital", ORBITAL)}

static func scan(mission_seed: int, site: Dictionary) -> Dictionary:
	var bounds: Vector2i = SCAN_FALSE_POSITIVE if is_false_positive(mission_seed, site) else SCAN_GENUINE
	return {"finding": "probable", "confidence": _draw(mission_seed, str(site.id), "scan", bounds)}

static func sample(mission_seed: int, site: Dictionary) -> Dictionary:
	if is_false_positive(mission_seed, site):
		return {"finding": "ruled-out", "confidence": _draw(mission_seed, str(site.id), "sample", RULED_OUT)}
	return {"finding": "confirmed", "confidence": _draw(mission_seed, str(site.id), "sample", CONFIRMED)}
