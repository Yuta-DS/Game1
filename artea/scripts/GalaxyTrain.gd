extends Node3D

## The Rainbow Galaxy Train.
##
## The story is explicit that this is not a travel menu: the player rides in
## the cabin, turns the Destination Wheel, works the speed lever and brake,
## rings the light bell, and watches the scenery change. The train therefore
## owns a real journey with a duration, not an instant scene swap — the ride
## itself is part of the reward.
##
## Which destinations the wheel will accept comes from JourneyState, so a
## station that has not been discovered simply is not on the dial.

signal departed(from_station: String, to_station: String)
signal arrived(station_id: String)
signal wheel_turned(station_id: String)
signal bell_rung()
signal speed_changed(speed: float)

enum State { WAITING, TRAVELLING, ARRIVING }

## Where the train is standing when it is not moving.
@export var current_station: String = "gallery"

## How long a full-length ride takes at normal speed, in seconds. The speed
## lever scales this, and the story wants sightseeing to be a real choice, so
## the slow end is genuinely slower rather than cosmetic.
@export var base_journey_time: float = 24.0

## Speed lever, from a slow sightseeing crawl to a brisk run.
@export_range(0.25, 2.0, 0.05) var speed: float = 1.0

## When true, Milo drives and the player can just look out of the window.
@export var milo_driving: bool = false

var state: State = State.WAITING
var destination: String = ""

## 0.0 at departure, 1.0 on arrival.
var progress: float = 0.0

var _braking: bool = false
var _journey: Node = null


func _ready() -> void:
	_journey = get_node_or_null("/root/JourneyState")
	if _journey == null:
		push_error("GalaxyTrain: JourneyState singleton not found; the wheel will not turn.")
	set_process(true)


func _process(delta: float) -> void:
	if state != State.TRAVELLING:
		return

	var rate := speed
	if _braking:
		# The brake is for slowing down near views and memory stars, not for
		# stopping the journey dead.
		rate *= 0.25

	progress += (delta / base_journey_time) * rate
	if progress >= 1.0:
		progress = 1.0
		_arrive()


# -----------------------
# THE DESTINATION WHEEL
# -----------------------

## Every station the wheel will currently accept.
func available_destinations() -> Array[String]:
	if _journey == null:
		return []
	return _journey.reachable_from(current_station)


## Turns the wheel towards a station. Returns false when that station is not
## on the dial, so the cabin UI can leave the symbol dark rather than pretend.
func turn_wheel_to(station_id: String) -> bool:
	if state == State.TRAVELLING:
		return false
	if not station_id in available_destinations():
		return false

	destination = station_id
	wheel_turned.emit(station_id)
	return true


## Begins the ride. The train must have somewhere to go.
func depart() -> bool:
	if state == State.TRAVELLING or destination == "":
		return false

	state = State.TRAVELLING
	progress = 0.0
	departed.emit(current_station, destination)
	return true


func _arrive() -> void:
	state = State.ARRIVING
	current_station = destination
	destination = ""
	_braking = false
	arrived.emit(current_station)
	state = State.WAITING


# -----------------------
# THE OTHER CONTROLS
# -----------------------

## Speed Lever.
func set_speed(new_speed: float) -> void:
	speed = clampf(new_speed, 0.25, 2.0)
	speed_changed.emit(speed)


## Brake Handle. Held down to linger near scenery.
func set_brake(pressed: bool) -> void:
	_braking = pressed


## Light Bell — wakes glowing flowers, musical stars and friendly creatures
## beside the track. Purely for delight; it does not affect the journey.
func ring_bell() -> void:
	bell_rung.emit()


## Milo Drive. The player can hand over at any time.
func set_milo_driving(enabled: bool) -> void:
	milo_driving = enabled
	if enabled and state == State.WAITING and destination == "":
		# Milo heads for wherever the story wants to go next.
		var next: String = _journey.next_story_station() if _journey else ""
		if next != "" and next != current_station:
			turn_wheel_to(next)


## How far along the ride the train is, for scenery and the window view.
func journey_progress() -> float:
	return progress


func is_travelling() -> bool:
	return state == State.TRAVELLING
