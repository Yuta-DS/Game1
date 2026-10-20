extends Control

const ShaderWarmup := preload("res://scripts/shader_warmup.gd")
const SceneLoader := preload("res://scripts/scene_loader.gd")

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
var _main_viewport: Viewport
var _restore_3d := false
var _previous_disable_3d := false
var _load_started_ms := 0
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
	_load_started_ms = Time.get_ticks_msec()
	# The opaque loader already covers this viewport. Drawing the full world
	# underneath competes with the tiny shader-warmup viewport on every frame.
	# Keep physics, scripts, cameras and authored visibility unchanged.
	if OS.has_feature("web"):
		_main_viewport = get_viewport()
		_previous_disable_3d = _main_viewport.disable_3d
		_main_viewport.disable_3d = true
		_restore_3d = true
	# Milo and MusicManager hold off until this screen is gone.
	add_to_group("loading_screen")
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
	# Shared packs first, then the area's own, which names the area.
	var packs := SceneLoader.packs_needed(next_scene_path)
	for index in packs.size():
		if not await _fetch_pack(packs[index], packs[-1].get_basename().capitalize(),
				float(index) / packs.size(), 1.0 / packs.size()):
			return
	if not OS.has_feature("threads"):
		await _load_dependencies_in_slices()
	_log_load_phase("resources")
	ResourceLoader.load_threaded_request(next_scene_path)
	loading_started = true


# An area's Pack is not part of the first download (ADR-0001), so the first
# time the player heads into the area it is fetched here, then mounted, and the
# load carries on as if it had always been there. The page does the download
# (arteaPacks in pck-loader.js: the Pack's parts in parallel, with retries and
# the Retry overlay) and writes the file into the engine's memory-backed /tmp;
# this only shows its progress. The parts are in the browser's cache for the
# next visit (ADR-0002), so nothing needs keeping in user:// as well.
## `start` and `share` place this file's download within the bar's Pack slice.
func _fetch_pack(file: String, area: String, start: float, share: float) -> bool:
	var local := "/tmp/artea_packs/" + file
	var key := JSON.stringify(file)
	JavaScriptBridge.eval("arteaPacks.fetch(%s, %s)" % [key, JSON.stringify(local)])
	while true:
		var state = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(arteaPacks.state[%s])" % key)))
		if not state is Dictionary or state.error != "":
			_fail("download failed: %s" % (state.error if state is Dictionary else "no loader"))
			return false
		if state.done:
			break
		if state.total > 0:
			_report(PACK_SLICE * (start + share * state.loaded / state.total),
				"Downloading the %s (%d / %d MB)" % [area, state.loaded / 1048576, state.total / 1048576])
		await get_tree().process_frame
	if not ProjectSettings.load_resource_pack(local):
		_fail("couldn't open the downloaded %s" % area)
		return false
	return true


# Without threads (the Web build) the request above does the whole load in a
# single main-thread block - ~5 s for the hub - long enough for Chrome to call
# the page unresponsive and with the screen frozen throughout. Loading the
# scene's dependencies first, a few per frame, hands control back to the
# browser in between, so the request is left to assemble resources already
# cached (~0.3 s for the hub).
func _load_dependencies_in_slices() -> void:
	var order: Array[String] = []
	_collect_dependencies(next_scene_path, {}, order)
	order.erase(next_scene_path)
	var frame_start := Time.get_ticks_msec()
	for i in order.size():
		if not ResourceLoader.has_cached(order[i]):
			_held.append(load(order[i]))
		if Time.get_ticks_msec() - frame_start >= DEPENDENCY_FRAME_BUDGET_MS:
			_report(LOAD_SLICE * float(i + 1) / float(order.size() + 1), "Loading world")
			await get_tree().process_frame
			frame_start = Time.get_ticks_msec()


# Depth first, so each resource is loaded after the ones it depends on.
func _collect_dependencies(path: String, seen: Dictionary, order: Array[String]) -> void:
	if seen.has(path):
		return
	seen[path] = true
	for dep in ResourceLoader.get_dependencies(path):
		var dep_path: String = dep.get_slice("::", 2) if dep.contains("::") else dep
		if ResourceLoader.exists(dep_path):
			_collect_dependencies(dep_path, seen, order)
	order.append(path)

# The bar only ever moves forward. Phase three's measurement can legitimately
# reset (a stalled frame puts the settled-frame count back to zero), and a bar
# that jumps backwards reads as a bug rather than as honest reporting.
func _report(fraction: float, text: String) -> void:
	_shown_percent = maxf(_shown_percent, clampf(fraction, 0.0, 1.0) * 100.0)
	progress_bar.value = _shown_percent
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
	_restore_world_rendering()
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

	_log_load_phase("construction")
	await _warm_shaders()
	_log_load_phase("warmup")
	_restore_world_rendering()
	await _hold_until_first_frames_settle()
	# Out of the group first: MusicManager skips while a loading screen is up.
	# Starting the track here rather than at the scene swap means it begins
	# from the top as the world appears, not part-way through.
	remove_from_group("loading_screen")
	# The loading music is the gallery's own track, so arriving there carries
	# on from the same spot instead of starting again.
	var scene := get_tree().current_scene
	var arriving_track = MusicManager.scene_to_track.get(scene.scene_file_path) if scene else null
	if OS.has_feature("web"):
		var music_at := _hide_web_overlay()
		MusicManager._check_scene(music_at if arriving_track == MusicManager.MAGIC_TRACK else 0.0)
		# The Hub is playable now, so the page starts downloading the other
		# areas' Packs in the background, most likely next first (issue #38).
		# Only downloading: mounting happens when the player goes there.
		if next_scene_path == HUB_SCENE:
			var files := SceneLoader.prefetch_order(get_tree())
			JavaScriptBridge.eval("arteaPacks.startPrefetch(%s)" % JSON.stringify(files))
	else:
		_release_scene_audio()
		_hand_over_music(arriving_track)
	# The browser console is the only log a web player has; tools/web-smoke.js
	# waits for this before checking the new scene is playable.
	print("[ARTEA] loading screen done: ", next_scene_path)
	print("ARTEA WORLD READY: ", next_scene_path)
	_log_load_phase("ready")
	queue_free()


func _exit_tree() -> void:
	_restore_world_rendering()
	if OS.has_feature("web"):
		AudioServer.set_bus_mute(0, _audio_was_muted)
		_hide_web_overlay()
	else:
		_release_scene_audio()


func _restore_world_rendering() -> void:
	if _restore_3d and is_instance_valid(_main_viewport):
		_main_viewport.disable_3d = _previous_disable_3d
	_restore_3d = false


func _log_load_phase(phase: String) -> void:
	print("LOAD TIMING ", next_scene_path, " ", phase, " ", Time.get_ticks_msec() - _load_started_ms, " ms")


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


# Godot draws on the same thread that loads, so a step that can't be split
# (building the scene, compiling shaders) still freezes this screen for a
# moment. The page shell (web_export_shell.html) draws Milo in a spinning ring
# under the bar and plays the loading music. The browser animates and plays
# those itself, so they keep going through those moments and the game never
# looks hung.
func _place_web_overlay() -> void:
	var below_bar: Vector2 = progress_bar.get_screen_transform() * Vector2(progress_bar.size.x / 2.0, progress_bar.size.y)
	JavaScriptBridge.eval("arteaLoading.place(%f, %f)" % [below_bar.x, below_bar.y])


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
	# Warm the real castle arrival view rather than a second quad scene with
	# different lighting. The opaque loader remains until actual frames settle.
	if OS.has_feature("web") and next_scene_path == "res://scenes/art_gallery_3d_inprogress.tscn":
		_restore_world_rendering()
		await get_tree().process_frame
		await get_tree().process_frame
		return
	# Benchmark escape hatch (tools/bench_castle_cold.gd), so the before/after
	# can be measured in the same build rather than by reverting the change.
	if Engine.has_meta("artea_skip_shader_warmup"):
		return
	_report(LOAD_SLICE + SCATTER_SLICE, "Compiling shaders")
	var materials := ShaderWarmup.unwarmed(ShaderWarmup.collect(scene))
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
	var completed: int = materials.size() if cursor < 0 else int(cursor / (2 if ShaderWarmup.WARM_INSTANCED else 1))
	ShaderWarmup.remember_warmed(materials, completed)
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
