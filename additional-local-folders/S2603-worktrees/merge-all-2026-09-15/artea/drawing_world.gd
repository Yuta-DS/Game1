extends Node3D

func _on_explore_colours_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/drawing_tool.tscn")
