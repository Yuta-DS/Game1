extends Area3D

# --- Configuration ---
@export var target_scene_path: String = "res://scenes/New_Hub_World.tscn"

# --- Signal Handler ---

# This function must be connected to the 'body_entered' signal of the Area3D node(s).
func _on_body_entered(body: Node3D):
	# Check if the body that entered is the player (a CharacterBody3D)
	if body is CharacterBody3D:
		go_to_scene(target_scene_path)
		
# --- Core Scene Switching Logic ---

func go_to_scene(path: String):
	if ResourceLoader.exists(path):
		print("TRAVELING from:", self.name, " to: ", path)
		get_tree().change_scene_to_file(path)
	else:
		print("ERROR: Target scene file not found at path:", path)
