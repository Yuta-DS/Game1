extends Control

# A player-centred virtual map camera for Artéa's two connected contexts.
#
# The compact minimap behaves like a conventional orthographic follow camera:
# the player stays at the centre, world features move beneath the marker, and
# far landmarks clamp to the rim. The full atlas uses absolute world bounds.
# Vector projection is used instead of a second 3D SubViewport because the
# Castle Galaxy is runtime-generated and several kilometres wide.

const CONTEXT_HUB := "hub"
const CONTEXT_GALAXY := "galaxy"
const COMPACT_SIZE := Vector2(286.0, 286.0)
const COMPACT_CENTER := Vector2(143.0, 126.0)
const COMPACT_RADIUS := 104.0
const COMPACT_MAP_RECT := Rect2(39.0, 22.0, 208.0, 208.0)
const HUB_METERS_PER_PIXEL := 1.7
const GALAXY_METERS_PER_PIXEL := 9.5
const GALAXY_PADDING := 420.0
const HUB_BOUNDS := Rect2(-230.0, -230.0, 460.0, 460.0)
const CASTLE_POSITION := Vector3(-51.4, 0.0, 27.41)
const FACING_SPEED_THRESHOLD := 0.08
const TELEPORT_DISTANCE := 100.0

# The compact map used to queue a redraw on every single frame. Each redraw
# samples ~530 landscape tiles, and _draw() is not cheap enough to be run 60
# times a second for a 208 px circle - profiled inside the castle it was 12 ms
# of a 15 ms frame, by far the largest single cost in the scene, and GDScript
# costs several times that again under WASM in the Web export.
#
# Nothing on this map changes fast enough to need 60 Hz. It is refreshed on a
# fixed cadence, and immediately when the player has actually moved far enough
# to shift the view by a tile, so following the player still feels continuous
# while a standing player costs almost nothing.
const MAP_REFRESH_INTERVAL := 1.0 / 12.0
const MAP_REFRESH_MOVE_METRES := 6.0

# Static sampler data, hoisted out of _landscape_color so it is not rebuilt for
# every one of the ~530 tiles the compact map draws.
const MIND_ZONE_COLORS: Array[Color] = [
	Color("35506a"), Color("315f70"), Color("3e4d75"),
	Color("536d59"), Color("4c386a"), Color("3e6b5d"),
]
const KINGDOM_IDS: Array[String] = ["mind", "heart", "creator"]
const KINGDOM_COLORS: Array[Color] = [
	Color("28394d"), Color("5b4356"), Color("675c3e"),
]
const GALAXY_ISLAND_SPECS := [
	[Vector2(0, 820), 160.0, Color("596d72")],
	[Vector2(0, 1640), 225.0, Color("537d66")],
	[Vector2(-600, 1640), 180.0, Color("315f70")],
	[Vector2(600, 1640), 180.0, Color("806f49")],
]
const GALAXY_BRIDGE_SEGMENTS := [
	[Vector2(0, 500), Vector2(0, 1422), 34.0],
	[Vector2(-218, 1640), Vector2(-430, 1640), 34.0],
	[Vector2(218, 1640), Vector2(410, 1640), 34.0],
]

# The hub is one round island: sea all round, a mountain ridge along its -Z
# rim and down both sides, a beach on the +Z side, and the brick village plaza
# east of the castle. Measured from a top-down render of New_Hub_World.
const HUB_ISLAND_CENTER := Vector2(15.0, -45.0)
const HUB_ISLAND_RADIUS := 200.0
const HUB_VILLAGE_PLAZA := Rect2(55.0, -120.0, 65.0, 155.0)
const HUB_LANDMARKS := [
	[Vector3(107, 0, -6), "VILLAGE SQUARE", Color("9bd487")],
	[Vector3(170, 0, 60), "PORT", Color("6fcfe8")],
]
# Minigame doors are read from their triggers, like hub_minigame_signs.gd, so
# the map follows the buildings if they move.
const HUB_DOORS := [
	["Popthought_world", "POP THOUGHTS"],
	["Drawing_Tool2", "MUSIC"], # Despite its name, this trigger opens the music minigame.
	["Drawing_Tool", "DRAWING"],
]
const DOOR_COLOR := Color("ffb86b")

@export_enum("hub", "galaxy") var map_context := CONTEXT_GALAXY

var _player: Node3D
var _world: Node3D
var _regions: Node3D
var _railway: Node3D
var _track: Array = [] # See _track_points().
var _bounds := HUB_BOUNDS
var _full_map_open := false
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _facing_world := Vector2(0.0, 1.0) # World X/Z. +Z is north on this atlas.
var _last_player_position := Vector3.ZERO
var _has_last_player_position := false

# Per-redraw sampler cache, filled by _refresh_landscape_sampling().
var _sample_world_to_local := Transform3D.IDENTITY
var _sample_blueprint_active := false
var _sample_zone_centres: Array[Vector2] = []
var _sample_zone_radii: Array[float] = []
var _sample_spur_active := false
var _sample_spur_start := Vector2.ZERO
var _sample_station_centre := Vector2.ZERO
var _sample_kingdom_centres: Array[Vector2] = []
var _sample_kingdom_halves: Array[float] = []
var _sample_kingdom_colors: Array[Color] = []

# Redraw cadence state (see MAP_REFRESH_INTERVAL).
var _redraw_cooldown := 0.0
var _last_drawn_position := Vector3.ZERO
var _last_drawn_facing := Vector2(0.0, 1.0)


func _ready() -> void:
	name = "ArteaWorldMinimap"
	set_process_unhandled_input(true)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	# The full map only redraws when the view changes, so a window resize must ask.
	resized.connect(queue_redraw)
	_apply_layout()
	call_deferred("_refresh_world_references")


func configure(context: String, player: Node3D = null) -> void:
	map_context = context if context == CONTEXT_HUB else CONTEXT_GALAXY
	_player = player
	_has_last_player_position = false
	_refresh_world_references()
	_apply_layout()
	queue_redraw()


func _refresh_world_references() -> void:
	if not is_inside_tree():
		return
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
	var scene := get_tree().current_scene
	_world = scene.get_node_or_null("ArtCastleFloatingWorld") as Node3D if scene != null else null
	if _world == null and scene != null and scene.name == "ArtCastleFloatingWorld":
		_world = scene as Node3D
	if _world == null and get_parent() != null and get_parent().get_parent() != null:
		var owner := get_parent().get_parent()
		if owner.name == "ArtCastleFloatingWorld":
			_world = owner as Node3D
		else:
			_world = owner.get_node_or_null("ArtCastleFloatingWorld") as Node3D
	_regions = _world.get_node_or_null("KingdomRegions3000m") as Node3D if _world != null else null
	_railway = _world.get_node_or_null("StoryCrownRailway") as Node3D if _world != null else null
	_track.clear()
	_recalculate_bounds()
	queue_redraw()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		_has_last_player_position = false
	_update_player_facing(delta)
	_redraw_cooldown -= delta
	if (_redraw_cooldown > 0.0 or _full_map_open) and not _view_moved():
		return
	_redraw_cooldown = MAP_REFRESH_INTERVAL
	if _player != null and is_instance_valid(_player):
		_last_drawn_position = _player.global_position
	_last_drawn_facing = _facing_world
	queue_redraw()


## True when the player has moved or turned enough that the drawn map is out of
## date, so movement is never visibly behind the cadence above.
func _view_moved() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if _player.global_position.distance_to(_last_drawn_position) >= MAP_REFRESH_MOVE_METRES:
		return true
	return _facing_world.dot(_last_drawn_facing) < 0.999


# The authoritative facing is actual horizontal travel, not CharacterBody3D's
# basis. Both Artéa controllers rotate a child visual while the body root may
# keep an authored 180-degree scene rotation. Movement also remains correct on
# trains because position delta is used when CharacterBody velocity is zero.
func _update_player_facing(delta: float) -> void:
	if _player == null:
		return
	# Cursor motion rotates the active gameplay camera in both player rigs. Use
	# the camera's true look vector first so cursor-left is always map-left.
	var motion := _camera_heading_world()
	var camera_is_authoritative := motion.length() >= FACING_SPEED_THRESHOLD
	if _player is CharacterBody3D:
		var body := _player as CharacterBody3D
		if not camera_is_authoritative:
			motion = Vector2(body.velocity.x, body.velocity.z)
	if not camera_is_authoritative and motion.length() < FACING_SPEED_THRESHOLD \
			and _has_last_player_position and delta > 0.0:
		var displacement := _player.global_position - _last_player_position
		var horizontal_distance := Vector2(displacement.x, displacement.z).length()
		if horizontal_distance < TELEPORT_DISTANCE:
			motion = Vector2(displacement.x, displacement.z) / delta
	_last_player_position = _player.global_position
	_has_last_player_position = true
	if motion.length() < FACING_SPEED_THRESHOLD:
		return
	var target := motion.normalized()
	var blend := 1.0 - exp(-18.0 * maxf(delta, 0.0))
	var angle := lerp_angle(_facing_world.angle(), target.angle(), blend)
	_facing_world = Vector2(cos(angle), sin(angle))


func _camera_heading_world() -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector2.ZERO
	var forward := -camera.global_transform.basis.z
	var flat := Vector2(forward.x, forward.z)
	return flat.normalized() if flat.length() >= FACING_SPEED_THRESHOLD else Vector2.ZERO


func get_player_facing_screen() -> Vector2:
	# Screen Y increases downward, so world +Z must become screen -Y.
	return Vector2(_facing_world.x, -_facing_world.y).normalized()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		set_full_map_open(not _full_map_open)
		get_viewport().set_input_as_handled()
	elif _full_map_open and event.is_action_pressed("ui_cancel"):
		set_full_map_open(false)
		get_viewport().set_input_as_handled()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		set_full_map_open(not _full_map_open)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		set_full_map_open(not _full_map_open)
		accept_event()


func set_full_map_open(open: bool) -> void:
	if _full_map_open == open:
		return
	_full_map_open = open
	if open:
		_previous_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = _previous_mouse_mode
	_apply_layout()
	queue_redraw()


func is_full_map_open() -> bool:
	return _full_map_open


func get_map_context() -> String:
	return map_context


func _apply_layout() -> void:
	if _full_map_open:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		position = Vector2.ZERO
		z_index = 900
	else:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		position = Vector2(18.0, 18.0)
		size = COMPACT_SIZE
		z_index = 100


func _draw() -> void:
	if _full_map_open:
		_draw_full_map()
	else:
		_draw_compact_map()


func _draw_compact_map() -> void:
	# Circular mask, quiet frame, and a single gold/cyan context accent.
	draw_circle(COMPACT_CENTER + Vector2(3, 5), COMPACT_RADIUS + 9.0, Color(0, 0, 0, 0.42))
	draw_circle(COMPACT_CENTER, COMPACT_RADIUS + 7.0, Color("151725"))
	draw_circle(COMPACT_CENTER, COMPACT_RADIUS + 4.0, Color(_accent(), 0.58))
	draw_circle(COMPACT_CENTER, COMPACT_RADIUS, _map_background())
	_draw_compact_landscape()
	for ring in [0.34, 0.67]:
		draw_arc(COMPACT_CENTER, COMPACT_RADIUS * ring, 0, TAU, 64,
			Color(_accent(), 0.10), 1.0, true)
	_draw_local_grid()
	if map_context == CONTEXT_HUB:
		_draw_hub_compact()
	else:
		_draw_galaxy_compact()
	_draw_player(COMPACT_CENTER, true)
	_draw_compact_compass()
	var title := "OUTSIDE • ARTÉA KINGDOM" if map_context == CONTEXT_HUB else "INSIDE • CASTLE GALAXY"
	draw_string(ThemeDB.fallback_font, Vector2(18, 254), title,
		HORIZONTAL_ALIGNMENT_CENTER, COMPACT_SIZE.x - 36, 14, _accent())
	draw_string(ThemeDB.fallback_font, Vector2(18, 278), "CLICK OR PRESS M  •  FULL MAP",
		HORIZONTAL_ALIGNMENT_CENTER, COMPACT_SIZE.x - 36, 11, Color("e9eef7"))


func _draw_local_grid() -> void:
	# Crosshair lines communicate that the map follows the player without adding
	# a dense tile grid over the small circular view.
	var line_color := Color(_accent(), 0.09)
	draw_line(COMPACT_CENTER + Vector2(-COMPACT_RADIUS + 5, 0),
		COMPACT_CENTER + Vector2(COMPACT_RADIUS - 5, 0), line_color, 1.0)
	draw_line(COMPACT_CENTER + Vector2(0, -COMPACT_RADIUS + 5),
		COMPACT_CENTER + Vector2(0, COMPACT_RADIUS - 5), line_color, 1.0)


func _draw_compact_landscape() -> void:
	if _player == null:
		return
	# A sampled top-down terrain layer. Every sample is projected from the real
	# player position, so it scrolls like a minimap camera while remaining cheap
	# enough for the generated multi-kilometre galaxy.
	#
	# Everything the sampler needs that is the same for all ~530 tiles is
	# resolved once, here. It used to be resolved per tile: two node-path
	# lookups, a cross-script call returning a Dictionary, and a dozen array and
	# Color allocations, 530 times a frame.
	_refresh_landscape_sampling()
	const TILE := 8.0
	var scale := HUB_METERS_PER_PIXEL if map_context == CONTEXT_HUB else GALAXY_METERS_PER_PIXEL
	for y in range(int(COMPACT_CENTER.y - COMPACT_RADIUS), int(COMPACT_CENTER.y + COMPACT_RADIUS), int(TILE)):
		for x in range(int(COMPACT_CENTER.x - COMPACT_RADIUS), int(COMPACT_CENTER.x + COMPACT_RADIUS), int(TILE)):
			var sample_screen := Vector2(x + TILE * 0.5, y + TILE * 0.5)
			if sample_screen.distance_to(COMPACT_CENTER) > COMPACT_RADIUS - TILE * 0.42:
				continue
			var screen_delta := sample_screen - COMPACT_CENTER
			var world_position := _player.global_position \
				+ Vector3(screen_delta.x * scale, 0.0, -screen_delta.y * scale)
			var color := _landscape_color(world_position)
			draw_rect(Rect2(Vector2(x, y), Vector2(TILE + 0.6, TILE + 0.6)), color, true)


func _landscape_color(world_position: Vector3) -> Color:
	var texture_wave := sin(world_position.x * 0.037) * cos(world_position.z * 0.029)
	if map_context == CONTEXT_HUB:
		# Hub terrain: see HUB_ISLAND_CENTER for the layout.
		var flat := Vector2(world_position.x, world_position.z)
		var from_centre := flat.distance_to(HUB_ISLAND_CENTER)
		if from_centre > HUB_ISLAND_RADIUS:
			return Color("275a72").lightened(texture_wave * 0.035)
		if flat.distance_to(Vector2(CASTLE_POSITION.x, CASTLE_POSITION.z)) < 29.0:
			return Color("62697a").lightened(texture_wave * 0.045)
		if HUB_VILLAGE_PLAZA.has_point(flat):
			return Color("8a7a66").lightened(texture_wave * 0.05)
		if flat.y < -110.0 or (from_centre > 140.0 and flat.y < 35.0):
			return Color("4d5a5e").lightened(texture_wave * 0.04)
		if flat.y > 70.0 or from_centre > 160.0:
			return Color("b99a61").lightened(texture_wave * 0.035)
		return Color("527d4e").lightened(texture_wave * 0.055)

	if _world == null:
		return Color("151934")
	# _sample_* are filled in by _refresh_landscape_sampling() once per redraw.
	var local := _sample_world_to_local * world_position
	var local_flat := Vector2(local.x, local.z)
	if _sample_blueprint_active:
		for zone_index in _sample_zone_centres.size():
			if local_flat.distance_to(_sample_zone_centres[zone_index]) \
					<= _sample_zone_radii[zone_index]:
				return MIND_ZONE_COLORS[zone_index % MIND_ZONE_COLORS.size()] \
					.lightened(texture_wave * 0.055)
		for route_index in _sample_zone_centres.size() - 1:
			if _distance_to_segment(local_flat, _sample_zone_centres[route_index],
					_sample_zone_centres[route_index + 1]) <= 18.0:
				return Color("72d6e8").lightened(texture_wave * 0.035)
		if _sample_spur_active:
			if local_flat.distance_to(_sample_station_centre) <= 72.0 \
					or _distance_to_segment(local_flat, _sample_spur_start,
						_sample_station_centre) <= 12.0:
				return Color("436b78").lightened(texture_wave * 0.04)
	# The central galaxy uses real island centres/radii from
	# art_castle_floating_world.gd. Water here is the surrounding star void.
	for spec in GALAXY_ISLAND_SPECS:
		if local_flat.distance_to(spec[0]) <= float(spec[1]):
			return (spec[2] as Color).lightened(texture_wave * 0.06)
	# Connected bridges and the long gallery approach remain visible as land.
	for segment in GALAXY_BRIDGE_SEGMENTS:
		if _distance_to_segment(local_flat, segment[0], segment[1]) <= float(segment[2]):
			return Color("8d88a0").lightened(texture_wave * 0.035)
	# Each kingdom's round station platform.
	for index in _sample_kingdom_centres.size():
		if local_flat.distance_to(_sample_kingdom_centres[index]) <= _sample_kingdom_halves[index]:
			return _sample_kingdom_colors[index].lightened(texture_wave * 0.055)
	return Color("101329").lightened(texture_wave * 0.018)


## Resolve everything the per-tile sampler needs, once per redraw.
func _refresh_landscape_sampling() -> void:
	_sample_blueprint_active = false
	_sample_spur_active = false
	_sample_zone_centres.clear()
	_sample_zone_radii.clear()
	_sample_kingdom_centres.clear()
	_sample_kingdom_halves.clear()
	_sample_kingdom_colors.clear()
	if _world == null:
		return
	_sample_world_to_local = _world.global_transform.affine_inverse()

	var mind_world := _blueprint_world()
	if mind_world != null:
		_sample_blueprint_active = true
		var mind_ids: Array = mind_world.call("get_zone_ids")
		for zone_id in mind_ids:
			var centre: Vector3 = mind_world.position + mind_world.call("get_zone_position", zone_id)
			_sample_zone_centres.append(Vector2(centre.x, centre.z))
			_sample_zone_radii.append(float(mind_world.call("get_zone_radius", zone_id)))
		var station_spur := mind_world.get_node_or_null(
			"WorldOneGeometry/OptionalCompletedWorldStationSpur") as Node3D
		if station_spur != null and station_spur.visible:
			var spur_start: Vector3 = mind_world.position \
				+ station_spur.get_meta("branch_start", Vector3.ZERO)
			var station_centre: Vector3 = mind_world.position \
				+ station_spur.get_meta("station_center", Vector3.ZERO)
			_sample_spur_active = true
			_sample_spur_start = Vector2(spur_start.x, spur_start.z)
			_sample_station_centre = Vector2(station_centre.x, station_centre.z)

	if _regions != null:
		var centres: Dictionary = _regions.call("get_kingdom_centers")
		for index in KINGDOM_IDS.size():
			# Only kingdoms the regions node actually reports. Defaulting a
			# missing one to Vector3.ZERO would paint its platform over the
			# world origin, which is the Tree of Life.
			if not centres.has(KINGDOM_IDS[index]):
				continue
			var centre: Vector3 = centres[KINGDOM_IDS[index]]
			_sample_kingdom_centres.append(Vector2(centre.x, centre.z))
			_sample_kingdom_halves.append((_regions.call("get_kingdom_size", KINGDOM_IDS[index]) as Vector2).x * 0.5)
			_sample_kingdom_colors.append(KINGDOM_COLORS[index])


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	if segment.length_squared() < 0.001:
		return point.distance_to(start)
	var amount := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * amount)


func _draw_hub_compact() -> void:
	_draw_compact_marker(CASTLE_POSITION, "CASTLE", Color("f2c55e"), "castle")
	for mark in _hub_landmarks():
		# The doors stand ~13 m apart, under 8 px here: dots only, names on the full map.
		var door: bool = mark[2] == DOOR_COLOR
		_draw_compact_marker(mark[0], "" if door else mark[1], mark[2], "door" if door else "place")


func _hub_landmarks() -> Array:
	var marks := HUB_LANDMARKS.duplicate()
	var scene := get_tree().current_scene if is_inside_tree() else null
	for door in HUB_DOORS:
		var trigger := scene.get_node_or_null("%s/CollisionShape3D" % door[0]) as Node3D \
			if scene != null else null
		if trigger != null:
			marks.append([trigger.global_position, door[1], DOOR_COLOR])
	return marks


## Galaxy landmarks as [global position, label, colour], read from the live
## scene so they follow the world if it is rebuilt.
func _galaxy_landmarks() -> Array:
	var marks := []
	var world_consts: Dictionary = _world.get_script().get_script_constant_map()
	for entry in [["ARRIVAL_FOUNTAIN_CENTRE", "FOUNTAIN", Color("8fe3ff")],
			["HUB", "TREE OF LIFE", Color("9ef0a0")],
			["MIND_GATE_POSITION", "WORLD ONE GATE", Color("63e8ff"), true]]:
		if world_consts.has(entry[0]):
			marks.append([_world.to_global(world_consts[entry[0]]), entry[1], entry[2],
				entry.size() > 3])
	var maze := _regions.get_node_or_null("HeartKingdomPlatform/HeartMusicMaze") as Node3D \
		if _regions != null else null
	if maze != null:
		marks.append([maze.to_global(maze.call("entrance_position")), "MELODY MAZE", Color("ff91c9")])
	var heart := _railway.get_node_or_null("HeartMelodyConnection/HeartMelodyIslandOne") as Node3D \
		if _railway != null else null
	if heart != null:
		marks.append([heart.global_position, "QUIET MEADOW", Color("ff91c9"), true])
	return marks


func _draw_galaxy_compact() -> void:
	if _regions == null or _railway == null:
		draw_string(ThemeDB.fallback_font, COMPACT_CENTER + Vector2(-70, 4), "MAPPING GALAXY…",
			HORIZONTAL_ALIGNMENT_CENTER, 140, 12, Color("cdeeff"))
		return
	var centres: Dictionary = _regions.call("get_kingdom_centers")
	var stations: Dictionary = _railway.call("get_station_positions")
	_draw_compact_route(_track_points(), Color("b97cff"), 3.0)
	_draw_compact_marker(_galaxy_castle_position(), "GALLERY", Color("f2c55e"), "castle")
	var colors := {"mind": Color("63e8ff"), "heart": Color("ff91c9"), "creator": Color("ffd46b")}
	var labels := {"mind": "MIND", "heart": "HEART", "creator": "CREATOR"}
	# Only kingdoms the regions node reports; Mind is drawn from World One.
	for kingdom_id in centres:
		_draw_compact_marker(_world.to_global(centres[kingdom_id]), labels[kingdom_id],
			colors[kingdom_id], "place")
	for index in 4:
		var station_id: String = ["gallery", "mind", "heart", "creator"][index]
		var station_color := Color("f8f2ff") if bool(_railway.call("is_station_unlocked", index)) \
			else Color("646679")
		_draw_compact_marker(_world.to_global(stations[station_id]), "", station_color, "station")
	for mark in _galaxy_landmarks():
		_draw_compact_marker(mark[0], mark[1], mark[2], "place")


## The railway's track in global space, sampled once: it never moves, and the
## railway may still be building its curves when the map first looks.
func _track_points() -> Array:
	if _track.is_empty() and _railway != null and _railway.has_method("get_track_points"):
		for point in _railway.call("get_track_points"):
			_track.append(_railway.to_global(point))
	return _track


func _draw_compact_route(world_points: Array, color: Color, width: float) -> void:
	if _player == null or world_points.size() < 2:
		return
	for index in world_points.size() - 1:
		var start := _compact_point(world_points[index])
		var finish := _compact_point(world_points[index + 1])
		var clipped := _clip_segment_to_circle(start, finish, COMPACT_CENTER, COMPACT_RADIUS - 4.0)
		if clipped.size() == 2:
			draw_line(clipped[0], clipped[1], color, width, true)


func _draw_compact_marker(world_position: Vector3, label: String, color: Color, kind: String) -> void:
	if _player == null:
		return
	var raw := _compact_point(world_position)
	var offset := raw - COMPACT_CENTER
	var max_distance := COMPACT_RADIUS - 13.0
	var clamped := offset.length() > max_distance
	var point := COMPACT_CENTER + offset.normalized() * max_distance if clamped else raw
	if kind == "castle":
		_draw_castle(point, true)
	elif kind == "door":
		draw_rect(Rect2(point - Vector2(3.5, 3.5), Vector2(7, 7)), color, true)
	elif kind == "station":
		draw_circle(point, 4.5, _map_background())
		draw_arc(point, 5.5, 0, TAU, 20, color, 2.0, true)
	else:
		draw_circle(point, 5.0, color)
		draw_arc(point, 7.0, 0, TAU, 20, Color(color, 0.45), 1.0, true)
	if clamped:
		var inward := -offset.normalized()
		draw_line(point, point + inward * 7.0, color, 2.0, true)
	elif not label.is_empty() and point.x > 32.0 and point.x < COMPACT_SIZE.x - 52.0:
		draw_string(ThemeDB.fallback_font, point + Vector2(8, 4), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, color.lightened(0.12))


func compact_point_for_world(global_position: Vector3) -> Vector2:
	return _compact_point(global_position)


func _compact_point(global_position: Vector3) -> Vector2:
	if _player == null:
		return COMPACT_CENTER
	var difference := global_position - _player.global_position
	var scale := HUB_METERS_PER_PIXEL if map_context == CONTEXT_HUB else GALAXY_METERS_PER_PIXEL
	# North-up projection: world X -> screen X, world +Z -> screen up.
	return COMPACT_CENTER + Vector2(difference.x, -difference.z) / scale


func _clip_segment_to_circle(start: Vector2, finish: Vector2, center: Vector2,
		radius: float) -> PackedVector2Array:
	var p := start - center
	var direction := finish - start
	var a := direction.dot(direction)
	if a < 0.0001:
		return PackedVector2Array([start, finish]) if p.length() <= radius else PackedVector2Array()
	var b := 2.0 * p.dot(direction)
	var c := p.dot(p) - radius * radius
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return PackedVector2Array([start, finish]) if c <= 0.0 else PackedVector2Array()
	var root := sqrt(discriminant)
	var enter := maxf(0.0, (-b - root) / (2.0 * a))
	var exit := minf(1.0, (-b + root) / (2.0 * a))
	if enter > exit:
		return PackedVector2Array()
	return PackedVector2Array([start + direction * enter, start + direction * exit])


func _draw_compact_compass() -> void:
	var font := ThemeDB.fallback_font
	draw_circle(COMPACT_CENTER + Vector2(0, -COMPACT_RADIUS + 2), 11.0, Color("151725"))
	draw_string(font, COMPACT_CENTER + Vector2(-5, -COMPACT_RADIUS + 7), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("fff5d6"))
	draw_string(font, COMPACT_CENTER + Vector2(COMPACT_RADIUS - 8, 4), "E",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d5d9e6"))
	draw_string(font, COMPACT_CENTER + Vector2(-4, COMPACT_RADIUS - 4), "S",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d5d9e6"))
	draw_string(font, COMPACT_CENTER + Vector2(-COMPACT_RADIUS + 1, 4), "W",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d5d9e6"))


func _draw_full_map() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.015, 0.04, 0.82), true)
	var panel_size := Vector2(minf(size.x - 72.0, 1240.0), minf(size.y - 72.0, 820.0))
	var panel := Rect2((size - panel_size) * 0.5, panel_size)
	draw_rect(panel, Color("111522"), true)
	draw_rect(panel, Color(_accent(), 0.74), false, 2.0)
	var title := "ARTÉA KINGDOM • OUTSIDE THE CASTLE" if map_context == CONTEXT_HUB \
		else "ART CASTLE GALAXY • INSIDE WORLD"
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(28, 42), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, _accent())
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(panel.size.x - 190, 40),
		"M / ESC  CLOSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f5f1e8"))
	var map_rect := Rect2(panel.position + Vector2(28, 62), panel.size - Vector2(56, 116))
	# Keep the world's proportions, so a round island stays round.
	var aspect := _bounds.size.x / maxf(_bounds.size.y, 0.001)
	var fitted := map_rect.size
	if fitted.x / fitted.y > aspect:
		fitted.x = fitted.y * aspect
	else:
		fitted.y = fitted.x / aspect
	map_rect = Rect2(map_rect.position + (map_rect.size - fitted) * 0.5, fitted)
	draw_rect(map_rect, _map_background(), true)
	draw_rect(map_rect, Color(_accent(), 0.52), false, 1.5)
	if map_context == CONTEXT_HUB:
		_draw_hub_full_landscape(map_rect)
		_draw_hub_full(map_rect)
	else:
		_draw_galaxy_full_landscape(map_rect)
		_draw_galaxy_full(map_rect)
	if _player != null:
		_draw_player(_map_global(_player.global_position, map_rect), false)
	_draw_full_compass(map_rect)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(28, panel.size.y - 24),
		"▲ YOU    ◆ ART CASTLE    ○ CROWN LINE STATION",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("dcecff"))


func _draw_hub_full(rect: Rect2) -> void:
	_draw_castle(_map_global(CASTLE_POSITION, rect), false)
	for mark in _hub_landmarks():
		_draw_full_landmark(_map_global(mark[0], rect), mark[1], mark[2])


func _draw_hub_full_landscape(rect: Rect2) -> void:
	_draw_sampled_landscape(rect)


## Paints the full map from the same sampler as the compact map, so the two
## can never disagree about where land, sea or a platform is.
func _draw_sampled_landscape(rect: Rect2) -> void:
	_refresh_landscape_sampling()
	const TILE := 10.0
	var y := rect.position.y
	while y < rect.end.y:
		var x := rect.position.x
		while x < rect.end.x:
			var tile := Rect2(x, y, minf(TILE, rect.end.x - x), minf(TILE, rect.end.y - y))
			draw_rect(tile, _landscape_color(_world_for_map_point(tile.get_center(), rect)), true)
			x += TILE
		y += TILE


## Inverse of _map_global.
func _world_for_map_point(point: Vector2, rect: Rect2) -> Vector3:
	var normalized := (point - rect.position) / rect.size
	return Vector3(_bounds.position.x + normalized.x * _bounds.size.x, 0.0,
		_bounds.position.y + (1.0 - normalized.y) * _bounds.size.y)


func _draw_galaxy_full_landscape(rect: Rect2) -> void:
	if _world == null:
		return
	_draw_sampled_landscape(rect)
	_draw_mind_spark_blueprint(rect)


# World One, when it is drawing its standalone blueprint. Found by name and
# called by method name rather than cast to MindSparkWorldOne: naming the class
# compiles World One's script into whatever ships the minimap - the Hub - and so
# dragged World One into the Core Pack instead of the Art Castle's (ADR-0001).
func _blueprint_world() -> Node3D:
	var mind_world := _world.get_node_or_null("MindSparkWorldOne") as Node3D if _world != null else null
	if mind_world == null or not bool(mind_world.get("force_standalone_blueprint")):
		return null
	return mind_world


func _draw_mind_spark_blueprint(rect: Rect2) -> void:
	var mind_world := _blueprint_world()
	if mind_world == null:
		return
	var zone_ids: Array = mind_world.call("get_zone_ids")
	var points := PackedVector2Array()
	var radius_scale := rect.size.x / maxf(_bounds.size.x, 1.0)
	for zone_index in zone_ids.size():
		var local_center: Vector3 = mind_world.position + mind_world.call("get_zone_position", zone_ids[zone_index])
		var point := _map_local(local_center, rect)
		points.append(point)
		var radius := maxf(3.0, float(mind_world.call("get_zone_radius", zone_ids[zone_index])) * radius_scale)
		var color := Color("315f70") if zone_index < 4 else Color("4c386a")
		draw_circle(point, radius, Color(color, 0.92))
		draw_arc(point, radius, 0, TAU, 32, Color("72e6f1"), 1.0, true)
	if points.size() >= 2:
		draw_polyline(points, Color("72d6e8"), 2.6, true)
	var station := mind_world.get_node_or_null(
		"WorldOneGeometry/OptionalCompletedWorldStationSpur") as Node3D
	if station != null and station.visible:
		var branch_start: Vector3 = mind_world.position + station.get_meta("branch_start", Vector3.ZERO)
		var station_center: Vector3 = mind_world.position + station.get_meta("station_center", Vector3.ZERO)
		draw_line(_map_local(branch_start, rect), _map_local(station_center, rect),
			Color("72d6e8"), 2.0, true)
		draw_circle(_map_local(station_center, rect), maxf(2.5, 72.0 * radius_scale), Color("436b78"))


func _draw_galaxy_full(rect: Rect2) -> void:
	if _regions == null or _railway == null:
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(18, 34), "MAPPING THE GALAXY…",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("cdeeff"))
		return
	var centres: Dictionary = _regions.call("get_kingdom_centers")
	var stations: Dictionary = _railway.call("get_station_positions")
	var route := PackedVector2Array()
	for point in _track_points():
		route.append(_map_global(point, rect))
	if route.size() > 1:
		draw_polyline(route, Color("b97cff"), 4.0, true)
	_draw_castle(_map_global(_galaxy_castle_position(), rect), false)
	var colors := {"mind": Color("63e8ff"), "heart": Color("ff91c9"), "creator": Color("ffd46b")}
	var labels := {"mind": "MIND SPARK", "heart": "HEART MELODY", "creator": "CREATOR'S LIGHT"}
	for kingdom_id in centres:
		_draw_full_kingdom(_map_local(centres[kingdom_id], rect), colors[kingdom_id], labels[kingdom_id])
	for index in 4:
		var point := _map_local(stations[["gallery", "mind", "heart", "creator"][index]], rect)
		var unlocked := bool(_railway.call("is_station_unlocked", index))
		draw_circle(point, 5.0, Color("f8f2ff") if unlocked else Color("55576b"))
		draw_arc(point, 8.0, 0, TAU, 18, Color("6deaff") if unlocked else Color("77798b"), 1.5)
	for mark in _galaxy_landmarks():
		_draw_full_landmark(_map_global(mark[0], rect), mark[1], mark[2], mark.size() > 3 and mark[3])


func _draw_full_kingdom(point: Vector2, color: Color, label: String) -> void:
	draw_circle(point, 34.0, Color(color, 0.18))
	draw_arc(point, 34.0, 0, TAU, 32, color, 1.6)
	draw_string(ThemeDB.fallback_font, point + Vector2(-70, 5), label,
		HORIZONTAL_ALIGNMENT_CENTER, 140, 14, color.lightened(0.18))


func _draw_full_landmark(point: Vector2, label: String, color: Color, label_left := false) -> void:
	draw_circle(point, 7.0, color)
	var font := ThemeDB.fallback_font
	var at := point + Vector2(10, 5)
	if label_left:
		at.x = point.x - 10.0 - font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color.lightened(0.16))


func _draw_castle(point: Vector2, compact: bool) -> void:
	var radius := 7.0 if compact else 11.0
	var diamond := PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius, 0),
		point + Vector2(0, radius), point + Vector2(-radius, 0)])
	draw_colored_polygon(diamond, Color("f2c55e"))
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]),
		Color("fff7ce"), 1.5, true)


func _draw_player(point: Vector2, compact: bool) -> void:
	var facing := get_player_facing_screen()
	var side := facing.orthogonal()
	var length := 13.0 if compact else 17.0
	var width := 6.5 if compact else 8.5
	if compact:
		draw_circle(point, 13.5, Color(0.04, 0.05, 0.10, 0.72))
		draw_arc(point, 13.5, 0, TAU, 28, Color(_accent(), 0.55), 1.0, true)
	var arrow := PackedVector2Array([
		point + facing * length,
		point - facing * length * 0.55 + side * width,
		point - facing * length * 0.18,
		point - facing * length * 0.55 - side * width,
	])
	draw_colored_polygon(arrow, Color("fffdf5"))
	draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[3], arrow[0]]),
		Color("292238"), 2.0, true)


func _draw_full_compass(rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, rect.position + Vector2(rect.size.x * 0.5 - 5, 19), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f7f1df"))
	draw_string(font, rect.position + Vector2(rect.size.x - 23, rect.size.y * 0.5), "E",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f7f1df"))
	draw_string(font, rect.position + Vector2(10, rect.size.y * 0.5), "W",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f7f1df"))


func _galaxy_castle_position() -> Vector3:
	if _world != null and _world.has_method("is_embedded_in_gallery") \
			and not bool(_world.call("is_embedded_in_gallery")):
		# Directly launched galaxy scenes return through the authored south gate.
		return _world.to_global(Vector3(0.0, 0.0, 958.0))
	# In the embedded campaign the real gallery/castle boundary is global z=10.
	return Vector3(0.0, 0.0, 10.0)


func _find_player() -> Node3D:
	for group_name in ["Player", "player"]:
		for candidate in get_tree().get_nodes_in_group(group_name):
			if candidate is Node3D:
				return candidate as Node3D
	var scene := get_tree().current_scene
	if scene != null:
		for node_name in ["Player3D", "NewPlayer", "StoryPlayer"]:
			var candidate := scene.get_node_or_null(node_name)
			if candidate is Node3D:
				return candidate as Node3D
	return null


func _recalculate_bounds() -> void:
	if map_context == CONTEXT_HUB:
		_bounds = HUB_BOUNDS
		return
	if _regions == null or _world == null:
		_bounds = Rect2(-1000, -1000, 2000, 2000)
		return
	var centres: Dictionary = _regions.call("get_kingdom_centers")
	var min_x := -GALAXY_PADDING
	var max_x := GALAXY_PADDING
	var min_z := 10.0 - GALAXY_PADDING
	var max_z := 10.0 + GALAXY_PADDING
	for kingdom_id in centres:
		var centre_global := _world.to_global(centres[kingdom_id])
		var reach := (_regions.call("get_kingdom_size", kingdom_id) as Vector2).x * 0.5 + GALAXY_PADDING
		min_x = minf(min_x, centre_global.x - reach)
		max_x = maxf(max_x, centre_global.x + reach)
		min_z = minf(min_z, centre_global.z - reach)
		max_z = maxf(max_z, centre_global.z + reach)
	var mind_world := _blueprint_world()
	if mind_world != null:
		for zone_id in mind_world.call("get_zone_ids"):
			var centre_global := mind_world.to_global(mind_world.call("get_zone_position", zone_id))
			var radius := float(mind_world.call("get_zone_radius", zone_id)) + 12.0
			min_x = minf(min_x, centre_global.x - radius)
			max_x = maxf(max_x, centre_global.x + radius)
			min_z = minf(min_z, centre_global.z - radius)
			max_z = maxf(max_z, centre_global.z + radius)
	_bounds = Rect2(min_x, min_z, max_x - min_x, max_z - min_z)


func map_point_for_world(global_position: Vector3, rect: Rect2 = COMPACT_MAP_RECT) -> Vector2:
	return _map_global(global_position, rect)


func _map_local(local_position: Vector3, rect: Rect2) -> Vector2:
	return _map_global(_world.to_global(local_position), rect)


func _map_global(global_position: Vector3, rect: Rect2) -> Vector2:
	var normalized := Vector2(
		(global_position.x - _bounds.position.x) / maxf(_bounds.size.x, 0.001),
		(global_position.z - _bounds.position.y) / maxf(_bounds.size.y, 0.001))
	return rect.position + Vector2(normalized.x * rect.size.x, (1.0 - normalized.y) * rect.size.y)


func _map_background() -> Color:
	return Color("173126") if map_context == CONTEXT_HUB else Color("101329")


func _accent() -> Color:
	return Color("f2c55e") if map_context == CONTEXT_HUB else Color("72e6f1")
