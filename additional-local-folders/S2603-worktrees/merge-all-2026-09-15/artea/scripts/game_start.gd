extends Node2D

 
func _on_play_button_pressed() -> void:
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/authentication.tscn"
	
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free() 
	
