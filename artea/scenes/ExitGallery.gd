extends Area3D

const SceneLoader := preload("res://scripts/scene_loader.gd")

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
	_leave_gallery.call_deferred(path)


# The hub is the heaviest scene in the project (its ProtonScatter grass alone
# places tens of thousands of instances), so stepping out of the gallery goes
# through the loading screen rather than freezing on a synchronous swap -- the
# same route used walking in through the castle door.
func _leave_gallery(path: String) -> void:
	SceneLoader.change_scene_with_loading(get_tree(), path)
