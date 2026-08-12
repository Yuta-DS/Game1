# CameraFollow.gd
#
# Third-person orbit camera. The player drives the yaw/pitch with the mouse and
# the camera trails the player at that angle, so the view follows the cursor
# instead of being welded behind the player's back.
extends Camera3D

@export var player_path: NodePath
@export var follow_height := 3.0        # how high the camera sits
@export var follow_distance := 7.0      # how far behind the player
@export var follow_side := 0.0          # offset to the side (0 = center)
@export var follow_look_at_offset := Vector3(0, 1.6, 0)
@export var lerp_speed := 8.0           # how smoothly it follows
@export var collision_margin := 0.35

@export var mouse_sensitivity := 0.005
@export var initial_pitch_degrees := -15.0
## Pitch clamp. Past roughly these angles the camera ends up inside the floor or
## staring at the ceiling, and look_at() degenerates when it lines up with UP.
# Near-vertical rather than fully vertical on purpose: at exactly +/-90 the
# view direction becomes parallel with Vector3.UP and look_at() degenerates,
# which reads in game as the camera locking up at the extremes. 89 gives the
# player effectively the whole sphere without ever hitting that singularity.
@export var min_pitch_degrees := -89.0
@export var max_pitch_degrees := 89.0

## Captures the cursor on load so mouse motion turns the view. Turn this off for
## scenes that need a visible cursor for UI.
@export var capture_mouse := true

var _mode := "follow"                   # "follow" or "inspect"
var _player: Node3D
var _tween: Tween
var _inspect_focus := Vector3.ZERO

var _yaw := 0.0
var _pitch := 0.0
var _touch_emulation_was_on := false

func _ready() -> void:
	_player = get_node_or_null(player_path)
	current = true  # make this the active camera

	# The project ships with input_devices/pointing/emulate_touch_from_mouse on
	# for the mobile HUD. That converts mouse motion into screen-drag events, so
	# InputEventMouseMotion never arrives and the view cannot be turned at all.
	# Switch it off for as long as this camera is alive and restore it on exit,
	# so the on-screen joystick scenes keep working.
	_touch_emulation_was_on = Input.is_emulating_touch_from_mouse()
	Input.set_emulate_touch_from_mouse(false)

	# Start behind the player rather than snapping the view on the first frame.
	if _player:
		_yaw = _player.global_rotation.y
	_pitch = deg_to_rad(initial_pitch_degrees)

	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree() -> void:
	Input.set_emulate_touch_from_mouse(_touch_emulation_was_on)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# _input rather than _unhandled_input: the rating UI is a Control layer, and
# once it has focus it consumes events before they reach the unhandled stage.
func _input(event: InputEvent) -> void:
	# Orbit whenever the camera is in follow mode. This deliberately does not
	# require MOUSE_MODE_CAPTURED: capture can silently fail to apply (it does
	# on a headless run, and can lag by a frame after an alt-tab), and gating on
	# it meant the view froze with no way to recover.
	if event is InputEventMouseMotion and _mode == "follow":
		# Wrapped rather than left to accumulate: yaw turns freely through a
		# full circle in both directions, and wrapping keeps it from drifting
		# into large float values over a long session.
		_yaw = wrapf(_yaw - event.relative.x * mouse_sensitivity, -PI, PI)
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))

	# Escape releases the cursor so the player can reach menus; clicking back in
	# the window recaptures it.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and capture_mouse and _mode == "follow":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if _mode == "follow" and _player:
		var focus := _player.global_transform.origin + follow_look_at_offset

		# Orbit around the player using the mouse-driven yaw/pitch instead of
		# the player's own facing, which is what made the view unturnable.
		var offset := Vector3(
			sin(_yaw) * cos(_pitch),
			sin(-_pitch),
			cos(_yaw) * cos(_pitch)
		) * follow_distance

		var target := focus + offset
		target.y += follow_height
		target += Vector3(cos(_yaw), 0.0, -sin(_yaw)) * follow_side

		# Keep the third-person camera on the player's side of walls, islands and
		# large props. Without this cast the camera crossed geometry and the whole
		# screen could be hidden by the object behind the player.
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(focus, target)
		if _player is CollisionObject3D:
			query.exclude = [(_player as CollisionObject3D).get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var hit_position: Vector3 = hit.position
			var toward_focus := hit_position.direction_to(focus)
			target = hit_position + toward_focus * collision_margin

		global_transform.origin = global_transform.origin.lerp(target, clamp(lerp_speed * delta, 0.0, 1.0))

		# Looking straight up or down leaves the view direction parallel to
		# Vector3.UP, where look_at() has no valid basis and the camera snaps.
		# Tilting the up-vector along the view's own horizontal heading keeps
		# a stable basis all the way to the poles, so the player can look
		# fully overhead or straight down without the view breaking.
		var to_focus := focus - global_transform.origin
		var up_hint := Vector3.UP
		if absf(to_focus.normalized().dot(Vector3.UP)) > 0.999:
			up_hint = Vector3(sin(_yaw), 0.0, cos(_yaw))
		look_at(focus, up_hint)

	elif _mode == "inspect":
		look_at(_inspect_focus, Vector3.UP)

func enter_inspect(target: Node3D) -> void:
	_mode = "inspect"
	_inspect_focus = target.global_transform.origin

	# Free the cursor so the rating panel can be clicked while inspecting.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var forward := target.global_transform.basis.z.normalized()
	var cam_pos := _inspect_focus + (forward * 2.2) + Vector3(0, 1.4, 0)

	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "global_transform:origin", cam_pos, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func exit_inspect() -> void:
	_mode = "follow"
	if _tween: _tween.kill()

	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
