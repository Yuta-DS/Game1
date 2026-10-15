extends Node2D
const SceneLoader := preload("res://scripts/scene_loader.gd")

func _on_button_pressed() -> void:
	# The hub lives in res://scenes/. Pointed at res://New_Hub_World.tscn this
	# button did nothing at all — the start screen was a dead end.
	SceneLoader.change_scene(get_tree(), "res://scenes/New_Hub_World.tscn")
