extends CharacterBody3D

# --- AUDIO NODES ---
@onready var footstep_player = $FootstepPlayer

# --- UI / DEBUG NODES ---
@onready var debug_coords = $CanvasLayer/DebugCoords 

# --- JUMP VARIABLES ---
@export var jump_height : float = 2.25
@export var jump_time_to_peak : float = 0.4
@export var jump_time_to_descent : float = 0.25
@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

@export var baseSpeed := 4.0
@export var runSpeed := 6.0

# --- INVENTORY SYSTEM ---
@export var inventory_data: inventoryData
@onready var inventory_gui: Control = $InventoryGUI
@onready var camera = $CameraController/Camera3D

var movementInput := Vector2.ZERO

func _ready() -> void:
	# Initialize inventory
	print("Player ready - inventory_data: ", inventory_data)
	print("Player ready - inventory_gui: ", inventory_gui)
	
	# Wait one frame for inventory_gui to be ready
	await get_tree().process_frame
	
	if inventory_data and inventory_gui:
		inventory_gui.set_inventory_data(inventory_data)
		print("Inventory initialized successfully")
	else:
		print("WARNING: Inventory not initialized!")

func _input(event: InputEvent) -> void:
	# Toggle inventory with I key
	if event.is_action_pressed("toggle_Inventory"):
		if inventory_gui:
			inventory_gui.toggle_visibility()

func _physics_process(delta: float) -> void:
	moveLogic(delta)
	jumpLogic(delta)
	
	# --- DEBUG COORDINATE UPDATE ---
	# We snap the numbers to 1 decimal place so they are easy to read
	if debug_coords:
		var pos = global_position
		debug_coords.text = "X: %.1f | Y: %.1f | Z: %.1f" % [pos.x, pos.y, pos.z]
	
	move_and_slide()

func jumpLogic(delta) -> void:
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = -jump_velocity
	else:
		$RogueSkin/AnimationPlayer.current_animation = 'Jump'
		$RogueSkin/AnimationPlayer.current_animation = 'ToucheGround'
		
	var gravity = jump_gravity if velocity.y > 0.0 else fall_gravity
	velocity.y -= gravity * delta
	
func moveLogic(delta) -> void:
	movementInput = Input.get_vector("move_left", "move_right", "move_forward", "move_backward").rotated(-camera.global_rotation.y)
	var velocity2D = Vector2(velocity.x, velocity.z)
	var isRunning: bool = Input.is_action_pressed("run")
	
	if movementInput != Vector2.ZERO:
		var speed = runSpeed if isRunning else baseSpeed
		velocity2D += movementInput * speed * delta * 3
		velocity2D = velocity2D.limit_length(speed)
		velocity.x = velocity2D.x
		velocity.z = velocity2D.y
		
		$RogueSkin/AnimationPlayer.current_animation = 'Run'
		
		# --- FOOTSTEP AUDIO ---
		if is_on_floor():
			if not footstep_player.playing:
				footstep_player.play()
		else:
			footstep_player.stop()

		var targetAngle = -movementInput.angle() + PI/2
		$RogueSkin.rotation.y = rotate_toward($RogueSkin.rotation.y, targetAngle, 6.0 * delta)
	else:
		velocity2D = velocity2D.move_toward(Vector2.ZERO, baseSpeed * 10.0 * delta)
		velocity.x = velocity2D.x
		velocity.z = velocity2D.y
		$RogueSkin/AnimationPlayer.current_animation = 'Idle'
		footstep_player.stop()

func collect_item(item: itemData) -> bool:
	return false
	
func NewPlayer():
	pass
