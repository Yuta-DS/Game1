extends Control

@export var next_scene_path: String = ""
@onready var progress_bar = $progress_bar
@onready var progress_label = $progressLabel

var loading_started := false
var _shown_percent := 0.0

# Entering a scene has three phases with very different costs, and only
# reporting the first one left the bar parked while the other two ran. Each
# phase owns a slice of the bar and fills its slice from a real measurement:
# the resource loader's own fraction, the number of scatter nodes that have
# finished building, and the number of settled frames. Nothing here advances
# on a timer - a bar that creeps forward on its own looks informative while
# telling the player nothing, and would go right back to hiding a stall.
const LOAD_SLICE := 0.6
const SCATTER_SLICE := 0.3
const SETTLE_SLICE := 0.1

# How the screen decides the new scene is actually drawable (see
# _hold_until_first_frames_settle).
#
# The budget separates "still stalling" from "running normally", NOT "running
# well". The Art Castle's ordinary frames are already in the 30-45 ms range,
# while the first-draw stalls this is waiting out are 100 ms+, so the
# threshold sits above the former and well below the latter. Setting it near
# the normal frame time instead would mean the condition is essentially never
# met and the screen just burns the full timeout on every load.
const SETTLE_FRAME_BUDGET_MS := 80
const SETTLE_FRAMES_REQUIRED := 3
const SETTLE_TIMEOUT_MS := 5000

func _ready():
	if next_scene_path == "":
		push_error("⚠ No scene path provided to loading screen.")
		return
	_start_load_once_visible()


# The request deliberately does NOT start in _ready(). The Web export ships
# without WASM thread support (export_presets.cfg variant/thread_support), so
# load_threaded_request cannot actually hand the work to a background thread
# there and the first chunk of it lands on the main thread instead. Starting
# it in _ready() therefore blocked before this screen had ever been drawn, and
# the player sat looking at a frozen frame of the scene they were leaving with
# no indication anything was happening. Giving the screen two frames to
# actually reach the display first costs ~30 ms and makes the wait legible.
func _start_load_once_visible() -> void:
	# Label the frames this is about to wait for, so the first thing that
	# reaches the display already reads as a load in progress.
	_report(0.0, "Loading world")
	await get_tree().process_frame
	await get_tree().process_frame
	ResourceLoader.load_threaded_request(next_scene_path)
	loading_started = true

# The bar only ever moves forward. Phase three's measurement can legitimately
# reset (a stalled frame puts the settled-frame count back to zero), and a bar
# that jumps backwards reads as a bug rather than as honest reporting.
func _report(fraction: float, text: String) -> void:
	_shown_percent = maxf(_shown_percent, clampf(fraction, 0.0, 1.0) * 100.0)
	progress_bar.value = _shown_percent
	progress_label.text = "%d%%  %s" % [int(_shown_percent), text]


func _process(_delta):
	if not loading_started:
		return

	var progress = []
	var status = ResourceLoader.load_threaded_get_status(next_scene_path, progress)

	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_report(float(progress[0]) * LOAD_SLICE, "Loading world")

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
	_report(LOAD_SLICE, "Building the world")

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

	# How many of them have finished is a real, reportable number, so the bar
	# fills across this phase instead of parking at a single value. A scene
	# with no scatter nodes at all (the Art Castle) has nothing to report and
	# no reason to claim it is placing foliage, so it just takes the slice.
	if pending.is_empty():
		_report(LOAD_SLICE + SCATTER_SLICE, "Building the world")
	else:
		var deadline := Time.get_ticks_msec() + 15000
		while Time.get_ticks_msec() < deadline:
			var done := 0
			for scatter in pending:
				if not is_instance_valid(scatter) or scatter.build_version >= 1:
					done += 1
			_report(LOAD_SLICE + SCATTER_SLICE * (float(done) / float(pending.size())),
				"Placing foliage (%d/%d)" % [done, pending.size()])
			if done >= pending.size():
				break
			await get_tree().process_frame

	await _hold_until_first_frames_settle()
	queue_free()


# A scene being loaded and instantiated is not the same as it being ready to
# draw. The Art Castle only pays for most of its materials when they are first
# rendered - the Compatibility renderer (the only one Web can use) compiles a
# shader the first time it actually draws with it, synchronously - so the
# first frames after the swap are by far the most expensive ones. The scatter
# wait above does not cover this: it exits immediately for any scene with no
# ProtonScatter nodes, which includes the castle, so this screen used to free
# itself one frame too early and the player saw the freeze happen just after
# it disappeared. Staying up until frames are actually landing on time keeps
# that cost behind the loading screen where it belongs.
func _hold_until_first_frames_settle() -> void:
	var base := LOAD_SLICE + SCATTER_SLICE
	_report(base, "Preparing the view")
	var deadline := Time.get_ticks_msec() + SETTLE_TIMEOUT_MS
	var calm_frames := 0
	while calm_frames < SETTLE_FRAMES_REQUIRED and Time.get_ticks_msec() < deadline:
		var started := Time.get_ticks_msec()
		await get_tree().process_frame
		if Time.get_ticks_msec() - started <= SETTLE_FRAME_BUDGET_MS:
			calm_frames += 1
		else:
			calm_frames = 0
		_report(base + SETTLE_SLICE * (float(calm_frames) / float(SETTLE_FRAMES_REQUIRED)),
			"Preparing the view")
	_report(1.0, "Ready")
