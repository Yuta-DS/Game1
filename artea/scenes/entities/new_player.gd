extends CharacterBody3D

#This is the jump function
@export var jump_height : float = 2.25
@export var jump_time_to_peak : float = 0.4
@export var jump_time_to_descent : float = 0.25
@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

@export var baseSpeed := 4.0
@export var runSpeed := 6.0

# Inventory system
@export var inventory_data: inventoryData
@onready var inventory_gui: Control = $InventoryGUI

@onready var camera = $CameraController/Camera3D

var movementInput := Vector2.ZERO
var interacting: bool = false

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
			_on_inventory_pressed()
				
# Inventory button handling during chat
func _on_inventory_pressed() -> void:
	if interacting:
		return
	if inventory_gui:
		inventory_gui.toggle_visibility()
		print("Toggled inventory visibility")
		
	else:
		print("ERROR: inventory_gui is null!")
	

func _physics_process(delta: float) -> void:
	
	#velocity = Vector3(movementInput.x, 0, movementInput.y) * baseSpeed
	moveLogic(delta)
	jumpLogic(delta)
	
	move_and_slide()

func jumpLogic(delta) -> void:
	if is_on_floor():
		#if Input.is_action_just_pressed("jump"):
		if not interacting and Input.is_action_just_pressed("jump"):
			velocity.y = -jump_velocity
	else:
		$RogueSkin/AnimationPlayer.current_animation = 'Jump'
		$RogueSkin/AnimationPlayer.current_animation = 'ToucheGround'
		
	var gravity = jump_gravity if velocity.y > 0.0 else fall_gravity


	velocity.y -= gravity * delta

	
func moveLogic(delta) -> void:
	
		if interacting:
			velocity.x = 0
			velocity.z = 0
			$RogueSkin/AnimationPlayer.current_animation = 'Idle'
			return
	
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
			var targetAngle = -movementInput.angle() + PI/2
			$RogueSkin.rotation.y = rotate_toward($RogueSkin.rotation.y, targetAngle, 6.0 * delta)
		else:
			velocity2D = velocity2D.move_toward(Vector2.ZERO, baseSpeed * 10.0 * delta)
			velocity.x = velocity2D.x
			velocity.z = velocity2D.y
			$RogueSkin/AnimationPlayer.current_animation = 'Idle'

func collect_item(item: itemData) -> bool:
	if inventory_data == null:
		print("ERROR: inventory_data is null!")
		return false
	
	print("Collecting item: ", item.name)
	print("Item texture: ", item.texture)
	print("Item stackable: ", item.stackable)
	
	# Try to add to existing stack if stackable
	if item.stackable:
		for slot in inventory_data.slot_Data:
			if slot != null and slot.item_Data != null:
				print("Comparing with slot item: ", slot.item_Data.name)
				# Compare by item name instead of object reference
				if slot.item_Data.name == item.name:
					slot.quantity += 1
					print("Stacked! New quantity: ", slot.quantity)
					if inventory_gui:
						print("Refreshing inventory GUI slots")
						inventory_gui.refresh_slots()
					else:
						print("WARNING: inventory_gui is null when trying to refresh!")
					return true
	
	# Find empty slot
	for i in range(inventory_data.slot_Data.size()):
		if inventory_data.slot_Data[i] == null:
			var new_slot = slotData.new()
			new_slot.item_Data = item
			new_slot.quantity = 1
			inventory_data.slot_Data[i] = new_slot
			print("Added to new slot ", i)
			print("Slot data - item: ", new_slot.item_Data.name, " qty: ", new_slot.quantity)
			if inventory_gui:
				print("Refreshing inventory GUI slots")
				inventory_gui.refresh_slots()
			else:
				print("WARNING: inventory_gui is null when trying to refresh!")
			return true
	
	# Inventory full
	print("Inventory is full!")
	return false
	
func NewPlayer():
	pass
