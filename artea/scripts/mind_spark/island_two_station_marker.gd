extends Node3D

var _station: QuestObjectBase
var _materials: Dictionary
var _has_activity := false


func bind(station: QuestObjectBase, materials: Dictionary) -> void:
	_station = station
	_materials = materials
	_station.feedback_changed.connect(_on_feedback_changed)
	_station.progress_changed.connect(_on_progress_changed)
	_station.completed.connect(_on_completed)
	_apply_state()


func _on_feedback_changed(_save_id: String, _message: String, _icon: String) -> void:
	_has_activity = true
	_apply_state()


func _on_progress_changed(_save_id: String, current: int, _total: int) -> void:
	_has_activity = _has_activity or current > 0
	_apply_state()


func _on_completed(_save_id: String, _result: Dictionary) -> void:
	_apply_state()


func _apply_state() -> void:
	if _station == null or _materials.is_empty():
		return
	var completed := bool(_station.current_state.get("completed", false))
	var progressed := int(_station.current_state.get("progress", 0)) > 0
	var active := not completed and (_has_activity or progressed)
	var beacon := get_node_or_null("MarkerStateBeacon") as MeshInstance3D
	if beacon != null:
		beacon.material_override = _materials.green_glow if completed else (
			_materials.arrival_glass if active else _materials.astral_lavender)
		beacon.scale = Vector3.ONE * (1.22 if completed else (1.08 if active else 0.88))
	var active_wings := get_node_or_null("ActiveStateWings") as Node3D
	if active_wings != null:
		active_wings.visible = active
	var completed_wings := get_node_or_null("CompletedStateWings") as Node3D
	if completed_wings != null:
		completed_wings.visible = completed
	set_meta("presentation_state", "completed" if completed else ("active" if active else "inactive"))
