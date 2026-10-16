extends Node2D
const SceneLoader := preload("res://scripts/scene_loader.gd")

 
func _on_play_button_pressed() -> void:
	SceneLoader.change_scene_with_loading(get_tree(), "res://scenes/authentication.tscn")
	
