extends SceneTree

const Sound = preload("res://scripts/heart_melody/music_circle_sound.gd")

func _initialize() -> void:
	OS.set_environment("ARTEA_SYNTHESIZE_CIRCLE", "1")
	DirAccess.make_dir_recursive_absolute("res://assets/audio/music_circle")
	for kind in {"xylophone": 8, "drums": 3, "bells": 5, "guitar": 4}:
		var count: int = {"xylophone": 8, "drums": 3, "bells": 5, "guitar": 4}[kind]
		for index in count:
			var stream := Sound.stream_for(kind, index)
			var error := stream.save_to_wav("res://assets/audio/music_circle/%s_%d.wav" % [kind, index])
			if error != OK:
				push_error("Cannot prepare music-circle audio: %s %d" % [kind, index])
				quit(1)
				return
	print("MUSIC CIRCLE AUDIO: 20 voices prepared")
	quit()
