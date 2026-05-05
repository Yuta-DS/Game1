extends Node2D

func _on_button_pressed() -> void:
	# 1. Grab the text from the UI box
	# Note: If your node is named 'LineEdit' instead of 'TextEdit', change it here
	var entered_name = $TextEdit.text
	
	# 2. Save to the existing Global variable
	if entered_name != "":
		Global.current_user_name = entered_name
	else:
		Global.current_user_name = "Seeker" # Fallback
	
	# 3. Change scenes
	get_tree().change_scene_to_file("res://scenes/New_Hub_World.tscn")
