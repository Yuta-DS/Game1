extends Node3D

@export var painting_title: String = "artwork_1.png"
var current_target_sprite: Sprite2D
var selected_frame_name: String = ""

# --- Scene Paths ---
const HUB_WORLD_PATH = "res://scenes/New_Hub_World.tscn"
const ARTEA_GAME_PATH = "res://scenes/artea_game.tscn"
const LOADING_SCENE_PATH = preload("res://scenes/loading_scene.tscn")

# --- Rating UI ---
@onready var rating_panel: Control = $CanvasLayer/RatingPanel
@onready var artwork_label: Label = $CanvasLayer/RatingPanel/ArtworkLabel
@onready var rating_label: Label = $CanvasLayer/RatingPanel/RatingLabel
@onready var rate_1_button: Button = $CanvasLayer/RatingPanel/Rate1
@onready var rate_2_button: Button = $CanvasLayer/RatingPanel/Rate2
@onready var rate_3_button: Button = $CanvasLayer/RatingPanel/Rate3
@onready var rate_4_button: Button = $CanvasLayer/RatingPanel/Rate4
@onready var rate_5_button: Button = $CanvasLayer/RatingPanel/Rate5
@onready var close_button: Button = $CanvasLayer/RatingPanel/CloseButton

func _ready() -> void:
	print("ArtGallery ready")

	if has_node("CanvasLayer/RatingPanel"):
		print("RatingPanel found")
	else:
		print("RatingPanel missing")
		
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		show_rating_panel("Frame_01", $GalleryManager.get_frame_rating("Frame_01"))

func show_rating_panel(frame_name: String, current_rating: int) -> void:
	selected_frame_name = frame_name
	rating_panel.visible = true
	artwork_label.text = "Artwork: " + frame_name

	if current_rating > 0:
		rating_label.text = "Current Rating: " + str(current_rating) + "/5"
	else:
		rating_label.text = "Current Rating: Not rated"

func hide_rating_panel() -> void:
	rating_panel.visible = false
	selected_frame_name = ""

func _on_rate_button_pressed(value: int) -> void:
	if selected_frame_name == "":
		return

	var gallery_manager = $GalleryManager
	if gallery_manager:
		gallery_manager.rate_frame(selected_frame_name, value)
		var updated_rating = gallery_manager.get_frame_rating(selected_frame_name)
		rating_label.text = "Current Rating: " + str(updated_rating) + "/5"

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		go_to_scene(HUB_WORLD_PATH)

func _on_back_to_hubworld_pressed() -> void:
	var loading_screen = LOADING_SCENE_PATH.instantiate()
	loading_screen.next_scene_path = ARTEA_GAME_PATH

	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free()

func go_to_scene(path: String) -> void:
	if ResourceLoader.exists(path):
		print("TRAVELING to: ", path)
		get_tree().change_scene_to_file(path)
	else:
		print("ERROR: Target scene file not found at path:", path)


func _on_open_test_button_pressed() -> void:
	pass # Replace with function body.
