extends CharacterBody3D

# --- AUDIO NODES & RESOURCES ---
@onready var footstep_player = $FootstepPlayer
@onready var floor_detector = $FloorDetector 

@onready var sfx_grass = preload("res://assets/SFX/grasswalk.mp3") 

# --- UI / DEBUG NODES ---
@onready var debug_coords = $CanvasLayer/DebugCoords 

# --- JUMP VARIABLES ---
@export var jump_height : float = 2.25
@export var jump_time_to_peak : float = 0.4
@export var jump_time_to_descent : float = 0.25
@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

# --- SPEED BOOSTED ---
@export var baseSpeed := 12.0
@export var runSpeed := 22.0

# --- INTERACTION & GRASS FIX ---
var interacting := false  # Critical fix for team's grass shader

# --- INVENTORY SYSTEM ---
@export var inventory_data: inventoryData
@onready var inventory_gui: Control = $InventoryGUI
@onready var camera = $CameraController/Camera3D

var movementInput := Vector2.ZERO
#var interacting := false  # <--- CRITICAL FIX: This stops the Camera Controller error

func _ready() -> void:
	await get_tree().process_frame
	if inventory_data and inventory_gui:
		inventory_gui.set_inventory_data(inventory_data)
	
	floor_detector.add_exception(self)
	
	if footstep_player is AudioStreamPlayer3D:
		footstep_player.volume_db = 10.0
		footstep_player.max_distance = 200.0
		footstep_player.unit_size = 20.0
		
func _input(event: InputEvent) -> void:
		# Toggle inventory with I key
		if event.is_action_pressed("toggle_Inventory"):
			print("I key pressed! inventory_gui exists: ", inventory_gui != null)
			_on_inventory_pressed()
			
func _on_inventory_pressed() -> void:
	if interacting:
		return
	if inventory_gui:
		inventory_gui.toggle_visibility()

func _physics_process(delta: float) -> void:
	moveLogic(delta)
	jumpLogic(delta)
	
	if debug_coords:
		var pos = global_position
		debug_coords.text = "X: %.1f | Y: %.1f | Z: %.1f" % [pos.x, pos.y, pos.z]
	
	move_and_slide()

func jumpLogic(delta) -> void:
	if is_on_floor():
		if not interacting and Input.is_action_just_pressed("jump"):
			velocity.y = -jump_velocity
	else:
		if has_node("RogueSkin/AnimationPlayer"):
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
		velocity2D += movementInput * speed * delta * 8
		velocity2D = velocity2D.limit_length(speed)
		velocity.x = velocity2D.x
		velocity.z = velocity2D.y
		
		if has_node("RogueSkin/AnimationPlayer"):
			$RogueSkin/AnimationPlayer.current_animation = 'Run'
		
		if is_on_floor():
			if floor_detector.is_colliding():
				var ground = floor_detector.get_collider()
				if ground.is_in_group("grass_surface") or (ground.get_parent() and ground.get_parent().is_in_group("grass_surface")):
				
				# Check the collider or its parent for the grass group
					var is_grass = ground.is_in_group("grass_surface") or (ground.get_parent() and ground.get_parent().is_in_group("grass_surface"))
					
					if is_grass:
						if footstep_player.stream != sfx_grass:
							footstep_player.stream = sfx_grass
						if not footstep_player.playing:
							footstep_player.play()
					else:
						if footstep_player.playing:
							footstep_player.stop()
		else:
			if footstep_player.playing:
				footstep_player.stop()

		var targetAngle = -movementInput.angle() + PI/2
		$RogueSkin.rotation.y = rotate_toward($RogueSkin.rotation.y, targetAngle, 6.0 * delta)
	else:
		velocity2D = velocity2D.move_toward(Vector2.ZERO, baseSpeed * 10.0 * delta)
		velocity.x = velocity2D.x
		velocity.z = velocity2D.y
		if has_node("RogueSkin/AnimationPlayer"):
			$RogueSkin/AnimationPlayer.current_animation = 'Idle'
		if footstep_player.playing:
			footstep_player.stop()

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
