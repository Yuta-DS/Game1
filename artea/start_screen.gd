extends Node2D

# This links your script to the new music node you just added
@onready var menu_music = $AudioStreamPlayer 

@onready var user_node = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/UsernameInput
@onready var pass_node = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/PasswordInput
	

func _on_button_pressed():
	print("START pressed")
	# 1. Grab the nodes

	# 2. Get the actual text
	var entered_user = user_node.text
	var entered_pass = pass_node.text
	
	if entered_user == "" or entered_pass == "":
		return

	# 3. Call the Global check
	print("Attempting login...")

	APIManager.login(
		entered_user,
		entered_pass,
		func(success, data):

			if success:

				print("LOGIN GRANTED")

				Global.current_user_name = entered_user

				enter_game(entered_user)

			else:

				print("LOGIN FAILED")

				print(data)
	)

func enter_game(username):
	# Save the name for the Hub World
	Global.current_user_name = username
	Global.auth_token = APIManager.auth_token
	
	# --- PROFESSIONAL MUSIC FADE ---
	# This creates a smooth transition instead of a sudden silence
	if menu_music:
		var tween = create_tween()
		tween.tween_property(menu_music, "volume_db", -80.0, 1.5)
		# Wait for the music to fade before changing scenes
		await tween.finished
	
	# Switch to the Hub World
	get_tree().change_scene_to_file("res://scenes/New_Hub_World.tscn")


func _on_register_button_pressed() -> void:
	print("REGISTER pressed")

	var entered_user = user_node.text.strip_edges()
	var entered_pass = pass_node.text

	if entered_user == "" or entered_pass == "":
		print("Missing username or password")
		return

	print("Attempting registration...")

	APIManager.register(
		entered_user,
		entered_pass,
		func(success, data):

			if success:

				print("REGISTER SUCCESS")

				# Auto-login after registration
				APIManager.login(
					entered_user,
					entered_pass,
					func(login_success, login_data):

						if login_success:

							print("AUTO LOGIN SUCCESS")

							Global.current_user_name = entered_user
							Global.auth_token = APIManager.auth_token

							enter_game(entered_user)

						else:

							print("AUTO LOGIN FAILED")
				)

			else:

				print("REGISTER FAILED")

				print(data)

				pass_node.text = ""

				# Optional future UI label
				# status_label.text = "Username already exists"
	)
