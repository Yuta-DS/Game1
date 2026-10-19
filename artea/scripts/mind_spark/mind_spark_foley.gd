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
		&"water_splash": return _render(event, 140.0, 0.55, 3, 0.85)
		_: return _render(event, 440.0, 0.35, 0, 0.25)


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
