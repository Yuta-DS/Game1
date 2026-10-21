extends SceneTree

const Circle = preload("res://scripts/heart_melody/heart_music_circle.gd")
const Sound = preload("res://scripts/heart_melody/music_circle_sound.gd")
var _last_midi := -1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 800)
	var host := Node3D.new()
	root.add_child(host)
	var player := (load("res://scenes/player_3d.tscn") as PackedScene).instantiate() as CharacterBody3D
	player.name = "Player3D"
	player.add_to_group("Player")
	host.add_child(player)
	player.set_physics_process(false)
	var camera := Camera3D.new()
	camera.name = "PlayingCamera"
	camera.set_script(load("res://scripts/CameraFollow.gd"))
	camera.set("player_path", NodePath("../Player3D"))
	host.add_child(camera)
	camera.make_current()
	var circle := Circle.new()
	host.add_child(circle)
	for frame in 5:
		await physics_frame
		await process_frame
	for kind in ["xylophone", "drums", "bells", "guitar"]:
		var instrument := circle.get_node("Playable_" + kind)
		player.global_position = instrument.to_global(Vector3(0, 2, 5))
		for frame in 3: await physics_frame
		assert(instrument._nearby, "Real player must be detected from the front")
		var interact := InputEventAction.new()
		interact.action = "interact"
		interact.pressed = true
		instrument._unhandled_input(interact)
		assert(instrument._active and not player.input_enabled)
		assert(instrument._panel.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
		var key := InputEventKey.new()
		key.pressed = true
		key.physical_keycode = KEY_A
		instrument._unhandled_input(key)
		assert(instrument.last_played == 0 and instrument._voices[0].playing,
			"Keyboard input must start an actual audio voice")
		for index in instrument.pad_labels().size():
			instrument._buttons[index].button_down.emit()
			assert(instrument.last_played == index)
			var stream: AudioStreamWAV = Sound.stream_for(kind, index)
			assert(stream != null and stream.data.size() > 1000)
			# Imported streams may use QOA compression. Verify the generated
			# source PCM rather than interpreting compressed bytes as samples.
			var pcm := FileAccess.get_file_as_bytes("res://assets/audio/music_circle/%s_%d.wav" % [kind, index])
			assert(pcm.size() > 10000 and pcm.slice(0, 4).get_string_from_ascii() == "RIFF")
			var peak := 0
			for sample_index in range(44, pcm.size() - 1, 32):
				peak = maxi(peak, absi(pcm.decode_s16(sample_index)))
			assert(peak > 1000, "Every pad must produce audible, non-silent PCM")
		await create_timer(0.65).timeout
		var pointer := InputEventMouseButton.new()
		pointer.button_index = MOUSE_BUTTON_LEFT
		pointer.pressed = true
		pointer.position = camera.unproject_position(instrument._pads[0].global_position)
		instrument._unhandled_input(pointer)
		assert(instrument.last_played == 0, "Clicking the 3D instrument must strike its real pad")
		var escape := InputEventAction.new()
		escape.action = "ui_cancel"
		escape.pressed = true
		instrument._unhandled_input(escape)
		assert(not instrument._active and player.input_enabled and camera.get("_mode") == "follow")
		# Repeated rapid hits must never change instrument size.
		for pad in instrument._pads: assert(pad.scale == Vector3.ONE)
		# A player on the rear/side can use the same interaction area.
		player.global_position = instrument.to_global(Vector3(5, 2, -3))
		for frame in 3: await physics_frame
		assert(instrument.open_playing())
		instrument.close_playing()
	var piano := circle.get_node("Playable_piano")
	piano.note_played.connect(func(midi): _last_midi = midi)
	player.global_position = piano.to_global(Vector3(0, 0.3, 0.5))
	for frame in 3: await physics_frame
	assert(piano._player_in_range and piano._keys.size() == 88 and piano._samples.size() == 36)
	piano._sit_down()
	assert(piano._seated and not player.input_enabled)
	assert(player.is_seated() and piano.has_node("PianoBench"), "Piano must seat the real controller on a physical bench")
	if player._fox_skeleton() != null: assert(player._sit_pose_applied)
	assert(player.global_position.distance_to(piano.to_global(piano.BENCH_TOP)) < 0.02)
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_A
	piano._unhandled_input(key)
	assert(piano._voices[0].playing, "The new piano uses the real sampled gallery voice")
	await create_timer(0.65).timeout
	var mesh := piano._keys[72].get_child(0) as MeshInstance3D
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.pressed = true
	pointer.position = camera.unproject_position(mesh.to_global(Vector3(0, 0.012, 0.055)))
	piano._unhandled_input(pointer)
	assert(_last_midi == 72, "Clicking a piano key must pick and sound the correct pitch")
	var tab := InputEventKey.new()
	tab.pressed = true
	tab.physical_keycode = KEY_TAB
	piano._unhandled_input(tab)
	assert(piano._keyboard_view and player.is_seated())
	piano._stand_up()
	assert(player.input_enabled and not player.is_seated() and not player._sit_pose_applied and camera.get("_mode") == "follow")
	piano._sit_down()
	assert(player.is_seated())
	piano.free()
	assert(player.input_enabled and not player.is_seated() and camera.get("_mode") == "follow", "Removing an occupied piano must restore walking")
	# Leaving the scene while playing must also restore controls.
	var last := circle.get_node("Playable_guitar")
	player.global_position = last.to_global(Vector3(0, 2, 5))
	for frame in 3: await physics_frame
	assert(last.open_playing())
	circle.free()
	assert(player.input_enabled, "Deleting an active instrument cannot leave movement locked")
	host.queue_free()
	await process_frame
	print("HEART MUSIC CIRCLE: PASS — actual proximity, keyboard, pads, audio and exit")
	quit()
