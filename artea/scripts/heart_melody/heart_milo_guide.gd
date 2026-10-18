extends Node
## Recorded Milo guidance accompanies exploration without locking movement.
const LINES := preload("res://assets/audio/milo/heart_guidance/lines.json")
const STAGES := ["garden", "rhythm", "organ", "harp", "boat", "chimes", "warning", "loom", "anchors", "orchestra", "complete"]
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

func _ready() -> void:
	world = get_parent()
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
	panel.offset_left = -730
	panel.offset_right = -24
	panel.offset_top = -230
	panel.offset_bottom = -110
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	caption = Label.new()
	caption.custom_minimum_size.x = 650
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 23)
	panel.add_child(caption)
	panel.hide()

func station_approach() -> bool:
	if not world.embedded_in_overworld: return false
	var connection := world.get_parent()
	var point: Vector3 = connection.to_local(world.player.global_position)
	for segment in [[connection.WALK_START, connection.WALK_TURN], [connection.WALK_TURN, connection.WALK_FINISH]]:
		if point.distance_to(Geometry3D.get_closest_point_to_segment(point, segment[0], segment[1])) < 24: return true
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
	if not current_line.is_empty():
		_remaining -= delta
		if _remaining <= 0: _finish_line()
		return
	_gap = maxf(0, _gap - delta)
	if _gap > 0 or world.modal_open or milo.is_speaking(): return
	if world.embedded_in_overworld and not world.embedded_active:
		if not heard.has("station"): play_line("station")
		return
	var index: int = mini(world.progress.committed.chapter.tasks.size(), 10)
	var id: String = STAGES[index]
	if not heard.has(id): play_line(id)
	elif not heard.has("free_play") and world.player_local_position().x > -40: play_line("free_play")

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
	caption.text = "Milo: " + str(LINES.data.lines[id])
	panel.show()
	voice.stream = stream
	voice.play()
	_remaining = stream.get_length() + 0.3
	if is_instance_valid(milo): milo.begin_recorded_guidance(stream.get_length())
	print("MILO HEART GUIDANCE: ", id)
	return true

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
	var index: int = mini(world.progress.committed.chapter.tasks.size(), 10)
	play_line(STAGES[index])

func _exit_tree() -> void:
	if is_instance_valid(world) and is_instance_valid(world.player): world.player.set_meta("milo_heart_escort", false)
	if is_instance_valid(milo): milo.end_recorded_guidance()
