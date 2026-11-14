# "Setup" — the facilitator's choice of how Artéa speaks.
#
# ARTÉA is built on a Christian foundation, and faith mode is the default and
# the authentic voice of the project. It is not an add-on to be switched on.
#
# Universal mode exists because the same game is used in schools, community
# programs, and private practice, where explicit faith framing may not be
# appropriate to present to someone else's children. In that mode the
# guardians keep their role, their warmth, and every word of the message —
# being known, being valued, having gifts and purpose. Only the naming
# register changes: the Keeper of Wisdom says what the Everlasting Father
# says.
#
# What must never differ between modes: progression, treasures, strengths,
# or rewards. JourneyState enforces that structurally by never reading
# audience_mode — no code path can gate a discovery on the setting.
#
# This is a facilitator control, not a player one. It is deliberately plain,
# text-led and unglamorous so it does not read to a child as a thing to go
# and play with, and it is placed behind the same always-available button
# pair as the crisis card rather than in the child's HUD.
extends Node

const INTRO := "Choose how Artéa speaks to this player. Set this before the session starts."

const FAITH_BLURB := "The guardians are named as in Artéa's story: the Everlasting Father, Archangel Raphael, and Uriel, with the Maker at the finale. This is Artéa's original voice."

const UNIVERSAL_BLURB := "The same guardians, named by their role: the Keeper of Wisdom, the Keeper of Healing, and the Keeper of Creativity. Written for schools and community settings that do not present explicit faith language."

const EQUAL_NOTE := "Both modes are the same game. The journey, the three treasures, the Crown of Life, and every strength the player earns are identical."

var _layer: CanvasLayer
var _faith_button: Button
var _universal_button: Button
var _status: Label


func _ready() -> void:
	_build_ui()
	_hide()


# Public so a settings button or dialogue command can open it.
func show_panel() -> void:
	# Called before _ready() built the UI — nothing to show yet.
	if _layer == null:
		return

	_refresh()
	_layer.visible = true


func _hide() -> void:
	if _layer == null:
		return
	_layer.visible = false


# Absolute node paths error out when this node is not inside the active scene
# tree — during a scene change, or under a test harness.
func _journey_state() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/JourneyState")


func _current_mode() -> String:
	var js := _journey_state()
	if js == null:
		return "faith"
	return str(js.audience_mode)


# The active mode is shown as a disabled button rather than a checkmark so
# the current state is unmissable at a glance in a room full of children.
func _refresh() -> void:
	var mode := _current_mode()
	_faith_button.disabled = mode == "faith"
	_universal_button.disabled = mode == "universal"

	if mode == "faith":
		_status.text = "Currently: faith mode."
	else:
		_status.text = "Currently: universal mode."


func _set_mode(mode: String) -> void:
	var js := _journey_state()
	if js == null:
		return

	js.set_audience_mode(mode)
	_refresh()

	# Island plaques are built once at scene load, so a mode change mid-session
	# would otherwise keep the old guardian names until the hub is reloaded.
	# Rebuilding is each node's own business, not this panel's — ask, don't
	# reach in and rewrite their labels from here.
	#
	# Searched rather than addressed by path: the sky isles are a child node of
	# the hub in New_Hub_World.tscn but are attached to a different parent in
	# the gallery's galaxy layer, so no single path finds them in both.
	var scene := get_tree().current_scene
	if scene != null:
		_notify_audience_change(scene)


func _notify_audience_change(node: Node) -> void:
	if node.has_method("refresh_audience_mode"):
		node.refresh_audience_mode()
	for child in node.get_children():
		_notify_audience_change(child)


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
	panel.custom_minimum_size = Vector2(700, 0)
	# PRESET_CENTER anchors the corner, not the middle — offset by half.
	panel.position = Vector2(-350, -260)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.16, 0.97)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(28)
	style.border_width_left = 4
	style.border_color = Color(0.62, 0.80, 1.0, 0.9)
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)

	box.add_child(_heading("Setup"))
	box.add_child(_body(INTRO, Color(0.90, 0.92, 0.97), 18))

	_status = _body("", Color(1.0, 0.88, 0.55), 19)
	box.add_child(_status)

	_faith_button = Button.new()
	_faith_button.text = "Faith mode (default)"
	_faith_button.custom_minimum_size = Vector2(0, 46)
	_faith_button.pressed.connect(_set_mode.bind("faith"))
	box.add_child(_faith_button)
	box.add_child(_body(FAITH_BLURB, Color(0.78, 0.86, 0.78), 16))

	_universal_button = Button.new()
	_universal_button.text = "Universal mode"
	_universal_button.custom_minimum_size = Vector2(0, 46)
	_universal_button.pressed.connect(_set_mode.bind("universal"))
	box.add_child(_universal_button)
	box.add_child(_body(UNIVERSAL_BLURB, Color(0.78, 0.86, 0.78), 16))

	box.add_child(_body(EQUAL_NOTE, Color(0.72, 0.78, 0.90), 16))

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 46)
	close.pressed.connect(_hide)
	box.add_child(close)

	panel.add_child(box)
	_layer.add_child(panel)


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
