@tool
extends EditorPlugin

const DockScript = preload("res://addons/design_supervisor/design_supervisor_dock.gd")
const BridgeScript = preload("res://addons/design_supervisor/design_supervisor_bridge.gd")
const DATA_DIR := "res://.godot/design_supervisor"
const HISTORY_PATH := DATA_DIR + "/history.json"
const FEEDBACK_PATH := DATA_DIR + "/feedback.json"

var _dock: DesignSupervisorDock
var _bridge: DesignSupervisorBridge
var _applied_revision := 1
var _draft: Dictionary = {}
var _history: Array = []
var _feedback: Array = []


func _enter_tree() -> void:
	_load_persistent_state()
	_dock = DockScript.new()
	_dock.name = "Design Supervisor"
	_dock.configure(self)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)

	_bridge = BridgeScript.new()
	_bridge.configure(self)
	add_child(_bridge)
	var result := _bridge.start()
	if result.get("ok", false):
		_dock.set_connection_token(result.token, result.port)
	else:
		_dock.show_bridge_error(result.error)
	_on_selection_changed()


func _exit_tree() -> void:
	if not _draft.is_empty():
		_discard_draft_internal()
	if is_instance_valid(_bridge):
		_bridge.stop()
		_bridge.queue_free()
	var selection := get_editor_interface().get_selection()
	if selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.disconnect(_on_selection_changed)
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()


func _on_selection_changed() -> void:
	if not _draft.is_empty():
		var draft_node: Node3D = _draft.get("node")
		var selected := _selected_node3d()
		if selected != draft_node:
			_discard_draft_internal()
	_refresh_dock()


func _selected_node3d() -> Node3D:
	for node in get_editor_interface().get_selection().get_selected_nodes():
		if node is Node3D:
			return node
	return null


func _refresh_dock() -> void:
	if is_instance_valid(_dock):
		_dock.set_state(_state_payload())


func _state_payload() -> Dictionary:
	var node := _selected_node3d()
	return {
		"project": ProjectSettings.get_setting("application/config/name", "Godot Project"),
		"scene":
		(
			get_editor_interface().get_edited_scene_root().scene_file_path
			if get_editor_interface().get_edited_scene_root()
			else ""
		),
		"applied_revision": _applied_revision,
		"selected": _node_payload(node) if node else {},
		"draft": _draft_payload()
	}


func _node_payload(node: Node3D) -> Dictionary:
	return {
		"design_id": _design_id(node),
		"name": node.name,
		"type": node.get_class(),
		"path": String(node.get_path()),
		"transform": _transform_payload(node.transform),
		"global_position": _vector_payload(node.global_position)
	}


func _draft_payload() -> Dictionary:
	if _draft.is_empty():
		return {}
	return {
		"draft_id": _draft.draft_id,
		"design_id": _draft.design_id,
		"base_revision": _draft.base_revision,
		"base_transform": _draft.base_payload,
		"proposed_transform": _draft.proposed_payload
	}


func _transform_payload(value: Transform3D) -> Dictionary:
	return {
		"position": _vector_payload(value.origin),
		"rotation_degrees": _vector_payload(value.basis.get_euler() * 180.0 / PI),
		"scale": _vector_payload(value.basis.get_scale())
	}


func _vector_payload(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _payload_transform(payload: Dictionary) -> Transform3D:
	var position := _payload_vector(payload.get("position", [0.0, 0.0, 0.0]))
	var rotation := _payload_vector(payload.get("rotation_degrees", [0.0, 0.0, 0.0])) * PI / 180.0
	var scale := _payload_vector(payload.get("scale", [1.0, 1.0, 1.0]))
	return Transform3D(Basis.from_euler(rotation).scaled(scale), position)


func _payload_vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _design_id(node: Node3D) -> String:
	if node.has_meta("design_supervisor_id"):
		return String(node.get_meta("design_supervisor_id"))
	var root := get_editor_interface().get_edited_scene_root()
	var scene := root.scene_file_path if root else "unsaved-scene"
	return "path:%s#%s" % [scene, node.get_path()]


func register_selected_id() -> Dictionary:
	var node := _selected_node3d()
	if node == null:
		return _error("Select a Node3D first.")
	if node.has_meta("design_supervisor_id"):
		return {
			"ok": true, "design_id": _design_id(node), "message": "Object already has a stable ID."
		}
	var design_id := "vds_%s" % _uuid()
	var undo := get_undo_redo()
	undo.create_action("Register Visual Design Supervisor ID")
	undo.add_do_method(node, "set_meta", "design_supervisor_id", design_id)
	undo.add_undo_method(node, "remove_meta", "design_supervisor_id")
	undo.commit_action()
	_refresh_dock()
	_dock.show_status("Registered stable ID %s." % design_id, false)
	return {"ok": true, "design_id": design_id}


func stage_selected_transform(transform: Dictionary) -> Dictionary:
	var node := _selected_node3d()
	if node == null:
		return _error("Select a Node3D first.")
	return _stage_transform(node, transform)


func _stage_transform(node: Node3D, transform: Dictionary) -> Dictionary:
	var validation := _validate_transform_payload(transform)
	if not validation.ok:
		return validation
	if not _draft.is_empty():
		_discard_draft_internal()
	var proposed := _payload_transform(transform)
	_draft = {
		"draft_id": "draft_%s" % _uuid(),
		"design_id": _design_id(node),
		"node": node,
		"base_revision": _applied_revision,
		"base_transform": node.transform,
		"base_payload": _transform_payload(node.transform),
		"proposed_transform": proposed,
		"proposed_payload": _transform_payload(proposed)
	}
	node.transform = proposed
	_refresh_dock()
	_dock.show_status("LIVE DRAFT PREVIEW. Apply or discard before saving the scene.", false)
	return {"ok": true, "draft": _draft_payload(), "warnings": validation.warnings}


func apply_current_draft() -> Dictionary:
	return _apply_draft(String(_draft.get("draft_id", "")), int(_draft.get("base_revision", -1)))


func _apply_draft(draft_id: String, base_revision: int) -> Dictionary:
	if _draft.is_empty() or _draft.draft_id != draft_id:
		return _error("Draft does not exist or is no longer active.")
	if base_revision != _applied_revision or base_revision != int(_draft.base_revision):
		return _error("Draft is stale. Discard it and create a new preview.")
	var validation := _validate_transform_payload(_draft.proposed_payload)
	if not validation.ok:
		return validation
	var node: Node3D = _draft.node
	if not is_instance_valid(node):
		return _error("The draft object no longer exists.")
	var base: Transform3D = _draft.base_transform
	var proposed: Transform3D = _draft.proposed_transform
	var record := {
		"revision": _applied_revision + 1,
		"timestamp": Time.get_datetime_string_from_system(true),
		"design_id": _draft.design_id,
		"object_name": node.name,
		"before": _draft.base_payload,
		"after": _draft.proposed_payload
	}
	node.transform = base
	var undo := get_undo_redo()
	undo.create_action("Apply Visual Design Supervisor Draft")
	undo.add_do_property(node, "transform", proposed)
	undo.add_undo_property(node, "transform", base)
	undo.commit_action()
	_applied_revision += 1
	_history.append(record)
	_save_json(HISTORY_PATH, {"applied_revision": _applied_revision, "items": _history})
	_draft = {}
	_refresh_dock()
	_dock.show_status("Applied revision %d. Godot Undo is available." % _applied_revision, false)
	return {"ok": true, "applied_revision": _applied_revision, "change": record}


func discard_current_draft() -> Dictionary:
	if _draft.is_empty():
		return _error("There is no active draft.")
	_discard_draft_internal()
	_refresh_dock()
	_dock.show_status("Draft discarded; original transform restored.", false)
	return {"ok": true, "applied_revision": _applied_revision}


func _discard_draft_internal() -> void:
	if _draft.is_empty():
		return
	var node: Node3D = _draft.get("node")
	if is_instance_valid(node):
		node.transform = _draft.base_transform
	_draft = {}


func undo_last_change() -> Dictionary:
	if get_undo_redo().has_undo():
		get_undo_redo().undo()
		_dock.show_status("Godot undo completed.", false)
		_refresh_dock()
		return {"ok": true}
	return _error("Godot has no action to undo.")


func measure_selected_objects() -> Dictionary:
	var nodes: Array[Node3D] = []
	for node in get_editor_interface().get_selection().get_selected_nodes():
		if node is Node3D:
			nodes.append(node)
	if nodes.size() != 2:
		return _error("Select exactly two Node3D objects to measure them.")
	var distance := nodes[0].global_position.distance_to(nodes[1].global_position)
	var result := {
		"ok": true,
		"from": _node_payload(nodes[0]),
		"to": _node_payload(nodes[1]),
		"distance": distance
	}
	_dock.show_status("Distance: %.4f project units." % distance, false)
	return result


func queue_feedback(message: String) -> Dictionary:
	return _submit_feedback({"message": message})


func _submit_feedback(arguments: Dictionary) -> Dictionary:
	var message := String(arguments.get("message", "")).strip_edges()
	if message.is_empty():
		return _error("Feedback message cannot be empty.")
	var selected := _selected_node3d()
	var item := {
		"feedback_id": "feedback_%s" % _uuid(),
		"timestamp": Time.get_datetime_string_from_system(true),
		"status": "queued",
		"message": message,
		"applied_revision": _applied_revision,
		"selected": _node_payload(selected) if selected else {},
		"draft": _draft_payload()
	}
	_feedback.append(item)
	_save_json(FEEDBACK_PATH, {"items": _feedback})
	if is_instance_valid(_dock):
		_dock.show_status("Feedback queued for Codex: %s" % item.feedback_id, false)
	return {"ok": true, "feedback": item}


func _list_objects() -> Dictionary:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return {"ok": true, "objects": [], "applied_revision": _applied_revision}
	var objects: Array = []
	_collect_node3d(root, objects)
	return {"ok": true, "objects": objects, "applied_revision": _applied_revision}


func _collect_node3d(node: Node, output: Array) -> void:
	if node is Node3D:
		output.append(_node_payload(node))
	for child in node.get_children():
		_collect_node3d(child, output)


func _find_node(design_id: String) -> Node3D:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node := stack.pop_back()
		if node is Node3D and _design_id(node) == design_id:
			return node
		stack.append_array(node.get_children())
	return null


func _validate_transform_payload(transform: Dictionary) -> Dictionary:
	var warnings: Array[String] = []
	for key in ["position", "rotation_degrees", "scale"]:
		var value = transform.get(key)
		if not value is Array or value.size() != 3:
			return _error("%s must contain exactly three numbers." % key)
		for component in value:
			if not component is int and not component is float:
				return _error("%s contains a non-numeric value." % key)
			if is_nan(float(component)) or is_inf(float(component)):
				return _error("%s contains NaN or infinity." % key)
	var position := _payload_vector(transform.position)
	var scale := _payload_vector(transform.scale)
	if position.length() > 1000000.0:
		return _error("Position is outside the allowed safety range.")
	if abs(scale.x) < 0.00001 or abs(scale.y) < 0.00001 or abs(scale.z) < 0.00001:
		return _error("Scale cannot be zero.")
	if abs(scale.x) > 1000.0 or abs(scale.y) > 1000.0 or abs(scale.z) > 1000.0:
		return _error("Scale exceeds the allowed safety range.")
	if scale.x < 0.0 or scale.y < 0.0 or scale.z < 0.0:
		warnings.append("Negative scale can invert faces and collision orientation.")
	return {"ok": true, "warnings": warnings}


func _capture_view() -> Dictionary:
	var viewport := get_editor_interface().get_editor_viewport_3d(0)
	if viewport == null or viewport.get_texture() == null:
		return _error("The primary 3D editor viewport is unavailable.")
	var image := viewport.get_texture().get_image()
	if image == null:
		return _error("Could not capture the 3D editor viewport.")
	return {
		"ok": true,
		"mime_type": "image/png",
		"data": Marshalls.raw_to_base64(image.save_png_to_buffer()),
		"applied_revision": _applied_revision
	}


func handle_bridge_action(action: String, arguments: Dictionary) -> Dictionary:
	match action:
		"get_state":
			return {"ok": true, "state": _state_payload()}
		"list_objects":
			return _list_objects()
		"register_selected":
			return register_selected_id()
		"stage_transform":
			var design_id := String(arguments.get("design_id", ""))
			var node := _selected_node3d() if design_id.is_empty() else _find_node(design_id)
			if node == null:
				return _error(
					"Design object was not found. Select it in Godot or refresh the object list."
				)
			return _stage_transform(node, arguments.get("transform", {}))
		"validate_draft":
			if _draft.is_empty():
				return _error("There is no active draft.")
			var result := _validate_transform_payload(_draft.proposed_payload)
			result["draft"] = _draft_payload()
			return result
		"apply_draft":
			return _apply_draft(
				String(arguments.get("draft_id", "")), int(arguments.get("base_revision", -1))
			)
		"discard_draft":
			return discard_current_draft()
		"measure_selected":
			return measure_selected_objects()
		"capture_view":
			return _capture_view()
		"submit_feedback":
			return _submit_feedback(arguments)
		"list_feedback":
			return {"ok": true, "items": _feedback}
		"get_history":
			return {"ok": true, "applied_revision": _applied_revision, "items": _history}
		_:
			return _error("Unsupported bridge action: %s" % action)


func _uuid() -> String:
	return (
		Marshalls
		. raw_to_base64(Crypto.new().generate_random_bytes(12))
		. replace("/", "_")
		. replace("+", "-")
		. replace("=", "")
	)


func _error(message: String) -> Dictionary:
	if is_instance_valid(_dock):
		_dock.show_status(message, true)
	return {"ok": false, "error": message}


func _load_persistent_state() -> void:
	var history_data := _load_json(HISTORY_PATH)
	_applied_revision = int(history_data.get("applied_revision", 1))
	_history = history_data.get("items", [])
	_feedback = _load_json(FEEDBACK_PATH).get("items", [])


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _save_json(path: String, payload: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA_DIR))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  "))
