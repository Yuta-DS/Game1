extends Node3D

const Art = preload("res://scripts/heart_melody/heart_art.gd")
const Instrument = preload("res://scripts/heart_melody/music_circle_instrument.gd")
const Piano = preload("res://scripts/heart_melody/music_circle_piano.gd")

func _ready() -> void:
	Art.label(self, "HEART MELODY · FREE PLAY\nPiano · Xylophone · Hand drums · Bells · Guitar\nWalk up to an instrument and press Q", Vector3(0, 17, -88), 56)
	_build_instruments.call_deferred()

func _build_instruments() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		push_error("Heart music circle requires the gameplay camera")
		return
	var positions := [Vector3(0, 0, -62), Vector3(-59, 0, -20), Vector3(-36, 0, 50),
		Vector3(36, 0, 50), Vector3(59, 0, -20)]
	var kinds := ["piano", "xylophone", "drums", "bells", "guitar"]
	var titles := ["Grand piano", "Rainbow xylophone", "Hand drums", "Garden bells", "Guitar chords"]
	for index in kinds.size():
		var position_value: Vector3 = positions[index]
		var stage := Art.cone(self, position_value + Vector3.UP * 0.07, 11, 11, 0.14, Color("e2c4b7"), true, 32)
		stage.name = "Stage_%s" % kinds[index]
		var instrument: Node3D
		if index == 0:
			instrument = Piano.new()
			instrument.scale = Vector3.ONE * 5.0
			instrument.camera_path = camera.get_path()
		else:
			instrument = Instrument.new()
			instrument.kind = kinds[index]
			instrument.title = titles[index]
		instrument.name = "Playable_%s" % kinds[index]
		instrument.position = position_value + Vector3.UP * 0.14
		# Keyboard/front pads face the open centre, with ample circulation space.
		instrument.rotation.y = atan2(-position_value.x, -position_value.z)
		add_child(instrument)
		Art.label(self, titles[index] + " · Q to play", position_value + Vector3.UP * 10, 30)
