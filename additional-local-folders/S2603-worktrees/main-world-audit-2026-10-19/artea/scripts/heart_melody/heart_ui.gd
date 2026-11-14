extends RefCounted
## Shared, compact cards for garden dialogue and step-by-step activities.
const INK := Color("121f2d")
const ACCENT := Color("72d7df")

static func style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("121f2df5")
	box.border_color = ACCENT
	box.set_border_width_all(2)
	box.set_corner_radius_all(12)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	return box

static func decorate(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", style())
	panel.add_theme_color_override("font_color", Color("f5f4e9"))

static func flow(parent: Control, steps: Array, active := 0) -> Control:
	var row := HBoxContainer.new()
	row.name = "ActivityFlow"
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	for i in steps.size():
		if i > 0:
			var arrow := Label.new()
			arrow.text = "›"
			arrow.add_theme_font_size_override("font_size", 28)
			arrow.add_theme_color_override("font_color", ACCENT)
			row.add_child(arrow)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := style()
		box.bg_color = Color("234853") if i == active else Color("1b2e3c")
		box.set_border_width_all(1)
		box.border_color = ACCENT if i == active else Color("38515e")
		box.content_margin_left = 10
		box.content_margin_right = 10
		card.add_theme_stylebox_override("panel", box)
		row.add_child(card)
		var label := Label.new()
		label.text = "%02d\n%s" % [i + 1, str(steps[i])]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 120
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		card.add_child(label)
	return row
