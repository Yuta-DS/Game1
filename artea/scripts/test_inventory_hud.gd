extends SceneTree


func _init() -> void:
	var packed := load("res://scenes/New_Hub_World.tscn") as PackedScene
	if packed == null:
		_fail("hub scene must load")
		return
	var hub := packed.instantiate()
	var button := hub.get_node_or_null("Inventory/TextureButton") as TextureButton
	if button == null:
		_fail("inventory button must exist")
		return
	if not is_equal_approx(button.anchor_left, 1.0) \
			or not is_equal_approx(button.anchor_right, 1.0) \
			or not is_equal_approx(button.offset_right, -16.0):
		_fail("inventory button must stay at the safe top-right edge")
		return
	if not is_equal_approx(button.size.x, 96.0) or not is_equal_approx(button.size.y, 96.0):
		_fail("inventory button must render at a clean 96px square")
		return
	if button.texture_normal == null \
			or button.texture_normal.resource_path != "res://assets/UI/inventory_backpack.svg":
		_fail("inventory button must use the scalable high-detail graphic")
		return
	if button.stretch_mode != TextureButton.STRETCH_KEEP_ASPECT_CENTERED:
		_fail("inventory graphic must preserve its aspect ratio")
		return
	hub.free()
	print("INVENTORY_HUD_TEST: PASS — sharp scalable icon anchored at the top-right safe edge")
	quit()


func _fail(message: String) -> void:
	push_error("INVENTORY_HUD_TEST: %s" % message)
	quit(1)
