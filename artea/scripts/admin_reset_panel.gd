# Admin password reset — lets whoever holds the server's ADMIN_RESET_KEY
# clear a locked-out player's password from the start screen, without needing
# direct database or shell access to the server.
#
# Deliberately not a player-facing feature: there is no email on file to
# verify identity, so this trusts the admin key alone. Keep that key off any
# machine a player can get to. See server/server.py's /admin/reset-password
# for the other half of this.
extends Node

var _layer: CanvasLayer
var _admin_key_input: LineEdit
var _username_input: LineEdit
var _new_password_input: LineEdit
var _status: Label


func _ready() -> void:
	_build_ui()
	_hide()


# Public so a button on the start screen can open it.
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
	var admin_key := _admin_key_input.text
	var username := _username_input.text.strip_edges()
	var new_password := _new_password_input.text

	if admin_key == "" or username == "" or new_password == "":
		_status.add_theme_color_override("font_color", Color.RED)
		_status.text = "All fields are required."
		return

	_status.add_theme_color_override("font_color", Color.WHITE)
	_status.text = "Resetting..."

	APIManager.admin_reset_password(
		admin_key,
		username,
		new_password,
		func(success, data):
			if success:
				_status.add_theme_color_override("font_color", Color.GREEN)
				_status.text = "Password reset for " + username + "."
				_new_password_input.text = ""
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
	panel.custom_minimum_size = Vector2(680, 0)
	# PRESET_CENTER anchors the corner, not the middle - offset by half.
	panel.position = Vector2(-340, -260)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.16, 0.97)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(28)
	style.border_width_left = 4
	style.border_color = Color(0.9, 0.6, 0.5, 0.9)
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 13)

	box.add_child(_heading("Admin: Reset Password"))
	box.add_child(_body(
		"For support use only. Requires the server's admin key.",
		Color(0.80, 0.82, 0.88), 20
	))

	_admin_key_input = _field("Admin key", true)
	box.add_child(_admin_key_input)

	_username_input = _field("Player username", false)
	box.add_child(_username_input)

	_new_password_input = _field("New password", true)
	box.add_child(_new_password_input)

	_status = _body("", Color.WHITE, 20)
	box.add_child(_status)

	var submit := Button.new()
	submit.text = "Reset Password"
	submit.custom_minimum_size = Vector2(0, 55)
	submit.add_theme_font_size_override("font_size", 20)
	submit.pressed.connect(_submit)
	box.add_child(submit)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 55)
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(_hide)
	box.add_child(close)

	panel.add_child(box)
	_layer.add_child(panel)


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.80))
	return label


func _body(text: String, colour: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(600, 0)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _field(placeholder: String, secret: bool) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.secret = secret
	field.custom_minimum_size = Vector2(0, 50)
	field.add_theme_font_size_override("font_size", 20)
	return field
