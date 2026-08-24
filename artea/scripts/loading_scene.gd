extends Control

@export var next_scene_path: String = ""
@onready var progress_bar = $progress_bar
@onready var progress_label = $progressLabel

var loading_started := false
var waiting_for_scatter := false
var _dot_timer := 0.0

func _ready():
	if next_scene_path != "":
		ResourceLoader.load_threaded_request(next_scene_path)
		loading_started = true
	else:
		push_error("⚠ No scene path provided to loading screen.")

func _process(delta):
	if waiting_for_scatter:
		# ProtonScatter has no percent-complete to report, only a completion
		# signal (see _wait_for_scatter_then_finish), so there is no real
		# number to show here. A static "100%" for several seconds reads as
		# frozen/broken, so cycle the label instead - the point is to prove
		# the game is still alive, not to claim false precision.
		_dot_timer += delta
		var dots := (int(_dot_timer / 0.4) % 3) + 1
		progress_label.text = "Placing foliage" + ".".repeat(dots)
		return

	if not loading_started:
		return

	var progress = []
	var status = ResourceLoader.load_threaded_get_status(next_scene_path, progress)

	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var percent = progress[0] * 100.0
		progress_bar.value = percent
		progress_label.text = str(percent as int) + "%"

	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		loading_started = false  # prevent re-entry
		var loaded_scene = ResourceLoader.load_threaded_get(next_scene_path)
		get_tree().change_scene_to_packed(loaded_scene)

		await get_tree().process_frame
		MusicManager._check_scene()
		_wait_for_scatter_then_finish()

# The .tscn resource finishing "load" above only means it has been parsed
# and instantiated. ProtonScatter's Grass/Objects nodes then spend several
# more seconds placing tens of thousands of instances on their own
# background thread (addons/proton_scatter/src/scatter.gd) - real work that
# doesn't block the main thread, but was previously invisible to this
# screen, so the loading screen vanished early and the player watched grass
# pop into a bare hub. Hold the screen until every scatter node still
# building finishes, then hand off.
func _wait_for_scatter_then_finish() -> void:
	progress_bar.value = 100
	progress_label.text = "Placing foliage..."
	waiting_for_scatter = true

	# full_rebuild() is deferred from each Scatter node's own _ready(), so
	# give that a couple of idle frames to actually start before checking -
	# checking immediately after the scene swap can race ahead of it.
	await get_tree().process_frame
	await get_tree().process_frame

	var hub := get_tree().current_scene
	if hub:
		for scatter in hub.find_children("*", "Node3D", true, false):
			if scatter.has_signal("build_completed") and scatter.has_method("is_thread_running") \
					and scatter.is_thread_running():
				await scatter.build_completed

	waiting_for_scatter = false
	queue_free()
