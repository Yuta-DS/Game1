# Headless check for the gallery grand piano.
#
#   Godot --headless --path artea --script res://scripts/test_gallery_piano.gd
#
# Scene-scoped on purpose: it builds the piano on its own rather than loading
# the gallery, which pulls in the local LLM and runs past a sane time budget
# (see the Tests section of AGENT.md).
extends SceneTree

const PIANO := preload("res://scripts/gallery_piano.gd")

var _failures := 0
var _piano: Node3D = null


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   %s" % message)
	else:
		_failures += 1
		printerr("  FAIL %s" % message)


func _initialize() -> void:
	print("gallery piano")
	_piano = PIANO.new()
	root.add_child(_piano)


# The piano builds itself in _ready(), which does not run until the first
# frame -- asserting straight after add_child() in _initialize() would measure
# an empty node and fail everything.
func _process(_delta: float) -> bool:
	_run(_piano)
	print("%s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)
	return true


func _run(piano: Node3D) -> void:
	# 88 keys, 52 of them white, is what makes it a piano rather than a prop.
	var keys: Dictionary = piano._keys
	_check(keys.size() == 88, "88 keys built (got %d)" % keys.size())
	var whites := 0
	for midi in piano._key_white:
		if piano._key_white[midi]:
			whites += 1
	_check(whites == 52, "52 white keys (got %d)" % whites)

	# Every key must resolve to a loaded sample, or some notes are silent.
	var missing: Array[int] = []
	for midi in range(piano.FIRST_MIDI, piano.LAST_MIDI + 1):
		var base := PIANO.base_octave_for(PIANO.octave_of(midi))
		if not piano._samples.has("%s%d" % [piano.NOTE_NAMES[midi % 12], base]):
			missing.append(midi)
	_check(missing.is_empty(), "every key maps to a sample (missing %d)" % missing.size())
	var expected: int = 12 * piano.SAMPLE_OCTAVES.size()
	_check(piano._samples.size() == expected,
		"%d samples loaded (got %d)" % [expected, piano._samples.size()])

	# Nothing may be shifted more than an octave, which is the whole reason
	# three sample sets are shipped rather than one. A0 sits three octaves
	# below C4, so a single set would have to stretch it 8x.
	var worst := 1.0
	for midi in range(piano.FIRST_MIDI, piano.LAST_MIDI + 1):
		var octave := PIANO.octave_of(midi)
		var shift: float = pow(2.0, float(octave - PIANO.base_octave_for(octave)))
		worst = maxf(worst, maxf(shift, 1.0 / shift))
	_check(worst <= 2.0 + 0.001, "no sample shifted past 2x (worst %.2fx)" % worst)

	# Keys must sit on their own layer: the Lens of Seeing cuts anything on
	# layer 4, and a blocked picking ray would make the piano unplayable.
	_check(piano.KEY_LAYER != 4, "keys are not on the Cuttable layer")
	var sample_key: Node3D = keys[60]
	var body: StaticBody3D = null
	for child in sample_key.get_children():
		if child is StaticBody3D:
			body = child
	_check(body != null, "middle C has a pickable body")
	if body != null:
		_check(body.collision_layer == 1 << (piano.KEY_LAYER - 1),
			"picking body is on the key layer")
		_check(int(body.get_meta("midi", -1)) == 60, "picking body carries its midi note")

	# Keys must not overlap, or clicks land on the wrong note.
	var xs: Array[float] = []
	for midi in keys:
		if piano._key_white[midi]:
			xs.append((keys[midi] as Node3D).position.x)
	xs.sort()
	var min_gap := 1.0
	for index in range(xs.size() - 1):
		min_gap = minf(min_gap, xs[index + 1] - xs[index])
	_check(min_gap > 0.015, "white keys are spaced apart (min %.4f m)" % min_gap)

	# The case has to have produced real geometry, not empty meshes.
	var meshes := 0
	var empty := 0
	for node in _descendants(piano):
		if node is MeshInstance3D:
			meshes += 1
			var mesh: Mesh = (node as MeshInstance3D).mesh
			if mesh == null or mesh.get_surface_count() == 0:
				empty += 1
	_check(meshes > 100, "case and keys built meshes (got %d)" % meshes)
	_check(empty == 0, "no empty meshes (got %d)" % empty)

	# Playing must not crash, and must leave a voice with a stream on it.
	piano._play_note(60)
	piano._press_key(60)
	var playing := 0
	for voice in piano._voices:
		if voice.stream != null:
			playing += 1
	_check(playing > 0, "playing middle C loaded a voice")

	_check_scene()


## The piano is wired into the gallery by hand-edited scene text, so confirm
## the scene still parses and carries the node.  Read through SceneState rather
## than instantiating: building the gallery for real pulls in the local LLM and
## blows the time budget (see AGENT.md).
func _check_scene() -> void:
	var packed: PackedScene = load("res://scenes/art_gallery_3d_inprogress.tscn")
	_check(packed != null, "gallery scene still loads")
	if packed == null:
		return
	var state := packed.get_state()
	var found := false
	var wired := false
	for index in range(state.get_node_count()):
		if state.get_node_name(index) != &"GrandPiano":
			continue
		found = true
		for property in range(state.get_node_property_count(index)):
			if state.get_node_property_name(index, property) == &"camera_path":
				wired = state.get_node_property_value(index, property) == NodePath("../Camera3D")
	_check(found, "gallery scene contains the GrandPiano node")
	_check(wired, "GrandPiano is wired to the gallery camera")

	# The seated view depends on a camera entry point the paintings do not use;
	# if it goes missing the piano silently becomes unplayable.
	var camera_script: GDScript = load("res://scripts/CameraFollow.gd")
	var methods: Array[String] = []
	for method in camera_script.get_script_method_list():
		methods.append(method.name)
	_check(methods.has("enter_inspect_framed"), "CameraFollow offers enter_inspect_framed()")
	_check(methods.has("exit_inspect"), "CameraFollow still offers exit_inspect()")


func _descendants(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_descendants(child))
	return out
