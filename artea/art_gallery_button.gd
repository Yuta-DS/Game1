extends Node3D

const SceneLoader := preload("res://scripts/scene_loader.gd")


func _on_button_pressed() -> void:
	SceneLoader.change_scene_with_loading(get_tree(), "res://scenes/art_gallery_3d_inprogress.tscn")
