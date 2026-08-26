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

	# is_thread_running() only reports true when ProtonScatter actually spawned
	# a Thread. On Web (no WASM thread support), scatter.gd takes its
	# dbg_disable_thread branch instead and builds synchronously via a
	# deferred call, so is_thread_running() never reports true there and a
	# wait gated on it was skipped entirely - the loading screen closed
	# before grass finished placing. build_version increments in
	# _on_transforms_ready() the same way on both the threaded and
	# synchronous paths, so it is a reliable "build in flight" check on
	# every platform.
	#
	# This polls build_version every frame instead of `await
	# scatter.build_completed`. A rebuild that crashes on Web (observed as an
	# "Uncaught RuntimeError: table index is out of bounds" WASM trap, most
	# likely from the Objects scatter's keep_static_colliders registering a
	# collision shape with PhysicsServer3D per tree instance) can silently
	# orphan a coroutine suspended on that signal - it never resumes and the
	# loading screen is stuck on screen forever, worse than the pop-in this
	# was written to hide. Polling only depends on get_tree().process_frame,
	# which keeps firing every frame regardless of what else breaks, and the
	# deadline below guarantees a hand-off no matter what.
	# Every scatter node here is a fresh instance from this scene load, so
	# build_version starts at 0 and "has completed its first build" is simply
	# build_version >= 1 - not "has advanced past whatever value it happened
	# to be at when this loop started". A start_version snapshot looked
	# right but breaks for any scatter that already finished (e.g. Objects,
	# lighter than Grass, often done before this loop even starts polling):
	# it can never build a second time on its own, so waiting for a further
	# increment burned the full deadline for no reason.
	var pending: Array = []
	var hub := get_tree().current_scene
	if hub:
		for scatter in hub.find_children("*", "Node3D", true, false):
			if scatter.has_signal("build_completed") and "build_version" in scatter:
				pending.append(scatter)

	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		var all_done := true
		for scatter in pending:
			if is_instance_valid(scatter) and scatter.build_version < 1:
				all_done = false
				break
		if all_done:
			break
		await get_tree().process_frame

	waiting_for_scatter = false
	queue_free()
