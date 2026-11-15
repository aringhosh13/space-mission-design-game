extends Node
## Stage 3 demonstration: the Aurora Delta landing region on Mars with the rover deployed.
const MissionEngine = preload("res://simulation/mission_engine.gd")
const SurfaceScene = preload("res://spaceflight/surface_scene.gd")
const Destinations = preload("res://simulation/destinations.gd")

var surface: Node3D

func _ready() -> void:
	var engine = MissionEngine.new()
	var config: Dictionary = {"battery": "compact", "power": "solar", "instrument": "drill"}
	var state: Dictionary = engine.act(engine.create_surface_mission(config, 42, "mars"), "launch")
	surface = SurfaceScene.new()
	surface.setup("mars", state, {
		"subtitle": "AURORA DELTA (FICTIONAL REGION)  /  GRAVITY 38% OF EARTH'S (NASA)",
		"notes": "Solar output is 43% of the Moon's (derived from Mars's 1.5 AU distance). Driving costs more in sand.\nOnly scan data can be transmitted: sample science counts when cores are flown home.",
	})
	add_child(surface)
