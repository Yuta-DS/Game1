# Keeps Wonderful Counsellor Milo beside whichever 3D player is active.
#
# The manager owns scene lifecycle only.  Milo's CharacterBody owns movement,
# animation and conversation.  Two-dimensional activities have no walkable
# player, so the manager deliberately leaves Milo unspawned there; the
# companion panel remains available through the activity UI instead.
#
# Alongside Milo it adds a MiloFallRescue node (milo_fall_rescue.gd), so Milo
# catches the player whenever they fall off the world.
extends Node

const MILO_SCENE := preload("res://scenes/milo_animations.tscn")
const FALL_RESCUE_SCRIPT := preload("res://scripts/milo_fall_rescue.gd")

var active_milo: CharacterBody3D
var active_player: CharacterBody3D
var active_fall_rescue: Node


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
	# Authored chapter guides own their interactions and checkpoint recovery.
	# All other scenes retain main's companion and flying fall-rescue system.
	if scene.get_meta("owns_companion_guidance", false):
		active_milo = null
		active_player = null
		active_fall_rescue = null
		return
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
	_attach_fall_rescue(scene)


func _attach_fall_rescue(scene: Node) -> void:
	var rescue := scene.get_node_or_null("MiloFallRescue")
	if rescue == null:
		rescue = FALL_RESCUE_SCRIPT.new()
		rescue.name = "MiloFallRescue"
		scene.add_child(rescue)
	rescue.call("set_player", active_player, active_milo)
	active_fall_rescue = rescue


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
				and candidate.has_method("set_companion_player"):
			return candidate as CharacterBody3D
	return null


func refresh_companion() -> void:
	_attach_to_current_scene()


func get_active_milo() -> CharacterBody3D:
	return active_milo if is_instance_valid(active_milo) else null


# For scenes with their own void check: Milo carries the player back to the
# last safe ground they stood on, or to `fallback` if there is none. Returns
# false when no rescue is possible, so the caller should respawn as before.
func request_fall_rescue(fallback := Vector3.INF) -> bool:
	if not is_instance_valid(active_fall_rescue):
		return false
	return bool(active_fall_rescue.call("rescue", fallback))
