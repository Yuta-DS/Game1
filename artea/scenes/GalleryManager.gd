extends Node3D

# =========================================================
# CONFIG
# =========================================================

#const WORKER_LIST_URL = "https://artea-gallery-api.artea-gallery-api.workers.dev/list-art"

#const MY_ARTWORKS_URL = "http://54.252.162.122/my_artworks"
#const SERVER_BASE = "http://54.252.162.122"
const RatingHeart := preload("res://scripts/rating_heart.gd")
const MY_ARTWORKS_URL = APIManager.MY_ARTWORKS_URL
const SERVER_BASE = APIManager.BASE_URL
const R2_DOWNLOAD_HOST = "https://pub-dcfcf45c45f94920a79a5f0ef9ecb177.r2.dev"
const PLACEHOLDER_PATH = "res://assets/ArtGallery/placeholders/"
const PLACEHOLDERS = [
	preload("res://assets/ArtGallery/placeholders/painting_1.jpeg"),
	preload("res://assets/ArtGallery/placeholders/painting_2.jpeg"),
	preload("res://assets/ArtGallery/placeholders/painting_3.jpeg"),
	preload("res://assets/ArtGallery/placeholders/painting_4.jpeg"),
	preload("res://assets/ArtGallery/placeholders/painting_5.jpeg"),
	preload("res://assets/ArtGallery/placeholders/painting_6.JPG"),
	preload("res://assets/ArtGallery/placeholders/painting_7.jpeg"),
	preload("res://assets/ArtGallery/placeholders/painting_8.jpeg"),
	preload("res://assets/ArtGallery/placeholders/painting_9.jpeg"),
	preload("res://assets/ArtGallery/placeholders/painting_10.jpeg"),
	preload("res://assets/ArtGallery/placeholders/painting_11.jpeg"),
	preload("res://assets/ArtGallery/placeholders/painting_12.jpeg")
]

const LOCAL_ART_PATH = "user://artworks/"
const RATINGS_FILE_PATH = "user://artworks/ratings.json"

const MAX_FRAMES_TO_LOAD = 12


var current_frame_hovered := ""
var current_rating := 0

# The rating widgets live under CanvasLayer/RatingPanel, a sibling of this node.
# Resolve all three controls from that one production panel so gallery setup
# cannot be interrupted by stale or partial overlay paths.
@onready var rating_ui = $"../CanvasLayer/RatingPanel"
@onready var rating_label: Label = $"../CanvasLayer/RatingPanel/RatingLabel"
@onready var likebutton: Button = $"../CanvasLayer/RatingPanel/HBoxContainer/LikeButton"
# =========================================================
# NODES
# =========================================================

@onready var list_request = $ListHTTPRequest
@onready var download_request = $DownloadHTTPRequest


# =========================================================
# DATA
# =========================================================

var image_metadata: Array = []

var images_to_download: Array = []

var current_frame_index: int = 0

var local_art_paths: Array[String] = []

# Keeps track of artwork assigned to frames
var frame_to_artwork: Dictionary = {}

var current_download_artwork_id = null

var online_gallery_ready := false
var local_gallery_ready := false


# Resolve any gallery frame into a local image path so every artwork — local,
# downloaded, or placeholder — can open through the same creation-world pipe.
# Remote images are copied from the frame texture into the private user folder;
# no network URL or credential is handed to the world scene.
func prepare_frame_for_world(frame_name: String) -> String:
	if frame_to_artwork.has(frame_name):
		var mapped = frame_to_artwork[frame_name]
		if mapped is String and FileAccess.file_exists(mapped):
			return mapped

	var frame := get_node_or_null("../" + frame_name)
	if frame == null or not frame is Sprite3D or frame.texture == null:
		return ""
	var image: Image = frame.texture.get_image()
	if image == null or image.is_empty():
		return ""
	var directory := "user://artworks/world_sources/"
	DirAccess.make_dir_recursive_absolute(directory)
	var safe_name := frame_name.validate_filename()
	var path := "%s%s_%d.png" % [directory, safe_name, Time.get_ticks_usec()]
	return path if image.save_png(path) == OK else ""


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	list_request.request_completed.connect(_on_list_request_completed)
	download_request.request_completed.connect(_on_download_request_completed)

	rating_ui.visible = false

	load_placeholders()

	list_user_artworks()
	



# =========================================================
# LOCAL ART LOADING
# =========================================================
func load_placeholders() -> void:
	for i in range(MAX_FRAMES_TO_LOAD):

		var frame_name = "Frame_%02d" % (i + 1)
		var frame_node = get_node_or_null("../" + frame_name)

		if frame_node == null:
			print("Could not find frame: ", frame_name)
			continue

		# Use the preloaded resources as the source of truth. The old filename
		# reconstruction mapped Frame 06 to painting_5.png and skipped painting_6.JPG;
		# case-sensitive Web exports could therefore leave frames blank.
		one_placeholder(frame_node, PLACEHOLDERS[i])
		
func one_placeholder(frame_node: Sprite3D, texture: Texture2D) -> void:
	if texture == null:
		print("Failed to load placeholder for ", frame_node.name)
		return

	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		frame_node.texture = texture
		return
	if image.is_compressed() and image.decompress() != OK:
		# Retain the original playable artwork if a platform cannot decode it.
		frame_node.texture = texture
		return
	image.resize(512, 512, Image.INTERPOLATE_BILINEAR)

	var resized_texture = ImageTexture.create_from_image(image)

	frame_node.texture = resized_texture
	frame_node.visible = true
	frame_node.modulate = Color.WHITE

func load_local_art_paths() -> void:

	local_art_paths.clear()

	var dir = DirAccess.open(LOCAL_ART_PATH)

	if dir == null:
		return

	var art_files: Array[Dictionary] = []

	dir.list_dir_begin()

	var file_name = dir.get_next()

	while file_name != "":

		if !dir.current_is_dir():

			var lower_name = file_name.to_lower()

			if lower_name.ends_with(".png") \
			or lower_name.ends_with(".jpg") \
			or lower_name.ends_with(".jpeg"):

				var full_path = LOCAL_ART_PATH + file_name

				var modified_time = FileAccess.get_modified_time(full_path)

				art_files.append({
					"path": full_path,
					"modified": modified_time
				})

		file_name = dir.get_next()

	dir.list_dir_end()

	# Newest artworks first
	art_files.sort_custom(
		func(a, b): return a["modified"] > b["modified"]
	)

	for item in art_files.slice(
		0,
		mini(MAX_FRAMES_TO_LOAD, art_files.size())
	):

		local_art_paths.append(item["path"])

	for i in range(local_art_paths.size()):

		print("Local order ", i, ": ", local_art_paths[i])


# =========================================================
# ONLINE ART LOADING
# =========================================================

func list_user_artworks() -> void:

	# Offline Guest deliberately carries a sentinel token so the rest of the
	# game can distinguish it from an uninitialised session. It is not a bearer
	# credential and must never be sent to the gallery API. Besides exposing a
	# fake credential, doing so on Web attempts to contact localhost and produces
	# an unhandled browser fetch error before the expected local fallback.
	if not Global.has_authenticated_session():
		load_local_art_paths()
		apply_local_art_over_online()
		return

	var headers = [
		"Authorization: Bearer " + Global.auth_token
	]

	var error = list_request.request(
		MY_ARTWORKS_URL,
		headers
	)

	if error != OK:

		print("Failed to request user artworks, fallback to local")

		load_local_art_paths()

		apply_local_art_over_online()


func _on_list_request_completed(
	result,
	response_code,
	headers,
	body
):

	if response_code != 200:

		print("Gallery API failed → fallback local")

		load_local_art_paths()

		apply_local_art_over_online()

		return

	var data = JSON.parse_string(
		body.get_string_from_utf8()
	)

	if typeof(data) != TYPE_ARRAY:

		print("Invalid JSON → fallback local")

		load_local_art_paths()

		apply_local_art_over_online()

		return
		
	if data.is_empty():

		print("Authenticated user has no online artwork.")
		load_local_art_paths()
		apply_local_art_over_online()
		online_gallery_ready = true
		return

	images_to_download.clear()

	for item in data:

		images_to_download.append({
			"id": item.id,
			"url": SERVER_BASE + item.url
		})

	current_frame_index = 0

	frame_to_artwork.clear()

	start_next_download()


func start_next_download() -> void:

	if current_frame_index >= MAX_FRAMES_TO_LOAD \
	or images_to_download.is_empty():

		print("Finished loading online gallery.")

		print_all_frame_ratings()
		online_gallery_ready = true

		return

	var artwork_data = images_to_download.pop_front()
	
	current_download_artwork_id = int(artwork_data["id"])

	var full_url = artwork_data["url"]

	print("Downloading online art: ", full_url)

	var error = download_request.request(full_url)

	if error != OK:

		print(
			"ERROR: Could not start download request for ",
			full_url,
			". Error code: ",
			error
		)

		start_next_download()


func _on_download_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	if response_code == 200:

		var image = Image.new()

		var load_error := image.load_png_from_buffer(body)
		if load_error != OK:
			load_error = image.load_jpg_from_buffer(body)
		if load_error != OK:
			load_error = image.load_webp_from_buffer(body)

		if load_error == OK:

			image.resize(
				512,
				512,
				Image.INTERPOLATE_BILINEAR
			)

			var texture = ImageTexture.create_from_image(image)

			var frame_name = "Frame_%02d" % (
				current_frame_index + 1
			)

			var frame_node = get_node_or_null(
				"../" + frame_name
			)

			if frame_node and frame_node is Sprite3D:

				frame_node.texture = texture
				frame_node.visible = true
				frame_node.modulate = Color.WHITE

				frame_to_artwork[frame_name] = int(current_download_artwork_id)

				print(
					"Assigned artwork ID ",
					current_download_artwork_id,
					" to ",
					frame_name
				)

			else:

				print(
					"WARNING: Could not find frame node: ",
					frame_name
				)

			current_frame_index += 1

		else:

			print(
				"ERROR: Failed to load online image from buffer. Load error code:",
				load_error
			)

	else:

		print(
			"ERROR: Image download failed with code:",
			response_code
		)

	start_next_download()


# =========================================================
# APPLY LOCAL ART
# =========================================================

func apply_local_art_over_online() -> void:

	if local_art_paths.is_empty():
		local_gallery_ready = true
		return

	for i in range(
		min(local_art_paths.size(), MAX_FRAMES_TO_LOAD)
	):

		var image = Image.new()

		var load_error = image.load(local_art_paths[i])

		if load_error != OK:

			print(
				"Failed to load local artwork: ",
				local_art_paths[i]
			)

			continue

		image.resize(
			512,
			512,
			Image.INTERPOLATE_BILINEAR
		)

		var texture = ImageTexture.create_from_image(image)

		var frame_name = "Frame_%02d" % (i + 1)

		var frame_node = get_node_or_null(
			"../" + frame_name
		)

		if frame_node and frame_node is Sprite3D:

			frame_node.texture = texture
			frame_node.visible = true
			frame_node.modulate = Color.WHITE

			frame_to_artwork[frame_name] = local_art_paths[i]

			print(
				"Player artwork applied to frame: ",
				frame_name
			)

		else:

			print(
				"WARNING: Could not find frame node: ",
				frame_name
			)
	update_rating_labels()
	local_gallery_ready = true

# =========================================================
# RATING SYSTEM
# =========================================================

func load_ratings() -> Dictionary:

	if not FileAccess.file_exists(RATINGS_FILE_PATH):

		return {}

	var file = FileAccess.open(
		RATINGS_FILE_PATH,
		FileAccess.READ
	)

	if file == null:

		print("Could not open ratings file for reading.")

		return {}

	var content = file.get_as_text()

	file.close()

	var parsed = JSON.parse_string(content)

	if parsed is Dictionary:

		return parsed

	print("Ratings file format invalid.")

	return {}


func save_ratings(ratings: Dictionary) -> void:

	var dir = DirAccess.open("user://")

	if dir != null:

		dir.make_dir_recursive("artworks")

	var file = FileAccess.open(
		RATINGS_FILE_PATH,
		FileAccess.WRITE
	)

	if file == null:

		print("Could not open ratings file for writing.")

		return

	file.store_string(JSON.stringify(ratings))

	file.close()


func set_artwork_rating(
	artwork_key: String,
	rating: int
) -> void:

	var ratings = load_ratings()

	ratings[artwork_key] = clamp(rating, 0, 1)

	save_ratings(ratings)

	print(
		"Saved rating ",
		rating,
		" for ",
		artwork_key
	)


func get_artwork_rating(
	artwork_key: String
) -> int:

	var ratings = load_ratings()

	if ratings.has(artwork_key):

		return int(ratings[artwork_key])

	return 0


func rate_frame(
	frame_name: String,
	rating: int
) -> void:

	if not frame_to_artwork.has(frame_name):

		print("No artwork assigned to frame: ", frame_name)

		return

	var artwork_key = str(frame_to_artwork[frame_name])

	print("Saving frame:", frame_name)
	print("Artwork key:", artwork_key)
	print("Rating:", rating)

	set_artwork_rating(artwork_key, rating)

	update_rating_labels()
	update_frame_rating_color(frame_name)

	print(
		"Frame ",
		frame_name,
		" rating: ",
		get_artwork_rating(artwork_key)
	)

func get_frame_rating(frame_name: String) -> int:
	
	if not online_gallery_ready and not local_gallery_ready:
		return 0

	print("Checking frame:", frame_name)
	print("frame_to_artwork:", frame_to_artwork)

	if not frame_to_artwork.has(frame_name):
		print("FRAME NOT FOUND")
		return 0

	var artwork_key = str(frame_to_artwork[frame_name])
	

	print("Artwork key:", artwork_key)

	if artwork_key == "[ONLINE]":
		return 0

	return get_artwork_rating(artwork_key)


func print_all_frame_ratings() -> void:

	print("=== Frame Ratings ===")

	for frame_name in frame_to_artwork.keys():

		var artwork_key = str(frame_to_artwork[frame_name])

		if artwork_key == "[ONLINE]":

			print(frame_name, " -> ONLINE ART")

		else:

			print(
				frame_name,
				" -> ",
				artwork_key,
				" | Rating: ",
				get_artwork_rating(artwork_key)
			)


# =========================================================
# DEBUG
# =========================================================

func clear_local_artworks():

	var dir = DirAccess.open(LOCAL_ART_PATH)

	if dir == null:

		return

	dir.list_dir_begin()

	var file_name = dir.get_next()

	while file_name != "":

		if file_name.ends_with(".png"):

			DirAccess.remove_absolute(
				LOCAL_ART_PATH + file_name
			)

		file_name = dir.get_next()

	dir.list_dir_end()
	
	
	
func update_rating_labels():

	for frame_name in frame_to_artwork.keys():

		var rating = get_frame_rating(frame_name)
		print("Frame:", frame_name)
		print("Rating:", rating)

		var frame = get_node_or_null("../" + frame_name)

		if frame == null:
			continue

		var label = frame.get_node_or_null("RatingLabel")

		

		if label == null:
			continue

		if rating > 0:
			label.text = "♥"
			label.modulate = Color.RED
		else:
			label.text = ""

			
			
			
func update_frame_rating_color(frame_name: String):

	var rating = get_frame_rating(frame_name)

	var frame = get_node_or_null("../" + frame_name)

	if frame == null:
		return

	var label = frame.get_node_or_null("RatingLabel")

	if label == null:
		return

	if rating > 0:
		label.modulate = Color.RED
	else:
		label.text = ""
		
					
func show_rating_ui(frame_name: String) -> void:
	
	

	rating_ui.visible = true

	var rating = get_frame_rating(frame_name)
	print("Showing rating for:", frame_name)
	print("Saved rating:", rating)

	RatingHeart.apply_to_label(rating_label, rating > 0)
	RatingHeart.apply_to_button(likebutton, rating > 0)		


func hide_rating_ui() -> void:

	current_frame_hovered = ""

	rating_ui.visible = false
	
func _input(event):

	if event.is_action_pressed("ui_accept"):

		if current_frame_hovered == "":
			return

		var current_saved_rating = get_frame_rating(current_frame_hovered)

		if current_saved_rating == 0:
			rate_frame(current_frame_hovered, 1)
		else:
			rate_frame(current_frame_hovered, 0)

		show_rating_ui(current_frame_hovered)
			


func _on_interaction_area_body_entered(body: Node3D, frame_name: String) -> void:

	pass
	
	

func _on_interaction_area_body_exited(body: Node3D, frame_name: String) -> void:

	pass
	
	
