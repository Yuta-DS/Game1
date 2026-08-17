extends Node3D

# The legacy GLB contains root-transform animation tracks. When it is placed
# directly in the hub those tracks reset the landmark to world origin. Keep the
# historical model as a static statue and reassert its authored sign position.

func _ready() -> void:
	for animation_node in find_children("*", "AnimationPlayer", true, false):
		var animation_player := animation_node as AnimationPlayer
		animation_player.stop()
		animation_player.process_mode = Node.PROCESS_MODE_DISABLED
	global_position = Vector3(110.0, 20.0, -15.0)
	rotation_degrees = Vector3(0.0, 100.4, 0.0)
	scale = Vector3.ONE * 10.0

