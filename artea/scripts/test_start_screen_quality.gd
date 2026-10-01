extends SceneTree

const START_SCREEN_PATH := "res://scenes/start_screen.tscn"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var start_source := FileAccess.get_file_as_string("res://start_screen.gd")
	var alternate_auth_source := FileAccess.get_file_as_string(
		"res://scripts/authentication.gd")
	assert(not start_source.contains("Backend response data content")
		and not start_source.contains("SESSION LOCKED")
		and not alternate_auth_source.contains("print(auth)"),
		"production authentication must not print response or session payloads")
	# Load after the deferred entry point so project autoload names used by the
	# screen controller are registered before its script is compiled.
	var screen := (load(START_SCREEN_PATH) as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame
	var form := screen.get_node(
		"AnimationParent/CenterContainer/PanelContainer/VBoxContainer") as VBoxContainer
	var username := form.get_node("UsernameInput") as LineEdit
	var password := form.get_node("PasswordInput") as LineEdit
	var status := form.get_node("StatusLabel") as Label
	assert(form.custom_minimum_size.x >= 520.0,
		"the login form must be wide enough to show its complete placeholders")
	assert(form.get_theme_constant("separation") >= 8,
		"the login controls need deliberate vertical breathing room")
	assert(username.placeholder_text == "Enter username"
		and username.get_theme_font_size("font_size") <= 42,
		"the username prompt must fit without oversized typography")
	assert(username.get_theme_stylebox("normal") is StyleBoxFlat
		and username.get_theme_stylebox("focus") is StyleBoxFlat,
		"the username field needs authored normal and keyboard-focus states")
	assert(password.secret and password.placeholder_text == "Password",
		"the password field must remain private and clearly labelled")
	assert(not username.get_signal_connection_list("text_submitted").is_empty()
		and not password.get_signal_connection_list("text_submitted").is_empty(),
		"both fields need an Enter-key path")
	assert(status.autowrap_mode != TextServer.AUTOWRAP_OFF
		and status.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"authentication feedback must wrap inside the form")
	for button_name in ["Button", "RegisterButton", "GuestButton"]:
		var button := form.get_node(button_name) as Button
		assert(button.get_theme_stylebox("focus") is StyleBoxFlat,
			"%s needs a visible keyboard-focus state" % button_name)
	var music := screen.get_node_or_null("AudioStreamPlayer") as AudioStreamPlayer
	if music != null:
		music.stop()
		music.stream = null
	screen.queue_free()
	await process_frame
	await process_frame
	print("START_SCREEN_QUALITY: PASS — readable form, complete placeholders, keyboard submission and visible focus states")
	quit()
