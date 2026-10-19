class_name HeartMelodyAudioDirector
extends RefCounted
signal cue(caption: String, note: int)
var player: AudioStreamPlayer
var muted := false
var cache: Dictionary = {}
const FREQUENCIES := [261.63, 293.66, 329.63, 392.0, 440.0, 523.25]

func play_note(index: int, volume := 0.22, timbre := 6) -> void:
	index = clampi(index, 0, 5)
	cue.emit("Note %d" % (index + 1), index)
	if muted or not is_instance_valid(player): return
	var key := str(index) + ":" + str(timbre)
	if not cache.has(key):
		var wave := AudioStreamWAV.new()
		wave.format = AudioStreamWAV.FORMAT_16_BITS
		wave.mix_rate = 22050
		var bytes := PackedByteArray()
		bytes.resize(11025 * 2)
		for i in 11025:
			var t := i / 22050.0
			var frequency: float = FREQUENCIES[index]
			var sample := (sin(TAU * frequency * t) + 0.18 * sin(TAU * frequency * (2 + timbre % 3) * t)) * exp(-t * (5 + timbre * 0.4)) * minf(t * 100, 1) * 0.7
			bytes.encode_s16(i * 2, int(sample * 32767))
		wave.data = bytes
		cache[key] = wave
	player.volume_db = linear_to_db(clampf(volume, 0.001, 1.0))
	player.stream = cache[key]
	player.play()

func cancel() -> void:
	if is_instance_valid(player): player.stop()
