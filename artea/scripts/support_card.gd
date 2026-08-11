# "If you need to talk to someone" — crisis resources.
#
# Deliberately independent of JourneyState. A player in real distress must be
# able to reach this at any stage, including stage 0, including with the
# journey wiped. It never reads the journey and never records that it was
# opened — someone checking this is not a metric.
#
# Attached to the Icons HUD alongside icons_hud.gd. Builds its own UI at
# runtime rather than editing Icons_HUD.tscn, whose Settings Panel is
# hand-positioned pixel art.
#
# Artéa is not a therapist and must never present itself as one. This card
# is the one place the game says so plainly and points elsewhere.
extends Node

# Verify these before every release — numbers and operating hours change,
# and a dead crisis number is worse than none at all.
# Last checked: 2026-08-07.
const RESOURCES := [
	{
		"region": "International",
		"name": "Find a Helpline",
		"contact": "findahelpline.com",
		"note": "Free, confidential support in over 130 countries.",
	},
	{
		"region": "Cambodia",
		"name": "TPO Cambodia",
		"contact": "017 276 477",
		"note": "Mental health support, Phnom Penh.",
	},
	{
		"region": "UK & Ireland",
		"name": "Samaritans",
		"contact": "116 123",
		"note": "Free, 24 hours a day, every day.",
	},
	{
		"region": "US & Canada",
		"name": "Suicide & Crisis Lifeline",
		"contact": "988",
		"note": "Call or text, 24 hours a day.",
	},
]

const INTRO := "Artéa is a game, not a therapist. It cannot help in an emergency.\nIf things feel heavy right now, these people can."

const CLOSING := "If you are in immediate danger, contact your local emergency number."

var _layer: CanvasLayer
var _panel: PanelContainer


func _ready() -> void:
	_build_ui()
	_hide()


# Public so a button, a dialogue `do` command, or a pause menu can open it.
func show_card() -> void:
	if _layer == null:
		return

	_layer.visible = true

	# Never trap the player behind a pause they cannot clear.
	var tree := get_tree()
	if tree != null:
		tree.paused = false


func _hide() -> void:
	if _layer == null:
		return

	_layer.visible = false


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	# Above the ceremony panel (layer 10) — nothing should ever cover this.
	_layer.layer = 20
	add_child(_layer)

	# Dim what is behind, so the card reads as a quiet moment out of the game.
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(720, 0)
	# PRESET_CENTER anchors the corner, not the middle — offset by half.
	_panel.position = Vector2(-360, -260)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.16, 0.97)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(28)
	style.border_width_left = 4
	style.border_color = Color(0.55, 0.85, 1.0, 0.9)
	_panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)

	box.add_child(_heading("If you need to talk to someone"))
	box.add_child(_body(INTRO, Color(0.88, 0.90, 0.96)))

	for r in RESOURCES:
		box.add_child(_resource_row(r))

	box.add_child(_body(CLOSING, Color(0.72, 0.76, 0.86)))

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 46)
	close.pressed.connect(_hide)
	box.add_child(close)

	_panel.add_child(box)
	_layer.add_child(_panel)


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72))
	return label


func _body(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(664, 0)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", colour)
	return label


# One resource, with the contact detail as the loudest thing in the row.
func _resource_row(r: Dictionary) -> PanelContainer:
	var holder := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.06)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	holder.add_theme_stylebox_override("panel", style)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "%s — %s" % [r["region"], r["name"]]
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.70, 0.88, 1.0))
	rows.add_child(title)

	var contact := Label.new()
	contact.text = r["contact"]
	contact.add_theme_font_size_override("font_size", 26)
	contact.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	rows.add_child(contact)

	var note := Label.new()
	note.text = r["note"]
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(620, 0)
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.78, 0.80, 0.88))
	rows.add_child(note)

	holder.add_child(rows)
	return holder
