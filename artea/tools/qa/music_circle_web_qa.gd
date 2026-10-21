extends Node3D

## Opt-in test scene, opened by web-smoke --music-circle after the castle pack
## is mounted. Exercises the real gallery/player, instruments and camera.
const KINDS := ["xylophone", "drums", "bells", "guitar", "piano"]
var _gallery: Node3D
var _circle: Node3D
var _player: CharacterBody3D
var _index := 0
var _next_down := false
var _posing := false
var _maze_down := false
var _maze_running := false
var _checking_escape := false
var _last_keyboard_view := false

func _ready() -> void:
	_gallery = (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	add_child(_gallery)
	for frame in 8: await get_tree().process_frame
	_circle = _gallery.get_node("ArtCastleFloatingWorld/KingdomRegions3000m/HeartKingdomPlatform/HeartMusicCircle")
	_player = _gallery.get_node("Player3D")
	_player.set_physics_process(false)
	for kind in KINDS:
		var instrument := _circle.get_node("Playable_" + kind)
		instrument.note_played.connect(_on_note.bind(kind))
		instrument.playing_changed.connect(_on_playing.bind(kind))
	_pose()

func _process(_delta: float) -> void:
	var maze_key := Input.is_physical_key_pressed(KEY_F9)
	if maze_key and not _maze_down and not _maze_running and is_instance_valid(_circle):
		_maze_running = true
		_maze_tour()
	_maze_down = maze_key
	if _checking_escape:
		var maze := _circle.get_parent().get_node("HeartMusicMaze")
		if _player.global_position.distance_to(maze.to_global(maze.entrance_position() + Vector3.UP * 0.5)) < 0.1:
			_checking_escape = false
			get_viewport().get_camera_3d().exit_inspect()
			print("MAZE QA return works")
	if is_instance_valid(_circle):
		var piano := _circle.get_node("Playable_piano")
		if piano._seated and piano._keyboard_view != _last_keyboard_view:
			_last_keyboard_view = piano._keyboard_view
			print("BENCH QA keyboard view" if _last_keyboard_view else "BENCH QA seat view")
	var down := Input.is_physical_key_pressed(KEY_F8)
	if down and not _next_down and not _posing and is_instance_valid(_circle):
		_index = (_index + 1) % KINDS.size()
		_pose()
	_next_down = down

func _pose() -> void:
	_posing = true
	var instrument := _circle.get_node("Playable_" + KINDS[_index])
	_player.global_position = instrument.to_global(Vector3(0, 0.3, 0.5) if KINDS[_index] == "piano" else Vector3(0, 2, 5))
	for frame in 5:
		await get_tree().physics_frame
		await get_tree().process_frame
	_posing = false
	print("MUSIC QA near ", KINDS[_index])

func _on_playing(active: bool, kind: String) -> void:
	if not active:
		if not _player.input_enabled:
			push_error("MUSIC QA FAILURE: player controls were not restored")
			return
		if kind == "piano" and (_player.is_seated() or _player._sit_pose_applied):
			push_error("MUSIC QA FAILURE: bench did not restore the standing pose")
			return
		print("MUSIC QA closed ", kind)
		return
	await get_tree().create_timer(0.8).timeout
	if _player.input_enabled:
		push_error("MUSIC QA FAILURE: movement was not paused while playing")
		return
	var instrument := _circle.get_node("Playable_" + kind)
	var point: Vector2
	if kind == "piano":
		if not _player.is_seated() or not _player._sit_pose_applied:
			push_error("MUSIC QA FAILURE: real fox is not seated on the bench")
			return
		if is_instance_valid(instrument._bench_milo) and (not instrument._bench_milo.is_seated() or instrument._bench_milo.global_position.distance_to(_player.global_position) < 1.7):
			push_error("MUSIC QA FAILURE: companion overlaps the player's bench seat")
			return
		var key_mesh := instrument._keys[60].get_child(0) as MeshInstance3D
		point = get_viewport().get_camera_3d().unproject_position(key_mesh.to_global(Vector3(0, 0.012, 0.055)))
	else:
		point = instrument._buttons[0].get_global_rect().get_center()
	# The game stretches its authored canvas to the browser viewport. CDP
	# mouse input uses displayed pixels, not the larger canvas coordinates.
	point = get_viewport().get_final_transform() * point
	print("MUSIC QA pad ", kind, " ", point.x, " ", point.y)
	print("MUSIC QA open ", kind)

func _on_note(index: int, kind: String) -> void:
	var instrument := _circle.get_node("Playable_" + kind)
	var count: int = instrument._voices.size()
	var voice = instrument._voices[(instrument._voice_index + count - 1) % count]
	if voice.stream == null or not voice.playing:
		push_error("MUSIC QA FAILURE: no audible voice on " + kind)
		return
	if kind != "piano" and not voice.stream.resource_path.begins_with("res://assets/audio/music_circle/"):
		push_error("MUSIC QA FAILURE: prepared sound was not exported for " + kind)
		return
	print("MUSIC QA note ", kind, " ", index)

func _maze_tour() -> void:
	var maze := _circle.get_parent().get_node("HeartMusicMaze")
	var route: Array = maze.route_to(maze.FOUNTAIN_CELL)
	if route.size() < 40:
		push_error("MUSIC QA FAILURE: maze has no solution")
		return
	_player.global_position = maze.to_global(maze.cell_position(route[0]) + Vector3.UP)
	for index in range(1, route.size() - 1):
		var target: Vector3 = maze.to_global(maze.cell_position(route[index]) + Vector3.UP)
		if _player.test_move(_player.global_transform, target - _player.global_position):
			push_error("MUSIC QA FAILURE: maze corridor is blocked")
			return
		_player.global_position = target
		await get_tree().physics_frame
		await get_tree().process_frame
	if not maze.completed:
		push_error("MUSIC QA FAILURE: fountain could not be reached")
		return
	var wall: Dictionary = maze.walls[0]
	var normal := Vector3.RIGHT if wall.size.x < wall.size.z else Vector3.BACK
	_player.global_position = maze.to_global(wall.position - normal * 6)
	if not _player.test_move(_player.global_transform, normal * 12):
		push_error("MUSIC QA FAILURE: player can walk through a hedge")
		return
	_player.global_position = maze.to_global(Vector3(96, 1, -410))
	if not _player.test_move(_player.global_transform, Vector3(0, 0, 298)):
		push_error("MUSIC QA FAILURE: the old straight maze bypass is still open")
		return
	var music_route: Array = maze.route_to(maze.MUSIC_EXIT)
	if music_route.size() < 40:
		push_error("MUSIC QA FAILURE: instrument route is too direct")
		return
	_player.global_position = maze.to_global(maze.cell_position(music_route[0]) + Vector3.UP)
	for index in range(1, music_route.size()):
		var target: Vector3 = maze.to_global(maze.cell_position(music_route[index]) + Vector3.UP)
		if _player.test_move(_player.global_transform, target - _player.global_position):
			push_error("MUSIC QA FAILURE: instrument maze route is blocked")
			return
		_player.global_position = target
		await get_tree().physics_frame
	var circle_entry: Vector3 = maze.to_global(maze.cell_position(maze.MUSIC_EXIT) + Vector3(0, 1, maze.CELL * 1.5))
	if _player.test_move(_player.global_transform, circle_entry - _player.global_position):
		push_error("MUSIC QA FAILURE: maze exit does not reach the instruments")
		return
	_player.global_position = maze.to_global(maze.fountain_position() + Vector3(32, 1, 0))
	print("MAZE QA path playable")
	var fountain := _circle.get_parent().get_node("HeartArrivalGarden/MusicalFountain")
	var music := fountain.get_node("FountainMusic") as AudioStreamPlayer3D
	if music.stream == null or not music.playing or music.stream.get_length() < 15:
		push_error("MUSIC QA FAILURE: fountain music is missing")
		return
	print("MAZE QA music active")
	var connection := _gallery.get_node("ArtCastleFloatingWorld/StoryCrownRailway/HeartMelodyConnection")
	var guide = connection.island.milo_guide
	if not guide.station_approach() or not guide.play_line("station") or not guide.voice.playing or not _player.input_enabled:
		push_error("MUSIC QA FAILURE: arrival narration stopped in the maze court")
		return
	print("MAZE QA guide station")
	get_viewport().get_camera_3d().near = 2.0
	get_viewport().get_camera_3d().enter_inspect_framed(maze, Vector3.ZERO, Vector3(0, 570, -530))
	await get_tree().create_timer(1.2).timeout
	print("MAZE QA overview ready")
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_camera_3d().near = 0.1
	get_viewport().get_camera_3d().enter_inspect_framed(fountain, Vector3.UP * 6, Vector3(62, 48, -70))
	await get_tree().create_timer(1.2).timeout
	print("MAZE QA fountain ready")
	_checking_escape = true
