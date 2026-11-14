extends Node3D


func _on_pop_thoughts_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/popThoughtsMenu.tscn")
