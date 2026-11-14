extends Node3D

func _ready():
	# Give the world a half-second to fully load everything
	await get_tree().create_timer(0.5).timeout
	_find_and_play_ocean()

func _find_and_play_ocean():
	# Search from root to find the sounds anywhere in the scene tree
	var s1 = get_tree().root.find_child("Ocean Sound", true, false)
	var s2 = get_tree().root.find_child("Ocean Sound 2", true, false)
	
	if s1:
		if s1.has_method("play"):
			s1.play()
			s1.set("volume_db", 0.0)
			print("✅ Ocean 1 Found and Playing")
	else:
		print("❌ ERROR: 'Ocean Sound' not found. Check the name in your Scene Tree!")

	if s2:
		if s2.has_method("play"):
			s2.play()
			s2.set("volume_db", 0.0)
			print("✅ Ocean 2 Found and Playing")

	# THE FIX: Safely enabling the Audio Listener
	var viewport = get_viewport()
	if viewport:
		# This is the standard Godot 4 way to enable the 'ears'
		viewport.audio_listener_enable_3d = true
		print("👂 Audio Listener enabled on Viewport")
