extends SceneTree

const Policy = preload("res://scripts/web_audio_policy.gd")

func _initialize() -> void:
	var drawing := (load("res://scenes/drawing_tool.tscn") as PackedScene).instantiate()
	var music := drawing.get_node("AudioStreamPlayer") as AudioStreamPlayer
	assert(music.stream.get_length() > 1800, "Exercise the real half-hour soundtrack")
	Policy.configure_player(music, false)
	assert(music.playback_type == AudioServer.PLAYBACK_TYPE_DEFAULT, "Native playback is unchanged")
	Policy.configure_player(music, true)
	assert(music.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "Long Web music streams before autoplay")
	var note := AudioStreamPlayer.new()
	var wave := AudioStreamWAV.new()
	wave.mix_rate = 22050
	wave.data = PackedByteArray()
	note.stream = wave
	Policy.configure_player(note, true)
	assert(note.playback_type == AudioServer.PLAYBACK_TYPE_DEFAULT, "Short notes retain low-latency samples")
	note.free()
	for kind in [AudioStreamPlayer2D, AudioStreamPlayer3D]:
		var player: Node = kind.new()
		player.set("stream", music.stream)
		Policy.configure_player(player, true)
		assert(player.get("playback_type") == AudioServer.PLAYBACK_TYPE_STREAM)
		player.free()
	drawing.free()
	print("WEB AUDIO MEMORY POLICY: PASS")
	quit()
