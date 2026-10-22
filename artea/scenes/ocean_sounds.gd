extends Node3D

var shoreline := PackedVector3Array()
var _sound: AudioStreamPlayer3D
var _target := Vector3.ZERO
var _refresh := 0.0

func _ready() -> void:
	_sound = get_node("Ocean Sound")
	get_node("Ocean Sound 2").queue_free()
	var stream := _sound.stream.duplicate() as AudioStreamOggVorbis
	stream.loop = true
	_sound.stream = stream
	_sound.bus = "SFX"
	_sound.unit_size = 20
	_sound.max_distance = 90
	_sound.volume_db = -8
	_sound.max_db = -6
	_target = _sound.global_position
	_build_shoreline()
	_update_shore_source()
	_sound.global_position = _target
	_sound.play()
	get_viewport().audio_listener_enable_3d = true

func _build_shoreline() -> void:
	# Reuse the same baked coast on desktop and Web; no per-frame terrain rays.
	var terrain := load("res://resources/web_hub_terrain.res") as ArrayMesh
	if terrain == null or terrain.get_surface_count() == 0:
		push_warning("Ocean ambience could not find the baked shoreline; keeping its coastal source.")
		return
	var vertices: PackedVector3Array = terrain.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var side := int(round(sqrt(float(vertices.size()))))
	if side < 3 or side * side != vertices.size():
		push_warning("Ocean ambience needs the regular Hub terrain grid; keeping its coastal source.")
		return
	var sea_y := get_parent_node_3d().global_position.y
	for z in range(1, side - 1):
		for x in range(1, side - 1):
			var index := z * side + x
			if vertices[index].y <= sea_y: continue
			for offset in [-1, 1, -side, side]:
				var next: Vector3 = vertices[index + offset]
				if next.y <= sea_y:
					shoreline.append(Vector3(next.x, sea_y, next.z))
					break
	_target = shoreline[0] if not shoreline.is_empty() else _sound.global_position

func _update_shore_source() -> void:
	var player := get_tree().get_first_node_in_group("Player") as Node3D
	if player == null: return
	var closest := INF
	for point in shoreline:
		var distance := player.global_position.distance_squared_to(point)
		if distance < closest:
			closest = distance
			_target = point

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh <= 0:
		_refresh = 0.25
		_update_shore_source()
	_sound.global_position = _sound.global_position.lerp(_target, 1.0 - exp(-delta * 6.0))
