extends CharacterBody3D

const WALK_SPEED := 6.0
const RUN_SPEED := 9.5
const JUMP_SPEED := 6.5
const LOOK_SENSITIVITY := 0.0024
const ACCELERATION := 28.0
const DECELERATION := 36.0
const TURN_SPEED := 10.0

var camera: Camera3D
var camera_pivot: Node3D
var ui_open := false
var visual_root: Node3D
var animation_player: AnimationPlayer
var idle_animation := &""
var walk_animation := &""
var run_animation := &""
var locomotion_state := "idle"


func _ready() -> void:
	camera_pivot = get_node_or_null("CameraPivot")
	camera = get_node_or_null("CameraPivot/SpringArm3D/Camera3D")
	if camera == null:
		camera = find_child("Camera3D", true, false)
	visual_root = get_node_or_null("ArtistFox") as Node3D
	if visual_root != null:
		animation_player = visual_root.find_child("AnimationPlayer*", true, false) as AnimationPlayer
	_configure_animations()
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	floor_stop_on_slope = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_ui_open(open: bool) -> void:
	ui_open = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not ui_open and camera_pivot != null:
		rotate_y(-event.relative.x * LOOK_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * LOOK_SENSITIVITY)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -1.05, 0.75)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not ui_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE \
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if not ui_open and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_SPEED

	var input := Vector2.ZERO if ui_open else Input.get_vector(
		"move_left", "move_right", "move_forward", "move_backward")
	var direction := (global_transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var running := not ui_open and Input.is_action_pressed("run")
	var speed := RUN_SPEED if running else WALK_SPEED
	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, ACCELERATION * delta)
		_rotate_visual_toward(input, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECELERATION * delta)
	move_and_slide()
	_update_locomotion(direction != Vector3.ZERO and is_on_floor(), running)


func _configure_animations() -> void:
	if animation_player == null:
		return
	for animation_name in animation_player.get_animation_list():
		var lower := str(animation_name).to_lower()
		if animation_name == &"RESET":
			continue
		if idle_animation.is_empty() and lower.contains("idle"):
			idle_animation = animation_name
		if walk_animation.is_empty() and lower.contains("walk"):
			walk_animation = animation_name
		if run_animation.is_empty() and (lower.contains("run") or lower.contains("gallop")):
			run_animation = animation_name
	if idle_animation.is_empty():
		idle_animation = _first_non_reset_animation()
	if walk_animation.is_empty():
		walk_animation = run_animation
	if run_animation.is_empty():
		run_animation = walk_animation
	_play_animation(idle_animation, 1.0)


func _first_non_reset_animation() -> StringName:
	if animation_player == null:
		return &""
	for animation_name in animation_player.get_animation_list():
		if animation_name != &"RESET":
			return animation_name
	return &""


func _rotate_visual_toward(input: Vector2, delta: float) -> void:
	if visual_root == null or input == Vector2.ZERO:
		return
	# The fox asset faces +Z. Input y=-1 is forward, so PI faces it toward the
	# camera-relative travel direction while the player root owns camera yaw.
	var target_angle := atan2(input.x, input.y)
	visual_root.rotation.y = rotate_toward(
		visual_root.rotation.y,
		target_angle,
		TURN_SPEED * delta
	)


func _update_locomotion(moving_on_floor: bool, running: bool) -> void:
	if not moving_on_floor:
		locomotion_state = "idle"
		_play_animation(idle_animation, 1.0)
		return
	if running:
		locomotion_state = "run"
		_play_animation(run_animation, 1.15)
	else:
		locomotion_state = "walk"
		# The fox pack exposes Run rather than Walk on some imports. Slowing that
		# clip gives a natural walk without requiring a duplicate animation asset.
		_play_animation(walk_animation, 0.72 if walk_animation == run_animation else 1.0)


func _play_animation(animation_name: StringName, speed_scale: float) -> void:
	if animation_player == null or animation_name.is_empty():
		return
	animation_player.speed_scale = speed_scale
	if animation_player.current_animation != animation_name or not animation_player.is_playing():
		animation_player.play(animation_name, 0.16)


func current_locomotion_state() -> String:
	return locomotion_state
