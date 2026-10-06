class_name CrownQuestJournal
extends Control

const CatalogScript := preload("res://scripts/crown_story_catalog.gd")
const CASTLE_SCENE := "res://scenes/art_gallery_3d_inprogress.tscn"

const INK := Color("#08142e")
const DEEP_SPACE := Color("#101f47")
const GLASS := Color("#172b55e8")
const CYAN := Color("#7ee9ff")
const STAR_GOLD := Color("#ffd57a")
const ROSE := Color("#ff9fc9")
const MINT := Color("#9ef0c8")
const TEXT := Color("#f5f7ff")
const MUTED := Color("#c3cce4")

var _catalog: Dictionary = {}
var _tracker: Variant = null
var _journey_state: Variant = null
var _campaign: Variant = null
var _audience_mode := "faith"

var _content: VBoxContainer
var _objective_title: Label
var _objective_body: Label
var _card_container: VBoxContainer
var _back_button: Button
var _arc_statuses: Dictionary = {}


func configure(
		source_catalog: Dictionary = {},
		source_tracker: Variant = null,
		source_state: Variant = null,
		source_campaign: Variant = null,
		audience_mode: String = ""
) -> void:
	_catalog = source_catalog.duplicate(true) if not source_catalog.is_empty() else CatalogScript.load_catalog()
	_tracker = source_tracker
	_journey_state = source_state
	_campaign = source_campaign
	_audience_mode = _resolve_audience_mode(audience_mode)
	if is_node_ready():
		_render_story()


func _ready() -> void:
	if _catalog.is_empty():
		_catalog = CatalogScript.load_catalog()
	if _journey_state == null:
		_journey_state = get_node_or_null("/root/JourneyState")
	if _campaign == null:
		_campaign = get_node_or_null("/root/JourneyCampaign")
	_audience_mode = _resolve_audience_mode("")
	_build_shell()
	_render_story()
	_back_button.grab_focus()


func _draw() -> void:
	# A motion-free constellation. It stays legible for reduced-motion users and
	# makes the three cards feel connected to one scientific star map.
	var points := [
		Vector2(size.x * 0.06, size.y * 0.15),
		Vector2(size.x * 0.18, size.y * 0.08),
		Vector2(size.x * 0.33, size.y * 0.17),
		Vector2(size.x * 0.73, size.y * 0.09),
		Vector2(size.x * 0.91, size.y * 0.20),
	]
	for index in points.size() - 1:
		draw_line(points[index], points[index + 1], Color(CYAN, 0.18), 1.5)
	for point in points:
		draw_circle(point, 2.8, Color(STAR_GOLD, 0.72))


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 16)
	margin.add_child(_content)

	var utility := HBoxContainer.new()
	_content.add_child(utility)
	var breadcrumb := _label("ARTÉA CASTLE  /  LIGHTBEARER'S FIELD JOURNAL", 14, CYAN)
	breadcrumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	utility.add_child(breadcrumb)
	_back_button = Button.new()
	_back_button.text = "← Back to Art Castle"
	_back_button.tooltip_text = "Return to the central ARTÉA Castle galaxy"
	_back_button.focus_mode = Control.FOCUS_ALL
	_back_button.add_theme_font_size_override("font_size", 16)
	_back_button.add_theme_color_override("font_color", INK)
	_back_button.add_theme_color_override("font_hover_color", INK)
	_back_button.add_theme_color_override("font_focus_color", INK)
	_back_button.add_theme_stylebox_override("normal", _panel_style(STAR_GOLD, 10, 0))
	_back_button.add_theme_stylebox_override("hover", _panel_style(Color("#ffe6a8"), 10, 0))
	_back_button.add_theme_stylebox_override("focus", _panel_style(CYAN, 10, 3))
	_back_button.pressed.connect(_on_back_pressed)
	utility.add_child(_back_button)

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _panel_style(DEEP_SPACE, 18, 2, CYAN))
	_content.add_child(header)
	var header_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		header_margin.add_theme_constant_override("margin_%s" % side, 18)
	header.add_child(header_margin)
	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 7)
	header_margin.add_child(header_box)
	var title := _label("THE CROWN OF LIFE", 32, TEXT)
	title.tooltip_text = "The complete connected ARTÉA journey"
	header_box.add_child(title)
	var promise := _label(str(_catalog.get("story", {}).get("promise", "Discover the light already within you.")), 17, MUTED)
	promise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_box.add_child(promise)
	header_box.add_child(_label("CURRENT BEACON", 13, STAR_GOLD))
	_objective_title = _label("", 22, TEXT)
	_objective_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_box.add_child(_objective_title)
	_objective_body = _label("", 16, MUTED)
	_objective_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_box.add_child(_objective_body)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	_card_container = VBoxContainer.new()
	_card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_container.add_theme_constant_override("separation", 14)
	scroll.add_child(_card_container)


func _render_story() -> void:
	if _card_container == null:
		return
	for child in _card_container.get_children():
		child.queue_free()
	_arc_statuses.clear()
	var errors := CatalogScript.validate(_catalog)
	if not errors.is_empty():
		_objective_title.text = "The star map is unavailable"
		_objective_body.text = "Return to the Art Castle and try the journal again."
		return

	var objective := _objective_presentation()
	_objective_title.text = str(objective.get("title", "Begin at the Art Castle"))
	_objective_body.text = _objective_summary(objective)

	var arcs: Array = _catalog.get("kingdom_arcs", [])
	for arc_index in arcs.size():
		var arc: Dictionary = arcs[arc_index]
		var status := _arc_status(arc, arc_index, objective)
		_arc_statuses[str(arc.get("id", ""))] = status
		_card_container.add_child(_build_arc_card(arc, status, objective))


func _build_arc_card(arc: Dictionary, status: String, objective: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "KingdomCard_%s" % str(arc.get("id", "unknown")).capitalize()
	card.tooltip_text = "%s — %s" % [arc.get("title", "Kingdom"), _status_label(status)]
	card.add_theme_stylebox_override("panel", _panel_style(_status_fill(status), 15, 2, _status_accent(status)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	box.add_child(heading)
	var sequence := _label("%02d" % int(arc.get("order", 0)), 26, _status_accent(status))
	sequence.custom_minimum_size.x = 42
	sequence.tooltip_text = "Kingdom %d of 3" % int(arc.get("order", 0))
	heading.add_child(sequence)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(titles)
	titles.add_child(_label(str(arc.get("title", "Kingdom")), 23, TEXT))
	titles.add_child(_label(str(arc.get("subtitle", arc.get("theme", ""))), 15, MUTED))
	var status_badge := _label(_status_label(status), 14, _status_accent(status))
	status_badge.tooltip_text = "Journey status: %s" % _status_label(status).to_lower()
	heading.add_child(status_badge)

	box.add_child(_fact("PURPOSE", str(arc.get("purpose", "")), CYAN))
	box.add_child(_fact("WHY THIS OPENS THE NEXT ROAD", str(arc.get("story_reason", "")), STAR_GOLD))
	var dialogue: Variant = arc.get("arrival_dialogue", {})
	if dialogue is Dictionary:
		var authored := CatalogScript.localized_text(dialogue, _audience_mode)
		box.add_child(_fact(str(dialogue.get("speaker", "Guide")).to_upper(), authored, ROSE))

	var separator := HSeparator.new()
	separator.modulate = Color(CYAN, 0.28)
	box.add_child(separator)
	for quest in arc.get("quests", []):
		if quest is Dictionary:
			box.add_child(_build_quest(quest, objective))
	return card


func _build_quest(quest: Dictionary, objective: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var quest_status := _quest_status(str(quest.get("id", "")), objective)
	box.add_child(_label("QUEST %d  ·  %s  ·  %s" % [int(quest.get("order", 0)), quest.get("title", ""), _status_label(quest_status)], 16, _status_accent(quest_status)))
	box.add_child(_fact("Quest purpose", str(quest.get("purpose", "")), CYAN))
	box.add_child(_fact("Story reason", str(quest.get("story_reason", "")), STAR_GOLD))
	for task in quest.get("tasks", []):
		if not task is Dictionary:
			continue
		var task_status := _task_status(str(task.get("id", "")), objective)
		var task_box := VBoxContainer.new()
		task_box.add_theme_constant_override("separation", 2)
		task_box.add_theme_constant_override("margin_left", 0)
		task_box.add_child(_label("    %s  Task %d: %s" % [_status_glyph(task_status), int(task.get("order", 0)), task.get("title", "")], 15, TEXT))
		task_box.add_child(_label("       PURPOSE — %s" % str(task.get("purpose", "")), 14, MUTED))
		task_box.add_child(_label("       REASON — %s" % str(task.get("story_reason", "")), 14, MUTED))
		for child in task_box.get_children():
			if child is Label:
				child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(task_box)
	return box


func _objective_presentation() -> Dictionary:
	if _tracker != null and _tracker.has_method("current_objective"):
		var tracked: Variant = _tracker.call("current_objective")
		if tracked is Dictionary:
			var result: Dictionary = tracked.duplicate(true)
			if result.get("dialogue", null) is Dictionary:
				result["authored_dialogue"] = CatalogScript.localized_text(result["dialogue"], _audience_mode)
			return result

	# Tracker-free mode is intentionally coarse. It derives only completed
	# treasures from JourneyState and never guesses that an individual task ran.
	for arc in _catalog.get("kingdom_arcs", []):
		if arc is Dictionary and not _state_has_arc_treasure(arc):
			return {
				"kind": "arc",
				"arc_id": arc.get("id", ""),
				"title": "Continue to %s" % arc.get("title", "the next kingdom"),
				"purpose": arc.get("purpose", ""),
				"story_reason": arc.get("story_reason", ""),
			}
	var finale: Dictionary = _catalog.get("finale", {})
	return {
		"kind": "finale",
		"id": finale.get("completion_id", ""),
		"title": finale.get("title", "Return to the Crown of Life celebration"),
		"purpose": finale.get("purpose", ""),
		"story_reason": finale.get("story_reason", ""),
	}


func _objective_summary(objective: Dictionary) -> String:
	var lines := PackedStringArray()
	var action := str(objective.get("mechanic_action", "")).strip_edges()
	if not action.is_empty():
		lines.append(action)
	var purpose := str(objective.get("purpose", "")).strip_edges()
	if not purpose.is_empty():
		lines.append("Purpose: %s" % purpose)
	var reason := str(objective.get("story_reason", "")).strip_edges()
	if not reason.is_empty():
		lines.append("Story reason: %s" % reason)
	var authored := str(objective.get("authored_dialogue", "")).strip_edges()
	if not authored.is_empty():
		lines.append(authored)
	return "\n".join(lines)


func _arc_status(arc: Dictionary, arc_index: int, objective: Dictionary) -> String:
	var arc_id := str(arc.get("id", ""))
	if _tracker != null and _tracker.has_method("is_arc_complete"):
		if bool(_tracker.call("is_arc_complete", arc_id)):
			return "completed"
		if str(objective.get("arc_id", "")) == arc_id:
			return "current"
		if _tracker.has_method("is_arc_ready") and bool(_tracker.call("is_arc_ready", arc_id)):
			return "current"
		return "locked"
	if _state_has_arc_treasure(arc):
		return "completed"
	for previous_index in arc_index:
		if not _state_has_arc_treasure(_catalog.get("kingdom_arcs", [])[previous_index]):
			return "locked"
	return "current"


func _quest_status(quest_id: String, objective: Dictionary) -> String:
	if _tracker == null:
		return "not_tracked"
	if _tracker.has_method("is_quest_complete") and bool(_tracker.call("is_quest_complete", quest_id)):
		return "completed"
	if str(objective.get("quest_id", "")) == quest_id:
		return "current"
	if _tracker.has_method("is_quest_ready") and bool(_tracker.call("is_quest_ready", quest_id)):
		return "current"
	return "locked"


func _task_status(task_id: String, objective: Dictionary) -> String:
	if _tracker == null:
		return "not_tracked"
	if _tracker.has_method("is_task_complete") and bool(_tracker.call("is_task_complete", task_id)):
		return "completed"
	return "current" if str(objective.get("id", "")) == task_id else "locked"


func _state_has_arc_treasure(arc: Dictionary) -> bool:
	if _journey_state == null or not _journey_state.has_method("has_treasure"):
		return false
	var treasure_id := str(arc.get("reward_id", "")).trim_prefix("treasure.")
	return bool(_journey_state.call("has_treasure", treasure_id))


func _resolve_audience_mode(requested: String) -> String:
	if requested in ["faith", "universal"]:
		return requested
	if _journey_state != null:
		for property in _journey_state.get_property_list():
			if str(property.get("name", "")) == "audience_mode":
				return "universal" if str(_journey_state.get("audience_mode")) == "universal" else "faith"
	return "faith"


func _on_back_pressed() -> bool:
	if _campaign != null and _campaign.has_method("return_to_campaign"):
		if bool(_campaign.call("return_to_campaign")):
			return true
	if ResourceLoader.exists(CASTLE_SCENE) and get_tree() != null:
		return get_tree().change_scene_to_file(CASTLE_SCENE) == OK
	return false


func kingdom_card_count() -> int:
	return _card_container.get_child_count() if _card_container != null else 0


func arc_status(arc_id: String) -> String:
	return str(_arc_statuses.get(arc_id, "unknown"))


func guardian_text(arc_id: String) -> String:
	var arc := CatalogScript.arc_by_id(_catalog, arc_id)
	var dialogue: Variant = arc.get("arrival_dialogue", {})
	return CatalogScript.localized_text(dialogue, _audience_mode) if dialogue is Dictionary else ""


func visible_text() -> String:
	var lines := PackedStringArray()
	_collect_label_text(self, lines)
	return "\n".join(lines)


func _collect_label_text(node: Node, lines: PackedStringArray) -> void:
	if node is Label:
		lines.append(node.text)
	elif node is Button:
		lines.append(node.text)
	for child in node.get_children():
		_collect_label_text(child, lines)


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _fact(caption: String, value: String, accent: Color) -> Label:
	return _label("%s — %s" % [caption, value], 15, accent)


func _status_label(status: String) -> String:
	match status:
		"completed": return "COMPLETED"
		"current": return "CURRENT"
		"locked": return "LOCKED"
		"not_tracked": return "NOT TRACKED"
		_: return "STATUS UNKNOWN"


func _status_glyph(status: String) -> String:
	match status:
		"completed": return "[COMPLETE]"
		"current": return "[CURRENT]"
		"locked": return "[LOCKED]"
		_: return "[NOT TRACKED]"


func _status_accent(status: String) -> Color:
	match status:
		"completed": return MINT
		"current": return STAR_GOLD
		"locked": return MUTED
		_: return CYAN


func _status_fill(status: String) -> Color:
	match status:
		"completed": return Color("#16394aee")
		"current": return GLASS
		"locked": return Color("#151d36e8")
		_: return Color("#132a48e8")


func _panel_style(fill: Color, radius: int, border_width: int, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
