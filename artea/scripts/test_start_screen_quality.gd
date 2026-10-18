extends SceneTree

const START_SCREEN_PATH := "res://scenes/start_screen.tscn"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var start_source := FileAccess.get_file_as_string("res://start_screen.gd")
	var alternate_auth_source := FileAccess.get_file_as_string(
		"res://scripts/authentication.gd")
	var game_manager_source := FileAccess.get_file_as_string("res://scripts/GameManager.gd")
	var gallery_manager_source := FileAccess.get_file_as_string(
		"res://scenes/GalleryManager.gd")
	assert(not start_source.contains("Backend response data content")
		and not start_source.contains("SESSION LOCKED")
		and not alternate_auth_source.contains("print(auth)"),
		"production authentication must not print response or session payloads")
	for routine_log in [
		"Loading dialogue from:",
		"Attempting to open:",
		"File exists:",
		"get_user_data_dir",
		"Offline gallery session",
		"No local artworks found",
		"No player artworks to replace online gallery",
		"Player artworks found:",
	]:
		assert(not game_manager_source.contains(routine_log)
			and not gallery_manager_source.contains(routine_log),
			"production startup must not print routine diagnostic: %s" % routine_log)
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
	assert(str(screen.get_meta("start_screen_layout", "")) == "physical_viewport_v1",
		"the start screen must use the physical-pixel-aware responsive layout")
	assert(form.custom_minimum_size.x >= 360.0,
		"the desktop login form must be wide enough to show its complete placeholders")
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
		and status.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and status.custom_minimum_size.y >= 50.0,
		"authentication feedback must wrap inside the form")
	for button_name in ["Button", "RegisterButton", "GuestButton"]:
		var button := form.get_node(button_name) as Button
		assert(button.get_theme_stylebox("focus") is StyleBoxFlat,
			"%s needs a visible keyboard-focus state" % button_name)
		assert(button.custom_minimum_size.y >= 50.0,
			"%s must remain a comfortable pointer and touch target" % button_name)
	var guest := form.get_node("GuestButton") as Button
	var stick_event := InputEventJoypadMotion.new()
	stick_event.axis = JOY_AXIS_LEFT_Y
	stick_event.axis_value = 0.8
	screen.call("_input", stick_event)
	assert(guest.has_focus() and bool(screen.get_meta(
		"start_screen_gamepad_ready", false)),
		"the first controller navigation must focus Offline Guest without focusing a text field")
	assert(guest.focus_neighbor_top == NodePath("../RegisterButton")
		and guest.focus_neighbor_bottom == NodePath("../UsernameInput")
		and username.focus_neighbor_top == NodePath("../GuestButton"),
		"controller navigation must wrap through the complete entry form")
	screen.call("show_message", "Account service is unavailable. Use Offline Guest.")
	await process_frame
	await process_frame
	assert(status.visible and status.get_global_rect().end.y \
		<= root.get_viewport().get_visible_rect().size.y + 1.0,
		"login failures must remain visible below the buttons")
	screen.call("show_message", "")
	await process_frame
	await process_frame

	# Exercise the exact logical/CSS relationship produced by canvas_items on a
	# 390×844 portrait phone. The background must cover the whole viewport and
	# the form must stay inside it at a readable physical scale.
	var logical_phone := Vector2(1710.0, 3700.0)
	var physical_phone := Vector2(390.0, 844.0)
	screen.call("_layout_for_viewport", logical_phone, physical_phone)
	var host := screen.get_node("AnimationParent/CenterContainer") as CenterContainer
	var background := screen.get_node("Background") as Sprite2D
	var texture_size := Vector2(background.texture.get_size()) * background.scale
	assert(texture_size.x >= logical_phone.x and texture_size.y >= logical_phone.y,
		"the portrait artwork must cover the full phone canvas")
	assert(bool(screen.get_meta("start_screen_portrait", false))
		and float(screen.get_meta("start_screen_ui_scale", 0.0)) >= 4.0,
		"portrait layout must compensate for expanded logical canvas scaling")
	var scaled_position := host.position
	var scaled_size := host.size * host.scale
	assert(scaled_position.x >= 0.0 and scaled_position.y >= 0.0
		and scaled_position.x + scaled_size.x <= logical_phone.x + 0.5
		and scaled_position.y + scaled_size.y <= logical_phone.y + 0.5,
		"the portrait login form must stay fully inside the visible phone viewport")
	assert((form.get_node("UsernameInput") as LineEdit).get_theme_font_size(
		"font_size") >= 22,
		"portrait authentication text must remain readable")
	var music := screen.get_node_or_null("AudioStreamPlayer") as AudioStreamPlayer
	if music != null:
		music.stop()
		music.stream = null
	guest.release_focus()
	screen.queue_free()
	await process_frame
	await process_frame
	print("START_SCREEN_QUALITY: PASS — readable form, complete placeholders, keyboard submission and visible focus states")
	quit()
