class_name MindSparkFoley
extends RefCounted

## Deterministic, mono 48 kHz Foley for the magical objects and combat actions.
## Mono is intentional: AudioStreamPlayer3D spatialises it to the listener's
## detected speaker layout (including 7.1) without a baked-in stereo direction.

const MIX_RATE := 48000


static func make_quest_feedback(object_kind: int, completed: bool) -> AudioStreamWAV:
	var base_frequencies := [523.25, 740.0, 659.25, 440.0, 196.0, 293.66,
		880.0, 155.56, 392.0, 987.77, 130.81, 587.33]
	var frequency: float = base_frequencies[clampi(object_kind, 0, base_frequencies.size() - 1)]
	var duration := 0.72 if object_kind in [6, 8, 9] else 0.46
	var character := object_kind % 4
	return _render("quest_%02d_%s" % [object_kind, "complete" if completed else "progress"],
		frequency * (1.25 if completed else 1.0), duration, character, 0.24)


static func make_combat_event(event: StringName) -> AudioStreamWAV:
	match event:
		&"player_swing": return _render(event, 210.0, 0.32, 3, 0.55)
		&"player_block": return _render(event, 330.0, 0.42, 1, 0.42)
		&"player_hurt": return _render(event, 145.0, 0.38, 0, 0.48)
		&"enemy_notice": return _render(event, 510.0, 0.30, 2, 0.20)
		&"enemy_telegraph": return _render(event, 185.0, 0.68, 2, 0.30)
		&"enemy_attack": return _render(event, 115.0, 0.44, 3, 0.62)
		&"enemy_hit": return _render(event, 275.0, 0.30, 0, 0.52)
		&"enemy_block": return _render(event, 720.0, 0.25, 1, 0.34)
		&"enemy_defeat": return _render(event, 165.0, 0.82, 2, 0.44)
		&"warden_storm": return _render(event, 82.0, 1.05, 3, 0.70)
		&"warden_strike": return _render(event, 68.0, 0.72, 3, 0.82)
		&"warden_open": return _render(event, 392.0, 1.15, 1, 0.30)
		&"warden_hit": return _render(event, 220.0, 0.36, 0, 0.54)
		&"warden_free": return _render(event, 261.63, 1.45, 2, 0.26)
		_: return _render(event, 440.0, 0.35, 0, 0.25)


static func make_play_event(event: StringName) -> AudioStreamWAV:
	match event:
		&"pad_bounce": return _render(event, 196.0, 0.42, 2, 0.08)
		&"water_splash": return _render_splash(event)
		_: return _render(event, 440.0, 0.35, 0, 0.25)


## A body landing in water, built the way real splashes sound (van den Doel,
## "Physically based models for liquid sounds", 2005): the slap of the surface
## breaking, a low thump and churn of displaced water, then hundreds of
## microscopic bubbles. Each bubble rings for a few milliseconds at the
## Minnaert frequency for its size (~3.26 kHz / radius in mm), rising in pitch
## as it surfaces; together they are what the ear hears as "water". A few big
## bubbles give the glug, and droplets falling back give the patter.
## `size` scales how much water moves: ~0.7 a step in, 1.0 a jump, 1.6 a dive.
static func _render_splash(event: StringName, size := 1.0) -> AudioStreamWAV:
	# Nothing here sits above ~10 kHz, so a lower rate halves the work.
	const RATE := 32000
	const DURATION := 1.2
	var frames := roundi(DURATION * RATE)
	var mix := PackedFloat32Array()
	mix.resize(frames)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(event))
	# One-pole low-pass coefficients for the fixed cutoffs.
	var k2200 := 1.0 - exp(-TAU * 2200.0 / RATE)
	var k400 := 1.0 - exp(-TAU * 400.0 / RATE)
	var k250 := 1.0 - exp(-TAU * 250.0 / RATE)
	var k180 := 1.0 - exp(-TAU * 180.0 / RATE)
	var k25 := 1.0 - exp(-TAU * 25.0 / RATE)
	var slap_lo := 0.0
	var slap_hi := 0.0
	var thump_a := 0.0
	var thump_b := 0.0
	var rush_lo := 0.0
	var rush_hi := 0.0
	var churn := 0.0
	for index in frames:
		var t := float(index) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		# A body entering water takes tens of milliseconds, so nothing starts
		# at full level. An instant onset is what makes a splash read as a
		# gunshot or a drum.
		var swell := smoothstep(0.0, 0.06, t)
		# Slap: a soft band-passed (~400 Hz-2.2 kHz) smack, not a crack.
		slap_hi += k2200 * (noise - slap_hi)
		slap_lo += k400 * (slap_hi - slap_lo)
		var slap := (slap_hi - slap_lo) * swell * exp(-t * 22.0) * 0.2
		# Thump: noise through two low-passes at ~180 Hz - a body of water
		# moving, not a pitched drum.
		thump_a += k180 * (noise - thump_a)
		thump_b += k180 * (thump_a - thump_b)
		var thump := thump_b * swell * exp(-t * 7.0) * 5.0 * size
		# Rush: the sheet of water thrown up and falling, band-passed noise
		# that darkens as it settles, swelling and dipping like churned water.
		churn += k25 * (rng.randf_range(0.2, 1.8) - churn)
		rush_hi += (1.0 - exp(-TAU * (700.0 + 1800.0 * exp(-t * 5.0)) / RATE)) * (noise - rush_hi)
		rush_lo += k250 * (rush_hi - rush_lo)
		# Swells over ~0.1 s and washes on, rather than bursting and stopping.
		var rush := (rush_hi - rush_lo) * churn * smoothstep(0.0, 0.1, t) \
			* exp(-t * 3.0 / sqrt(size)) * 0.9
		mix[index] = slap + thump + rush
	# Small entrained bubbles, spread across the wash and thinning out.
	for bubble in roundi(260 * size):
		var start := 0.03 + pow(rng.randf(), 1.2) * 0.65
		var radius_mm := exp(rng.randf_range(log(0.7), log(4.0)))
		_add_bubble(mix, RATE, start, radius_mm, 0.016 * radius_mm * (1.0 - start))
	# A few large bubbles from the cavity the body leaves behind: the glug.
	for bubble in roundi(4 * size):
		_add_bubble(mix, RATE, rng.randf_range(0.06, 0.28), rng.randf_range(8.0, 14.0),
			rng.randf_range(0.12, 0.2))
	# Droplets raining back onto the surface: tiny, bright, scattered.
	for drop in roundi(110 * size):
		var start := 0.12 + pow(rng.randf(), 1.6) * 0.85
		_add_bubble(mix, RATE, start, rng.randf_range(0.35, 1.4),
			rng.randf_range(0.015, 0.045) * (1.15 - start))
	# A final gentle low-pass (~4.5 kHz) takes the edge off the whole mix.
	var k_out := 1.0 - exp(-TAU * 4500.0 / RATE)
	var smoothed := 0.0
	var peak := 0.0
	for index in frames:
		smoothed += k_out * (mix[index] - smoothed)
		mix[index] = smoothed
		peak = maxf(peak, absf(smoothed))
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for index in frames:
		# Short fade-out so the tail never clicks.
		var fade := minf(1.0, float(frames - index) / (0.08 * RATE))
		var value := mix[index] / maxf(peak, 0.0001) * 0.8 * fade
		bytes.encode_s16(index * 2, clampi(roundi(value * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.set_meta("foley_event", event)
	wav.set_meta("source_quality", "48 kHz mono positional")
	return wav


## One bubble ringing (van den Doel): Minnaert frequency from its radius, a
## damping that grows with frequency so small bubbles are only a click, and a
## pitch that rises as the bubble nears the surface.
static func _add_bubble(mix: PackedFloat32Array, rate: int, start: float,
		radius_mm: float, amplitude: float) -> void:
	var frequency := 3260.0 / radius_mm
	if frequency > rate * 0.4:
		return
	var damping := 0.13 * frequency + 0.0072 * pow(frequency, 1.5)
	var first := roundi(start * rate)
	var last := mini(mix.size(), first + roundi(minf(5.0 / damping, 0.2) * rate))
	var phase := 0.0
	for index in range(first, last):
		var age := float(index - first) / rate
		phase += TAU * frequency * (1.0 + 0.1 * damping * age) / rate
		mix[index] += sin(phase) * exp(-damping * age) * amplitude


static func _render(event: StringName, frequency: float, duration: float,
		character: int, noise_amount: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	var frames := maxi(1, roundi(duration * MIX_RATE))
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var noise_state := 0.173 + float(abs(hash(String(event))) % 997) / 997.0
	for index in frames:
		var t := float(index) / MIX_RATE
		var progress := float(index) / frames
		var attack := minf(1.0, t / 0.018)
		var decay := pow(maxf(0.0, 1.0 - progress), 1.7 if character != 1 else 1.15)
		var envelope := attack * decay
		noise_state = fmod(noise_state * 3.987654 + 0.12345, 1.0)
		var noise := noise_state * 2.0 - 1.0
		var pitch_curve := 1.0
		if character == 2:
			pitch_curve = 0.76 + progress * 0.62
		elif character == 3:
			pitch_curve = 1.35 - progress * 0.62
		var phase := TAU * frequency * pitch_curve * t
		var tone := sin(phase) * 0.58 + sin(phase * 2.01) * 0.19 + sin(phase * 3.98) * 0.08
		if character == 1:
			# Bell/glass partials ring independently instead of forming a plain beep.
			tone = sin(phase) * 0.46 + sin(phase * 2.71) * 0.24 * exp(-t * 2.2) \
				+ sin(phase * 4.13) * 0.13 * exp(-t * 4.1)
		elif character == 3:
			# Airy impacts and swings emphasise filtered turbulence.
			noise *= sin(PI * progress)
		var sample_value := (tone * (1.0 - noise_amount) + noise * noise_amount) * envelope * 0.72
		var sample := clampi(roundi(sample_value * 32767.0), -32768, 32767)
		bytes[index * 2] = sample & 0xff
		bytes[index * 2 + 1] = (sample >> 8) & 0xff
	wav.data = bytes
	wav.set_meta("foley_event", event)
	wav.set_meta("source_quality", "48 kHz mono positional")
	return wav
