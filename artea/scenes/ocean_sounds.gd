extends Node3D

func _ready():
	# This looks for the sounds even if they are in a different part of the map
	call_deferred("_find_and_play_ocean")

func _find_and_play_ocean():
	# Use 'find_child' to search the whole scene for these specific names
	var s1 = get_tree().root.find_child("Ocean Sound", true, false)
	var s2 = get_tree().root.find_child("Ocean Sound 2", true, false)
	
	if s1:
		s1.play()
		print("Found and started Ocean 1")
	if s2:
		s2.play()
		print("Found and started Ocean 2")
