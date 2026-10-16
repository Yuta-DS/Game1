# Keeps Wonderful Counsellor Milo beside whichever 3D player is active.
#
# The manager owns scene lifecycle only.  Milo's CharacterBody owns movement,
# animation and conversation.  Two-dimensional activities have no walkable
# player, so the manager deliberately leaves Milo unspawned there; the
# companion panel remains available through the activity UI instead.
extends Node

const MILO_SCENE := preload("res://milo2/godot/milo2_game_character.tscn")
const FALL_RESCUE_SCRIPT := preload("res://scripts/milo_fall_rescue.gd")
const ConversationContext := preload("res://scripts/MiloConversationContext.gd")
const ART_GALAXY_FALLBACK_SCALE := 1.40
# The fox GLB's static AABB includes extra animation space beyond its ordinary
# upright silhouette. This side-by-side calibrated ratio makes Milo and the
# fox equal in their standing gameplay pose while retaining dynamic sizing if
# either source asset changes later.
const ART_GALAXY_PERCEIVED_HEIGHT_CALIBRATION := 0.88

var active_milo: CharacterBody3D
var active_player: CharacterBody3D
var active_fall_rescue: Node
var conversation_context := ConversationContext.new()


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_attach_to_current_scene")


func _on_scene_changed() -> void:
	active_milo = null
	active_player = null
	active_fall_rescue = null
	call_deferred("_attach_to_current_scene")


func _attach_to_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	conversation_context.update_scene(scene.name, _journey_stage(),
		_journey_mode(), "exploring", false)
	_remove_legacy_milos(scene)
	var player := _find_3d_player(scene)
	if player == null:
		return
	var milo := _find_live_milo(scene)
	if milo == null:
		milo = MILO_SCENE.instantiate() as CharacterBody3D
		milo.name = "WonderfulCounsellorMilo"
		scene.add_child(milo)
	active_player = player
	active_milo = milo
	_apply_scene_scale(active_milo, scene)
	if active_milo.has_method("set_companion_player"):
		active_milo.call("set_companion_player", active_player, true)
	_attach_fall_rescue(scene)


func _attach_fall_rescue(scene: Node) -> void:
	var rescue := scene.get_node_or_null("MiloFallRescue")
	if rescue == null:
		rescue = FALL_RESCUE_SCRIPT.new()
		rescue.name = "MiloFallRescue"
		scene.add_child(rescue)
	rescue.call("set_player", active_player, active_milo)
	active_fall_rescue = rescue


func _apply_scene_scale(milo: CharacterBody3D, scene: Node) -> void:
	if milo == null:
		return
	var in_art_galaxy := scene.find_child("ArtCastleFloatingWorld", true, false) != null
	var target_scale := 1.0
	var fox_height := 0.0
	var milo_native_height := 0.0
	if in_art_galaxy:
		# Compare the rendered meshes, not the two collision capsules. The Galaxy
		# fox is authored at a different child scale, so a fixed Milo multiplier
		# only approximates the match and drifts whenever either asset changes.
		milo.scale = Vector3.ONE
		var fox_visual := _galaxy_fox_visual(active_player)
		var milo_visual := milo.get_node_or_null("Model") as Node3D
		fox_height = _visual_height(active_player, fox_visual)
		milo_native_height = _visual_height(milo, milo_visual)
		if fox_height > 0.001 and milo_native_height > 0.001:
			target_scale = fox_height / milo_native_height \
				* ART_GALAXY_PERCEIVED_HEIGHT_CALIBRATION
		else:
			target_scale = ART_GALAXY_FALLBACK_SCALE
	milo.scale = Vector3.ONE * target_scale
	milo.set_meta("scene_scale_profile",
		"art_galaxy_fox_perceived_height_match" if in_art_galaxy else "native_world_scale")
	milo.set_meta("scene_scale_multiplier", milo.scale.x)
	milo.set_meta("matched_fox_visual_height_m", fox_height)
	milo.set_meta("milo_native_visual_height_m", milo_native_height)
	milo.set_meta("fox_idle_pose_calibration", ART_GALAXY_PERCEIVED_HEIGHT_CALIBRATION)


func _galaxy_fox_visual(player: CharacterBody3D) -> Node3D:
	if player == null:
		return null
	var fox := player.get_node_or_null("FoxVisuals/Fox") as Node3D
	if fox != null:
		return fox
	return player.get_node_or_null("RogueSkin") as Node3D


func _visual_height(character: Node3D, visual_root: Node3D) -> float:
	if character == null or visual_root == null:
		return 0.0
	var combined := AABB()
	var has_bounds := false
	for node in visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var character_local := character.global_transform.affine_inverse() \
			* mesh_instance.global_transform
		var bounds := character_local * mesh_instance.get_aabb()
		combined = combined.merge(bounds) if has_bounds else bounds
		has_bounds = true
	return combined.size.y if has_bounds else 0.0


func _find_3d_player(scene: Node) -> CharacterBody3D:
	for group_name in [&"player", &"Player"]:
		for candidate in get_tree().get_nodes_in_group(group_name):
			if candidate is CharacterBody3D and scene.is_ancestor_of(candidate):
				return candidate as CharacterBody3D
	for node_name in [&"NewPlayer", &"Player3D"]:
		var candidate := scene.find_child(String(node_name), true, false)
		if candidate is CharacterBody3D:
			return candidate as CharacterBody3D
	return null


func _find_live_milo(scene: Node) -> CharacterBody3D:
	for candidate in get_tree().get_nodes_in_group("milo"):
		if candidate is CharacterBody3D and scene.is_ancestor_of(candidate) \
				and not candidate.is_queued_for_deletion() \
				and _is_final_milo(candidate):
			return candidate as CharacterBody3D
	return null


func _remove_legacy_milos(scene: Node) -> void:
	# Older levels may still contain an embedded generation-1 Milo. Remove that
	# runtime instance before resolving the companion so only Milo 2 can appear.
	for candidate in get_tree().get_nodes_in_group("milo"):
		if candidate is CharacterBody3D and scene.is_ancestor_of(candidate) \
				and not _is_final_milo(candidate):
			candidate.queue_free()


func _is_final_milo(candidate: Node) -> bool:
	return candidate.has_method("get_milo_generation") \
		and int(candidate.call("get_milo_generation")) == 2


func refresh_companion() -> void:
	_attach_to_current_scene()


func get_active_milo() -> CharacterBody3D:
	return active_milo if is_instance_valid(active_milo) else null


func request_fall_rescue(fallback := Vector3.INF) -> bool:
	if not is_instance_valid(active_fall_rescue):
		return false
	return bool(active_fall_rescue.call("rescue", fallback))


func get_conversation_context() -> MiloConversationContext:
	return conversation_context


func clear_conversation_memory() -> void:
	conversation_context.clear_session_memory()


func _journey_stage() -> int:
	var journey := get_node_or_null("/root/JourneyState")
	return int(journey.get("stage")) if journey != null else 0


func _journey_mode() -> String:
	var journey := get_node_or_null("/root/JourneyState")
	return str(journey.get("audience_mode")) if journey != null else "faith"
