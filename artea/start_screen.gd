extends Node2D

func _on_button_pressed():
	# 1. Grab the text using the NEW path through your containers
	var entered_name = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/LineEdit.text
	
	# 2. Save to the existing Global variable
	if entered_name != "":
		Global.current_user_name = entered_name
	else:
		# Fallback to 'Seeker' for that mythical feel Louisa liked
		Global.current_user_name = "Seeker"
	
	# 3. Change scenes to the Hub World
	get_tree().change_scene_to_file("res://scenes/New_Hub_World.tscn")
