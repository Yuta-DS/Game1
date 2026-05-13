extends Node2D

func _on_button_pressed():
	# 1. Grab the nodes
	var user_node = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/UsernameInput
	var pass_node = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/PasswordInput
	
	# 2. Get the actual text
	var entered_user = user_node.text
	var entered_pass = pass_node.text
	
	print("Attempting login for: ", entered_user)

	# 3. Call the Global check
	var status = UserStorage.login_user(entered_user, entered_pass)
	
	# 4. THE ONLY WAY IN IS SUCCESS
	if status == "SUCCESS":
		print("LOGIN GRANTED")
		enter_game(entered_user)
	elif status == "WRONG_PASSWORD":
		print("LOGIN DENIED: WRONG PASSWORD")
		pass_node.text = "" # Wipes the password box
	elif status == "USER_NOT_FOUND":
		print("LOGIN DENIED: USER DOES NOT EXIST")
		# For now, we block everyone to test the security
		# UserStorage.register_user(entered_user, entered_pass)
	else:
		print("UNKNOWN ERROR")

func enter_game(username):
	Global.current_user_name = username
	get_tree().change_scene_to_file("res://scenes/New_Hub_World.tscn")
