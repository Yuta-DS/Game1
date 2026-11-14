## Creator's Light — Gallery Frame Ritual
##
## An authored, offline reflection moment. This deliberately does not analyse
## artwork, call a model, or reconstruct a Viewfinder-like space. The player's
## chosen motif is the meaning-making action; the app simply remembers it.
extends Control

const SceneLoader := preload("res://scripts/scene_loader.gd")

const CASTLE_FALLBACK_SCENE := "res://scenes/art_gallery_3d_inprogress.tscn"

const MOTIFS := {
	"star_bridge": {
		"title": "Star Bridge",
		"symbol": "✦",
		"colour": Color("77d9ff"),
		"description": "A bridge for a hopeful next step.",
	},
	"dream_door": {
		"title": "Dream Door",
		"symbol": "⌑",
		"colour": Color("ffbd6b"),
		"description": "A door toward a possibility you want to explore.",
	},
	"constellation_mural": {
		"title": "Constellation Mural",
		"symbol": "✧",
		"colour": Color("d7a4ff"),
		"description": "A constellation that celebrates the pieces of your story.",
	},
}

var _creation_id := ""
var _artwork_path := ""
var _artwork_title := "My Artwork"
var _selected_motif := ""
var _placed_motif := ""

var _art_frame: PanelContainer
var _motif_buttons: Dictionary = {}
var _status: Label
var _place_button: Button
var _undo_button: Button
var _confirm_button: Button
var _ornament: RitualOrnament


static func motif_ids() -> Array[String]:
	return ["star_bridge", "dream_door", "constellation_mural"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_resolve_artwork()
	_build_ritual()
	_refresh()


func _resolve_artwork() -> void:
	# Prefer the artwork deliberately handed over by the art studio/gallery.
	var creation_world := get_node_or_null("/root/CreationWorldState")
	if creation_world != null:
		var candidate := str(creation_world.call("active_artwork_path")) if creation_world.has_method("active_artwork_path") else ""
		if not candidate.is_empty() and FileAccess.file_exists(candidate):
			_artwork_path = candidate
			var record: Dictionary = creation_world.call("current_record") if creation_world.has_method("current_record") else {}
			_artwork_title = str(record.get("title", "My Artwork"))

	var journey := get_node_or_null("/root/JourneyState")
	if journey == null:
		return
	if not _artwork_path.is_empty() and journey.has_method("creation_id_for_path"):
		_creation_id = str(journey.call("creation_id_for_path", _artwork_path))
	# A direct launch remains useful after restart: show the newest locally saved
	# creation, never inspect, upload, or infer anything from it.
	var stored_creations = journey.get("creations")
	if _creation_id.is_empty() and stored_creations is Array:
		var creations: Array = stored_creations
		if not creations.is_empty():
			var latest: Dictionary = creations.back()
			var latest_path := str(latest.get("path", ""))
			if FileAccess.file_exists(latest_path):
				_artwork_path = latest_path
				_artwork_title = str(latest.get("title", "My Artwork"))
				_creation_id = str(latest.get("id", ""))


func _build_ritual() -> void:
	var background := ColorRect.new()
	background.color = Color("0c1028")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var stars := RitualOrnament.new()
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stars.modulate = Color(1, 1, 1, 0.55)
	background.add_child(stars)

	var page := MarginContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("margin_left", 48)
	page.add_theme_constant_override("margin_top", 34)
	page.add_theme_constant_override("margin_right", 48)
	page.add_theme_constant_override("margin_bottom", 34)
	add_child(page)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	page.add_child(layout)

	var top := HBoxContainer.new()
	layout.add_child(top)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	var eyebrow := Label.new()
	eyebrow.text = "CREATOR’S LIGHT  ·  ARTÉA CASTLE GALLERY"
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color("9edfff"))
	heading.add_child(eyebrow)
	var title := Label.new()
	title.text = "Frame a light from your own story"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("fff6df"))
	heading.add_child(title)
	var return_button := Button.new()
	return_button.text = "Return to Art Castle"
	return_button.custom_minimum_size = Vector2(190, 44)
	return_button.pressed.connect(_return_to_campaign)
	top.add_child(return_button)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 26)
	layout.add_child(content)

	_art_frame = PanelContainer.new()
	_art_frame.custom_minimum_size = Vector2(460, 450)
	_art_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_art_frame.add_theme_stylebox_override("panel", _panel_style(Color("252a51"), Color("a4ddff"), 3, 22))
	content.add_child(_art_frame)
	var art_stack := VBoxContainer.new()
	art_stack.add_theme_constant_override("separation", 12)
	_art_frame.add_child(art_stack)
	var art_label := Label.new()
	art_label.text = _artwork_title
	art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	art_label.add_theme_font_size_override("font_size", 20)
	art_stack.add_child(art_label)
	var art_view := TextureRect.new()
	art_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_view.custom_minimum_size = Vector2(410, 300)
	art_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_view.texture = _load_artwork_texture()
	art_stack.add_child(art_view)
	if art_view.texture == null:
		var empty := Label.new()
		empty.text = "Your next creation will appear here.\nSave artwork in the Creator’s Light studio, then return to frame it."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", Color("c9c8e8"))
		art_stack.add_child(empty)
	_ornament = RitualOrnament.new()
	_ornament.custom_minimum_size = Vector2(0, 68)
	_ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_stack.add_child(_ornament)

	var choices := VBoxContainer.new()
	choices.custom_minimum_size = Vector2(390, 0)
	choices.add_theme_constant_override("separation", 12)
	content.add_child(choices)
	var guide := Label.new()
	guide.text = "Choose one small symbol. There is no right answer."
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_font_size_override("font_size", 19)
	guide.add_theme_color_override("font_color", Color("f5eaff"))
	choices.add_child(guide)
	for motif_id in motif_ids():
		var motif: Dictionary = MOTIFS[motif_id]
		var button := Button.new()
		button.text = "%s  %s\n%s" % [str(motif["symbol"]), str(motif["title"]), str(motif["description"])]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 78)
		button.pressed.connect(_choose_motif.bind(motif_id))
		choices.add_child(button)
		_motif_buttons[motif_id] = button
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color("fff0ae"))
	_status.add_theme_font_size_override("font_size", 16)
	choices.add_child(_status)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	choices.add_child(actions)
	_place_button = Button.new()
	_place_button.text = "Place in Frame"
	_place_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_place_button.custom_minimum_size = Vector2(0, 48)
	_place_button.pressed.connect(_place_selected_motif)
	actions.add_child(_place_button)
	_undo_button = Button.new()
	_undo_button.text = "Undo"
	_undo_button.custom_minimum_size = Vector2(86, 48)
	_undo_button.pressed.connect(_undo)
	actions.add_child(_undo_button)
	_confirm_button = Button.new()
	_confirm_button.text = "Confirm My Light"
	_confirm_button.custom_minimum_size = Vector2(0, 52)
	_confirm_button.pressed.connect(_confirm)
	choices.add_child(_confirm_button)


func _load_artwork_texture() -> Texture2D:
	if _artwork_path.is_empty() or not FileAccess.file_exists(_artwork_path):
		return null
	var image := Image.load_from_file(_artwork_path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _choose_motif(motif_id: String) -> void:
	if not MOTIFS.has(motif_id):
		return
	_selected_motif = motif_id
	for id in _motif_buttons:
		var button := _motif_buttons[id] as Button
		button.modulate = Color.WHITE if id == motif_id else Color(0.72, 0.72, 0.86)
	_status.text = "%s is ready. Place it when it feels right." % str(MOTIFS[motif_id]["title"])
	_refresh()


func _place_selected_motif() -> void:
	if _selected_motif.is_empty():
		_status.text = "Choose a symbol first."
		return
	_placed_motif = _selected_motif
	_status.text = "%s is now part of this frame. You can undo or confirm." % str(MOTIFS[_placed_motif]["title"])
	_refresh()


func _undo() -> void:
	if _placed_motif.is_empty():
		_status.text = "Nothing has been placed yet."
		return
	_placed_motif = ""
	_status.text = "The frame is open again. Choose or place a different symbol."
	_refresh()


func _confirm() -> void:
	if _placed_motif.is_empty():
		_status.text = "Place a symbol in the frame before confirming."
		return
	if _creation_id.is_empty():
		_status.text = "This frame needs a saved artwork first. Return to the studio, save your work, then frame it here."
		return
	var journey := get_node_or_null("/root/JourneyState")
	if journey == null or not journey.has_method("complete_creator_frame_ritual"):
		_status.text = "The journey journal is unavailable right now. Your artwork has not been changed."
		return
	if not bool(journey.call("complete_creator_frame_ritual", _creation_id, _placed_motif)):
		_status.text = "This frame could not be confirmed yet. Your artwork remains safe; return to the studio and try again."
		return
	_status.text = "Creator’s Light awakened. Your chosen symbol is now part of your Crown of Life journey."
	_confirm_button.disabled = true
	_place_button.disabled = true
	_undo_button.disabled = true
	await get_tree().create_timer(1.4).timeout
	_return_to_campaign()


func _refresh() -> void:
	var has_artwork := not _creation_id.is_empty() and not _artwork_path.is_empty()
	_place_button.disabled = _selected_motif.is_empty() or not _placed_motif.is_empty()
	_undo_button.disabled = _placed_motif.is_empty()
	_confirm_button.disabled = _placed_motif.is_empty() or not has_artwork
	if _status.text.is_empty():
		_status.text = "Choose a symbol to begin." if has_artwork else "No saved artwork is selected yet."
	if _ornament != null:
		_ornament.motif_id = _placed_motif
		_ornament.queue_redraw()


func _return_to_campaign() -> void:
	var campaign := get_node_or_null("/root/JourneyCampaign")
	if campaign != null and campaign.has_method("return_to_campaign"):
		campaign.call("return_to_campaign")
		return
	SceneLoader.change_scene_with_loading(get_tree(), CASTLE_FALLBACK_SCENE)


func _panel_style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style


class RitualOrnament extends Control:
	var motif_id := ""

	func _draw() -> void:
		var centre := size * 0.5
		for index in range(18):
			var x := fmod(float(index * 97), max(size.x, 1.0))
			var y := fmod(float(index * 47 + 13), max(size.y, 1.0))
			draw_circle(Vector2(x, y), 1.5 + float(index % 3), Color("88ccff", 0.62))
		if motif_id.is_empty():
			return
		var motif: Dictionary = MOTIFS.get(motif_id, {})
		var colour: Color = motif.get("colour", Color.WHITE)
		if motif_id == "star_bridge":
			draw_arc(centre + Vector2(-80, 18), 78, PI, TAU, 40, colour, 5.0, true)
			draw_line(centre + Vector2(-80, 18), centre + Vector2(80, 18), colour, 3.0, true)
			draw_circle(centre + Vector2(0, -40), 8, colour)
		elif motif_id == "dream_door":
			var door := Rect2(centre - Vector2(36, 30), Vector2(72, 64))
			draw_rect(door, colour, false, 5.0, true)
			draw_arc(centre + Vector2(0, -30), 36, PI, TAU, 28, colour, 5.0, true)
			draw_circle(centre + Vector2(18, 4), 4, colour)
		else:
			var points := PackedVector2Array([centre + Vector2(-65, 22), centre + Vector2(-25, -20), centre + Vector2(18, 14), centre + Vector2(68, -28)])
			draw_polyline(points, colour, 3.0, true)
			for point in points:
				draw_circle(point, 7, colour)
