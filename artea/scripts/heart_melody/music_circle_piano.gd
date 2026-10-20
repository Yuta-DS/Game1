extends "res://scripts/gallery_piano.gd"

signal note_played(midi: int)
signal playing_changed(active: bool)

const EASY_KEYS := [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K]
const EASY_NOTES := [60, 62, 64, 65, 67, 69, 71, 72]
const Art = preload("res://scripts/heart_melody/heart_art.gd")
const BENCH_TOP := Vector3(0, 0.38, 0.65)
var _sitting_player: CharacterBody3D
var _standing_transform := Transform3D.IDENTITY
var _standing_visual_yaw := 0.0
var _keyboard_view := false
var _bench_milo: Node3D
var _milo_seat: RemoteTransform3D

func _ready() -> void:
	super._ready()
	# The side seat view sees the full keyboard at an angle. Oversized picking
	# boxes from the close gallery view would intercept neighboring keys here.
	for midi in _keys:
		var pivot: Node3D = _keys[midi]
		for child in pivot.get_children():
			if child is StaticBody3D:
				var shape := child.get_child(0) as CollisionShape3D
				(shape.shape as BoxShape3D).size.y = (WHITE_KEY_THICKNESS if _key_white[midi] else BLACK_KEY_THICKNESS) + 0.002
	var bench := Node3D.new()
	bench.name = "PianoBench"
	add_child(bench)
	Art.box(bench, BENCH_TOP - Vector3.UP * 0.045, Vector3(1.1, 0.09, 0.40), Color("6c4563"), true)
	Art.box(bench, BENCH_TOP - Vector3.UP * 0.105, Vector3(1.13, 0.035, 0.43), Color("d6ad62"))
	for x in [-0.45, 0.45]:
		for z in [-0.13, 0.13]:
			Art.box(bench, Vector3(x, 0.135, BENCH_TOP.z + z), Vector3(0.065, 0.27, 0.065), Color("f4ead5"), true)
	_milo_seat = RemoteTransform3D.new()
	_milo_seat.name = "MiloListeningSeat"
	_milo_seat.position = BENCH_TOP + Vector3(-0.43, 0, 0)
	_milo_seat.rotation.y = PI
	_milo_seat.update_scale = false
	add_child(_milo_seat)

func _on_body_exited(body: Node) -> void:
	# A seated player temporarily disables their walking capsule. That is
	# intentional and must not be mistaken for walking out of piano range.
	if _seated and body == _sitting_player: return
	super._on_body_exited(body)

func _sit_down() -> void:
	super._sit_down()
	if _seated:
		for candidate in get_tree().get_nodes_in_group("Player"):
			if candidate is CharacterBody3D and candidate.has_method("set_seated"):
				_sitting_player = candidate
				break
		if is_instance_valid(_sitting_player):
			_standing_transform = _sitting_player.global_transform
			_standing_visual_yaw = _sitting_player.fox_visuals.rotation.y if _sitting_player.fox_visuals != null else 0.0
			_sitting_player.set_seated(true)
			_sitting_player.global_transform = Transform3D(global_basis.orthonormalized() * Basis(Vector3.UP, PI), to_global(BENCH_TOP))
			_sitting_player._update_character_animation(0.0, false)
		var manager := get_node_or_null("/root/MiloCompanionManager")
		if manager != null:
			var companion: Node3D = manager.get_active_milo()
			if companion != null and companion.has_method("sit_on") and not companion.is_seated():
				_bench_milo = companion
				_bench_milo.sit_on(_milo_seat)
		_keyboard_view = false
		_update_seat_view()
		playing_changed.emit(true)

func _update_seat_view() -> void:
	_set_player_shown(not _keyboard_view)
	if _keyboard_view:
		_camera.enter_inspect_framed(self, SEAT_FOCUS, SEAT_VIEW)
	else:
		_camera.enter_inspect_framed(self, Vector3(0, 0.65, 0), Vector3(1.15, 0.85, 1.25))
	_show_prompt("Seated at piano · Click keys or A S D F G H J K · Tab: seat / keyboard view · Esc: stand up")

func _stand_up() -> void:
	var was_seated := _seated
	if was_seated and is_instance_valid(_bench_milo):
		_bench_milo.stand_up()
		_bench_milo = null
	if was_seated and is_instance_valid(_sitting_player):
		_sitting_player.set_seated(false)
		_sitting_player.global_transform = _standing_transform
		if _sitting_player.fox_visuals != null: _sitting_player.fox_visuals.rotation.y = _standing_visual_yaw
		_sitting_player = null
	super._stand_up()
	if was_seated: playing_changed.emit(false)

func _play_note(midi: int) -> void:
	super._play_note(midi)
	note_played.emit(midi)

func _input(event: InputEvent) -> void:
	if _seated and event is InputEventKey:
		_unhandled_input(event)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _seated and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			_keyboard_view = not _keyboard_view
			_update_seat_view()
			get_viewport().set_input_as_handled()
			return
		var index := EASY_KEYS.find(event.physical_keycode)
		if index >= 0:
			_play_note(EASY_NOTES[index])
			_press_key(EASY_NOTES[index])
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)

func _strike_at(screen_position: Vector2, always: bool) -> void:
	# Seat view is farther from the keys than the gallery's close view.
	var camera := _camera as Camera3D
	if camera == null: return
	var origin := camera.project_ray_origin(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen_position) * 100, 1 << (KEY_LAYER - 1))
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		if not always: _last_dragged_midi = -1
		return
	var collider := hit.collider as Node
	if collider == null or not is_ancestor_of(collider) or not collider.has_meta("midi"): return
	var midi: int = collider.get_meta("midi")
	if not always and midi == _last_dragged_midi: return
	_last_dragged_midi = midi
	_play_note(midi)
	_press_key(midi)

func _exit_tree() -> void:
	if _seated:
		_stand_up()
