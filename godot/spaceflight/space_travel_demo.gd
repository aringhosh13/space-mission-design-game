extends Node
## Stage 2 demonstration: take off from the Moon, fly to Mars (or back), land with a transition card,
## and take off again. The full surface loop is in expedition_demo.tscn.
const Ship = preload("res://simulation/ship_flight.gd")
const Travel = preload("res://simulation/travel.gd")
const Destinations = preload("res://simulation/destinations.gd")
const SpaceScene = preload("res://spaceflight/space_scene.gd")
const Transition = preload("res://spaceflight/transition_overlay.gd")

var space: Node3D
var transition: CanvasLayer
var ship: Dictionary
var landed_at: String = ""

func _ready() -> void:
	transition = Transition.new()
	add_child(transition)
	ship = Ship.create(Ship.FUEL_LOADS.standard, 87.0)
	_takeoff_from("moon", "mars")

func _takeoff_from(origin: String, target: String) -> void:
	var result: Dictionary = Travel.takeoff(ship, origin, Destinations.get_def(target).space.position)
	if not result.ok:
		transition.play("STRANDED ON %s" % str(Destinations.get_def(origin).name).to_upper(), [result.reason], 3.0)
		return
	ship = result.ship
	var def: Dictionary = Destinations.get_def(origin)
	transition.play("ASCENT FROM %s" % str(def.name).to_upper(), [
		"Ascent burn: %d kg of propellant." % roundi(result.fuel_burned),
		"Surface gravity %.2f m/s² (real, NASA). Ascent Δv in this game scales with it." % def.gravity,
		"Distances and travel times are compressed. Real trip: %s." % Destinations.get_def(target).real_travel])
	await transition.covered
	_show_space(target)

func _show_space(target: String) -> void:
	if space: space.queue_free()
	space = SpaceScene.new()
	space.setup(ship, target)
	space.land_requested.connect(_on_land_requested)
	add_child(space)

func _on_land_requested(id: String) -> void:
	var result: Dictionary = Travel.land(space.ship, id)
	if not result.ok: return
	ship = result.ship
	landed_at = id
	space.paused = true
	var def: Dictionary = Destinations.get_def(id)
	transition.play("TOUCHDOWN: %s" % str(def.name).to_upper(), [
		"Descent burn: %d kg. Fuel left: %d kg." % [roundi(result.fuel_burned), roundi(ship.fuel)],
		def.fiction,
		"Stage 2 demo: taking off again for the return leg. The full surface loop runs in expedition_demo.tscn."], 2.5)
	await transition.covered
	if space: space.queue_free()
	space = null
	await transition.finished
	_takeoff_from(id, "moon" if id != "moon" else "mars")
