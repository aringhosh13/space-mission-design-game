extends RefCounted
## Regional candidate-traverse screening on unscaled NASA elevations, never gameplay mesh heights.
## Not flight validated. DEM resolution cannot resolve wheel hazards, local rocks or illumination.
const GRID: int = 65
const MODEL := {"wh_per_m": 0.02, "idle_w": 20.0, "speed_m_s": 0.2, "grade_penalty": 10.0}

class TerrainGraph extends AStar2D:
	var heights: PackedFloat32Array
	var slopes: PackedFloat32Array
	var energy_mode: bool = false
	func _compute_cost(from: int, to: int) -> float:
		var distance: float = get_point_position(from).distance_to(get_point_position(to))
		if not energy_mode: return distance
		return distance * 0.02 * (1.0 + maxf(0.0, heights[to] - heights[from]) / distance * 10.0) + distance / 0.2 * 20.0 / 3600.0
	func _estimate_cost(from: int, to: int) -> float:
		var distance: float = get_point_position(from).distance_to(get_point_position(to))
		return distance * (0.02 + 20.0 / (0.2 * 3600.0)) if energy_mode else distance

static func plan(data: Resource, start: Vector2, goal: Vector2, slope_limit: float = 15.0,
		battery_wh: float = 10000.0, reserve: float = 0.2, energy_mode: bool = true) -> Dictionary:
	var result := {"outbound": [], "return": [], "feasible": false, "reason": "", "distance_m": 0.0,
		"energy_wh": 0.0, "max_slope_deg": 0.0, "source": data.source_product if data != null else "unavailable", "model": MODEL.duplicate(),
		"slope_limit": slope_limit, "battery_wh": battery_wh, "reserve": reserve,
		"method": "energy" if energy_mode else "distance", "grid_step_m": data.real_half_extent_m * 2.0 / (GRID - 1) if data != null else 0.0}
	if data == null or data.width < 2 or data.height < 2 or data.elevations.size() != data.width * data.height or data.real_half_extent_m <= 0:
		result.reason = "Missing or invalid measured elevation grid."
		return result
	if not start.is_finite() or not goal.is_finite() or not is_finite(slope_limit) or not is_finite(battery_wh) or not is_finite(reserve) or battery_wh <= 0 or reserve < 0 or reserve >= 1 or slope_limit <= 0:
		result.reason = "Invalid planning inputs."
		return result
	if start.x < 0 or start.y < 0 or start.x > 1 or start.y > 1 or goal.x < 0 or goal.y < 0 or goal.x > 1 or goal.y > 1:
		result.reason = "Choose points inside the measured patch."
		return result
	var graph := TerrainGraph.new()
	graph.energy_mode = energy_mode
	graph.heights.resize(GRID * GRID)
	graph.slopes.resize(GRID * GRID)
	var step_m: float = result.grid_step_m
	for y in range(GRID):
		for x in range(GRID):
			var id: int = y * GRID + x
			graph.add_point(id, Vector2(x, y) * step_m)
			graph.heights[id] = data.sample_uv(float(x) / (GRID - 1), float(y) / (GRID - 1))
			if not is_finite(graph.heights[id]):
				result.reason = "Invalid elevation value in the measured grid."
				return result
	for y in range(GRID):
		for x in range(GRID):
			var left: int = y * GRID + maxi(0, x - 1)
			var right: int = y * GRID + mini(GRID - 1, x + 1)
			var up: int = maxi(0, y - 1) * GRID + x
			var down: int = mini(GRID - 1, y + 1) * GRID + x
			var dx: float = (graph.heights[right] - graph.heights[left]) / (step_m * (2 if x > 0 and x < GRID - 1 else 1))
			var dy: float = (graph.heights[down] - graph.heights[up]) / (step_m * (2 if y > 0 and y < GRID - 1 else 1))
			graph.slopes[y * GRID + x] = rad_to_deg(atan(Vector2(dx, dy).length()))
			if graph.slopes[y * GRID + x] > slope_limit: graph.set_point_disabled(y * GRID + x)
	for y in range(GRID):
		for x in range(GRID):
			var from: int = y * GRID + x
			for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
				var nx: int = x + offset.x
				var ny: int = y + offset.y
				if nx < 0 or nx >= GRID or ny >= GRID: continue
				var to: int = ny * GRID + nx
				if offset.x != 0 and offset.y != 0 and (graph.is_point_disabled(y * GRID + nx) or graph.is_point_disabled(ny * GRID + x)): continue
				var edge_m: float = graph.get_point_position(from).distance_to(graph.get_point_position(to))
				if rad_to_deg(atan(absf(graph.heights[to] - graph.heights[from]) / edge_m)) <= slope_limit:
					graph.connect_points(from, to)
	var origin: int = roundi(start.y * (GRID - 1)) * GRID + roundi(start.x * (GRID - 1))
	var target: int = roundi(goal.y * (GRID - 1)) * GRID + roundi(goal.x * (GRID - 1))
	if origin == target or graph.is_point_disabled(origin) or graph.is_point_disabled(target):
		result.reason = "Choose distinct points outside sampled steep cells."
		return result
	for leg in ["outbound", "return"]:
		var ids: PackedInt64Array = graph.get_id_path(origin, target) if leg == "outbound" else graph.get_id_path(target, origin)
		if ids.is_empty():
			result.reason = "No connected return traverse satisfies the sampled slope limit."
			return result
		for index in range(ids.size()):
			var id: int = ids[index]
			result[leg].append(Vector2(id % GRID, id / GRID) / float(GRID - 1))
			result.max_slope_deg = maxf(result.max_slope_deg, graph.slopes[id])
			if index == 0: continue
			var previous: int = ids[index - 1]
			var distance: float = graph.get_point_position(previous).distance_to(graph.get_point_position(id))
			var rise: float = graph.heights[id] - graph.heights[previous]
			result.distance_m += distance
			result.energy_wh += distance * MODEL.wh_per_m * (1.0 + maxf(0.0, rise) / distance * MODEL.grade_penalty) + distance / MODEL.speed_m_s * MODEL.idle_w / 3600.0
			result.max_slope_deg = maxf(result.max_slope_deg, rad_to_deg(atan(absf(rise) / distance)))
	result.feasible = float(result.energy_wh) <= battery_wh * (1.0 - reserve)
	result.reason = "Passes the stated model and reserve; reconnaissance still required." if result.feasible else "Insufficient modeled energy for the full return traverse and reserve."
	return result

static func geographic(data: Resource, uv: Vector2) -> Vector3:
	var east: float = (uv.x * 2.0 - 1.0) * data.real_half_extent_m
	var north: float = (1.0 - uv.y * 2.0) * data.real_half_extent_m
	var radius: float = 3396000.0 if str(data.source_product).begins_with("MEGT") else 1737400.0
	var distance: float = Vector2(east, north).length() / radius
	var bearing: float = atan2(east, north)
	var lat0: float = deg_to_rad(data.centre_latitude)
	var lon0: float = deg_to_rad(data.centre_longitude)
	var lat: float = asin(sin(lat0) * cos(distance) + cos(lat0) * sin(distance) * cos(bearing))
	var lon: float = lon0 + atan2(sin(bearing) * sin(distance) * cos(lat0), cos(distance) - sin(lat0) * sin(lat))
	return Vector3(wrapf(rad_to_deg(lon), -180, 180), rad_to_deg(lat), data.sample_uv(uv.x, uv.y))

static func geojson(data: Resource, result: Dictionary) -> Dictionary:
	var features: Array = []
	for leg in ["outbound", "return"]:
		var points: Array = []
		for uv: Vector2 in result[leg]:
			var geo: Vector3 = geographic(data, uv)
			# Two-coordinate GeoJSON: avoids implying datum-relative elevation is WGS84 altitude.
			points.append([geo.x, geo.y])
		if points.size() >= 2:
			features.append({"type": "Feature", "properties": {"leg": leg, "body": "Mars" if str(data.source_product).begins_with("MEGT") else "Moon"}, "geometry": {"type": "LineString", "coordinates": points}})
	var properties: Dictionary = result.duplicate(true)
	properties.erase("outbound")
	properties.erase("return")
	properties["warning"] = "Planetocentric planetary coordinates, not Earth WGS84. Regional screening only; unvalidated power model. No rock/thermal/communication/illumination clearance."
	properties["source_url"] = "https://pds-geosciences.wustl.edu/mgs/urn-nasa-pds-mgs_mola_topography_derived/meg016/megt90n000eb.img" if str(data.source_product).begins_with("MEGT") else "https://pds-geosciences.wustl.edu/lro/lro-l-lola-3-rdr-v1/lrolol_1xxx/data/lola_gdr/cylindrical/img/ldem_16.img"
	properties["centre_latitude"] = data.centre_latitude
	properties["centre_longitude"] = data.centre_longitude
	properties["patch_half_extent_m"] = data.real_half_extent_m
	return {"type": "FeatureCollection", "features": features, "properties": properties}
