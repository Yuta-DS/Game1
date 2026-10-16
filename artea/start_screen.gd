extends Node2D
const SceneLoader := preload("res://scripts/scene_loader.gd")

const WORLD_ONE_SCENE := "res://scenes/art_gallery_3d_inprogress.tscn"

# Links to the intro music audio player node
@onready var menu_music = $AudioStreamPlayer 

# Grab the UI Input Fields
@onready var user_node = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/UsernameInput
@onready var pass_node = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/PasswordInput

# Dynamic visual feedback label for formatting error reporting
@onready var status_label = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var background: Sprite2D = $Background
@onready var form_host: CenterContainer = $AnimationParent/CenterContainer
@onready var form: VBoxContainer = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer
@onready var guest_button: Button = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/GuestButton

func _ready():
	# Clean out any old error text when the start scene boots up
	status_label.text = ""
	# Keyboard users can advance through the form without reaching for the
	# pointer. Do not grab focus automatically because that would open the soft
	# keyboard over the artwork on phones before the player asks for it.
	user_node.text_submitted.connect(func(_value: String): pass_node.grab_focus())
	pass_node.text_submitted.connect(func(_value: String): _on_button_pressed())
	_layout_for_viewport(get_viewport().get_visible_rect().size)
	get_viewport().size_changed.connect(func():
		_layout_for_viewport(get_viewport().get_visible_rect().size))


func _input(event: InputEvent) -> void:
	# Keep the phone artwork free of an unsolicited software keyboard, while
	# still giving a controller-only player a usable first action. Godot sends
	# _input before Control._gui_input, so the same D-pad/stick event that creates
	# focus is consumed once; later events follow the normal GUI navigation path.
	if _is_gamepad_navigation(event) and _focus_gamepad_entry_if_needed():
		get_viewport().set_input_as_handled()


func _is_gamepad_navigation(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return event.pressed and event.button_index in [
			JOY_BUTTON_A,
			JOY_BUTTON_DPAD_UP,
			JOY_BUTTON_DPAD_DOWN,
			JOY_BUTTON_DPAD_LEFT,
			JOY_BUTTON_DPAD_RIGHT,
		]
	if event is InputEventJoypadMotion:
		return event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] \
			and absf(event.axis_value) >= 0.55
	return false


func _focus_gamepad_entry_if_needed() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and form.is_ancestor_of(focus_owner):
		return false
	guest_button.grab_focus()
	set_meta("start_screen_gamepad_ready", true)
	return true


func _layout_for_viewport(viewport_size: Vector2,
		physical_size: Vector2 = Vector2.ZERO) -> void:
	## Keep the illustrated entry screen and authentication controls usable in
	## real CSS pixels. With canvas_items, a 390×844 phone exposes roughly
	## 1710×3700 logical pixels; fixed authored offsets therefore used only the
	## top quarter and shrank the form below fingertip size.
	if viewport_size.x < 1.0 or viewport_size.y < 1.0:
		return
	if physical_size.is_zero_approx():
		physical_size = _start_physical_size(viewport_size)
	if physical_size.x < 240.0 or physical_size.y < 240.0:
		physical_size = viewport_size
	var ui_scale := _start_interface_scale(viewport_size, physical_size)
	var physical_width := viewport_size.x / ui_scale
	var physical_height := viewport_size.y / ui_scale
	var portrait := physical_height > physical_width * 1.15

	# Cover the complete viewport rather than preserving the old 1710×1112
	# rectangle and leaving a large blank area below it. Sprite2D uses its texture
	# centre as the focal point, retaining the mascot on narrow crops.
	if background != null and background.texture != null:
		var texture_size := Vector2(background.texture.get_size())
		var cover := maxf(viewport_size.x / texture_size.x,
			viewport_size.y / texture_size.y)
		background.position = viewport_size * 0.5
		background.scale = Vector2.ONE * cover

	# PanelContainer contributes 25 px on each side. Reserve those margins here
	# so the complete panel, rather than only its VBox, fits a 320–390 px phone.
	var form_width_px := clampf(physical_width - 82.0, 250.0, 360.0) if portrait \
		else clampf(physical_width * 0.30, 360.0, 460.0)
	form.custom_minimum_size = Vector2(form_width_px, 0.0)
	form.add_theme_constant_override("separation", 9)
	(form.get_node("Username") as Label).add_theme_font_size_override(
		"font_size", 24 if portrait else 26)
	for input_name in ["UsernameInput", "PasswordInput"]:
		var input := form.get_node(input_name) as LineEdit
		input.custom_minimum_size.y = 50.0
		input.add_theme_font_size_override("font_size", 22 if portrait else 24)
	for button_name in ["Button", "RegisterButton", "GuestButton"]:
		var button := form.get_node(button_name) as Button
		button.custom_minimum_size.y = 50.0
		button.add_theme_font_size_override("font_size", 22 if portrait else 24)
	status_label.add_theme_font_size_override("font_size", 16 if portrait else 18)

	# The host and all its children remain authored in physical-pixel units, then
	# this single scale maps them into the expanded logical canvas.
	form_host.scale = Vector2.ONE * ui_scale
	form_host.reset_size()
	var base_size := form_host.get_combined_minimum_size()
	form_host.size = base_size
	var physical_form_size := base_size
	var physical_position := Vector2.ZERO
	if portrait:
		physical_position.x = (physical_width - physical_form_size.x) * 0.5
		physical_position.y = maxf(20.0,
			physical_height - physical_form_size.y - 28.0)
	else:
		physical_position.x = clampf(physical_width * 0.055, 36.0, 76.0)
		physical_position.y = clampf(
			(physical_height - physical_form_size.y) * 0.58,
			24.0, physical_height - physical_form_size.y - 24.0)
	form_host.position = physical_position * ui_scale
	set_meta("start_screen_layout", "physical_viewport_v1")
	set_meta("start_screen_ui_scale", ui_scale)
	set_meta("start_screen_physical_size", physical_size)
	set_meta("start_screen_portrait", portrait)


func _start_physical_size(viewport_size: Vector2) -> Vector2:
	var display_size := Vector2(DisplayServer.window_get_size())
	var css_size := Vector2.ZERO
	if OS.has_feature("web"):
		var encoded := str(JavaScriptBridge.eval(
			"JSON.stringify([window.innerWidth || 0, window.innerHeight || 0])", true))
		if encoded.begins_with("["):
			var decoded: Variant = JSON.parse_string(encoded)
			if decoded is Array and decoded.size() >= 2:
				css_size = Vector2(float(decoded[0]), float(decoded[1]))
	return _select_start_physical_size(viewport_size, display_size, css_size)


func _select_start_physical_size(viewport_size: Vector2, display_size: Vector2,
		css_size: Vector2 = Vector2.ZERO) -> Vector2:
	if css_size.x >= 240.0 and css_size.y >= 240.0:
		return css_size
	if display_size.x >= 240.0 and display_size.y >= 240.0:
		return display_size
	return viewport_size


func _start_interface_scale(viewport_size: Vector2,
		physical_size: Vector2) -> float:
	if physical_size.x <= 0.0 or physical_size.y <= 0.0:
		return 1.0
	return maxf(1.0, maxf(viewport_size.x / physical_size.x,
		viewport_size.y / physical_size.y))

# Helper utility to cleanly control status messages and alert color states
func show_message(text: String, is_error: bool = true):
	status_label.text = text
	if is_error:
		status_label.add_theme_color_override("font_color", Color.RED)
	else:
		status_label.add_theme_color_override("font_color", Color.GREEN)

# Connected to the 'Login' Button's pressed() signal
func _on_button_pressed():
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
				show_message("Login granted! Loading...", false)
				enter_game(entered_user, false)
			else:
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
				pass_node.text = ""
				show_message("Username already exists!")
	)

# Connected to your physical 'GuestButton' (Play Offline as Guest)
func _on_guest_button_pressed() -> void:
	print("GUEST access selected")
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
		Global.auth_token = Global.OFFLINE_GUEST_TOKEN
	else:
		Global.current_user_name = username
		Global.auth_token = APIManager.auth_token
	
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
	var destination := "res://scenes/New_Hub_World.tscn"
	if is_guest and OS.has_feature("web"):
		# The opt-in browser probes need to exercise the actual World One entry
		# without relying on a long mouse route through the hub.
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		if "world_one_story=1" in query or "world_one_quality=1" in query:
			destination = "res://scenes/art_gallery_3d_inprogress.tscn"
	SceneLoader.change_scene_with_loading(get_tree(), destination)
