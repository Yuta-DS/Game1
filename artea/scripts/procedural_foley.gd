class_name ProceduralFoley
extends RefCounted

## Small deterministic foley synthesizer. The clips are generated in memory so
## the same surface sounds work in native builds and the non-threaded Web build.

const SAMPLE_RATE := 22050


static func make_footstep(surface: StringName, variant := 0) -> AudioStreamWAV:
	var duration := 0.27
	if surface == &"sand" or surface == &"gravel" or surface == &"grass":
		duration = 0.32
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var random := RandomNumberGenerator.new()
	random.seed = hash("%s_%d" % [String(surface), variant]) + 0x4152544541
	var low_noise := 0.0
	var mid_noise := 0.0
	for index in sample_count:
		var time := float(index) / SAMPLE_RATE
		var heel_time := time
		var toe_time := time - (0.085 + float(variant % 3) * 0.006)
		var heel := exp(-heel_time * 25.0) * smoothstep(0.0, 0.006, heel_time)
		var toe := exp(-maxf(0.0, toe_time) * 31.0) \
			* smoothstep(0.0, 0.004, toe_time) if toe_time >= 0.0 else 0.0
		var impact := heel + toe * 0.68
		var noise := random.randf_range(-1.0, 1.0)
		low_noise = lerpf(low_noise, noise, 0.045)
		mid_noise = lerpf(mid_noise, noise, 0.26)
		var dry_noise := noise - low_noise
		var value := 0.0
		match surface:
			&"grass":
				# Crushed blades and soft soil: broadband fibre crackle without a
				# pitched oscillator, so grass cannot ring like sheet metal.
				var crush := exp(-time * 10.5) * smoothstep(0.0, 0.012, time)
				value = (mid_noise * 0.52 + low_noise * 0.28) * crush
				value += dry_noise * impact * 0.13
				value += sin(TAU * 74.0 * time) * heel * 0.13
			&"wood":
				# Keep the warm bridge knock that already reads correctly in game.
				value = sin(TAU * (148.0 + variant * 4.0) * time) * impact * 0.54
				value += mid_noise * impact * 0.17
				value += sin(TAU * 690.0 * time) * exp(-time * 68.0) * 0.18
			&"sand":
				var scrape := exp(-time * 8.5) * smoothstep(0.0, 0.018, time)
				value = (dry_noise * 0.20 + mid_noise * 0.44) * scrape
				value += low_noise * impact * 0.18
			&"gravel":
				var scatter := exp(-time * 9.0) * smoothstep(0.0, 0.008, time)
				var pebble := 1.0 if random.randf() > 0.955 else 0.0
				value = (mid_noise * 0.33 + dry_noise * 0.15) * scatter
				value += dry_noise * pebble * scatter * 0.42
				value += sin(TAU * (185.0 + variant * 11.0) * time) * impact * 0.10
			&"brick":
				# Dry masonry contact; the body tone is deliberately short and quiet.
				value = sin(TAU * (205.0 + variant * 7.0) * time) * impact * 0.27
				value += (mid_noise * 0.32 + dry_noise * 0.09) * impact
			&"stone":
				value = sin(TAU * (268.0 + variant * 9.0) * time) * impact * 0.31
				value += (mid_noise * 0.30 + dry_noise * 0.08) * impact
			&"metal":
				# The only intentionally ringing footstep family.
				value = sin(TAU * (720.0 + variant * 35.0) * time) * exp(-time * 17.0) * 0.34
				value += sin(TAU * 1190.0 * time) * exp(-time * 29.0) * 0.16
				value += dry_noise * impact * 0.10
			_: # compacted earth / dirt
				value = sin(TAU * (82.0 + variant * 2.0) * time) * impact * 0.42
				value += low_noise * impact * 0.45 + mid_noise * impact * 0.16
		samples[index] = clampf(value * 0.82, -1.0, 1.0)
	return _stream_from_samples(samples, false)


static func make_vegetation_brush(variant := 0) -> AudioStreamWAV:
	# A lateral leaf/blade swish. This is intentionally not a foot impact: it has
	# a soft attack and a long moving tail, used only when passing beside foliage.
	var duration := 0.48 + float(variant % 3) * 0.035
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var random := RandomNumberGenerator.new()
	random.seed = 0x4252555348 + variant * 7919
	var mid_noise := 0.0
	for index in sample_count:
		var time := float(index) / SAMPLE_RATE
		var progress := time / duration
		var raw := random.randf_range(-1.0, 1.0)
		mid_noise = lerpf(mid_noise, raw, 0.18)
		var swish := sin(PI * progress) * (0.72 + sin(TAU * progress * 2.3) * 0.16)
		var leaf_tick := 1.0 if random.randf() > 0.982 else 0.0
		var value := mid_noise * swish * 0.48 + (raw - mid_noise) * leaf_tick * swish * 0.18
		samples[index] = clampf(value, -1.0, 1.0)
	return _stream_from_samples(samples, false)


static func make_wind_loop(seed_value: int, rustle := false) -> AudioStreamWAV:
	var duration := 5.0
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var low_noise := 0.0
	var high_noise := 0.0
	for index in sample_count:
		var time := float(index) / SAMPLE_RATE
		var raw := random.randf_range(-1.0, 1.0)
		low_noise = lerpf(low_noise, raw, 0.012)
		high_noise = lerpf(high_noise, raw, 0.18)
		var gust := 0.52 + sin(TAU * time / duration) * 0.19 \
			+ sin(TAU * time * 0.61 + 1.7) * 0.11
		var value := low_noise * gust * 1.65
		if rustle:
			var leaf_pulse := pow(maxf(0.0, sin(TAU * time * 1.9 + 0.7)), 5.0)
			value += high_noise * leaf_pulse * 0.24
		# Crossfade the generated tail toward the head to avoid a Web loop click.
		var seam := minf(float(index) / 900.0, float(sample_count - 1 - index) / 900.0)
		value *= clampf(seam, 0.0, 1.0)
		samples[index] = clampf(value, -1.0, 1.0)
	return _stream_from_samples(samples, true)


static func make_train_loop(layer: StringName) -> AudioStreamWAV:
	var duration := 4.0 if layer == &"engine" else 2.0
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var random := RandomNumberGenerator.new()
	random.seed = hash(String(layer)) + 0x545241494E
	var filtered_noise := 0.0
	for index in sample_count:
		var time := float(index) / SAMPLE_RATE
		var phase := fmod(time, duration)
		var raw := random.randf_range(-1.0, 1.0)
		filtered_noise = lerpf(filtered_noise, raw, 0.045)
		var value := 0.0
		match layer:
			&"engine":
				# A warm magitech traction motor: low mechanical fundamentals plus
				# a quiet crystal/reactor overtone that remains audible while docked.
				value = sin(TAU * 42.0 * time) * 0.32
				value += sin(TAU * 84.0 * time + 0.35) * 0.18
				value += sin(TAU * 168.0 * time + sin(time * 0.9) * 0.4) * 0.055
				value += filtered_noise * 0.18
			&"rail":
				# Eight wheel joints per loop. Each impact has a metal click followed
				# by a short low carriage resonance.
				var joint_phase := fmod(phase * 4.0, 1.0)
				var impact := pow(maxf(0.0, 1.0 - joint_phase * 18.0), 4.0)
				value = sin(TAU * 710.0 * time) * impact * 0.58
				value += sin(TAU * 126.0 * time) * impact * 0.32
				value += filtered_noise * impact * 0.24
			_:
				value = filtered_noise * 0.5
		var seam := minf(float(index) / 480.0,
			float(sample_count - 1 - index) / 480.0)
		samples[index] = clampf(value * clampf(seam, 0.0, 1.0), -1.0, 1.0)
	return _stream_from_samples(samples, true)


static func make_train_event(event_name: StringName) -> AudioStreamWAV:
	var duration := 1.8 if event_name == &"departure" else 1.25
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var random := RandomNumberGenerator.new()
	random.seed = hash(String(event_name)) + 0x4152544541
	var hiss := 0.0
	for index in sample_count:
		var time := float(index) / SAMPLE_RATE
		var progress := time / duration
		var value := 0.0
		if event_name == &"departure":
			# A friendly two-note Crown Line departure call rather than a harsh
			# real-world locomotive horn.
			var note_envelope := sin(PI * clampf(progress, 0.0, 1.0))
			var second_note := smoothstep(0.34, 0.48, progress)
			value = sin(TAU * 293.66 * time) * (1.0 - second_note) * 0.44
			value += sin(TAU * 392.0 * time) * second_note * 0.38
			value += sin(TAU * 587.33 * time) * note_envelope * 0.08
			value *= note_envelope
		else:
			# Brake shoe shimmer, followed by a pneumatic release at the dock.
			var squeal_envelope := pow(maxf(0.0, 1.0 - progress), 1.7)
			var frequency := lerpf(1250.0, 620.0, progress)
			value = sin(TAU * frequency * time) * squeal_envelope * 0.18
			var raw := random.randf_range(-1.0, 1.0)
			hiss = lerpf(hiss, raw, 0.22)
			value += hiss * smoothstep(0.42, 0.62, progress) \
				* pow(maxf(0.0, 1.0 - progress), 0.55) * 0.42
		samples[index] = clampf(value, -1.0, 1.0)
	return _stream_from_samples(samples, false)


static func make_world_object_loop(kind: StringName) -> AudioStreamWAV:
	var duration := 6.0
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var random := RandomNumberGenerator.new()
	random.seed = hash(String(kind)) + 0x574F524C44
	var low_noise := 0.0
	for index in sample_count:
		var time := float(index) / SAMPLE_RATE
		var phase := fmod(time, duration)
		var raw := random.randf_range(-1.0, 1.0)
		low_noise = lerpf(low_noise, raw, 0.025)
		var value := 0.0
		match kind:
			&"mechanism":
				var turn := fmod(phase * 1.25, 1.0)
				var knock := pow(maxf(0.0, 1.0 - turn * 22.0), 4.0)
				value = sin(TAU * 63.0 * time) * 0.22 + sin(TAU * 138.0 * time) * knock * 0.24
				value += low_noise * 0.16
			&"forge":
				var strike_phase := fmod(phase + 1.1, 2.4)
				var strike := pow(maxf(0.0, 1.0 - strike_phase * 9.0), 5.0)
				value = low_noise * (0.28 + sin(time * 1.7) * 0.08)
				value += sin(TAU * 880.0 * time) * strike * 0.34
			&"cavern":
				value = sin(TAU * 51.0 * time) * 0.12 + low_noise * 0.34
				value += sin(TAU * 147.0 * time + sin(time * 0.35)) * 0.045
			&"station":
				var bell_phase := fmod(phase, 4.0)
				var bell := exp(-bell_phase * 2.8)
				value = (sin(TAU * 523.25 * time) * 0.28 \
					+ sin(TAU * 783.99 * time) * 0.15) * bell
			&"magic":
				value = sin(TAU * 110.0 * time) * 0.11
				value += sin(TAU * 329.63 * time + sin(time * 0.6) * 0.8) * 0.075
				value += sin(TAU * 659.25 * time + 1.2) * 0.035
			_:
				value = low_noise * 0.2
		var seam := minf(float(index) / 900.0,
			float(sample_count - 1 - index) / 900.0)
		samples[index] = clampf(value * clampf(seam, 0.0, 1.0), -1.0, 1.0)
	return _stream_from_samples(samples, true)


static func _stream_from_samples(samples: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in samples.size():
		bytes.encode_s16(index * 2, int(clampf(samples[index], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream
