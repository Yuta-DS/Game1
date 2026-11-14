extends Area3D

# --- Configuration ---
@export var target_scene_path: String = "res://scenes/New_Hub_World.tscn"

# Where the player should appear in the target scene. The hub reads this
# through Global and places the player at the matching arrival marker, so
# stepping out of the Art Castle puts them on its own doorstep instead of at
# the hub's authored default start point on the far side of the map.
@export var arrival_spawn_point: String = "castle_front_door"

var _travelling := false

# --- Signal Handler ---

# This function must be connected to the 'body_entered' signal of the Area3D node(s).
func _on_body_entered(body: Node3D):
	# Check if the body that entered is the player (a CharacterBody3D)
	if body is CharacterBody3D:
		go_to_scene(target_scene_path)

# --- Core Scene Switching Logic ---

func go_to_scene(path: String):
	# body_entered can fire twice within one frame and the swap is deferred,
	# so without this guard the scene change is queued more than once.
	if _travelling:
		return

	if not ResourceLoader.exists(path):
		push_error("ExitGallery: target scene not found at path: %s" % path)
		return

	_travelling = true
	if arrival_spawn_point != "":
		Global.request_spawn_at(arrival_spawn_point)

	# Changing the scene from inside a physics callback frees this Area3D while
	# the physics server is still iterating it. Deferring runs the swap once
	# that callback has unwound.
	get_tree().change_scene_to_file.call_deferred(path)
