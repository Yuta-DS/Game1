extends Node3D

## The inside of the Rainbow Galaxy Train.
##
## The story asks for a cabin the player occupies rather than a menu they click
## through: they turn the Destination Wheel, work the speed lever and brake,
## ring the light bell, and watch the galaxy move past the window. This script
## drives the visible parts of that cabin and hands every decision to the
## GalaxyTrain node above it, which is the authority on where the train may go.

@export var train_path: NodePath = NodePath("..")

## How far the scenery scrolls over a full journey, in metres. Large enough
## that the window never repeats within one ride.
@export var scenery_travel: float = 400.0

## How fast the destination wheel turns towards the station the player picked.
@export var wheel_turn_speed: float = 4.0

@onready var _wheel: Node3D = get_node_or_null("Controls/DestinationWheel")
@onready var _lever: Node3D = get_node_or_null("Controls/SpeedLever")
@onready var _brake: Node3D = get_node_or_null("Controls/BrakeHandle")
@onready var _scenery: Node3D = get_node_or_null("WindowView/Scenery")
@onready var _bell_light: OmniLight3D = get_node_or_null("Controls/LightBell/BellGlow")

var _train: Node = null

## Where each station sits on the face of the wheel, in degrees.
const WHEEL_ANGLES := {
	"gallery": 0.0,
	"mind_spark": 90.0,
	"heart_melody": 180.0,
	"creators_light": 270.0,
	"castle": 45.0,
}

var _target_wheel_angle: float = 0.0
var _bell_glow: float = 0.0
var _scenery_start := Vector3.ZERO


func _ready() -> void:
	_train = get_node_or_null(train_path)
	if _train == null:
		push_error("TrainCabin: no GalaxyTrain found at %s" % train_path)
		return

	if _scenery:
		_scenery_start = _scenery.position

	_train.wheel_turned.connect(_on_wheel_turned)
	_train.bell_rung.connect(_on_bell_rung)
	_train.departed.connect(_on_departed)
	_train.arrived.connect(_on_arrived)


func _process(delta: float) -> void:
	if _train == null:
		return

	_turn_wheel(delta)
	_move_scenery()
	_set_lever_and_brake()
	_fade_bell(delta)


## The wheel eases towards the chosen symbol rather than snapping, so turning
## it reads as a deliberate act.
func _turn_wheel(delta: float) -> void:
	if _wheel == null:
		return
	var current := _wheel.rotation_degrees.y
	var wanted := _target_wheel_angle
	_wheel.rotation_degrees.y = lerp_angle(
		deg_to_rad(current), deg_to_rad(wanted), clampf(delta * wheel_turn_speed, 0.0, 1.0)
	) * 180.0 / PI


## The window view slides past in step with how far the journey has come, so
## braking really does slow the scenery down.
func _move_scenery() -> void:
	if _scenery == null:
		return
	_scenery.position = _scenery_start + Vector3(
		0.0, 0.0, _train.journey_progress() * scenery_travel
	)


func _set_lever_and_brake() -> void:
	if _lever:
		# Lever swings between -35 and +35 degrees across the speed range.
		var t: float = inverse_lerp(0.25, 2.0, _train.speed)
		_lever.rotation_degrees.x = lerp(-35.0, 35.0, clampf(t, 0.0, 1.0))
	if _brake:
		_brake.rotation_degrees.x = -30.0 if _train.get("_braking") else 0.0


func _fade_bell(delta: float) -> void:
	if _bell_light == null:
		return
	_bell_glow = maxf(0.0, _bell_glow - delta * 1.5)
	_bell_light.light_energy = _bell_glow * 6.0


func _on_wheel_turned(station_id: String) -> void:
	_target_wheel_angle = WHEEL_ANGLES.get(station_id, 0.0)


func _on_bell_rung() -> void:
	# The bell wakes the glowing flowers and musical stars beside the track.
	_bell_glow = 1.0


func _on_departed(_from_station: String, _to_station: String) -> void:
	if _scenery:
		_scenery.position = _scenery_start


func _on_arrived(_station_id: String) -> void:
	if _scenery:
		_scenery.position = _scenery_start


# -----------------------
# THE CONTROLS, FOR THE CABIN UI TO CALL
# -----------------------

func turn_wheel_to(station_id: String) -> bool:
	return _train.turn_wheel_to(station_id) if _train else false


func pull_departure_lever() -> bool:
	return _train.depart() if _train else false


func set_speed(value: float) -> void:
	if _train:
		_train.set_speed(value)


func hold_brake(pressed: bool) -> void:
	if _train:
		_train.set_brake(pressed)


func ring_bell() -> void:
	if _train:
		_train.ring_bell()


func ask_milo_to_drive(enabled: bool) -> void:
	if _train:
		_train.set_milo_driving(enabled)
