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
const GALAXY_PADDING := 180.0
const HUB_BOUNDS := Rect2(-230.0, -230.0, 460.0, 460.0)
const CASTLE_POSITION := Vector3(-51.4, 0.0, 27.41)
const FACING_SPEED_THRESHOLD := 0.08
const TELEPORT_DISTANCE := 100.0

const HUB_RIVER := [
	Vector3(-190, 0, -220), Vector3(-132, 0, -110), Vector3(-148, 0, 4),
	Vector3(-108, 0, 102), Vector3(-82, 0, 220),
]
const HUB_ROAD := [
	Vector3(150, 0, -150), Vector3(62, 0, -48), Vector3(5, 0, 4), CASTLE_POSITION,
]

@export_enum("hub", "galaxy") var map_context := CONTEXT_GALAXY

var _player: Node3D
var _world: Node3D
var _regions: Node3D
var _railway: Node3D
var _bounds := HUB_BOUNDS
var _full_map_open := false
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _facing_world := Vector2(0.0, 1.0) # World X/Z. +Z is north on this atlas.
var _last_player_position := Vector3.ZERO
var _has_last_player_position := false


func _ready() -> void:
	name = "ArteaWorldMinimap"
	set_process_unhandled_input(true)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
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
	_recalculate_bounds()
	queue_redraw()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		_has_last_player_position = false
	_update_player_facing(delta)
	queue_redraw()


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
		# Hub terrain: ocean edge, beaches, forest/grass, village clearings, and
		# the raised castle rock. Coordinates match the current playable hub.
		var coast := world_position.z + 176.0 + sin(world_position.x * 0.025) * 20.0
		if coast < 0.0:
			return Color("275a72").lightened(texture_wave * 0.035)
		if coast < 18.0:
			return Color("b99a61").lightened(texture_wave * 0.035)
		var castle_distance := Vector2(world_position.x, world_position.z).distance_to(
			Vector2(CASTLE_POSITION.x, CASTLE_POSITION.z))
		if castle_distance < 29.0:
			return Color("62697a").lightened(texture_wave * 0.045)
		var village_distance := Vector2(world_position.x - 42.0, world_position.z + 40.0).length()
		if village_distance < 52.0:
			return Color("617f4c").lightened(texture_wave * 0.05)
		var mountain_distance := minf(
			Vector2(world_position.x + 95.0, world_position.z + 118.0).length(),
			Vector2(world_position.x - 112.0, world_position.z + 94.0).length())
		if mountain_distance < 58.0:
			return Color("435749").lightened(texture_wave * 0.04)
		return Color("527d4e").lightened(texture_wave * 0.055)

	if _world == null:
		return Color("151934")
	var local := _world.to_local(world_position)
	var mind_world := _world.get_node_or_null("MindSparkWorldOne") as MindSparkWorldOne
	if mind_world != null and mind_world.force_standalone_blueprint:
		var mind_colors := [Color("35506a"), Color("315f70"), Color("3e4d75"),
			Color("536d59"), Color("4c386a"), Color("3e6b5d")]
		var mind_ids := mind_world.get_zone_ids()
		for zone_index in mind_ids.size():
			var zone_center := mind_world.position + mind_world.get_zone_position(mind_ids[zone_index])
			if Vector2(local.x, local.z).distance_to(Vector2(zone_center.x, zone_center.z)) \
					<= mind_world.get_zone_radius(mind_ids[zone_index]):
				return mind_colors[zone_index].lightened(texture_wave * 0.055)
		for route_index in mind_ids.size() - 1:
			var route_start := mind_world.position + mind_world.get_zone_position(mind_ids[route_index])
			var route_finish := mind_world.position + mind_world.get_zone_position(mind_ids[route_index + 1])
			if _distance_to_segment(Vector2(local.x, local.z), Vector2(route_start.x, route_start.z),
					Vector2(route_finish.x, route_finish.z)) <= 18.0:
				return Color("72d6e8").lightened(texture_wave * 0.035)
		var station_spur := mind_world.get_node_or_null(
			"WorldOneGeometry/OptionalCompletedWorldStationSpur") as Node3D
		if station_spur != null and station_spur.visible:
			var spur_start: Vector3 = mind_world.position + station_spur.get_meta("branch_start", Vector3.ZERO)
			var station_center: Vector3 = mind_world.position + station_spur.get_meta("station_center", Vector3.ZERO)
			var point := Vector2(local.x, local.z)
			if point.distance_to(Vector2(station_center.x, station_center.z)) <= 72.0 \
					or _distance_to_segment(point, Vector2(spur_start.x, spur_start.z),
						Vector2(station_center.x, station_center.z)) <= 12.0:
				return Color("436b78").lightened(texture_wave * 0.04)
	# The central galaxy uses real island centres/radii from
	# art_castle_floating_world.gd. Water here is the surrounding star void.
	var island_specs := [
		[Vector2(0, 820), 160.0, Color("596d72")],
		[Vector2(0, 1640), 225.0, Color("537d66")],
		[Vector2(-600, 1640), 180.0, Color("315f70")],
		[Vector2(0, 2290), 180.0, Color("79526d")],
		[Vector2(600, 1640), 180.0, Color("806f49")],
	]
	var local_flat := Vector2(local.x, local.z)
	for spec in island_specs:
		if local_flat.distance_to(spec[0]) <= float(spec[1]):
			return (spec[2] as Color).lightened(texture_wave * 0.06)
	# Connected bridges and the long gallery approach remain visible as land.
	for segment in [
		[Vector2(0, 500), Vector2(0, 1422), 34.0],
		[Vector2(-218, 1640), Vector2(-430, 1640), 34.0],
		[Vector2(0, 1858), Vector2(0, 2120), 34.0],
		[Vector2(218, 1640), Vector2(410, 1640), 34.0],
	]:
		if _distance_to_segment(local_flat, segment[0], segment[1]) <= float(segment[2]):
			return Color("8d88a0").lightened(texture_wave * 0.035)
	# Each 3 km kingdom is a real authored square region beyond the inner isles.
	if _regions != null:
		var centres: Dictionary = _regions.call("get_kingdom_centers")
		for kingdom_id in ["mind", "heart", "creator"]:
			var centre: Vector3 = centres[kingdom_id]
			if absf(local.x - centre.x) <= 1500.0 and absf(local.z - centre.z) <= 1500.0:
				var colors := {"mind": Color("28394d"), "heart": Color("5b4356"),
					"creator": Color("675c3e")}
				return colors[kingdom_id].lightened(texture_wave * 0.055)
	return Color("101329").lightened(texture_wave * 0.018)


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	if segment.length_squared() < 0.001:
		return point.distance_to(start)
	var amount := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * amount)


func _draw_hub_compact() -> void:
	_draw_compact_route(HUB_RIVER, Color("4b99b7"), 8.0)
	_draw_compact_route(HUB_ROAD, Color("c9ab72"), 3.5)
	_draw_compact_marker(CASTLE_POSITION, "CASTLE", Color("f2c55e"), "castle")
	_draw_compact_marker(Vector3(42, 0, -40), "VILLAGE", Color("9bd487"), "place")
	_draw_compact_marker(Vector3(150, 0, -150), "PIER", Color("6fcfe8"), "place")
	_draw_compact_marker(Vector3(-120, 0, 112), "SKYRAIL", Color("d89cff"), "station")


func _draw_galaxy_compact() -> void:
	if _regions == null or _railway == null:
		draw_string(ThemeDB.fallback_font, COMPACT_CENTER + Vector2(-70, 4), "MAPPING GALAXY…",
			HORIZONTAL_ALIGNMENT_CENTER, 140, 12, Color("cdeeff"))
		return
	var centres: Dictionary = _regions.call("get_kingdom_centers")
	var stations: Dictionary = _railway.call("get_station_positions")
	var route := []
	for station_id in ["gallery", "mind", "heart", "creator"]:
		route.append(_world.to_global(stations[station_id]))
	_draw_compact_route(route, Color("b97cff"), 3.0)
	_draw_compact_marker(_galaxy_castle_position(), "GALLERY", Color("f2c55e"), "castle")
	var colors := {"mind": Color("63e8ff"), "heart": Color("ff91c9"), "creator": Color("ffd46b")}
	var labels := {"mind": "MIND", "heart": "HEART", "creator": "CREATOR"}
	for kingdom_id in ["mind", "heart", "creator"]:
		_draw_compact_marker(_world.to_global(centres[kingdom_id]), labels[kingdom_id],
			colors[kingdom_id], "place")
	for index in 4:
		var station_id: String = ["gallery", "mind", "heart", "creator"][index]
		var station_color := Color("f8f2ff") if bool(_railway.call("is_station_unlocked", index)) \
			else Color("646679")
		_draw_compact_marker(_world.to_global(stations[station_id]), "", station_color, "station")


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
	var river := PackedVector2Array()
	for point in HUB_RIVER:
		river.append(_map_global(point, rect))
	draw_polyline(river, Color("4b99b7"), 12.0, true)
	var road := PackedVector2Array()
	for point in HUB_ROAD:
		road.append(_map_global(point, rect))
	draw_polyline(road, Color("c9ab72"), 5.0, true)
	_draw_castle(_map_global(CASTLE_POSITION, rect), false)
	_draw_full_landmark(_map_global(Vector3(42, 0, -40), rect), "VILLAGE", Color("9bd487"))
	_draw_full_landmark(_map_global(Vector3(150, 0, -150), rect), "PIER", Color("6fcfe8"))
	_draw_full_landmark(_map_global(Vector3(-120, 0, 112), rect), "SKYRAIL", Color("d89cff"))


func _draw_hub_full_landscape(rect: Rect2) -> void:
	# Broad terrain silhouettes before paths and labels. These are keyed to the
	# live hub bounds and landmark coordinates rather than decorative wallpaper.
	var sea_edge := PackedVector2Array([
		_map_global(Vector3(-230, 0, -230), rect),
		_map_global(Vector3(230, 0, -230), rect),
		_map_global(Vector3(230, 0, -172), rect),
		_map_global(Vector3(120, 0, -158), rect),
		_map_global(Vector3(15, 0, -182), rect),
		_map_global(Vector3(-95, 0, -154), rect),
		_map_global(Vector3(-230, 0, -176), rect),
	])
	draw_colored_polygon(sea_edge, Color("275a72"))
	var beach := PackedVector2Array([
		_map_global(Vector3(-230, 0, -176), rect),
		_map_global(Vector3(-95, 0, -154), rect),
		_map_global(Vector3(15, 0, -182), rect),
		_map_global(Vector3(120, 0, -158), rect),
		_map_global(Vector3(230, 0, -172), rect),
		_map_global(Vector3(230, 0, -142), rect),
		_map_global(Vector3(105, 0, -132), rect),
		_map_global(Vector3(10, 0, -154), rect),
		_map_global(Vector3(-110, 0, -126), rect),
		_map_global(Vector3(-230, 0, -146), rect),
	])
	draw_colored_polygon(beach, Color("9e8759"))
	for mountain in [Vector3(-95, 0, -118), Vector3(112, 0, -94)]:
		var centre := _map_global(mountain, rect)
		draw_circle(centre, rect.size.x * 0.105, Color("405348"))
		draw_arc(centre, rect.size.x * 0.072, 0, TAU, 40, Color("73826c"), 2.0, true)
	var village := _map_global(Vector3(42, 0, -40), rect)
	draw_circle(village, rect.size.x * 0.085, Color("657d4e"))
	var castle_rock := _map_global(CASTLE_POSITION, rect)
	draw_circle(castle_rock, rect.size.x * 0.055, Color("646b7b"))


func _draw_galaxy_full_landscape(rect: Rect2) -> void:
	if _world == null:
		return
	# Outer kingdom landmasses: exact 3 km x 3 km authored extents.
	if _regions != null:
		var centres: Dictionary = _regions.call("get_kingdom_centers")
		var colors := {"mind": Color("25394c"), "heart": Color("584052"),
			"creator": Color("655a3c")}
		for kingdom_id in ["mind", "heart", "creator"]:
			var centre: Vector3 = centres[kingdom_id]
			var top_left := _map_local(centre + Vector3(-1500, 0, 1500), rect)
			var bottom_right := _map_local(centre + Vector3(1500, 0, -1500), rect)
			var region_rect := Rect2(top_left, bottom_right - top_left).abs()
			draw_rect(region_rect, colors[kingdom_id], true)
			draw_rect(region_rect, Color(colors[kingdom_id].lightened(0.28), 0.75), false, 1.5)
			# Five-by-five shelves mirror the generated region chunk layout.
			for row in 5:
				for column in 5:
					var chunk := centre + Vector3(-1160 + column * 580, 0, -1160 + row * 580)
					var chunk_point := _map_local(chunk, rect)
					draw_circle(chunk_point, maxf(2.0, region_rect.size.x * 0.048),
						Color(colors[kingdom_id].lightened(0.07), 0.58))
	# Inner floating islands and their true connecting bridges.
	var island_specs := [
		[Vector3(0, 0, 820), 155.0, Color("596d72")],
		[Vector3(0, 0, 1640), 220.0, Color("537d66")],
		[Vector3(-600, 0, 1640), 175.0, Color("315f70")],
		[Vector3(0, 0, 2290), 175.0, Color("79526d")],
		[Vector3(600, 0, 1640), 175.0, Color("806f49")],
	]
	var radius_scale := rect.size.x / maxf(_bounds.size.x, 1.0)
	for spec in island_specs:
		var centre := _map_local(spec[0], rect)
		var radius := maxf(4.0, float(spec[1]) * radius_scale)
		draw_circle(centre, radius, spec[2])
		draw_arc(centre, radius, 0, TAU, 40, Color((spec[2] as Color).lightened(0.25), 0.72), 1.2)
	for bridge in [
		[Vector3(0, 0, 500), Vector3(0, 0, 1422)],
		[Vector3(-218, 0, 1640), Vector3(-430, 0, 1640)],
		[Vector3(0, 0, 1858), Vector3(0, 0, 2120)],
		[Vector3(218, 0, 1640), Vector3(410, 0, 1640)],
	]:
		draw_line(_map_local(bridge[0], rect), _map_local(bridge[1], rect),
			Color("9e98ad"), 4.0, true)
	_draw_mind_spark_blueprint(rect)


func _draw_mind_spark_blueprint(rect: Rect2) -> void:
	var mind_world := _world.get_node_or_null("MindSparkWorldOne") as MindSparkWorldOne
	if mind_world == null or not mind_world.force_standalone_blueprint:
		return
	var zone_ids := mind_world.get_zone_ids()
	var points := PackedVector2Array()
	var radius_scale := rect.size.x / maxf(_bounds.size.x, 1.0)
	for zone_index in zone_ids.size():
		var local_center := mind_world.position + mind_world.get_zone_position(zone_ids[zone_index])
		var point := _map_local(local_center, rect)
		points.append(point)
		var radius := maxf(3.0, mind_world.get_zone_radius(zone_ids[zone_index]) * radius_scale)
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
	for station_id in ["gallery", "mind", "heart", "creator"]:
		route.append(_map_local(stations[station_id], rect))
	draw_polyline(route, Color("b97cff"), 4.0, true)
	_draw_castle(_map_global(_galaxy_castle_position(), rect), false)
	var colors := {"mind": Color("63e8ff"), "heart": Color("ff91c9"), "creator": Color("ffd46b")}
	var labels := {"mind": "MIND SPARK", "heart": "HEART MELODY", "creator": "CREATOR'S LIGHT"}
	for kingdom_id in ["mind", "heart", "creator"]:
		_draw_full_kingdom(_map_local(centres[kingdom_id], rect), colors[kingdom_id], labels[kingdom_id])
	for index in 4:
		var point := _map_local(stations[["gallery", "mind", "heart", "creator"][index]], rect)
		var unlocked := bool(_railway.call("is_station_unlocked", index))
		draw_circle(point, 5.0, Color("f8f2ff") if unlocked else Color("55576b"))
		draw_arc(point, 8.0, 0, TAU, 18, Color("6deaff") if unlocked else Color("77798b"), 1.5)


func _draw_full_kingdom(point: Vector2, color: Color, label: String) -> void:
	draw_circle(point, 34.0, Color(color, 0.18))
	draw_arc(point, 34.0, 0, TAU, 32, color, 1.6)
	draw_string(ThemeDB.fallback_font, point + Vector2(-70, 5), label,
		HORIZONTAL_ALIGNMENT_CENTER, 140, 14, color.lightened(0.18))


func _draw_full_landmark(point: Vector2, label: String, color: Color) -> void:
	draw_circle(point, 7.0, color)
	draw_string(ThemeDB.fallback_font, point + Vector2(10, 5), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color.lightened(0.16))


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
	for centre_value in centres.values():
		var centre_global := _world.to_global(centre_value)
		min_x = minf(min_x, centre_global.x - 1500.0 - GALAXY_PADDING)
		max_x = maxf(max_x, centre_global.x + 1500.0 + GALAXY_PADDING)
		min_z = minf(min_z, centre_global.z - 1500.0 - GALAXY_PADDING)
		max_z = maxf(max_z, centre_global.z + 1500.0 + GALAXY_PADDING)
	var mind_world := _world.get_node_or_null("MindSparkWorldOne") as MindSparkWorldOne
	if mind_world != null and mind_world.force_standalone_blueprint:
		for zone_id in mind_world.get_zone_ids():
			var centre_global := mind_world.to_global(mind_world.get_zone_position(zone_id))
			var radius := mind_world.get_zone_radius(zone_id) + 12.0
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
