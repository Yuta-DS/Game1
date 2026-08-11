extends CharacterBody3D

@export var speed: float = 10.0
@export var input_enabled: bool = true

## Jump height in metres. Stair risers in the hub are 0.42 m, so this only has
## to clear obstacles the step logic cannot.
@export var jump_height: float = 1.4

## The camera the player moves relative to. When unset, the player falls back to
## the viewport's active camera, so the gallery, the hub and any other scene all
## work without needing this wired up by hand.
@export var camera_path: NodePath

# --- Visual & Animation Setup ---
@onready var animation_player = $FoxVisuals/Fox/AnimationPlayer
@onready var fox_visuals = $FoxVisuals # Reference to the container to handle rotation

const RUNNING_SPEED_THRESHOLD = 0.1 # Minimum speed to trigger the running animation
const ROTATION_SPEED = 10.0 # Speed at which the fox model rotates (adjust as needed)

var _camera: Camera3D


func _ready() -> void:
	# Stairs are built as a stack of boxes (see hub_castle_stairs.gd), so the
	# capsule catches on every riser edge unless the body is allowed to step up
	# over them. 0.6 m clears the 0.42 m risers with margin to spare.
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.6
	floor_stop_on_slope = true
	# Keeps the body glued to the treads on the way down instead of launching off
	# each step and re-entering the air state.
	floor_block_on_wall = false

	if camera_path:
		_camera = get_node_or_null(camera_path) as Camera3D


func set_input_enabled(v: bool) -> void:
	input_enabled = v


# The active camera can be swapped at runtime (the gallery tweens between a
# follow camera and an inspect camera), so this is resolved per frame rather
# than cached once.
func _active_camera() -> Camera3D:
	if _camera and _camera.is_inside_tree():
		return _camera
	return get_viewport().get_camera_3d()


func _physics_process(delta: float) -> void:
	# Gravity always runs. Without it move_and_slide() has no downward force to
	# resolve steps against, which is why the stair could not be climbed.
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	# Disable movement if input is locked (e.g. inspecting a painting). Gravity
	# still applies so a locked player cannot hang in mid-air.
	if not input_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()

		# Ensure the fox is in the Idle animation when locked
		if animation_player.current_animation != "Idle":
			animation_player.play("Idle")
		return

	# Handle movement input
	var input_dir := Vector2.ZERO

	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	input_dir = input_dir.normalized()

	# Convert 2D input to a 3D direction in the camera's frame, so "forward" is
	# wherever the player is looking. Previously this used the raw input axes,
	# which meant W always pushed toward world -Z no matter where the view was
	# pointing.
	var move_dir := Vector3.ZERO
	var camera := _active_camera()
	if camera:
		var basis := camera.global_transform.basis
		# Flatten to the ground plane — the camera looks down at the player, and
		# its unflattened forward vector would drive the player into the floor.
		var forward := Vector3(basis.z.x, 0.0, basis.z.z).normalized()
		var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
		move_dir = (right * input_dir.x + forward * input_dir.y).normalized()
	else:
		move_dir = Vector3(input_dir.x, 0.0, input_dir.y)

	# Apply velocity based on input and speed
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = sqrt(2.0 * jump_height * absf(get_gravity().y))

	# --- ANIMATION AND ROTATION LOGIC ---
	var current_movement_length = Vector2(velocity.x, velocity.z).length()

	if current_movement_length > RUNNING_SPEED_THRESHOLD:
		# 1. Animation: Play Run
		if animation_player.current_animation != "Run":
			animation_player.play("Run")

		# 2. Rotation: Calculate target angle and smoothly rotate the visual model
		var target_angle = atan2(velocity.x, velocity.z) # Angle based on movement vector
		fox_visuals.rotation.y = rotate_toward(fox_visuals.rotation.y, target_angle, ROTATION_SPEED * delta)

	else:
		# 1. Animation: Play Idle
		if animation_player.current_animation != "Idle":
			animation_player.play("Idle")

	move_and_slide()
