extends SceneTree
## Standalone UI contract/layout tests, not a claim of gameplay integration.

const UI := preload("res://scripts/train_passenger_journey_ui.gd")
const Hud := preload("res://scripts/ui/artea_hud_theme.gd")
var checks := 0
var failures: Array[String] = []
var get_off_count := 0
var continue_count := 0
var ui: CanvasLayer

class PreviewBackdrop extends Control:
	var texture: GradientTexture2D
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color("223e59"), Color("0d1c32")])
		texture = GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill_from = Vector2(0, 0)
		texture.fill_to = Vector2(.8, 1)
	func _draw() -> void:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
		# Soft celestial chart arcs reference the train's orbital roof details.
		var centre := size * Vector2(.5, .46)
		for radius in [280, 360, 475]:
			draw_arc(centre, radius, 0, TAU, 160, Color(.82, .73, .5, .08), 1, true)
		var rng := RandomNumberGenerator.new()
		rng.seed = 280829
		for star in 90:
			var at := Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
			var radius := rng.randf_range(.5, 1.4)
			draw_circle(at, radius, Color(.95, .89, .71, rng.randf_range(.12, .55)))
			if star % 15 == 0:
				draw_line(at - Vector2(0, 4), at + Vector2(0, 4), Color(.95, .89, .71, .30), 1, true)
				draw_line(at - Vector2(4, 0), at + Vector2(4, 0), Color(.95, .89, .71, .30), 1, true)

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("CELESTIAL_BANNER: " + message)

func _frames(count := 5) -> void:
	for i in count:
		await process_frame

func _key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		root.push_input(event, true)

func _click(button: Button) -> void:
	var at := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func _shot(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await _frames()
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://%s.png" % label) == OK, "Saved " + label)

func _game_context_shot(background: Control) -> void:
	# Optional saved gameplay reference, not a simulated live integration claim.
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--backdrop="):
			path = arg.trim_prefix("--backdrop=")
	if path.is_empty() or "--capture" not in OS.get_cmdline_user_args():
		return
	var reference := Image.load_from_file(path)
	_check(reference != null, "Saved gameplay background loads")
	if reference == null:
		return
	var scene := TextureRect.new()
	scene.texture = ImageTexture.create_from_image(reference)
	scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.hide()
	var notice := CanvasLayer.new()
	notice.layer = 111
	root.add_child(notice)
	var label := Label.new()
	label.text = "UI PREVIEW  ·  SAVED GAMEPLAY BACKGROUND"
	label.position = Vector2(20, 20)
	label.add_theme_font_override("font", Hud.utility_font())
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Hud.PARCHMENT)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.add_child(label)
	await _shot("game_style_banner_context")
	scene.queue_free()
	notice.queue_free()
	background.show()
	await _frames()

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 880)
	Engine.max_fps = 30
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background := PreviewBackdrop.new()
	root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui = UI.new()
	root.add_child(ui)
	ui.get_off_requested.connect(func() -> void: get_off_count += 1)
	ui.continue_requested.connect(func() -> void: continue_count += 1)
	await _frames()
	var overlay := ui.get_node("ArrivalChoice") as Control
	var panel := ui.get("_panel") as Control
	var get_off := ui.find_child("GetOffHere", true, false) as Button
	var next := ui.find_child("NextStation", true, false) as Button
	_check(not overlay.visible and not ui.get_node("JourneyStatus").visible, "Nothing obstructs play before a journey")
	ui.show_arrival("Mind Spark", "Heart Melody", "")
	await _frames()
	_check(overlay.visible, "Arrival banner is visible")
	_check(not ui.get_node("JourneyStatus").visible, "Travel strip hides on arrival")
	_check(get_off.has_focus(), "Safe exit is the default keyboard focus")
	_check((ui.get("_station") as Label).text == "Mind Spark", "Actual arrival name is displayed")
	_check((ui.get("_next") as Label).text == "Heart Melody", "Next stop is displayed")
	_check(not next.disabled, "Unlocked station remains selectable")
	_check(root.get_visible_rect().encloses(panel.get_global_rect()), "Desktop banner fits viewport")
	_check(not get_off.get_global_rect().intersects(next.get_global_rect()), "Buttons do not overlap")
	_check(get_off.size.y >= 48 and next.size.y >= 48, "Both choices have accessible target heights")
	_check((ui.get("_display") as Font).resource_path == Hud.DISPLAY_FONT_PATH, "Uses the game's original display font")
	_check((ui.get("_body") as Font).resource_path == Hud.UTILITY_FONT_PATH, "Uses the game's original utility font")
	_check(get_off.get_theme_font("font") == Hud.utility_font(), "Buttons share the game's font")
	_check((ui.get("_station") as Label).get_theme_color("font_color") == UI.INK, "Title uses dark ink on the restored pearl palette")
	_check(UI.Frame.PEARL == Color("fff9eb") and UI.Frame.GOLD == Color("c89e48"), "Previous pearl and warm-gold colours are restored")
	_check(UI.Frame.RAINBOW.size() == 7, "Frame includes all seven rainbow colours")
	_check(panel.get_node("GoldSnowflakeFrame").mouse_filter == Control.MOUSE_FILTER_IGNORE, "Gold frame never captures clicks")
	await _shot("game_style_banner_desktop")
	await _game_context_shot(background)
	_click(get_off)
	_check(get_off_count == 1 and continue_count == 0, "Exit click emits only the exit signal")
	_click(next)
	_check(get_off_count == 1 and continue_count == 1, "Continue click emits only the continue signal")
	ui.show_arrival("Creator's Light", "Artéa Gallery", "")
	await _frames()
	_key(KEY_TAB)
	_check(next.has_focus(), "Tab reaches the next-station button")
	_key(KEY_ENTER)
	_check(continue_count == 2, "Enter activates the focused choice")
	_key(KEY_ESCAPE)
	_key(KEY_Q)
	_key(KEY_R)
	_check(overlay.visible and get_off_count == 1 and continue_count == 2, "Other shortcuts cannot choose or dismiss the prompt")
	for dimensions in [Vector2i(360, 740), Vector2i(320, 700), Vector2i(1920, 1080)]:
		root.size = dimensions
		await _frames(8)
		_check(root.get_visible_rect().encloses(panel.get_global_rect()), "Banner fits %s" % dimensions)
		_check(panel.get_global_rect().encloses(get_off.get_global_rect()) and panel.get_global_rect().encloses(next.get_global_rect()), "Choices fit their frame at %s" % dimensions)
		_check(not get_off.get_global_rect().intersects(next.get_global_rect()), "Choices stay separate at %s" % dimensions)
	root.size = Vector2i(360, 740)
	ui.show_arrival("Mind Spark", "Heart Melody", "Earn the Star of Wisdom in Mind Spark to unlock Heart Melody.")
	await _frames(8)
	_check(next.disabled and not get_off.disabled, "Locked routes keep Get off here available")
	_click(next)
	_check(continue_count == 2, "Disabled next-station click emits nothing")
	_check(root.get_visible_rect().encloses(panel.get_global_rect()), "Locked message fits narrow banner")
	await _shot("game_style_banner_mobile_locked")
	# Short windows must scroll to focused actions, not clip them off-screen.
	root.size = Vector2i(640, 320)
	ui.show_arrival("Creator's Light", "Artéa Gallery", "")
	await _frames(8)
	next.grab_focus()
	await _frames(8)
	_check(root.get_visible_rect().encloses(next.get_global_rect()), "Keyboard focus scrolls the next action into a short viewport")
	_check((ui.get("_scroll") as ScrollContainer).scroll_vertical > 0, "Short viewport enables vertical scrolling")
	root.size = Vector2i(1280, 880)
	ui.show_travel("Heart Melody", 1)
	await _frames(8)
	_check(not overlay.visible and ui.get_node("JourneyStatus").visible, "Travel strip replaces the arrival banner")
	_check("COACH 2" in (ui.get("_travel_text") as Label).text, "Coach numbering remains one-based")
	_check(root.get_visible_rect().encloses((ui.get_node("JourneyStatus") as Control).get_global_rect()), "Travel strip fits viewport")
	await _shot("game_style_banner_travel")
	_check((ui.get_node("JourneyStatus") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "Travel status does not block pointer input")
	root.size = Vector2i(320, 700)
	await _frames(8)
	_check(root.get_visible_rect().encloses((ui.get_node("JourneyStatus") as Control).get_global_rect()), "Travel strip fits narrow screens")
	ui.close_journey()
	_check(not overlay.visible and not ui.get_node("JourneyStatus").visible, "Closing hides both UI states")
	_check(not get_off.has_focus() and not next.has_focus(), "Closing releases button focus")
	print("CELESTIAL_BANNER: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	ui.queue_free()
	background.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
