extends CanvasLayer
## Celestial passenger banner. The railway remains responsible for travel and
## camera locking. Same signals/methods as the previous station-choice component.

signal get_off_requested
signal continue_requested

const Frame := preload("res://scripts/train_celestial_frame.gd")
const Hud := preload("res://scripts/ui/artea_hud_theme.gd")
const INK := Color("243c50")
const GOLD_TEXT := Color("806022")
const MUTED := Color("526775")

var _overlay: Control
var _scroll: ScrollContainer
var _panel: PanelContainer
var _station: Label
var _description: Label
var _next: Label
var _get_off: Button
var _continue: Button
var _actions: GridContainer
var _travel: PanelContainer
var _travel_text: Label
var _body: Font
var _display: Font
var _button_font: Font

func _ready() -> void:
	name = "PassengerJourneyUI"
	layer = 110
	_body = Hud.utility_font()
	_button_font = _body
	_display = Hud.display_font()
	_overlay = Control.new()
	_overlay.name = "ArrivalChoice"
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(.025, .045, .085, .48)
	_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bounds := MarginContainer.new()
	_overlay.add_child(bounds)
	bounds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		bounds.add_theme_constant_override("margin_" + edge, 16)
	_scroll = ScrollContainer.new()
	_scroll.name = "ArrivalScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	bounds.add_child(_scroll)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(centre)
	_panel = _framed_panel(false)
	_panel.name = "CelestialArrivalBanner"
	centre.add_child(_panel)
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 42)
	padding.add_theme_constant_override("margin_right", 42)
	padding.add_theme_constant_override("margin_top", 112)
	padding.add_theme_constant_override("margin_bottom", 49)
	_panel.add_child(padding)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	padding.add_child(content)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 3)
	content.add_child(heading)
	_label(heading, "CROWN LINE", 14, GOLD_TEXT)
	_label(heading, "STATION ARRIVAL", 12, MUTED)
	_station = _label(heading, "", 50, INK, _display)
	_station.add_theme_color_override("font_shadow_color", Color(1, 1, 1, .8))
	_station.add_theme_constant_override("shadow_offset_y", 1)
	var separator := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color("d3bc86")
	line.thickness = 1
	separator.add_theme_stylebox_override("separator", line)
	content.add_child(separator)
	_description = _label(content, "", 18, MUTED)
	var route := PanelContainer.new()
	route.add_theme_stylebox_override("panel", _surface(Color("e9f0ee"), Color("d2c08b"), 12))
	content.add_child(route)
	var route_text := VBoxContainer.new()
	route_text.add_theme_constant_override("separation", 3)
	route.add_child(route_text)
	_label(route_text, "NEXT STOP", 12, GOLD_TEXT)
	_next = _label(route_text, "", 24, INK, _display)
	_actions = GridContainer.new()
	_actions.columns = 2
	_actions.add_theme_constant_override("h_separation", 12)
	_actions.add_theme_constant_override("v_separation", 10)
	content.add_child(_actions)
	_get_off = _button("GetOffHere", "Get off here", false)
	_actions.add_child(_get_off)
	_get_off.pressed.connect(func() -> void: get_off_requested.emit())
	_continue = _button("NextStation", "Next station", true)
	_actions.add_child(_continue)
	_continue.pressed.connect(func() -> void: continue_requested.emit())
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 3)
	content.add_child(footer)
	_label(footer, "The train will wait for your choice.", 13, MUTED)
	_label(footer, "Tab to choose  ·  Enter to confirm", 11, MUTED)
	_overlay.hide()
	_travel = _framed_panel(true)
	_travel.name = "JourneyStatus"
	_travel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_travel)
	var travel_padding := MarginContainer.new()
	travel_padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right"]:
		travel_padding.add_theme_constant_override("margin_" + edge, 30)
	travel_padding.add_theme_constant_override("margin_top", 26)
	travel_padding.add_theme_constant_override("margin_bottom", 19)
	_travel.add_child(travel_padding)
	_travel_text = _label(travel_padding, "", 15, INK)
	_travel.hide()
	get_viewport().size_changed.connect(_layout)
	_layout()

func _framed_panel(compact: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var frame := Frame.new()
	frame.name = "GoldSnowflakeFrame"
	frame.compact = compact
	panel.add_child(frame)
	return panel

func _surface(fill: Color, edge: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _label(parent: Node, text: String, font_size: int, colour: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _body if font == null else font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	parent.add_child(label)
	return label

func _button(node_name: String, text: String, primary: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	Hud.style_action_button(button, Hud.PARCHMENT)
	button.custom_minimum_size.y = 56
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", _button_font)
	button.add_theme_font_size_override("font_size", 16)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_color_override("font_disabled_color", Color("6a7275"))
	var normal := _surface(Color("e8ca80") if primary else Color("fffbee"), Color("b58a39"), 12)
	normal.set_border_width_all(2)
	normal.shadow_color = Color("b58a39") if primary else Color("d2c08b")
	normal.shadow_offset = Vector2(0, 3)
	normal.shadow_size = 2
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _surface(Color("f6da91") if primary else Color("e1f0f3"), Color("92651e"), 12))
	button.add_theme_stylebox_override("pressed", _surface(Color("d8b66d") if primary else Color("d7e5e8"), GOLD_TEXT, 12))
	button.add_theme_stylebox_override("disabled", _surface(Color("e3e0d6"), Color("b6b3a9"), 12))
	var focus := _surface(Color.TRANSPARENT, INK, 0)
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(3)
	button.add_theme_stylebox_override("focus", focus)
	return button

func _layout() -> void:
	var width := get_viewport().get_visible_rect().size.x
	_panel.custom_minimum_size.x = minf(640, maxf(240, width - 32))
	_actions.columns = 1 if width < 500 else 2
	_station.add_theme_font_size_override("font_size", 32 if width < 500 else 50)
	_travel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	var half_width := minf(235, maxf(120, (width - 24) * .5))
	_travel.offset_left = -half_width
	_travel.offset_right = half_width
	_travel.offset_top = 12
	_travel.offset_bottom = 116

func show_travel(destination: String, section: int) -> void:
	_overlay.hide()
	_get_off.release_focus()
	_continue.release_focus()
	_travel_text.text = "THE CROWN LINE  ·  COACH %d\nNext stop: %s" % [section + 1, destination]
	_travel.show()

func show_arrival(station: String, next_station: String, locked_reason: String) -> void:
	_travel.hide()
	_station.text = station
	_description.text = "Explore this stop, or keep riding?"
	_next.text = next_station if locked_reason.is_empty() else locked_reason
	_next.add_theme_font_override("font", _display if locked_reason.is_empty() else _body)
	_next.add_theme_font_size_override("font_size", 24 if locked_reason.is_empty() else 15)
	_continue.disabled = not locked_reason.is_empty()
	_continue.text = "Next station" if locked_reason.is_empty() else "Station locked"
	_overlay.show()
	_scroll.scroll_vertical = 0
	_get_off.grab_focus()

func close_journey() -> void:
	_overlay.hide()
	_travel.hide()
	_get_off.release_focus()
	_continue.release_focus()

func _unhandled_key_input(_event: InputEvent) -> void:
	if _overlay.visible:
		get_viewport().set_input_as_handled()
