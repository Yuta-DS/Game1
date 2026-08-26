extends CharacterBody3D

enum CompanionState {
	WAITING,
	IDLE_NEAR_PLAYER,
	FOLLOWING,
	CATCHING_UP,
	GREETING,
	TALKING,
	LISTENING,
	REFLECTING,
	GUIDING,
	ENCOURAGING,
	CELEBRATING,
	SUPPORTING,
}

@export var walk_speed := 1.10
@export var catch_up_speed := 1.65
@export var movement_acceleration := 4.2
@export var movement_deceleration := 5.4
@export var turn_speed := 5.0
@export var follow_start_distance := 3.1
@export var follow_stop_distance := 2.15
@export var catch_up_distance := 8.0
@export var catch_up_exit_distance := 6.5
@export var safe_reposition_distance := 18.0
@export var maximum_vertical_separation := 5.0
@export var player_teleport_distance := 12.0
@export var breadcrumb_spacing := 0.75
@export var gravity_enabled := true
@export var terrain_grounding_enabled := true

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
var player: CharacterBody3D
var companion_state := CompanionState.WAITING
var _breadcrumbs: Array[Vector3] = []
var _last_player_sample := Vector3.INF
var _previous_player_position := Vector3.INF
var _follow_active := false
var _catch_up_active := false
var mouth_closed: MeshInstance3D
var mouth_open_small: MeshInstance3D
var mouth_open_wide: MeshInstance3D
var tongue_small: GeometryInstance3D
var tongue_wide: GeometryInstance3D
var _speech_remaining := 0.0
var _speech_elapsed := 0.0
var _mouth_shape := "closed"
var _tts_voice_id := ""
var _tts_voice_resolved := false
var greeting_voice: AudioStreamPlayer3D
var _recorded_greeting_played := false
var _conversation_state := CompanionState.GREETING
var _conversation_active := false
var relaxed_eyelids: Array[GeometryInstance3D] = []
var half_eyelids: Array[GeometryInstance3D] = []
var closed_eyelids: Array[GeometryInstance3D] = []
var gaze_parts: Array[Node3D] = []
var _gaze_origins: Dictionary = {}
var _blink_shape := "relaxed"
var _blink_elapsed := 0.0
var _blink_active := false
var _blink_timer := 2.4
var _blink_rng := RandomNumberGenerator.new()
var model_root: Node3D
var _model_base_position := Vector3.ZERO
var _model_base_rotation := Vector3.ZERO
var _motion_elapsed := 0.0
var contact_shadow: MeshInstance3D
var cane_contact_shadow: MeshInstance3D
var free_hand_parts: Array[Node3D] = []
var left_foot_parts: Array[Node3D] = []
var right_foot_parts: Array[Node3D] = []
var _secondary_part_origins: Dictionary = {}
var hand_meshes: Array[MeshInstance3D] = []
var _hand_curl_shape_indices: Dictionary = {}
var gait_skeleton: Skeleton3D
var _gait_bone_indices: Dictionary = {}
var _procedural_gait_angles: Dictionary = {}

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
var _cane_cycle_time := 0.0
var _cane_gait_state := "plant"
var _previous_gait_phase := 0.0
var _leg_ik: Dictionary = {}
var _leg_targets: Dictionary = {}
var _leg_poles: Dictionary = {}
var _foot_locks: Dictionary = {}
var _foot_was_planted: Dictionary = {"l": false, "r": false}
var _cane_arm_ik: TwoBoneIK3D
var _cane_grip_target: Node3D
var _cane_elbow_pole: Node3D
var _cane_rig: Node3D
var _cane_tip_mesh: MeshInstance3D
var _cane_tip_lock := Vector3.ZERO
var _cane_tip_locked := false
var _grounding_targets: Node3D

const CANE_GAIT_CYCLE_SECONDS := 1.28
const CANE_GAIT_STRIDE_METRES := 1.40
const CANE_PLANT_END := 0.18
const CANE_SUPPORT_END := 0.70
const LEFT_FOOT_CONTACT_START := 0.10
const LEFT_FOOT_CONTACT_END := 0.52
const RIGHT_FOOT_CONTACT_START := 0.60
const RIGHT_FOOT_CONTACT_END := 0.02
const CANE_CONTACT_START := 0.05
const CANE_CONTACT_END := 0.52
const CONTACT_BLEND_PHASE := 0.055
const FOOT_BONE_CLEARANCE := 0.14
const GROUND_PROBE_UP := 0.42
const GROUND_PROBE_DOWN := 0.72
const COUNSELLOR_POSE_SECONDS := 0.36
const HAND_CLEARANCE_ARC := 0.16
const BLINK_SECONDS := 0.22
const ARM_BONES := [
	"upperarm.l", "lowerarm.l", "wrist.l", "hand.l",
	"upperarm.r", "lowerarm.r", "wrist.r", "hand.r",
]
const GAIT_BONES := [
	"upperarm.l", "lowerarm.l", "wrist.l", "hand.l",
	"upperarm.r", "lowerarm.r", "wrist.r", "hand.r",
]

var counsellor_pose_tween: Tween
var _active_counsellor_pose := ""


func _ready():
	# Milo is a non-blocking companion. He still collides with the world so his
	# body can walk on terrain, but the player and combat systems cannot hit him.
	collision_layer = 0
	collision_mask = 1
	floor_snap_length = 0.34
	floor_max_angle = deg_to_rad(48.0)
	floor_stop_on_slope = true
	anim_player = _find_animation_player(self)
	if anim_player != null:
		# Evaluate the authored clip before Milo's controller adds its restrained
		# gaze and weight-shift pass during the same rendered frame.
		anim_player.process_priority = -10
	_play_animation("Idle_3")
	model_root = get_node_or_null("Model") as Node3D
	if model_root != null:
		_model_base_position = model_root.position
		_model_base_rotation = model_root.rotation
	_build_counsellor_props()
	_resolve_mouth_shapes()
	greeting_voice = get_node_or_null("MiloGreetingVoice") as AudioStreamPlayer3D
	_resolve_eye_system()
	_resolve_secondary_parts()
	_resolve_gait_rig()
	_build_contact_shadow()
	_setup_terrain_grounding()
	_build_journey_aura()
	_apply_journey_stage()
	var initial_player := _find_player()
	if initial_player != null:
		set_companion_player(initial_player, false)
	else:
		_set_companion_state(CompanionState.WAITING)


func _find_player() -> CharacterBody3D:
	for group_name in [&"player", &"Player"]:
		var candidate := get_tree().get_first_node_in_group(group_name)
		if candidate is CharacterBody3D:
			return candidate as CharacterBody3D
	var parent := get_parent()
	if parent != null:
		for node_name in [&"NewPlayer", &"Player3D"]:
			var candidate := parent.get_node_or_null(NodePath(String(node_name)))
			if candidate is CharacterBody3D:
				return candidate as CharacterBody3D
	return null


func set_companion_player(next_player: CharacterBody3D,
		reposition_near_player := false) -> void:
	player = next_player
	_breadcrumbs.clear()
	_last_player_sample = Vector3.INF
	_previous_player_position = Vector3.INF
	_follow_active = false
	_catch_up_active = false
	if player == null:
		_set_companion_state(CompanionState.WAITING)
		return
	_sample_player_breadcrumb(true)
	_previous_player_position = player.global_position
	if reposition_near_player or global_position.distance_to(player.global_position) \
			> safe_reposition_distance:
		_reposition_safely_near_player()
	_set_companion_state(CompanionState.IDLE_NEAR_PLAYER)


func _set_companion_state(next_state: CompanionState) -> void:
	companion_state = next_state


func get_companion_state_name() -> String:
	return CompanionState.keys()[companion_state]


func _resolve_mouth_shapes() -> void:
	mouth_closed = find_child("Mouth", true, false) as MeshInstance3D
	mouth_open_small = find_child("MouthOpenSmall", true, false) as MeshInstance3D
	mouth_open_wide = find_child("MouthOpenWide", true, false) as MeshInstance3D
	tongue_small = find_child("TongueSmall", true, false) as GeometryInstance3D
	tongue_wide = find_child("TongueWide", true, false) as GeometryInstance3D
	_set_mouth_shape("closed")


func _set_mouth_shape(shape_name: String) -> void:
	_mouth_shape = shape_name
	if mouth_closed != null:
		mouth_closed.visible = shape_name == "closed"
	if mouth_open_small != null:
		mouth_open_small.visible = shape_name == "small"
	if mouth_open_wide != null:
		mouth_open_wide.visible = shape_name == "wide"
	if tongue_small != null:
		tongue_small.visible = shape_name == "small"
	if tongue_wide != null:
		tongue_wide.visible = shape_name == "wide"


func _on_companion_speech_requested(spoken_text: String) -> void:
	var clean_text := spoken_text.strip_edges()
	if clean_text.is_empty():
		_stop_speaking()
		return
	_speech_elapsed = 0.0
	_speech_remaining = clampf(float(clean_text.length()) / 14.0, 0.8, 42.0)
	_set_companion_state(CompanionState.TALKING)
	_set_mouth_shape("small")
	if greeting_voice != null and greeting_voice.playing:
		greeting_voice.stop()
	_speak_with_platform_voice(_spoken_version(clean_text))


func _play_recorded_greeting() -> void:
	if greeting_voice == null or greeting_voice.stream == null \
			or greeting_voice.playing or _recorded_greeting_played:
		return
	_recorded_greeting_played = true
	_speech_elapsed = 0.0
	_speech_remaining = greeting_voice.stream.get_length()
	_set_companion_state(CompanionState.TALKING)
	_set_mouth_shape("small")
	greeting_voice.play()


func _spoken_version(source_text: String) -> String:
	var spoken := source_text.replace("Wonderful Counsellor Milo ·", "")
	spoken = spoken.replace("Milo:", "")
	spoken = spoken.replace("·", ".")
	# UI layout uses blank lines and bullets; TTS reads more naturally when they
	# become pauses instead of announcing formatting.
	while "\n\n" in spoken:
		spoken = spoken.replace("\n\n", ". ")
	return spoken.replace("\n", " ").strip_edges()


func _speak_with_platform_voice(spoken_text: String) -> void:
	if spoken_text.is_empty() or not DisplayServer.has_feature(
			DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	if not _tts_voice_resolved:
		_tts_voice_resolved = true
		var voices := DisplayServer.tts_get_voices()
		# Milo has one recognisable voice across supported platforms. Prefer a
		# warm male English voice by name, then fall back by English locale.
		for voice_data in voices:
			var voice_name := str(voice_data.get("name", "")).to_lower()
			var voice_id := str(voice_data.get("id", "")).to_lower()
			if voice_name.contains("daniel") or voice_id.contains("daniel"):
				_tts_voice_id = str(voice_data.get("id", ""))
				break
		for preferred_prefix in ["en_GB", "en_AU", "en_US", "en"]:
			if not _tts_voice_id.is_empty():
				break
			for voice_data in voices:
				if str(voice_data.get("language", "")).begins_with(preferred_prefix):
					_tts_voice_id = str(voice_data.get("id", ""))
					break
			if not _tts_voice_id.is_empty():
				break
	if _tts_voice_id.is_empty():
		return
	var voice_volume := 82
	if player != null:
		var distance := global_position.distance_to(player.global_position)
		voice_volume = int(round(lerpf(86.0, 24.0, clampf(distance / 30.0, 0.0, 1.0))))
	DisplayServer.tts_speak(spoken_text, _tts_voice_id, voice_volume, 0.90, 0.96, 2603, true)


func _on_companion_activity_state_requested(state_name: String) -> void:
	var state_key := state_name.to_upper()
	if not CompanionState.has(state_key):
		return
	_conversation_state = int(CompanionState[state_key])
	_conversation_active = true
	if not is_speaking():
		_set_companion_state(_conversation_state)


func _update_speaking(delta: float) -> void:
	if _speech_remaining <= 0.0:
		return
	_speech_elapsed += delta
	_speech_remaining = maxf(0.0, _speech_remaining - delta)
	if _speech_remaining <= 0.0:
		_stop_speaking()
		return
	var phase := int(floor(_speech_elapsed / 0.11)) % 4
	match phase:
		0, 2:
			_set_mouth_shape("small")
		1:
			_set_mouth_shape("wide")
		_:
			_set_mouth_shape("closed")


func _stop_speaking() -> void:
	_speech_remaining = 0.0
	_speech_elapsed = 0.0
	_set_mouth_shape("closed")
	if _conversation_active:
		_set_companion_state(_conversation_state)
	elif player != null:
		_set_companion_state(CompanionState.IDLE_NEAR_PLAYER)


func is_speaking() -> bool:
	return _speech_remaining > 0.0


func get_mouth_shape() -> String:
	return _mouth_shape


func _resolve_eye_system() -> void:
	_blink_rng.seed = 0x4d494c4f
	for side in ["L", "R"]:
		var relaxed := find_child("EyelidRelaxed_%s" % side, true, false) \
			as GeometryInstance3D
		var half := find_child("EyelidHalf_%s" % side, true, false) \
			as GeometryInstance3D
		var closed := find_child("EyelidClosed_%s" % side, true, false) \
			as GeometryInstance3D
		if relaxed != null:
			relaxed_eyelids.append(relaxed)
		if half != null:
			half_eyelids.append(half)
		if closed != null:
			closed_eyelids.append(closed)
		for part_prefix in ["Pupil", "IrisInner", "EyeCatchlight"]:
			var part := find_child("%s_%s" % [part_prefix, side], true, false) \
				as Node3D
			if part != null:
				gaze_parts.append(part)
				_gaze_origins[part] = part.position
	_set_eyelid_shape("relaxed")


func trigger_blink() -> void:
	_blink_active = true
	_blink_elapsed = 0.0


func get_blink_shape() -> String:
	return _blink_shape


func _set_eyelid_shape(shape_name: String) -> void:
	_blink_shape = shape_name
	for lid in relaxed_eyelids:
		lid.visible = shape_name == "relaxed"
	for lid in half_eyelids:
		lid.visible = shape_name == "half"
	for lid in closed_eyelids:
		lid.visible = shape_name == "closed"


func _update_eye_animation(delta: float) -> void:
	if _blink_active:
		_blink_elapsed += delta
		var phase := _blink_elapsed / BLINK_SECONDS
		if phase < 0.25:
			_set_eyelid_shape("half")
		elif phase < 0.58:
			_set_eyelid_shape("closed")
		elif phase < 0.82:
			_set_eyelid_shape("half")
		else:
			_set_eyelid_shape("relaxed")
			_blink_active = false
			_blink_timer = _blink_rng.randf_range(2.6, 5.1)
	else:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			trigger_blink()

	# Milo follows the player's face with a deliberately tiny shared iris move.
	# Keeping all six eye layers together avoids the sliding-doll-eye effect.
	var gaze_offset := Vector3.ZERO
	if player != null and is_instance_valid(player):
		var local_target := global_transform.affine_inverse() \
			* (player.global_position + Vector3.UP * 1.25)
		gaze_offset.x = clampf(local_target.x * 0.0035, -0.010, 0.010)
		gaze_offset.z = clampf((local_target.y - 1.50) * 0.0035, -0.006, 0.006)
	var focus_weight := 1.0 - exp(-delta * 8.0)
	for part in gaze_parts:
		var origin: Vector3 = _gaze_origins[part]
		part.position = part.position.lerp(origin + gaze_offset, focus_weight)


func get_gaze_offset() -> Vector3:
	if gaze_parts.is_empty():
		return Vector3.ZERO
	var part := gaze_parts[0]
	return part.position - (_gaze_origins[part] as Vector3)


func _resolve_secondary_parts() -> void:
	for part_name in ["Paw_L", "Cuff_L", "CuffAccent_L"]:
		_add_secondary_part(free_hand_parts, part_name)
	for side in ["L", "R"]:
		var hand := find_child("Paw_%s" % side, true, false) as MeshInstance3D
		if hand == null or hand.mesh == null:
			continue
		for shape_index in hand.mesh.get_blend_shape_count():
			if hand.mesh.get_blend_shape_name(shape_index) == "FingerCurl":
				hand_meshes.append(hand)
				_hand_curl_shape_indices[hand] = shape_index
				break
	for part_name in ["Trouser_L", "Boot_L", "Sole_L"]:
		_add_secondary_part(left_foot_parts, part_name)
	for part_name in ["Trouser_R", "Boot_R", "Sole_R"]:
		_add_secondary_part(right_foot_parts, part_name)


func _resolve_gait_rig() -> void:
	gait_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if gait_skeleton == null:
		return
	for bone_name in GAIT_BONES:
		var bone_index := gait_skeleton.find_bone(bone_name)
		if bone_index >= 0:
			_gait_bone_indices[bone_name] = bone_index
			_procedural_gait_angles[bone_name] = Vector3.ZERO


func _setup_terrain_grounding() -> void:
	if not terrain_grounding_enabled or gait_skeleton == null:
		return
	_grounding_targets = Node3D.new()
	_grounding_targets.name = "MiloGroundingTargets"
	add_child(_grounding_targets)
	for side in ["l", "r"]:
		var foot_target := Node3D.new()
		foot_target.name = "FootTarget_%s" % side.to_upper()
		_grounding_targets.add_child(foot_target)
		foot_target.global_position = _bone_world_position("foot.%s" % side)
		_leg_targets[side] = foot_target
		var knee_pole := Node3D.new()
		knee_pole.name = "KneePole_%s" % side.to_upper()
		_grounding_targets.add_child(knee_pole)
		knee_pole.global_position = _bone_world_position("lowerleg.%s" % side) \
			+ global_transform.basis.z.normalized() * 0.32
		_leg_poles[side] = knee_pole
		var leg_ik := _create_two_bone_ik("LegIK_%s" % side.to_upper(),
			"upperleg.%s" % side, "lowerleg.%s" % side, "foot.%s" % side,
			foot_target, knee_pole)
		if leg_ik != null:
			_leg_ik[side] = leg_ik
	_setup_cane_constraint()


func _create_two_bone_ik(node_name: String, root_bone: String,
		middle_bone: String, end_bone: String, target: Node3D,
		pole: Node3D) -> TwoBoneIK3D:
	if gait_skeleton.find_bone(root_bone) < 0 \
			or gait_skeleton.find_bone(middle_bone) < 0 \
			or gait_skeleton.find_bone(end_bone) < 0:
		return null
	var ik := TwoBoneIK3D.new()
	ik.name = node_name
	gait_skeleton.add_child(ik)
	ik.set_setting_count(1)
	ik.set_root_bone_name(0, root_bone)
	ik.set_middle_bone_name(0, middle_bone)
	ik.set_end_bone_name(0, end_bone)
	ik.set_target_node(0, ik.get_path_to(target))
	ik.set_pole_node(0, ik.get_path_to(pole))
	ik.set_influence(0.0)
	return ik


func _setup_cane_constraint() -> void:
	_cane_tip_mesh = find_child("MayorCaneGroundTip", true, false) \
		as MeshInstance3D
	if _cane_tip_mesh == null:
		return
	_cane_rig = Node3D.new()
	_cane_rig.name = "MiloCaneRig"
	gait_skeleton.add_child(_cane_rig)
	var cane_parts := gait_skeleton.find_children("MayorCane*", "MeshInstance3D",
		false, false)
	for part in cane_parts:
		(part as Node3D).reparent(_cane_rig, true)
	_cane_grip_target = Node3D.new()
	_cane_grip_target.name = "MiloCaneGripTarget"
	_cane_rig.add_child(_cane_grip_target)
	_cane_grip_target.global_position = _bone_world_position("wrist.l")
	_cane_elbow_pole = Node3D.new()
	_cane_elbow_pole.name = "MiloCaneElbowPole"
	_grounding_targets.add_child(_cane_elbow_pole)
	_cane_elbow_pole.global_position = _bone_world_position("lowerarm.l") \
		+ global_transform.basis.z.normalized() * 0.24
	_cane_arm_ik = _create_two_bone_ik("CaneArmIK", "upperarm.l",
		"lowerarm.l", "wrist.l", _cane_grip_target, _cane_elbow_pole)


func _bone_world_position(bone_name: String) -> Vector3:
	if gait_skeleton == null:
		return global_position
	var bone_index := gait_skeleton.find_bone(bone_name)
	if bone_index < 0:
		return global_position
	return gait_skeleton.global_transform \
		* gait_skeleton.get_bone_global_pose(bone_index).origin


func _add_secondary_part(target: Array[Node3D], part_name: String) -> void:
	var part := find_child(part_name, true, false) as Node3D
	if part != null:
		target.append(part)
		_secondary_part_origins[part] = part.position


func get_companion_activity_name() -> String:
	return CompanionState.keys()[_conversation_state]


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
	_active_counsellor_pose = pose_name
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
	if cane_contact_shadow != null:
		cane_contact_shadow.visible = is_visible


func _set_counsellor_prop(pose_name: String) -> void:
	if map_prop != null:
		map_prop.visible = pose_name == "map"
	if tablet_prop != null:
		tablet_prop.visible = pose_name == "tablet"
	if counsellor_sparkles != null:
		counsellor_sparkles.visible = pose_name in ["encourage", "heart"]


func _begin_pause(_duration := -1.0) -> void:
	_cancel_counsellor_pose_transition()
	_active_counsellor_pose = ""
	velocity.x = 0.0
	velocity.z = 0.0
	_reset_cane_gait()
	_reset_mayor_arm_pose()
	_set_cane_visible(true)
	_set_counsellor_prop("")
	_play_animation("Idle_3")
	if anim_player != null:
		anim_player.speed_scale = 1.0
	if player != null:
		_set_companion_state(CompanionState.IDLE_NEAR_PLAYER)


func _reset_cane_gait() -> void:
	_cane_cycle_time = 0.0
	_previous_gait_phase = 0.0
	_cane_gait_state = "plant"
	_foot_locks.clear()
	_foot_was_planted = {"l": false, "r": false}
	_cane_tip_locked = false
	for side in _leg_ik:
		(_leg_ik[side] as TwoBoneIK3D).set_influence(0.0)
	if _cane_arm_ik != null:
		_cane_arm_ik.set_influence(0.0)


func _sample_cane_gait(phase: float) -> Dictionary:
	# One deterministic stride keeps locomotion, cane support and animation
	# cadence in agreement.  Smooth interpolation prevents speed snapping at
	# the plant/support/recovery boundaries.
	var wrapped := fposmod(phase, 1.0)
	if wrapped < CANE_PLANT_END:
		var plant_t := smoothstep(0.0, CANE_PLANT_END, wrapped)
		return {"state": "plant", "speed": lerpf(0.95, 0.98, plant_t)}
	if wrapped < CANE_SUPPORT_END:
		var support_t := smoothstep(CANE_PLANT_END, CANE_SUPPORT_END, wrapped)
		return {"state": "support", "speed": lerpf(0.98, 1.025, support_t)}
	var recovery_t := smoothstep(CANE_SUPPORT_END, 1.0, wrapped)
	return {"state": "recover", "speed": lerpf(1.015, 0.95, recovery_t)}


func _advance_cane_gait(delta: float, actual_speed := 0.0) -> float:
	# Distance, rather than a second independent timer, owns phase. A collision,
	# acceleration or castle corner therefore slows the feet and cane together.
	var travelled := maxf(actual_speed, 0.0) * delta
	var phase_delta := travelled / CANE_GAIT_STRIDE_METRES
	_previous_gait_phase = _current_gait_phase()
	_cane_cycle_time = fposmod(_cane_cycle_time \
		+ phase_delta * CANE_GAIT_CYCLE_SECONDS, CANE_GAIT_CYCLE_SECONDS)
	var phase := _cane_cycle_time / CANE_GAIT_CYCLE_SECONDS
	var sample := _sample_cane_gait(phase)
	_cane_gait_state = str(sample.state)
	return float(sample.speed)


func get_cane_gait_state() -> String:
	return _cane_gait_state


func get_gait_phase() -> float:
	return _current_gait_phase()


func get_foot_contact_weight(side: String) -> float:
	var phase := _current_gait_phase()
	if side.to_lower() == "l":
		return _contact_weight(phase, LEFT_FOOT_CONTACT_START,
			LEFT_FOOT_CONTACT_END)
	return _contact_weight(phase, RIGHT_FOOT_CONTACT_START,
		RIGHT_FOOT_CONTACT_END)


func get_cane_contact_weight() -> float:
	return _contact_weight(_current_gait_phase(), CANE_CONTACT_START,
		CANE_CONTACT_END)


func _contact_weight(phase: float, contact_start: float,
		contact_end: float) -> float:
	var duration := fposmod(contact_end - contact_start, 1.0)
	var progress := fposmod(phase - contact_start, 1.0)
	if progress > duration:
		return 0.0
	var fade := minf(CONTACT_BLEND_PHASE, duration * 0.35)
	var fade_in := smoothstep(0.0, fade, progress)
	var fade_out := smoothstep(0.0, fade, duration - progress)
	return minf(fade_in, fade_out)


func _reset_mayor_arm_pose() -> void:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	for bone_name in ["upperarm.l", "lowerarm.l", "wrist.l", "hand.l",
			"upperarm.r", "lowerarm.r", "wrist.r", "hand.r"]:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index >= 0:
			skeleton.reset_bone_pose(bone_index)


func _physics_process(delta: float) -> void:
	if gravity_enabled and not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	if player == null or not is_instance_valid(player):
		player = _find_player()
		if player == null:
			_set_companion_state(CompanionState.WAITING)
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()
			return
		set_companion_player(player, false)

	if _player_teleported_since_last_frame():
		_reposition_safely_near_player()
		move_and_slide()
		return
	_sample_player_breadcrumb()
	# Conversation owns Milo's pose and facing until the panel closes.
	if chatbot_ui != null or player_in_range:
		_approach_horizontal_velocity(Vector3.ZERO, movement_deceleration, delta)
		move_and_slide()
		return

	var separation := global_position.distance_to(player.global_position)
	_prune_reached_breadcrumbs()
	if separation >= follow_start_distance:
		_follow_active = true
	elif separation <= follow_stop_distance:
		_follow_active = false
	if not _follow_active:
		if companion_state in [CompanionState.FOLLOWING, CompanionState.CATCHING_UP]:
			var remaining_speed := _approach_horizontal_velocity(
				Vector3.ZERO, movement_deceleration, delta)
			if remaining_speed <= 0.03:
				_begin_pause()
			else:
				_play_animation("Cane_Walk")
				_update_locomotion_playback(remaining_speed, walk_speed)
		else:
			_approach_horizontal_velocity(Vector3.ZERO, movement_deceleration, delta)
		move_and_slide()
		return

	var target := _breadcrumbs[0] if not _breadcrumbs.is_empty() \
		else player.global_position
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.01:
		_approach_horizontal_velocity(Vector3.ZERO, movement_deceleration, delta)
		move_and_slide()
		return
	var direction := to_target.normalized()
	if separation >= catch_up_distance:
		_catch_up_active = true
	elif separation <= catch_up_exit_distance:
		_catch_up_active = false
	var movement_speed := catch_up_speed if _catch_up_active else walk_speed
	_set_companion_state(CompanionState.CATCHING_UP if _catch_up_active \
		else CompanionState.FOLLOWING)
	var stride_multiplier := float(_sample_cane_gait(_current_gait_phase()).speed)
	var desired_velocity := direction * movement_speed * stride_multiplier
	if not _has_walkable_ground_ahead(direction):
		desired_velocity = Vector3.ZERO
	# Catch-up changes the destination speed, not Milo's physical ability to lunge.
	# Keeping the same acceleration preserves the supported elderly silhouette.
	var acceleration := movement_acceleration
	var actual_speed := _approach_horizontal_velocity(
		desired_velocity, acceleration, delta)
	_advance_cane_gait(delta, actual_speed)
	var travel_direction := Vector3(velocity.x, 0.0, velocity.z).normalized()
	if travel_direction.length_squared() > 0.01:
		var turn_weight := 1.0 - exp(-turn_speed * delta)
		rotation.y = lerp_angle(rotation.y,
			atan2(travel_direction.x, travel_direction.z), turn_weight)
	# Milo is an elderly cane user, so catch-up remains a quicker version of the
	# same supported gait instead of switching into the donor's human sprint.
	_play_animation("Cane_Walk")
	_update_locomotion_playback(actual_speed, movement_speed)

	move_and_slide()


func _approach_horizontal_velocity(target: Vector3, acceleration: float,
		delta: float) -> float:
	var current := Vector3(velocity.x, 0.0, velocity.z)
	var next := current.move_toward(Vector3(target.x, 0.0, target.z),
		maxf(acceleration, 0.01) * delta)
	velocity.x = next.x
	velocity.z = next.z
	return next.length()


func _update_locomotion_playback(actual_speed: float, authored_speed: float) -> void:
	if anim_player == null:
		return
	var clip := anim_player.get_animation("Cane_Walk")
	if clip == null or clip.length <= 0.0:
		return
	# Seeking the donor clip from the one gait clock removes drift between Milo's
	# physical travel, leg pose and procedural cane/arm overlay.
	anim_player.speed_scale = 0.0
	anim_player.seek(_current_gait_phase() * clip.length, true)


func _has_walkable_ground_ahead(direction: Vector3) -> bool:
	# Headless controller tests intentionally have no floor. Only enforce the
	# ledge probe once CharacterBody3D has confirmed that Milo is grounded.
	if not gravity_enabled or not is_on_floor() or direction.length_squared() < 0.01:
		return true
	var world := get_world_3d()
	if world == null:
		return true
	var probe_origin := global_position + direction.normalized() * 0.48 \
		+ Vector3.UP * 0.48
	var query := PhysicsRayQueryParameters3D.create(probe_origin,
		probe_origin + Vector3.DOWN * 1.15, collision_mask)
	query.exclude = [get_rid()]
	if player != null and is_instance_valid(player):
		query.exclude.append(player.get_rid())
	return not world.direct_space_state.intersect_ray(query).is_empty()


func _sample_player_breadcrumb(force := false) -> void:
	if player == null:
		return
	var sample := player.global_position
	if not force and _last_player_sample != Vector3.INF \
			and sample.distance_to(_last_player_sample) < breadcrumb_spacing:
		return
	_breadcrumbs.append(sample)
	_last_player_sample = sample
	if _breadcrumbs.size() > 96:
		_breadcrumbs.pop_front()


func _player_teleported_since_last_frame() -> bool:
	if player == null:
		return false
	var current := player.global_position
	if _previous_player_position == Vector3.INF:
		_previous_player_position = current
		return false
	var moved := current.distance_to(_previous_player_position)
	_previous_player_position = current
	return moved >= player_teleport_distance


func _prune_reached_breadcrumbs() -> void:
	while _breadcrumbs.size() > 1:
		if not _has_reached_breadcrumb(_breadcrumbs[0]):
			break
		_breadcrumbs.pop_front()


func _has_reached_breadcrumb(point: Vector3) -> bool:
	var point_delta := point - global_position
	var horizontal_delta := Vector2(point_delta.x, point_delta.z).length()
	# A point directly above or below Milo is not reached. Retaining its height
	# keeps him on the player's castle stair/ledge route instead of cutting to
	# another side of the structure.
	return horizontal_delta <= 0.65 and absf(point_delta.y) <= 0.85


func _reposition_safely_near_player() -> void:
	if player == null:
		return
	var horizontal_velocity := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var behind := -horizontal_velocity.normalized() if horizontal_velocity.length() > 0.2 \
		else Vector3(1.0, 0.0, 1.0).normalized()
	var desired := player.global_position
	var world := get_world_3d()
	if world != null:
		var side := Vector3(-behind.z, 0.0, behind.x)
		for offset: Vector3 in [behind * follow_stop_distance,
				side * follow_stop_distance, -side * follow_stop_distance,
				-behind * follow_stop_distance, Vector3.ZERO]:
			var candidate: Vector3 = player.global_position + offset
			var query := PhysicsRayQueryParameters3D.create(
				candidate + Vector3.UP * 4.0, candidate + Vector3.DOWN * 10.0, 1)
			query.exclude = [get_rid(), player.get_rid()]
			var hit := world.direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				desired = candidate
				desired.y = (hit.position as Vector3).y + 0.05
				break
	global_position = desired
	velocity = Vector3.ZERO
	_breadcrumbs.clear()
	_follow_active = false
	_catch_up_active = false
	_sample_player_breadcrumb(true)
	_previous_player_position = player.global_position
	_begin_pause()


func look_at_player(delta):
	if player == null:
		return
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
	_update_speaking(delta)
	_update_eye_animation(delta)
	_update_secondary_motion(delta)
	_update_terrain_grounding(delta)
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
		_set_companion_state(CompanionState.GREETING)
		_play_recorded_greeting()
		wave_timer = 0.0
		first_wave = true

	wave_timer += delta

	if wave_timer >= 5.0 and not _player_is_busy():
		_play_animation("Wave_One_Hand")
		wave_timer = 0.0

	# interaction
	if Input.is_action_just_pressed("interact") and player_in_range \
			and not _player_is_busy():
		print("Interacting with Milo")
		open_chatbot()


func _update_secondary_motion(delta: float) -> void:
	if model_root == null:
		return
	_motion_elapsed += delta
	var target_position := _model_base_position
	var target_rotation := _model_base_rotation
	var is_walking := companion_state in [CompanionState.FOLLOWING,
		CompanionState.CATCHING_UP]
	var stride_wave := 0.0
	var gait_strength := 0.0
	if is_walking:
		var stride_phase := _current_gait_phase()
		stride_wave = sin(stride_phase * TAU)
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		gait_strength = clampf(horizontal_speed / maxf(walk_speed, 0.01), 0.0, 1.0)
		# The root carries only the centre-of-mass shift. Limbs articulate on their
		# deform bones below; moving whole skinned meshes made the old feet slide.
		target_position.y += (1.0 - absf(stride_wave)) * 0.006 * gait_strength
		target_position.x += stride_wave * 0.005 * gait_strength
		target_rotation.x -= 0.045 * gait_strength
		target_rotation.z += stride_wave * 0.012 * gait_strength
	else:
		var breath := sin(_motion_elapsed * 1.65)
		target_position.y += breath * 0.004
		target_rotation.z += breath * 0.004
	var settle_weight := 1.0 - exp(-delta * 10.0)
	model_root.position = model_root.position.lerp(target_position, settle_weight)
	model_root.rotation.x = lerp_angle(model_root.rotation.x,
		target_rotation.x, settle_weight)
	model_root.rotation.z = lerp_angle(model_root.rotation.z,
		target_rotation.z, settle_weight)
	_update_limb_secondary_motion(stride_wave, is_walking, gait_strength, delta)


func _update_terrain_grounding(delta: float) -> void:
	if not terrain_grounding_enabled or gait_skeleton == null:
		return
	var is_walking := companion_state in [CompanionState.FOLLOWING,
		CompanionState.CATCHING_UP]
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var gait_strength := clampf(horizontal_speed / maxf(walk_speed, 0.01),
		0.0, 1.0) if is_walking else 0.0
	for side in ["l", "r"]:
		_update_foot_grounding(side, get_foot_contact_weight(side) * gait_strength)
	_update_cane_grounding(delta, get_cane_contact_weight() * gait_strength,
		is_walking, gait_strength)


func _update_foot_grounding(side: String, contact_weight: float) -> void:
	if not _leg_ik.has(side) or not _leg_targets.has(side):
		return
	var ik := _leg_ik[side] as TwoBoneIK3D
	var target := _leg_targets[side] as Node3D
	var animated_position := _bone_world_position("foot.%s" % side)
	var planted := contact_weight > 0.015
	if planted and not bool(_foot_was_planted.get(side, false)):
		var hit := _probe_ground(animated_position)
		if not hit.is_empty():
			var floor_point := hit.position as Vector3
			_foot_locks[side] = Vector3(animated_position.x,
				floor_point.y + FOOT_BONE_CLEARANCE, animated_position.z)
	if planted and _foot_locks.has(side):
		var locked: Vector3 = _foot_locks[side]
		var ground_hit := _probe_ground(locked)
		if not ground_hit.is_empty():
			locked.y = (ground_hit.position as Vector3).y + FOOT_BONE_CLEARANCE
			_foot_locks[side] = locked
		target.global_position = locked
		ik.set_influence(contact_weight)
	else:
		target.global_position = animated_position
		ik.set_influence(0.0)
		if not planted:
			_foot_locks.erase(side)
	var pole := _leg_poles.get(side) as Node3D
	if pole != null:
		pole.global_position = _bone_world_position("lowerleg.%s" % side) \
			+ global_transform.basis.z.normalized() * 0.32
	_foot_was_planted[side] = planted


func _update_cane_grounding(delta: float, contact_weight: float,
		is_walking: bool, gait_strength: float) -> void:
	if _cane_rig == null or _cane_tip_mesh == null:
		return
	var planted := is_walking and contact_weight > 0.015
	if planted and not _cane_tip_locked:
		var tip_position := _cane_tip_world_position()
		var hit := _probe_ground(tip_position)
		if not hit.is_empty():
			_cane_tip_lock = hit.position as Vector3
			_cane_tip_locked = true
	if planted and _cane_tip_locked:
		var tip_now := _cane_tip_world_position()
		_cane_rig.global_position += _cane_tip_lock - tip_now
		if cane_contact_shadow != null:
			cane_contact_shadow.global_position = _cane_tip_lock \
				+ Vector3.UP * 0.027
	else:
		_cane_tip_locked = false
		var phase := _current_gait_phase()
		var recovery_progress := fposmod(phase - CANE_CONTACT_END, 1.0) \
			/ fposmod(CANE_CONTACT_START - CANE_CONTACT_END, 1.0)
		var recovery_arc := sin(clampf(recovery_progress, 0.0, 1.0) * PI)
		var recovery_offset := Vector3(0.0, recovery_arc * 0.055,
			recovery_arc * 0.075) * gait_strength
		var settle := 1.0 - exp(-delta * 9.0)
		_cane_rig.position = _cane_rig.position.lerp(recovery_offset, settle)
		if cane_contact_shadow != null:
			var tip := _cane_tip_world_position()
			cane_contact_shadow.global_position = Vector3(tip.x,
				global_position.y + 0.027, tip.z)
	if _cane_elbow_pole != null:
		_cane_elbow_pole.global_position = _bone_world_position("lowerarm.l") \
			+ global_transform.basis.z.normalized() * 0.24
	if _cane_arm_ik != null:
		_cane_arm_ik.set_influence(0.76 * gait_strength if is_walking else 0.0)


func _cane_tip_world_position() -> Vector3:
	if _cane_tip_mesh == null or _cane_tip_mesh.mesh == null:
		return global_position
	var bounds := _cane_tip_mesh.get_aabb()
	var local_tip := Vector3(bounds.get_center().x, bounds.position.y,
		bounds.get_center().z)
	return _cane_tip_mesh.to_global(local_tip)


func _probe_ground(point: Vector3) -> Dictionary:
	var world := get_world_3d()
	if world == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * GROUND_PROBE_UP,
		point + Vector3.DOWN * GROUND_PROBE_DOWN, collision_mask)
	query.exclude = [get_rid()]
	if player != null and is_instance_valid(player):
		query.exclude.append(player.get_rid())
	return world.direct_space_state.intersect_ray(query)


func _update_limb_secondary_motion(stride_wave: float, is_walking: bool,
		gait_strength: float, delta: float) -> void:
	var weight := 1.0 - exp(-delta * 16.0)
	# Skinned hands and shoes must remain at their authored node origins. Their
	# bones now create the motion, keeping sleeves, trousers and paws connected.
	_set_secondary_part_offset(free_hand_parts, Vector3.ZERO, weight)
	_set_secondary_part_offset(left_foot_parts, Vector3.ZERO, weight)
	_set_secondary_part_offset(right_foot_parts, Vector3.ZERO, weight)
	_update_procedural_cane_gait(stride_wave, is_walking, gait_strength, delta)
	_update_hand_motion(stride_wave, is_walking, delta)


func _update_procedural_cane_gait(stride_wave: float, is_walking: bool,
		gait_strength: float, delta: float) -> void:
	if gait_skeleton == null:
		return
	# The counsellor FK pose owns these same arm bones. The idle cane-gait pass
	# used to reset their rotations after the transition, pulling both paws away
	# from the visible map and tablet edges.
	if not _active_counsellor_pose.is_empty():
		return
	if not is_walking and companion_state not in [CompanionState.WAITING,
			CompanionState.IDLE_NEAR_PLAYER]:
		# Dialogue, greetings and authored gestures own the rig completely.
		return
	var targets: Dictionary = {}
	for bone_name in GAIT_BONES:
		targets[bone_name] = Vector3.ZERO
	if is_walking:
		var phase := _current_gait_phase()
		var cane_wave := cos(phase * TAU)
		var cane_load := maxf(cane_wave, 0.0)

		# The visual right arm is .l on this mirrored donor rig. It stays flexed
		# around the cane and advances only a few degrees. The free arm (.r) makes
		# the restrained counter-swing that balances the opposite stepping leg.
		targets["upperarm.l"] = Vector3(-3.0 + cane_wave * 2.5, 0.0, -4.0)
		targets["lowerarm.l"] = Vector3(-13.0 + cane_load * 3.0, 0.0, 0.0)
		targets["wrist.l"] = Vector3(4.0 - cane_wave * 2.0, 0.0, 0.0)
		targets["hand.l"] = Vector3(0.0, 0.0, cane_wave * 1.5)
		targets["upperarm.r"] = Vector3(-stride_wave * 9.0, 0.0, 2.0)
		targets["lowerarm.r"] = Vector3(-7.0 - absf(stride_wave) * 5.0,
			0.0, 0.0)
		targets["wrist.r"] = Vector3(stride_wave * 2.5, 0.0, 0.0)

	for bone_name in targets:
		targets[bone_name] = (targets[bone_name] as Vector3) * gait_strength
	var blend_weight := 1.0 - exp(-delta * (18.0 if is_walking else 10.0))
	for bone_name in _gait_bone_indices:
		var bone_index: int = _gait_bone_indices[bone_name]
		var target_degrees: Vector3 = targets.get(bone_name, Vector3.ZERO)
		var target_rotation := Quaternion.from_euler(Vector3(
			deg_to_rad(target_degrees.x), deg_to_rad(target_degrees.y),
			deg_to_rad(target_degrees.z)))
		var current := gait_skeleton.get_bone_pose_rotation(bone_index)
		var blended := current.slerp(target_rotation, blend_weight).normalized()
		gait_skeleton.set_bone_pose_rotation(bone_index, blended)
		var blended_euler := blended.get_euler()
		_procedural_gait_angles[bone_name] = Vector3(
			rad_to_deg(blended_euler.x), rad_to_deg(blended_euler.y),
			rad_to_deg(blended_euler.z))


func get_procedural_gait_angle(bone_name: String) -> Vector3:
	return _procedural_gait_angles.get(bone_name, Vector3.ZERO)


func get_rig_bone_pose_angle(bone_name: String) -> Vector3:
	if gait_skeleton == null:
		return Vector3.ZERO
	var bone_index := gait_skeleton.find_bone(bone_name)
	if bone_index < 0:
		return Vector3.ZERO
	var euler := gait_skeleton.get_bone_pose_rotation(bone_index).get_euler()
	return Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z))


func _current_gait_phase() -> float:
	return fposmod(_cane_cycle_time / CANE_GAIT_CYCLE_SECONDS, 1.0)


func _update_hand_motion(stride_wave: float, is_walking: bool,
		delta: float) -> void:
	# Each complete hand is one connected mesh. Its one FingerCurl blend shape
	# deforms the three sculpted lobes together, so no digit can detach or float.
	var idle_curl := 0.08 + sin(_motion_elapsed * 1.65) * 0.025
	var speaking := is_speaking() or companion_state in [CompanionState.TALKING,
			CompanionState.ENCOURAGING, CompanionState.CELEBRATING]
	var weight := 1.0 - exp(-delta * 18.0)
	for hand in hand_meshes:
		var curl := idle_curl
		if is_walking:
			# Paw_R is the visible cane hand; it keeps a secure unified grip while
			# the free paw remains relaxed enough to counter-swing.
			curl = 0.78 + absf(stride_wave) * 0.08 \
				if hand.name == "Paw_R" else 0.18 + absf(stride_wave) * 0.05
		if speaking:
			curl = 0.62 + sin(_speech_elapsed * 10.0) * 0.16
		var shape_index: int = _hand_curl_shape_indices[hand]
		var current := hand.get_blend_shape_value(shape_index)
		hand.set_blend_shape_value(shape_index, lerpf(current, curl, weight))


func get_hand_curl_amounts() -> Dictionary:
	var result := {}
	for hand in hand_meshes:
		var shape_index: int = _hand_curl_shape_indices[hand]
		result[str(hand.name)] = hand.get_blend_shape_value(shape_index)
	return result


func _set_secondary_part_offset(parts: Array[Node3D], offset: Vector3,
		weight: float) -> void:
	for part in parts:
		var origin: Vector3 = _secondary_part_origins[part]
		part.position = part.position.lerp(origin + offset, weight)


func get_left_foot_motion_offset() -> Vector3:
	if left_foot_parts.is_empty():
		return Vector3.ZERO
	var part := left_foot_parts[0]
	return part.position - (_secondary_part_origins[part] as Vector3)


func get_secondary_motion_offset() -> Vector3:
	return model_root.position - _model_base_position if model_root != null \
		else Vector3.ZERO


func open_chatbot():
	if chatbot_ui != null:
		return

	_conversation_active = true
	chatbot_ui = load("res://scenes/chatbot.tscn").instantiate()
	get_tree().current_scene.add_child(chatbot_ui)
	print("Milo opened chat")

	chatbot_ui.user_input.grab_focus()
	chatbot_ui.connect("chat_closed", Callable(self, "close_chatbot"))
	chatbot_ui.connect("companion_pose_requested",
		Callable(self, "_on_companion_pose_requested"))
	chatbot_ui.connect("companion_speech_requested",
		Callable(self, "_on_companion_speech_requested"))
	chatbot_ui.connect("companion_activity_state_requested",
		Callable(self, "_on_companion_activity_state_requested"))
	_on_companion_pose_requested("welcome")
	chatbot_ui.call("replay_current_speech")

	_set_player_interaction_locked(true)
	_set_companion_state(CompanionState.TALKING)


func close_chatbot():
	if chatbot_ui != null:
		chatbot_ui.queue_free()
		chatbot_ui = null

	_set_player_interaction_locked(false)
	_conversation_active = false
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()
	_stop_speaking()
	_set_counsellor_prop("")
	_play_animation("Idle_3")
	# Return through the same clear transition instead of snapping the paws back
	# through the coat as the dialogue closes.
	_start_counsellor_arm_transition("neutral")
	_set_companion_state(CompanionState.IDLE_NEAR_PLAYER)


func _player_is_busy() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if "interacting" in player and bool(player.get("interacting")):
		return true
	if "input_enabled" in player and not bool(player.get("input_enabled")):
		return true
	return false


func _set_player_interaction_locked(locked: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	if "interacting" in player:
		player.set("interacting", locked)
	elif player.has_method("set_input_enabled"):
		player.call("set_input_enabled", not locked)
	elif "input_enabled" in player:
		player.set("input_enabled", not locked)


func _exit_tree() -> void:
	# Scene changes and parent removal can bypass the chatbot's Close signal.
	# Never carry Milo's movement lock into the surviving player/world.
	_cancel_counsellor_pose_transition()
	_conversation_active = false
	_stop_speaking()
	if chatbot_ui != null and is_instance_valid(chatbot_ui):
		chatbot_ui.queue_free()
		chatbot_ui = null
	_set_player_interaction_locked(false)


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


func _build_contact_shadow() -> void:
	# A soft local contact patch prevents Milo's broad shoes from appearing to
	# float when the level's directional shadow is faint or outside its atlas.
	contact_shadow = MeshInstance3D.new()
	contact_shadow.name = "MiloContactShadow"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.82, 0.48)
	contact_shadow.mesh = quad
	contact_shadow.position = Vector3(0.0, 0.026, 0.02)
	contact_shadow.rotation_degrees.x = -90.0
	contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadow_material := ShaderMaterial.new()
	var shadow_shader := Shader.new()
	shadow_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(1.0, 0.18, dot(p, p));
	ALBEDO = vec3(0.025, 0.035, 0.055);
	ALPHA = edge * 0.30;
}
"""
	shadow_material.shader = shadow_shader
	contact_shadow.material_override = shadow_material
	add_child(contact_shadow)

	# A second restrained patch sits under the authored cane tip. It shares the
	# same soft shader and follows Milo's root, appearing only while the cane is
	# visible so counsellor poses without the cane do not leave a stray dot.
	cane_contact_shadow = MeshInstance3D.new()
	cane_contact_shadow.name = "MiloCaneContactShadow"
	var cane_quad := QuadMesh.new()
	cane_quad.size = Vector2(0.17, 0.14)
	cane_contact_shadow.mesh = cane_quad
	cane_contact_shadow.position = Vector3(0.52, 0.027, 0.02)
	cane_contact_shadow.rotation_degrees.x = -90.0
	cane_contact_shadow.cast_shadow = \
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cane_contact_shadow.material_override = shadow_material
	add_child(cane_contact_shadow)


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
