extends CharacterBody3D

@onready var floor_detector = $FloorDetector 

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

# Per-spawn idle facing override, in radians. Only affects the visual model's
# rotation before the player first moves -- moveLogic() below recomputes
# RogueSkin's rotation from movement input every frame once input arrives, so
# this must stay a LOCAL rotation on RogueSkin rather than a rotation on this
# root node. Rotating the root instead would silently break moveLogic()'s
# movement-relative facing everywhere (not just at spawn), since that code
# derives RogueSkin's target rotation from camera-relative input assuming the
# root itself never rotates.
@export var override_initial_facing: bool = false
@export_range(-360.0, 360.0, 0.1, "radians_as_degrees") var initial_facing_radians: float = 0.0
# Per-spawn initial camera yaw override, in radians, applied to CameraController
# (a SpringArm3D) after its own _ready() runs (children ready before parents,
# so this always wins over its startYawY default). Independent of
# initial_facing_radians above -- set both explicitly to keep the camera and
# the visual model's spawn facing in agreement. Both overrides are gated by
# their own bool rather than "value != 0.0", since 0 radians (due +Z) is a
# perfectly valid angle a scene may legitimately want.
@export var override_initial_camera_yaw: bool = false
@export_range(-360.0, 360.0, 0.1, "radians_as_degrees") var initial_camera_yaw_radians: float = 0.0
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

# The imported fox mesh extends roughly 0.05 m below its root pivot. Nested
# PackedScene transform overrides have also proved unreliable after reimport,
# so establish both the authored scale and a small visual-only foot lift here.
# The CharacterBody and capsule are unchanged: physics stays on the floor while
# the rendered feet sit on top of it instead of being depth-clipped by paving.
const VISUAL_MODEL_SCALE := 1.5
# Keep enough render clearance for the skinned boot animation. The former
# 0.055 m correction left the mesh bounds just 5 mm above the plane, which can
# still depth-clip at normal camera distance even though physics is grounded.
const VISUAL_FOOT_LIFT := 0.105


func _ready() -> void:
	var visual := get_node_or_null("RogueSkin") as Node3D
	if visual != null:
		visual.scale = Vector3.ONE * VISUAL_MODEL_SCALE
		visual.position.y = VISUAL_FOOT_LIFT
		visual.set_meta("ground_alignment", "feet_on_rendered_surface")
		if override_initial_facing:
			visual.rotation.y = initial_facing_radians
	if override_initial_camera_yaw:
		var cam_rig := get_node_or_null("CameraController")
		if cam_rig:
			cam_rig.rotation.y = initial_camera_yaw_radians
	# The stair treads are separate boxes, so the body needs to stay attached to
	# them on the way down instead of launching off each edge.
	floor_snap_length = 0.7
	# Slightly above the default 45 so the spiral's tilted treads still register
	# as floor rather than wall.
	floor_max_angle = deg_to_rad(50.0)
	floor_block_on_wall = false

	# Child controls are already ready here; bind before physics can collect.
	if inventory_data and inventory_gui:
		inventory_gui.set_inventory_data(inventory_data)
	
	floor_detector.add_exception(self)
	
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
		
		var targetAngle = -movementInput.angle() + PI/2
		$RogueSkin.rotation.y = rotate_toward($RogueSkin.rotation.y, targetAngle, 6.0 * delta)
	else:
		velocity2D = velocity2D.move_toward(Vector2.ZERO, baseSpeed * 10.0 * delta)
		velocity.x = velocity2D.x
		velocity.z = velocity2D.y
		_play_locomotion_animation("Idle", 1.0)


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
		for i in range(inventory_data.slot_Data.size()):
			var slot = inventory_data.slot_Data[i]
			if slot != null and slot.item_Data != null:
				if slot.item_Data.name == item.name:
					slot.quantity += 1
					if inventory_gui:
						inventory_gui.refresh_slots(i)
					return true

	for i in range(inventory_data.slot_Data.size()):
		if inventory_data.slot_Data[i] == null:
			var new_slot = slotData.new()
			new_slot.item_Data = item
			new_slot.quantity = 1
			inventory_data.slot_Data[i] = new_slot
			if inventory_gui:
				inventory_gui.refresh_slots(i)
			return true
	
	return false
