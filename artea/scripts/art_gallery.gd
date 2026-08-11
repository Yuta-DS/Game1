extends Node3D

@export var painting_title: String = "artwork_1.png"


@export var frame_name : String = ""
var current_target_sprite: Sprite2D
var selected_frame_name: String = ""
var player_near_artwork = false
var current_frame_name := ""
var _world_opening := false

# --- Scene Paths ---
const HUB_WORLD_PATH = "res://scenes/New_Hub_World.tscn"
const ARTEA_GAME_PATH = "res://scenes/artea_game.tscn"
const CREATION_WORLD_PATH = "res://scenes/creation_world.tscn"
const QUEST_JOURNAL_PATH = "res://scenes/crown_quest_journal.tscn"
const LOADING_SCENE_PATH = preload("res://scenes/loading_scene.tscn")

# --- Rating UI ---
@onready var ratingpanel: Control = $CanvasLayer/RatingPanel
@onready var ratinglabel: Label = $CanvasLayer/RatingPanel/RatingLabel
@onready var likebutton: Button = $CanvasLayer/RatingPanel/HBoxContainer/LikeButton




func _ready() -> void:
	_build_galaxy_transit()
	_build_quest_journal_button()
	likebutton.visible = true
	
	likebutton.text = "♥"

	
	print("RatingPanel = ", ratingpanel)
	print("RatingLabel = ", ratinglabel)
	print("likebutton = ", likebutton)
	
	
			
	likebutton.pressed.connect(func(): _on_rate_button_pressed(1))
	

	if ratingpanel:
		ratingpanel.visible = false


# The complete train-and-island kingdom belongs inside this cosmic Art Castle
# scene. Runtime construction avoids duplicating the large generated meshes in
# the scene file and guarantees the islands exist before rails resolve docks.
func _build_galaxy_transit() -> void:
	var transit_transform := Transform3D(Basis.from_scale(Vector3.ONE * 0.5),
		Vector3(0.0, -33.0, 1.3))

	var isles := Node3D.new()
	isles.name = "GalaxyIsles"
	isles.transform = transit_transform
	isles.set_script(load("res://scripts/hub_sky_isles.gd"))
	add_child(isles)

	var rail := Node3D.new()
	rail.name = "SkyRail"
	rail.transform = transit_transform
	rail.set_script(load("res://scripts/hub_skyrail.gd"))
	add_child(rail)

	var rider := Node3D.new()
	rider.name = "TrainRider"
	rider.set_script(load("res://scripts/hub_train_rider.gd"))
	add_child(rider)
		
		
func _input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
		_open_quest_journal()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept") and player_near_artwork:
		_enter_current_frame_world()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("rate_artwork") and player_near_artwork:

		show_rating_panel(
			current_frame_name,
			$GalleryManager.get_frame_rating(current_frame_name)
		)


func _build_quest_journal_button() -> void:
	var button := Button.new()
	button.name = "CrownJourneyJournalButton"
	button.text = "✦ Crown Journey  [J]"
	button.tooltip_text = "Open the Crown of Life quest journal"
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.position = Vector2(-250.0, 24.0)
	button.custom_minimum_size = Vector2(220.0, 48.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(_open_quest_journal)
	$CanvasLayer.add_child(button)


func _open_quest_journal() -> void:
	var campaign := get_node_or_null("/root/JourneyCampaign")
	if campaign != null and campaign.has_method("open_quest_journal"):
		if bool(campaign.call("open_quest_journal")):
			return
	if ResourceLoader.exists(QUEST_JOURNAL_PATH):
		get_tree().change_scene_to_file(QUEST_JOURNAL_PATH)

func show_rating_panel(frame_name: String, current_rating: int) -> void:
	print("Frame:", frame_name)
	print("Current rating:", current_rating)

	selected_frame_name = frame_name
	ratingpanel.visible = true

	if current_rating > 0:
		ratinglabel.text = "Artwork Rating: ♥\nEnter / Space — explore this artwork"
		ratinglabel.modulate = Color.RED
		likebutton.modulate = Color.RED
	else:
		ratinglabel.text = "Artwork Rating: ♡\nEnter / Space — explore this artwork"
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
		if path == HUB_WORLD_PATH:
			_request_castle_front_door_spawn()
		print("TRAVELING to: ", path)
		get_tree().change_scene_to_file(path)
	else:
		print("ERROR: Target scene file not found at path:", path)


# Exit1's body_entered signal is connected to this gallery root, not to the
# ExitGallery script on the Area3D. Carry the destination explicitly here so
# every real doorway return lands at the castle it just exited.
func _request_castle_front_door_spawn() -> void:
	var global := get_node_or_null("/root/Global")
	if global != null and global.has_method("request_spawn_at"):
		global.request_spawn_at("castle_front_door")


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


func _enter_current_frame_world() -> void:
	if current_frame_name.is_empty() or _world_opening:
		return
	_world_opening = true
	var path: String = $GalleryManager.prepare_frame_for_world(current_frame_name)
	if path.is_empty() or not FileAccess.file_exists(path):
		_world_opening = false
		ratinglabel.text = "This artwork is not available locally yet. Please try again."
		return
	var state := get_node_or_null("/root/CreationWorldState")
	if state == null:
		_world_opening = false
		ratinglabel.text = "The interactive artwork world is not available in this scene yet."
		return
	if not ResourceLoader.exists(CREATION_WORLD_PATH):
		_world_opening = false
		ratinglabel.text = "The interactive artwork world is still being prepared. Please try again shortly."
		return

	state.prepare_artwork(path, current_frame_name.replace("_", " "))
	ratinglabel.text = "Building your interactive 3D artwork world…\nYou will be able to walk, jump and interact inside it."
	state.prepare_explorable_world(func(ok: bool, response: Dictionary) -> void:
		if not is_instance_valid(self):
			return
		if not ok:
			_world_opening = false
			ratinglabel.text = str(response.get("error",
				"This artwork world could not open yet. Please try again."))
			return
		var transition_error := get_tree().change_scene_to_file(CREATION_WORLD_PATH)
		if transition_error != OK:
			_world_opening = false
			ratinglabel.text = "The interactive artwork world could not open yet. Please try again."
	)
