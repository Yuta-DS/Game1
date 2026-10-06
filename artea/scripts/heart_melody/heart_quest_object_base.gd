class_name HeartQuestObjectBase
extends Node3D
signal completed(object_id: String)
signal feedback(message: String)
signal hint_requested(object_id: String)
var object_id := ""
var actions: Array[String] = []
var handler: Callable

func configure(id: String, allowed_actions: Array[String], callback: Callable) -> void:
	object_id = id
	actions = allowed_actions.duplicate()
	handler = callback

func available_actions() -> Array[String]:
	return actions.duplicate()

func interact(action: String) -> bool:
	if object_id.is_empty() or action not in actions or not handler.is_valid(): return false
	var accepted: bool = handler.call(action)
	if accepted: completed.emit(object_id)
	else: feedback.emit("This action is not ready. Your progress has not been removed.")
	return accepted

func request_hint() -> void:
	hint_requested.emit(object_id)
