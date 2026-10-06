@tool
class_name DesignSupervisorDock
extends VBoxContainer

var _plugin: EditorPlugin
var _object_label: Label
var _id_label: Label
var _revision_label: Label
var _draft_label: Label
var _token_edit: LineEdit
var _status: RichTextLabel
var _feedback: LineEdit
var _position: Array[SpinBox] = []
var _rotation: Array[SpinBox] = []
var _scale: Array[SpinBox] = []
var _apply_button: Button
var _discard_button: Button


func configure(plugin: EditorPlugin) -> void:
	_plugin = plugin
	_build_ui()


func _build_ui() -> void:
	custom_minimum_size = Vector2(320, 420)
	var title := Label.new()
	title.text = "Visual Design Supervisor"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	_object_label = Label.new()
	_object_label.text = "Select a Node3D"
	add_child(_object_label)
	_id_label = Label.new()
	_id_label.text = "ID: —"
	_id_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_id_label)
	_revision_label = Label.new()
	_revision_label.text = "Applied revision: 1"
	add_child(_revision_label)
	_draft_label = Label.new()
	_draft_label.text = "Draft: none"
	add_child(_draft_label)

	var register_button := Button.new()
	register_button.text = "Register Stable ID"
	register_button.pressed.connect(func(): _plugin.register_selected_id())
	add_child(register_button)

	var grid := GridContainer.new()
	grid.columns = 4
	add_child(grid)
	for heading in ["Transform", "X", "Y", "Z"]:
		var label := Label.new()
		label.text = heading
		grid.add_child(label)
	_position = _add_vector_row(grid, "Position", -1000000.0, 1000000.0, 0.01, 0.0)
	_rotation = _add_vector_row(grid, "Rotation °", -36000.0, 36000.0, 0.1, 0.0)
	_scale = _add_vector_row(grid, "Scale", -1000.0, 1000.0, 0.01, 1.0)

	var preview_button := Button.new()
	preview_button.text = "Stage Live Preview"
	preview_button.pressed.connect(_on_preview)
	add_child(preview_button)

	var action_row := HBoxContainer.new()
	add_child(action_row)
	_apply_button = Button.new()
	_apply_button.text = "Apply Draft"
	_apply_button.disabled = true
	_apply_button.pressed.connect(func(): _plugin.apply_current_draft())
	action_row.add_child(_apply_button)
	_discard_button = Button.new()
	_discard_button.text = "Discard"
	_discard_button.disabled = true
	_discard_button.pressed.connect(func(): _plugin.discard_current_draft())
	action_row.add_child(_discard_button)
	var undo_button := Button.new()
	undo_button.text = "Godot Undo"
	undo_button.pressed.connect(func(): _plugin.undo_last_change())
	action_row.add_child(undo_button)

	var measure_button := Button.new()
	measure_button.text = "Measure Selected Objects"
	measure_button.pressed.connect(func(): _plugin.measure_selected_objects())
	add_child(measure_button)

	add_child(HSeparator.new())
	var connection_title := Label.new()
	connection_title.text = "Codex connection token"
	add_child(connection_title)
	var token_row := HBoxContainer.new()
	add_child(token_row)
	_token_edit = LineEdit.new()
	_token_edit.editable = false
	_token_edit.secret = true
	_token_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	token_row.add_child(_token_edit)
	var copy_button := Button.new()
	copy_button.text = "Copy"
	copy_button.pressed.connect(
		func():
			DisplayServer.clipboard_set(_token_edit.text)
			show_status("Connection token copied. Use it with connect_supervisor.", false)
	)
	token_row.add_child(copy_button)

	_feedback = LineEdit.new()
	_feedback.placeholder_text = "Tell Codex what should change…"
	add_child(_feedback)
	var feedback_button := Button.new()
	feedback_button.text = "Queue Feedback for Codex"
	feedback_button.pressed.connect(_on_feedback)
	add_child(feedback_button)

	_status = RichTextLabel.new()
	_status.fit_content = true
	_status.custom_minimum_size = Vector2(0, 70)
	_status.text = "Ready. Select a Node3D."
	add_child(_status)


func _add_vector_row(
	grid: GridContainer,
	label_text: String,
	min_value: float,
	max_value: float,
	step: float,
	default_value: float
) -> Array[SpinBox]:
	var label := Label.new()
	label.text = label_text
	grid.add_child(label)
	var boxes: Array[SpinBox] = []
	for _axis in range(3):
		var box := SpinBox.new()
		box.min_value = min_value
		box.max_value = max_value
		box.step = step
		box.value = default_value
		box.allow_greater = false
		box.allow_lesser = false
		grid.add_child(box)
		boxes.append(box)
	return boxes


func set_connection_token(token: String, port: int) -> void:
	_token_edit.text = token
	show_status("Local bridge ready on 127.0.0.1:%d." % port, false)


func show_bridge_error(message: String) -> void:
	show_status(message, true)


func set_state(state: Dictionary) -> void:
	var selected: Dictionary = state.get("selected", {})
	_object_label.text = selected.get("name", "Select a Node3D")
	_id_label.text = "ID: %s" % selected.get("design_id", "—")
	_revision_label.text = "Applied revision: %d" % int(state.get("applied_revision", 1))
	var draft: Dictionary = state.get("draft", {})
	if draft.is_empty():
		_draft_label.text = "Draft: none"
		_apply_button.disabled = true
		_discard_button.disabled = true
	else:
		_draft_label.text = "Draft: %s (LIVE PREVIEW)" % draft.get("draft_id", "unknown")
		_apply_button.disabled = false
		_discard_button.disabled = false
	if selected.has("transform"):
		_set_boxes(_position, selected.transform.position)
		_set_boxes(_rotation, selected.transform.rotation_degrees)
		_set_boxes(_scale, selected.transform.scale)


func show_status(message: String, is_error: bool) -> void:
	_status.text = ("[color=red]%s[/color]" if is_error else "%s") % message


func _set_boxes(boxes: Array[SpinBox], values: Array) -> void:
	for index in range(min(3, values.size())):
		boxes[index].value = float(values[index])


func _box_values(boxes: Array[SpinBox]) -> Array[float]:
	return [boxes[0].value, boxes[1].value, boxes[2].value]


func _on_preview() -> void:
	_plugin.stage_selected_transform(
		{
			"position": _box_values(_position),
			"rotation_degrees": _box_values(_rotation),
			"scale": _box_values(_scale)
		}
	)


func _on_feedback() -> void:
	var message := _feedback.text.strip_edges()
	if message.is_empty():
		show_status("Write feedback before queuing it.", true)
		return
	_plugin.queue_feedback(message)
	_feedback.clear()
