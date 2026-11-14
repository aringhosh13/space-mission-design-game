extends RefCounted
## Equipment design review. Pure: no nodes, input or rendering.
const Rules = preload("res://simulation/rules.gd")

static func is_known_config(config: Dictionary) -> bool:
	for slot in Rules.SLOTS:
		if not str(config.get(slot, "")) in Rules.SLOTS[slot]: return false
	return true

static func review(config: Dictionary) -> Dictionary:
	var cost: int = Rules.BASE_COST
	var mass: int = Rules.BASE_MASS
	var warnings: Array[String] = []
	for slot in Rules.SLOTS:
		var choice: String = str(config.get(slot, ""))
		if not choice in Rules.SLOTS[slot]:
			warnings.append("Choose a valid %s before launch." % Rules.SLOT_NAMES[slot])
			continue
		cost += int(Rules.PARTS[choice].cost)
		mass += int(Rules.PARTS[choice].mass)
	if cost > Rules.BUDGET:
		warnings.append("Over budget by %d credits. Try a lighter equipment package." % (cost - Rules.BUDGET))
	if mass > Rules.MASS_LIMIT:
		warnings.append("Over launch mass limit by %d kg. Remove a heavier component." % (mass - Rules.MASS_LIMIT))
	return {"cost": cost, "mass": mass, "budget": Rules.BUDGET, "mass_limit": Rules.MASS_LIMIT, "warnings": warnings}

static func battery_capacity(config: Dictionary) -> float:
	if not is_known_config(config): return 0.0
	return float(Rules.PARTS[str(config.battery)].capacity)
