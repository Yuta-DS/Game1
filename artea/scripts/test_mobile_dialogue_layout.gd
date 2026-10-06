extends SceneTree

const HubBalloonScene := preload("res://dialogue/HubworldBalloon.tscn")
const TherapistBalloonScene := preload("res://dialogue/therapistBalloon.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not await _verify_balloon(HubBalloonScene, true):
		return
	if not await _verify_balloon(TherapistBalloonScene, false):
		return
	print("MOBILE_DIALOGUE_LAYOUT_TEST: PASS — both World One and therapist balloons keep portrait and landscape text, panels, and response targets physically readable")
	quit(0)


func _verify_balloon(scene: PackedScene, hub_variant: bool) -> bool:
	var balloon := scene.instantiate()
	root.add_child(balloon)
	await process_frame
	var logical_phone := Vector2(1710.0, 3700.0)
	var physical_phone := Vector2(390.0, 844.0)
	var selected: Vector2 = balloon.call("_select_dialogue_physical_size",
		logical_phone, Vector2(710.0, 1536.0), physical_phone)
	if selected != physical_phone:
		_fail("dialogue sizing does not prefer the browser CSS viewport", hub_variant)
		return false
	balloon.call("_layout_for_viewport", logical_phone, physical_phone)
	if str(balloon.get_meta("dialogue_layout", "")) != "phone_readable_v1":
		_fail("portrait Web viewport does not select the phone dialogue layout", hub_variant)
		return false
	var scale_value := float(balloon.get_meta("dialogue_ui_scale", 0.0))
	var root_control := balloon.get_node("Balloon") as Control
	var panel := root_control.get_node("Panel" if hub_variant else "MarginContainer") as Control
	var responses := root_control.get_node("Responses") as Control if hub_variant \
		else root_control.get_node("ResponsesMenu") as Control
	var character := balloon.get_node("%CharacterLabel") as RichTextLabel
	var dialogue := balloon.get_node("%DialogueLabel") as RichTextLabel
	var menu := balloon.get_node("%ResponsesMenu") as Control
	var template := menu.get_node("ResponseExample") as Button
	if scale_value < 4.0 or root_control.scale != Vector2.ONE:
		_fail("portrait dialogue does not compensate for canvas_items scaling", hub_variant)
		return false
	if dialogue.get_theme_font_size("normal_font_size") / scale_value < 16.5 \
			or character.get_theme_font_size("normal_font_size") / scale_value < 17.5 \
			or template.get_theme_font_size("font_size") / scale_value < 15.5:
		_fail("portrait dialogue typography is smaller than its readable CSS target", hub_variant)
		return false
	if template.custom_minimum_size.y / scale_value < 47.9:
		_fail("portrait response target is smaller than 48 CSS pixels", hub_variant)
		return false
	if panel.offset_top >= panel.offset_bottom or responses.offset_top >= responses.offset_bottom:
		_fail("portrait dialogue bands have invalid vertical geometry", hub_variant)
		return false
	if panel.offset_bottom > responses.offset_top:
		_fail("dialogue panel overlaps the response band", hub_variant)
		return false

	var logical_landscape := Vector2(2405.0, 1112.0)
	var physical_landscape := Vector2(844.0, 390.0)
	balloon.call("_layout_for_viewport", logical_landscape, physical_landscape)
	scale_value = float(balloon.get_meta("dialogue_ui_scale", 0.0))
	if dialogue.get_theme_font_size("normal_font_size") / scale_value < 15.5 \
			or template.custom_minimum_size.y / scale_value < 41.9:
		_fail("landscape dialogue typography or response target is too small", hub_variant)
		return false

	balloon.queue_free()
	await process_frame
	return true


func _fail(message: String, hub_variant: bool) -> void:
	push_error("MobileDialogueLayout (%s): %s" % [
		"hub" if hub_variant else "therapist", message])
	quit(1)
