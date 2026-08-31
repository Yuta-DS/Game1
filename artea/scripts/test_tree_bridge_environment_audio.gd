extends SceneTree


const EXPECTED_SOURCES := {
	"TreeBridgeWind_00": &"elevated_wind",
	"TreeBridgeWind_01": &"elevated_wind",
	"TreeBridgeWind_02": &"elevated_wind",
	"TreeBridgeCrystal_00": &"crystal_resonance",
	"TreeBridgeCrystal_01": &"crystal_resonance",
	"TreeBridgeCrystal_02": &"crystal_resonance",
	"TreeBridgeStructure": &"structural_resonance",
}


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("TREE_BRIDGE_ENVIRONMENT_AUDIO_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var packed := load("res://scenes/art_castle_floating_world.tscn") as PackedScene
	if packed == null:
		_fail("cannot load Art Castle floating world")
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	for _frame in 24:
		await process_frame

	var audio_root := scene.get_node_or_null("SpatialAudioEnvironment") as Node3D
	if audio_root == null:
		_fail("central spatial audio root was not installed")
		return
	var bridge_sources: Array[AudioStreamPlayer3D] = []
	for candidate in audio_root.find_children("*", "AudioStreamPlayer3D", true, false):
		var source := candidate as AudioStreamPlayer3D
		if source.get_meta("environment_profile", "") == "tree_processional_bridge":
			bridge_sources.append(source)
	if bridge_sources.size() != EXPECTED_SOURCES.size():
		_fail("expected 7 bridge emitters, found %d" % bridge_sources.size())
		return

	for source in bridge_sources:
		if not EXPECTED_SOURCES.has(String(source.name)):
			_fail("unexpected bridge source %s" % source.name)
			return
		if source.get_meta("environment_layer", &"") != EXPECTED_SOURCES[String(source.name)]:
			_fail("wrong layer on %s" % source.name)
			return
		if source.stream == null or not source.playing:
			_fail("%s is silent" % source.name)
			return
		if source.bus != &"SFX" or source.panning_strength != 1.0:
			_fail("%s bypasses spatial SFX routing" % source.name)
			return
		if source.attenuation_model != AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE \
				or source.max_distance <= 0.0:
			_fail("%s lacks bounded inverse-distance falloff" % source.name)
			return
		if not bool(source.get_meta("surround_7_1_ready", false)):
			_fail("%s lacks surround/stereo fallback registration" % source.name)
			return

	print("TREE_BRIDGE_ENVIRONMENT_AUDIO_TEST: PASS — 3 wind + 3 crystal + 1 structure emitters are spatial, bounded, playing, and surround-ready")
	quit()
