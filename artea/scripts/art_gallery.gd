extends Node3D

@export var painting_title: String = "artwork_1.png"


@export var frame_name : String = ""
var current_target_sprite: Sprite2D
var selected_frame_name: String = ""
var player_near_artwork = false
var current_frame_name := ""

# --- Scene Paths ---
const HUB_WORLD_PATH = "res://scenes/New_Hub_World.tscn"
const ARTEA_GAME_PATH = "res://scenes/artea_game.tscn"
const LOADING_SCENE_PATH = preload("res://scenes/loading_scene.tscn")

# --- Rating UI ---
@onready var ratingpanel: Control = $CanvasLayer/RatingPanel
@onready var ratinglabel: Label = $CanvasLayer/RatingPanel/RatingLabel
@onready var likebutton: Button = $CanvasLayer/RatingPanel/HBoxContainer/LikeButton




func _ready() -> void:
	likebutton.visible = true
	
	likebutton.text = "♥"

	
	print("RatingPanel = ", ratingpanel)
	print("RatingLabel = ", ratinglabel)
	print("likebutton = ", likebutton)
	
	
			
	likebutton.pressed.connect(func(): _on_rate_button_pressed(1))
	

	if ratingpanel:
		ratingpanel.visible = false
		
		
func _input(event):

	if event.is_action_pressed("rate_artwork") and player_near_artwork:

		show_rating_panel(
			current_frame_name,
			$GalleryManager.get_frame_rating(current_frame_name)
		)

func show_rating_panel(frame_name: String, current_rating: int) -> void:
	print("Frame:", frame_name)
	print("Current rating:", current_rating)

	selected_frame_name = frame_name
	ratingpanel.visible = true

	if current_rating > 0:
		ratinglabel.text = "Artwork Rating:\n♥"
		ratinglabel.modulate = Color.RED
		likebutton.modulate = Color.RED
	else:
		ratinglabel.text = "Artwork Rating:\n♡"
		ratinglabel.modulate = Color.WHITE
		likebutton.modulate = Color.WHITE
		
func hide_rating_panel() -> void:
	ratingpanel.visible = false
	selected_frame_name = ""

func _on_rate_button_pressed(value: int) -> void:
	if selected_frame_name == "":
		return

	var gallery_manager = $GalleryManager

	if gallery_manager:
		var current_rating = gallery_manager.get_frame_rating(selected_frame_name)

		if current_rating > 0:
			gallery_manager.rate_frame(selected_frame_name, 0)

			ratinglabel.text = "Artwork Rating:\n♡"
			ratinglabel.modulate = Color.WHITE
			likebutton.modulate = Color.WHITE

		else:
			gallery_manager.rate_frame(selected_frame_name, 1)

			ratinglabel.text = "Artwork Rating:\n♥"
			ratinglabel.modulate = Color.RED
			likebutton.modulate = Color.RED			
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
	print("Test button pressed")


func _on_interaction_area_body_entered(body, frame_name):

	if body.name != "Player3D":
		return

	player_near_artwork = true
	current_frame_name = frame_name

	var rating = $GalleryManager.get_frame_rating(frame_name)

	print("Entered:", frame_name)
	print("Rating returned:", rating)

	show_rating_panel(frame_name, rating)
	

func _on_interaction_area_body_exited(body, frame_name):

	if body.name != "Player3D":
		return

	print("Exited:", frame_name)

	player_near_artwork = false
	current_frame_name = ""

	hide_rating_panel()
