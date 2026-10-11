# Shows a one-time recovery code and blocks until the player acknowledges
# it. Both registration and a self-service reset issue a fresh code (see
# server/server.py's _generate_recovery_code - it's returned in plaintext
# exactly once, never stored or logged after that response), so this is the
# one place in the UI responsible for making sure the player actually sees
# it before the screen moves on.
extends Node

var _layer: CanvasLayer
var _code_label: Label
var _on_continue: Callable


func _ready() -> void:
	_build_ui()
	_hide()


# on_continue runs after the player dismisses the modal - registration uses
# it to continue into auto-login; a reset just closes with a no-op.
func show_code(code: String, on_continue: Callable) -> void:
	if _layer == null:
		return

	_code_label.text = code
	_on_continue = on_continue
	_layer.visible = true


func _hide() -> void:
	if _layer == null:
		return
	_layer.visible = false


func _continue_pressed() -> void:
	_hide()
	if _on_continue.is_valid():
		_on_continue.call()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 16
	add_child(_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 0)
	# PRESET_CENTER anchors the corner, not the middle - offset by half.
	panel.position = Vector2(-260, -180)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.16, 0.98)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(28)
	style.border_width_left = 4
	style.border_color = Color(0.62, 0.90, 0.70, 0.9)
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)

	box.add_child(_heading("Save your recovery code"))
	box.add_child(_body(
		"If you ever forget your password, this code is the only way to reset it yourself. It will not be shown again after you continue - write it down now.",
		Color(0.90, 0.92, 0.97), 16
	))

	_code_label = Label.new()
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.add_theme_font_size_override("font_size", 28)
	_code_label.add_theme_color_override("font_color", Color(0.65, 1.0, 0.75))
	box.add_child(_code_label)

	var continue_button := Button.new()
	continue_button.text = "I've saved it - Continue"
	continue_button.custom_minimum_size = Vector2(0, 46)
	continue_button.pressed.connect(_continue_pressed)
	box.add_child(continue_button)

	panel.add_child(box)
	_layer.add_child(panel)


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72))
	return label


func _body(text: String, colour: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(464, 0)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label
