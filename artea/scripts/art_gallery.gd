extends Node2D

@export var painting_title: String = "artwork_1.png"

var current_target_sprite: Sprite2D

func _ready() -> void:
	pass


func _on_back_to_hubworld_pressed() -> void:
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/artea_game.tscn"
	
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free() 
