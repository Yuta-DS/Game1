# Keeps Wonderful Counsellor Milo beside whichever 3D player is active.
#
# The manager owns scene lifecycle only.  Milo's CharacterBody owns movement,
# animation and conversation.  Two-dimensional activities have no walkable
# player, so the manager deliberately leaves Milo unspawned there; the
# companion panel remains available through the activity UI instead.
extends Node

const MILO_SCENE := preload("res://milo2/godot/milo2_game_character.tscn")

var active_milo: CharacterBody3D
var active_player: CharacterBody3D


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_attach_to_current_scene")


func _on_scene_changed() -> void:
	active_milo = null
	active_player = null
	call_deferred("_attach_to_current_scene")


func _attach_to_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
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
	if active_milo.has_method("set_companion_player"):
		active_milo.call("set_companion_player", active_player, true)


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
