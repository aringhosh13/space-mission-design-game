extends Resource
## Measured planetary elevation in metres: LOLA above reference sphere, MOLA above areoid.
## Source-specific metadata and distortions are documented beside the processed resources.
@export var width: int = 0
@export var height: int = 0
@export var elevations: PackedFloat32Array = PackedFloat32Array()
@export var source_product: String = "LDEM_16 V3.1"
@export var centre_latitude: float = -88.0
@export var centre_longitude: float = 30.0
@export var real_half_extent_m: float = 75000.0

func sample_uv(u: float, v: float, wrap_x: bool = false) -> float:
	if width < 2 or height < 2 or elevations.size() != width * height: return 0.0
	var px: float = fposmod(u * width - 0.5, width) if wrap_x else clampf(u, 0.0, 1.0) * (width - 1)
	var py: float = clampf(v * height - 0.5, 0.0, height - 1) if wrap_x else clampf(v, 0.0, 1.0) * (height - 1)
	var x0: int = floori(px)
	var y0: int = floori(py)
	var x1: int = (x0 + 1) % width if wrap_x else mini(x0 + 1, width - 1)
	var y1: int = mini(y0 + 1, height - 1)
	return lerpf(lerpf(elevations[y0 * width + x0], elevations[y0 * width + x1], px - x0),
		lerpf(elevations[y1 * width + x0], elevations[y1 * width + x1], px - x0), py - y0)

func elevation_at(latitude: float, longitude: float) -> float:
	return sample_uv(fposmod(longitude, 360.0) / 360.0, (90.0 - clampf(latitude, -90.0, 90.0)) / 180.0, true)
