extends RefCounted
## Native contract v1. Coordinate values are world metres; y is terrain elevation.
## Mission state is a Dictionary returned by the adapter. UI never determines hidden truth.

const VERSION: int = 1
const MAP_LIMIT: float = 78.0
const INTERACTION_RANGE: float = 6.0
const DEFAULT_CONFIG: Dictionary = {
	"battery": "compact", "power": "solar", "instrument": "scanner"
}
const FINDING_LABELS: Dictionary = {
	"unconfirmed": "ORBITAL SIGNAL", "probable": "PRELIMINARY EVIDENCE",
	"confirmed": "CONFIRMED BY SAMPLE", "ruled-out": "RULED OUT BY SAMPLE"
}
const FINDING_COLORS: Dictionary = {
	"unconfirmed": Color("f3c582"), "probable": Color("8acdf5"),
	"confirmed": Color("a6e5bb"), "ruled-out": Color("d6abd9")
}

static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
