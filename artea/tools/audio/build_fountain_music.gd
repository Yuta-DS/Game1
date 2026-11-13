extends SceneTree

const Sound = preload("res://scripts/heart_melody/music_circle_sound.gd")
const RATE := 22050
const FRAMES := RATE * 16

func _initialize() -> void:
	OS.set_environment("ARTEA_SYNTHESIZE_CIRCLE", "1")
	var mix := PackedFloat32Array()
	mix.resize(FRAMES)
	var melody := [0, 2, 4, 6, 5, 4, 2, 1, 0, 2, 5, 7, 6, 4, 2, 1,
		0, 1, 2, 4, 5, 4, 2, 0, 3, 5, 7, 5, 4, 2, 1, 0]
	for index in melody.size():
		_add(mix, Sound.stream_for("bells", melody[index]).data if melody[index] < 5 else Sound.stream_for("xylophone", melody[index]).data, index * RATE / 2, 0.32)
	for index in 8:
		_add(mix, Sound.stream_for("guitar", [0, 1, 2, 3][index % 4]).data, index * RATE * 2, 0.48)
	var bytes := PackedByteArray()
	bytes.resize(FRAMES * 2)
	for index in FRAMES: bytes.encode_s16(index * 2, int(clampf(mix[index], -0.9, 0.9) * 32767))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = RATE
	wave.data = bytes
	var result := wave.save_to_wav("res://assets/audio/music_circle/fountain_theme.wav")
	print("FOUNTAIN MUSIC: ", "PASS" if result == OK else error_string(result))
	quit(0 if result == OK else 1)

func _add(mix: PackedFloat32Array, pcm: PackedByteArray, start: int, gain: float) -> void:
	for frame in pcm.size() / 2:
		var index := (start + frame) % FRAMES
		mix[index] += float(pcm.decode_s16(frame * 2)) / 32767.0 * gain
