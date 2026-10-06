extends Node2D

# Links to the intro music audio player node
@onready var menu_music = $AudioStreamPlayer 

# Grab the UI Input Fields
@onready var user_node = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/UsernameInput
@onready var pass_node = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/PasswordInput

# Dynamic visual feedback label for formatting error reporting
@onready var status_label = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/StatusLabel

func _ready():
	# Clean out any old error text when the start scene boots up
	status_label.text = ""
	# Release Web templates reject scene paths in engine startup arguments.
	# The local preview adapter requests a normal runtime scene transition.
	var heart_preview := "--heart-preview" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		heart_preview = heart_preview or JavaScriptBridge.eval("window.ARTEA_HEART_PREVIEW === true", true) == true
	if heart_preview:
		print("HEART PREVIEW REQUEST ACCEPTED")
		if OS.has_feature("web"): JavaScriptBridge.eval("window.ARTEA_HEART_PREVIEW = false", true)
		_open_heart_preview.call_deferred()

func _open_heart_preview() -> void:
	Global.current_user_name = "Guest_Player"
	Global.auth_token = "OFFLINE_GUEST_TOKEN"
	var result := get_tree().change_scene_to_file("res://scenes/heart_melody/heart_melody_world.tscn")
	if result != OK:
		show_message("The garden could not open. Please reload and try again.")

# Helper utility to cleanly control status messages and alert color states
func show_message(text: String, is_error: bool = true):
	status_label.text = text
	if is_error:
		status_label.add_theme_color_override("font_color", Color.RED)
	else:
		status_label.add_theme_color_override("font_color", Color.GREEN)

# Connected to the 'Login' Button's pressed() signal
func _on_button_pressed():
	print("START pressed")
	
	# 1. Check network connectivity status
	if not check_internet_connection():
		show_message("No internet connection! Use Guest Mode.")
		return

	# 2. Extract and strip text field bounds
	var entered_user = user_node.text.strip_edges()
	var entered_pass = pass_node.text
	
	if entered_user == "" or entered_pass == "":
		show_message("Username/Password cannot be empty!")
		return

	show_message("Attempting login...", false)

	# 3. Route credentials to APIManager
	APIManager.login(
		entered_user,
		entered_pass,
		func(success, data):
			if success:
				print("LOGIN GRANTED")
				show_message("Login granted! Loading...", false)
				enter_game(entered_user, false)
			else:
				print("LOGIN FAILED")
				print("Backend response data type: ", typeof(data))
				print("Backend response data content: ", data)
				
				# SAFE INTERCEPT TYPE A: Server returned a data Dictionary (Rafa's API)
				if typeof(data) == TYPE_DICTIONARY:
					if data.has("error"):
						var error_msg = data["error"].to_upper()
						if "PASSWORD" in error_msg or "INVALID" in error_msg:
							show_message("Invalid credentials!")
						elif "FOUND" in error_msg or "EXIST" in error_msg:
							show_message("Account does not exist!")
						else:
							show_message("Login failed: " + str(data["error"]))
					else:
						show_message("Invalid credentials!")
						
				# SAFE INTERCEPT TYPE B: Mock fallback string (Local UserStorage)
				elif typeof(data) == TYPE_STRING:
					if data == "USER_NOT_FOUND":
						show_message("Account does not exist!")
					elif data == "WRONG_PASSWORD":
						show_message("Invalid credentials!")
					else:
						show_message("Login failed! Try again.")
				else:
					show_message("Invalid credentials!")
	)

# Connected to the 'Register' Button's pressed() signal
func _on_register_button_pressed() -> void:
	print("REGISTER pressed")
	
	if not check_internet_connection():
		show_message("No internet connection to register!")
		return

	var entered_user = user_node.text.strip_edges()
	var entered_pass = pass_node.text

	if entered_user == "" or entered_pass == "":
		show_message("Fields cannot be empty!")
		return

	show_message("Registering account...", false)

	APIManager.register(
		entered_user,
		entered_pass,
		func(success, data):
			if success:
				print("REGISTER SUCCESS")
				show_message("Account created! Auto-logging in...", false)
				
				# Trigger auto-login loop so the player bypasses double entry
				APIManager.login(
					entered_user,
					entered_pass,
					func(login_success, login_data):
						if login_success:
							enter_game(entered_user, false)
						else:
							show_message("Auto-login failed. Try logging in manually.")
				)
			else:
				print("REGISTER FAILED")
				print("Backend response data type: ", typeof(data))
				print("Backend response data content: ", data)
				pass_node.text = ""

				# This used to unconditionally say "Username already exists!"
				# regardless of what actually went wrong - including a plain
				# connection failure (data is null, not a real server error),
				# which made an unreachable backend indistinguishable from a
				# real duplicate account.
				if typeof(data) == TYPE_DICTIONARY and data.has("error"):
					var error_msg = str(data["error"]).to_upper()
					if "EXIST" in error_msg:
						show_message("Username already exists!")
					elif "MISSING" in error_msg:
						show_message("Fields cannot be empty!")
					else:
						show_message("Registration failed: " + str(data["error"]))
				else:
					show_message("Could not reach the server. Check your connection and try again.")
	)

# Connected to your physical 'GuestButton' (Play Offline as Guest)
func _on_guest_button_pressed() -> void:
	print("GUEST access selected - Cleaning input boxes completely")
	
	# FORCE WIPE FIELDS: This guarantees the text fields are blanked out 
	# before the engine moves scenes, cutting any accidental link to input tracking.
	user_node.text = ""
	pass_node.text = ""
	
	show_message("Entering as Guest (Offline Mode)...", false)
	
	# Pass 'true' as the second parameter to signal a hard offline guest load
	enter_game("Guest_Player", true)

# Checks for a usable non-loopback network address.
# IP.get_local_addresses() always returns at least the loopback entries
# (127.0.0.1 / ::1), so a non-empty list does not mean the machine is online.
# Loopback is still accepted when the API itself is on localhost, which is the
# case for a local development server.
func check_internet_connection() -> bool:
	if APIManager.BASE_URL.contains("127.0.0.1") or APIManager.BASE_URL.contains("localhost"):
		return true

	for address in IP.get_local_addresses():
		if address.begins_with("127.") or address == "::1":
			continue
		# Link-local addresses mean no usable route (APIPA / self-assigned).
		if address.begins_with("169.254.") or address.to_lower().begins_with("fe80"):
			continue
		return true

	return false

# Handles variable registration tracking, audio attenuation, and scene execution
func enter_game(username: String, is_guest: bool = false):
	# Direct assignment block to separate your tracks completely
	if is_guest:
		Global.current_user_name = "Guest_Player"
		Global.auth_token = "OFFLINE_GUEST_TOKEN"
		print("SESSION LOCKED: API Database completely bypassed.")
	else:
		Global.current_user_name = username
		Global.auth_token = APIManager.auth_token
		print("SESSION LOCKED: Connected to live API Server for user: ", username)
	
	# Fade the menu music out, but do not wait on it.
	#
	# This previously did `await tween.finished`. A tween only advances while its
	# node is processing, and on the web browsers suspend audio until a user
	# gesture, so the fade could never complete and the await stayed pending
	# forever - leaving the screen on "Entering as Guest (Offline Mode)..." with
	# no error, because the scene change below was never reached. The fade is
	# polish; changing scene is what this button is for.
	if menu_music:
		var tween := create_tween()
		tween.tween_property(menu_music, "volume_db", -80.0, 1.5)

	# Open up the master integrated sandbox environment through the loading
	# screen rather than a direct change_scene_to_file. A direct swap dropped
	# the player straight into a bare hub that then visibly populated with
	# tens of thousands of grass instances over the next few seconds -
	# ProtonScatter builds them on a background thread, which keeps the game
	# from freezing but does nothing to hide the pop-in. The loading screen
	# now waits on that thread too (see loading_scene.gd), not just the scene
	# resource itself.
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/New_Hub_World.tscn"
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free()
