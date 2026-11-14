extends RefCounted
## CLAUDE OWNERSHIP: replace this facade's preview backend with the native production port.
## Keep these methods and state keys compatible with shared/mission_contract.gd.
const Preview = preload("res://preview/mission_preview.gd")
var backend = Preview.new()

func create_mission(config: Dictionary, mission_seed: int) -> Dictionary:
	return backend.create_mission(config, mission_seed)

func review_design(config: Dictionary) -> Dictionary:
	return backend.review_design(config)

func move_rover(state: Dictionary, proposed_position: Vector3) -> Dictionary:
	return backend.move_rover(state, proposed_position)

func act(state: Dictionary, action: String) -> Dictionary:
	return backend.act(state, action)

func get_report(state: Dictionary) -> Dictionary:
	return backend.get_report(state)
