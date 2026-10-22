# camera_auto_follow.gd
#
# On phones and tablets, swings a third-person camera round behind the player
# while they run, so turning around turns the view with them. Used by
# CameraFollow.gd, the hub's camera_controller.gd and the Heart Melody camera.
# With a mouse the player steers the view themselves: there the keys never
# turn it.
#
# Movement is camera-relative, which on its own makes this loop forever: hold
# S, the fox turns to face the camera, the camera swings behind it, S now means
# the other way, and round it goes. So the direction movement reads from
# (control_yaw) stays where the view was when the input started, and only
# catches up when the input is released, changes direction, or the player looks
# around by hand.
extends RefCounted

const TouchDevice := preload("res://scripts/touch_controls.gd")

## Seconds after a mouse or finger look before the camera takes over again.
const LOOK_HOLD := 1.0
## How quickly the view swings behind (exponential rate, per second).
const SWING_RATE := 2.5
const MIN_SPEED := 1.0
## Stick or key changes smaller than this keep the same movement frame.
const RELATCH_ANGLE := 0.52

## Phones and tablets have no mouse look to steer with, so only there does the
## camera follow the player's turns. Settable so tests can cover both.
var follow_every_turn := TouchDevice.is_touch_device()

var control_yaw := 0.0
## True while movement input is held and control_yaw is in use.
var latched := false
var _input := Vector2.ZERO
var _since_look := LOOK_HOLD
var _resync := true


func looked() -> void:
	_since_look = 0.0
	_resync = true


# Returns the new view yaw. velocity is the player's, in world space.
func step(delta: float, view_yaw: float, velocity: Vector3) -> float:
	_since_look += delta
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	latched = not input.is_zero_approx()
	if _resync or not latched or _input.is_zero_approx() \
			or absf(input.angle_to(_input)) > RELATCH_ANGLE:
		_resync = false
		_input = input
		control_yaw = view_yaw
	var flat := Vector2(velocity.x, velocity.z)
	if follow_every_turn and latched and _since_look >= LOOK_HOLD and flat.length() >= MIN_SPEED:
		# The yaw whose forward (-sin, -cos) points along the run.
		view_yaw = lerp_angle(view_yaw, atan2(-flat.x, -flat.y), 1.0 - exp(-SWING_RATE * delta))
	return wrapf(view_yaw, -PI, PI)
