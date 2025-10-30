# ExitGallery.gd
extends Area3D

# --- CHANGE THIS PATH ---
@export var target_scene_path: String = "res://New_Hub_World.tscn"

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
		print("TRAVELING from:", self.name, " to: ", path)
		get_tree().change_scene_to_file(path)
	else:
		print("ERROR: Target scene not found at:", path)
