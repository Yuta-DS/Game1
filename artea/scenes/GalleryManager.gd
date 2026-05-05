extends Node3D

const WORKER_LIST_URL = "https://artea-gallery-api.artea-gallery-api.workers.dev/list-art"
const R2_DOWNLOAD_HOST = "https://pub-dcfcf45c45f94920a79a5f0ef9ecb177.r2.dev"

const LOCAL_ART_PATH = "user://artworks/"
const RATINGS_FILE_PATH = "user://artworks/ratings.json"
const MAX_FRAMES_TO_LOAD = 12

@onready var list_request = $ListHTTPRequest
@onready var download_request = $DownloadHTTPRequest

var image_metadata: Array = []
var images_to_download: Array[String] = []

var current_frame_index: int = 0
var local_art_paths: Array[String] = []

# Keeps track of which artwork file/path is shown in which frame
var frame_to_artwork: Dictionary = {}

func _ready() -> void:
	list_request.request_completed.connect(_on_list_request_completed)
	download_request.request_completed.connect(_on_download_request_completed)

	load_local_art_paths()
	list_bucket_contents()

# =========================================================
# LOCAL ART LOADING
# =========================================================
func load_local_art_paths() -> void:
	local_art_paths.clear()

	var dir = DirAccess.open(LOCAL_ART_PATH)
	if dir == null:
		print("No local artworks found.")
		return

	var art_files: Array[Dictionary] = []

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if !dir.current_is_dir():
			var lower_name = file_name.to_lower()
			if lower_name.ends_with(".png") or lower_name.ends_with(".jpg") or lower_name.ends_with(".jpeg"):
				var full_path = LOCAL_ART_PATH + file_name
				var modified_time = FileAccess.get_modified_time(full_path)

				art_files.append({
					"path": full_path,
					"modified": modified_time
				})
		file_name = dir.get_next()

	dir.list_dir_end()

	# Newest saved artwork first
	art_files.sort_custom(func(a, b): return a["modified"] > b["modified"])

	for item in art_files.slice(0, mini(MAX_FRAMES_TO_LOAD, art_files.size())):
		local_art_paths.append(item["path"])

	print("Player artworks found: ", local_art_paths.size())
	for i in range(local_art_paths.size()):
		print("Local order ", i, ": ", local_art_paths[i])

# =========================================================
# ONLINE ART LOADING
# =========================================================
func list_bucket_contents() -> void:
	var error = list_request.request(WORKER_LIST_URL)

	if error != OK:
		print("ERROR: Could not start Worker request. Godot Error Code:", error)

func _on_list_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		print("ERROR: Worker list request failed with code:", response_code)
		print("Response body:", body.get_string_from_utf8())
		return

	var json_result = JSON.parse_string(body.get_string_from_utf8())

	if json_result is Array:
		image_metadata = json_result
	else:
		print("ERROR: Worker returned invalid JSON format.")
		return

	image_metadata.sort_custom(sort_by_last_modified)

	var newest_metadata = image_metadata.slice(0, mini(MAX_FRAMES_TO_LOAD, image_metadata.size()))

	images_to_download.clear()
	for item in newest_metadata:
		images_to_download.append(item.filename)

	print("Finished listing online images. Total found: ", image_metadata.size())

	current_frame_index = 0
	frame_to_artwork.clear()
	start_next_download()

func sort_by_last_modified(a, b):
	return a.last_modified > b.last_modified

func start_next_download() -> void:
	if current_frame_index >= MAX_FRAMES_TO_LOAD or images_to_download.is_empty():
		print("Finished loading online gallery.")
		apply_local_art_over_online()
		print_all_frame_ratings()
		return

	var filename = images_to_download.pop_front()
	var full_url = R2_DOWNLOAD_HOST.trim_suffix("/") + "/" + filename

	print("Downloading online art: ", full_url)

	var error = download_request.request(full_url)

	if error != OK:
		print("ERROR: Could not start download request for ", filename, ". Error code: ", error)
		start_next_download()

func _on_download_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var image = Image.new()
		var load_error = image.load_jpg_from_buffer(body)

		if load_error == OK:
			image.resize(512, 512, Image.INTERPOLATE_BILINEAR)

			var texture = ImageTexture.create_from_image(image)

			var frame_name = "Frame_%02d" % (current_frame_index + 1)
			var frame_node = get_node_or_null("../" + frame_name)

			if frame_node and frame_node is Sprite3D:
				frame_node.texture = texture
				frame_to_artwork[frame_name] = "[ONLINE]"
				print("Online art applied to frame: ", frame_name)
			else:
				print("WARNING: Could not find or access frame node: ", frame_name)

			current_frame_index += 1
		else:
			print("ERROR: Failed to load online image from buffer. Load error code:", load_error)
	else:
		print("ERROR: Image download failed with code:", response_code)

	start_next_download()

func apply_local_art_over_online() -> void:
	if local_art_paths.is_empty():
		print("No player artworks to replace online gallery.")
		return

	print("Applying player artworks over online gallery...")

	for i in range(min(local_art_paths.size(), MAX_FRAMES_TO_LOAD)):
		var image = Image.new()
		var load_error = image.load(local_art_paths[i])

		if load_error != OK:
			print("Failed to load local artwork: ", local_art_paths[i])
			continue

		image.resize(512, 512, Image.INTERPOLATE_BILINEAR)

		var texture = ImageTexture.create_from_image(image)

		var frame_name = "Frame_%02d" % (i + 1)
		var frame_node = get_node_or_null("../" + frame_name)

		if frame_node and frame_node is Sprite3D:
			frame_node.texture = texture
			frame_to_artwork[frame_name] = local_art_paths[i]
			print("Player artwork replaced online art in frame: ", frame_name)
		else:
			print("WARNING: Could not find frame node: ", frame_name)

# =========================================================
# RATING SYSTEM
# =========================================================
func load_ratings() -> Dictionary:
	if not FileAccess.file_exists(RATINGS_FILE_PATH):
		return {}

	var file = FileAccess.open(RATINGS_FILE_PATH, FileAccess.READ)
	if file == null:
		print("Could not open ratings file for reading.")
		return {}

	var content = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	if parsed is Dictionary:
		return parsed

	print("Ratings file format invalid. Returning empty ratings.")
	return {}

func save_ratings(ratings: Dictionary) -> void:
	var dir = DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive("artworks")

	var file = FileAccess.open(RATINGS_FILE_PATH, FileAccess.WRITE)
	if file == null:
		print("Could not open ratings file for writing.")
		return

	file.store_string(JSON.stringify(ratings))
	file.close()

func set_artwork_rating(artwork_key: String, rating: int) -> void:
	var ratings = load_ratings()
	ratings[artwork_key] = clamp(rating, 1, 5)
	save_ratings(ratings)
	print("Saved rating ", rating, " for ", artwork_key)

func get_artwork_rating(artwork_key: String) -> int:
	var ratings = load_ratings()
	if ratings.has(artwork_key):
		return int(ratings[artwork_key])
	return 0

# Rate by frame name, for example: rate_frame("Frame_01", 5)
func rate_frame(frame_name: String, rating: int) -> void:
	if not frame_to_artwork.has(frame_name):
		print("No artwork assigned to frame: ", frame_name)
		return

	var artwork_key = str(frame_to_artwork[frame_name])

	# Optional: block rating online placeholders
	if artwork_key == "[ONLINE]":
		print("This frame currently shows online gallery art. Rating skipped.")
		return

	set_artwork_rating(artwork_key, rating)
	print("Frame ", frame_name, " now has rating: ", get_artwork_rating(artwork_key))

# Get rating by frame name
func get_frame_rating(frame_name: String) -> int:
	if not frame_to_artwork.has(frame_name):
		return 0

	var artwork_key = str(frame_to_artwork[frame_name])
	if artwork_key == "[ONLINE]":
		return 0

	return get_artwork_rating(artwork_key)

# Debug helper
func print_all_frame_ratings() -> void:
	print("=== Frame Ratings ===")
	for frame_name in frame_to_artwork.keys():
		var artwork_key = str(frame_to_artwork[frame_name])
		if artwork_key == "[ONLINE]":
			print(frame_name, " -> ONLINE ART")
		else:
			print(frame_name, " -> ", artwork_key, " | Rating: ", get_artwork_rating(artwork_key))
