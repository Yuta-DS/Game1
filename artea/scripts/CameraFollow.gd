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
## Follow rate used while riding the train. Higher than the on-foot rate: the
## ride already carries the camera along with it, so this only has to settle the
## small residual, and a slow rate there reads as the view sloshing behind.
@export var ride_lerp_speed := 14.0
@export var collision_margin := 0.35

## Scroll-wheel zoom bounds for the third-person view. The far end is wide
## enough to take in the train and the sky islands around it while riding.
@export var min_follow_distance := 3.0
@export var max_follow_distance := 26.0
@export var zoom_step := 1.4

## Fallback eye offset for characters without a measured head/eye socket.
@export var first_person_eye := Vector3(0.0, 1.55, 0.0)
## Wider first-person framing without moving the eye behind the character.
@export_range(60.0, 110.0, 1.0) var first_person_fov := 95.0
## A slight downward gaze shows the route and the low dashboard from the eyes.
@export_range(-10.0, 0.0, 0.5) var driver_initial_pitch_degrees := -4.0

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

## "third" or "first". Boarding starts in third; 3 and 4 switch freely.
var _view := "third"
## Set while the player is aboard the train. First person is still selectable
## with 3, but boarding always starts from the third-person view.
var _ride_view_active := false
var _driver_view_train: Node3D
var _driver_eye_local := Vector3.ZERO
var _previous_driver_yaw := 0.0
var _third_person_fov := 75.0

## Last frame's focus point, used to carry the train's motion into the camera
## before smoothing so a fast-moving ride does not leave the view trailing.
var _previous_focus := Vector3.ZERO

var _yaw := 0.0
var _pitch := 0.0
var _touch_emulation_was_on := false
## Track deliberate cursor release separately from OS pointer-lock state:
## Web capture can be deferred/denied, but Escape must still suspend looking.
var _mouse_look_released := false
var _passenger_prompt_active := false
var _mouse_look_released_before_prompt := false

func _ready() -> void:
	# Follow after gameplay movers have published their final frame transform.
	# This is especially important for sync-to-physics train platforms, whose
	# rider position otherwise reaches the camera one render frame late.
	process_priority = 100
	_third_person_fov = fov
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
	# Scene cameras are authored at the origin. Easing from there can begin
	# inside a floor, wall or large prop and briefly fill the whole screen with
	# geometry when the gallery/Castle Galaxy first appears. Start at the same
	# collision-safe follow target used during normal play.
	if _player:
		_snap_to_follow_target()

	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree() -> void:
	Input.set_emulate_touch_from_mouse(_touch_emulation_was_on)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# _input rather than _unhandled_input: the rating UI is a Control layer, and
# once it has focus it consumes events before they reach the unhandled stage.
func _input(event: InputEvent) -> void:
	if not current or _passenger_prompt_active:
		return
	# Orbit whenever the camera is in follow mode. This deliberately does not
	# require MOUSE_MODE_CAPTURED: capture can silently fail to apply (it does
	# on a headless run, and can lag by a frame after an alt-tab), and gating on
	# it meant the view froze with no way to recover.
	if event is InputEventMouseMotion and _mode == "follow" and not _mouse_look_released:
		# Wrapped rather than left to accumulate: yaw turns freely through a
		# full circle in both directions, and wrapping keeps it from drifting
		# into large float values over a long session.
		_yaw = wrapf(_yaw - event.relative.x * mouse_sensitivity, -PI, PI)
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))

	# Scroll wheel pulls the third-person view in and out. Bound to the raw
	# button rather than an action because the project's input map has no zoom
	# action, and the wheel is what players reach for by reflex.
	if event is InputEventMouseButton and event.pressed and _mode == "follow":
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(-zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(zoom_step)

	# 1 and 2 are reserved for Crown Line drive/passenger selection. Camera view
	# switching remains available on 3 and 4.
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_3:
			set_view_mode("first")
			_resume_mouse_look()
		elif key == KEY_4:
			set_view_mode("third")
			_resume_mouse_look()

	# Escape releases both pointer lock and camera motion for menu interaction.
	if event.is_action_pressed("ui_cancel"):
		_release_mouse_look()

func _unhandled_input(event: InputEvent) -> void:
	# Let GUI buttons consume clicks first; only game-space clicks recapture.
	if current and not _passenger_prompt_active and event is InputEventMouseButton and event.pressed and capture_mouse and _mode == "follow" \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_resume_mouse_look()

func _release_mouse_look() -> void:
	_mouse_look_released = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume_mouse_look() -> void:
	if _mode != "follow" or _passenger_prompt_active:
		return
	_mouse_look_released = false
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_passenger_prompt_active(active: bool) -> void:
	if active == _passenger_prompt_active:
		return
	_passenger_prompt_active = active
	if active:
		_mouse_look_released_before_prompt = _mouse_look_released
		_release_mouse_look()
	elif not _mouse_look_released_before_prompt:
		_resume_mouse_look()

func _process(delta: float) -> void:
	if _driver_view_train != null and not is_instance_valid(_driver_view_train):
		end_ride_view()
	if _mode == "follow" and _player and _view == "first":
		# First person sits at the player's eye and aims along the same yaw and
		# pitch the mouse already drives, so switching views never changes which
		# way "forward" is for movement.
		global_transform.origin = _player.global_transform.origin + first_person_eye
		if _player.has_method("get_first_person_eye_position"):
			global_position = _player.call("get_first_person_eye_position", first_person_eye)
		if _has_driver_view():
			# The eye follows the character's pose. Mouse yaw remains a free look
			# offset relative to the train instead of drifting off the track.
			if not _player.has_method("get_first_person_eye_position"):
				global_position = _driver_view_train.to_global(_driver_eye_local)
			var train_yaw := _driver_view_train.global_rotation.y
			_yaw = wrapf(_yaw + angle_difference(_previous_driver_yaw, train_yaw), -PI, PI)
			_previous_driver_yaw = train_yaw
			global_basis = _driver_view_train.global_basis.orthonormalized() * Basis.from_euler(
				Vector3(_pitch, angle_difference(train_yaw, _yaw), 0.0))
			return
		var aim := Vector3(
			sin(_yaw) * cos(_pitch),
			sin(-_pitch),
			cos(_yaw) * cos(_pitch)
		)
		var eye_target := global_transform.origin - aim
		var eye_up := Vector3.UP
		if absf(aim.normalized().dot(Vector3.UP)) > 0.999:
			eye_up = Vector3(sin(_yaw), 0.0, cos(_yaw))
		look_at(eye_target, eye_up)
		return

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
		target = _collision_safe_target(focus, target)

		# Exponential smoothing rather than `lerp_speed * delta` used directly as
		# a weight: the raw form is framerate-dependent (and above 1/lerp_speed
		# seconds per frame it overshoots outright), which made the view judder
		# whenever the frame time moved.
		var smoothing := 1.0 - pow(2.0, -lerp_speed * delta)

		# While riding, the focus is bolted to a train covering several metres per
		# frame. A camera that eases toward it from behind can never catch up, so
		# it lags and then over-corrects — measured at 7.4 degrees of swing in a
		# single frame, far rougher than the train itself. Carrying the ride's own
		# motion forward first means the smoothing only has to absorb the small
		# residual, not the whole distance the train travelled.
		if _ride_view_active:
			var ride_motion := focus - _previous_focus
			global_transform.origin += ride_motion
			smoothing = 1.0 - pow(2.0, -ride_lerp_speed * delta)

		global_transform.origin = global_transform.origin.lerp(
			target, clampf(smoothing, 0.0, 1.0))
		_previous_focus = focus

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


func _zoom_by(amount: float) -> void:
	follow_distance = clampf(follow_distance + amount,
		min_follow_distance, max_follow_distance)


# "first" or "third". Public so the train can force the third-person view when
# the player boards, and so a HUD button can offer the same toggle as 3/4.
func set_view_mode(view: String) -> void:
	if view != "first" and view != "third":
		return
	if view == "first" and _view != "first":
		_third_person_fov = fov
	if view == "first" and _view != "first" and _has_driver_view():
		_yaw = _driver_view_train.global_rotation.y
		_previous_driver_yaw = _yaw
		_pitch = deg_to_rad(driver_initial_pitch_degrees)
	_view = view
	_apply_view_fov()
	_apply_character_visibility()
	if _view == "third" and _player:
		_snap_to_follow_target()


func _apply_view_fov() -> void:
	fov = first_person_fov if _view == "first" and _mode == "follow" else _third_person_fov


# In first person the camera sits at the player's eye, which is inside their own
# head — without this the whole screen is filled by the back of the character's
# face. Hiding only the visual children leaves collision and gameplay untouched.
func _apply_character_visibility() -> void:
	if _player == null:
		return
	for child in _player.get_children():
		if child is VisualInstance3D or child is Node3D:
			if child is CollisionShape3D or child is Camera3D:
				continue
			(child as Node3D).visible = _view != "first"


func get_view_mode() -> String:
	return _view


# Called by the train when the player takes a seat or the driver cab. Riding
# always begins in third person — the point of being on the train is seeing it —
# and pulls the view out far enough to take in the carriage and the route.
func begin_ride_view(distance := 14.0) -> void:
	_ride_view_active = true
	follow_distance = clampf(distance, min_follow_distance, max_follow_distance)
	# Seed the motion carry-over from where the focus is now. Without this the
	# first ride frame treats the entire focus vector as one frame of travel and
	# throws the camera across the level.
	if _player != null:
		_previous_focus = _player.global_transform.origin + follow_look_at_offset
	set_view_mode("third")


func end_ride_view() -> void:
	_ride_view_active = false
	_driver_view_train = null


func configure_driver_view(train: Node3D, eye_local: Vector3) -> void:
	_driver_view_train = train
	_driver_eye_local = eye_local


func _has_driver_view() -> bool:
	return _ride_view_active and is_instance_valid(_driver_view_train)


func is_ride_view_active() -> bool:
	return _ride_view_active


func _snap_to_follow_target() -> void:
	# Public callers (the train forcing a ride view, a scene re-seating the
	# camera) can reach this before _ready has resolved the player, so this
	# cannot assume one exists.
	if _player == null:
		return
	var focus := _player.global_transform.origin + follow_look_at_offset
	var offset := Vector3(
		sin(_yaw) * cos(_pitch),
		sin(-_pitch),
		cos(_yaw) * cos(_pitch)
	) * follow_distance
	var target := focus + offset
	target.y += follow_height
	target += Vector3(cos(_yaw), 0.0, -sin(_yaw)) * follow_side
	global_position = _collision_safe_target(focus, target)
	_previous_focus = focus
	look_at(focus, Vector3.UP)


func _collision_safe_target(focus: Vector3, target: Vector3) -> Vector3:
	# Keep the third-person camera on the player's side of walls, islands and
	# large props. Without this cast the camera crossed geometry and the whole
	# screen could be hidden by the object behind the player.
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(focus, target)
	var excluded_rids: Array[RID] = []
	if _player is CollisionObject3D:
		excluded_rids.append((_player as CollisionObject3D).get_rid())
	# The train is the platform carrying the camera focus, not an intervening
	# wall. Letting the camera ray hit its own carriage shell makes the target
	# alternate between stopped and moving as rail geometry crosses the ray.
	if _ride_view_active:
		for ride_body in get_tree().get_nodes_in_group("ride_camera_ignore"):
			if ride_body is CollisionObject3D:
				excluded_rids.append((ride_body as CollisionObject3D).get_rid())
	query.exclude = excluded_rids
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return target
	var hit_position: Vector3 = hit.position
	var toward_focus := hit_position.direction_to(focus)
	return hit_position + toward_focus * collision_margin

func enter_inspect(target: Node3D) -> void:
	_mode = "inspect"
	_apply_view_fov()
	_inspect_focus = target.global_transform.origin

	# Free the cursor so the rating panel can be clicked while inspecting.
	_release_mouse_look()

	var forward := target.global_transform.basis.z.normalized()
	var cam_pos := _inspect_focus + (forward * 2.2) + Vector3(0, 1.4, 0)

	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "global_transform:origin", cam_pos, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func exit_inspect() -> void:
	_mode = "follow"
	_apply_view_fov()
	if _tween: _tween.kill()

	_resume_mouse_look()
