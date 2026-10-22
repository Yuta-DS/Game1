extends Node

## Opt-in release-build telemetry. Copied to this test browser's /tmp only,
## and retained outside current_scene so every measured world stays real.
var _command: JavaScriptObject
var _label := ""
var _until := 0
var _sample_after := 0
var _previous := 0
var _frames: Array[float] = []
var _process_ms: Array[float] = []
var _physics_ms: Array[float] = []
var _draws: Array[float] = []
var _primitives: Array[float] = []
var _saved: Array[Dictionary] = []
var _options := {}
var _camera: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _scripts := {}
var _mesh_groups := {}
var _portrait: Camera3D

func _ready() -> void:
	set_process(false)
	_command = JavaScriptBridge.create_callback(func(args):
		_start(str(args[0]), float(args[1]), JSON.parse_string(str(args[2]))))
	JavaScriptBridge.get_interface("window").arteaFrameProfile = _command
	print("FRAME SAMPLER READY")

func _start(label: String, seconds: float, options: Dictionary) -> void:
	if not _label.is_empty(): return
	_label = label
	_options = options
	_frames.clear()
	_process_ms.clear()
	_physics_ms.clear()
	_draws.clear()
	_primitives.clear()
	_scripts.clear()
	_mesh_groups.clear()
	_camera = get_viewport().get_camera_3d()
	if _camera != null and "_yaw" in _camera:
		_yaw = _camera.get("_yaw")
		_pitch = _camera.get("_pitch")
	var scene := get_tree().current_scene
	if options.get("portrait", false):
		var milo := scene.get_node("Milo_Animations2") as Node3D
		_portrait = Camera3D.new()
		add_child(_portrait)
		_portrait.global_position = milo.global_position + milo.global_basis.z * 3.0 + milo.global_basis.x * 1.2 + Vector3.UP * 1.6
		_portrait.look_at(milo.global_position + Vector3.UP * 1.2)
		_portrait.make_current()
	if options.has("sea_view"):
		_portrait = Camera3D.new()
		_portrait.far = 4000
		add_child(_portrait)
		_portrait.global_position = Vector3(80, 85, 0) if options.sea_view == "east" else Vector3(0, 85, 80)
		_portrait.look_at(Vector3(800, 10, 0) if options.sea_view == "east" else Vector3(0, 10, 800))
		_portrait.make_current()
	for property in ["scaling_3d_scale", "msaa_3d"]:
		if options.has(property):
			_saved.append({"node": get_viewport(), "property": property, "value": get_viewport().get(property)})
			get_viewport().set(property, options[property])
	if options.get("at", "") == "melody":
		var circle := scene.get_node_or_null("ArtCastleFloatingWorld/KingdomRegions3000m/HeartKingdomPlatform/HeartMusicCircle") as Node3D
		var player := get_tree().get_first_node_in_group("Player") as CharacterBody3D
		if circle != null and player != null:
			player.global_position = circle.global_position + Vector3(0, 1, 20)
			player.velocity = Vector3.ZERO
			if _camera != null and "_yaw" in _camera:
				_camera.set("_yaw", 0.0)
				_camera.set("_pitch", -0.3)
	if options.get("render_off", false):
		_saved.append({"node": get_viewport(), "property": "disable_3d", "value": get_viewport().disable_3d})
		get_viewport().disable_3d = true
	var nodes: Array[Node] = [scene]
	while not nodes.is_empty():
		var node := nodes.pop_back() as Node
		for child in node.get_children(): nodes.append(child)
		if node is MeshInstance3D and node.is_visible_in_tree() and node.mesh != null:
			var path_parts := str(scene.get_path_to(node)).split("/")
			var group := "/".join(path_parts.slice(0, mini(2, path_parts.size() - 1)))
			_mesh_groups[group] = int(_mesh_groups.get(group, 0)) + node.mesh.get_surface_count()
		var script := node.get_script() as Script
		if script != null and (node.is_processing() or node.is_physics_processing()):
			var path := script.resource_path
			_scripts[path] = int(_scripts.get(path, 0)) + 1
		if options.get("scripts_off", false):
			_saved.append({"node": node, "process": node.is_processing(), "physics": node.is_physics_processing()})
			node.set_process(false)
			node.set_physics_process(false)
		if options.get("no_shadows", false) and node is Light3D:
			_saved.append({"node": node, "property": "shadow_enabled", "value": node.shadow_enabled})
			node.shadow_enabled = false
		if options.get("no_lights", false) and node is Light3D:
			_saved.append({"node": node, "property": "visible", "value": node.visible})
			node.visible = false
		if options.get("animations_off", false) and node is AnimationMixer:
			_saved.append({"node": node, "property": "active", "value": node.active})
			node.active = false
		if options.get("modifiers_off", false) and node is SkeletonModifier3D:
			_saved.append({"node": node, "property": "active", "value": node.active})
			node.active = false
		if options.get("skin_off", false) and node is MeshInstance3D and node.skin != null:
			_saved.append({"node": node, "property": "visible", "value": node.visible})
			node.visible = false
		if options.get("milo_script_off", false) and str(node.name) == "Milo_Animations2":
			_saved.append({"node": node, "process": node.is_processing(), "physics": node.is_physics_processing()})
			node.set_process(false)
			node.set_physics_process(false)
		if options.get("no_scatter", false) and node.has_signal("build_completed"):
			var output := node.get("output_root") as Node3D
			if output != null:
				_saved.append({"node": output, "property": "visible", "value": output.visible})
				output.visible = false
		if node is Node3D and node.name in options.get("hide_names", []):
			_saved.append({"node": node, "property": "visible", "value": node.visible})
			node.visible = false
	var cold := bool(options.get("orbit", false)) or options.has("at")
	_sample_after = Time.get_ticks_usec() + (0 if cold else 800000)
	_until = _sample_after + int(seconds * 1000000)
	_previous = Time.get_ticks_usec() if cold else 0
	set_process(true)

func _process(delta: float) -> void:
	if _options.get("orbit", false) and is_instance_valid(_camera) and "_yaw" in _camera:
		_camera.set("_yaw", float(_camera.get("_yaw")) + delta * 0.65)
	var now := Time.get_ticks_usec()
	if now < _sample_after: return
	if _previous > 0:
		_frames.append(float(now - _previous) / 1000.0)
		_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
		_physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000)
		_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_previous = now
	if now >= _until: _finish()

func _finish() -> void:
	set_process(false)
	var long_audio: Array = []
	for kind in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for player in get_tree().current_scene.find_children("*", kind, true, false):
			var stream := player.get("stream") as AudioStream
			if stream != null and stream.get_length() > 30:
				long_audio.append({"node": str(player.get_path()), "seconds": stream.get_length(),
					"mode": player.get("playback_type"), "playing": player.get("playing"), "position": player.get_playback_position()})
	var result := {"label": _label, "frames": _stats(_frames), "process_ms": _stats(_process_ms),
		"physics_ms": _stats(_physics_ms), "draws": _stats(_draws), "primitives": _stats(_primitives),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"processing_scripts": _scripts, "mesh_groups": _mesh_groups, "long_audio": long_audio}
	for record in _saved:
		if not is_instance_valid(record.node): continue
		if record.has("property"):
			record.node.set(record.property, record.value)
		else:
			record.node.set_process(record.process)
			record.node.set_physics_process(record.physics)
	_saved.clear()
	if is_instance_valid(_portrait):
		if is_instance_valid(_camera): _camera.make_current()
		_portrait.queue_free()
		_portrait = null
	if is_instance_valid(_camera) and "_yaw" in _camera:
		_camera.set("_yaw", _yaw)
		_camera.set("_pitch", _pitch)
	_label = ""
	print("FRAME PROFILE ", JSON.stringify(result))

func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var ordered := values.duplicate()
	ordered.sort()
	var total := 0.0
	var spikes := 0
	var median: float = ordered[ordered.size() / 2]
	for value in ordered:
		total += value
		if value > maxf(50.0, median * 1.8): spikes += 1
	return {"n": ordered.size(), "mean": total / ordered.size(), "p50": median,
		"p95": ordered[mini(ordered.size() - 1, int(ordered.size() * 0.95))],
		"p99": ordered[mini(ordered.size() - 1, int(ordered.size() * 0.99))],
		"max": ordered[-1], "spikes": spikes}
