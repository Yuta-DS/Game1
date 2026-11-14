extends Node
## Recorded Milo guidance accompanies exploration without locking movement.
const LINES := preload("res://assets/audio/milo/heart_guidance/lines.json")
const STAGES := ["garden", "rhythm", "organ", "harp", "boat", "chimes", "warning", "loom", "anchors", "orchestra", "complete"]
const UI = preload("res://scripts/heart_melody/heart_ui.gd")
var world: Node3D
var milo: CharacterBody3D
var voice: AudioStreamPlayer
var caption: Label
var panel: PanelContainer
var heard := {}
var current_line := ""
var last_line := "garden"
var _was_escorting := false
var _remaining := 0.0
var _gap := 0.0
var enabled := true
var _observed_tasks := 0
var _pending: Array[String] = []
var _pages: Array[String] = []
var _page_ends: Array[float] = []
var _duration := 0.0

func _ready() -> void:
	world = get_parent()
	_observed_tasks = world.progress.committed.chapter.tasks.size()
	voice = AudioStreamPlayer.new()
	voice.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	voice.volume_db = -2
	add_child(voice)
	voice.finished.connect(_finish_line)
	var layer := CanvasLayer.new()
	layer.name = "MiloGardenGuidance"
	add_child(layer)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -464
	panel.offset_right = -24
	panel.offset_top = -350
	panel.offset_bottom = -90
	UI.decorate(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "MILO · YOUR GARDEN GUIDE"
	title.add_theme_color_override("font_color", UI.ACCENT)
	title.add_theme_font_size_override("font_size", 21)
	column.add_child(title)
	caption = Label.new()
	caption.custom_minimum_size.x = 396
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 23)
	column.add_child(caption)
	panel.hide()

func station_approach() -> bool:
	if not world.embedded_in_overworld: return false
	var connection := world.get_parent()
	var point: Vector3 = connection.to_local(world.player.global_position)
	var circle := connection.get_parent().get_parent().get_node_or_null("KingdomRegions3000m/HeartKingdomPlatform/HeartMusicCircle") as Node3D
	if circle != null:
		var court_point := circle.to_local(world.player.global_position)
		if absf(court_point.y) < 24.0 and Vector2(court_point.x, court_point.z).length() < 455.0:
			return true
	var walk: PackedVector3Array = connection.walk_points
	for i in walk.size() - 1:
		if point.distance_to(Geometry3D.get_closest_point_to_segment(point, walk[i], walk[i + 1])) < 24: return true
	return false

func tick(delta: float) -> void:
	var escorting: bool = enabled and (not world.embedded_in_overworld or world.embedded_active or station_approach())
	world.player.set_meta("milo_heart_escort", escorting)
	if not escorting:
		if _was_escorting: stop()
		_was_escorting = false
		return
	var manager := get_node("/root/MiloCompanionManager")
	milo = manager.get_active_milo()
	if milo == null:
		manager.refresh_companion()
		milo = manager.get_active_milo()
	if milo == null: return
	if not _was_escorting:
		# Bring the existing companion off the railway; never create a second Milo.
		milo.set_companion_player(world.player, milo.global_position.distance_to(world.player.global_position) > 16)
	_was_escorting = true
	var count: int = mini(world.progress.committed.chapter.tasks.size(), 10)
	if count > _observed_tasks:
		# Only committed achievements announce completion. Queue voice lines so
		# a quick sequence of actions cannot cut off an earlier explanation.
		for index in range(_observed_tasks, count): _pending.append("done_" + str(index))
	_observed_tasks = count
	if not current_line.is_empty():
		_remaining -= delta
		_update_caption()
		if _remaining <= 0: _finish_line()
		return
	_gap = maxf(0, _gap - delta)
	if _gap > 0 or world.modal_open or milo.is_speaking(): return
	if not _pending.is_empty():
		play_line(_pending.pop_front())
		return
	if world.embedded_in_overworld and not world.embedded_active:
		if not heard.has("station"): play_line("station")
		return
	var index: int = mini(world.progress.committed.chapter.tasks.size(), 10)
	var id: String = STAGES[index]
	if not heard.has(id) and _near_stage(index): play_line(id)
	elif heard.has(id) and _near_stage(index) and not heard.has("free_play") and world.player_local_position().x > -40: play_line("free_play")

func play_line(id: String) -> bool:
	if not LINES.data.lines.has(id): return false
	var path := "res://assets/audio/milo/heart_guidance/" + id + ".ogg"
	if not ResourceLoader.exists(path): return false
	var stream := load(path) as AudioStream
	if stream == null: return false
	if current_line != "": stop()
	current_line = id
	last_line = id
	heard[id] = true
	_duration = stream.get_length()
	_prepare_pages(str(LINES.data.lines[id]))
	# Milo is heard, not captioned on screen: the transcript card stays hidden.
	caption.text = _pages[0]
	voice.stream = stream
	voice.play()
	_remaining = stream.get_length()
	if is_instance_valid(milo): milo.begin_recorded_guidance(stream.get_length())
	print("MILO HEART GUIDANCE: ", id)
	return true

func _near_stage(index: int) -> bool:
	var x: float = world.player_local_position().x
	if index <= 1: return x < 104
	if index <= 4: return x >= 104 and x < 225
	if index <= 6: return x >= 225 and x < 345
	if index <= 8: return x >= 345
	return x >= 380

func _prepare_pages(text: String) -> void:
	_pages.clear()
	_page_ends.clear()
	var words := text.split(" ", false)
	var page := ""
	var consumed := 0
	for word in words:
		if page.length() + word.length() > 150 and not page.is_empty():
			_pages.append(page)
			_page_ends.append(float(consumed) / words.size())
			page = ""
		page += (" " if not page.is_empty() else "") + word
		consumed += 1
	if not page.is_empty():
		_pages.append(page)
		_page_ends.append(1.0)

func _update_caption() -> void:
	if _pages.is_empty(): return
	# Recorded audio owns visibility. Short transcript pages follow playback;
	# audio.finished removes the card immediately at the end of the voice.
	var fraction := clampf(voice.get_playback_position() / maxf(_duration, 0.01), 0, 1)
	for i in _pages.size():
		if fraction <= _page_ends[i]:
			caption.text = _pages[i]
			return

func _finish_line() -> void:
	voice.stop()
	current_line = ""
	_remaining = 0
	_gap = 2.0
	panel.hide()
	if is_instance_valid(milo): milo.end_recorded_guidance()

func stop() -> void:
	_finish_line()

func replay() -> void:
	world._close()
	if world.embedded_in_overworld and not world.embedded_active and station_approach():
		play_line("station")
		return
	var index: int = mini(world.progress.committed.chapter.tasks.size(), 10)
	play_line(STAGES[index])

func _exit_tree() -> void:
	if is_instance_valid(world) and is_instance_valid(world.player): world.player.set_meta("milo_heart_escort", false)
	if is_instance_valid(milo): milo.end_recorded_guidance()
