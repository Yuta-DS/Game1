extends Node3D


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/art_gallery_3d_inprogress.tscn")
