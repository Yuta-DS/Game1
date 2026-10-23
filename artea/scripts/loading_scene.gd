extends Control

const ShaderWarmup := preload("res://scripts/shader_warmup.gd")
const SceneLoader := preload("res://scripts/scene_loader.gd")
const TouchDevice := preload("res://scripts/touch_controls.gd")
## Phones and tablets: how much bigger the loading words and Milo are drawn.
const TOUCH_TEXT_SCALE := 1.35
const TOUCH_MILO_SCALE := 1.9

@export var next_scene_path: String = ""
@onready var progress_bar = $progress_bar
@onready var progress_label = $progressLabel

var loading_started := false
var _shown_percent := 0.0
var _status_text := ""
# Resources loaded ahead of the scene (see _load_dependencies_in_slices).
# The cache only keeps a resource while something references it, so without
# this each one is freed as soon as it loads and the final request loads the
# lot again in one block.
var _held: Array[Resource] = []
var _audio_was_muted := false
# Off the web: the new scene's sound players, held on a muted bus until this
# screen goes, mapped to the bus each one belongs on.
var _held_audio := {}
const HOLD_BUS := &"LoadingHold"
# The gallery's track as a plain file (not imported), so its bytes can be
# handed to the web page, which plays it itself. Listed in the Web preset's
# include_filter.
const WEB_MUSIC_PATH := "res://assets/SFX/loading_music.ogg.raw"
var _spinner_ring: Control
var _spinner_milo: TextureRect

# Entering a scene has three phases with very different costs, and only
# reporting the first one left the bar parked while the other two ran. Each
# phase owns a slice of the bar and fills its slice from a real measurement:
# the resource loader's own fraction, the number of scatter nodes that have
# finished building, and the number of settled frames. Nothing here advances
# on a timer - a bar that creeps forward on its own looks informative while
# telling the player nothing, and would go right back to hiding a stall.
const LOAD_SLICE := 0.6
const SCATTER_SLICE := 0.22
const WARMUP_SLICE := 0.08
const SETTLE_SLICE := 0.1

# The shader warmup is real, measurable work (the castle's 32 distinct variants
# cost ~4.4 s of compilation between them), so it gets its own slice of the bar
# rather than being hidden inside the settle phase.
const WARMUP_TIMEOUT_MS := 20000

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

# How long _load_dependencies_in_slices may keep the main thread per frame.
# Short enough that the browser stays responsive and the dots keep moving;
# yielding after every single resource instead spent ~3.5 s of the hub's load
# just waiting on frames.
const DEPENDENCY_FRAME_BUDGET_MS := 50

# Fetching an area's Pack, when it has not been fetched yet, fills the first
# part of the load slice; loading the scene from it fills the rest.
const PACK_SLICE := LOAD_SLICE * 0.5
# Arriving here starts the background download of the other areas' Packs.
const HUB_SCENE := "res://scenes/New_Hub_World.tscn"

func _ready():
	# Milo and MusicManager hold off until this screen is gone.
	add_to_group("loading_screen")
	if TouchDevice.is_touch_device():
		# The percentage sits right on the bar, so it grows upwards, away from it.
		$Title.pivot_offset = $Title.size / 2.0
		progress_label.pivot_offset = Vector2(progress_label.size.x / 2.0, progress_label.size.y)
		for label: Label in [$Title, progress_label]:
			label.scale = Vector2.ONE * TOUCH_TEXT_SCALE
	# The new scene's own sounds (ocean ambience, gallery music) start the
	# moment it enters the tree, under this screen. Silence them until the
	# player can see the world they belong to. The loading music starts
	# straight away: waiting to see whether a load turns out long doesn't
	# work, because the wait is checked from _process, which can't run during
	# the very freezes the music is meant to cover.
	if OS.has_feature("web"):
		# The browser plays the music on the web, so the whole bus can go.
		_audio_was_muted = AudioServer.is_bus_mute(0)
		AudioServer.set_bus_mute(0, true)
		if not JavaScriptBridge.eval("arteaLoading.hasMusic()"):
			var bytes := FileAccess.get_file_as_bytes(WEB_MUSIC_PATH)
			if not bytes.is_empty():
				JavaScriptBridge.eval("arteaLoading.setMusic('%s')" % Marshalls.raw_to_base64(bytes))
		JavaScriptBridge.eval("arteaLoading.show(); arteaLoading.startMusic()")
		get_viewport().size_changed.connect(_place_web_overlay)
		_place_web_overlay.call_deferred()
	else:
		# The music plays through the game here, so hold the scene's own
		# players on a muted bus instead of muting everything.
		if AudioServer.get_bus_index(HOLD_BUS) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, HOLD_BUS)
			AudioServer.set_bus_mute(AudioServer.bus_count - 1, true)
		get_tree().node_added.connect(_hold_scene_audio)
		var music: AudioStreamPlayer2D = MusicManager.player2
		# A load started while the last one's music is still fading out
		# takes the music back instead of letting the fade stop it.
		var fade = music.get_meta("loading_fade", null)
		if fade is Tween and fade.is_valid():
			fade.kill()
			music.volume_db = music.get_meta("loading_fade_volume")
		if music.stream != MusicManager.MAGIC_TRACK or not music.playing:
			music.stream = MusicManager.MAGIC_TRACK
			music.play()
		_build_milo_spinner()
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
	if OS.has_feature("web") and not ResourceLoader.exists(next_scene_path):
		if not await _load_web_content_pack():
			return
	if not ResourceLoader.exists(next_scene_path):
		_fail("scene file missing")
		return
	ResourceLoader.load_threaded_request(next_scene_path)
	loading_started = true


# The browser starts with the hub in a small pack. Other scenes and their
# imported assets are downloaded together on the first trip out of the hub.
# Desktop exports retain the normal single-pack scene loading path.
func _load_web_content_pack() -> bool:
	var state := str(JavaScriptBridge.eval(
		"window.ARTEA_CONTENT_PACK ? window.ARTEA_CONTENT_PACK.state : 'missing'", true))
	if state == "missing":
		_fail("content downloader unavailable")
		return false
	if state == "mounted":
		return true
	if state != "ready":
		JavaScriptBridge.eval("window.ARTEA_CONTENT_PACK.load()", true)
		while true:
			state = str(JavaScriptBridge.eval("window.ARTEA_CONTENT_PACK.state", true))
			if state == "ready":
				break
			if state == "failed":
				_fail("content download failed")
				return false
			var fraction := float(JavaScriptBridge.eval(
				"window.ARTEA_CONTENT_PACK.progress", true))
			_report(fraction * 0.2, "Downloading game area")
			await get_tree().process_frame
	_report(0.2, "Opening game area")
	if not ProjectSettings.load_resource_pack("/content.pck", true):
		_fail("content pack could not be opened")
		return false
	JavaScriptBridge.eval("window.ARTEA_CONTENT_PACK.state = 'mounted'", true)
	return true

# The bar only ever moves forward. Phase three's measurement can legitimately
# reset (a stalled frame puts the settled-frame count back to zero), and a bar
# that jumps backwards reads as a bug rather than as honest reporting.
func _report(fraction: float, text: String) -> void:
	_shown_percent = maxf(_shown_percent, clampf(fraction, 0.0, 1.0) * 100.0)
	progress_bar.value = _shown_percent
	# Each phase once (not its running counts), timestamped by the browser
	# console, so a slow load can be split into download, load, build, shaders.
	if text.get_slice(" (", 0) != _status_text.get_slice(" (", 0):
		print("[ARTEA] loading phase: ", text.get_slice(" (", 0))
	_status_text = text
	_refresh_label()


# The bar only moves on real progress, so through a long phase it sits still
# and the screen looks frozen even while the game is running fine. The dots
# tick every frame instead: they keep moving whenever the game is alive and
# stop only if the main thread really is blocked.
func _refresh_label() -> void:
	var dots := ".".repeat(int(Time.get_ticks_msec() / 300) % 4)
	progress_label.text = "%d%%  %s%s" % [int(_shown_percent), _status_text, dots]


func _process(_delta):
	_refresh_label()
	# A script can set its player's bus after it enters the tree (Milo's voice
	# does), so take any change as the bus to return to and hold it again.
	for player in _held_audio:
		if is_instance_valid(player) and player.bus != HOLD_BUS:
			_held_audio[player] = player.bus
			player.bus = HOLD_BUS
	if _spinner_ring != null:
		# Matches the web version in web_export_shell.html: one turn every
		# 0.9 s, Milo bobbing and tilting every 1.6 s.
		_spinner_ring.rotation = fmod(Time.get_ticks_msec() / 900.0, 1.0) * TAU
		var bob := sin(Time.get_ticks_msec() / 1600.0 * TAU)
		_spinner_milo.position.y = 13.0 - bob * 2.0
		_spinner_milo.rotation = deg_to_rad(6.0) * bob
	if not loading_started:
		return

	var progress = []
	var status = ResourceLoader.load_threaded_get_status(next_scene_path, progress)

	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_report(float(progress[0]) * LOAD_SLICE, "Loading world")

	elif status == ResourceLoader.THREAD_LOAD_FAILED \
			or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		loading_started = false
		_fail("load failed")

	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		loading_started = false  # prevent re-entry
		var loaded_scene = ResourceLoader.load_threaded_get(next_scene_path)
		_held.clear()
		# Building the scene can't be split up and is the longest single pause
		# (~1.6 s for the hub on desktop). Say so before it starts, so the bar
		# isn't left at 59% looking stuck while it happens.
		_report(LOAD_SLICE, "Building the world")
		await get_tree().process_frame
		# A scene missing one of its dependencies arrives as null (web.txt
		# Problem 1), and change_scene_to_packed then does nothing.
		var err: Error = ERR_CANT_CREATE if loaded_scene == null \
			else get_tree().change_scene_to_packed(loaded_scene)
		if err != OK:
			_fail(error_string(err))
			return

		await get_tree().process_frame
		_wait_for_scatter_then_finish()

# The scene being left is already gone, so this screen is all the player has:
# say so on it rather than leaving the bar parked as if still loading.
func _fail(reason: String) -> void:
	_hide_web_overlay()
	SceneLoader.report_failure(get_tree(), next_scene_path, reason)
	progress_label.text = "Couldn't load this area. Reload the game to try again."


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

	await _warm_shaders()
	await _hold_until_first_frames_settle()
	print("[ARTEA] scene ready ", next_scene_path)
	queue_free()


func _exit_tree() -> void:
	if OS.has_feature("web"):
		AudioServer.set_bus_mute(0, _audio_was_muted)
		_hide_web_overlay()
	else:
		_release_scene_audio()


# Moving the player to a muted bus rather than pausing it: some (the train,
# the tree's bells) call play() again whenever they find themselves stopped,
# which a pause counts as.
func _hold_scene_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		_held_audio[node] = node.bus
		node.bus = HOLD_BUS


func _release_scene_audio() -> void:
	if get_tree().node_added.is_connected(_hold_scene_audio):
		get_tree().node_added.disconnect(_hold_scene_audio)
	for player in _held_audio:
		if is_instance_valid(player):
			player.bus = _held_audio[player]
	_held_audio.clear()


# Off the web the loading music is MusicManager's own player. The gallery
# keeps it playing; anywhere else it fades out before that scene's track (if
# any) takes over.
func _hand_over_music(arriving_track) -> void:
	if arriving_track == MusicManager.MAGIC_TRACK:
		MusicManager._check_scene()
		return
	var music: AudioStreamPlayer2D = MusicManager.player2
	var volume := music.volume_db
	var fade := MusicManager.create_tween()
	music.set_meta("loading_fade", fade)
	music.set_meta("loading_fade_volume", volume)
	fade.tween_property(music, "volume_db", -40.0, 0.6)
	fade.tween_callback(func():
		music.stop()
		music.volume_db = volume
		MusicManager._check_scene())


# Off the web, Godot draws the Milo spinner itself (on the web the page shell
# does, so it keeps moving through main-thread stalls). Same look: Milo in a
# ring, centred just under the bar.
func _build_milo_spinner() -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = Vector2(72, 72)
	holder.position = progress_bar.position + Vector2(progress_bar.size.x / 2.0 - 36.0, progress_bar.size.y + 12.0)
	add_child(holder)
	_spinner_ring = Control.new()
	_spinner_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spinner_ring.size = holder.size
	_spinner_ring.pivot_offset = holder.size / 2.0
	_spinner_ring.draw.connect(func():
		var ink := Color(0.109804, 0.121569, 0.0392157)
		_spinner_ring.draw_arc(Vector2(36, 36), 33.5, 0.0, TAU, 48, Color(ink, 0.25), 5.0, true)
		_spinner_ring.draw_arc(Vector2(36, 36), 33.5, -PI * 0.75, -PI * 0.25, 16, ink, 5.0, true))
	holder.add_child(_spinner_ring)
	_spinner_milo = TextureRect.new()
	_spinner_milo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spinner_milo.texture = preload("res://icon_milo.png")
	_spinner_milo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spinner_milo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_spinner_milo.size = Vector2(44, 44)
	_spinner_milo.position = Vector2(14, 14)
	_spinner_milo.pivot_offset = Vector2(22, 22)
	holder.add_child(_spinner_milo)
	if TouchDevice.is_touch_device():
		# Grow downwards from the bar so Milo never covers it.
		holder.pivot_offset = Vector2(holder.size.x / 2.0, 0.0)
		holder.scale = Vector2.ONE * TOUCH_MILO_SCALE


# Godot draws on the same thread that loads, so a step that can't be split
# (building the scene, compiling shaders) still freezes this screen for a
# moment. The page shell (web_export_shell.html) draws Milo in a spinning ring
# under the bar and plays the loading music. The browser animates and plays
# those itself, so they keep going through those moments and the game never
# looks hung.
func _place_web_overlay() -> void:
	var below_bar: Vector2 = progress_bar.get_screen_transform() * Vector2(progress_bar.size.x / 2.0, progress_bar.size.y)
	var milo_scale := TOUCH_MILO_SCALE if TouchDevice.is_touch_device() else 1.0
	JavaScriptBridge.eval("arteaLoading.place(%f, %f, %f)" % [below_bar.x, below_bar.y, milo_scale])


# Returns where the loading music had got to, in seconds (0 if it never
# started), so the gallery can carry on from there.
func _hide_web_overlay() -> float:
	if not OS.has_feature("web"):
		return 0.0
	var at = JavaScriptBridge.eval("arteaLoading.hide()")
	return float(at) if at != null else 0.0


# Compile the new scene's shaders while this screen is still covering them.
#
# The Compatibility renderer compiles a material's shader the first time it
# draws with it, synchronously, on the main thread. _hold_until_first_frames_
# settle() below waits for that to stop happening, but waiting only covers the
# materials that happen to face the camera in those first frames. Every other
# one still compiles later, during play, as a hitch the moment it first comes
# into view.
#
# That matters more since the world started being distance-culled
# (world_streaming_director.gd): distant cells are now guaranteed not to have
# been drawn during the settle frames, so without this every cell appearing as
# the player walks out of the castle would arrive with a fresh compile attached.
func _warm_shaders() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	# Benchmark escape hatch (tools/bench_castle_cold.gd), so the before/after
	# can be measured in the same build rather than by reverting the change.
	if Engine.has_meta("artea_skip_shader_warmup"):
		return
	_report(LOAD_SLICE + SCATTER_SLICE, "Compiling shaders")
	var materials := ShaderWarmup.collect(scene)
	if materials.is_empty():
		return
	var rig := ShaderWarmup.build_rig(materials)
	add_child(rig)
	var total := ShaderWarmup.warm_node_count(rig)
	# Revealed a couple of variants at a time rather than all at once. Each
	# reveal makes the next frame as long as those compiles take, so doing the
	# lot in one frame would lock the screen solid for the whole run with the
	# bar frozen - the exact thing this screen exists to avoid. The deadline is
	# a backstop only: a driver that compiles unusually slowly hands over to
	# gameplay rather than stranding the player here.
	var cursor := 0
	var deadline := Time.get_ticks_msec() + WARMUP_TIMEOUT_MS
	while cursor >= 0 and Time.get_ticks_msec() < deadline:
		cursor = ShaderWarmup.reveal_next(rig, cursor)
		if cursor < 0:
			break
		if total > 0:
			_report(LOAD_SLICE + SCATTER_SLICE
				+ WARMUP_SLICE * (float(cursor) / float(total)), "Compiling shaders")
		await get_tree().process_frame
	# One more frame so the final batch is actually drawn before the rig goes.
	await get_tree().process_frame
	rig.queue_free()


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
	var base := LOAD_SLICE + SCATTER_SLICE + WARMUP_SLICE
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
