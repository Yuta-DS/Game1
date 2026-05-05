extends Node2D

func _on_button_pressed():
	# 1. Grab the text from the new LineEdit node
	var entered_name = $LineEdit.text
	
	# 2. Save to the existing Global variable
	if entered_name != "":
		Global.current_user_name = entered_name
	else:
		# Using 'Seeker' as a fallback ensures the bubble always has a name
		Global.current_user_name = "Seeker"
	
	# 3. Change scenes to the Hub World
	get_tree().change_scene_to_file("res://scenes/New_Hub_World.tscn")
