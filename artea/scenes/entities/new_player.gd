extends CharacterBody3D

# --- AUDIO NODES ---
@onready var footstep_player = $FootstepPlayer

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
		print("Inventory has ", inventory_data.slot_Data.size(), " slots")
	else:
		print("WARNING: Inventory not initialized!")

func _input(event: InputEvent) -> void:
	# Toggle inventory with I key
	if event.is_action_pressed("toggle_Inventory"):
		print("I key pressed! inventory_gui exists: ", inventory_gui != null)
		if inventory_gui:
			print("Toggling inventory visibility")
			inventory_gui.toggle_visibility()
		else:
			print("ERROR: inventory_gui is null!")

func _physics_process(delta: float) -> void:
	moveLogic(delta)
	jumpLogic(delta)
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
		
		# SET ANIMATION
		$RogueSkin/AnimationPlayer.current_animation = 'Run'
		
		# --- FOOTSTEP AUDIO START ---
		# Only play if the player is actually touching the ground
		if is_on_floor():
			if not footstep_player.playing:
				footstep_player.play()
		else:
			# Stop footsteps if we jump or fall
			footstep_player.stop()
		# --- FOOTSTEP AUDIO END ---

		var targetAngle = -movementInput.angle() + PI/2
		$RogueSkin.rotation.y = rotate_toward($RogueSkin.rotation.y, targetAngle, 6.0 * delta)
	else:
		velocity2D = velocity2D.move_toward(Vector2.ZERO, baseSpeed * 10.0 * delta)
		velocity.x = velocity2D.x
		velocity.z = velocity2D.y
		
		# SET ANIMATION
		$RogueSkin/AnimationPlayer.current_animation = 'Idle'
		
		# --- STOP FOOTSTEPS ---
		# Stop sound when we are standing still
		footstep_player.stop()

func collect_item(item: itemData) -> bool:
	if inventory_data == null:
		print("ERROR: inventory_data is null!")
		return false
	
	if item.stackable:
		for slot in inventory_data.slot_Data:
			if slot != null and slot.item_Data != null:
				if slot.item_Data.name == item.name:
					slot.quantity += 1
					if inventory_gui:
						inventory_gui.refresh_slots()
					return true
	
	for i in range(inventory_data.slot_Data.size()):
		if inventory_data.slot_Data[i] == null:
			var new_slot = slotData.new()
			new_slot.item_Data = item
			new_slot.quantity = 1
			inventory_data.slot_Data[i] = new_slot
			if inventory_gui:
				inventory_gui.refresh_slots()
			return true
	
	return false
	
func NewPlayer():
	pass
