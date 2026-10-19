extends Node

const ProceduralFoleyScript := preload("res://scripts/procedural_foley.gd")

const ART_CASTLE_HUB := Vector3(0.0, 0.0, 1640.0)
const ART_CASTLE_MIND := Vector3(-600.0, 0.0, 1640.0)
const ART_CASTLE_HEART := Vector3(0.0, 0.0, 2290.0)
const ART_CASTLE_CREATOR := Vector3(600.0, 0.0, 1640.0)
const TREE_BRIDGE_PORTAL_STATIONS := [107.28, 223.50, 339.72]
const TREE_BRIDGE_START_Z := 1422.0
const TREE_BRIDGE_MID_Z := 1198.5

var _active_scene: Node
var _scene_audio_root: Node3D
var _footstep_states: Dictionary = {}
var _surface_streams: Dictionary = {}
var _train_states: Dictionary = {}
var _train_loop_streams: Dictionary = {}
var _train_event_streams: Dictionary = {}
var _world_loop_streams: Dictionary = {}
var _object_emitter_counts: Dictionary = {}
var _vegetation_brush_streams: Array[AudioStream] = []
var _vegetation_anchors: Array[Node3D] = []
var _terrain_node: Node
var _web_surface_map: Image

const FOOTSTEP_SURFACES := [&"grass", &"earth", &"sand", &"gravel", &"brick", &"stone", &"wood", &"metal"]
const RECORDED_FOOTSTEP_PATHS := {
	&"grass": [
		"res://assets/audio/pro_footsteps/grass/0.ogg", "res://assets/audio/pro_footsteps/grass/1.ogg",
		"res://assets/audio/pro_footsteps/grass/2.ogg", "res://assets/audio/pro_footsteps/grass/3.ogg",
		"res://assets/audio/pro_footsteps/grass/4.ogg", "res://assets/audio/pro_footsteps/grass/5.ogg"],
	&"earth": [
		"res://assets/audio/footsteps/earth/0.ogg", "res://assets/audio/footsteps/earth/1.ogg",
		"res://assets/audio/footsteps/earth/2.ogg", "res://assets/audio/footsteps/earth/3.ogg",
		"res://assets/audio/footsteps/earth/4.ogg", "res://assets/audio/footsteps/earth/5.ogg"],
	&"sand": [
		"res://assets/audio/footsteps/sand/Fantozzi-SandL1.ogg", "res://assets/audio/footsteps/sand/Fantozzi-SandR1.ogg",
		"res://assets/audio/footsteps/sand/Fantozzi-SandL2.ogg", "res://assets/audio/footsteps/sand/Fantozzi-SandR2.ogg",
		"res://assets/audio/footsteps/sand/Fantozzi-SandL3.ogg", "res://assets/audio/footsteps/sand/Fantozzi-SandR3.ogg"],
	&"gravel": [
		"res://assets/audio/pro_footsteps/gravel/0.ogg", "res://assets/audio/pro_footsteps/gravel/1.ogg",
		"res://assets/audio/pro_footsteps/gravel/2.ogg", "res://assets/audio/pro_footsteps/gravel/3.ogg",
		"res://assets/audio/pro_footsteps/gravel/4.ogg", "res://assets/audio/pro_footsteps/gravel/5.ogg"],
	&"brick": [
		"res://assets/audio/pro_footsteps/brick/0.ogg", "res://assets/audio/pro_footsteps/brick/1.ogg",
		"res://assets/audio/pro_footsteps/brick/2.ogg", "res://assets/audio/pro_footsteps/brick/3.ogg",
		"res://assets/audio/pro_footsteps/brick/4.ogg", "res://assets/audio/pro_footsteps/brick/5.ogg"],
	&"stone": [
		"res://assets/audio/pro_footsteps/stone/0.ogg", "res://assets/audio/pro_footsteps/stone/1.ogg",
		"res://assets/audio/pro_footsteps/stone/2.ogg", "res://assets/audio/pro_footsteps/stone/3.ogg",
		"res://assets/audio/pro_footsteps/stone/4.ogg", "res://assets/audio/pro_footsteps/stone/5.ogg"],
	&"wood": [
		"res://assets/audio/footsteps/wood/0.ogg", "res://assets/audio/footsteps/wood/1.ogg",
		"res://assets/audio/footsteps/wood/2.ogg", "res://assets/audio/footsteps/wood/3.ogg",
		"res://assets/audio/footsteps/wood/4.ogg", "res://assets/audio/footsteps/wood/5.ogg",
		"res://assets/audio/footsteps/wood/6.ogg", "res://assets/audio/footsteps/wood/7.ogg",
		"res://assets/audio/footsteps/wood/8.ogg"],
	&"metal": [
		"res://assets/audio/pro_footsteps/metal/0.ogg", "res://assets/audio/pro_footsteps/metal/1.ogg",
		"res://assets/audio/pro_footsteps/metal/2.ogg", "res://assets/audio/pro_footsteps/metal/3.ogg",
		"res://assets/audio/pro_footsteps/metal/4.ogg", "res://assets/audio/pro_footsteps/metal/5.ogg"],
}
const RECORDED_BRUSH_PATHS := [
	"res://assets/audio/pro_vegetation/foliage_brush_0.ogg",
	"res://assets/audio/pro_vegetation/foliage_brush_1.ogg",
]
const WEB_TERRAIN_HALF_EXTENT := 2048.0
const SURROUND_READY_META := &"surround_7_1_ready"

const OBJECT_EMITTER_LIMITS := {
	&"windmill": 3,
	&"watermill": 3,
	&"lumbermill": 3,
	&"forge": 3,
	&"cave_air": 3,
	&"aether_power": 10,
}
const MOTION_REQUIRED_PROFILES := [&"windmill", &"watermill", &"lumbermill", &"forge"]


func _ready() -> void:
	for surface in FOOTSTEP_SURFACES:
		var variants := _load_recorded_streams(RECORDED_FOOTSTEP_PATHS.get(surface, []))
		if variants.is_empty():
			for variant in 4:
				variants.append(ProceduralFoleyScript.make_footstep(surface, variant))
		_surface_streams[surface] = variants
	_vegetation_brush_streams = _load_recorded_streams(RECORDED_BRUSH_PATHS)
	if _vegetation_brush_streams.is_empty():
		for variant in 4:
			_vegetation_brush_streams.append(ProceduralFoleyScript.make_vegetation_brush(variant))
	_world_loop_streams = {
		&"windmill": _load_looping_recording(
			"res://assets/audio/world_objects/tree_wind_loop.ogg",
			ProceduralFoleyScript.make_world_object_loop(&"mechanism")),
		&"watermill": _load_looping_recording(
			"res://assets/audio/world_objects/watermill_loop.ogg",
			ProceduralFoleyScript.make_world_object_loop(&"mechanism")),
		&"lumbermill": _load_looping_recording(
			"res://assets/audio/world_objects/sawmill_loop.ogg",
			ProceduralFoleyScript.make_world_object_loop(&"mechanism")),
		&"forge": _load_looping_recording(
			"res://assets/audio/Campfire.ogg",
			ProceduralFoleyScript.make_world_object_loop(&"forge")),
		&"cave_air": _load_looping_recording(
			"res://assets/audio/world_objects/cave_air_loop.ogg",
			ProceduralFoleyScript.make_world_object_loop(&"cavern")),
		&"aether_power": _load_looping_recording(
			"res://assets/audio/world_objects/aether_power_loop.ogg",
			ProceduralFoleyScript.make_world_object_loop(&"magic")),
	}
	_train_loop_streams = {
		&"engine": _load_looping_recording(
			"res://assets/audio/pro_train/royal_hudson_engine_loop.ogg",
			ProceduralFoleyScript.make_train_loop(&"engine")),
		&"rail": _load_looping_recording("res://assets/audio/pro_train/royal_hudson_rail_loop.ogg",
			ProceduralFoleyScript.make_train_loop(&"rail")),
		&"rush": ProceduralFoleyScript.make_wind_loop(31415, false),
	}
	var power_whistle := load("res://assets/audio/pro_train/royal_hudson_whistle.ogg")
	_train_event_streams = {
		# Automatic departures previously replayed the same long locomotive
		# whistle as the manual horn. Moving trains could therefore fill the hub
		# with repeated "doo doo" calls even when the player never requested one.
		# Keep the realistic whistle on the explicit R control and use a short,
		# gentle bird chorus for unattended departures.
		&"departure": ProceduralFoleyScript.make_train_event(&"departure"),
		&"horn": power_whistle,
		&"brake": ProceduralFoleyScript.make_train_event(&"brake"),
	}
	get_tree().node_added.connect(_on_tree_node_added)
	process_physics_priority = 80
	call_deferred("_refresh_scene")


func _load_recorded_streams(paths: Array) -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	for path in paths:
		var stream := load(String(path)) as AudioStream
		if stream == null:
			continue
		stream = stream.duplicate()
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = false
		streams.append(stream)
	return streams


func _load_looping_recording(path: String, fallback: AudioStream) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream == null:
		return fallback
	stream = stream.duplicate()
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream


func _process(delta: float) -> void:
	if get_tree().current_scene != _active_scene:
		_refresh_scene()
	_update_train_audio(delta)


func _physics_process(delta: float) -> void:
	if _active_scene == null:
		return
	_discover_players()
	var expired: Array[int] = []
	for instance_id in _footstep_states:
		var state: Dictionary = _footstep_states[instance_id]
		# Validity is checked before the cast: casting a freed object with `as`
		# is itself an error, and players are freed whenever the scene changes.
		if not is_instance_valid(state.player):
			expired.append(instance_id)
			continue
		var player := state.player as CharacterBody3D
		if player == null or not player.is_inside_tree():
			expired.append(instance_id)
			continue
		_update_player_footsteps(state, player, delta)
		_footstep_states[instance_id] = state
	for instance_id in expired:
		_footstep_states.erase(instance_id)


func _refresh_scene() -> void:
	_active_scene = get_tree().current_scene
	_footstep_states.clear()
	_train_states.clear()
	_object_emitter_counts.clear()
	_vegetation_anchors.clear()
	_terrain_node = null
	_web_surface_map = null
	_scene_audio_root = null
	if _active_scene == null:
		return
	if _active_scene.has_node("SpatialAudioEnvironment"):
		_scene_audio_root = _active_scene.get_node("SpatialAudioEnvironment") as Node3D
	else:
		_scene_audio_root = Node3D.new()
		_scene_audio_root.name = "SpatialAudioEnvironment"
		_active_scene.add_child(_scene_audio_root)
	_scan_existing_spatial_sources()
	_install_environment_audio()
	_find_terrain_sources()
	_discover_players()
	call_deferred("_scan_existing_world_nodes")


func _scan_existing_world_nodes() -> void:
	if _active_scene == null:
		return
	_consider_world_audio_node(_active_scene)
	for candidate in _active_scene.find_children("*", "Node3D", true, false):
		var spatial := candidate as Node3D
		if _is_train_root(spatial) or classify_world_emitter(spatial) != &"":
			_consider_world_audio_node(spatial)
		if _is_vegetation_anchor(spatial):
			_register_vegetation_anchor(spatial)


func _scan_existing_spatial_sources() -> void:
	if _active_scene == null:
		return
	for candidate in _active_scene.find_children("*", "AudioStreamPlayer3D", true, false):
		_configure_surround_source(candidate as AudioStreamPlayer3D)


func _on_tree_node_added(node: Node) -> void:
	if node is AudioStreamPlayer3D:
		call_deferred("_configure_surround_source", node as AudioStreamPlayer3D)
	if node is Node3D:
		# Large galaxy scenes add tens of thousands of decorative mesh nodes.
		# Filter synchronously by semantic name so only the handful of possible
		# emitters schedule deferred work on Web's single main thread.
		var spatial := node as Node3D
		if _is_train_root(spatial) or classify_world_emitter(spatial) != &"":
			call_deferred("_consider_world_audio_node", node)
		if _is_vegetation_anchor(spatial):
			call_deferred("_register_vegetation_anchor", spatial)


func _configure_surround_source(source: AudioStreamPlayer3D) -> void:
	if source == null or not is_instance_valid(source):
		return
	# A mono positional source is decoded by Godot to the listener's detected
	# speaker layout. With 7.1 hardware this uses SPCAP across front, centre,
	# side and rear channels; on Web/headphones it gracefully becomes stereo.
	source.panning_strength = 1.0
	source.area_mask = 1
	if source.bus == &"Master":
		source.bus = &"SFX"
	if source.attenuation_model != AudioStreamPlayer3D.ATTENUATION_DISABLED:
		if source.max_distance <= 0.0:
			source.max_distance = _default_surround_distance(source)
		source.unit_size = maxf(source.unit_size, 2.0)
		# Retain clarity nearby while naturally removing high-frequency detail as
		# the listener moves away from the physical source.
		source.attenuation_filter_cutoff_hz = clampf(
			source.attenuation_filter_cutoff_hz, 6200.0, 9200.0)
		source.attenuation_filter_db = clampf(source.attenuation_filter_db, -18.0, -10.0)
	var moving_source := _source_moves_through_world(source)
	source.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP \
		if moving_source else AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	if moving_source:
		_enable_listener_doppler()
	source.set_meta(SURROUND_READY_META, true)
	source.set_meta("surround_output", "7.1 SPCAP when detected; positional stereo fallback")


func _default_surround_distance(source: AudioStreamPlayer3D) -> float:
	var label := String(source.name).to_lower()
	if "ocean" in label or "wind" in label or "water" in label \
			or "ambience" in label or "background" in label:
		return 180.0
	if "milo" in label or "voice" in label:
		return 30.0
	if "foot" in label or "brush" in label or "pop" in label \
			or "feedback" in label:
		return 28.0
	return 72.0


func _source_moves_through_world(source: AudioStreamPlayer3D) -> bool:
	var current: Node = source
	while current != null and current != _active_scene:
		if current is Node3D and _is_train_root(current as Node3D):
			return true
		current = current.get_parent()
	return false


func _enable_listener_doppler() -> void:
	if _active_scene == null:
		return
	for candidate in _active_scene.find_children("*", "Camera3D", true, false):
		var camera := candidate as Camera3D
		if camera.current:
			camera.doppler_tracking = Camera3D.DOPPLER_TRACKING_PHYSICS_STEP


func get_detected_speaker_layout() -> String:
	match AudioServer.get_speaker_mode():
		AudioServer.SPEAKER_SURROUND_71: return "7.1"
		AudioServer.SPEAKER_SURROUND_51: return "5.1"
		AudioServer.SPEAKER_SURROUND_31: return "3.1"
		_: return "stereo"


func _find_terrain_sources() -> void:
	_terrain_node = _active_scene.find_child("Terrain3D", true, false)
	var map_texture := load("res://resources/web_hub_surface_map.png") as Texture2D
	if map_texture != null:
		_web_surface_map = map_texture.get_image()


func _is_vegetation_anchor(node: Node3D) -> bool:
	var label := String(node.name).to_lower()
	if "scatteritem" in label or "collision" in label or "canopy" in label \
			or "leaf" in label or "leaves" in label or "trunk" in label \
			or "root" in label:
		return false
	return "bush" in label or "foliage" in label or "shrub" in label \
		or label.begins_with("ms_tree_") or label.begins_with("cl_tree_") \
		or label.begins_with("hm_tree_") or label.ends_with("cypress")


func _register_vegetation_anchor(node: Node3D) -> void:
	if _vegetation_anchors.size() >= 192 or node in _vegetation_anchors:
		return
	if _active_scene == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	_vegetation_anchors.append(node)


func _consider_world_audio_node(node: Node) -> void:
	if _active_scene == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	if node != _active_scene and not _active_scene.is_ancestor_of(node):
		return
	var spatial := node as Node3D
	if spatial == null:
		return
	if _is_train_root(spatial):
		_register_train(spatial)
		return
	if _has_managed_train_ancestor(spatial):
		return
	var kind := classify_world_emitter(spatial)
	if kind != &"":
		_register_world_emitter(spatial, kind)


func _is_train_root(node: Node3D) -> bool:
	var label := String(node.name).to_lower()
	# Imported Crown Line meshes intentionally use names such as TRAIN_Boiler and
	# TRAIN_Wheel. Name-prefix matching attached a complete four-source sound rig
	# to every one of those visual children. Real procedural trains mark their
	# root explicitly; the unique story train name remains supported for scenes
	# authored before that marker existed.
	return label == "rainbowgalaxytrain" or bool(node.get_meta("spatial_train_root", false))


func _has_managed_train_ancestor(node: Node) -> bool:
	var current := node.get_parent()
	while current != null and current != _active_scene:
		if not is_instance_valid(current):
			return false
		if current.has_meta("spatial_train_audio"):
			return true
		current = current.get_parent()
	return false


func _register_train(train: Node3D) -> void:
	var instance_id := train.get_instance_id()
	if _train_states.has(instance_id) or train.has_meta("spatial_train_audio"):
		return
	train.set_meta("spatial_train_audio", true)
	var engine := _new_attached_source(train, "TractionEngine3D", -25.0, 260.0, 20.0)
	# The hybrid steam/electric loop radiates from the visible nose crystal and
	# reactor valve assembly instead of the midpoint between the passenger cars.
	engine.position = Vector3(0.0, 4.2, -15.0)
	engine.stream = _train_loop_streams[&"engine"]
	engine.play()
	var rail := _new_attached_source(train, "RailClatter3D", -60.0, 230.0, 16.0)
	rail.stream = _train_loop_streams[&"rail"]
	rail.play()
	var rush := _new_attached_source(train, "TravelWind3D", -60.0, 180.0, 20.0)
	rush.stream = _train_loop_streams[&"rush"]
	rush.play()
	var events := _new_attached_source(train, "TrainEvents3D", -8.0, 340.0, 28.0)
	events.position = Vector3(0.0, 5.2, -15.0)
	_train_states[instance_id] = {
		"train": train,
		"engine": engine,
		"rail": rail,
		"rush": rush,
		"events": events,
		"last_position": train.global_position,
		"speed": 0.0,
		"moving": false,
		"stationary_time": 2.0,
		"event_cooldown": 0.0,
		"horn_cooldown": 0.0,
	}


func _update_train_audio(delta: float) -> void:
	if delta <= 0.0 or _train_states.is_empty():
		return
	var expired: Array[int] = []
	for instance_id in _train_states:
		var state: Dictionary = _train_states[instance_id]
		# Validity is checked before the cast: casting a freed object with `as`
		# is itself an error. Leaving a scene frees its trains a frame or more
		# before current_scene changes and _refresh_scene clears this table.
		if not is_instance_valid(state.train):
			expired.append(instance_id)
			continue
		var train := state.train as Node3D
		if train == null or not train.is_inside_tree():
			expired.append(instance_id)
			continue
		var raw_speed := train.global_position.distance_to(state.last_position) / delta
		var speed := lerpf(float(state.speed), minf(raw_speed, 520.0),
			clampf(delta * 5.0, 0.0, 1.0))
		var speed_ratio := clampf(speed / 95.0, 0.0, 1.0)
		var moving := speed > 0.75
		var engine := state.engine as AudioStreamPlayer3D
		var rail := state.rail as AudioStreamPlayer3D
		var rush := state.rush as AudioStreamPlayer3D
		engine.volume_db = lerpf(-24.0, -5.5, speed_ratio)
		# Preserve the identity of the recorded machine rather than "chipmunking"
		# it across the whole speed range. Loudness carries most of the motion cue.
		engine.pitch_scale = lerpf(0.92, 1.08, speed_ratio)
		rail.volume_db = lerpf(-52.0, -5.0, clampf(speed / 55.0, 0.0, 1.0))
		rail.pitch_scale = lerpf(0.94, 1.10, clampf(speed / 110.0, 0.0, 1.0))
		rush.volume_db = lerpf(-58.0, -11.0, clampf((speed - 12.0) / 120.0, 0.0, 1.0))
		rush.pitch_scale = lerpf(0.82, 1.25, speed_ratio)
		state.event_cooldown = maxf(0.0, float(state.event_cooldown) - delta)
		state.horn_cooldown = maxf(0.0, float(state.horn_cooldown) - delta)
		if not moving:
			state.stationary_time = float(state.stationary_time) + delta
		elif not bool(state.moving) and float(state.stationary_time) > 0.65 \
				and float(state.event_cooldown) <= 0.0:
			_play_train_event(state, &"departure")
			state.stationary_time = 0.0
			state.event_cooldown = 2.2
		if bool(state.moving) and not moving and float(state.event_cooldown) <= 0.0:
			_play_train_event(state, &"brake")
			state.event_cooldown = 1.4
		state.last_position = train.global_position
		state.speed = speed
		state.moving = moving
		_train_states[instance_id] = state
	for instance_id in expired:
		_train_states.erase(instance_id)


func request_train_horn(train: Node3D) -> bool:
	if train == null or not is_instance_valid(train):
		return false
	var instance_id := train.get_instance_id()
	if not _train_states.has(instance_id):
		_register_train(train)
	if not _train_states.has(instance_id):
		return false
	var state: Dictionary = _train_states[instance_id]
	if float(state.horn_cooldown) > 0.0:
		return false
	_play_train_event(state, &"horn")
	state.horn_cooldown = 0.55
	_train_states[instance_id] = state
	return true


func _play_train_event(state: Dictionary, event_name: StringName) -> void:
	var events := state.events as AudioStreamPlayer3D
	events.stream = _train_event_streams[event_name]
	events.volume_db = -7.0 if event_name == &"horn" else -15.0 \
		if event_name == &"departure" else -11.0
	events.play()


func classify_world_emitter(node: Node) -> StringName:
	var label := String(node.name).to_lower().replace("_", "").replace(" ", "")
	# Landmark lighting is not the machine or building named in its label.
	if label.begins_with("lantern"):
		return &""
	if "windmill" in label:
		return &"windmill"
	if "watermill" in label or label == "millwheel":
		return &"watermill"
	if "lumbermill" in label:
		return &"lumbermill"
	if "blacksmith" in label or label in ["forge", "castleforge"]:
		return &"forge"
	if label in ["msmine", "clextmine", "hmextmine", "mineentrance", "cavern"] \
			or label.begins_with("buildingmine"):
		return &"cave_air"
	# "crownrig" (the small crystal accent on the hub castle roof) is left out:
	# its hum carried 92 m and read as an unexplained buzz at the castle door.
	if label in ["treeoflife", "crownoflife", "wisdomheartshrine",
			"treeofimagination", "reactorcore", "destinationwheel",
			"thresholdruneseal", "celestialcore", "referenceastralmachine",
			"lumenenginerig", "heartengine", "midspanresonanceframe"]:
		return &"aether_power"
	return &""


func _register_world_emitter(node: Node3D, kind: StringName) -> void:
	if node.has_meta("spatial_world_emitter"):
		return
	if _has_same_profile_ancestor(node, kind) or _has_player_ancestor(node):
		return
	if kind in MOTION_REQUIRED_PROFILES and not _object_has_active_motion(node):
		node.set_meta("sound_audit_treatment", "static_silent")
		return
	var count := int(_object_emitter_counts.get(kind, 0))
	if count >= int(OBJECT_EMITTER_LIMITS.get(kind, 0)):
		return
	node.set_meta("spatial_world_emitter", kind)
	_object_emitter_counts[kind] = count + 1
	var max_distance_value := 92.0 if kind == &"aether_power" else 58.0
	var source := _new_attached_source(node, "ObjectAmbience_%s" % String(kind),
		-25.0, max_distance_value, max_distance_value * 0.14)
	source.stream = _world_loop_streams[kind]
	# Hidden landmarks (e.g. the castle redesign hides ReferenceAstralMachine)
	# must not keep humming. Visibility changes propagate to Node3D children.
	source.playing = node.is_visible_in_tree()
	node.visibility_changed.connect(func() -> void:
		if is_instance_valid(source) and is_instance_valid(node):
			source.playing = node.is_visible_in_tree())


func _has_same_profile_ancestor(node: Node, kind: StringName) -> bool:
	var current := node.get_parent()
	while current != null and current != _active_scene:
		# Imported models often repeat their source filename on every mesh child.
		# Suppress those coincident emitters, but retain genuinely separate sound
		# sources that happen to be nested for scene organisation.
		if classify_world_emitter(current) == kind and current is Node3D:
			if node.global_position.distance_to((current as Node3D).global_position) <= 12.0:
				return true
		current = current.get_parent()
	return false


func _has_player_ancestor(node: Node) -> bool:
	var current: Node = node
	while current != null and current != _active_scene:
		if current is CharacterBody3D or current.is_in_group("player") \
				or current.is_in_group("Player"):
			return true
		current = current.get_parent()
	return false


func _object_has_active_motion(node: Node) -> bool:
	if bool(node.get_meta("sound_active", false)):
		return true
	for candidate in node.find_children("*", "AnimationPlayer", true, false):
		if (candidate as AnimationPlayer).is_playing():
			return true
	return false


func _discover_players() -> void:
	for group_name in [&"player", &"Player"]:
		for candidate in get_tree().get_nodes_in_group(group_name):
			if candidate is CharacterBody3D:
				_register_player(candidate as CharacterBody3D)
	if _active_scene != null:
		for node_name in ["NewPlayer", "Player3D"]:
			var candidate := _active_scene.get_node_or_null(node_name)
			if candidate is CharacterBody3D:
				_register_player(candidate as CharacterBody3D)


func _register_player(player: CharacterBody3D) -> void:
	var instance_id := player.get_instance_id()
	if _footstep_states.has(instance_id):
		return
	var marker := Node.new()
	marker.name = "SurfaceFootstepManaged"
	player.add_child(marker)
	var audio := AudioStreamPlayer3D.new()
	audio.name = "SurfaceFootsteps3D"
	audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	audio.unit_size = 3.5
	audio.max_distance = 28.0
	audio.max_db = -2.0
	audio.volume_db = -8.0
	audio.panning_strength = 1.0
	audio.bus = &"SFX"
	player.add_child(audio)
	_configure_surround_source(audio)
	var brush_audio := AudioStreamPlayer3D.new()
	brush_audio.name = "VegetationBrush3D"
	brush_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	brush_audio.unit_size = 2.4
	brush_audio.max_distance = 16.0
	brush_audio.max_db = -3.0
	brush_audio.volume_db = -12.0
	brush_audio.panning_strength = 1.0
	brush_audio.bus = &"SFX"
	player.add_child(brush_audio)
	_configure_surround_source(brush_audio)
	_footstep_states[instance_id] = {
		"player": player,
		"audio": audio,
		"cadence": 0.0,
		"step_index": 0,
		"brush_audio": brush_audio,
		"brush_cooldown": 0.0,
	}


func _update_player_footsteps(state: Dictionary, player: CharacterBody3D, delta: float) -> void:
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	state.brush_cooldown = maxf(0.0, float(state.brush_cooldown) - delta)
	if not player.is_on_floor() or horizontal_speed < 0.55:
		state.cadence = 0.0
		return
	var surface := _surface_below(player)
	_update_vegetation_brush(state, player, surface, horizontal_speed)
	state.cadence = float(state.cadence) - delta
	if float(state.cadence) > 0.0:
		return
	var audio := state.audio as AudioStreamPlayer3D
	var step_index := int(state.step_index)
	var variants: Array = _surface_streams.get(surface, _surface_streams[&"earth"])
	audio.stream = variants[step_index % variants.size()]
	# The recordings already contain natural variation. Keep pitch movement nearly
	# imperceptible so footsteps do not acquire the synthetic/chipmunk character
	# caused by the previous ten-percent shifts.
	audio.pitch_scale = 0.99 + float((step_index * 7) % 3) * 0.01
	audio.volume_db = -8.0 if surface == &"wood" else -9.5 if surface == &"grass" else -9.0
	audio.play()
	state.step_index = step_index + 1
	state.cadence = clampf(3.3 / horizontal_speed, 0.28, 0.58)


func _update_vegetation_brush(state: Dictionary, player: CharacterBody3D,
		surface: StringName, horizontal_speed: float) -> void:
	if float(state.brush_cooldown) > 0.0 or not vegetation_is_beside(player.global_position, surface):
		return
	var brush_audio := state.brush_audio as AudioStreamPlayer3D
	var step_index := int(state.step_index)
	brush_audio.stream = _vegetation_brush_streams[step_index % _vegetation_brush_streams.size()]
	brush_audio.pitch_scale = 0.99 + float(step_index % 2) * 0.02
	brush_audio.volume_db = lerpf(-15.0, -9.5, clampf(horizontal_speed / 6.0, 0.0, 1.0))
	brush_audio.play()
	state.brush_cooldown = 0.62


func _surface_below(player: CharacterBody3D) -> StringName:
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3.UP * 0.35,
		player.global_position + Vector3.DOWN * 2.6)
	query.exclude = [player.get_rid()]
	query.collision_mask = 0x7fffffff
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return &"earth"
	var collider := hit.get("collider") as Node
	var terrain_surface := _terrain_surface_at(collider, hit.get("position", player.global_position))
	return terrain_surface if terrain_surface != &"" else classify_surface(collider)


func _terrain_surface_at(collider: Node, world_position: Vector3) -> StringName:
	var current := collider
	for _depth in 6:
		if current == null:
			break
		if current == _terrain_node or String(current.name) == "Terrain3D":
			var terrain_data = current.get("data")
			if terrain_data != null:
				var base_id: int = terrain_data.get_control_base_id(world_position)
				var overlay_id: int = terrain_data.get_control_overlay_id(world_position)
				var blend: float = terrain_data.get_control_blend(world_position)
				return _terrain_texture_to_surface(overlay_id if not is_nan(blend) and blend >= 0.5 else base_id)
		if String(current.name) == "WebTerrainCollision":
			return _web_terrain_surface_at(world_position)
		current = current.get_parent()
	return &""


func _terrain_texture_to_surface(texture_id: int) -> StringName:
	match texture_id:
		1: return &"sand"
		2: return &"brick"
		_: return &"grass"


func _web_terrain_surface_at(world_position: Vector3) -> StringName:
	if _web_surface_map == null or _web_surface_map.is_empty():
		return &"grass"
	var uv := (Vector2(world_position.x, world_position.z) + Vector2.ONE * WEB_TERRAIN_HALF_EXTENT) \
		/ (WEB_TERRAIN_HALF_EXTENT * 2.0)
	var pixel := Vector2i(
		clampi(roundi(uv.x * (_web_surface_map.get_width() - 1)), 0, _web_surface_map.get_width() - 1),
		clampi(roundi(uv.y * (_web_surface_map.get_height() - 1)), 0, _web_surface_map.get_height() - 1))
	return _terrain_texture_to_surface(clampi(floori(_web_surface_map.get_pixelv(pixel).r * 3.0), 0, 2))


func vegetation_is_beside(world_position: Vector3, current_surface: StringName) -> bool:
	# Underfoot vegetation uses grass footsteps. A brush is a different event and
	# only fires beside an edge or a placed plant, never merely because the floor is grass.
	if current_surface == &"grass":
		return false
	for anchor in _vegetation_anchors:
		if is_instance_valid(anchor):
			var offset := anchor.global_position - world_position
			if Vector2(offset.x, offset.z).length_squared() <= 8.0 and absf(offset.y) <= 3.2:
				return true
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var beside: Vector3 = world_position + direction * 1.15
		if _terrain_surface_at_position(beside) == &"grass":
			return true
	return false


func _terrain_surface_at_position(world_position: Vector3) -> StringName:
	if _terrain_node != null and is_instance_valid(_terrain_node):
		var terrain_data = _terrain_node.get("data")
		if terrain_data != null:
			var base_id: int = terrain_data.get_control_base_id(world_position)
			var overlay_id: int = terrain_data.get_control_overlay_id(world_position)
			var blend: float = terrain_data.get_control_blend(world_position)
			return _terrain_texture_to_surface(overlay_id if not is_nan(blend) and blend >= 0.5 else base_id)
	return _web_terrain_surface_at(world_position) if _web_surface_map != null else &""


func classify_surface(collider: Node) -> StringName:
	var current := collider
	for _depth in 5:
		if current == null:
			break
		if current.has_meta("footstep_surface"):
			var tagged := StringName(current.get_meta("footstep_surface"))
			if tagged in FOOTSTEP_SURFACES:
				return tagged
		var label := String(current.name).to_lower()
		# Do not use a raw `"rail" in label` check: it also matches "trail" and
		# previously routed ordinary meadow/dirt trail colliders to metal Foley.
		var is_rail_hardware := label == "rail" or label.begins_with("rail_") \
				or label.ends_with("_rail") or "railtrack" in label \
				or "rail_track" in label or "railway" in label
		if "metal" in label or "iron" in label or "brass" in label \
				or is_rail_hardware or "deckplate" in label:
			return &"metal"
		if "timber" in label or "plank" in label or "wood" in label or "pier" in label:
			return &"wood"
		if "sand" in label or "beach" in label:
			return &"sand"
		if "gravel" in label or "pebble" in label or "shingle" in label:
			return &"gravel"
		if "brick" in label or "paving" in label or "tile" in label \
				or "court" in label or "promenade" in label or "mosaic" in label \
				or "rune" in label:
			return &"brick"
		if "stone" in label or "castle" in label or "stair" in label \
				or "rock" in label or "foundation" in label or "walkway" in label \
				or "studiofloor" in label:
			return &"stone"
		if "bridge" in label or "causeway" in label:
			return &"wood"
		if "dirt" in label or "earth" in label or "soil" in label or "ground" in label:
			return &"earth"
		if current.is_in_group("grass_surface") or current.is_in_group("grass"):
			return &"grass"
		if "terrain" in label or "grass" in label or "garden" in label:
			return &"grass"
		current = current.get_parent()
	return &"earth"


func _install_environment_audio() -> void:
	if _scene_audio_root == null or _active_scene == null:
		return
	var scene_name := String(_active_scene.name)
	if scene_name == "HubWorld":
		_stop_legacy_hub_ambience()
		_add_loop("HarbourWaterAndBirds", "res://assets/audio/Flowing Water and Birds (Hub).ogg",
			Vector3(145.0, 8.0, 67.0), -15.0, 115.0, 20.0)
		_add_loop("CastleCourtyardFire", "res://assets/audio/Campfire.ogg",
			Vector3(-51.0, 76.0, 28.0), -18.0, 62.0, 8.0)
		_add_recorded_wind("WesternTreeWind", Vector3(-108.0, 38.0, -18.0), 92.0)
		_add_recorded_wind("EasternTreeWind", Vector3(112.0, 35.0, 12.0), 92.0)
	elif scene_name == "ArtCastleFloatingWorld" or _active_scene.has_node("ArtCastleFloatingWorld"):
		var floating_world := _active_scene.get_node_or_null("ArtCastleFloatingWorld") as Node3D
		if floating_world != null:
			# The embedded galaxy is offset 480 m in front of the Art Gallery. Keep
			# all authored sound coordinates in the floating world's local frame.
			_scene_audio_root.transform = floating_world.transform
		_add_loop("CloudSea", "res://assets/audio/Ocean_Ambience_Loop.ogg",
			Vector3(0.0, -35.0, 1460.0), -22.0, 520.0, 85.0)
		_install_tree_bridge_ambience()
		_add_recorded_wind("TreeOfLifeCanopyWind", ART_CASTLE_HUB + Vector3(0, 92, 0), 310.0)
		_add_recorded_wind("MindSparkHighWind", ART_CASTLE_MIND + Vector3(0, 54, 0), 230.0)
		_add_loop("HeartMelodyWaterGarden", "res://assets/audio/waterfall_ambient_loop.ogg",
			ART_CASTLE_HEART + Vector3(0, 8, 0), -18.0, 240.0, 38.0)
		_add_recorded_wind("CreatorsLightCanvasWind", ART_CASTLE_CREATOR + Vector3(0, 42, 0), 230.0)


func _install_tree_bridge_ambience() -> void:
	# Three restrained zones make the 447 m crossing feel continuous without a
	# single flat ambience following the player or adding expensive processors.
	var wind_positions := [
		Vector3(-16.0, 17.0, 1347.0),
		Vector3(18.0, 20.0, TREE_BRIDGE_MID_Z),
		Vector3(-14.0, 17.0, 1050.0),
	]
	for index in wind_positions.size():
		var wind := _new_spatial_source("TreeBridgeWind_%02d" % index,
			wind_positions[index], -29.0, 155.0, 20.0)
		wind.stream = ProceduralFoleyScript.make_wind_loop(82520 + index * 97, true)
		_tag_tree_bridge_source(wind, &"elevated_wind")
		wind.play(float(index) * 1.35)

	# The three cyan crown crystals share one deterministic stream, but start at
	# different phases so the bridge never produces a mechanically synced chord.
	var crystal_stream := ProceduralFoleyScript.make_world_object_loop(&"magic")
	for index in TREE_BRIDGE_PORTAL_STATIONS.size():
		var station: float = TREE_BRIDGE_PORTAL_STATIONS[index]
		var crystal := _new_spatial_source("TreeBridgeCrystal_%02d" % index,
			Vector3(0.0, 22.0, TREE_BRIDGE_START_Z - station),
			-31.0, 92.0, 12.0)
		crystal.stream = crystal_stream
		crystal.attenuation_filter_cutoff_hz = 7200.0
		_tag_tree_bridge_source(crystal, &"crystal_resonance")
		crystal.play(float(index) * 1.85)

	# A nearly subliminal low body tone sits below the midpoint. It gives the
	# long span physical weight while footsteps remain the dominant close sound.
	var structure := _new_spatial_source("TreeBridgeStructure",
		Vector3(0.0, -8.0, TREE_BRIDGE_MID_Z), -35.0, 115.0, 16.0)
	structure.stream = ProceduralFoleyScript.make_world_object_loop(&"mechanism")
	structure.attenuation_filter_cutoff_hz = 3200.0
	_tag_tree_bridge_source(structure, &"structural_resonance")
	structure.play(2.4)


func _tag_tree_bridge_source(source: AudioStreamPlayer3D, layer: StringName) -> void:
	source.set_meta("environment_profile", "tree_processional_bridge")
	source.set_meta("environment_layer", layer)
	source.set_meta("laptop_cpu_profile", "seven_mono_emitters_no_realtime_effects")


func _stop_legacy_hub_ambience() -> void:
	for node_name in ["Water Flow", "Wind"]:
		var legacy := _active_scene.get_node_or_null(node_name) as AudioStreamPlayer3D
		if legacy != null:
			legacy.stop()
			legacy.autoplay = false


func _add_loop(node_name: String, stream_path: String, position_value: Vector3,
		volume: float, max_distance_value: float, unit_size_value: float) -> void:
	var source := _new_spatial_source(node_name, position_value, volume,
		max_distance_value, unit_size_value)
	var stream := load(stream_path)
	if stream is AudioStreamOggVorbis:
		stream = stream.duplicate()
		(stream as AudioStreamOggVorbis).loop = true
	source.stream = stream
	if source.stream != null:
		source.play()


func _add_generated_wind(node_name: String, position_value: Vector3, seed_value: int,
		rustle: bool, max_distance_value: float) -> void:
	var source := _new_spatial_source(node_name, position_value, -24.0,
		max_distance_value, max_distance_value * 0.12)
	source.stream = ProceduralFoleyScript.make_wind_loop(seed_value, rustle)
	source.play()


func _add_recorded_wind(node_name: String, position_value: Vector3,
		max_distance_value: float) -> void:
	var source := _new_spatial_source(node_name, position_value, -25.0,
		max_distance_value, max_distance_value * 0.12)
	source.stream = _load_looping_recording(
		"res://assets/audio/world_objects/tree_wind_loop.ogg",
		ProceduralFoleyScript.make_wind_loop(2603, true))
	source.play()


func _new_spatial_source(node_name: String, position_value: Vector3, volume: float,
		max_distance_value: float, unit_size_value: float) -> AudioStreamPlayer3D:
	var source := AudioStreamPlayer3D.new()
	source.name = node_name
	source.position = position_value
	source.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	source.volume_db = volume
	source.max_db = -4.0
	source.max_distance = max_distance_value
	source.unit_size = unit_size_value
	source.panning_strength = 1.0
	source.attenuation_filter_cutoff_hz = 8500.0
	source.attenuation_filter_db = -12.0
	source.bus = &"SFX"
	_scene_audio_root.add_child(source)
	_configure_surround_source(source)
	return source


func _new_attached_source(parent: Node3D, node_name: String, volume: float,
		max_distance_value: float, unit_size_value: float) -> AudioStreamPlayer3D:
	var source := AudioStreamPlayer3D.new()
	source.name = node_name
	source.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	source.volume_db = volume
	source.max_db = -3.0
	source.max_distance = max_distance_value
	source.unit_size = unit_size_value
	source.panning_strength = 1.0
	source.attenuation_filter_cutoff_hz = 7600.0
	source.attenuation_filter_db = -14.0
	source.bus = &"SFX"
	parent.add_child(source)
	_configure_surround_source(source)
	return source
