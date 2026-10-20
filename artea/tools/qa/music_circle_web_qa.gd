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
		print("MUSIC QA closed ", kind)
		return
	await get_tree().create_timer(0.8).timeout
	if _player.input_enabled:
		push_error("MUSIC QA FAILURE: movement was not paused while playing")
		return
	var instrument := _circle.get_node("Playable_" + kind)
	var point: Vector2
	if kind == "piano":
		var key_mesh := instrument._keys[60].get_child(0) as MeshInstance3D
		point = get_viewport().get_camera_3d().unproject_position(key_mesh.to_global(Vector3(0, 0.04, 0)))
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
