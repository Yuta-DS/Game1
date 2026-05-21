extends Node2D

# This links your script to the new music node you just added
@onready var menu_music = $AudioStreamPlayer 

func _on_button_pressed():
	# 1. Grab the nodes
	var user_node = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/UsernameInput
	var pass_node = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/PasswordInput
	
	# 2. Get the actual text
	var entered_user = user_node.text
	var entered_pass = pass_node.text
	
	if entered_user == "" or entered_pass == "":
		return

	# 3. Call the Global check
	var status = UserStorage.login_user(entered_user, entered_pass)
	
	# 4. Handle the result
	if status == "SUCCESS":
		print("LOGIN GRANTED")
		enter_game(entered_user)
		
	elif status == "WRONG_PASSWORD":
		print("LOGIN DENIED: WRONG PASSWORD")
		pass_node.text = "" # Clear the box for a retry
		# We stay on the screen because we don't call enter_game()
		
	elif status == "USER_NOT_FOUND":
		# Automatically register new users for the demo
		UserStorage.register_user(entered_user, entered_pass)
		print("New account registered for: ", entered_user)
		enter_game(entered_user)

func enter_game(username):
	# Save the name for the Hub World
	Global.current_user_name = username
	
	# --- PROFESSIONAL MUSIC FADE ---
	# This creates a smooth transition instead of a sudden silence
	if menu_music:
		var tween = create_tween()
		tween.tween_property(menu_music, "volume_db", -80.0, 1.5)
		# Wait for the music to fade before changing scenes
		await tween.finished
	
	# Switch to the Hub World
	get_tree().change_scene_to_file("res://scenes/New_Hub_World.tscn")
