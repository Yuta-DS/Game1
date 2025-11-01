extends Node3D

@export var painting_title: String = "artwork_1.png"
var current_target_sprite: Sprite2D

# --- Scene Paths ---
const HUB_WORLD_PATH = "res://New_Hub_World.tscn"
const ARTEA_GAME_PATH = "res://scenes/artea_game.tscn"
const LOADING_SCENE_PATH = preload("res://scenes/loading_scene.tscn")

func _on_body_entered(body: Node3D) -> void:
	# This function handles the primary scene transition when the player enters the Area3D.
	
	# 1. Check if the body that entered is the player (a CharacterBody3D)
	if body is CharacterBody3D:
		go_to_scene(HUB_WORLD_PATH)

func _on_back_to_hubworld_pressed() -> void:
	# This function handles returning to the main game via a UI button press (loading screen logic).
	
	var loading_screen = LOADING_SCENE_PATH.instantiate()
	loading_screen.next_scene_path = ARTEA_GAME_PATH
	
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free() 
	
# --- Core Scene Switching Logic ---

func go_to_scene(path: String):
	# Handles the final change of scene after checking file existence.
	if ResourceLoader.exists(path):
		print("TRAVELING to: ", path)
		get_tree().change_scene_to_file(path)
	else:
		print("ERROR: Target scene file not found at path:", path)
