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
@onready var rate1: Button = $CanvasLayer/RatingPanel/HBoxContainer/Rate1
@onready var rate2: Button = $CanvasLayer/RatingPanel/HBoxContainer/Rate2
@onready var rate3: Button = $CanvasLayer/RatingPanel/HBoxContainer/Rate3
@onready var rate4: Button = $CanvasLayer/RatingPanel/HBoxContainer/Rate4
@onready var rate5: Button = $CanvasLayer/RatingPanel/HBoxContainer/Rate5
#@onready var artwork_label: Label = $CanvasLayer/RatingPanel/ArtworkLabel
#@onready var rating_label: Label = $CanvasLayer/RatingPanel/RatingLabel
#@onready var rate1: Button = $CanvasLayer/RatingPanel/Rate1
#@onready var rate2: Button = $CanvasLayer/RatingPanel/Rate2
#@onready var rate_3_button: Button = $CanvasLayer/RatingPanel/Rate3
#@onready var rate_4_button: Button = $CanvasLayer/RatingPanel/Rate4
#@onready var rate_5_button: Button = $CanvasLayer/RatingPanel/Rate5
#@onready var close_button: Button = $CanvasLayer/RatingPanel/CloseButton



func _ready() -> void:
	rate1.visible = true
	rate2.visible = true
	rate3.visible = true
	rate4.visible = true
	rate5.visible = true
	rate1.text = "★"
	rate2.text = "★★"
	rate3.text = "★★★"
	rate4.text = "★★★★"
	rate5.text = "★★★★★"
	
	print("RatingPanel = ", ratingpanel)
	print("RatingLabel = ", ratinglabel)
	print("Rate1 = ", rate1)
			
	rate1.pressed.connect(func(): _on_rate_button_pressed(1))
	rate2.pressed.connect(func(): _on_rate_button_pressed(2))
	rate3.pressed.connect(func(): _on_rate_button_pressed(3))
	rate4.pressed.connect(func(): _on_rate_button_pressed(4))
	rate5.pressed.connect(func(): _on_rate_button_pressed(5))

	if ratingpanel:
		ratingpanel.visible = false
		
		
func _input(event):

	if event.is_action_pressed("rate_artwork") and player_near_artwork:

		show_rating_panel(
			current_frame_name,
			$GalleryManager.get_frame_rating(current_frame_name)
		)

func show_rating_panel(frame_name: String, current_rating: int) -> void:
	selected_frame_name = frame_name
	ratingpanel.visible = true

	var stars := ""

	for i in range(5):
		if i < current_rating:
			stars += "★"
		else:
			stars += "☆"

	ratinglabel.text = "Artwork Rating:\n" + stars


func hide_rating_panel() -> void:
	ratingpanel.visible = false
	selected_frame_name = ""

func _on_rate_button_pressed(value: int) -> void:
	if selected_frame_name == "":
		return

	var gallery_manager = $GalleryManager
	if gallery_manager:
		gallery_manager.rate_frame(selected_frame_name, value)
		var updated_rating = gallery_manager.get_frame_rating(selected_frame_name)
		var stars := ""

		for i in range(5):
			if i < updated_rating:
				stars += "★"
			else:
				stars += "☆"

		ratinglabel.text = "Artwork Rating:\n" + stars

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

	print("Entered:", frame_name)

	show_rating_panel(
		frame_name,
		$GalleryManager.get_frame_rating(frame_name)
	)
	

func _on_interaction_area_body_exited(body, frame_name):

	if body.name != "Player3D":
		return

	print("Exited:", frame_name)

	player_near_artwork = false
	current_frame_name = ""

	hide_rating_panel()
