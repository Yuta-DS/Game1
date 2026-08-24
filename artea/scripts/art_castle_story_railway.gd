extends Node3D

# The Rainbow Galaxy Train follows one level closed Crown Line. The route runs
# Gallery -> Mind -> Heart -> Creator -> Gallery without a terminal reversal.

const ROUTE_HEIGHT := 35.0
const STATION_STRAIGHT_LENGTH := 150.0
# Forty metres is a full urban-rail turning radius and still more than three
# Crown Line widths. The two large kingdom arcs are far broader; this lower
# bound applies only to the compact Gallery/Mind Spark sightseeing loop.
const MINIMUM_DESIGN_TURN_RADIUS := 40.0

const STATIONS := [
	{"id": "gallery", "title": "ARTÉA GALLERY", "subtitle": "RIGHT-SIDE SKY DOCK", "position": Vector3(260.0, ROUTE_HEIGHT, 820.0), "landing": Vector3(150.0, 2.0, 820.0)},
	# Keep the station around its original west-side location, but align its
	# entrance directly with the main Mind Spark park island. The 79 m clear gap
	# from the platform rim to the island rim is exactly occupied by one centred
	# ceremonial stair, with its landing overlapping the island by 8 m.
	{"id": "mind", "title": "MIND SPARK", "subtitle": "PARK EDGE STATION", "position": Vector3(-883.0, ROUTE_HEIGHT, 1640.0), "landing": Vector3(-767.0, 2.0, 1640.0)},
	{"id": "heart", "title": "HEART MELODY", "subtitle": "EAST FLOATING STATION", "position": Vector3(1700.0, ROUTE_HEIGHT, 7640.0), "landing": Vector3(1500.0, 2.0, 7640.0)},
	{"id": "creator", "title": "CREATOR'S LIGHT", "subtitle": "EAST FLOATING STATION", "position": Vector3(5300.0, ROUTE_HEIGHT, 3940.0), "landing": Vector3(5100.0, 2.0, 3940.0)},
]

# The Crown Line always enters the game parked at the castle-side Gallery dock.
# Keeping this named avoids a later station reorder silently moving the player's
# first train away from the opening castle runway/arrival island.
const START_STATION_INDEX := 0

const CONTROL_POINTS := [
	# Preserve the original station approach/departure directions, but keep every
	# handle on the shared level plane. The fourth pair is the new closing arc.
	[Vector3(420.0, ROUTE_HEIGHT, 1080.0), Vector3(-680.0, ROUTE_HEIGHT, 1510.0)],
	[Vector3(1800.0, ROUTE_HEIGHT, 5200.0), Vector3(2050.0, ROUTE_HEIGHT, 6500.0)],
	[Vector3(5600.0, ROUTE_HEIGHT, 7200.0), Vector3(5600.0, ROUTE_HEIGHT, 5000.0)],
	[Vector3(4973.0, ROUTE_HEIGHT, 2785.0), Vector3(100.0, ROUTE_HEIGHT, 560.0)],
]

const BLUEPRINT := {
	"layout_side": "right/east",
	"kingdom_boundary_clearance_m": 200.0,
	"dock_radius_m": 38.0,
	"access_bridge_width_m": 16.0,
	"platform_guard_height_m": 3.0,
	"rail_system": "single_center_monorail",
	"center_beam_width_m": 3.2,
	"center_beam_height_m": 1.6,
	"train_origin_above_beam_m": 1.4,
	"minimum_rail_elevation_m": ROUTE_HEIGHT - 1.4,
	"station_straight_length_m": STATION_STRAIGHT_LENGTH,
	"minimum_design_turn_radius_m": MINIMUM_DESIGN_TURN_RADIUS,
	"route_character": "straight_docks_broad_sightseeing_curves",
	"closed_loop": true,
}

const RIDE_SECONDS := 14.0
const INTERACTION_RANGE := 48.0
# The driver station sits at the front end of the first coach's open deck, just
# behind the engine bulkhead. Both points must be air the player can actually
# stand in: the old cab seat at z=-13 was buried inside the solid EngineBody box
# (y 0..8, z -23.5..-6.5), so boarding teleported the player into geometry, and
# the old interaction point at z=-6 sat on the far side of the driver console
# wall, out of reach from the deck. Keep both on the walkable deck side of the
# bulkhead, above the deck floor (deck top is y=1.3).
const DRIVER_INTERACTION_POINT := Vector3(0.0, 2.4, -4.6)
const DRIVER_SEAT := Vector3(0.0, 2.4, -4.6)
# Q is a close, intentional interaction, but it has to be comfortable to hit
# while walking. The driver range covers the whole front third of the first
# coach so approaching the cab from anywhere on the deck offers driving without
# the player having to hunt for an exact spot; the seat range stays shorter so
# the two never fight over the middle of the coach.
const DRIVER_INTERACTION_RANGE := 8.0
const SEAT_INTERACTION_RANGE := 3.5
# Seat points are where the player capsule's CENTRE is placed, so they sit a
# capsule half-height above the bench top (JumpBench spans y 0.65..2.65) rather
# than on it. At the old y=3.0 the character's feet ended up level with the
# cushion and it read as standing on the bench instead of sitting in it.
const BENCH_SEATS := [
	Vector3(-2.4, 3.45, 2.8), Vector3(0.0, 3.45, 2.8), Vector3(2.4, 3.45, 2.8),
	Vector3(-2.4, 3.45, 17.8), Vector3(0.0, 3.45, 17.8), Vector3(2.4, 3.45, 17.8),
]
const BOARDING_OFFSET := Vector3(0.0, 0.0, 11.0)
const ACCESS_DECK_THICKNESS := 1.0
const LANDING_PLAYER_CLEARANCE := 2.0
const MANUAL_DRIVE_SPEED := 420.0
const DISPLAY_MAX_SPEED_KPH := 120.0
const DISPLAY_ACCELERATION_KPH_S := 34.0
const DISPLAY_BRAKING_KPH_S := 58.0
const STAIR_STEP_COUNT := 16
# Begin at the circular platform rim. The previous -29.5 m start left the
# skybridge running underneath the gray platform from x=-37 to x=-31, which
# appeared as a wide gray break through the stair when viewed from above.
const STAIR_START_X := -35.8
const STAIR_END_X := -7.5
const STAIR_BOTTOM_TOP_Y := -0.65
const STAIR_TOP_TOP_Y := 1.10
const DETAILED_TRAIN_MODEL_PATH := "res://assets3D/crown_line_train/crown_line_runtime_textured.glb"
const DETAILED_TRAIN_EDITABLE_PARTS := 13000
const GODOT_ENGINE_COVER_SCRIPT := "res://scripts/crown_line_godot_engine_cover.gd"

@export var ride_duration := RIDE_SECONDS

var _curves: Array[Curve3D] = []
var _station_nodes: Array[Node3D] = []
var _player: CharacterBody3D
var _train: Node3D
var _train_glow: OmniLight3D
var _current_station := START_STATION_INDEX
var _direction := 1
var _riding := false
var _manual_driving := false
var _seated_passenger := false
var _passenger_in_motion := false
var _passenger_seat_index := -1
var _drive_segment := -1
var _drive_progress := 0.0
var _drive_motion_direction := 1
var _display_speed_kph := 0.0
var _last_train_position := Vector3.ZERO
var _movement_vfx: Node3D
var _rainbow_trail_particles: GPUParticles3D
var _gold_trail_particles: GPUParticles3D
var _rainbow_wake_ribbons: Array[MeshInstance3D] = []
var _motion_blur_echoes: Array[Node3D] = []
var _motion_echo_history: Array[Transform3D] = []
var _last_motion_direction := Vector3.FORWARD
var _movement_vfx_speed_ratio := 0.0
var _rainbow_gold_accent_count := 0
var _horn_request_count := 0
var _speed_band_parts: Array[Node3D] = []
var _speed_rotor_parts: Array[Node3D] = []
var _speed_needle: Node3D
var _wheel_mechanism_parts: Array[Node3D] = []
var _reactor_mechanism_parts: Array[Node3D] = []
var _steam_gear_parts: Array[Node3D] = []
var _brake_needles: Array[Node3D] = []
var _island_power_rotors: Array[Node3D] = []
var _island_power_lights: Array[OmniLight3D] = []
var _mechanism_time := 0.0
var _prompt: Label
var _status: Label
var _rail_material: ShaderMaterial
var _gold_material: StandardMaterial3D
var _glass_material: StandardMaterial3D
var _stone_material: StandardMaterial3D
var _nature_material: StandardMaterial3D
var _violet_material: StandardMaterial3D
var _canopy_material: StandardMaterial3D
var _dark_metal_material: StandardMaterial3D


func _ready() -> void:
	_player = get_node_or_null("../../Player3D") as CharacterBody3D
	if _player == null:
		_player = get_node_or_null("../Player3D") as CharacterBody3D
	_build_materials()
	_build_route()
	_build_stations()
	_build_train()
	_build_hud()
	_refresh_station_lights()


func _process(delta: float) -> void:
	_refresh_station_lights()
	if _manual_driving:
		var throttle := Input.get_action_strength("move_forward") \
			- Input.get_action_strength("move_backward")
		drive_manual(throttle, delta)
	elif _train != null and not _riding:
		# Keep the docked chassis exactly aligned with the level guideway.
		_train.position.y = ROUTE_HEIGHT
	if _seated_passenger and _player != null and _train != null and _passenger_seat_index >= 0:
		_player.global_position = _train.to_global(BENCH_SEATS[_passenger_seat_index])
	_update_train_mechanisms(delta)
	_update_island_power_effect(delta)
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _player == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var pressed_key := (event as InputEventKey).physical_keycode
		if pressed_key == KEY_NONE:
			pressed_key = (event as InputEventKey).keycode
		if pressed_key == KEY_R and _manual_driving:
			if request_horn():
				get_viewport().set_input_as_handled()
			return
		if pressed_key == KEY_1 or pressed_key == KEY_2:
			var mode := "drive" if pressed_key == KEY_1 else "ride"
			if select_train_mode(mode):
				get_viewport().set_input_as_handled()
			return
	# "interact" is the project's Q binding (physical keycode 81). Testing
	# event.keycode directly missed it entirely: the action is authored with
	# physical_keycode set and keycode left at 0, so the old comparison only
	# ever matched by accident of keyboard layout.
	if event.is_action_pressed("interact") and not event.is_echo():
		if _seated_passenger:
			if _passenger_in_motion:
				_status.text = "PASSENGER RIDE IN PROGRESS  •  EXIT AT THE NEXT STATION"
			else:
				leave_passenger_seat()
			get_viewport().set_input_as_handled()
			return
		if _manual_driving:
			if _drive_segment < 0:
				request_disembark()
			else:
				_status.text = "SLOW TO A STATION BEFORE LEAVING THE DRIVER DECK"
			get_viewport().set_input_as_handled()
			return
		if _riding:
			return
		var interaction_mode := get_interaction_mode_for_position(_player.global_position)
		if interaction_mode == "drive":
			board_as_driver()
			get_viewport().set_input_as_handled()
			return
		if interaction_mode == "sit":
			var nearest_seat := get_nearest_passenger_seat_index(_player.global_position)
			sit_in_passenger_seat(nearest_seat)
			get_viewport().set_input_as_handled()


# The active third-person camera, if this scene has one. Riding and driving push
# it out to a wide view; stepping off restores normal following. Resolved live
# rather than cached at _ready, because the gallery swaps cameras at runtime.
func _follow_camera() -> Node:
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.has_method("begin_ride_view"):
		return camera
	for candidate in get_tree().get_nodes_in_group("follow_camera"):
		if candidate.has_method("begin_ride_view"):
			return candidate
	return null


# Boarding always starts in third person so the player can see the train they
# are on. They remain free to press 1 for first person once aboard.
func _begin_ride_camera(distance: float) -> void:
	var camera := _follow_camera()
	if camera != null:
		camera.call("begin_ride_view", distance)


func _end_ride_camera() -> void:
	var camera := _follow_camera()
	if camera != null:
		camera.call("end_ride_view")


func get_station_count() -> int:
	return STATIONS.size()


func get_segment_count() -> int:
	return _curves.size()


func is_closed_loop() -> bool:
	return true


func get_route_forward_direction_at_station(station_index: int) -> Vector3:
	if _curves.is_empty():
		return Vector3.ZERO
	var curve: Curve3D = _curves[posmod(station_index, _curves.size())]
	return (curve.sample_baked(2.0) - curve.sample_baked(0.0)).normalized()


func get_route_endpoints() -> PackedVector3Array:
	return PackedVector3Array([STATIONS.front().position, STATIONS.back().position])


func get_station_positions() -> Dictionary:
	var result := {}
	for station in STATIONS:
		result[station.id] = station.position
	return result


func get_engineering_blueprint() -> Dictionary:
	return BLUEPRINT.duplicate(true)


func get_minimum_route_height() -> float:
	var minimum := INF
	for curve in _curves:
		var length := curve.get_baked_length()
		for sample in 41:
			minimum = minf(minimum, curve.sample_baked(length * float(sample) / 40.0).y)
	return minimum


func get_total_route_length() -> float:
	var total := 0.0
	for curve in _curves:
		total += curve.get_baked_length()
	return total


func get_full_lap_drive_seconds() -> float:
	return get_total_route_length() / MANUAL_DRIVE_SPEED


func get_minimum_turn_radius() -> float:
	var minimum_radius := INF
	for segment_index in _curves.size():
		minimum_radius = minf(minimum_radius, get_segment_minimum_turn_radius(segment_index))
	return minimum_radius


func get_segment_minimum_turn_radius(segment_index: int) -> float:
	if segment_index < 0 or segment_index >= _curves.size():
		return 0.0
	var curve := _curves[segment_index]
	var length := curve.get_baked_length()
	var minimum_radius := INF
	var sample_count := maxi(3, int(ceil(length / 8.0)))
	for sample_index in range(1, sample_count):
		var distance := length * float(sample_index) / float(sample_count)
		var a := curve.sample_baked(maxf(0.0, distance - 4.0))
		var b := curve.sample_baked(distance)
		var c := curve.sample_baked(minf(length, distance + 4.0))
		var side_a := a.distance_to(b)
		var side_b := b.distance_to(c)
		var side_c := c.distance_to(a)
		var twice_area := (b - a).cross(c - a).length()
		if twice_area > 0.001:
			var radius := side_a * side_b * side_c / (2.0 * twice_area)
			minimum_radius = minf(minimum_radius, radius)
	return minimum_radius


func get_station_landing(index: int) -> Vector3:
	if index < 0 or index >= STATIONS.size():
		return Vector3.ZERO
	return STATIONS[index].landing


func get_station_position(index: int) -> Vector3:
	if index < 0 or index >= STATIONS.size():
		return Vector3.ZERO
	return STATIONS[index].position


func get_train_deck_position() -> Vector3:
	if _train == null:
		return Vector3.ZERO
	return _train.to_global(Vector3(0.0, 1.35, 0.0))


func get_driver_interaction_position() -> Vector3:
	if _train == null:
		return Vector3.ZERO
	return _train.to_global(DRIVER_INTERACTION_POINT)


func get_driver_seat_position() -> Vector3:
	if _train == null:
		return Vector3.ZERO
	return _train.to_global(DRIVER_SEAT)


func get_nearest_passenger_seat_index(world_position: Vector3) -> int:
	if _train == null:
		return -1
	var nearest_index := -1
	var nearest_distance := SEAT_INTERACTION_RANGE
	for seat_index in BENCH_SEATS.size():
		var distance := world_position.distance_to(_train.to_global(BENCH_SEATS[seat_index]))
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_index = seat_index
	return nearest_index


func get_passenger_seat_count() -> int:
	return BENCH_SEATS.size()


func get_driver_interaction_range() -> float:
	return DRIVER_INTERACTION_RANGE


func get_seat_interaction_range() -> float:
	return SEAT_INTERACTION_RANGE


func get_passenger_seat_position(seat_index: int) -> Vector3:
	if _train == null or seat_index < 0 or seat_index >= BENCH_SEATS.size():
		return Vector3.ZERO
	return _train.to_global(BENCH_SEATS[seat_index])


func is_passenger_seated() -> bool:
	return _seated_passenger


func is_passenger_train_moving() -> bool:
	return _seated_passenger and _passenger_in_motion


func get_interaction_mode_for_position(world_position: Vector3) -> String:
	if _train == null:
		return "none"
	var driver_distance := world_position.distance_to(get_driver_interaction_position())
	var nearest_seat := get_nearest_passenger_seat_index(world_position)
	var seat_distance := INF
	if nearest_seat >= 0:
		seat_distance = world_position.distance_to(get_passenger_seat_position(nearest_seat))
	if driver_distance <= DRIVER_INTERACTION_RANGE and driver_distance <= seat_distance:
		return "drive"
	if nearest_seat >= 0:
		return "sit"
	return "none"


func get_current_station() -> int:
	return _current_station


func get_start_station_index() -> int:
	return START_STATION_INDEX


func get_start_station_id() -> String:
	return String(STATIONS[START_STATION_INDEX].id)


func is_riding() -> bool:
	return _riding


func is_driving() -> bool:
	return _manual_driving


func get_drive_segment() -> int:
	return _drive_segment


func get_drive_progress() -> float:
	return _drive_progress


func get_display_speed_kph() -> float:
	return _display_speed_kph


func get_horn_request_count() -> int:
	return _horn_request_count


func get_registered_mechanism_count() -> int:
	return _speed_band_parts.size() + _speed_rotor_parts.size() + _wheel_mechanism_parts.size() \
		+ _reactor_mechanism_parts.size() + _steam_gear_parts.size() + _brake_needles.size()


func get_directional_vfx_state() -> Dictionary:
	var ribbon_positions: Array[Vector3] = []
	for ribbon in _rainbow_wake_ribbons:
		ribbon_positions.append(ribbon.global_position)
	var echo_positions: Array[Vector3] = []
	var visible_echo_count := 0
	for echo in _motion_blur_echoes:
		if echo.visible:
			echo_positions.append(echo.global_position)
			visible_echo_count += 1
	return {
		"available": _movement_vfx != null and _rainbow_trail_particles != null,
		"emitting": _rainbow_trail_particles.emitting if _rainbow_trail_particles != null else false,
		"movement_direction": _last_motion_direction,
		"trail_world_position": _movement_vfx.global_position if _movement_vfx != null else Vector3.ZERO,
		"speed_ratio": _movement_vfx_speed_ratio,
		"rainbow_colour_count": 7,
		"ribbon_world_positions": ribbon_positions,
		"echo_world_positions": echo_positions,
		"visible_echo_count": visible_echo_count,
		"gold_accent_count": _rainbow_gold_accent_count,
	}


func get_train_feature_summary() -> Dictionary:
	return {
		"driveable": true,
		"walkable": true,
		"jumpable": true,
		"sittable": true,
		"passenger_seats": BENCH_SEATS.size(),
		"analog_speed_mechanism": true,
		"closed_loop": true,
		"level_route": true,
		"proximity_interactions": true,
		"driver_interaction_range_m": DRIVER_INTERACTION_RANGE,
		"seat_interaction_range_m": SEAT_INTERACTION_RANGE,
		"interaction_rule": "nearest cab or passenger seat",
		"cab_entry": "front doorway to driver seat",
		"mode_controls": "1 drive, 2 ride",
		"driver_controls": "1 drive, W forward, S reverse, R horn, Q exit",
	}


func request_horn() -> bool:
	if not _manual_driving or _train == null:
		return false
	var audio_manager := get_node_or_null("/root/WorldSpatialAudio")
	if audio_manager == null or not audio_manager.has_method("request_train_horn") \
			or not bool(audio_manager.call("request_train_horn", _train)):
		return false
	_horn_request_count += 1
	_status.text = "REAL TRAIN AIR HORN"
	return true


func select_train_mode(mode: String) -> bool:
	if mode != "drive" and mode != "ride" or _player == null or _train == null:
		return false
	if _manual_driving:
		if mode == "drive":
			return true
		if _drive_segment >= 0:
			_status.text = "STOP AT A STATION BEFORE SWITCHING TO PASSENGER MODE"
			return false
		_disembark_driver()
	elif _seated_passenger:
		if mode == "ride":
			return true
		if _passenger_in_motion:
			_status.text = "PASSENGER RIDE IN PROGRESS  •  SWITCH TO DRIVER AT THE NEXT STATION"
			return false
		leave_passenger_seat()
	elif _riding:
		return false
	elif _player.global_position.distance_to(get_train_deck_position()) > INTERACTION_RANGE:
		return false
	if mode == "drive":
		_player.global_position = get_driver_interaction_position()
		return board_as_driver()
	var closest_seat := 0
	var closest_distance := INF
	for seat_index in BENCH_SEATS.size():
		var distance := _player.global_position.distance_to(get_passenger_seat_position(seat_index))
		if distance < closest_distance:
			closest_distance = distance
			closest_seat = seat_index
	_player.global_position = get_passenger_seat_position(closest_seat)
	return sit_in_passenger_seat(closest_seat)


func sit_in_passenger_seat(seat_index: int) -> bool:
	if _player == null or _train == null or _riding \
			or seat_index < 0 or seat_index >= BENCH_SEATS.size():
		return false
	if _player.global_position.distance_to(_train.to_global(BENCH_SEATS[seat_index])) > SEAT_INTERACTION_RANGE:
		return false
	_seated_passenger = true
	_passenger_seat_index = seat_index
	_riding = true
	_player.call("set_input_enabled", false)
	_player.velocity = Vector3.ZERO
	_player.global_position = _train.to_global(BENCH_SEATS[seat_index])
	_begin_ride_camera(14.0)
	_status.text = "PASSENGER MODE  •  2 RIDE  •  1 DRIVE AT A STATION  •  Q STAND"
	call_deferred("_ride_seated_passenger_one_station")
	return true


func leave_passenger_seat() -> bool:
	if not _seated_passenger or _player == null:
		return false
	var seat_position := _train.to_global(BENCH_SEATS[_passenger_seat_index])
	_seated_passenger = false
	_passenger_in_motion = false
	_passenger_seat_index = -1
	_riding = false
	_player.global_position = seat_position + Vector3(0.0, 0.2, 2.2)
	_player.velocity = Vector3.ZERO
	_player.call("set_input_enabled", true)
	_end_ride_camera()
	_status.text = "CROWN LINE PASSENGER SEAT RELEASED"
	return true


func _ride_seated_passenger_one_station() -> void:
	if not _seated_passenger or _train == null:
		return
	var target := posmod(_current_station + 1, STATIONS.size())
	if not is_station_unlocked(target):
		_status.text = _locked_message(target)
		return
	_passenger_in_motion = true
	var segment_index := _current_station
	_status.text = "PASSENGER RIDE  •  %s → %s" % [
		STATIONS[_current_station].title, STATIONS[target].title]
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(progress: float) -> void:
		_set_train_progress(segment_index, progress), 0.0, 1.0, ride_duration)
	await tween.finished
	_current_station = target
	_train.position = STATIONS[_current_station].position
	_orient_train_at_station(_current_station)
	_passenger_in_motion = false
	if _player != null and _passenger_seat_index >= 0:
		_player.global_position = _train.to_global(BENCH_SEATS[_passenger_seat_index])
		_player.velocity = Vector3.ZERO
	_status.text = "DOCKED AT %s  •  Q STAND" % STATIONS[_current_station].title


func request_ride() -> bool:
	if _riding or _player == null:
		return false
	if _player.global_position.distance_to(_boarding_position(_current_station)) > INTERACTION_RANGE:
		return false
	return _try_depart()


# Optional guided travel remains available for story sequences that ask Milo to
# drive. Normal station interaction now boards the player as the driver.
func request_completed_world_ride() -> bool:
	if _riding or _player == null:
		return false
	if _player.global_position.distance_to(_boarding_position(_current_station)) > INTERACTION_RANGE:
		return false
	var target := posmod(_current_station + _direction, STATIONS.size())
	if not is_completed_station_unlocked(target):
		_status.text = "USE THE WORLD GATE FIRST  •  THE TRAIN REVISITS COMPLETED WORLDS"
		return false
	_ride_to(target)
	return true


func board_as_driver() -> bool:
	if _riding or _player == null:
		return false
	if _player.global_position.distance_to(get_driver_interaction_position()) > DRIVER_INTERACTION_RANGE:
		return false
	_riding = true
	_manual_driving = true
	_drive_segment = -1
	_drive_progress = 0.0
	_drive_motion_direction = 1
	_display_speed_kph = 0.0
	_train.position = STATIONS[_current_station].position
	_orient_train_at_station(_current_station)
	_player.call("set_input_enabled", false)
	_player.velocity = Vector3.ZERO
	_player.global_position = _train.to_global(DRIVER_SEAT)
	# Driving pulls the view furthest out: the whole train plus the track ahead.
	_begin_ride_camera(18.0)
	_status.text = "DRIVER MODE  •  W/S MOVE  •  R HORN  •  2 RIDE AT A STATION  •  Q EXIT"
	return true


func request_disembark() -> bool:
	if not _manual_driving or _drive_segment >= 0:
		return false
	_disembark_driver()
	return true


# Public so the runtime and focused tests use the exact same driving path.
# Positive throttle follows Gallery -> Mind -> Heart -> Creator -> Gallery;
# negative throttle reverses around the same closed Crown Line.
func drive_manual(throttle: float, delta: float) -> void:
	if not _manual_driving or _train == null:
		return
	var requested_direction := _drive_motion_direction
	if absf(throttle) >= 0.01:
		requested_direction = 1 if throttle > 0.0 else -1
	var changing_direction := requested_direction != _drive_motion_direction and _display_speed_kph > 0.5
	if not changing_direction and absf(throttle) >= 0.01:
		_drive_motion_direction = requested_direction
	var target_speed := 0.0 if changing_direction else absf(throttle) * DISPLAY_MAX_SPEED_KPH
	var speed_rate := DISPLAY_ACCELERATION_KPH_S if target_speed > _display_speed_kph \
		else DISPLAY_BRAKING_KPH_S
	_display_speed_kph = move_toward(_display_speed_kph, target_speed, speed_rate * maxf(delta, 0.0))
	if _display_speed_kph < 0.05:
		_display_speed_kph = 0.0
		if _player != null:
			_player.global_position = _train.to_global(DRIVER_SEAT)
		return
	var drive_direction := _drive_motion_direction
	if _drive_segment < 0:
		if not _begin_manual_segment(drive_direction):
			_display_speed_kph = 0.0
			return
	var curve := _curves[_drive_segment]
	var progress_delta := (_display_speed_kph / DISPLAY_MAX_SPEED_KPH) \
		* MANUAL_DRIVE_SPEED * maxf(delta, 0.0) \
		/ maxf(curve.get_baked_length(), 1.0)
	_drive_progress = clampf(_drive_progress + progress_delta * float(drive_direction), 0.0, 1.0)
	_set_train_progress(_drive_segment, _drive_progress)
	_status.text = "DRIVING  •  %03d KM/H  •  %s  •  W/S MOVE  •  R HORN" \
		% [roundi(_display_speed_kph), _segment_destination_name(drive_direction)]
	if is_equal_approx(_drive_progress, 0.0):
		_dock_manual_train(_drive_segment)
	elif is_equal_approx(_drive_progress, 1.0):
		_dock_manual_train(_drive_segment + 1)


func _begin_manual_segment(drive_direction: int) -> bool:
	var target := posmod(_current_station + drive_direction, STATIONS.size())
	if not is_station_unlocked(target):
		_status.text = _locked_message(target)
		return false
	_drive_segment = _current_station if drive_direction > 0 else target
	_drive_progress = 0.0 if drive_direction > 0 else 1.0
	return true


func _dock_manual_train(station_index: int) -> void:
	_current_station = posmod(station_index, STATIONS.size())
	_drive_segment = -1
	_display_speed_kph = 0.0
	_train.position = STATIONS[_current_station].position
	_orient_train_at_station(_current_station)
	if _player != null:
		_player.global_position = _train.to_global(DRIVER_SEAT)
		_player.velocity = Vector3.ZERO
	_status.text = "DOCKED AT %s  •  R HORN  •  Q EXIT  •  W/S KEEP DRIVING" % STATIONS[_current_station].title


func _segment_destination_name(drive_direction: int) -> String:
	if _drive_segment < 0:
		return STATIONS[_current_station].title
	var target := posmod(_drive_segment + 1, STATIONS.size()) if drive_direction > 0 else _drive_segment
	return STATIONS[target].title


func _disembark_driver() -> void:
	if not _manual_driving or _drive_segment >= 0:
		return
	_manual_driving = false
	_riding = false
	_display_speed_kph = 0.0
	if _player != null:
		_player.global_position = to_global(STATIONS[_current_station].position + Vector3(25.0, 2.0, 0.0))
		_player.velocity = Vector3.ZERO
		_player.call("set_input_enabled", true)
	_end_ride_camera()
	_status.text = "ARRIVED  •  Explore %s" % STATIONS[_current_station].title


func _boarding_position(station_index: int) -> Vector3:
	return to_global(STATIONS[station_index].position + BOARDING_OFFSET)


func station_unlocked_with(index: int, treasure_flags: Dictionary) -> bool:
	if index <= 1:
		return index >= 0
	if index == 2:
		return bool(treasure_flags.get("star_of_wisdom", false))
	if index == 3:
		return bool(treasure_flags.get("harmony_jewel", false))
	return false


func completed_station_unlocked_with(index: int, treasure_flags: Dictionary) -> bool:
	if index == 0:
		return true
	if index == 1:
		return bool(treasure_flags.get("star_of_wisdom", false))
	if index == 2:
		return bool(treasure_flags.get("harmony_jewel", false))
	if index == 3:
		return bool(treasure_flags.get("creators_light", false))
	return false


func completed_destination_indices_with(treasure_flags: Dictionary) -> PackedInt32Array:
	var destinations := PackedInt32Array()
	for index in STATIONS.size():
		if completed_station_unlocked_with(index, treasure_flags):
			destinations.append(index)
	return destinations


func is_completed_station_unlocked(index: int) -> bool:
	var journey := get_node_or_null("/root/JourneyState")
	var flags: Dictionary = {}
	if journey != null:
		flags = journey.get("treasures") as Dictionary
	return completed_station_unlocked_with(index, flags)


func is_station_unlocked(index: int) -> bool:
	var journey := get_node_or_null("/root/JourneyState")
	var flags: Dictionary = {}
	if journey != null:
		flags = journey.get("treasures") as Dictionary
	return station_unlocked_with(index, flags)


func _build_materials() -> void:
	_rail_material = ShaderMaterial.new()
	_rail_material.shader = Shader.new()
	_rail_material.shader.code = """
shader_type spatial;
render_mode cull_disabled;
void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * 0.85;
	ROUGHNESS = 0.28;
	METALLIC = 0.18;
}
"""
	_gold_material = _material(Color("f6cb67"), 0.42, Color("f3a936"), 1.2)
	_glass_material = _material(Color(0.18, 0.86, 0.97, 0.72), 0.20, Color("36dcff"), 1.7, true)
	_stone_material = _material(Color("d7d7e5"), 0.84)
	_nature_material = _material(Color("426f5b"), 0.88, Color("5fa978"), 0.18)
	_violet_material = _material(Color("8d62d1"), 0.32, Color("b477ff"), 1.45)
	_canopy_material = _material(Color(0.23, 0.48, 0.72, 0.76), 0.24,
		Color("48cce8"), 0.72, true)
	_dark_metal_material = _material(Color("263552"), 0.42, Color("283f65"), 0.20)


func _build_route() -> void:
	var routes := Node3D.new()
	routes.name = "CrownLineRoute"
	add_child(routes)
	for index in STATIONS.size():
		var curve := Curve3D.new()
		# Each station connection has a true straight departure, a broad cubic
		# sightseeing bend, and a true straight arrival. This gives the complete
		# train a stable platform alignment instead of beginning a turn at the dock.
		var start: Vector3 = STATIONS[index].position
		var next_index := (index + 1) % STATIONS.size()
		var finish: Vector3 = STATIONS[next_index].position
		var departure_control: Vector3 = CONTROL_POINTS[index][0]
		# Use the destination's established departure heading for arrival too. The
		# two neighbouring segments therefore form one straight line through the
		# platform rather than meeting as an angled joint beneath the train.
		var arrival_control: Vector3 = CONTROL_POINTS[next_index][0]
		var departure_direction: Vector3 = (departure_control - start).normalized()
		var arrival_direction: Vector3 = (arrival_control - finish).normalized()
		var endpoint_distance := start.distance_to(finish)
		var straight_length := minf(STATION_STRAIGHT_LENGTH, endpoint_distance * 0.16)
		var departure_end: Vector3 = start + departure_direction * straight_length
		var arrival_start: Vector3 = finish - arrival_direction * straight_length
		# Long middle handles are intentional: several legacy station headings face
		# away from the direct chord, so a short cubic would produce a toy-like
		# hairpin. The broad arc gives the articulated coaches room to follow.
		var curve_handle_length := minf(1600.0, endpoint_distance * 0.35)
		curve.add_point(start, Vector3.ZERO,
			departure_direction * straight_length / 3.0)
		curve.add_point(departure_end,
			-departure_direction * straight_length / 3.0,
			departure_direction * curve_handle_length)
		curve.add_point(arrival_start,
			-arrival_direction * curve_handle_length,
			arrival_direction * straight_length / 3.0)
		curve.add_point(finish,
			-arrival_direction * straight_length / 3.0, Vector3.ZERO)
		curve.bake_interval = 12.0
		_curves.append(curve)
		var segment_root := Node3D.new()
		segment_root.name = "StorySegment_%d_%s_to_%s" % [index + 1, STATIONS[index].id, STATIONS[next_index].id]
		routes.add_child(segment_root)
		_build_track_mesh(segment_root, curve, index)


func _build_track_mesh(parent: Node3D, curve: Curve3D, segment_index: int) -> void:
	var length := curve.get_baked_length()
	# Sweep one mesh along the complete baked curve. The former 40 m boxes left a
	# visible cut at every sample and ignored vertical pitch, making long bends
	# look like disconnected straight bars. Ten-metre rings form one smooth beam
	# with one exact collision surface for the whole station-to-station span.
	var sample_count := maxi(2, int(ceil(length / 10.0)))
	var beam_points := PackedVector3Array()
	var ribbon_points := PackedVector3Array()
	for sample_index in sample_count + 1:
		var distance := length * float(sample_index) / float(sample_count)
		var centre := curve.sample_baked(distance) - Vector3.UP * 1.4
		beam_points.append(centre)
		ribbon_points.append(centre + Vector3.UP * 0.87)
	_add_continuous_curve_prism(parent, "CenterMonorailBeam", beam_points,
		3.2, 1.6, _rail_material, true, true)
	_add_continuous_curve_prism(parent, "CrownLineEnergyRibbon", ribbon_points,
		0.92, 0.14, _gold_material, false)
	# Only the approach and departure beside Mind Spark receive the circuit-garden
	# guide rails. The rest of the kingdom loop keeps its established appearance.
	if segment_index == 0 or segment_index == 1:
		_build_mind_spark_railway_details(parent, curve, segment_index)
	parent.set_meta("continuous_track", true)
	parent.set_meta("visual_mesh_pieces", 1)
	parent.set_meta("sample_spacing_m", length / float(sample_count))
	parent.set_meta("route_length_m", length)


func _build_mind_spark_railway_details(parent: Node3D, curve: Curve3D,
		segment_index: int) -> void:
	var length := curve.get_baked_length()
	var detail_length := minf(260.0, length * 0.22)
	var start_distance := length - detail_length if segment_index == 0 else 0.0
	var finish_distance := length if segment_index == 0 else detail_length
	var left_points := PackedVector3Array()
	var right_points := PackedVector3Array()
	const SAMPLE_COUNT := 30
	for sample_index in SAMPLE_COUNT + 1:
		var distance := lerpf(start_distance, finish_distance,
			float(sample_index) / float(SAMPLE_COUNT))
		var previous := curve.sample_baked(maxf(0.0, distance - 2.0))
		var following := curve.sample_baked(minf(length, distance + 2.0))
		var forward := (following - previous).normalized()
		var side := Vector3.UP.cross(forward).normalized()
		var centre := curve.sample_baked(distance) - Vector3.UP * 0.48
		left_points.append(centre - side * 2.15)
		right_points.append(centre + side * 2.15)
	var prefix := "MindSparkIncoming" if segment_index == 0 else "MindSparkOutgoing"
	_add_continuous_curve_prism(parent, "%sCircuitGuideLeft" % prefix,
		left_points, 0.24, 0.16, _glass_material, false)
	_add_continuous_curve_prism(parent, "%sCircuitGuideRight" % prefix,
		right_points, 0.24, 0.16, _glass_material, false)
	parent.set_meta("mind_spark_rail_upgrade", true)


func _add_continuous_curve_prism(parent: Node3D, node_name: String,
		points: PackedVector3Array, width: float, height: float,
		material: Material, collision: bool, rainbow_colours: bool = false) -> MeshInstance3D:
	var rings: Array[PackedVector3Array] = []
	for index in points.size():
		var previous := points[maxi(0, index - 1)]
		var following := points[mini(points.size() - 1, index + 1)]
		var forward := (following - previous).normalized()
		var side := Vector3.UP.cross(forward).normalized()
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT
		var local_up := forward.cross(side).normalized()
		var centre := points[index]
		rings.append(PackedVector3Array([
			centre - side * width * 0.5 + local_up * height * 0.5,
			centre + side * width * 0.5 + local_up * height * 0.5,
			centre + side * width * 0.5 - local_up * height * 0.5,
			centre - side * width * 0.5 - local_up * height * 0.5,
		]))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spectrum := [
		Color("ff426d"), Color("ff9a45"), Color("ffe95a"), Color("55ef87"),
		Color("42e9f5"), Color("4c78ff"), Color("b85cff")]
	for ring_index in rings.size() - 1:
		var colour_a: Color = spectrum[ring_index % spectrum.size()] if rainbow_colours else Color.WHITE
		var colour_b: Color = spectrum[(ring_index + 1) % spectrum.size()] if rainbow_colours else Color.WHITE
		for edge_index in 4:
			var next_edge := (edge_index + 1) % 4
			_add_surface_coloured_quad(surface,
				rings[ring_index][edge_index], rings[ring_index + 1][edge_index],
				rings[ring_index + 1][next_edge], rings[ring_index][next_edge],
				colour_a, colour_b)
	_add_surface_coloured_quad(surface, rings[0][3], rings[0][2], rings[0][1], rings[0][0],
		spectrum[0] if rainbow_colours else Color.WHITE,
		spectrum[0] if rainbow_colours else Color.WHITE)
	var last_ring := rings.size() - 1
	var last_colour: Color = spectrum[last_ring % spectrum.size()] if rainbow_colours else Color.WHITE
	_add_surface_coloured_quad(surface, rings[last_ring][0], rings[last_ring][1],
		rings[last_ring][2], rings[last_ring][3], last_colour, last_colour)
	surface.generate_normals()
	var mesh := surface.commit()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.name = "%sCollision" % node_name
		var shape_node := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(mesh.get_faces())
		shape_node.shape = shape
		body.add_child(shape_node)
		var physics_material := PhysicsMaterial.new()
		physics_material.friction = 0.92
		physics_material.bounce = 0.0
		body.physics_material_override = physics_material
		parent.add_child(body)
	return instance


func _add_surface_coloured_quad(surface: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, colour_a: Color, colour_b: Color) -> void:
	for vertex_data in [[a, colour_a], [b, colour_b], [c, colour_b],
			[a, colour_a], [c, colour_b], [d, colour_a]]:
		surface.set_color(vertex_data[1])
		surface.add_vertex(vertex_data[0])


func _add_surface_quad(surface: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3) -> void:
	for vertex in [a, b, c, a, c, d]:
		surface.set_color(Color.WHITE)
		surface.add_vertex(vertex)


func _build_stations() -> void:
	var stations_root := Node3D.new()
	stations_root.name = "StoryStations"
	add_child(stations_root)
	for index in STATIONS.size():
		var info: Dictionary = STATIONS[index]
		var station := Node3D.new()
		station.name = "Station_%02d_%s" % [index + 1, info.id]
		station.position = info.position
		stations_root.add_child(station)
		_station_nodes.append(station)
		_add_cylinder(station, "WalkablePlatform", Vector3(0.0, -3.2, 0.0), 38.0, 4.0, _stone_material, true)
		_build_floating_dock_structure(station)
		if String(info.id) == "mind":
			_build_mind_spark_station_upgrade(station)
		else:
			_build_bio_magitech_pavilion(station)
		var landing_local: Vector3 = info.landing - info.position
		var dock_sign := signf(landing_local.x)
		if is_zero_approx(dock_sign):
			dock_sign = -1.0
		_build_world_access_bridge(station, landing_local, dock_sign)
		_add_cylinder(station, "DestinationWheel", Vector3(0.0, -0.6, 0.0), 17.0, 1.0, _glass_material, false)
		# The access stair is built by the skybridge function on the same east-west
		# axis as the world bridge. A former north-facing ramp left a gap at this
		# exact dock edge even though both pieces existed visually.
		# Start the lane clear of the stair head. At the full 15 m width its west
		# edge reached x=-7.5, the exact top step, so the lane body bit ~1.1 m
		# into the flight and the player caught on it stepping off the stairs.
		const BOARDING_LANE_WIDTH := 12.8
		_add_box(station, "BoardingLane",
			Vector3(-dock_sign * (15.0 - BOARDING_LANE_WIDTH) * 0.5, 0.8, 11.0),
			Vector3(BOARDING_LANE_WIDTH, 0.6, 28.0), _glass_material, true)
		_build_platform_guardrails(station, dock_sign)
		var board_label := Label3D.new()
		board_label.name = "BoardTrainSign"
		board_label.text = "WALK ONTO THE CROWN LINE\nQ BY A BENCH: RIDE  ✦  Q IN CAB: DRIVE\nW FORWARD  ✦  S REVERSE"
		board_label.position = Vector3(0.0, 7.0, 24.0)
		board_label.font_size = 28
		board_label.outline_size = 8
		board_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		board_label.no_depth_test = false
		station.add_child(board_label)
		for spoke in 8:
			var angle := TAU * float(spoke) / 8.0
			_add_segment_box(station, "WheelSpoke", Vector3(0.0, 0.15, 0.0),
				Vector3(cos(angle) * 14.0, 0.15, sin(angle) * 14.0), Vector2(0.55, 0.55), _gold_material)
		var beacon := OmniLight3D.new()
		beacon.name = "UnlockBeacon"
		beacon.position = Vector3(0.0, 13.0, 0.0)
		beacon.omni_range = 42.0
		beacon.light_energy = 5.0
		station.add_child(beacon)
		var label := Label3D.new()
		label.name = "StationSign"
		label.text = "%02d  %s\n%s" % [index + 1, info.title, info.subtitle]
		label.position = Vector3(0.0, 20.0, 0.0)
		label.font_size = 46
		label.outline_size = 10
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = false
		station.add_child(label)


func _build_mind_spark_station_upgrade(station: Node3D) -> void:
	var upgrade := Node3D.new()
	upgrade.name = "MindSparkStationUpgrade"
	upgrade.set_meta("zone_scope", "mind_spark_only")
	upgrade.set_meta("walk_around_train", true)
	upgrade.set_meta("cab_q_interaction", true)
	station.add_child(upgrade)
	_build_mind_spark_floating_ground(upgrade)

	# A luminous circular promenade matches the reference while the complete
	# collision-enabled platform beneath it lets the player circle either end of
	# the parked train without stepping onto the guideway.
	var promenade := Node3D.new()
	promenade.name = "CircularBoardingPromenade"
	upgrade.add_child(promenade)
	_add_torus(promenade, "OuterCyanCircuitRing", Vector3(0.0, -0.92, 0.0),
		32.4, 33.1, _glass_material)
	_add_torus(promenade, "InnerSandGuideRing", Vector3(0.0, 0.22, 0.0),
		17.2, 17.7, _gold_material)
	for marker_index in 16:
		var angle := TAU * float(marker_index) / 16.0
		var inner := Vector3(cos(angle) * 27.0, 0.24, sin(angle) * 27.0)
		var outer := Vector3(cos(angle) * 31.7, 0.24, sin(angle) * 31.7)
		_add_segment_box(promenade, "CircuitWalkMarker_%02d" % marker_index,
			inner, outer, Vector2(0.28, 0.16), _glass_material)

	# Restore the earlier split-wing roof the player selected: twelve large cyan
	# solar-glass leaves, sand-gold outlines, green branch columns and an open
	# centre above the train. All pieces remain visual-only and above clearance.
	var crystal_tree := Node3D.new()
	crystal_tree.name = "MindCrystalTreeCanopy"
	upgrade.add_child(crystal_tree)
	_add_cylinder(crystal_tree, "CyanKnowledgeMast", Vector3(0.0, 7.0, 0.0),
		0.62, 14.0, _glass_material, false, 8)
	_add_cylinder(crystal_tree, "VioletMindCrystal", Vector3(0.0, 15.2, 0.0),
		1.35, 5.0, _violet_material, false, 6)
	_add_torus(crystal_tree, "RestoredCanopyEnergyRing", Vector3(0.0, 12.1, 0.0),
		8.35, 8.8, _gold_material)
	var restored_petal_mesh := _leaf_petal_mesh(22.0, 10.0, 0.48)
	for side in [-1.0, 1.0]:
		for petal_index in 6:
			var ratio := float(petal_index) / 5.0
			var angle := (0.0 if side > 0 else PI) \
				+ lerpf(-PI * 0.25, PI * 0.25, ratio)
			var outward := Vector3(cos(angle), 0.0, -sin(angle))
			var tangent := Vector3(sin(angle), 0.0, cos(angle))
			var centre := outward * 22.0 \
				+ Vector3.UP * (12.8 + sin(ratio * PI) * 0.6)
			var petal := MeshInstance3D.new()
			petal.name = "RestoredSolarGlassPetal_%s_%02d" % [
				"L" if side < 0 else "R", petal_index]
			petal.mesh = restored_petal_mesh
			petal.position = centre
			petal.rotation.y = angle
			petal.material_override = _canopy_material
			crystal_tree.add_child(petal)
			var root := centre - outward * 11.0
			var shoulder_a := centre - outward * 1.8 - tangent * 5.0
			var tip := centre + outward * 11.0
			var shoulder_b := centre - outward * 1.8 + tangent * 5.0
			var edge_points := [root, shoulder_a, tip, shoulder_b, root]
			for edge_index in 4:
				_add_segment_box(crystal_tree,
					"RestoredGoldenPetalEdge_%s_%02d_%02d" % [
						"L" if side < 0 else "R", petal_index, edge_index],
					edge_points[edge_index] + Vector3.UP * 0.30,
					edge_points[edge_index + 1] + Vector3.UP * 0.30,
					Vector2(0.26, 0.26), _gold_material)
			_add_segment_box(crystal_tree,
				"RestoredGoldenPetalVein_%s_%02d" % [
					"L" if side < 0 else "R", petal_index],
				root + Vector3.UP * 0.32, tip + Vector3.UP * 0.32,
				Vector2(0.20, 0.20), _gold_material)
	var restored_supports := Node3D.new()
	restored_supports.name = "RestoredBranchingSupportColumns"
	upgrade.add_child(restored_supports)
	for side in [-1.0, 1.0]:
		for support_index in 3:
			var z := -14.0 + float(support_index) * 14.0
			var x := float(side) * 19.0
			_add_cylinder(restored_supports,
				"RestoredLivingColumn_%s_%02d" % [
					"L" if side < 0 else "R", support_index],
				Vector3(x, 5.2, z), 0.75, 10.4, _nature_material, false, 8)
			_add_cylinder(restored_supports,
				"RestoredEngineeringCollar_%s_%02d" % [
					"L" if side < 0 else "R", support_index],
				Vector3(x, 9.2, z), 1.15, 0.65, _gold_material, false, 12)

	# Tall circuit monoliths create the Mind Spark skyline. They are visual-only
	# and sit on the outer rim, so they cannot trap the player or clip the train.
	var monoliths := Node3D.new()
	monoliths.name = "CircuitMonolithGarden"
	upgrade.add_child(monoliths)
	var monolith_angles := [-2.55, -2.12, -1.66, -1.18, -0.64, 0.66, 1.18, 1.66, 2.12, 2.55]
	for monolith_index in monolith_angles.size():
		var angle: float = monolith_angles[monolith_index]
		var height := 8.0 + float(monolith_index % 3) * 2.3
		var position_value := Vector3(cos(angle) * 31.0, height * 0.5,
			sin(angle) * 31.0)
		_add_box(monoliths, "CircuitMonolith_%02d" % monolith_index,
			position_value, Vector3(2.0, height, 0.55), _dark_metal_material,
			false, 0.0, -angle + PI * 0.5)
		_add_box(monoliths, "CyanRunePanel_%02d" % monolith_index,
			position_value + Vector3.UP * 0.2, Vector3(1.15, height * 0.62, 0.68),
			_glass_material, false, 0.0, -angle + PI * 0.5)
	for rail_index in 12:
		var angle_a := TAU * float(rail_index) / 12.0
		var angle_b := TAU * float(rail_index + 1) / 12.0
		_add_segment_box(upgrade, "SandSafetyRail_%02d" % rail_index,
			Vector3(cos(angle_a) * 35.0, 2.2, sin(angle_a) * 35.0),
			Vector3(cos(angle_b) * 35.0, 2.2, sin(angle_b) * 35.0),
			Vector2(0.25, 0.25), _gold_material)


func _build_mind_spark_floating_ground(upgrade: Node3D) -> void:
	var ground := Node3D.new()
	ground.name = "MindSparkFloatingGround"
	ground.set_meta("walkable_circuit_floor", true)
	ground.set_meta("faceted_suspended_foundation", true)
	upgrade.add_child(ground)
	# Replace the generic drum/roots at this station only; the dedicated faceted
	# island below supplies the complete visible load-bearing silhouette.
	var station := upgrade.get_parent() as Node3D
	var generic_foundation := station.get_node_or_null("FloatingDockStructure") as Node3D
	if generic_foundation != null:
		generic_foundation.visible = false
	var floor_blue := _material(Color("789fbd"), 0.70, Color("6adcf2"), 0.18)
	var floor_light := _material(Color("b9d4e6"), 0.64, Color("a7eeff"), 0.12)

	# Layered circular deck based on the supplied top/front orthographic views.
	_add_cylinder(ground, "WalkableCircuitFloor", Vector3(0.0, -1.02, 0.0),
		37.2, 0.30, floor_blue, false, 32)
	_add_torus(ground, "SegmentedOuterStoneRim", Vector3(0.0, -0.82, 0.0),
		35.8, 37.8, floor_light)
	_add_cylinder(ground, "CentralCircuitDisc", Vector3(0.0, -0.78, 0.0),
		7.2, 0.18, floor_blue, false, 32)
	_add_torus(ground, "CentralCircuitHalo", Vector3(0.0, -0.62, 0.0),
		4.2, 4.7, _glass_material)
	_add_torus(ground, "InnerCircuitRing", Vector3(0.0, -0.70, 0.0),
		13.8, 14.25, _glass_material)
	_add_torus(ground, "OuterCircuitRing", Vector3(0.0, -0.70, 0.0),
		27.4, 27.85, _glass_material)
	for circuit_index in 16:
		var angle := TAU * float(circuit_index) / 16.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		_add_segment_box(ground, "RadialCircuit_%02d" % circuit_index,
			direction * 7.5 + Vector3.UP * -0.58,
			direction * 35.6 + Vector3.UP * -0.58,
			Vector2(0.22, 0.10), _glass_material)
	# The three brighter axial conduits reproduce the strong parallel path in the
	# reference without adding collision or narrowing the boarding route.
	for lane_index in 3:
		var lane_x := -1.35 + float(lane_index) * 1.35
		_add_segment_box(ground, "StationAxisConduit_%02d" % lane_index,
			Vector3(lane_x, -0.50, -36.2), Vector3(lane_x, -0.50, 36.2),
			Vector2(0.24, 0.11), floor_light)
	for panel_index in 24:
		var angle_a := TAU * float(panel_index) / 24.0
		var angle_b := TAU * float(panel_index + 1) / 24.0
		_add_segment_box(ground, "OuterDeckPanelSeam_%02d" % panel_index,
			Vector3(cos(angle_a) * 36.8, -0.52, sin(angle_a) * 36.8),
			Vector3(cos(angle_b) * 36.8, -0.52, sin(angle_b) * 36.8),
			Vector2(0.20, 0.10), floor_light)

	# One authored triangular mesh now creates the reference's continuous rocky
	# taper. Alternating ring rotations produce readable diamond facets instead
	# of the previous stack of smooth-sided cylinders.
	_add_faceted_floating_island(ground)
	_build_island_power_crystal(ground)
	for crystal_index in 4:
		var angle := PI * 0.25 + TAU * float(crystal_index) / 4.0
		_build_rim_power_crystal(ground, crystal_index,
			Vector3(cos(angle) * 30.5, -13.0, sin(angle) * 30.5))


func _build_island_power_crystal(ground: Node3D) -> void:
	var reactor := Node3D.new()
	reactor.name = "AetherCrystalReactor"
	reactor.set_meta("power_sources", ["magic", "technology", "nature"])
	reactor.set_meta("visual_effect", "floating_pulse")
	ground.add_child(reactor)
	# Layered facets make the cyan crystal readable from a distance. The bright
	# inner shard is visible through the translucent outer shell.
	_add_tapered_cylinder(reactor, "CentralHangingCrystal",
		Vector3(0.0, -29.0, 0.0), 4.4, 0.0, 14.5, _glass_material, 8)
	var crystal_core_material := _material(Color("75eaf4"), 0.18,
		Color("43dce9"), 1.25)
	var life_power_material := _material(Color("67d77c"), 0.46,
		Color("75ed8b"), 1.15)
	_add_tapered_cylinder(reactor, "LuminousCrystalCore",
		Vector3(0.0, -28.7, 0.0), 1.55, 0.0, 10.4,
		crystal_core_material, 8)
	_add_tapered_cylinder(reactor, "CrystalCrown",
		Vector3(0.0, -21.5, 0.0), 0.0, 3.25, 4.0,
		crystal_core_material, 8)
	# Colored edge ribs expose the eight crystal facets even when the inner glow
	# is bright. Alternating violet and green makes the magic/nature channels
	# visibly distinct from the cyan technology shell.
	for facet_index in 8:
		var facet_angle := TAU * float(facet_index) / 8.0
		var shoulder := Vector3(cos(facet_angle) * 4.35, -21.75,
			sin(facet_angle) * 4.35)
		_add_walkway_between(reactor, "CrystalFacetRib_%02d" % facet_index,
			shoulder, Vector3(0.0, -36.25, 0.0), 0.16, 0.13,
			_violet_material if facet_index % 2 == 0 else life_power_material, false)

	# TECHNOLOGY: three independently tilted gyroscopic rings, circuit spokes,
	# and four stabilizer pylons visibly hold the core in a magnetic field.
	var ring_specs := [
		["TechnologyGyroRingA", Vector3(0.0, -25.0, 0.0), 5.4, 6.05, Vector3(8.0, 0.0, 0.0)],
		["TechnologyGyroRingB", Vector3(0.0, -29.2, 0.0), 6.7, 7.35, Vector3(-12.0, 0.0, 18.0)],
		["TechnologyGyroRingC", Vector3(0.0, -33.0, 0.0), 5.1, 5.72, Vector3(15.0, 0.0, -14.0)],
	]
	for ring_spec in ring_specs:
		_add_torus(reactor, ring_spec[0], ring_spec[1], ring_spec[2],
			ring_spec[3], _glass_material, ring_spec[4])
		_island_power_rotors.append(reactor.get_node(ring_spec[0]) as Node3D)
	for spoke_index in 8:
		var angle := TAU * float(spoke_index) / 8.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		_add_segment_box(reactor, "CircuitSpoke_%02d" % spoke_index,
			direction * 4.2 + Vector3.UP * -25.0,
			direction * 8.5 + Vector3.UP * -25.0,
			Vector2(0.22, 0.16), _glass_material)
	for pylon_index in 4:
		var angle := TAU * float(pylon_index) / 4.0 + PI * 0.25
		var pylon_position := Vector3(cos(angle) * 8.5, -25.0, sin(angle) * 8.5)
		_add_cylinder(reactor, "FieldStabilizer_%02d" % pylon_index,
			pylon_position + Vector3.DOWN * 0.55, 0.28, 2.6,
			_dark_metal_material, false, 6)
		_add_tapered_cylinder(reactor, "StabilizerEmitter_%02d" % pylon_index,
			pylon_position + Vector3.UP * 1.25, 0.62, 0.0, 1.3,
			_glass_material, 6)

	# MAGIC: violet orbit and luminous motes describe energy moving around the
	# machine without relying on text or a numerical display.
	_add_torus(reactor, "VioletAetherOrbit", Vector3(0.0, -28.5, 0.0),
		8.2, 8.55, _violet_material, Vector3(32.0, 0.0, 18.0))
	var magic_orbit := reactor.get_node("VioletAetherOrbit") as Node3D
	_island_power_rotors.append(magic_orbit)
	var motes := Node3D.new()
	motes.name = "OrbitingAetherMotes"
	reactor.add_child(motes)
	_island_power_rotors.append(motes)
	for mote_index in 18:
		var progress := float(mote_index) / 18.0
		var angle := TAU * progress
		var mote := MeshInstance3D.new()
		mote.name = "AetherMote_%02d" % mote_index
		var mote_mesh := SphereMesh.new()
		mote_mesh.radius = 0.23 + float(mote_index % 3) * 0.08
		mote_mesh.height = mote_mesh.radius * 2.0
		mote_mesh.radial_segments = 8
		mote_mesh.rings = 4
		mote.mesh = mote_mesh
		mote.position = Vector3(cos(angle) * (7.0 + sin(angle * 3.0)),
			-28.0 + sin(angle * 2.0) * 4.5, sin(angle) * (7.0 + sin(angle * 3.0)))
		mote.material_override = [_glass_material, _violet_material,
			_nature_material][mote_index % 3]
		motes.add_child(mote)

	# NATURE: eight leaf-shaped field collectors cradle the crystal and visually
	# feed green life energy into the technology ring.
	var nature_crown := Node3D.new()
	nature_crown.name = "NatureEnergyCrown"
	reactor.add_child(nature_crown)
	_add_torus(nature_crown, "NatureLifeRing", Vector3(0.0, -23.9, 0.0),
		5.5, 5.92, life_power_material, Vector3(-8.0, 0.0, 6.0))
	_island_power_rotors.append(nature_crown.get_node("NatureLifeRing") as Node3D)
	for leaf_index in 8:
		var angle := TAU * float(leaf_index) / 8.0
		var leaf := MeshInstance3D.new()
		leaf.name = "PowerLeaf_%02d" % leaf_index
		leaf.mesh = _leaf_petal_mesh(6.2, 2.4, 0.32)
		leaf.position = Vector3(cos(angle) * 5.6, -24.2, sin(angle) * 5.6)
		leaf.rotation = Vector3(deg_to_rad(-34.0), -angle, deg_to_rad(10.0))
		leaf.material_override = life_power_material
		nature_crown.add_child(leaf)
		_add_segment_box(nature_crown, "LifeConduit_%02d" % leaf_index,
			Vector3(cos(angle) * 7.6, -24.2, sin(angle) * 7.6),
			Vector3(cos(angle) * 2.7, -25.0, sin(angle) * 2.7),
			Vector2(0.20, 0.14), life_power_material)

	var central_light := OmniLight3D.new()
	central_light.name = "AetherPulseLight"
	central_light.position = Vector3(0.0, -28.0, 0.0)
	central_light.light_color = Color("66f3ff")
	central_light.light_energy = 3.8
	central_light.omni_range = 32.0
	reactor.add_child(central_light)
	_island_power_lights.append(central_light)


func _build_rim_power_crystal(ground: Node3D, crystal_index: int,
		position_value: Vector3) -> void:
	var reactor := Node3D.new()
	reactor.name = "RimPowerCrystal_%02d" % crystal_index
	reactor.position = position_value
	reactor.set_meta("power_sources", ["magic", "technology", "nature"])
	ground.add_child(reactor)
	var rim_core_material := _material(Color("79e8f4"), 0.20,
		Color("4bddea"), 1.0)
	var rim_life_material := _material(Color("70dc82"), 0.48,
		Color("78ed8e"), 0.9)
	_add_tapered_cylinder(reactor, "RimHangingCrystal", Vector3.ZERO,
		2.15, 0.0, 11.5, _glass_material, 6)
	_add_tapered_cylinder(reactor, "RimLuminousCore", Vector3(0.0, 0.1, 0.0),
		0.82, 0.0, 8.2, rim_core_material, 6)
	for facet_index in 6:
		var facet_angle := TAU * float(facet_index) / 6.0
		_add_walkway_between(reactor, "RimFacetRib_%02d" % facet_index,
			Vector3(cos(facet_angle) * 2.1, 5.65, sin(facet_angle) * 2.1),
			Vector3(0.0, -5.75, 0.0), 0.11, 0.09,
			_violet_material if facet_index % 2 == 0 else rim_life_material, false)

	# Compact magnetic rings and a tilted magic orbit repeat the central reactor
	# language at a smaller scale, so all four edge crystals visibly contribute.
	_add_torus(reactor, "RimTechnologyRingUpper", Vector3(0.0, 1.2, 0.0),
		2.7, 3.05, _glass_material, Vector3(8.0, 0.0, -6.0))
	_add_torus(reactor, "RimTechnologyRingLower", Vector3(0.0, -2.7, 0.0),
		3.25, 3.58, _glass_material, Vector3(-10.0, 0.0, 8.0))
	_add_torus(reactor, "RimMagicOrbit", Vector3(0.0, -0.9, 0.0),
		3.8, 4.08, _violet_material, Vector3(28.0, 0.0, 18.0))
	for ring_name in ["RimTechnologyRingUpper", "RimTechnologyRingLower", "RimMagicOrbit"]:
		_island_power_rotors.append(reactor.get_node(ring_name) as Node3D)

	var nature_crown := Node3D.new()
	nature_crown.name = "RimNatureCrown"
	reactor.add_child(nature_crown)
	_add_torus(nature_crown, "RimLifeRing", Vector3(0.0, 3.9, 0.0),
		2.45, 2.75, rim_life_material, Vector3(-10.0, 0.0, 5.0))
	_island_power_rotors.append(nature_crown.get_node("RimLifeRing") as Node3D)
	for leaf_index in 4:
		var leaf_angle := TAU * float(leaf_index) / 4.0 + PI * 0.25
		var leaf := MeshInstance3D.new()
		leaf.name = "RimPowerLeaf_%02d" % leaf_index
		leaf.mesh = _leaf_petal_mesh(3.4, 1.35, 0.22)
		leaf.position = Vector3(cos(leaf_angle) * 2.8, 3.7,
			sin(leaf_angle) * 2.8)
		leaf.rotation = Vector3(deg_to_rad(-30.0), -leaf_angle, deg_to_rad(8.0))
		leaf.material_override = rim_life_material
		nature_crown.add_child(leaf)

	var motes := Node3D.new()
	motes.name = "RimAetherMotes"
	reactor.add_child(motes)
	_island_power_rotors.append(motes)
	for mote_index in 6:
		var mote_angle := TAU * float(mote_index) / 6.0
		var mote := MeshInstance3D.new()
		mote.name = "RimAetherMote_%02d" % mote_index
		var mote_mesh := SphereMesh.new()
		mote_mesh.radius = 0.18
		mote_mesh.height = 0.36
		mote_mesh.radial_segments = 6
		mote_mesh.rings = 3
		mote.mesh = mote_mesh
		mote.position = Vector3(cos(mote_angle) * 4.25,
			sin(mote_angle * 2.0) * 2.2, sin(mote_angle) * 4.25)
		mote.material_override = [_glass_material, _violet_material,
			rim_life_material][mote_index % 3]
		motes.add_child(mote)

	var pulse_light := OmniLight3D.new()
	pulse_light.name = "RimPulseLight"
	pulse_light.position = Vector3(0.0, -0.5, 0.0)
	pulse_light.light_color = [Color("6bf4ff"), Color("b77cff"),
		Color("78ed8e"), Color("72dfff")][crystal_index]
	pulse_light.light_energy = 2.2
	pulse_light.omni_range = 13.0
	reactor.add_child(pulse_light)
	_island_power_lights.append(pulse_light)


func _update_island_power_effect(delta: float) -> void:
	if _island_power_rotors.is_empty():
		return
	for rotor_index in _island_power_rotors.size():
		var rotor := _island_power_rotors[rotor_index]
		if is_instance_valid(rotor):
			var direction := 1.0 if rotor_index % 2 == 0 else -1.0
			rotor.rotate_y(delta * direction * (0.22 + float(rotor_index) * 0.045))
	for light_index in _island_power_lights.size():
		var power_light := _island_power_lights[light_index]
		if is_instance_valid(power_light):
			power_light.light_energy = 2.6 + float(light_index == 0) * 0.9 \
				+ sin(_mechanism_time * (2.1 + float(light_index) * 0.17)) * 0.7


func _build_floating_dock_structure(station: Node3D) -> void:
	var structure := Node3D.new()
	structure.name = "FloatingDockStructure"
	station.add_child(structure)
	_add_cylinder(structure, "SuspendedFoundation", Vector3(0, -8.0, 0), 32.0, 10.0,
		_stone_material, false, 16)
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var anchor := MeshInstance3D.new()
		anchor.name = "AetherAnchor_%02d" % index
		var mesh := CylinderMesh.new()
		mesh.top_radius = 3.6
		mesh.bottom_radius = 0.35
		mesh.height = 15.0
		mesh.radial_segments = 6
		anchor.mesh = mesh
		anchor.position = Vector3(cos(angle) * 22.0, -18.0, sin(angle) * 22.0)
		anchor.material_override = _glass_material
		structure.add_child(anchor)
	# Living roots make the load path legible without adding collision beneath
	# the playable deck. They connect the platform rim to the crystal foundation.
	for side in [-1.0, 1.0]:
		for rib_index in 3:
			var z := -13.0 + float(rib_index) * 13.0
			_add_walkway_between(structure, "LivingRootRib_%s_%02d" % ["L" if side < 0 else "R", rib_index],
				Vector3(float(side) * 27.0, -4.0, z),
				Vector3(float(side) * 8.0, -16.0, z * 0.45), 1.0, 1.0, _nature_material, false)


func _build_bio_magitech_pavilion(station: Node3D) -> void:
	var pavilion := Node3D.new()
	pavilion.name = "BioMagitechPavilion"
	station.add_child(pavilion)
	var canopy := Node3D.new()
	canopy.name = "LivingCrystalCanopy"
	pavilion.add_child(canopy)
	var petal_mesh := _leaf_petal_mesh(22.0, 10.0, 0.48)
	# Six authored leaf prisms on each side form a radial flower crown while
	# preserving the open central slot above the monorail and moving train.
	for side in [-1.0, 1.0]:
		for petal_index in 6:
			var ratio := float(petal_index) / 5.0
			var angle := (0.0 if side > 0 else PI) + lerpf(-PI * 0.25, PI * 0.25, ratio)
			var outward := Vector3(cos(angle), 0.0, -sin(angle))
			var tangent := Vector3(sin(angle), 0.0, cos(angle))
			var centre := outward * 22.0 + Vector3.UP * (12.8 + sin(ratio * PI) * 0.6)
			var petal := MeshInstance3D.new()
			petal.name = "SolarGlassPetal_%s_%02d" % ["L" if side < 0 else "R", petal_index]
			petal.mesh = petal_mesh
			petal.position = centre
			petal.rotation.y = angle
			petal.material_override = _canopy_material
			canopy.add_child(petal)
			var root := centre - outward * 11.0
			var shoulder_a := centre - outward * 1.8 - tangent * 5.0
			var tip := centre + outward * 11.0
			var shoulder_b := centre - outward * 1.8 + tangent * 5.0
			var edge_points := [root, shoulder_a, tip, shoulder_b, root]
			for edge_index in 4:
				_add_segment_box(canopy,
					"GoldenPetalEdge_%s_%02d_%02d" % ["L" if side < 0 else "R", petal_index, edge_index],
					edge_points[edge_index] + Vector3.UP * 0.30,
					edge_points[edge_index + 1] + Vector3.UP * 0.30,
					Vector2(0.26, 0.26), _gold_material)
			_add_segment_box(canopy,
				"GoldenPetalVein_%s_%02d" % ["L" if side < 0 else "R", petal_index],
				root + Vector3.UP * 0.32, tip + Vector3.UP * 0.32,
				Vector2(0.20, 0.20), _gold_material)
	# Layered platform rings turn the plain drum into the blueprint's engineered
	# circular boarding crown.
	_add_torus(pavilion, "OuterPlatformEnergyRing", Vector3(0.0, -0.9, 0.0),
		33.4, 34.0, _gold_material)
	_add_torus(pavilion, "InnerPlatformCircuitRing", Vector3(0.0, 0.28, 0.0),
		17.4, 17.9, _glass_material)
	# Branching columns sit outside the 15 m boarding lane. Their gold collars
	# show where the living structure connects to engineered roof modules.
	var supports := Node3D.new()
	supports.name = "BranchingSupportColumns"
	pavilion.add_child(supports)
	for side in [-1.0, 1.0]:
		for support_index in 3:
			var z := -14.0 + float(support_index) * 14.0
			var x := float(side) * 19.0
			_add_cylinder(supports, "LivingColumn_%s_%02d" % ["L" if side < 0 else "R", support_index],
				Vector3(x, 5.2, z), 0.75, 10.4, _nature_material, false, 8)
			_add_cylinder(supports, "EngineeringCollar_%s_%02d" % ["L" if side < 0 else "R", support_index],
				Vector3(x, 9.2, z), 1.15, 0.65, _gold_material, false, 12)
			_add_walkway_between(supports, "CanopyBranchInner_%s_%02d" % ["L" if side < 0 else "R", support_index],
				Vector3(x, 8.6, z), Vector3(float(side) * 13.0, 12.0, z),
				0.62, 0.62, _nature_material, false)
			_add_walkway_between(supports, "CanopyBranchOuter_%s_%02d" % ["L" if side < 0 else "R", support_index],
				Vector3(x, 8.6, z), Vector3(float(side) * 27.0, 12.0, z),
				0.62, 0.62, _nature_material, false)
	_build_resonance_arch(pavilion, "ResonanceBoardingArchRear", Vector3(-13.0, 4.9, 2.0), -1.0)
	_build_resonance_arch(pavilion, "ResonanceBoardingArchFront", Vector3(13.0, 4.9, 2.0), 1.0)
	# A crystal spine marks the station centre but stays above head and train
	# clearance; the thin vertical shaft is visual-only.
	_add_cylinder(pavilion, "CrystalEnergySpine", Vector3(0.0, 14.2, 1.5),
		1.05, 7.0, _violet_material, false, 6)
	_add_torus(pavilion, "CanopyEnergyRing", Vector3(0.0, 12.1, 1.5),
		8.35, 8.8, _gold_material)
	for side in [-1.0, 1.0]:
		for planter_index in 2:
			var planter_z := -11.0 + float(planter_index) * 23.0
			_build_crystal_planter(pavilion,
				"CrystalPlanter_%s_%02d" % ["L" if side < 0 else "R", planter_index],
				Vector3(float(side) * 26.0, 0.2, planter_z))
	# Cyan circuits guide players around the track and toward both boarding bays.
	for side in [-1.0, 1.0]:
		_add_walkway_between(pavilion, "PlatformCircuit_%s" % ("L" if side < 0 else "R"),
			Vector3(float(side) * 10.0, 0.35, -17.0),
			Vector3(float(side) * 10.0, 0.35, 21.0), 0.30, 0.08, _glass_material, false)
		var pavilion_light := OmniLight3D.new()
		pavilion_light.name = "CanopyGlowLeft" if side < 0 else "CanopyGlowRight"
		pavilion_light.position = Vector3(float(side) * 13.0, 7.0, 2.0)
		pavilion_light.light_color = Color("72eaff")
		pavilion_light.light_energy = 2.4
		pavilion_light.omni_range = 19.0
		pavilion.add_child(pavilion_light)


func _build_resonance_arch(parent: Node3D, node_name: String,
		centre: Vector3, facing_side: float) -> void:
	var arch := Node3D.new()
	arch.name = node_name
	arch.position = centre
	parent.add_child(arch)
	# Vertical concentric rings read as a scientific resonance gateway rather
	# than another square portal. The opening faces the track from either side.
	_add_torus(arch, "GoldenResonanceRing", Vector3.ZERO, 4.0, 4.55,
		_gold_material, Vector3(0.0, 0.0, 90.0))
	_add_torus(arch, "CyanResonanceRing", Vector3(facing_side * 0.10, 0.0, 0.0),
		3.35, 3.65, _glass_material, Vector3(0.0, 0.0, 90.0))
	for z_side in [-1.0, 1.0]:
		_add_box(arch, "ArchFootRear" if z_side < 0 else "ArchFootFront",
			Vector3(0.0, -3.9, float(z_side) * 3.0), Vector3(1.1, 1.3, 1.3),
			_dark_metal_material, false)
		_add_cylinder(arch, "ArchCrystalRear" if z_side < 0 else "ArchCrystalFront",
			Vector3(0.0, -2.8, float(z_side) * 3.0), 0.38, 1.5,
			_violet_material, false, 6)


func _build_crystal_planter(parent: Node3D, node_name: String, position_value: Vector3) -> void:
	var planter := Node3D.new()
	planter.name = node_name
	planter.position = position_value
	parent.add_child(planter)
	_add_box(planter, "PlanterBase", Vector3.ZERO, Vector3(5.0, 0.8, 4.0),
		_nature_material, true)
	for crystal_index in 3:
		_add_cylinder(planter, "GrowthCrystal_%02d" % crystal_index,
			Vector3(-1.2 + float(crystal_index) * 1.2, 1.25, 0.0),
			0.36 + float(crystal_index) * 0.08, 2.4 + float(crystal_index % 2),
			_violet_material, false, 6)


func _build_world_access_bridge(station: Node3D, landing_local: Vector3,
		dock_sign: float) -> void:
	var bridge := Node3D.new()
	bridge.name = "KingdomAccessSkybridge"
	station.add_child(bridge)
	# Meet the circular platform at its outer rim instead of passing underneath
	# it. The 16 m bridge is 7.3 m wide at the outer stair edges, so x=-37 keeps
	# its full entrance on the 38 m platform while exposing the complete stair.
	var dock_edge := Vector3(dock_sign * 37.0, -1.2, 0.0)
	# STATIONS stores a safe player landing point two metres above each island.
	# Using that point as the deck centre left the downhill end visibly floating
	# almost three metres above the ground. Place the sloped box so its actual
	# top corner, including the slope, lands exactly on the island surface.
	var landing_surface_y := landing_local.y - LANDING_PLAYER_CLEARANCE
	var landing := Vector3(landing_local.x,
		landing_surface_y - ACCESS_DECK_THICKNESS * 0.5, landing_local.z)
	for _iteration in 2:
		var bridge_basis := Basis.looking_at((landing - dock_edge).normalized(), Vector3.UP)
		landing.y = landing_surface_y - bridge_basis.y.y * ACCESS_DECK_THICKNESS * 0.5
	_add_walkway_between(bridge, "FloatingAccessDeck", dock_edge, landing, 16.0,
		ACCESS_DECK_THICKNESS, _dark_metal_material, false)
	_build_bridge_ceremonial_ascent(bridge, dock_edge, landing)
	_build_dock_arrival_stairs(station, dock_sign,
		Vector3(landing.x, landing_surface_y, landing.z))
	var direction := landing - dock_edge
	var side_axis := Vector3(-direction.z, 0, direction.x).normalized()
	# The guards must clear the arrival flight, which is 15.6 m wide (±7.8) where
	# it crosses the bridge. At the old ±7.4 they ran 0.4 m inside the stair, so
	# both rails and their posts cut down the full length of the run. Sit them on
	# the 16 m deck's outer edge instead, just past the widest stair tread.
	const SKYBRIDGE_GUARD_OFFSET := 7.9
	for side in [-1.0, 1.0]:
		var edge_offset := side_axis * float(side) * SKYBRIDGE_GUARD_OFFSET
		for rail_height in [1.15, 2.35]:
			var lateral: Vector3 = edge_offset + Vector3.UP * float(rail_height)
			_add_walkway_between(bridge,
				"SkybridgeGuardLeft" if side < 0 else "SkybridgeGuardRight",
				dock_edge + lateral, landing + lateral, 0.30, 0.30, _gold_material, true)
		for post_index in 9:
			var ratio := float(post_index) / 8.0
			var surface := dock_edge.lerp(landing, ratio) + edge_offset
			_add_box(bridge, "SkybridgeRailPost",
				surface + Vector3.UP * 1.2, Vector3(0.34, 2.4, 0.34),
				_gold_material, true)


func _build_bridge_ceremonial_ascent(parent: Node3D, start: Vector3, finish: Vector3) -> void:
	# Forty-eight shallow visual treads distribute the 27 m station rise into
	# player-scale increments. Collision remains the continuous box beneath, so
	# the route is smooth while reading as the blueprint's ceremonial stair.
	const LONG_STEP_COUNT := 48
	const CENTRAL_WIDTH := 5.2
	const SIDE_WIDTH := 4.7
	const SIDE_OFFSET := CENTRAL_WIDTH * 0.5 + SIDE_WIDTH * 0.5
	var horizontal_run := Vector3(finish.x - start.x, 0.0, finish.z - start.z)
	if horizontal_run.length() < 0.01:
		return
	var forward := horizontal_run.normalized()
	var side_axis := Vector3(-forward.z, 0.0, forward.x)
	var step_depth := horizontal_run.length() / float(LONG_STEP_COUNT) + 0.10
	for step_index in LONG_STEP_COUNT:
		var ratio := float(step_index) / float(LONG_STEP_COUNT - 1)
		var surface := start.lerp(finish, ratio) + Vector3.UP * 0.58
		for side in [-1.0, 1.0]:
			var tread_centre := surface + side_axis * float(side) * SIDE_OFFSET
			_add_box(parent,
				"CeremonialStep_%s_%02d" % ["L" if side < 0 else "R", step_index],
				Vector3(tread_centre.x, surface.y - 0.06, tread_centre.z),
				Vector3(SIDE_WIDTH, 0.12, step_depth), _stone_material, false,
				0.0, atan2(forward.x, forward.z))
	_add_surface_ramp_mesh(parent, "CentralLumenRamp",
		start + Vector3.UP * 0.62, finish + Vector3.UP * 0.62,
		CENTRAL_WIDTH, 0.16, _dark_metal_material)
	_add_surface_ramp_mesh(parent, "AccessEnergyConduit",
		start + Vector3.UP * 0.73, finish + Vector3.UP * 0.73,
		1.05, 0.08, _glass_material)
	# Three paired crystal gardens break the long climb into a measured sequence
	# of magical-engineering nodes while remaining outside the clear centre lane.
	for garden_index in 3:
		var ratio := 0.22 + float(garden_index) * 0.28
		var garden_surface := start.lerp(finish, ratio) + Vector3.UP * 0.75
		for side in [-1.0, 1.0]:
			var garden_position := garden_surface + side_axis * float(side) * 7.0
			_build_ascent_crystal_node(parent,
				"AscentCrystalNode_%s_%02d" % ["L" if side < 0 else "R", garden_index],
				garden_position)


func _build_ascent_crystal_node(parent: Node3D, node_name: String,
		position_value: Vector3) -> void:
	var node := Node3D.new()
	node.name = node_name
	node.position = position_value
	parent.add_child(node)
	_add_box(node, "GardenPlinth", Vector3(0.0, 0.0, 0.0),
		Vector3(2.6, 0.55, 1.4), _nature_material, false)
	_add_cylinder(node, "WayfindingCrystal", Vector3(0.0, 1.05, 0.0),
		0.42, 2.1, _violet_material, false, 6)
	_add_torus(node, "EnergyCollar", Vector3(0.0, 0.65, 0.0),
		0.62, 0.78, _gold_material)


func _build_dock_arrival_stairs(station: Node3D, dock_sign: float,
		access_landing_surface: Vector3) -> void:
	var stairs := Node3D.new()
	stairs.name = "AccessRamp"
	station.add_child(stairs)
	# Keep the visible stair rhythm, but let one continuous ramp carry the
	# player. The old cumulative collision boxes all extended to one shared
	# bottom and their upper faces combined into the tall wall seen at the dock.
	const STEP_DEPTH := 2.4
	const TREAD_THICKNESS := 0.12
	const CENTRAL_RAMP_WIDTH := 5.4
	const SIDE_STAIR_WIDTH := 4.9
	const SIDE_STAIR_Z := CENTRAL_RAMP_WIDTH * 0.5 + SIDE_STAIR_WIDTH * 0.5
	var stair_start_x := -STAIR_START_X * dock_sign
	var stair_end_x := -STAIR_END_X * dock_sign
	for index in STAIR_STEP_COUNT:
		var ratio := float(index) / float(STAIR_STEP_COUNT - 1)
		var top_y := lerpf(STAIR_BOTTOM_TOP_Y, STAIR_TOP_TOP_Y, ratio)
		var x := lerpf(stair_start_x, stair_end_x, ratio)
		_add_box(stairs, "DockStep_%02d" % (index + 1),
			Vector3(x, top_y - TREAD_THICKNESS * 0.5, -SIDE_STAIR_Z),
			Vector3(STEP_DEPTH, TREAD_THICKNESS, SIDE_STAIR_WIDTH), _stone_material, false)
		_add_box(stairs, "DockStepRight_%02d" % (index + 1),
			Vector3(x, top_y - TREAD_THICKNESS * 0.5, SIDE_STAIR_Z),
			Vector3(STEP_DEPTH, TREAD_THICKNESS, SIDE_STAIR_WIDTH), _stone_material, false)
	var ramp_start := Vector3(stair_start_x + dock_sign * STEP_DEPTH * 0.5,
		STAIR_BOTTOM_TOP_Y - 0.04, 0.0)
	var ramp_finish := Vector3(stair_end_x - dock_sign * STEP_DEPTH * 0.5,
		STAIR_TOP_TOP_Y + 0.16, 0.0)
	_add_surface_ramp_mesh(stairs, "CentralAccessRamp", ramp_start, ramp_finish,
		CENTRAL_RAMP_WIDTH, 0.24, _dark_metal_material)
	_add_surface_ramp_mesh(stairs, "CrystalEnergyConduit",
		ramp_start + Vector3.UP * 0.15, ramp_finish + Vector3.UP * 0.15,
		1.05, 0.08, _glass_material)
	# One convex body carries the complete landing-to-platform route. Two boxes
	# that only touched at the stair foot exposed an internal end face, so the
	# player stopped at the exact bridge/stair seam despite both tops lining up.
	_add_combined_access_collision(stairs, "WalkableStairRamp",
		access_landing_surface,
		Vector3(stair_start_x + dock_sign * STEP_DEPTH * 0.5,
			STAIR_BOTTOM_TOP_Y - 0.10, 0.0),
		Vector3(stair_end_x - dock_sign * STEP_DEPTH * 0.5,
			STAIR_TOP_TOP_Y + 0.10, 0.0), 15.6, 0.42)
	# Open rails replace the previous 2.6 m solid yellow walls, which filled the
	# camera and visually hid the stairs in the Web build.
	for side in [-1.0, 1.0]:
		var side_z := float(side) * 7.55
		for post_index in 7:
			var ratio := float(post_index) / 6.0
			var x := lerpf(stair_start_x, stair_end_x, ratio)
			var tread_y := lerpf(STAIR_BOTTOM_TOP_Y, STAIR_TOP_TOP_Y, ratio)
			_add_box(stairs, "StairRailPost", Vector3(x, tread_y + 1.25, side_z),
				Vector3(0.38, 2.5, 0.38), _gold_material, true)
		var rail_start := Vector3(stair_start_x, STAIR_BOTTOM_TOP_Y + 2.15, side_z)
		var rail_finish := Vector3(stair_end_x, STAIR_TOP_TOP_Y + 2.15, side_z)
		_add_walkway_between(stairs,
			"StairGuardLeft" if side < 0 else "StairGuardRight",
			rail_start, rail_finish, 0.38, 0.38, _gold_material, true)
	# Inner handrails clearly separate the ceremonial side stairs from the
	# accessible luminous centre ramp.
	for side in [-1.0, 1.0]:
		var inner_z := float(side) * (CENTRAL_RAMP_WIDTH * 0.5 + 0.18)
		_add_walkway_between(stairs, "InnerRampGuardLeft" if side < 0 else "InnerRampGuardRight",
			Vector3(stair_start_x, STAIR_BOTTOM_TOP_Y + 1.05, inner_z),
			Vector3(stair_end_x, STAIR_TOP_TOP_Y + 1.05, inner_z),
			0.24, 0.24, _gold_material, false)


func _add_surface_ramp_collision(parent: Node3D, node_name: String, start_surface: Vector3,
		finish_surface: Vector3, width: float, thickness: float) -> void:
	var direction := finish_surface - start_surface
	var length := direction.length()
	if length < 0.01:
		return
	# Basis.looking_at() aims local -Z at the target, but the box measures its
	# length on +Z. Passing the run direction straight in therefore builds the
	# ramp reversed: the walkable face descends while the visible treads climb,
	# leaving the player floating at one end of the flight and sunk at the other.
	# Negating the direction puts +Z along the run so the slope matches the steps.
	var basis := Basis.looking_at(-direction.normalized(), Vector3.UP)
	# start_surface and finish_surface describe the walkable top face. Lower the
	# body's origin along its local normal so the collision surface meets them.
	var midpoint := (start_surface + finish_surface) * 0.5 - basis.y * thickness * 0.5
	var body := StaticBody3D.new()
	body.name = "%sCollision" % node_name
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, thickness, length)
	shape_node.shape = shape
	body.add_child(shape_node)
	body.transform = Transform3D(basis, midpoint)
	parent.add_child(body)


func _add_combined_access_collision(parent: Node3D, node_name: String,
		landing_surface: Vector3, foot_surface: Vector3, top_surface: Vector3,
		width: float, _thickness: float) -> void:
	var body := StaticBody3D.new()
	body.name = "%sCollision" % node_name
	var shape_node := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	var surfaces := [landing_surface, foot_surface, top_surface]
	var edges: Array[PackedVector3Array] = []
	for index in surfaces.size():
		var previous: Vector3 = surfaces[maxi(0, index - 1)]
		var following: Vector3 = surfaces[mini(surfaces.size() - 1, index + 1)]
		var forward := Vector3(following.x - previous.x, 0.0,
			following.z - previous.z).normalized()
		var side_axis := Vector3(-forward.z, 0.0, forward.x)
		edges.append(PackedVector3Array([
			surfaces[index] - side_axis * width * 0.5,
			surfaces[index] + side_axis * width * 0.5,
		]))
	var faces := PackedVector3Array()
	for index in surfaces.size() - 1:
		var left_a := edges[index][0]
		var right_a := edges[index][1]
		var left_b := edges[index + 1][0]
		var right_b := edges[index + 1][1]
		faces.append_array(PackedVector3Array([
			left_a, right_a, right_b,
			left_a, right_b, left_b,
		]))
	shape.set_faces(faces)
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)


func _add_surface_ramp_mesh(parent: Node3D, node_name: String, start_surface: Vector3,
		finish_surface: Vector3, width: float, thickness: float, material: Material) -> void:
	var direction := finish_surface - start_surface
	if direction.length() < 0.01:
		return
	# Same -Z/+Z correction as _add_surface_ramp_collision(), so the visible ramp
	# and the body the player walks on stay on the same slope.
	var basis := Basis.looking_at(-direction.normalized(), Vector3.UP)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, thickness, direction.length())
	instance.mesh = mesh
	instance.transform = Transform3D(basis,
		(start_surface + finish_surface) * 0.5 - basis.y * thickness * 0.5)
	instance.material_override = material
	parent.add_child(instance)


func _build_platform_guardrails(station: Node3D, dock_sign: float) -> void:
	for side in [-1.0, 1.0]:
		var side_x := float(side) * 18.0
		var is_dock_side := is_equal_approx(float(side), dock_sign)
		for post_index in 6:
			var z := -16.0 + float(post_index) * 8.0
			# Leave the centre of whichever platform edge faces this station's
			# world landing open. Mind Spark approaches from the right; the other
			# three stations currently approach from the left.
			if is_dock_side and absf(z) < 6.0:
				continue
			_add_box(station, "PlatformRailPost", Vector3(side_x, 1.7, z),
				Vector3(0.42, 3.4, 0.42), _gold_material, true)
		for height in [1.4, 3.1]:
			var guard_name := "PlatformGuardLeft" if side < 0.0 else "PlatformGuardRight"
			if is_dock_side:
				_add_walkway_between(station, guard_name,
					Vector3(side_x, height, -16.0), Vector3(side_x, height, -6.0),
					0.38, 0.38, _gold_material, true)
				_add_walkway_between(station, "%sFront" % guard_name,
					Vector3(side_x, height, 6.0), Vector3(side_x, height, 24.0),
					0.38, 0.38, _gold_material, true)
			else:
				_add_walkway_between(station, guard_name,
					Vector3(side_x, height, -16.0), Vector3(side_x, height, 24.0),
					0.38, 0.38, _gold_material, true)


func _add_walkway_between(parent: Node3D, node_name: String, start: Vector3, finish: Vector3,
		width: float, thickness: float, material: Material, collision: bool) -> void:
	var direction := finish - start
	var length := direction.length()
	if length < 0.01:
		return
	var basis := Basis.looking_at(direction.normalized(), Vector3.UP)
	var midpoint := (start + finish) * 0.5
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, thickness, length)
	instance.mesh = mesh
	instance.transform = Transform3D(basis, midpoint)
	instance.material_override = material
	parent.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.name = "%sCollision" % node_name
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		shape_node.shape = shape
		body.add_child(shape_node)
		body.transform = Transform3D(basis, midpoint)
		parent.add_child(body)


func _build_train() -> void:
	_train = Node3D.new()
	_train.name = "RainbowGalaxyTrain"
	_train.position = STATIONS[0].position
	add_child(_train)
	var colours := [Color("f35c94"), Color("f3bc55"), Color("63d69b"), Color("5bc9ed"), Color("9370dc")]
	# The reference train has two open passenger coaches behind one crystal
	# engine. These simple hidden bodies remain the authoritative walkable and
	# rideable collision shell beneath the detailed Blender construction.
	for carriage_index in 2:
		var carriage := Node3D.new()
		carriage.name = "Carriage_%02d" % (carriage_index + 1)
		carriage.position.z = float(carriage_index) * 15.0
		_train.add_child(carriage)
		var body_material := _material(colours[(carriage_index + 2) % colours.size()], 0.32,
			colours[(carriage_index + 2) % colours.size()], 0.9)
		# Open passenger deck: walkable/jumpable floor, low walls, open centre.
		_add_box(carriage, "PassengerDeck", Vector3(0.0, 0.65, 0.0), Vector3(11.0, 1.3, 13.0),
			body_material, true)
		for side in [-1.0, 1.0]:
			_add_box(carriage, "CoachGuardLeft" if side < 0 else "CoachGuardRight",
				Vector3(side * 5.15, 2.0, 0.0), Vector3(0.7, 2.7, 13.0), _gold_material, true)
		# Split end guards leave a 4 m centre doorway aligned with the station lane.
		for end_z in [-6.15, 6.15]:
			for side in [-1.0, 1.0]:
				_add_box(carriage, "DoorGuard", Vector3(float(side) * 3.5, 2.0, end_z),
					Vector3(3.0, 2.7, 0.7), _gold_material, true)
		# Two side benches with a clear centre aisle between them. A single
		# 5.5 m bench spanned the whole walkway, so walking the length of the
		# coach meant climbing a 1.35 m step up onto the seat and back down —
		# the deck read as glitchy rather than walkable. Seats stay where they
		# were; only the middle is opened up.
		for bench_side in [-1.0, 1.0]:
			_add_box(carriage, "JumpBenchLeft" if bench_side < 0 else "JumpBenchRight",
				Vector3(bench_side * 2.4, 1.65, 2.8), Vector3(1.9, 2.0, 2.2),
				_glass_material, true)
		if carriage_index == 0:
			# A waist-high control desk, not a full-height wall. At 2.7 m tall
			# and centred at y=2.0 this sealed the doorway between the deck and
			# the cab: the player could never get within Q range of the driver
			# point, so driving was unreachable in play. Keeping it below
			# standing height leaves the cab walkable and still reads as a desk.
			_add_box(carriage, "DriverConsole", Vector3(0.0, 1.6, -5.6),
				Vector3(4.8, 0.6, 0.8), _glass_material, true)
			var driver_label := Label3D.new()
			driver_label.name = "DriverControls"
			driver_label.text = "CROWN LINE DRIVER\n1 DRIVE  •  W/S MOVE  •  R HORN  •  Q EXIT"
			driver_label.position = Vector3(0.0, 4.2, -4.4)
			driver_label.font_size = 22
			driver_label.outline_size = 6
			driver_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			driver_label.no_depth_test = false
			carriage.add_child(driver_label)
		for side in [-1.0, 1.0]:
			for z in [-4.0, 4.0]:
				_add_cylinder(carriage, "StarWheel", Vector3(side * 5.4, 0.4, z), 2.1, 1.0, _gold_material, false, 16, Vector3(0.0, 0.0, 90.0))

	# Gangway plate bridging the two coaches. Each deck is 13 m long and they sit
	# 15 m apart, leaving a 2 m hole at z=6.5..8.5 that dropped the player
	# straight through the train to the rail below. The plate is flush with both
	# decks so walking between coaches is a continuous floor, not a jump.
	_add_box(_train, "CoachGangway", Vector3(0.0, 0.65, 7.5), Vector3(4.0, 1.3, 2.6),
		_gold_material, true)
	for gangway_side in [-1.0, 1.0]:
		_add_box(_train, "GangwayRail", Vector3(gangway_side * 2.35, 2.0, 7.5),
			Vector3(0.3, 2.7, 2.6), _gold_material, true)

	var engine := Node3D.new()
	engine.name = "MiloEngine"
	engine.position = Vector3(0.0, 0.0, -15.0)
	_train.add_child(engine)
	_add_box(engine, "EngineBody", Vector3(0.0, 4.0, 0.0), Vector3(12.0, 8.0, 17.0),
		_material(Color("724cc5"), 0.30, Color("aa84ff"), 1.3), true)
	# Guard rail along the engine's rear roof edge. The roof is 8 m up and the
	# coach deck is at 1.3 m, so anyone who got onto the engine could walk off
	# the back and take a 6.7 m fall onto the deck. This closes that edge.
	_add_box(engine, "EngineRoofGuard", Vector3(0.0, 8.55, 8.2), Vector3(12.0, 1.1, 0.4),
		_gold_material, true)
	_add_cylinder(engine, "CrownChimney", Vector3(0.0, 10.0, -2.0), 2.6, 8.0, _gold_material, false, 12)
	_train_glow = OmniLight3D.new()
	_train_glow.name = "GuidingLight"
	_train_glow.position = Vector3(0.0, 7.0, -10.0)
	_train_glow.light_color = Color("a8eeff")
	_train_glow.light_energy = 7.0
	_train_glow.omni_range = 38.0
	_train.add_child(_train_glow)
	_attach_detailed_train_visual()
	_build_rainbow_gold_layout()
	_build_directional_movement_vfx()
	_train.position = STATIONS[START_STATION_INDEX].position
	_orient_train_at_station(START_STATION_INDEX)


func _attach_detailed_train_visual() -> void:
	var detailed_scene := load(DETAILED_TRAIN_MODEL_PATH) as PackedScene
	if detailed_scene == null:
		push_warning("Crown Line detailed Blender train could not be loaded")
		return
	# Keep the proven procedural StaticBody3D collision and driver labels while
	# replacing its primitive meshes with the optimized textured export. The source
	# Blend retains all 13,000 editable components; the game export consolidates its
	# static surfaces and preserves named moving mechanisms for playable frame rates.
	for candidate in _train.find_children("*", "MeshInstance3D", true, false):
		(candidate as MeshInstance3D).visible = false
	var detailed_train := detailed_scene.instantiate() as Node3D
	if detailed_train == null:
		push_warning("Crown Line Blender export did not instantiate as Node3D")
		return
	detailed_train.name = "BlenderCrownLineTrain"
	# Blender's -Y crystal nose imports on Godot's +Z. Rotate the visual once so
	# the engine faces local -Z, the same forward axis used by Basis.looking_at(),
	# while the two coach decks remain aligned with their collision shells.
	detailed_train.rotation.y = PI
	detailed_train.set_meta("source_blend",
		"res://assets3D/crown_line_train/crown_line_lego_train.blend")
	detailed_train.set_meta("editable_part_count", DETAILED_TRAIN_EDITABLE_PARTS)
	detailed_train.set_meta("walkable_collision_source", "procedural_two_coach_shell")
	_train.add_child(detailed_train)
	_enhance_detailed_train_palette(detailed_train)
	# The production train now carries a second, native-Godot interpretation of
	# the same shared bird/bullet cover blueprint used by the Blender source.
	# It is intentionally separate so comparison captures can toggle either
	# renderer without changing collisions, controls, seating or train motion.
	var godot_cover := Node3D.new()
	godot_cover.name = "GodotEngineCover"
	godot_cover.set_script(load(GODOT_ENGINE_COVER_SCRIPT))
	_train.add_child(godot_cover)
	_register_train_mechanisms(detailed_train)
	_last_train_position = _train.global_position


func _enhance_detailed_train_palette(detailed_train: Node3D) -> void:
	# Preserve the authored textures while lifting the muted runtime material
	# families into a clearer rainbow-and-gold hierarchy. Surface overrides keep
	# the source GLB untouched and therefore remain safe for the Web export.
	var palette := {
		"aged_gold": Color("ffd45a"),
		"gold": Color("ffd45a"),
		"roof_teal": Color("25e0bd"),
		"roof_turquoise": Color("35c9ff"),
		"navy": Color("4169e8"),
		"violet": Color("b16cff"),
		"cyan": Color("50efff"),
		"indigo": Color("7659e8"),
		"living_root": Color("55b96f"),
	}
	for candidate in detailed_train.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if source == null:
				continue
			var material_name := source.resource_name.to_lower()
			var selected := Color.TRANSPARENT
			for palette_key in palette:
				if material_name.contains(palette_key):
					selected = palette[palette_key]
					break
			if selected.a <= 0.0:
				continue
			var enhanced := source.duplicate() as StandardMaterial3D
			enhanced.albedo_color = selected
			enhanced.emission_enabled = true
			enhanced.emission = selected
			enhanced.emission_energy_multiplier = 0.38 if material_name.contains("gold") else 0.22
			if material_name.contains("gold"):
				enhanced.metallic = 0.86
				enhanced.roughness = 0.24
			mesh_instance.set_surface_override_material(surface_index, enhanced)


func _build_rainbow_gold_layout() -> void:
	var accents := Node3D.new()
	accents.name = "RainbowGoldAccentLayout"
	_train.add_child(accents)
	_rainbow_gold_accent_count = 0
	# Two continuous gold sills visually bind the engine and both coaches into
	# one royal Crown Line silhouette.
	for side in [-1.0, 1.0]:
		_add_box(accents, "GoldRoyalSillLeft" if side < 0.0 else "GoldRoyalSillRight",
			Vector3(side * 5.72, 0.95, -0.8), Vector3(0.22, 0.30, 45.0),
			_gold_material, false)
		_rainbow_gold_accent_count += 1
	# Seven slim spectrum rails run over each open coach canopy. They add colour
	# without covering seats, doors, the driver view, or walkable collision.
	var spectrum := [
		Color("ff4f78"), Color("ff934d"), Color("ffe45b"), Color("5ee889"),
		Color("43e6ee"), Color("4d82ff"), Color("b16cff")]
	for coach_z in [0.0, 15.0]:
		for colour_index in spectrum.size():
			var colour: Color = spectrum[colour_index]
			var rainbow_material := _material(colour, 0.28, colour, 0.78)
			var x := -3.6 + float(colour_index) * 1.2
			_add_box(accents, "CoachSpectrum_%02d_%02d" % [int(coach_z), colour_index],
				Vector3(x, 7.55, coach_z), Vector3(0.32, 0.18, 12.2),
				rainbow_material, false)
			_rainbow_gold_accent_count += 1


func _build_directional_movement_vfx() -> void:
	_movement_vfx = Node3D.new()
	_movement_vfx.name = "DirectionalRainbowMovementVFX"
	_movement_vfx.top_level = true
	_train.add_child(_movement_vfx)
	_build_motion_blur_echoes()

	var spectrum := [
		Color("ff426d"), Color("ff914d"), Color("ffe95a"), Color("55ef87"),
		Color("42e9f5"), Color("4c78ff"), Color("b16cff")]
	_rainbow_wake_ribbons.clear()
	for colour_index in spectrum.size():
		var colour: Color = spectrum[colour_index]
		var ribbon := MeshInstance3D.new()
		ribbon.name = "RainbowWakeRibbon_%02d" % colour_index
		var ribbon_mesh := BoxMesh.new()
		ribbon_mesh.size = Vector3(0.46, 0.14, 1.0)
		var ribbon_material := StandardMaterial3D.new()
		ribbon_material.albedo_color = Color(colour, 0.76)
		ribbon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ribbon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ribbon_material.emission_enabled = true
		ribbon_material.emission = colour
		ribbon_material.emission_energy_multiplier = 2.2
		ribbon_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ribbon_mesh.material = ribbon_material
		ribbon.mesh = ribbon_mesh
		ribbon.visible = false
		_movement_vfx.add_child(ribbon)
		ribbon.top_level = true
		_rainbow_wake_ribbons.append(ribbon)

	var rainbow := Gradient.new()
	rainbow.offsets = PackedFloat32Array([0.0, 0.14, 0.29, 0.43, 0.58, 0.74, 1.0])
	rainbow.colors = PackedColorArray([
		Color("ff426d"), Color("ff9a45"), Color("ffe95a"), Color("55ef87"),
		Color("42e9f5"), Color("4c78ff"), Color(0.72, 0.35, 1.0, 0.0)])
	_rainbow_trail_particles = _make_train_trail_particles(
		"RainbowDirectionTrail", rainbow, 360, 1.75, 0.52, 54.0)
	_movement_vfx.add_child(_rainbow_trail_particles)

	var gold := Gradient.new()
	gold.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	gold.colors = PackedColorArray([
		Color("fff4b0"), Color("ffd04d"), Color(1.0, 0.55, 0.10, 0.0)])
	_gold_trail_particles = _make_train_trail_particles(
		"GoldCrownSparkTrail", gold, 144, 1.20, 0.32, 40.0)
	_movement_vfx.add_child(_gold_trail_particles)
	_movement_vfx.global_position = _train.global_position + Vector3.UP * 2.2


func _build_motion_blur_echoes() -> void:
	_motion_blur_echoes.clear()
	_motion_echo_history.clear()
	var echo_colours := [
		Color("55efff"), Color("7f75ff"), Color("c968ff"),
		Color("ff5fa0"), Color("ffd45a")]
	for echo_index in 5:
		var echo := Node3D.new()
		echo.name = "TrainMotionEcho_%02d" % (echo_index + 1)
		echo.visible = false
		_movement_vfx.add_child(echo)
		echo.top_level = true
		var alpha := 0.055 - float(echo_index) * 0.007
		var body_material := _make_motion_echo_material(echo_colours[echo_index], alpha)
		var gold_material := _make_motion_echo_material(Color("ffd45a"), alpha * 0.82)
		# Rounded, transparent volumes leave a soft train-shaped persistence trail.
		# Unlike the previous wire boxes, these have no hard rectangular edges.
		_add_motion_echo_glow(echo, "EchoEngineGlow",
			Vector3(0.0, 4.2, -15.0), Vector3(12.0, 8.2, 17.0), body_material)
		_add_motion_echo_glow(echo, "EchoCoachFrontGlow",
			Vector3(0.0, 3.8, 0.0), Vector3(11.0, 7.4, 13.0), body_material)
		_add_motion_echo_glow(echo, "EchoCoachRearGlow",
			Vector3(0.0, 3.8, 15.0), Vector3(11.0, 7.4, 13.0), body_material)
		_add_motion_echo_glow(echo, "EchoGoldChassisGlow",
			Vector3(0.0, 0.7, -0.8), Vector3(11.8, 0.45, 44.0), gold_material)
		_motion_blur_echoes.append(echo)


func _make_motion_echo_material(colour: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 0.72
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	return material


func _add_motion_echo_glow(parent: Node3D, node_name: String,
		center: Vector3, size: Vector3, material: Material) -> void:
	var glow := MeshInstance3D.new()
	glow.name = node_name
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 1.0
	glow_mesh.height = 2.0
	glow_mesh.radial_segments = 16
	glow_mesh.rings = 8
	glow.mesh = glow_mesh
	glow.position = center
	glow.scale = size * 0.5
	glow.material_override = material
	parent.add_child(glow)


func _make_train_trail_particles(node_name: String, colour_gradient: Gradient,
		particle_amount: int, particle_lifetime: float, particle_radius: float,
		maximum_velocity: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = particle_amount
	particles.lifetime = particle_lifetime
	particles.preprocess = particle_lifetime
	particles.randomness = 0.36
	particles.fixed_fps = 30
	particles.local_coords = false
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-70.0, -35.0, -70.0), Vector3(140.0, 70.0, 140.0))

	var motion := ParticleProcessMaterial.new()
	motion.direction = Vector3(0.0, 0.0, -1.0)
	motion.spread = 22.0
	motion.initial_velocity_min = maximum_velocity * 0.52
	motion.initial_velocity_max = maximum_velocity
	motion.gravity = Vector3(0.0, 1.6, 0.0)
	motion.damping_min = 4.0
	motion.damping_max = 8.0
	motion.scale_min = 0.55
	motion.scale_max = 1.65
	if node_name == "RainbowDirectionTrail":
		# Randomized hue gives every cross-section of the wake a true spectrum;
		# the lifetime ramp then orders those colours into a soft rainbow tail.
		motion.hue_variation_min = -1.0
		motion.hue_variation_max = 1.0
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(4.8, 1.8, 0.8)
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = colour_gradient
	motion.color_ramp = ramp_texture
	particles.process_material = motion

	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = particle_radius
	spark_mesh.height = particle_radius * 2.0
	spark_mesh.radial_segments = 5
	spark_mesh.rings = 2
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.vertex_color_use_as_albedo = true
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_material.no_depth_test = false
	spark_mesh.material = spark_material
	particles.draw_pass_1 = spark_mesh
	return particles


func _register_train_mechanisms(detailed_train: Node3D) -> void:
	_speed_band_parts.clear()
	_speed_rotor_parts.clear()
	_speed_needle = null
	_wheel_mechanism_parts.clear()
	_reactor_mechanism_parts.clear()
	_steam_gear_parts.clear()
	_brake_needles.clear()
	for candidate in detailed_train.find_children("*", "MeshInstance3D", true, false):
		var part := candidate as Node3D
		var part_name := String(part.name)
		if part_name.contains("Engine_SpeedMechanismBand_"):
			_speed_band_parts.append(part)
			part.set_meta("mechanism_base_scale", part.scale)
		elif part_name.contains("Engine_SpeedMechanismRotor_"):
			_speed_rotor_parts.append(part)
		elif part_name.contains("Engine_ETCS_ActualSpeedNeedle"):
			_speed_needle = part
			part.set_meta("mechanism_base_rotation", part.rotation)
		elif part_name.contains("Engine_Bogie_Wheel_") \
			or part_name.contains("Engine_Bogie_WheelGold_") \
			or part_name.contains("Engine_Bogie_WheelSpoke_") \
			or part_name.contains("Engine_Bogie_Tyre_") \
			or part_name.contains("Engine_Bogie_RailFlange_") \
			or part_name.contains("Engine_Bogie_BrakeDisc_"):
			_wheel_mechanism_parts.append(part)
			part.set_meta("mechanism_base_rotation", part.rotation)
		elif part_name.contains("Engine_ReactorEmitter_") \
			or part_name.contains("Engine_ReactorValveCore_") \
			or part_name.contains("Engine_NoseCrystal_InnerLightCore"):
			_reactor_mechanism_parts.append(part)
			part.set_meta("mechanism_base_scale", part.scale)
		elif part_name.contains("Engine_SteamDriveGear_") \
			or part_name.contains("Engine_SteamValveGear_") \
			or part_name.contains("Engine_SteamGovernorGear_"):
			_steam_gear_parts.append(part)
			part.set_meta("mechanism_spin_direction",
				-1.0 if part_name.contains("Valve") else 1.0)
		elif part_name.contains("Engine_BrakeGaugeNeedle_"):
			_brake_needles.append(part)
			part.set_meta("mechanism_base_rotation", part.rotation)


func _update_train_mechanisms(delta: float) -> void:
	if _train == null or delta <= 0.0:
		return
	_mechanism_time += delta
	var motion_delta := _train.global_position - _last_train_position
	var travelled := motion_delta.length()
	_last_train_position = _train.global_position
	_update_directional_movement_vfx(delta, motion_delta)
	if not _manual_driving:
		var measured_speed := clampf(travelled / delta * DISPLAY_MAX_SPEED_KPH \
			/ MANUAL_DRIVE_SPEED, 0.0, DISPLAY_MAX_SPEED_KPH)
		var target_speed := measured_speed if _riding else 0.0
		_display_speed_kph = move_toward(_display_speed_kph, target_speed,
			DISPLAY_BRAKING_KPH_S * delta)
	var speed_ratio := clampf(_display_speed_kph / DISPLAY_MAX_SPEED_KPH, 0.0, 1.0)
	for band_index in _speed_band_parts.size():
		var speed_band := _speed_band_parts[band_index]
		var base_scale: Vector3 = speed_band.get_meta("mechanism_base_scale", Vector3.ONE)
		var threshold := float(band_index) / maxf(float(_speed_band_parts.size() - 1), 1.0)
		var activation := clampf((speed_ratio - threshold * .72) / .28, 0.0, 1.0)
		speed_band.scale = Vector3(base_scale.x * (.16 + activation * .84),
			base_scale.y, base_scale.z * (.65 + activation * .35))
	if _speed_needle != null:
		var needle_base: Vector3 = _speed_needle.get_meta("mechanism_base_rotation", Vector3.ZERO)
		_speed_needle.rotation = needle_base + Vector3(0.0, speed_ratio * 3.65, 0.0)
	for speed_rotor in _speed_rotor_parts:
		speed_rotor.rotate_y(delta * (.35 + speed_ratio * 5.5))
	var signed_spin := float(_drive_motion_direction) * speed_ratio * delta * 8.5
	for wheel_part in _wheel_mechanism_parts:
		wheel_part.rotate_x(signed_spin)
	for steam_gear in _steam_gear_parts:
		var gear_direction: float = steam_gear.get_meta("mechanism_spin_direction", 1.0)
		steam_gear.rotate_z(signed_spin * gear_direction * 1.22)
	var reactor_pulse := 1.0 + speed_ratio * 0.22 \
		+ sin(_mechanism_time * (3.0 + speed_ratio * 8.0)) * (0.025 + speed_ratio * 0.045)
	for reactor_part in _reactor_mechanism_parts:
		var base_scale: Vector3 = reactor_part.get_meta("mechanism_base_scale", Vector3.ONE)
		reactor_part.scale = base_scale * reactor_pulse
	for brake_needle in _brake_needles:
		var base_rotation: Vector3 = brake_needle.get_meta("mechanism_base_rotation", Vector3.ZERO)
		brake_needle.rotation = base_rotation + Vector3(0.0, speed_ratio * 1.85, 0.0)
	if _train_glow != null:
		_train_glow.light_energy = 5.0 + speed_ratio * 8.0 + sin(_mechanism_time * 5.0) * 0.4


func _update_directional_movement_vfx(delta: float, motion_delta: Vector3) -> void:
	if _movement_vfx == null or _rainbow_trail_particles == null \
			or _gold_trail_particles == null:
		return
	var raw_speed := motion_delta.length() / maxf(delta, 0.0001)
	var moving := raw_speed > 0.75 and motion_delta.length_squared() > 0.0001
	if moving:
		var measured_direction := motion_delta.normalized()
		if _last_motion_direction.dot(measured_direction) < -0.35:
			_motion_echo_history.clear()
		_last_motion_direction = measured_direction
		_motion_echo_history.push_front(_train.global_transform)
		if _motion_echo_history.size() > 40:
			_motion_echo_history.pop_back()
		# Place the emitter opposite actual world movement. This naturally swaps
		# from the rear coach to the engine end when the driver reverses, so the
		# rainbow always streams behind travel instead of behind a fixed train end.
		_movement_vfx.global_position = _train.global_position \
			- _last_motion_direction * 24.0 + Vector3.UP * 2.4
		_movement_vfx.global_basis = Basis.looking_at(-_last_motion_direction, Vector3.UP)
	_movement_vfx_speed_ratio = move_toward(_movement_vfx_speed_ratio,
		clampf(raw_speed / MANUAL_DRIVE_SPEED, 0.0, 1.0) if moving else 0.0,
		delta * (3.8 if moving else 5.5))
	var should_emit := moving and _movement_vfx_speed_ratio > 0.015
	_rainbow_trail_particles.emitting = should_emit
	_gold_trail_particles.emitting = should_emit
	if not moving:
		_motion_echo_history.clear()
	for echo_index in _motion_blur_echoes.size():
		var echo := _motion_blur_echoes[echo_index]
		var history_index := 2 + echo_index * 3
		var has_snapshot := should_emit and history_index < _motion_echo_history.size()
		echo.visible = has_snapshot
		if has_snapshot:
			echo.global_transform = _motion_echo_history[history_index]
			# A slight longitudinal stretch blends the snapshots into motion blur
			# while retaining a recognizable engine-and-two-coach silhouette.
			echo.scale = Vector3(1.0 + float(echo_index) * 0.018, 1.0,
				1.0 + _movement_vfx_speed_ratio * 0.16)
	var ribbon_length := lerpf(10.0, 58.0, _movement_vfx_speed_ratio)
	var ribbon_side := _last_motion_direction.cross(Vector3.UP).normalized()
	if ribbon_side.length_squared() < 0.01:
		ribbon_side = Vector3.RIGHT
	for ribbon_index in _rainbow_wake_ribbons.size():
		var ribbon := _rainbow_wake_ribbons[ribbon_index]
		ribbon.visible = should_emit
		ribbon.global_basis = Basis.looking_at(_last_motion_direction, Vector3.UP)
		ribbon.scale = Vector3(1.0, 1.0, ribbon_length)
		ribbon.global_position = _train.global_position \
			- _last_motion_direction * (24.0 + ribbon_length * 0.5) \
			+ ribbon_side * (-4.2 + float(ribbon_index) * 1.4) \
			+ Vector3.UP * (2.4 + sin(_mechanism_time * 5.0 \
				+ float(ribbon_index) * 0.72) * 0.34)
	_rainbow_trail_particles.amount_ratio = clampf(0.58 + _movement_vfx_speed_ratio * 0.42, 0.0, 1.0) \
		if should_emit else 0.0
	_gold_trail_particles.amount_ratio = clampf(0.38 + _movement_vfx_speed_ratio * 0.48, 0.0, 0.86) \
		if should_emit else 0.0


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "CrownLineHUD"
	add_child(canvas)
	# Keep private labels as non-rendered state sinks because the driving logic
	# updates their text. The former 520px panel obscured the left side of play.
	_prompt = Label.new()
	_prompt.name = "HiddenDriverPrompt"
	_prompt.visible = false
	canvas.add_child(_prompt)
	_status = Label.new()
	_status.name = "HiddenDriverStatus"
	_status.visible = false
	canvas.add_child(_status)


func _update_prompt() -> void:
	if _prompt == null:
		return
	if _riding:
		if _manual_driving:
			_prompt.text = "YOU ARE DRIVING  •  W/S MOVE  •  R HORN  •  Q EXIT WHEN DOCKED"
		elif _seated_passenger:
			_prompt.text = "SEATED ON THE CROWN LINE  •  Q STAND"
		else:
			_prompt.text = "RAINBOW GALAXY TRAIN  •  MILO IS GUIDING THE CROWN LINE"
		return
	if _player == null:
		_prompt.text = "CROWN LINE  •  Follow the glowing rails to a station"
		return
	var interaction_mode := get_interaction_mode_for_position(_player.global_position)
	if interaction_mode == "drive":
		var target := posmod(_current_station + 1, STATIONS.size())
		_prompt.text = "Q DRIVE  •  W FORWARD  •  S REVERSE  •  %s NEXT" % STATIONS[target].title
		return
	if interaction_mode == "sit":
		_prompt.text = "Q SIT AND RIDE  •  WALK TO THE CAB TO DRIVE"
		return
	if _player.global_position.distance_to(_boarding_position(_current_station)) > INTERACTION_RANGE:
		_prompt.text = "CROWN LINE  •  Walk onto a coach to sit or enter the cab to drive"
		return
	var target := posmod(_current_station + _direction, STATIONS.size())
	if is_station_unlocked(target):
		_prompt.text = "Q  BOARD DRIVER DECK  •  W FORWARD  •  S REVERSE  •  %s NEXT" \
			% STATIONS[target].title
	else:
		_prompt.text = _locked_message(target)


func _locked_message(target: int) -> String:
	if target == 2:
		return "HEART MELODY IS LOCKED  •  Earn the Star of Wisdom in Mind Spark"
	if target == 3:
		return "CREATOR'S LIGHT IS LOCKED  •  Earn the Harmony Jewel in Heart Melody"
	return "THIS STATION HAS NOT AWAKENED YET"


func _try_depart() -> bool:
	var target := posmod(_current_station + _direction, STATIONS.size())
	if not is_station_unlocked(target):
		_status.text = _locked_message(target)
		return false
	_ride_to(target)
	return true


func _ride_to(target: int) -> void:
	if _riding:
		return
	_riding = true
	_status.text = "%s → %s" % [STATIONS[_current_station].title, STATIONS[target].title]
	if _player != null:
		_player.call("set_input_enabled", false)
		_player.velocity = Vector3.ZERO
		_player.global_position = _train.to_global(BENCH_SEATS[0])
	var forward := posmod(_current_station + 1, STATIONS.size()) == target
	var segment_index := _current_station if forward else target
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(progress: float) -> void:
		_set_train_progress(segment_index, progress if forward else 1.0 - progress), 0.0, 1.0, ride_duration)
	await tween.finished
	_current_station = target
	_train.position = STATIONS[_current_station].position
	_orient_train_at_station(_current_station)
	if _player != null:
		_player.global_position = to_global(STATIONS[_current_station].position + Vector3(25.0, 2.0, 0.0))
		_player.velocity = Vector3.ZERO
		_player.call("set_input_enabled", true)
	_end_ride_camera()
	_status.text = "ARRIVED  •  Explore %s" % STATIONS[_current_station].title
	_riding = false


func _set_train_progress(segment_index: int, progress: float) -> void:
	var curve := _curves[segment_index]
	var length := curve.get_baked_length()
	var distance := length * clampf(progress, 0.0, 1.0)
	var point := curve.sample_baked(distance)

	# Aim from a point behind the train to one ahead of it, rather than from the
	# train's own position to a fixed 2 m ahead. At speed the train covers up to
	# 5.5 m per frame, so a 2 m lookahead was shorter than one step: successive
	# frames sampled inconsistent parts of the baked curve and the heading
	# snapped in ~5 degree jumps while the mean turn was only 0.29 degrees. A
	# span the length of the train reads the curve's actual tangent instead.
	const AIM_SPAN := 12.0
	var behind := curve.sample_baked(clampf(distance - AIM_SPAN, 0.0, length))
	var ahead := curve.sample_baked(clampf(distance + AIM_SPAN, 0.0, length))

	_train.position = point
	var direction := ahead - behind
	if direction.length_squared() > 0.01:
		var target_basis := Basis.looking_at(direction.normalized(), Vector3.UP)
		# Ease into the new heading so any residual step in the sampled tangent
		# arrives as a turn rather than a snap. Framerate-independent so the ride
		# feels the same whether the browser build runs at 30 or 60 fps.
		var blend := 1.0 - pow(0.0001, get_process_delta_time())
		_train.basis = _train.basis.slerp(target_basis, clampf(blend, 0.0, 1.0)) \
			if _manual_driving else target_basis
	if _player != null:
		var rider_offset := DRIVER_SEAT
		if _seated_passenger and _passenger_seat_index >= 0:
			rider_offset = BENCH_SEATS[_passenger_seat_index]
		elif not _manual_driving:
			rider_offset = BENCH_SEATS[0]
		_player.global_position = _train.to_global(rider_offset)


func _orient_train_at_station(station_index: int) -> void:
	if _train == null or _curves.is_empty():
		return
	var direction := Vector3.FORWARD
	var curve: Curve3D = _curves[posmod(station_index, _curves.size())]
	direction = curve.sample_baked(2.0) - curve.sample_baked(0.0)
	if direction.length_squared() > 0.01:
		_train.basis = Basis.looking_at(direction.normalized(), Vector3.UP)


func _refresh_station_lights() -> void:
	for index in _station_nodes.size():
		var station := _station_nodes[index]
		var unlocked := is_station_unlocked(index)
		var beacon := station.get_node_or_null("UnlockBeacon") as OmniLight3D
		var sign := station.get_node_or_null("StationSign") as Label3D
		if beacon != null:
			beacon.light_color = Color("5de7ff") if unlocked else Color("635a79")
			beacon.light_energy = 5.0 if unlocked else 0.7
		if sign != null:
			sign.modulate = Color("f8e8ff") if unlocked else Color("777184")


func _add_segment_box(parent: Node3D, node_name: String, start: Vector3, finish: Vector3,
		cross_section: Vector2, material: Material, collision: bool = false) -> void:
	var direction := finish - start
	if direction.length() < 0.01:
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(cross_section.x, cross_section.y, direction.length())
	mesh_instance.mesh = mesh
	mesh_instance.position = (start + finish) * 0.5
	mesh_instance.rotation.y = atan2(direction.x, direction.z)
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	if collision:
		var body := StaticBody3D.new()
		body.name = "%sCollision" % node_name
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		shape_node.shape = shape
		body.add_child(shape_node)
		body.position = mesh_instance.position
		body.rotation = mesh_instance.rotation
		parent.add_child(body)


func _add_box(parent: Node3D, node_name: String, position_value: Vector3, size: Vector3,
		material: Material, collision: bool = false, rotation_x: float = 0.0,
		rotation_y: float = 0.0) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position_value
	instance.rotation = Vector3(rotation_x, rotation_y, 0.0)
	instance.material_override = material
	parent.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.name = "%sCollision" % node_name
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
		body.position = position_value
		body.rotation = Vector3(rotation_x, rotation_y, 0.0)
		parent.add_child(body)


func _add_cylinder(parent: Node3D, node_name: String, position_value: Vector3,
		radius: float, height: float, material: Material, collision: bool,
		segments: int = 32, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	instance.mesh = mesh
	instance.position = position_value
	instance.rotation_degrees = rotation_value
	instance.material_override = material
	parent.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		var shape_node := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		shape_node.shape = shape
		body.add_child(shape_node)
		body.position = position_value
		parent.add_child(body)


func _add_faceted_floating_island(parent: Node3D) -> void:
	const SEGMENTS := 24
	var ring_radii: Array[float] = [34.0, 34.0, 28.0, 20.0, 11.5]
	var ring_heights: Array[float] = [-3.0, -5.2, -9.6, -15.4, -21.2]
	var ring_rotations: Array[float] = [0.0, PI / 24.0, 0.0, PI / 24.0, 0.0]
	var palette: Array[Color] = [
		Color("a9bdd1"), Color("8fa8c1"), Color("7893af"),
		Color("6885a4"), Color("567493"), Color("92aec7"),
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band_index in ring_radii.size() - 1:
		for segment_index in SEGMENTS:
			var angle_a := TAU * float(segment_index) / float(SEGMENTS)
			var angle_b := TAU * float(segment_index + 1) / float(SEGMENTS)
			var top_a := Vector3(
				cos(angle_a + ring_rotations[band_index]) * ring_radii[band_index],
				ring_heights[band_index],
				sin(angle_a + ring_rotations[band_index]) * ring_radii[band_index])
			var top_b := Vector3(
				cos(angle_b + ring_rotations[band_index]) * ring_radii[band_index],
				ring_heights[band_index],
				sin(angle_b + ring_rotations[band_index]) * ring_radii[band_index])
			var bottom_a := Vector3(
				cos(angle_a + ring_rotations[band_index + 1]) * ring_radii[band_index + 1],
				ring_heights[band_index + 1],
				sin(angle_a + ring_rotations[band_index + 1]) * ring_radii[band_index + 1])
			var bottom_b := Vector3(
				cos(angle_b + ring_rotations[band_index + 1]) * ring_radii[band_index + 1],
				ring_heights[band_index + 1],
				sin(angle_b + ring_rotations[band_index + 1]) * ring_radii[band_index + 1])
			var color_a := palette[(band_index * 2 + segment_index) % palette.size()]
			var color_b := palette[(band_index * 2 + segment_index + 2) % palette.size()]
			if (band_index + segment_index) % 2 == 0:
				_add_colored_surface_triangle(surface, top_a, bottom_a, bottom_b, color_a)
				_add_colored_surface_triangle(surface, top_a, bottom_b, top_b, color_b)
			else:
				_add_colored_surface_triangle(surface, top_a, bottom_a, top_b, color_a)
				_add_colored_surface_triangle(surface, top_b, bottom_a, bottom_b, color_b)
	var tip := Vector3(0.0, -27.0, 0.0)
	var last_ring := ring_radii.size() - 1
	for segment_index in SEGMENTS:
		var angle_a := TAU * float(segment_index) / float(SEGMENTS)
		var angle_b := TAU * float(segment_index + 1) / float(SEGMENTS)
		var ring_a := Vector3(cos(angle_a) * ring_radii[last_ring],
			ring_heights[last_ring], sin(angle_a) * ring_radii[last_ring])
		var ring_b := Vector3(cos(angle_b) * ring_radii[last_ring],
			ring_heights[last_ring], sin(angle_b) * ring_radii[last_ring])
		_add_colored_surface_triangle(surface, ring_a, tip, ring_b,
			palette[(segment_index + 3) % palette.size()])
	surface.generate_normals()
	var mesh := surface.commit()
	var material := _material(Color.WHITE, 0.88)
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.name = "TriangulatedSuspendedIsland"
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)


func _add_colored_surface_triangle(surface: SurfaceTool, a: Vector3,
		b: Vector3, c: Vector3, color: Color) -> void:
	for vertex in [a, b, c]:
		surface.set_color(color)
		surface.add_vertex(vertex)


func _add_tapered_cylinder(parent: Node3D, node_name: String,
		position_value: Vector3, top_radius: float, bottom_radius: float,
		height: float, material: Material, segments: int) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = material
	parent.add_child(instance)


func _add_torus(parent: Node3D, node_name: String, position_value: Vector3,
		inner_radius: float, outer_radius: float, material: Material,
		rotation_value: Vector3 = Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 32
	mesh.ring_segments = 8
	instance.mesh = mesh
	instance.position = position_value
	instance.rotation_degrees = rotation_value
	instance.material_override = material
	parent.add_child(instance)


func _leaf_petal_mesh(length: float, width: float, thickness: float) -> ArrayMesh:
	# A faceted double-point leaf prism gives the low-poly roof a deliberate
	# architectural silhouette, unlike scaling a sphere into a cyan capsule.
	var half_length := length * 0.5
	var half_width := width * 0.5
	var half_height := thickness * 0.5
	var points := PackedVector3Array([
		Vector3(-half_length, half_height, 0.0),
		Vector3(0.0, half_height, -half_width),
		Vector3(half_length, half_height, 0.0),
		Vector3(0.0, half_height, half_width),
		Vector3(-half_length, -half_height, 0.0),
		Vector3(0.0, -half_height, -half_width),
		Vector3(half_length, -half_height, 0.0),
		Vector3(0.0, -half_height, half_width),
	])
	var triangles := PackedInt32Array([
		0, 3, 2, 0, 2, 1,
		4, 5, 6, 4, 6, 7,
		0, 1, 5, 0, 5, 4,
		1, 2, 6, 1, 6, 5,
		2, 3, 7, 2, 7, 6,
		3, 0, 4, 3, 4, 7,
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point_index in triangles:
		surface.set_color(Color.WHITE)
		surface.add_vertex(points[point_index])
	surface.generate_normals()
	return surface.commit()


func _material(color: Color, roughness: float, emission: Color = Color.BLACK,
		energy: float = 0.0, transparent: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
