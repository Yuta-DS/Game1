extends Node2D
const SceneLoader := preload("res://scripts/scene_loader.gd")

const AdminResetPanel := preload("res://scripts/admin_reset_panel.gd")
const ForgotPasswordPanel := preload("res://scripts/forgot_password_panel.gd")
const RecoveryCodeModal := preload("res://scripts/recovery_code_modal.gd")

# Links to the intro music audio player node
@onready var menu_music = $AudioStreamPlayer

# Grab the UI Input Fields
@onready var user_node = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/UsernameInput
@onready var pass_node = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/PasswordInput

# The options box the real login/register/guest buttons already live in -
# the forgot-password button joins them here instead of floating separately,
# so it rides the same panel and animation.
@onready var options_box = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer

# Dynamic visual feedback label for formatting error reporting
@onready var status_label = $AnimationParent/CenterContainer/PanelContainer/VBoxContainer/StatusLabel

var _admin_panel: Node
var _forgot_password_panel: Node
var _code_modal: Node

func _ready():
	print("Account screen initializing")
	# Clean out any old error text when the start scene boots up
	status_label.text = ""
	if APIManager.uses_managed_accounts():
		var recovery := Button.new()
		recovery.text = "Verify account / reset password"
		recovery.pressed.connect(_managed_recovery)
		user_node.get_parent().add_child(recovery)
	print("Account screen initialized")
	# Built here rather than added to the .tscn - runtime-built UI is this
	# project's house style for anything that isn't the primary scene content
	# (see facilitator_settings.gd), and keeps a support tool out of the
	# scene diff entirely.
	_admin_panel = AdminResetPanel.new()
	add_child(_admin_panel)
	_build_admin_button()

	_forgot_password_panel = ForgotPasswordPanel.new()
	add_child(_forgot_password_panel)

	_code_modal = RecoveryCodeModal.new()
	add_child(_code_modal)
	_build_forgot_password_button()
	# The background is authored for the 1710x1112 base size; stretch "expand"
	# widens the view on 16:9 screens, which left a bare strip at the edge.
	get_viewport().size_changed.connect(_fit_background)
	_fit_background()
	# Download, without mounting, the first playable area's packs while the
	# player is signing in. Later worlds retain the existing in-game prefetch.
	if OS.has_feature("web"):
		_prefetch_hub.call_deferred()
	# Release Web templates reject scene paths in engine startup arguments.
	# The local preview adapter requests a normal runtime scene transition.
	var heart_preview := "--heart-preview" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		heart_preview = heart_preview or JavaScriptBridge.eval("window.ARTEA_HEART_PREVIEW === true", true) == true
	if heart_preview:
		print("HEART PREVIEW REQUEST ACCEPTED")
		if OS.has_feature("web"): JavaScriptBridge.eval("window.ARTEA_HEART_PREVIEW = false", true)
		_open_heart_preview.call_deferred()

# Scales the background to cover the whole visible area, like CSS
# background-size: cover, so there is never an empty strip at any aspect.
func _fit_background() -> void:
	var background := $Background as Sprite2D
	var view := get_viewport_rect().size
	var tex := background.texture.get_size()
	background.position = view * 0.5
	background.scale = Vector2.ONE * maxf(view.x / tex.x, view.y / tex.y)


func _prefetch_hub() -> void:
	var hub_files := SceneLoader.packs_needed("res://scenes/New_Hub_World.tscn")
	if hub_files.is_empty():
		return
	var browser := JavaScriptBridge.get_interface("window")
	var connection = browser.navigator.connection
	if connection != null and bool(connection.saveData):
		return
	if browser.arteaPacks != null:
		var files = JavaScriptBridge.get_interface("JSON").parse(JSON.stringify(hub_files))
		browser.arteaPacks.startPrefetch(files)


func _open_heart_preview() -> void:
	Global.current_user_name = "Guest_Player"
	Global.auth_token = "OFFLINE_GUEST_TOKEN"
	var opened := SceneLoader.change_scene(get_tree(), "res://scenes/heart_melody/heart_melody_world.tscn")
	if not opened:
		show_message("The garden could not open. Please reload and try again.")


# Small and tucked in a corner on purpose - this is a support tool for
# whoever holds the server's admin key, not a player-facing feature.
#
# Top-right rather than top-left: the always-on FPS counter (fps_counter.gd)
# sits at (16, 16) on its own CanvasLayer above everything, which otherwise
# covers this button entirely.
func _build_admin_button() -> void:
	# A Control's anchors resolve against the viewport only when its parent
	# is not itself a CanvasItem - StartScreen is a Node2D, which is one, so
	# anchoring the button straight onto it resolves against the wrong rect
	# and the button ends up off-screen. Every other overlay in this project
	# (facilitator_settings.gd, JourneySafeguards, admin_reset_panel.gd)
	# avoids this by wrapping in its own CanvasLayer first; this needs the
	# same fix.
	var layer := CanvasLayer.new()
	layer.layer = 14
	add_child(layer)

	var button := Button.new()
	button.text = "Admin"
	button.custom_minimum_size = Vector2(90, 30)
	button.add_theme_font_size_override("font_size", 14)
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# PRESET_TOP_RIGHT anchors the corner at the right edge, so x must be
	# negative to pull the button back onto the screen.
	button.position = Vector2(-102, 12)
	button.pressed.connect(_admin_panel.show_panel)
	layer.add_child(button)


# Joins the real login panel rather than floating separately, since this is
# a normal part of the login flow, not a support tool like the Admin button.
func _build_forgot_password_button() -> void:
	var button := Button.new()
	button.text = "Forgot password?"
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(_forgot_password_panel.show_panel)
	options_box.add_child(button)

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

	if APIManager.uses_managed_accounts():
		_managed_register(entered_user, entered_pass)
		return
	show_message("Registering account...", false)

	APIManager.register(
		entered_user,
		entered_pass,
		func(success, data):
			if success:
				print("REGISTER SUCCESS")
				show_message("Account created!", false)

				var do_auto_login := func():
					show_message("Logging in...", false)
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

				# The recovery code is only ever shown this once - the modal
				# blocks auto-login until the player acknowledges it, so the
				# scene change below can't carry it away unseen.
				var recovery_code := ""
				if typeof(data) == TYPE_DICTIONARY:
					recovery_code = str(data.get("recovery_code", ""))

				if recovery_code != "":
					_code_modal.show_code(recovery_code, do_auto_login)
				else:
					do_auto_login.call()
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
	print("Guest button selected")
	APIManager.clear_session()
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
	# Browser network interfaces are unavailable; let HTTP report connectivity.
	if OS.has_feature("web"): return true
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
	SceneLoader.change_scene_with_loading(get_tree(), "res://scenes/New_Hub_World.tscn")


# Account setup stays outside gameplay. Cognito sends codes to the verified
# email; credentials and refresh tokens are never written to browser storage.
func _account_form(title_text: String, labels: Array, submit: Callable) -> Window:
	var dialog := Window.new()
	dialog.title = title_text
	dialog.size = Vector2i(500, 340)
	dialog.transient = true
	dialog.exclusive = true
	add_child(dialog)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
	dialog.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var fields: Array[LineEdit] = []
	for caption in labels:
		var label := Label.new()
		label.text = str(caption)
		column.add_child(label)
		var field := LineEdit.new()
		field.secret = "password" in str(caption).to_lower()
		field.custom_minimum_size.y = 42
		column.add_child(field)
		fields.append(field)
	var message := Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	var button := Button.new()
	button.text = "Continue"
	button.custom_minimum_size.y = 44
	column.add_child(button)
	button.pressed.connect(func():
		var values: Array[String] = []
		for field in fields: values.append(field.text)
		message.text = "Please wait..."
		button.disabled = true
		submit.call(values, func(ok: bool, text: String):
			if not is_instance_valid(dialog): return
			if ok:
				dialog.exclusive = false
				dialog.hide()
				dialog.queue_free()
			else:
				message.text = text
				button.disabled = false
		)
	)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()
	fields[0].grab_focus()
	return dialog

func _managed_register(username: String, password: String) -> void:
	_account_form("Create your account", ["Email for account verification and recovery"], func(values, done):
		APIManager.register(username, password, func(ok, data):
			done.call(ok, str(data.get("error", "Could not create account.")))
			if ok: _managed_confirm(username)
		, values[0].strip_edges())
	)

func _managed_confirm(username: String) -> void:
	_account_form("Verify your email", ["Verification code from your email"], func(values, done):
		APIManager.confirm_account(username, values[0].strip_edges(), func(ok, data):
			done.call(ok, str(data.get("error", "Could not verify account.")))
			if ok: show_message("Email verified. You can now sign in.", false)
		)
	)

func _managed_recovery() -> void:
	var username: String = user_node.text.strip_edges()
	if username.is_empty():
		show_message("Enter your username first.")
		return
	var dialog := _account_form("Reset password", ["Code from your email", "New password (at least 14 characters)"], func(values, done):
		APIManager.reset_password(username, values[0].strip_edges(), values[1], func(ok, data):
			done.call(ok, str(data.get("error", "Could not reset password.")))
			if ok: show_message("Password changed. You can now sign in.", false)
		)
	)
	APIManager.request_password_reset(username, func(_ok, _data): pass)
	var verify := Button.new()
	verify.text = "Resend verification email instead"
	verify.position = Vector2(20, 295)
	dialog.add_child(verify)
	verify.pressed.connect(func():
		APIManager.resend_confirmation(username, func(ok, data):
			if ok:
				dialog.exclusive = false
				dialog.hide()
				dialog.queue_free()
				_managed_confirm(username)
			else: show_message(str(data.get("error", "Please try again.")))
		)
	)
