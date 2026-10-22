# Third-person spring-arm camera.
#
# Yaw turns freely through a full circle; pitch is limited only near the
# poles, where looking exactly straight up or down leaves the arm's basis
# degenerate and the view snaps.
extends SpringArm3D
const TouchDevice := preload("res://scripts/touch_controls.gd")
const AutoFollow := preload("res://scripts/camera_auto_follow.gd")

# Looked up by path in the hub, but this scene is also instanced in worlds
# whose root is not HubWorld. Resolved defensively so the camera never hard
# -fails on a scene that happens to be arranged differently.
@onready var player: Node = _find_player()

# Kept as exports so a scene can still narrow the range, but they now default
# to the full usable sphere. The hub previously authored -0.8/-0.1, roughly
# -46 to -6 degrees, which pinned the view downward — the sky islands were
# literally unlookable-at.
@export var minLimitX: float = -1.18   # ~-68 degrees; keeps ground context
@export var maxLimitX: float = 1.05    # ~+60 degrees; avoids underside shots
@export var mouseAcceleration := 0.005
@export var startPitchX := deg_to_rad(-14.0)
@export var startYawY := PI
@export var pivotHeight := 2.05
@export var minZoom := 4.8
@export var maxZoom := 9.2
@export var zoomStep := 0.7

var _follow := AutoFollow.new()

func _ready() -> void:
	add_to_group("touch_look")
	# Nested PackedScene transform overrides have been lost on some imports of
	# NewPlayer.tscn. Establish the gameplay pose here so the spring arm always
	# begins above the character instead of intersecting the terrain.
	position.y = pivotHeight
	rotation.x = clampf(startPitchX, minLimitX, maxLimitX)
	rotation.y = wrapf(startYawY, -PI, PI)
	# Castle foliage and generated architecture use several collision layers.
	# A full mask keeps the camera on the player's side of every solid surface.
	collision_mask = 0xFFFFFFFF
	spring_length = clampf(spring_length, minZoom, maxZoom)
	# Keep the first gameplay frame stable. Capturing immediately while the game
	# steals focus turns the user's movement away from the terminal into a huge
	# orbit and can leave them staring at empty sky. A click below opts into look.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _exit_tree() -> void:
	# Do not strand a hidden/captured cursor when leaving the 3D world.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	# The player may be absent (or still loading) in non-hub scenes; only
	# block camera input when there is a player and it is mid-interaction
	# (e.g. Milo's chat panel is open). Checked first so a click on a UI
	# button while talking to Milo cannot recapture/hide the mouse out from
	# under the player before the click even reaches the button.
	var busy: bool = player != null and "interacting" in player and player.interacting
	# Escape releases the pointer for menus and desktop use. Clicking the game
	# recaptures it, matching the other third-person camera in this project.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if busy:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_length = maxf(minZoom, spring_length - zoomStep)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_length = minf(maxZoom, spring_length + zoomStep)
			return
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = TouchDevice.captured_mode()
		return
	# Emulated motion is a finger on a phone or tablet; TouchControls sends
	# look drags to touch_look() instead, so taps no longer spin the view.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		rotateFromVector(event.relative * mouseAcceleration)


# Look drag from the on-screen touch controls (scripts/touch_controls.gd).
func touch_look(relative: Vector2) -> void:
	if player != null and "interacting" in player and player.interacting:
		return
	rotateFromVector(relative * mouseAcceleration)

func _process(delta: float) -> void:
	if player is CharacterBody3D and not ("interacting" in player and player.interacting):
		# The arm hangs off the player, so its local yaw is offset from the
		# world yaw by whatever the player body itself is turned.
		var body_yaw := global_rotation.y - rotation.y
		rotation.y = _follow.step(delta, global_rotation.y, player.velocity) - body_yaw


## The yaw movement should be relative to (see camera_auto_follow.gd).
func movement_yaw() -> float:
	return _follow.control_yaw if _follow.latched else global_rotation.y


func rotateFromVector(v: Vector2):
	if v.length() == 0: return
	_follow.looked()
	# Wrapped rather than accumulated: yaw turns through a full circle in
	# both directions without drifting into large float values over a session.
	rotation.y = wrapf(rotation.y - v.x, -PI, PI)
	rotation.x = clamp(rotation.x - v.y, minLimitX, maxLimitX)


func _find_player() -> Node:
	var byGroup := get_tree().get_nodes_in_group("player")
	if byGroup.size() > 0:
		return byGroup[0]
	# The camera hangs off the player in NewPlayer.tscn, so walking up is a
	# reliable fallback when the group is missing.
	var node := get_parent()
	while node != null:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null 
