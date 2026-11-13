extends Control
const SceneLoader := preload("res://scripts/scene_loader.gd")

func _on_back_to_hub_button_pressed() -> void:
	SceneLoader.change_scene_with_loading(get_tree(), "res://scenes/artea_game.tscn")
