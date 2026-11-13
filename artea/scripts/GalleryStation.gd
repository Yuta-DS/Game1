extends Node3D

## The ARTÉA Gallery Station: where the Rainbow Galaxy Train lives.
##
## Gates around the town do not load kingdoms themselves. They ask the station
## to carry the player, and the station runs a real ride — wheel, departure,
## journey, arrival — before the kingdom scene is loaded. That keeps the story's
## promise that the train is not a travel menu.

signal ride_started(station_id: String)
signal ride_finished(station_id: String)

## The train scene parked at this platform.
@export var train_scene: PackedScene = null

## Skips the ride and loads straight through. Useful for testing, and for
## players who would rather not sit through the journey every time.
@export var instant_travel: bool = false

## How far along the rails the train travels during a ride, in metres. The
## train is visible from the town, so the journey can be watched from outside
## as well as from inside the cabin.
@export var visible_travel: float = 240.0

var _train: Node = null
var _pending_scene: String = ""
var _riding: bool = false
var _train_home := Vector3.ZERO
var _ride_heading := Vector3.FORWARD

## Which way each station lies from the platform, so the train sets off towards
## the right gate rather than always the same way.
const HEADINGS := {
	"mind_spark": Vector3(0, 0, -1),
	"heart_melody": Vector3(1, 0, 0),
	"creators_light": Vector3(0, 0, 1),
	"castle": Vector3(1, 0, 0),
	"gallery": Vector3(-1, 0, 0),
}


func _ready() -> void:
	_spawn_train()
	_connect_gates()


func _spawn_train() -> void:
	if train_scene == null:
		return
	_train = train_scene.instantiate()
	add_child(_train)
	if _train is Node3D:
		_train_home = _train.position
	if _train.has_signal("arrived"):
		_train.arrived.connect(_on_train_arrived)


## Finds every gate in the level and listens for boarding requests, so gates
## do not need to know the station exists.
func _connect_gates() -> void:
	for gate in get_tree().get_nodes_in_group("station_gate"):
		if gate.has_signal("boarding_requested"):
			gate.boarding_requested.connect(_on_boarding_requested)


func _on_boarding_requested(station_id: String, destination_scene: String) -> void:
	if _riding:
		return

	if instant_travel or _train == null:
		get_tree().change_scene_to_file(destination_scene)
		return

	if not _train.turn_wheel_to(station_id):
		# The wheel refused, which means the station is not open after all.
		return

	_pending_scene = destination_scene
	_ride_heading = HEADINGS.get(station_id, Vector3.FORWARD)
	_riding = _train.depart()
	if _riding:
		_face_the_journey()
		ride_started.emit(station_id)
	else:
		_pending_scene = ""


## Points the train down the line it is about to travel.
func _face_the_journey() -> void:
	if not _train is Node3D or _ride_heading.length_squared() < 0.01:
		return
	_train.rotation.y = atan2(_ride_heading.x, _ride_heading.z)


## The train really rolls out of the station, so the ride can be watched from
## the town as well as from the cabin window.
func _process(_delta: float) -> void:
	if not _riding or not _train is Node3D:
		return
	_train.position = _train_home + _ride_heading * (_train.journey_progress() * visible_travel)


func _on_train_arrived(station_id: String) -> void:
	if not _riding:
		return
	_riding = false

	# The train comes back to its platform, ready for the next journey.
	if _train is Node3D:
		_train.position = _train_home

	ride_finished.emit(station_id)

	if _pending_scene != "":
		var scene := _pending_scene
		_pending_scene = ""
		get_tree().change_scene_to_file(scene)


func is_riding() -> bool:
	return _riding
