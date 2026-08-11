extends Node

const SemanticObjectFactory := preload("res://scripts/creation_world/semantic_object_factory.gd")

# Runtime reconciler for living artwork worlds. It deliberately spreads object
# creation across frames and preloads imported assets on worker threads so a
# detailed painting cannot freeze the game while dozens of actors are built.

signal generation_started(revision: int, total_operations: int)
signal generation_progress(revision: int, completed: int, total: int, object_id: String)
signal generation_finished(revision: int, total: int)
signal generation_failed(revision: int, object_id: String, message: String)

@export var frame_budget_usec := 3200
@export var max_operations_per_frame := 2

var _spawn_actor: Callable
var _update_actor: Callable
var _remove_actor: Callable
var _actor_ids: Callable
var _priority_origin: Callable
var _queue: Array[Dictionary] = []
var _requested_resources: Dictionary = {}
var _revision := 0
var _total := 0
var _completed := 0
var _active := false


func configure(spawn_actor: Callable, update_actor: Callable,
		remove_actor: Callable, actor_ids: Callable) -> void:
	_spawn_actor = spawn_actor
	_update_actor = update_actor
	_remove_actor = remove_actor
	_actor_ids = actor_ids


# Optional. When supplied, pending work is ordered by distance from this point
# (normally the player) so the objects the player is walking toward finish
# first and the world assembles around them rather than in manifest order.
func set_priority_origin(origin_provider: Callable) -> void:
	_priority_origin = origin_provider


func reconcile(manifest: Dictionary) -> int:
	_revision += 1
	_queue.clear()
	_total = 0
	_completed = 0
	var current_ids: Dictionary = {}
	if _actor_ids.is_valid():
		for actor_id in _actor_ids.call():
			current_ids[str(actor_id)] = true
	var desired_ids := {}
	var animations := _records_by_id(manifest.get("animations", []))
	var interactions := _records_by_id(manifest.get("interactions", []))

	for collection_key in ["objects", "characters"]:
		var collection = manifest.get(collection_key, [])
		if not collection is Array:
			continue
		for value in collection:
			if not value is Dictionary:
				continue
			var spec: Dictionary = value.duplicate(true)
			var object_id := str(spec.get("id", "")).validate_node_name()
			if object_id.is_empty() or desired_ids.has(object_id):
				continue
			if collection_key == "characters" and str(spec.get("type", "")).is_empty():
				spec["type"] = "character"
			desired_ids[object_id] = true
			var operation := {
				"revision": _revision,
				"kind": "update" if current_ids.has(object_id) else "spawn",
				"id": object_id,
				"spec": spec,
				"animation": animations.get(object_id, {}),
				"interaction": interactions.get(object_id, {}),
				"asset_path": SemanticObjectFactory.asset_path_for_spec(spec),
				"world_position": _world_position_for(spec),
			}
			_queue.append(operation)
			_request_asset(str(operation["asset_path"]))

	for actor_id in current_ids:
		if not desired_ids.has(actor_id):
			_queue.append({
				"revision": _revision,
				"kind": "remove",
				"id": str(actor_id),
				"asset_path": "",
			})

	_sort_queue_by_priority()
	_total = _queue.size()
	_active = _total > 0
	set_process(_active)
	generation_started.emit(_revision, _total)
	if not _active:
		generation_finished.emit(_revision, 0)
	return _revision


func is_idle() -> bool:
	return not _active and _queue.is_empty()


func pending_count() -> int:
	return _queue.size()


func current_revision() -> int:
	return _revision


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if not _active:
		return
	var deadline := Time.get_ticks_usec() + frame_budget_usec
	var completed_this_frame := 0
	var deferred_assets := 0
	while not _queue.is_empty() and completed_this_frame < max_operations_per_frame \
			and Time.get_ticks_usec() <= deadline:
		var operation: Dictionary = _queue.pop_front()
		if int(operation.get("revision", -1)) != _revision:
			continue
		var asset_path := str(operation.get("asset_path", ""))
		if not asset_path.is_empty() and not _asset_is_ready(asset_path):
			_queue.append(operation)
			deferred_assets += 1
			if deferred_assets >= _queue.size():
				break
			continue
		_execute(operation)
		completed_this_frame += 1
		_completed += 1
		generation_progress.emit(
			_revision, _completed, _total, str(operation.get("id", "")))

	if _queue.is_empty():
		_active = false
		set_process(false)
		generation_finished.emit(_revision, _total)


func _execute(operation: Dictionary) -> void:
	var object_id := str(operation.get("id", ""))
	var kind := str(operation.get("kind", ""))
	if kind == "remove":
		if _remove_actor.is_valid():
			_remove_actor.call(object_id)
		return
	var callable := _update_actor if kind == "update" else _spawn_actor
	if not callable.is_valid():
		generation_failed.emit(_revision, object_id, "The world actor factory is unavailable.")
		return
	var result = callable.call(
		operation.get("spec", {}),
		operation.get("animation", {}),
		operation.get("interaction", {}))
	if result == null:
		generation_failed.emit(_revision, object_id, "The 3D actor could not be created.")


func _request_asset(path: String) -> void:
	if path.is_empty() or _requested_resources.has(path) or not ResourceLoader.exists(path):
		return
	_requested_resources[path] = ResourceLoader.load_threaded_request(path)


func _asset_is_ready(path: String) -> bool:
	if path.is_empty() or not ResourceLoader.exists(path):
		return true
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return false
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		# Pulling the completed resource registers it in the loader cache; the
		# semantic factory's normal load() is then immediate.
		ResourceLoader.load_threaded_get(path)
	return true


func _sort_queue_by_priority() -> void:
	if not _priority_origin.is_valid():
		return
	var origin = _priority_origin.call()
	if not origin is Vector3:
		return
	var focus: Vector3 = origin
	# Removals are cheap and free memory, so they stay ahead of construction.
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_remove := str(a.get("kind", "")) == "remove"
		var b_remove := str(b.get("kind", "")) == "remove"
		if a_remove != b_remove:
			return a_remove
		return _priority_distance(a, focus) < _priority_distance(b, focus))


func _priority_distance(operation: Dictionary, focus: Vector3) -> float:
	var position = operation.get("world_position", null)
	if position is Vector3:
		return focus.distance_squared_to(position)
	return INF


# A coarse world-space guess from the manifest's normalized coordinates. It is
# only ever used to order the queue, never to place the finished actor.
func _world_position_for(spec: Dictionary) -> Vector3:
	var normalized = spec.get("normalized_position", spec.get("position", null))
	var nx := 0.5
	var ny := 0.5
	if normalized is Dictionary:
		nx = float(normalized.get("x", 0.5))
		ny = float(normalized.get("y", 0.5))
	elif normalized is Array and normalized.size() >= 2:
		nx = float(normalized[0])
		ny = float(normalized[1])
	else:
		var bounds := SemanticObjectFactory.normalized_bounds(spec)
		nx = bounds.get_center().x
		ny = bounds.get_center().y
	return Vector3(lerpf(-16.0, 16.0, clampf(nx, 0.0, 1.0)), 0.0,
		lerpf(-13.0, 8.0, clampf(ny, 0.0, 1.0)))


func _records_by_id(raw) -> Dictionary:
	var output := {}
	if not raw is Array:
		return output
	for value in raw:
		if value is Dictionary:
			var object_id := str(value.get("object_id", ""))
			if not object_id.is_empty():
				output[object_id] = value
	return output
