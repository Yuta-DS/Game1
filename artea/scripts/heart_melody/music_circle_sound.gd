extends RefCounted

## Short, cached PCM voices prepared offline and shipped with the game.
## Synthesis remains available for rebuilding the files and native fallback.
static var _cache: Dictionary = {}
const MIDI := [60, 62, 64, 65, 67, 69, 71, 72]
const CHORDS := [[48, 52, 55, 60, 64, 67], [45, 52, 57, 60, 64, 69],
	[41, 48, 53, 57, 60, 65], [43, 50, 55, 59, 62, 67]]

static func stream_for(kind: String, index: int) -> AudioStreamWAV:
	var key := "%s:%d" % [kind, index]
	if _cache.has(key):
		return _cache[key]
	var prepared_path := "res://assets/audio/music_circle/%s_%d.wav" % [kind, index]
	if OS.get_environment("ARTEA_SYNTHESIZE_CIRCLE") != "1" and ResourceLoader.exists(prepared_path):
		var prepared := load(prepared_path) as AudioStreamWAV
		_cache[key] = prepared
		return prepared
	var rate := 22050
	var duration := 1.35 if kind in ["guitar", "bells"] else 0.70
	var count := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for sample_index in count:
		var t := float(sample_index) / rate
		var sample := 0.0
		var attack := minf(t * 300.0, 1.0)
		if kind == "guitar":
			for string_index in 6:
				var age := t - float(string_index) * 0.018
				if age < 0.0:
					continue
				var frequency := 440.0 * pow(2.0, (float(CHORDS[index][string_index]) - 69.0) / 12.0)
				sample += (sin(TAU * frequency * age) + 0.35 * sin(TAU * frequency * age * 2.0)
					+ 0.15 * sin(TAU * frequency * age * 3.0)) * exp(-age * 4.5) * minf(age * 350, 1.0) / 7.0
		elif kind == "drums":
			var base: float = [90.0, 135.0, 190.0][index]
			var phase := TAU * (base * t + 30.0 * (1.0 - exp(-t * 30.0)) / 30.0)
			var noise := fmod(sin(float(sample_index + 1) * 78.233) * 43758.5453, 1.0)
			sample = (0.72 * sin(phase) * exp(-t * 15.0)
				+ 0.18 * noise * exp(-t * 65.0)) * attack
		else:
			var frequency := 440.0 * pow(2.0, (float(MIDI[index]) - 69.0) / 12.0)
			if kind == "bells":
				sample = (sin(TAU * frequency * t) * exp(-t * 3.2)
					+ 0.35 * sin(TAU * frequency * 2.76 * t) * exp(-t * 5.0)
					+ 0.18 * sin(TAU * frequency * 5.4 * t) * exp(-t * 8.0)) * attack * 0.58
			else:
				sample = (sin(TAU * frequency * t) * exp(-t * 8.0)
					+ 0.30 * sin(TAU * frequency * 3.0 * t) * exp(-t * 18.0)) * attack * 0.65
		# Smooth the final milliseconds so releasing a voice cannot click.
		sample *= minf((duration - t) * 100.0, 1.0)
		bytes.encode_s16(sample_index * 2, int(clampf(sample, -0.95, 0.95) * 32767))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = rate
	wave.data = bytes
	_cache[key] = wave
	return wave
