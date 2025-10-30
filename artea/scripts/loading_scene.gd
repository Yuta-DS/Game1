extends Control

@export var next_scene_path: String = ""
@onready var progress_bar = $progress_bar
@onready var progress_label = $progressLabel

var loading_started := false

func _ready():
	if next_scene_path != "":
		ResourceLoader.load_threaded_request(next_scene_path)
		loading_started = true
	else:
		push_error("⚠ No scene path provided to loading screen.")

func _process(_delta):
	if not loading_started:
		return

	var progress = []
	var status = ResourceLoader.load_threaded_get_status(next_scene_path, progress)

	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var percent = progress[0] * 100.0
		progress_bar.value = percent
		progress_label.text = str(percent as int) + "%"
	
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		var loaded_scene = ResourceLoader.load_threaded_get(next_scene_path)
		get_tree().change_scene_to_packed(loaded_scene)
		
		await get_tree().process_frame  
		MusicManager._check_scene()     
		loading_started = false  # prevent re-entry
