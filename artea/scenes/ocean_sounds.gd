extends Node3D

@onready var water_audio = $"Water Flow" # Make sure this matches your node name

func _ready():
	# Wait for the engine to fully wake up
	await get_tree().process_frame
	if water_audio:
		water_audio.play()
		print("Water sounds forced to start!")
