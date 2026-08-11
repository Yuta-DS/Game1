extends Node2D

func _on_button_pressed() -> void:
	# The hub lives in res://scenes/. Pointed at res://New_Hub_World.tscn this
	# button did nothing at all — the start screen was a dead end.
	get_tree().change_scene_to_file("res://scenes/New_Hub_World.tscn")
