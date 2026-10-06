extends Node
# Editable synchronized synthesized layers; gain changes never restart a loop.
var layers: Array[AudioStreamPlayer] = []
var target_state := -1

func _ready() -> void:
	for layer in 3:
		var player := AudioStreamPlayer.new()
		player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
		player.stream = _loop(layer)
		player.volume_db = -80 if layer > 0 else -30
		add_child(player)
		layers.append(player)
		player.play()

func restore(planted: bool, complete: bool) -> void:
	var state := int(planted) + 2 * int(complete)
	if state == target_state: return
	target_state = state
	for i in range(1, 3):
		var audible := planted if i == 1 else complete
		create_tween().tween_property(layers[i], "volume_db", -25.0 if audible else -80.0, 1.2)

func _loop(layer: int) -> AudioStreamWAV:
	var sample_rate := 11025
	var length := sample_rate * 8
	var bytes := PackedByteArray()
	bytes.resize(length * 2)
	for i in length:
		var t := float(i) / sample_rate
		var sample := 0.0
		if layer == 0:
			sample = (sin(TAU * 130.875 * t) + 0.35 * sin(TAU * 196.0 * t)) * 0.12 * (0.8 + 0.2 * sin(TAU * t / 8))
		else:
			var beat := fmod(t, 2.0)
			var frequency: float = [261.625, 392.0, 329.625, 392.0][int(t / 2)]
			sample = sin(TAU * frequency * beat) * exp(-beat * 3) * minf(beat * 40, 1) * 0.3
			if layer == 2:
				beat = fmod(t, 0.5)
				sample = sin(TAU * 98 * beat) * exp(-beat * 22) * minf(beat * 100, 1) * 0.35
		bytes.encode_s16(i * 2, int(sample * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = length
	return stream
