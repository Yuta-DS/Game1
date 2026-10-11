# Self-service "forgot password" - lets a player reset their own password
# with the one-time recovery code issued at registration (or by an earlier
# reset), without needing the admin tool. See
# server/server.py's /reset-password-with-code for the other half of this.
extends Node

const RecoveryCodeModal := preload("res://scripts/recovery_code_modal.gd")

var _layer: CanvasLayer
var _username_input: LineEdit
var _code_input: LineEdit
var _new_password_input: LineEdit
var _status: Label
var _code_modal: Node


func _ready() -> void:
	_code_modal = RecoveryCodeModal.new()
	add_child(_code_modal)
	_build_ui()
	_hide()


func show_panel() -> void:
	if _layer == null:
		return

	_status.text = ""
	_layer.visible = true


func _hide() -> void:
	if _layer == null:
		return
	_layer.visible = false


func _submit() -> void:
	var username := _username_input.text.strip_edges()
	var code := _code_input.text.strip_edges()
	var new_password := _new_password_input.text

	if username == "" or code == "" or new_password == "":
		_status.add_theme_color_override("font_color", Color.RED)
		_status.text = "All fields are required."
		return

	_status.add_theme_color_override("font_color", Color.WHITE)
	_status.text = "Resetting..."

	APIManager.reset_password_with_code(
		username,
		code,
		new_password,
		func(success, data):
			if success:
				_username_input.text = ""
				_code_input.text = ""
				_new_password_input.text = ""
				_hide()

				# The submitted code is now spent - the server issued a
				# fresh one in the same response, which the player needs to
				# save the same way the original was shown at registration.
				var new_code = ""
				if typeof(data) == TYPE_DICTIONARY:
					new_code = str(data.get("recovery_code", ""))
				_code_modal.show_code(new_code, func(): pass)
			else:
				_status.add_theme_color_override("font_color", Color.RED)
				if typeof(data) == TYPE_DICTIONARY and data.has("error"):
					_status.text = str(data["error"])
				else:
					_status.text = "Could not reach the server."
	)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 15
	add_child(_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 0)
	# PRESET_CENTER anchors the corner, not the middle - offset by half.
	panel.position = Vector2(-260, -210)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.16, 0.97)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(28)
	style.border_width_left = 4
	style.border_color = Color(0.62, 0.80, 1.0, 0.9)
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)

	box.add_child(_heading("Forgot Password"))
	box.add_child(_body(
		"Enter your username and the recovery code you saved when you registered.",
		Color(0.80, 0.82, 0.88), 15
	))

	_username_input = _field("Username", false)
	box.add_child(_username_input)

	_code_input = _field("Recovery code", false)
	box.add_child(_code_input)

	_new_password_input = _field("New password", true)
	box.add_child(_new_password_input)

	_status = _body("", Color.WHITE, 15)
	box.add_child(_status)

	var submit := Button.new()
	submit.text = "Reset Password"
	submit.custom_minimum_size = Vector2(0, 42)
	submit.pressed.connect(_submit)
	box.add_child(submit)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 42)
	close.pressed.connect(_hide)
	box.add_child(close)

	panel.add_child(box)
	_layer.add_child(panel)


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
	return label


func _body(text: String, colour: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(464, 0)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _field(placeholder: String, secret: bool) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.secret = secret
	field.custom_minimum_size = Vector2(0, 40)
	return field
