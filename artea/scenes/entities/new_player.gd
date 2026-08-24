extends CharacterBody3D

# --- AUDIO NODES & RESOURCES ---
@onready var footstep_player = $FootstepPlayer
@onready var floor_detector = $FloorDetector 

@onready var sfx_grass = preload("res://assets/SFX/grasswalk.ogg") 

# --- JUMP VARIABLES ---
@export var jump_height : float = 2.25
@export var jump_time_to_peak : float = 0.4
@export var jump_time_to_descent : float = 0.25
@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

# Player-scale speeds. The previous 12/22 m/s values crossed a full courtyard
# in under a second, skipped narrow collisions and made the follow camera feel
# unstable. These retain a responsive sprint without turning traversal into a
# debug fly-through.
@export var baseSpeed := 6.0
@export var runSpeed := 10.0

# --- INTERACTION & GRASS FIX ---
var interacting := false  # Critical fix for team's grass shader

# --- INVENTORY SYSTEM ---
@export var inventory_data: inventoryData
@onready var inventory_gui: Control = $InventoryGUI
@onready var camera = $CameraController/Camera3D

var movementInput := Vector2.ZERO

# --- STAIR STEPPING ---
# The castle stair (hub_castle_stairs.gd) rises 0.284 m per tread. The ceiling
# is set well above that so uneven terrain and the bridge planks also step
# cleanly, but stays under the 1.0 m mark so the player cannot walk up walls.
const MAX_STEP_HEIGHT := 0.65
# Ignore hops smaller than this — they are surface noise, and stepping every
# one of them makes flat ground feel jittery.
const MIN_STEP_HEIGHT := 0.02
# How far ahead to look for standable ground once raised.
const STEP_FORWARD_PROBE := 0.45
# The least forward progress that still counts as clearing the step rather than
# hitting a wall. Below this the capsule has not advanced past its own skin, so
# there is no new ground to stand on.
const MIN_STEP_FORWARD := 0.08
# Extra downward reach so the far side of a tread is found even when it sits a
# little lower than the near side.
const STEP_DOWN_PROBE := 0.1


func _ready() -> void:
	# The stair treads are separate boxes, so the body needs to stay attached to
	# them on the way down instead of launching off each edge.
	floor_snap_length = 0.7
	# Slightly above the default 45 so the spiral's tilted treads still register
	# as floor rather than wall.
	floor_max_angle = deg_to_rad(50.0)
	floor_block_on_wall = false

	await get_tree().process_frame
	if inventory_data and inventory_gui:
		inventory_gui.set_inventory_data(inventory_data)
	
	floor_detector.add_exception(self)
	
	# --- OPTIMIZED AUDIO SETTINGS ---
	if footstep_player is AudioStreamPlayer3D:
		footstep_player.volume_db = -4.0
		footstep_player.max_distance = 24.0
		footstep_player.unit_size = 6.0
		footstep_player.panning_strength = 0.5
		
func _input(event: InputEvent) -> void:
	# Toggle inventory with I key
	if event.is_action_pressed("toggle_Inventory"):
		_on_inventory_pressed()
			
func _on_inventory_pressed() -> void:
	if interacting:
		return
	if inventory_gui:
		inventory_gui.toggle_visibility()

func _physics_process(delta: float) -> void:
	_recover_orphaned_interaction_lock()
	moveLogic(delta)
	jumpLogic(delta)

	var was_on_floor := is_on_floor()
	var pre_step_position := global_position
	# Captured before the slide: move_and_slide() zeroes the component that ran
	# into geometry, so reading velocity afterwards reports the body as standing
	# still and the step probe never fires.
	var intended_velocity := velocity

	move_and_slide()

	# move_and_slide() alone will not climb the castle stair: each tread is a
	# separate box with a vertical riser face, and a capsule pushed horizontally
	# into a vertical face just stops. Snapping cannot help either, because snap
	# only pulls the body *down* onto a floor it has already cleared.
	_try_step_up(was_on_floor, pre_step_position, intended_velocity, delta)


# `interacting` is intentionally a hard movement lock while dialogue or Milo's
# reflection panel is open. Several older callers write the boolean directly,
# though, so an interrupted/invalid interaction could strand the player with no
# UI and no way to move. Boat travel is unaffected because it suspends this
# physics process while boarded.
func _recover_orphaned_interaction_lock() -> void:
	if not interacting or _has_live_interaction_owner():
		return

	interacting = false
	velocity.x = 0.0
	velocity.z = 0.0
	print("Player control restored after orphaned interaction lock")


func _has_live_interaction_owner() -> bool:
	if not is_inside_tree():
		return false

	var manager := get_node_or_null("/root/GameManager")
	if manager != null:
		var dialogue_ui: Variant = manager.get("dialogue_ui")
		if dialogue_ui is Node and is_instance_valid(dialogue_ui) \
				and not dialogue_ui.is_queued_for_deletion():
			return true

	# Milo's curated reflection is the only non-dialogue UI that owns the same
	# lock. Locate it by its stable scene-root name rather than an NPC path so a
	# moved Milo cannot break recovery.
	var scene := get_tree().current_scene
	if scene != null:
		var chatbot := scene.find_child("chatbot", true, false)
		# A hidden chatbot is not an active modal owner. The old check treated
		# the mere presence of this node as a live conversation, so a chatbot
		# hidden by closing/scene UI could keep `interacting` true forever and
		# make the player look physically wedged on otherwise clear architecture.
		if chatbot is Control and is_instance_valid(chatbot) \
				and not chatbot.is_queued_for_deletion() \
				and (chatbot as Control).is_visible_in_tree():
			return true

	return false


# Lifts the body over a low obstruction it just bumped into, so a stack of boxes
# walks like a staircase. Runs only when grounded and actually blocked, so it
# never gives free height in mid-air or against a real wall.
func _try_step_up(was_on_floor: bool, pre_step_position: Vector3, intended_velocity: Vector3, delta: float) -> void:
	if not was_on_floor or not is_on_wall():
		return

	var horizontal_velocity := Vector3(intended_velocity.x, 0.0, intended_velocity.z)
	if horizontal_velocity.length() < 0.1:
		return

	# Anything the body reported as "wall" (i.e. steeper than floor_max_angle) is
	# a step candidate. An earlier version demanded a near-vertical face, but the
	# spiral's treads are rotated boxes whose blocking edge reads about 23 deg
	# off vertical, so that test rejected the entire staircase. The real safety
	# check is the landing test further down, which refuses anything too steep to
	# stand on.
	if intended_velocity.y > 0.0:
		# Rising already (jump): let the jump play out rather than stacking a
		# step on top of it.
		return

	# How far the body actually got this frame. If it moved freely there is
	# nothing to climb.
	var travelled := Vector3(
		global_position.x - pre_step_position.x,
		0.0,
		global_position.z - pre_step_position.z)
	var wanted := horizontal_velocity * delta
	if travelled.length() >= wanted.length() * 0.75:
		return

	var motion: Vector3 = horizontal_velocity.normalized() * (STEP_FORWARD_PROBE + safe_margin)

	# Cast the capsule up, forward, then back down — the standard three-phase
	# step probe. Doing it with test_move means the step is only taken when the
	# body genuinely fits there, so it cannot tunnel into geometry.
	var params := PhysicsTestMotionParameters3D.new()
	var result := PhysicsTestMotionResult3D.new()

	params.from = global_transform
	params.motion = Vector3.UP * MAX_STEP_HEIGHT
	var up_blocked := PhysicsServer3D.body_test_motion(get_rid(), params, result)
	var up_distance: float = result.get_travel().y if up_blocked else MAX_STEP_HEIGHT
	if up_distance < MIN_STEP_HEIGHT:
		return

	var raised := global_transform
	raised.origin += Vector3.UP * up_distance

	params.from = raised
	params.motion = motion
	# Use how far the body actually got, not whether it touched anything at all.
	# A boolean test rejects the entire spiral stair: consecutive treads overlap,
	# so the next plateau starts ~0.19 m ahead while this probe reaches ~0.45 m.
	# The raised capsule therefore always grazes the following riser, and treating
	# that contact as "wall" bailed out on every step of the climb.
	var forward_travel := motion
	if PhysicsServer3D.body_test_motion(get_rid(), params, result):
		forward_travel = result.get_travel()
		# Only a genuine wall stops the capsule before it clears its own radius;
		# anything further is a step whose far edge we can still land on.
		if forward_travel.length() < MIN_STEP_FORWARD:
			return
	var forward := raised
	forward.origin += forward_travel

	params.from = forward
	params.motion = Vector3.DOWN * (up_distance + STEP_DOWN_PROBE)
	if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
		# Nothing underneath — this is a ledge, not a step. Don't float.
		return

	# Use the signed vertical travel. get_travel().length() is unsigned, so a
	# sideways component in the resolved motion inflated the drop and pushed the
	# landing below the tread — which then failed the climbed <= 0.0 test and
	# rejected steps the body could actually stand on.
	var landing := forward.origin
	landing.y += result.get_travel().y
	var climbed := landing.y - global_position.y
	# A step down is legitimate too (the spiral is walked in both directions);
	# only refuse a rise taller than the body can lift itself over.
	if climbed > MAX_STEP_HEIGHT:
		return

	# Reject anything we would land on that is too steep to stand on.
	var landing_normal := result.get_collision_normal()
	if landing_normal.angle_to(Vector3.UP) > floor_max_angle:
		return

	global_position = landing
	# Keep the body glued down for the next frame so the climb reads as walking
	# rather than a series of little hops.
	apply_floor_snap()

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
		_play_locomotion_animation("Idle", 1.0)
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
		
		var animation_player := get_node_or_null("RogueSkin/AnimationPlayer") as AnimationPlayer
		if animation_player != null:
			var locomotion := "Run"
			if not isRunning and animation_player.has_animation("Walk"):
				locomotion = "Walk"
			_play_locomotion_animation(locomotion, 1.05 if isRunning else 0.72)
		
		# --- FOOTSTEP LOGIC FIX ---
		if is_on_floor():
			if floor_detector.is_colliding():
				var ground = floor_detector.get_collider()
				# Check the collider or its parent for the grass group
				var is_grass = ground.is_in_group("grass_surface") or (ground.get_parent() and ground.get_parent().is_in_group("grass_surface"))
				
				
				if is_grass:
					if footstep_player.stream != sfx_grass:
						footstep_player.stream = sfx_grass
					
					if not footstep_player.playing:
						# Random pitch makes steps stand out against wind
						footstep_player.pitch_scale = randf_range(0.9, 1.1)
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
		_play_locomotion_animation("Idle", 1.0)
		if footstep_player.playing:
			footstep_player.stop()


func _play_locomotion_animation(animation_name: String, speed_scale: float) -> void:
	var animation_player := get_node_or_null("RogueSkin/AnimationPlayer") as AnimationPlayer
	if animation_player == null or not animation_player.has_animation(animation_name):
		return
	animation_player.speed_scale = speed_scale
	if animation_player.current_animation != animation_name \
			or not animation_player.is_playing():
		animation_player.play(animation_name, 0.14)

func collect_item(item: itemData) -> bool:
	if inventory_data == null:
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
