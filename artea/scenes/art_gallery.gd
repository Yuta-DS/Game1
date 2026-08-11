extends Node3D

@export var painting_title: String = "artwork_1.png"
var current_target_sprite: Sprite2D

const HUB_WORLD_PATH = "res://scenes/New_Hub_World.tscn"
const ARTEA_GAME_PATH = "res://scenes/artea_game.tscn"
const LOADING_SCENE_PATH = preload("res://scenes/loading_scene.tscn")

@onready var paintings = [
	$Frame/Area2D/Painting1,
	$Frame2/Area2D/Painting2,
	$Frame3/Area2D/Painting3,
	$Frame4/Area2D/Painting4,
	$Frame5/Area2D/Painting5
]

func _ready() -> void:
	print("ArtGallery scene is running")

	for painting in paintings:
		painting.texture = null

	load_saved_artworks()

func load_saved_artworks() -> void:
	var dir_path = "user://artworks/"
	var dir = DirAccess.open(dir_path)

	if dir == null:
		print("No saved artworks folder found.")
		return

	var image_paths: Array[String] = []

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if !dir.current_is_dir() and file_name.ends_with(".png"):
			image_paths.append(dir_path + file_name)
		file_name = dir.get_next()

	dir.list_dir_end()

	print("Found saved images: ", image_paths.size())

	for i in range(min(image_paths.size(), paintings.size())):
		set_painting_texture(paintings[i], image_paths[i])

func set_painting_texture(painting_node: Sprite2D, path: String) -> void:
	var image := Image.new()
	var err := image.load(path)

	if err != OK:
		print("Failed to load artwork: ", path)
		return

	var texture := ImageTexture.create_from_image(image)
	painting_node.texture = texture
	print("Loaded artwork into: ", painting_node.name)

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
		print("ERROR: Target scene file not found at path: ", path)


func _request_castle_front_door_spawn() -> void:
	var global := get_node_or_null("/root/Global")
	if global != null and global.has_method("request_spawn_at"):
		global.request_spawn_at("castle_front_door")
