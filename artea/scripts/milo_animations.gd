extends CharacterBody3D

@onready var player = get_node("../NewPlayer")

@export var walk_speed := 1.10
@export var wander_radius := 7.0
@export var minimum_pause := 1.6
@export var maximum_pause := 4.5
@export var initial_greeting_pause := 10.0

const STAGE_GLOW := [
	Color("7896c8"),
	Color("86b7ff"),
	Color("f5a95e"),
	Color("d98cff"),
	Color("ffd66e"),
]
const STAGE_ENERGY := [0.18, 0.55, 0.85, 1.2, 1.65]
const COUNSELLOR_ANIMATIONS := {
	"welcome": "Counsellor_Welcome",
	"guide": "Counsellor_Guide",
	"map": "Counsellor_Map",
	"tablet": "Counsellor_Tablet",
	"encourage": "Counsellor_Encourage",
	"heart": "Counsellor_Heart",
}

var player_in_range := false
var chatbot_ui = null

var wave_timer := 0.0
var first_wave := false
var journey_stage := -1
var aura: Node3D
var aura_light: OmniLight3D
var aura_material: StandardMaterial3D
var anim_player: AnimationPlayer
var counsellor_props: Node3D
var map_prop: Node3D
var tablet_prop: Node3D
var counsellor_sparkles: Node3D
var _home: Vector3
var _walk_target: Vector3
var _pause_timer := 0.0
var _is_walking := false
var _cane_cycle_time := 0.0
var _cane_gait_state := "plant"

const CANE_GAIT_CYCLE_SECONDS := 1.15
const CANE_PLANT_END := 0.18
const CANE_SUPPORT_END := 0.70
const COUNSELLOR_POSE_SECONDS := 0.36
const HAND_CLEARANCE_ARC := 0.16
const ARM_BONES := [
	"upperarm.l", "lowerarm.l", "wrist.l", "hand.l",
	"upperarm.r", "lowerarm.r", "wrist.r", "hand.r",
]

var counsellor_pose_tween: Tween


func _ready():
	# This nested inherited scene loses its instance origin when the Web hub is
	# assembled. The Artéa sign keeps its authored landmark transform, so use it
	# as Milo's stable anchor. He now works beside the sign instead of waiting at
	# the player's spawn point.
	if player != null:
		var artea_sign := get_node_or_null("../Artéa_Signpost_1027230400_texture") as Node3D
		if artea_sign != null:
			global_position = artea_sign.global_position + Vector3(-7.5, -8.5, -1.5)
		else:
			global_position = Vector3(104.8, 21.0, -7.25)
	anim_player = _find_animation_player(self)
	_home = global_position
	_begin_pause(initial_greeting_pause)
	_play_animation("Idle_3")
	_build_counsellor_props()
	_build_journey_aura()
	_apply_journey_stage()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _play_animation(animation_name: String) -> void:
	if anim_player != null and anim_player.has_animation(animation_name) \
			and anim_player.current_animation != animation_name:
		var playback_speed := 0.62 if animation_name in ["Walk", "Walking", "Cane_Walk"] else 1.0
		if animation_name == "Wave_One_Hand":
			playback_speed = 0.76
		anim_player.play(animation_name, 0.22, playback_speed)


func _on_companion_pose_requested(pose_name: String) -> void:
	var animation_name := str(COUNSELLOR_ANIMATIONS.get(pose_name, "Counsellor_Welcome"))
	_play_animation(animation_name)
	_start_counsellor_arm_transition(pose_name)


func _start_counsellor_arm_transition(pose_name: String) -> void:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	_cancel_counsellor_pose_transition()
	var start_pose := _capture_arm_pose(skeleton)
	_apply_counsellor_arm_pose(pose_name)
	var target_pose := _capture_arm_pose(skeleton)
	_restore_arm_pose(skeleton, start_pose)

	# Props and the cane appear only after the paws reach their collision-safe
	# endpoints. This prevents a moving hand from sweeping through solid meshes.
	_set_cane_visible(false)
	_set_counsellor_prop("")
	counsellor_pose_tween = create_tween()
	counsellor_pose_tween.set_trans(Tween.TRANS_CUBIC)
	counsellor_pose_tween.set_ease(Tween.EASE_IN_OUT)
	counsellor_pose_tween.tween_method(
		_blend_counsellor_arm_pose.bind(skeleton, start_pose, target_pose),
		0.0, 1.0, COUNSELLOR_POSE_SECONDS)
	counsellor_pose_tween.tween_callback(
		_finish_counsellor_arm_transition.bind(pose_name))


func _capture_arm_pose(skeleton: Skeleton3D) -> Dictionary:
	var pose := {}
	for bone_name in ARM_BONES:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index >= 0:
			pose[bone_name] = {
				"position": skeleton.get_bone_pose_position(bone_index),
				"rotation": skeleton.get_bone_pose_rotation(bone_index),
				"scale": skeleton.get_bone_pose_scale(bone_index),
			}
	return pose


func _restore_arm_pose(skeleton: Skeleton3D, pose: Dictionary) -> void:
	for bone_name in pose:
		var bone_index := skeleton.find_bone(str(bone_name))
		var bone_pose: Dictionary = pose[bone_name]
		skeleton.set_bone_pose_position(bone_index, bone_pose.position)
		skeleton.set_bone_pose_rotation(bone_index, bone_pose.rotation)
		skeleton.set_bone_pose_scale(bone_index, bone_pose.scale)


func _blend_counsellor_arm_pose(weight: float, skeleton: Skeleton3D,
		start_pose: Dictionary, target_pose: Dictionary) -> void:
	for bone_name in start_pose:
		var bone_index := skeleton.find_bone(str(bone_name))
		var from_pose: Dictionary = start_pose[bone_name]
		var to_pose: Dictionary = target_pose[bone_name]
		skeleton.set_bone_pose_position(bone_index,
			(from_pose.position as Vector3).lerp(to_pose.position, weight))
		skeleton.set_bone_pose_rotation(bone_index,
			(from_pose.rotation as Quaternion).slerp(to_pose.rotation, weight))
		skeleton.set_bone_pose_scale(bone_index,
			(from_pose.scale as Vector3).lerp(to_pose.scale, weight))

	# Route each paw in front of Milo's coat instead of through his torso.
	var clearance := sin(weight * PI) * HAND_CLEARANCE_ARC
	if clearance > 0.0:
		for hand_name in ["hand.l", "hand.r"]:
			var hand_index := skeleton.find_bone(hand_name)
			var hand_pose := skeleton.get_bone_global_pose(hand_index)
			hand_pose.origin.z += clearance
			skeleton.set_bone_global_pose(hand_index, hand_pose)


func _finish_counsellor_arm_transition(pose_name: String) -> void:
	counsellor_pose_tween = null
	_set_cane_visible(pose_name in ["welcome", "guide", "neutral"])
	_set_counsellor_prop(pose_name)


func _cancel_counsellor_pose_transition() -> void:
	if counsellor_pose_tween != null and counsellor_pose_tween.is_valid():
		counsellor_pose_tween.kill()
	counsellor_pose_tween = null


func _apply_counsellor_arm_pose(pose_name: String) -> void:
	# The donor rig's animation library uses Blender IK controls which are not
	# evaluated by Godot. These compact FK poses operate on Milo's deform bones,
	# producing the six readable silhouettes from the approved reference sheet.
	_reset_mayor_arm_pose()
	match pose_name:
		"welcome":
			_pose_arm("r", Vector3(0.0, 0.0, 100.0),
				Vector3(0.0, 0.0, 80.0), Vector3(0.0, 0.0, -12.0))
		"guide":
			_pose_arm("r", Vector3(0.0, 0.0, 92.0),
				Vector3(0.0, 0.0, -6.0), Vector3(0.0, 0.0, -8.0))
		"map":
			_pose_arm("l", Vector3(-55.0, 0.0, -27.0),
				Vector3(55.0, 0.0, 125.0), Vector3(0.0, 0.0, -14.0))
			_pose_arm("r", Vector3(-55.0, 0.0, 27.0),
				Vector3(55.0, 0.0, -125.0), Vector3(0.0, 0.0, 14.0))
			# The map's visible front reaches z=0.376. A 0.105 m-deep paw
			# therefore rests at z=0.487 with 6 mm clearance instead of clipping.
			_place_hand("l", Vector3(0.42, 1.05, 0.487))
			_place_hand("r", Vector3(-0.42, 1.05, 0.487))
		"tablet":
			_pose_arm("l", Vector3(-55.0, 0.0, -30.0),
				Vector3(55.0, 0.0, 130.0), Vector3(0.0, 0.0, -12.0))
			_pose_arm("r", Vector3(-55.0, 0.0, 30.0),
				Vector3(55.0, 0.0, -130.0), Vector3(0.0, 0.0, 16.0))
			# Tablet runes reach z=0.409; z=0.520 retains the same safe gap.
			_place_hand("l", Vector3(0.29, 1.05, 0.520))
			_place_hand("r", Vector3(-0.41, 1.05, 0.520))
		"encourage":
			_pose_arm("l", Vector3(-8.0, 0.0, -58.0),
				Vector3(0.0, 0.0, -26.0), Vector3(0.0, 0.0, 12.0))
			_pose_arm("r", Vector3(-8.0, 0.0, 58.0),
				Vector3(0.0, 0.0, 26.0), Vector3(0.0, 0.0, -12.0))
		"heart":
			_pose_arm("r", Vector3(65.0, 0.0, -147.0),
				Vector3(0.0, 0.0, 81.0), Vector3(0.0, 0.0, 18.0))
			_place_hand("r", Vector3(-0.16, 1.20, 0.405), 35.0)


func _pose_arm(side: String, upper_degrees: Vector3,
		lower_degrees: Vector3, wrist_degrees: Vector3) -> void:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	_set_bone_euler(skeleton, "upperarm.%s" % side, upper_degrees)
	_set_bone_euler(skeleton, "lowerarm.%s" % side, lower_degrees)
	_set_bone_euler(skeleton, "wrist.%s" % side, wrist_degrees)


func _set_bone_euler(skeleton: Skeleton3D, bone_name: String,
		degrees: Vector3) -> void:
	var bone_index := skeleton.find_bone(bone_name)
	if bone_index >= 0:
		var rest_rotation := skeleton.get_bone_pose_rotation(bone_index)
		var gesture_rotation := Quaternion.from_euler(Vector3(
			deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z)))
		skeleton.set_bone_pose_rotation(bone_index, rest_rotation * gesture_rotation)


func _place_hand(side: String, target: Vector3, roll_degrees := 0.0) -> void:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var bone_index := skeleton.find_bone("hand.%s" % side)
	if bone_index < 0:
		return
	var hand_pose := skeleton.get_bone_global_pose(bone_index)
	if not is_zero_approx(roll_degrees):
		hand_pose.basis = Basis(Vector3.FORWARD, deg_to_rad(roll_degrees)) \
			* hand_pose.basis
	hand_pose.origin = target
	skeleton.set_bone_global_pose(bone_index, hand_pose)


func _set_cane_visible(is_visible: bool) -> void:
	for descendant in find_children("*", "Node3D", true, false):
		var part := descendant as Node3D
		var part_name := str(part.name)
		if part_name.begins_with("MayorCane") or part_name.begins_with("CaneGrip"):
			part.visible = is_visible


func _set_counsellor_prop(pose_name: String) -> void:
	if map_prop != null:
		map_prop.visible = pose_name == "map"
	if tablet_prop != null:
		tablet_prop.visible = pose_name == "tablet"
	if counsellor_sparkles != null:
		counsellor_sparkles.visible = pose_name in ["encourage", "heart"]


func _begin_pause(duration := -1.0) -> void:
	_cancel_counsellor_pose_transition()
	_is_walking = false
	_pause_timer = duration if duration >= 0.0 else randf_range(minimum_pause, maximum_pause)
	velocity.x = 0.0
	velocity.z = 0.0
	_reset_cane_gait()
	_reset_mayor_arm_pose()
	_set_cane_visible(true)
	_set_counsellor_prop("")
	_play_animation("Idle_3")
	if anim_player != null:
		anim_player.speed_scale = 1.0


func _reset_cane_gait() -> void:
	_cane_cycle_time = 0.0
	_cane_gait_state = "plant"


func _sample_cane_gait(phase: float) -> Dictionary:
	# One deterministic stride keeps locomotion, cane support and animation
	# cadence in agreement.  Smooth interpolation prevents speed snapping at
	# the plant/support/recovery boundaries.
	var wrapped := fposmod(phase, 1.0)
	if wrapped < CANE_PLANT_END:
		var plant_t := smoothstep(0.0, CANE_PLANT_END, wrapped)
		return {"state": "plant", "speed": lerpf(0.52, 0.72, plant_t)}
	if wrapped < CANE_SUPPORT_END:
		var support_t := smoothstep(CANE_PLANT_END, CANE_SUPPORT_END, wrapped)
		return {"state": "support", "speed": lerpf(0.86, 1.22, support_t)}
	var recovery_t := smoothstep(CANE_SUPPORT_END, 1.0, wrapped)
	return {"state": "recover", "speed": lerpf(0.88, 0.62, recovery_t)}


func _advance_cane_gait(delta: float) -> float:
	_cane_cycle_time = fposmod(_cane_cycle_time + delta, CANE_GAIT_CYCLE_SECONDS)
	var phase := _cane_cycle_time / CANE_GAIT_CYCLE_SECONDS
	var sample := _sample_cane_gait(phase)
	_cane_gait_state = str(sample.state)
	return float(sample.speed)


func get_cane_gait_state() -> String:
	return _cane_gait_state


func _reset_mayor_arm_pose() -> void:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	for bone_name in ["upperarm.l", "lowerarm.l", "wrist.l", "hand.l",
			"upperarm.r", "lowerarm.r", "wrist.r", "hand.r"]:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index >= 0:
			skeleton.reset_bone_pose(bone_index)


func _choose_town_target() -> void:
	var angle := randf() * TAU
	var distance := randf_range(wander_radius * 0.35, wander_radius)
	_walk_target = _home + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	_is_walking = true


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	# Milo stops to greet the player, then resumes his town route after they go.
	if player_in_range:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if not _is_walking:
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_choose_town_target()
	else:
		var to_target := _walk_target - global_position
		to_target.y = 0.0
		if to_target.length() <= 0.45:
			_begin_pause()
		else:
			var direction := to_target.normalized()
			var stride_multiplier := _advance_cane_gait(delta)
			velocity.x = direction.x * walk_speed * stride_multiplier
			velocity.z = direction.z * walk_speed * stride_multiplier
			rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 5.5 * delta)
			# The cane-side arm remains in its authored closed grip while the
			# opposite arm and legs retain the market-villager walking motion.
			_play_animation("Cane_Walk")
			if anim_player != null:
				# Cadence follows the same support curve as translation: slow while
				# planting, quickest while stepping past the cane, then ease back.
				anim_player.speed_scale = lerpf(0.82, 1.08,
					clampf((stride_multiplier - 0.52) / 0.70, 0.0, 1.0))

	move_and_slide()


func look_at_player(delta):
	var target_pos = player.global_transform.origin
	var my_pos = global_transform.origin

	var direction = (target_pos - my_pos).normalized()
	var rotation_y = atan2(direction.x, direction.z)

	rotation.y = lerp_angle(rotation.y, rotation_y, 5.0 * delta)


func _on_area_3d_player_entered(body):
	if body == player:
		player_in_range = true


func _on_area_3d_player_exited(body):
	if body == player:
		player_in_range = false
		_reset_npc_state()


func _reset_npc_state():
	# hard reset everything so nothing gets stuck
	wave_timer = 0.0
	first_wave = false
	_begin_pause(1.0)


func _process(delta):
	_apply_journey_stage()
	if aura != null:
		aura.rotate_y(delta * (0.18 + max(journey_stage, 0) * 0.08))

	# Outside the interaction zone, locomotion owns Milo's facing and animation.
	if not player_in_range:
		return

	look_at_player(delta)

	# INSIDE interaction zone: waving logic
	if not first_wave:
		_play_animation("Wave_One_Hand")
		wave_timer = 0.0
		first_wave = true

	wave_timer += delta

	if wave_timer >= 5.0 and not player.interacting:
		_play_animation("Wave_One_Hand")
		wave_timer = 0.0

	# interaction
	if Input.is_action_just_pressed("interact") and player_in_range and !player.interacting:
		print("Interacting with Milo")
		open_chatbot()
		player.interacting = true


func open_chatbot():
	if chatbot_ui != null:
		return

	chatbot_ui = load("res://scenes/chatbot.tscn").instantiate()
	get_tree().current_scene.add_child(chatbot_ui)
	print("Milo opened chat")

	chatbot_ui.user_input.grab_focus()
	chatbot_ui.connect("chat_closed", Callable(self, "close_chatbot"))
	chatbot_ui.connect("companion_pose_requested",
		Callable(self, "_on_companion_pose_requested"))
	_on_companion_pose_requested("welcome")

	player.interacting = true


func close_chatbot():
	if chatbot_ui != null:
		chatbot_ui.queue_free()
		chatbot_ui = null

	player.interacting = false
	_set_counsellor_prop("")
	_play_animation("Idle_3")
	# Return through the same clear transition instead of snapping the paws back
	# through the coat as the dialogue closes.
	_start_counsellor_arm_transition("neutral")


func _exit_tree() -> void:
	# Scene changes and parent removal can bypass the chatbot's Close signal.
	# Never carry Milo's movement lock into the surviving player/world.
	_cancel_counsellor_pose_transition()
	if chatbot_ui != null and is_instance_valid(chatbot_ui):
		chatbot_ui.queue_free()
		chatbot_ui = null
	if player != null and is_instance_valid(player) and "interacting" in player:
		player.interacting = false


func _build_counsellor_props() -> void:
	counsellor_props = Node3D.new()
	counsellor_props.name = "CounsellorPoseProps"
	add_child(counsellor_props)

	var paper := _counsellor_material("MiloMapPaper", Color("b99158"))
	var paper_dark := _counsellor_material("MiloMapInk", Color("725436"))
	map_prop = Node3D.new()
	map_prop.name = "CounsellorMap"
	map_prop.position = Vector3(0.0, 1.00, 0.35)
	map_prop.rotation_degrees = Vector3(0.0, 0.0, -3.0)
	counsellor_props.add_child(map_prop)
	_prop_box(map_prop, "MapPaper", Vector3(0.48, 0.34, 0.025),
		Vector3.ZERO, paper)
	for fold_x in [-0.08, 0.08]:
		_prop_box(map_prop, "MapFold", Vector3(0.008, 0.31, 0.030),
			Vector3(fold_x, 0.0, 0.018), paper_dark)
	for route_spec in [
		[Vector3(-0.15, 0.08, 0.022), Vector3(0.10, 0.012, 0.008)],
		[Vector3(-0.02, -0.02, 0.022), Vector3(0.14, 0.012, 0.008)],
		[Vector3(0.14, -0.09, 0.022), Vector3(0.09, 0.012, 0.008)],
	]:
		_prop_box(map_prop, "MapRoute", route_spec[1], route_spec[0], paper_dark)

	var tablet_frame := _counsellor_material("MiloTabletFrame", Color("3185a8"), true)
	var tablet_screen := _counsellor_material("MiloTabletScreen", Color("76d9e8"), true)
	tablet_prop = Node3D.new()
	tablet_prop.name = "CounsellorTablet"
	tablet_prop.position = Vector3(-0.06, 1.02, 0.36)
	tablet_prop.rotation_degrees = Vector3(0.0, 0.0, 7.0)
	counsellor_props.add_child(tablet_prop)
	_prop_box(tablet_prop, "TabletFrame", Vector3(0.34, 0.43, 0.030),
		Vector3.ZERO, tablet_frame)
	_prop_box(tablet_prop, "TabletScreen", Vector3(0.29, 0.36, 0.038),
		Vector3(0.0, 0.01, 0.020), tablet_screen)
	for rune_spec in [
		[Vector3(-0.07, 0.08, 0.045), Vector3(0.08, 0.012, 0.008)],
		[Vector3(0.05, 0.00, 0.045), Vector3(0.10, 0.012, 0.008)],
		[Vector3(-0.02, -0.09, 0.045), Vector3(0.13, 0.012, 0.008)],
	]:
		_prop_box(tablet_prop, "TabletRune", rune_spec[1], rune_spec[0], tablet_frame)

	var sparkle_material := _counsellor_material("MiloCounsellorSparkle",
		Color("ffd66e"), true)
	counsellor_sparkles = Node3D.new()
	counsellor_sparkles.name = "CounsellorSparkles"
	counsellor_props.add_child(counsellor_sparkles)
	for sparkle_spec in [
		[Vector3(0.55, 1.52, 0.29), Vector3(0.035, 0.09, 0.025)],
		[Vector3(0.64, 1.38, 0.29), Vector3(0.025, 0.06, 0.020)],
		[Vector3(-0.55, 1.48, 0.29), Vector3(0.025, 0.065, 0.020)],
	]:
		var sparkle := _prop_box(counsellor_sparkles, "CounsellorSparkle",
			sparkle_spec[1], sparkle_spec[0], sparkle_material)
		sparkle.rotation_degrees.z = 45.0

	_set_counsellor_prop("")


func _counsellor_material(material_name: String, color: Color,
		emissive := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = material_name
	material.albedo_color = color
	material.roughness = 0.42
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.65
	return material


func _prop_box(parent: Node3D, part_name: String, size: Vector3,
		position: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = position
	part.material_override = material
	parent.add_child(part)
	return part


# Milo's glow is evidence of the journey, not a generic NPC highlight. The
# orbital bands pick up the same colour as the castle's current stage, so he
# remains the player's visual companion even before they open the chat.
func _build_journey_aura() -> void:
	aura = Node3D.new()
	aura.name = "JourneyAura"
	# Keep the journey glow grounded around Milo's feet. A floating ring above
	# his head made the neutral standing pose read like a prototype gizmo.
	aura.position = Vector3(0.0, 0.10, 0.0)
	add_child(aura)

	var halo := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.50
	ring.outer_radius = 0.54
	ring.rings = 16
	ring.ring_segments = 8
	halo.mesh = ring
	aura_material = StandardMaterial3D.new()
	aura_material.emission_enabled = true
	aura_material.metallic = 0.5
	aura_material.roughness = 0.25
	halo.material_override = aura_material
	aura.add_child(halo)

	for i in range(3):
		var star := MeshInstance3D.new()
		var gem := SphereMesh.new()
		gem.radius = 0.075
		gem.height = 0.15
		gem.radial_segments = 6
		gem.rings = 3
		star.mesh = gem
		star.position = Vector3(cos(TAU * i / 3.0) * 0.56, 0.0,
			sin(TAU * i / 3.0) * 0.56)
		star.material_override = aura_material
		aura.add_child(star)

	aura_light = OmniLight3D.new()
	aura_light.position = Vector3(0.0, 0.55, 0.0)
	aura_light.omni_range = 5.5
	aura_light.shadow_enabled = false
	aura.add_child(aura_light)


func _apply_journey_stage() -> void:
	var js := get_node_or_null("/root/JourneyState")
	var next_stage := clampi(js.stage, 0, STAGE_GLOW.size() - 1) if js != null else 0
	if next_stage == journey_stage:
		return

	journey_stage = next_stage
	if aura == null:
		return
	# Let Milo read as a natural character at the opening stage. The evidence
	# aura appears only after the player has actually advanced their journey.
	aura.visible = journey_stage > 0

	var glow: Color = STAGE_GLOW[journey_stage]
	aura_material.albedo_color = glow
	aura_material.emission = glow
	aura_material.emission_energy_multiplier = STAGE_ENERGY[journey_stage]
	aura_light.light_color = glow
	aura_light.light_energy = STAGE_ENERGY[journey_stage]
	var scale_factor := 0.72 + journey_stage * 0.12
	aura.scale = Vector3.ONE * scale_factor
