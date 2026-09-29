extends Node

## Opt-in production WebGL benchmark. Enable with `?world_one_perf=1`.
## The probe owns a temporary camera, samples the same four views as the native
## benchmark, prints one machine-readable result, then removes itself.

const WARMUP_FRAMES := 90
const SAMPLE_FRAMES := 240

var _world: MindSparkWorldOne
var _camera: Camera3D
var _views: Array = []
var _view_index := 0
var _frame_index := 0
var _samples: Array[float] = []
var _draw_total := 0.0
var _primitive_total := 0.0
var _results: Array[Dictionary] = []


func configure(world: MindSparkWorldOne) -> void:
	_world = world
	call_deferred("_begin")


func _begin() -> void:
	if _world == null or not is_instance_valid(_world):
		queue_free()
		return
	var island_one_hero := _world.find_child("EchoGardenHeroBenchmark", true, false) as Node3D
	var evidence := _world.get_object_by_kind(QuestObjectDefinition.ObjectKind.EVIDENCE_SCANNER)
	if island_one_hero == null or evidence == null:
		print("WORLD_ONE_WEB_PERF_ERROR: review landmarks unavailable")
		queue_free()
		return
	_views = [
		{
			"name": "island_one_tree_court",
			"position": _world.to_local(island_one_hero.to_global(Vector3(50, 6, 100))),
			"target": _world.to_local(island_one_hero.to_global(Vector3(0, 18, 0))),
		},
		{
			"name": "island_two_evidence_court",
			"position": _world.to_local(evidence.to_global(Vector3(0, 5.5, 23))),
			"target": _world.to_local(evidence.to_global(Vector3(0, 4.2, 0))),
		},
		{"name": "island_three_stormworks", "position": Vector3(300, 27, 28),
			"target": Vector3(430, 35, 25)},
		{"name": "island_three_reflection", "position": Vector3(520, 27, 15),
			"target": Vector3(650, 34, -58)},
	]
	_camera = Camera3D.new()
	_camera.name = "WorldOneWebPerfCamera"
	_camera.near = 0.1
	_camera.far = 5000.0
	_camera.fov = 62.0
	_world.add_child(_camera)
	_activate_view()
	set_process(true)


func _process(delta: float) -> void:
	if _frame_index < WARMUP_FRAMES:
		_frame_index += 1
		return
	_samples.append(delta * 1000.0)
	_draw_total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_primitive_total += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_frame_index += 1
	if _samples.size() >= SAMPLE_FRAMES:
		_finish_view()


func _activate_view() -> void:
	var view: Dictionary = _views[_view_index]
	_camera.position = view.position
	_camera.look_at(_world.to_global(view.target), Vector3.UP)
	_camera.make_current()
	_frame_index = 0
	_samples.clear()
	_draw_total = 0.0
	_primitive_total = 0.0


func _finish_view() -> void:
	_samples.sort()
	var total := 0.0
	for value in _samples:
		total += value
	_results.append({
		"view": _views[_view_index].name,
		"frames": SAMPLE_FRAMES,
		"mean_ms": snappedf(total / SAMPLE_FRAMES, 0.001),
		"p50_ms": snappedf(_samples[SAMPLE_FRAMES / 2], 0.001),
		"p95_ms": snappedf(_samples[int(SAMPLE_FRAMES * 0.95)], 0.001),
		"p99_ms": snappedf(_samples[int(SAMPLE_FRAMES * 0.99)], 0.001),
		"mean_draws": roundi(_draw_total / SAMPLE_FRAMES),
		"mean_primitives": roundi(_primitive_total / SAMPLE_FRAMES),
	})
	_view_index += 1
	if _view_index < _views.size():
		_activate_view()
		return
	print("WORLD_ONE_WEB_PERF: %s" % JSON.stringify({
		"renderer": RenderingServer.get_current_rendering_method(),
		"viewport": "%dx%d" % [get_viewport().size.x, get_viewport().size.y],
		"static_memory_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
		"views": _results,
	}))
	_world.set_meta("web_perf_results", _results.duplicate(true))
	_world.set_meta("web_perf_probe_completed", true)
	set_process(false)
	_camera.queue_free()
	queue_free()
