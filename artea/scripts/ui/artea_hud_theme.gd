# Artéa's "artist's field journal" HUD kit.
#
# One place that owns the palette, the two bundled fonts, and the panel/button
# shapes the creation world builds its HUD from. The point is cohesion: every
# plaque, action and modal in the gameplay view is cut from these few makers,
# so nothing falls back to a grey default Godot control on top of a painting.
#
# Pure presentation. Nothing here reads game state or wires behaviour — callers
# own the text, the signals and the layout.
extends RefCounted

# Palette from the supervision brief. Ink glass carries every dark backing;
# parchment carries type. Contrast has to survive both the pink artwork worlds
# and the bright castle, so these stay fixed while artwork colour only ever
# tints an accent.
const INK_GLASS := Color("171a2b")
const PARCHMENT := Color("fff2c7")
const LENS_CYAN := Color("67e8f9")
const CREATOR_CORAL := Color("ff8066")
const CASTLE_BLUE := Color("7698ff")
const QUIET_MIST := Color("d9e2ff")

const DISPLAY_FONT_PATH := "res://assets/Fonts/NewFont-Artea.otf"
const UTILITY_FONT_PATH := "res://assets/Fonts/Cloud_finish_BOLD.ttf"

# Touch/click target floor. The brief asks for 44 px, which is also the usual
# accessibility minimum, and these are children using a mouse.
const MIN_ACTION_HEIGHT := 44.0

# Safe margin from the viewport edge at the project's 1710x1112 design size.
const SAFE_MARGIN := 24.0

const CORNER_RADIUS := 14
const BORDER_WIDTH := 2


static func display_font() -> Font:
	return load(DISPLAY_FONT_PATH) as Font


static func utility_font() -> Font:
	return load(UTILITY_FONT_PATH) as Font


# The ink-glass plaque every panel sits in: translucent dark fill, restrained
# warm border, generous internal padding so modal text never touches an edge.
# `accent` tints the border with the current artwork colour — the signature
# element that makes the HUD feel cut from the painting.
static func panel_style(accent: Color = PARCHMENT, opacity: float = 0.82,
		padding: float = 18.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(INK_GLASS.r, INK_GLASS.g, INK_GLASS.b, opacity)
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_border_width_all(BORDER_WIDTH)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	style.set_content_margin_all(padding)
	return style


# A slim accent bar drawn along a plaque. Used for the title plaque and the
# creative-action group so the artwork's own colour reads as a stripe of paint.
static func accent_bar(accent: Color, height: float = 3.0) -> Panel:
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.95)
	style.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("panel", style)
	return bar


# Buttons in the same ink-glass family as the plaques, keyed by an accent so a
# creative action (coral) reads differently from a navigation one (castle
# blue) without either becoming a default grey control.
static func style_action_button(button: Button, accent: Color) -> void:
	button.custom_minimum_size = Vector2(0.0, MIN_ACTION_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", utility_font())
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", accent)
	button.add_theme_color_override("font_focus_color", Color.WHITE)

	button.add_theme_stylebox_override("normal", _button_style(accent, 0.78, 0.55))
	button.add_theme_stylebox_override("hover", _button_style(accent, 0.90, 0.95))
	button.add_theme_stylebox_override("pressed", _button_style(accent, 0.96, 1.0))
	# Focus is its own cyan ring so keyboard users can see where they are.
	button.add_theme_stylebox_override("focus", _button_style(LENS_CYAN, 0.90, 1.0))
	button.add_theme_stylebox_override("disabled", _button_style(accent, 0.55, 0.25))


static func _button_style(accent: Color, fill_opacity: float,
		border_opacity: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(INK_GLASS.r, INK_GLASS.g, INK_GLASS.b, fill_opacity)
	style.set_corner_radius_all(12)
	style.set_border_width_all(BORDER_WIDTH)
	style.border_color = Color(accent.r, accent.g, accent.b, border_opacity)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


# Text inputs matched to the button family, so the idea modal does not mix a
# default LineEdit into an otherwise hand-made panel.
static func style_line_edit(edit: LineEdit, accent: Color) -> void:
	edit.custom_minimum_size = Vector2(0.0, MIN_ACTION_HEIGHT)
	edit.add_theme_font_override("font", utility_font())
	edit.add_theme_font_size_override("font_size", 16)
	edit.add_theme_color_override("font_color", PARCHMENT)
	edit.add_theme_color_override("font_placeholder_color",
		Color(QUIET_MIST.r, QUIET_MIST.g, QUIET_MIST.b, 0.6))
	edit.add_theme_color_override("caret_color", accent)
	edit.add_theme_stylebox_override("normal", _button_style(accent, 0.70, 0.45))
	edit.add_theme_stylebox_override("focus", _button_style(LENS_CYAN, 0.80, 0.95))


# Display type for world titles and modal headings.
static func style_heading(label: Label, size: int = 30) -> void:
	label.add_theme_font_override("font", display_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", PARCHMENT)


# Compact utility copy: control hints, status lines, secondary captions.
static func style_body(label: Label, size: int = 16,
		color: Color = QUIET_MIST) -> void:
	label.add_theme_font_override("font", utility_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
