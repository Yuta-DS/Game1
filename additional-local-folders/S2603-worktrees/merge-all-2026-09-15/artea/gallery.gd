extends Node3D

@onready var paintings = [
	$Frame/Area2D/Painting1,
	$Frame2/Area2D/Painting2,
	$Frame3/Area2D/Painting3,
	$Frame4/Area2D/Painting4,
	$Frame5/Area2D/Painting5
]

func _ready() -> void:
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
