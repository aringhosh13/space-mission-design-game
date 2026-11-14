extends "res://tests/spaceflight/campaign_route.gd"
## Codex GPU input driver. Native focus changes can release held keys; refresh W while driving.
## Retains every campaign assertion and manual landing pilot. No mission resources/positions are edited.
func drive_to(target: Vector3, tolerance: float = 4.5) -> bool:
	var surface: Node = game.current
	var reached: bool = false
	var last: Vector3 = mission().position
	var detour: int = 0
	for i in range(5400):
		var here: Vector3 = mission().position
		var offset := Vector2(target.x - here.x, target.z - here.z)
		if offset.length() <= tolerance:
			reached = true
			break
		key(KEY_W, true)
		var heading: float = atan2(-offset.x, -offset.y)
		if detour > 0:
			detour -= 1
			heading += 1.2
		surface.rover.yaw = heading
		await physics_frame
		if i % 45 == 44:
			if Vector2(here.x - last.x, here.z - last.z).length() < 1.0: detour = 50
			last = here
		if float(mission().energy) <= 0.05: break
	key(KEY_W, false)
	await frames(15)
	check(reached, "Drive blocked on %s at %s toward %s (energy %.1f)" % [surface.destination_id, mission().position, target, float(mission().energy)])
	return reached
