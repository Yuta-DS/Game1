# "Your journey" — what Artéa remembers, and the button that erases it.
#
# The journey record holds what the player wrote about their own distressing
# thoughts. Keeping that is the point of the whole design, but it is only
# defensible if the player can see it and take it back. This is that.
#
# One button, one confirmation, no maze. The confirmation exists because the
# wipe is irreversible, not to talk the player out of it — "Delete" is the
# affirmative choice and it is never disguised or delayed.
#
# Attached to the Icons HUD alongside icons_hud.gd. Builds its own UI at
# runtime rather than editing Icons_HUD.tscn's hand-positioned Settings Panel.
extends Node

const REASSURANCE := "Your thoughts and feelings stay on this device. Artwork stays local unless an adult or facilitator deliberately uses a separate export or upload option."

const CONFIRM := "This erases every thought, feeling, and strength Artéa remembers about you, and the castle returns to sleep.\n\nArtwork you already saved to the gallery is kept.\n\nThis cannot be undone."

const DONE := "Your journey has been erased."

var _layer: CanvasLayer
var _panel: PanelContainer
var _summary: Label
var _confirm_box: VBoxContainer
var _delete_button: Button
var _status: Label


func _ready() -> void:
	_build_ui()
	_hide()


# Public so a settings button or dialogue command can open it.
func show_panel() -> void:
	# Called before _ready() built the UI — nothing to show yet. Silently
	# doing nothing is right here: this is the erase-my-data panel, and
	# crashing it is worse than a button that needs a second press.
	if _layer == null:
		return

	_refresh()
	_layer.visible = true


func _hide() -> void:
	if _layer == null:
		return

	_layer.visible = false
	_confirm_box.visible = false
	_status.text = ""


# Absolute node paths error out when this node is not inside the active
# scene tree — during a scene change, or under a test harness. The journey
# record is optional to this panel's existence, so resolve it defensively.
func _journey_state() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/JourneyState")


# What the game currently remembers, in plain counts. Thought *text* is
# deliberately not listed — re-reading their own worst thoughts in a settings
# menu is not something the player asked for. Counts are enough to make the
# record concrete.
func _refresh() -> void:
	var js := _journey_state()
	if js == null:
		_summary.text = "Artéa is not remembering anything right now."
		_delete_button.disabled = true
		return

	if not js.has_journey():
		_summary.text = "Artéa is not remembering anything yet.\nYour journey has not started."
		_delete_button.disabled = true
		return

	_delete_button.disabled = false
	_summary.text = "\n".join([
		"Artéa remembers:",
		"  %d thought%s you wrote" % [js.thoughts.size(), "" if js.thoughts.size() == 1 else "s"],
		"  %d feeling%s you named" % [js.emotions.size(), "" if js.emotions.size() == 1 else "s"],
		"  %d thing%s you made" % [js.creations.size(), "" if js.creations.size() == 1 else "s"],
		"  %d strength%s you earned" % [js.strengths.size(), "" if js.strengths.size() == 1 else "s"],
	])


func _on_delete_pressed() -> void:
	_confirm_box.visible = true


func _on_cancel_pressed() -> void:
	_confirm_box.visible = false


func _on_confirm_pressed() -> void:
	var js := _journey_state()
	if js != null:
		js.clear_journey()

	_confirm_box.visible = false
	_status.text = DONE
	_refresh()

	# The castle sleeps again immediately if we are standing in it, so the
	# erase is something the player *sees*, not just a message.
	var hub := get_tree().current_scene
	if hub != null and hub.has_method("apply_stage"):
		hub.apply_stage(0)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 15
	add_child(_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(700, 0)
	# PRESET_CENTER anchors the corner, not the middle — offset by half.
	_panel.position = Vector2(-350, -240)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.16, 0.97)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(28)
	style.border_width_left = 4
	style.border_color = Color(1.0, 0.85, 0.4, 0.9)
	_panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)

	box.add_child(_heading("Your journey"))
	box.add_child(_body(REASSURANCE, Color(0.78, 0.86, 0.78), 17))

	_summary = _body("", Color(0.90, 0.92, 0.97), 19)
	box.add_child(_summary)

	_status = _body("", Color(1.0, 0.88, 0.55), 18)
	box.add_child(_status)

	_delete_button = Button.new()
	_delete_button.text = "Erase my journey"
	_delete_button.custom_minimum_size = Vector2(0, 46)
	_delete_button.pressed.connect(_on_delete_pressed)
	box.add_child(_delete_button)

	box.add_child(_build_confirm())

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 46)
	close.pressed.connect(_hide)
	box.add_child(close)

	_panel.add_child(box)
	_layer.add_child(_panel)


func _build_confirm() -> VBoxContainer:
	_confirm_box = VBoxContainer.new()
	_confirm_box.visible = false
	_confirm_box.add_theme_constant_override("separation", 10)

	_confirm_box.add_child(_body(CONFIRM, Color(1.0, 0.82, 0.78), 17))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	# Cancel first in reading order, but neither option is hidden or
	# pre-selected — the player decides.
	var cancel := Button.new()
	cancel.text = "Keep my journey"
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_on_cancel_pressed)
	row.add_child(cancel)

	var confirm := Button.new()
	confirm.text = "Erase it"
	confirm.custom_minimum_size = Vector2(0, 44)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.add_theme_color_override("font_color", Color(1.0, 0.62, 0.58))
	confirm.pressed.connect(_on_confirm_pressed)
	row.add_child(confirm)

	_confirm_box.add_child(row)
	return _confirm_box


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72))
	return label


func _body(text: String, colour: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(644, 0)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label
