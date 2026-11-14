extends Node3D
## Stage 1 demonstration: fly the ship among navigation buoys. Fuel, mass and thrust come from
## simulation/ship_flight.gd. Run res://scenes/spaceflight/ship_sandbox.tscn.
const Ship = preload("res://simulation/ship_flight.gd")
const Pilot = preload("res://spaceflight/pilot_input.gd")
const ShipRig = preload("res://spaceflight/ship_rig.gd")
const ChaseCamera = preload("res://spaceflight/chase_camera.gd")
const SpaceSky = preload("res://spaceflight/space_sky.gd")
const FlightHUD = preload("res://spaceflight/flight_hud.gd")

signal ship_updated(ship: Dictionary)

@export var cargo_mass: float = 87.0
@export var fuel_load: String = "standard"
var ship: Dictionary
var rig: Node3D
var camera: Camera3D
var hud: CanvasLayer
var input_override: Variant = null  # tests can set a Dictionary to fly without a keyboard

func _ready() -> void:
	add_child(SpaceSky.new())
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 40, 0)
	sun.light_energy = 1.3
	add_child(sun)
	_buoys()
	ship = Ship.create(float(Ship.FUEL_LOADS[fuel_load]), cargo_mass)
	rig = ShipRig.new()
	add_child(rig)
	camera = ChaseCamera.new()
	camera.target = rig
	camera.current = true
	add_child(camera)
	rig.apply(ship)
	camera.snap_now()
	hud = FlightHUD.new()
	add_child(hud)

func _buoys() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f3c582")
	material.emission_enabled = true
	material.emission = Color("f3c582")
	material.emission_energy_multiplier = 1.5
	var ring := TorusMesh.new()
	ring.inner_radius = 5.5
	ring.outer_radius = 6.0
	for i in range(24):
		var buoy := MeshInstance3D.new()
		buoy.mesh = ring
		buoy.material_override = material
		buoy.position = Vector3(sin(i * 0.9) * 60.0, cos(i * 0.6) * 20.0, -i * 70.0)
		buoy.rotation.x = PI / 2.0
		add_child(buoy)

func _physics_process(delta: float) -> void:
	var input: Dictionary = input_override if input_override is Dictionary else Pilot.read()
	ship = Ship.step(ship, input, delta)
	rig.apply(ship)
	camera.speed_hint = Ship.speed(ship)
	ship_updated.emit(ship)
	hud.show_flight({
		"speed": Ship.speed(ship), "throttle": ship.throttle, "braking": ship.braking,
		"fuel": ship.fuel, "fuel_capacity": ship.fuel_capacity, "delta_v": Ship.delta_v_remaining(ship),
		"mass": {"hull": ship.dry_mass, "cargo": ship.cargo_mass, "fuel": ship.fuel, "total": Ship.total_mass(ship)},
		"destination_line": "FLIGHT TEST RANGE  ·  fly through the amber buoys",
		"warnings": ["Fuel exhausted: you can only coast now."] if ship.fuel <= 0.0 else [],
	})
