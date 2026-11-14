extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	root.add_child(viewport)
	var menu: Node2D = load("res://scenes/start_screen.tscn").instantiate()
	viewport.add_child(menu)
	await process_frame
	for screen in [Vector2(390, 844), Vector2(844, 390), Vector2(375, 667), Vector2(768, 1024), Vector2(1024, 768), Vector2(820, 1180), Vector2(1180, 820), Vector2(1920, 1080)]:
		var factor: float = minf(screen.x / 1710.0, screen.y / 1112.0)
		viewport.size = Vector2i(screen / factor)
		menu._layout_for_screen()
		await process_frame
		await process_frame
		var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size))
		for name in ["UsernameInput", "PasswordInput", "Button", "RegisterButton", "GuestButton", "StatusLabel"]:
			var control: Control = menu.get_node("AnimationParent/CenterContainer/PanelContainer/VBoxContainer/" + name)
			assert(bounds.encloses(control.get_global_rect()), "%s must fit %s" % [name, screen])
		menu.show_message("Username/Password cannot be empty!")
		await process_frame
		await process_frame
		var panel: Control = menu.get_node("AnimationParent/CenterContainer/PanelContainer")
		assert(bounds.encloses(panel.get_global_rect()), "Form with feedback must fit %s" % screen)
		var guest: Button = menu.get_node("AnimationParent/CenterContainer/PanelContainer/VBoxContainer/GuestButton")
		assert(guest.get_global_rect().size.y * factor >= 30.0, "Guest target must remain usable at %s" % screen)
		var background: Sprite2D = menu.get_node("Background")
		assert(is_equal_approx(background.scale.x, background.scale.y), "Background must retain its aspect ratio")
		print("MOBILE_LAYOUT: PASS ", screen)
	viewport.queue_free()
	await process_frame
	quit()
