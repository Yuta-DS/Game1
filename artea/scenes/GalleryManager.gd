# GalleryManager.gd
extends Node3D

# *************************************************************************
# STEP 1: Configuration and Variables
# *************************************************************************

# 1. WORKER LIST URL (API Call): Uses the complex URL that successfully listed 13 images.
const WORKER_LIST_URL = "https://artea-gallery-api.artea-gallery-api.workers.dev/list-art" 

# 2. R2 DOWNLOAD HOST (File Server Hostname Only): The base address for fetching files.
const R2_DOWNLOAD_HOST = "https://pub-dcfcf45c45f94920a79a5f0ef9ecb177.r2.dev" 

# Note: R2_BUCKET_NAME is commented out as it's not needed for the final, working URL path.
# const R2_BUCKET_NAME = "artea-art-gallery" 

# Define the number of frames to load
const MAX_FRAMES_TO_LOAD = 12

# Node references
@onready var list_request = $ListHTTPRequest
@onready var download_request = $DownloadHTTPRequest

# Data containers
var image_metadata: Array = [] 
var images_to_download: Array[String] = []

# Counter to index the 12 existing frames
var current_frame_index = 0

# --- Godot Core Functions ---

func _ready():
	# Connect Signals
	list_request.request_completed.connect(_on_list_request_completed)
	download_request.request_completed.connect(_on_download_request_completed)
	
	# Start the entire loading process
	list_bucket_contents()

# *************************************************************************
# STEP 3: Function to Start the Listing Request (CALLS WORKER API)
# *************************************************************************

func list_bucket_contents():
	# We call the secure Worker API which handles the R2 authentication.
	var error = list_request.request(WORKER_LIST_URL) 
	
	if error != OK:
		print("ERROR: Could not start Worker request. Godot Error Code:", error)

# *************************************************************************
# STEP 4: Function to Handle the List Response (JSON PARSING)
# *************************************************************************

func _on_list_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code != 200:
		print("ERROR: Worker list request failed with code:", response_code)
		print("Response body:", body.get_string_from_utf8()) 
		return

	# --- JSON PARSING LOGIC ---
	var json_result = JSON.parse_string(body.get_string_from_utf8())
	
	if json_result is Array:
		image_metadata = json_result
	else:
		print("ERROR: Worker returned invalid JSON format. Check Worker logs for error.")
		return
		
	# --- SORTING LOGIC: Newest First ---
	image_metadata.sort_custom(sort_by_last_modified)
	
	# Limit the list to the 12 available frames
	var newest_metadata = image_metadata.slice(0, mini(MAX_FRAMES_TO_LOAD, image_metadata.size()))

	images_to_download.clear()
	for item in newest_metadata:
		images_to_download.append(item.filename) 

	print("Finished listing. Total images found:", image_metadata.size(), ". Displaying the newest:", images_to_download.size())
	
	if not images_to_download.is_empty():
		start_next_download()

# Custom sort function for newest files
func sort_by_last_modified(a, b):
	return a.last_modified > b.last_modified

# *************************************************************************
# STEP 5: Functions to Handle Download and Display
# *************************************************************************

func start_next_download():
	if current_frame_index >= MAX_FRAMES_TO_LOAD or images_to_download.is_empty():
		print("All featured images have been downloaded and displayed.")
		return

	var filename = images_to_download.pop_front()
	
	# --- FINAL CORRECTED DOWNLOAD URL CONSTRUCTION ---
	# Uses R2_DOWNLOAD_HOST + Filename ONLY.
	var full_url = R2_DOWNLOAD_HOST.trim_suffix("/") + "/" + filename
	
	print("Attempting to download:", full_url)
	# Send the request
	var error = download_request.request(full_url) 
	
	if error != OK:
		print("ERROR: Could not start download request for", filename, ". Error code:", error)
		start_next_download() 

func _on_download_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code == 200:
		var image = Image.new()
		# Assumes images are JPG. Change to load_png_from_buffer if needed.
		var load_error = image.load_jpg_from_buffer(body) 
		
		# The extra node path here was misplaced and has been removed.
		# $"../10305PictureFrameV2Max2011It4" # <-- REMOVED MISPLACED CODE

		if load_error == OK:
			
			# --- Image Resizing Logic (FIXED SIZE) ---
			var target_size = Vector2i(512, 512) 
			
			# FORCE RESIZE to 512x512 pixels to ensure visual consistency on all frames.
			image.resize(target_size.x, target_size.y, Image.INTERPOLATE_BILINEAR)
			# --- END Image Resizing Logic ---
			
			var texture = ImageTexture.create_from_image(image)
			
			# --- Display Logic ---
			var frame_name = "Frame_%02d" % (current_frame_index + 1)
			var frame_node = get_node_or_null("../" + frame_name) 
			
			if frame_node and is_instance_of(frame_node, Sprite3D):
				frame_node.texture = null 
				frame_node.texture = texture
				print("Image applied to frame:", frame_name)
			else:
				print("WARNING: Could not find or access frame node:", frame_name)
				
			current_frame_index += 1
			
		else:
			print("ERROR: Failed to load image from buffer. Load error code:", load_error)
	else:
		print("ERROR: Image download failed with code:", response_code)

	start_next_download()
