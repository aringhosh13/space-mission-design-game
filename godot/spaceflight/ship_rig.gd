extends Node3D
## Scene node for a ship. The simulation owns the ship state; apply() mirrors it onto the node.
const ShipModel = preload("res://spaceflight/ship_model.gd")
var model: Node3D

func _ready() -> void:
	model = ShipModel.new()
	add_child(model)

func apply(ship: Dictionary) -> void:
	position = ship.position
	rotation = Vector3(float(ship.pitch), float(ship.yaw), 0.0)
	if model: model.set_engine(float(ship.throttle), float(ship.braking))
