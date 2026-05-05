extends Node3D

@onready var water_audio = $"Ocean Sound"

func _ready():
	# Ensure the node exists and is inside the tree
	if water_audio and water_audio.is_inside_tree():
		# Reset the offset to the beginning just in case
		water_audio.seek(0.0) 
		water_audio.play()
		print("Ocean audio initialized instantly.")
	else:
		# Fallback: if it's not ready, play it as soon as it enters
		call_deferred("_force_play_water")

func _force_play_water():
	if water_audio:
		water_audio.play()
