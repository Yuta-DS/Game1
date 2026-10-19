# ExitGallery.gd
extends Area3D
const SceneLoader := preload("res://scripts/scene_loader.gd")

# The hub lives in res://scenes/. The old res://New_Hub_World.tscn does not
# exist, so go_to_scene() took the "target scene not found" branch below and
# the doorway silently did nothing — the same failure ExitGallery.gd had.
@export var target_scene_path: String = "res://scenes/New_Hub_World.tscn"

# This function is automatically called when a physics body enters the Area3D
func _on_body_entered(body: Node3D):
	# Check if the body that entered is the player (assuming your player is a CharacterBody3D)
	if body is CharacterBody3D: 
		
		# Call the dedicated function to perform the scene switch
		go_to_scene(target_scene_path)
	# Note: If your player's script has a unique name (e.g., "PlayerController"), 
	# you can use 'if body.get_script() is PlayerController:' for a more precise check.

# Scene switching function
func go_to_scene(path: String):
	if ResourceLoader.exists(path):
		if path == target_scene_path:
			var global := get_node_or_null("/root/Global")
			if global != null and global.has_method("request_spawn_at"):
				global.request_spawn_at("castle_front_door")
		print("TRAVELING from:", self.name, " to: ", path)
		SceneLoader.change_scene(get_tree(), path)
	else:
		print("ERROR: Target scene not found at:", path)
