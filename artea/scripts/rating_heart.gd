# The gallery's like button and rating text.
#
# The heart is drawn from SVG icons rather than the ♥ / ♡ characters: the Web
# export ships without the emoji font (it is excluded for size), and the
# default font has no heart glyphs, so the characters rendered blank on Web.
# Icons render identically on every platform.
extends RefCounted

const HEART_FILLED := preload("res://assets/UI/icons/heart_filled.svg")
const HEART_OUTLINE := preload("res://assets/UI/icons/heart_outline.svg")
const LIKED_COLOR := Color(0.93, 0.16, 0.3)
const UNLIKED_COLOR := Color.WHITE
const BUTTON_SIZE := Vector2(96.0, 96.0)


static func rating_text(liked: bool) -> String:
	return "Artwork Rating: Liked" if liked else "Artwork Rating: Not liked yet"


static func apply_to_button(button: Button, liked: bool) -> void:
	if button == null:
		return
	button.text = ""
	button.icon = HEART_FILLED if liked else HEART_OUTLINE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = BUTTON_SIZE
	button.tooltip_text = "Unlike this artwork" if liked else "Like this artwork"
	button.modulate = LIKED_COLOR if liked else UNLIKED_COLOR


static func apply_to_label(label: Label, liked: bool, suffix := "") -> void:
	if label == null:
		return
	label.text = rating_text(liked) + suffix
	label.modulate = LIKED_COLOR if liked else UNLIKED_COLOR
