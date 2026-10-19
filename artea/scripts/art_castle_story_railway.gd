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
	# Heart's track runs east-west, so its landing is 200 m off the north side,
	# square to the track (not along it, where the train comes in).
	{"id": "heart", "title": "HEART MELODY", "subtitle": "EAST FLOATING STATION", "position": Vector3(1700.0, ROUTE_HEIGHT, 7640.0), "landing": Vector3(1722.4, 2.0, 7838.7)},
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
const DRIVER_INTERACTION_RANGE := 12.0
const SEAT_INTERACTION_RANGE := 7.5
const FLEXIBLE_BOARDING_RANGE := 14.0
# Seat points are where the player capsule's CENTRE is placed, so they sit a
# capsule half-height above the bench top (JumpBench spans y 0.65..2.65) rather
# than on it. At the old y=3.0 the character's feet ended up level with the
# cushion and it read as standing on the bench instead of sitting in it.
const BENCH_SEATS := [
	Vector3(-2.4, 3.45, 2.8), Vector3(0.0, 3.45, 2.8), Vector3(2.4, 3.45, 2.8),
	Vector3(-2.4, 3.45, 17.8), Vector3(0.0, 3.45, 17.8), Vector3(2.4, 3.45, 17.8),
]
# BENCH_SEATS is the old hand-placed layout. The live seats are built from the
# train model's benches (_build_rider_seats); these points remain only as the
# fallback when the model is missing, and to keep seat 0 where it always was.
#
# The engine's open cab has two seats, measured from the train model in
# train-local space (cushion centre at the cushion top). They share the
# Seat_Navy surface with the cab controls, so they are not derived like the
# benches. Both face forward (-Z): the driver takes the first, Milo the second.
const CAB_SEATS := [Vector3(0.55, 3.26, -15.1), Vector3(-0.55, 3.26, -15.1)]
# How far the player's capsule centre sits above a cushion top, and where
# Milo's origin goes relative to a seat (seat-local: +Z is the way he faces).
# Tuned against renders so both read as sitting on the cushion.
const RIDER_SEAT_LIFT := 0.0
const MILO_SEAT_OFFSET := Vector3(0.0, 0.0, 0.0)
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
var _rider_anchor: RemoteTransform3D
var _milo_anchor: RemoteTransform3D
# Train-local seat transforms (origin where the rider goes, +Z the way they
# face) built from the model's benches, the bench each belongs to, and the cab.
var _passenger_seats: Array[Transform3D] = []
var _passenger_seat_bench: Array[int] = []
var _bench_boxes: Array[AABB] = []
var _driver_seat := Transform3D()
var _codriver_seat := Transform3D()
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
var _steam_rod_parts: Array[Node3D] = []
var _steam_pressure_parts: Array[Node3D] = []
var _steam_valve_parts: Array[Node3D] = []
var _steam_exhaust_particles: GPUParticles3D
var _celestial_halo_parts: Array[Node3D] = []
var _brake_needles: Array[Node3D] = []
var _island_power_rotors: Array[Node3D] = []
var _island_power_lights: Array[OmniLight3D] = []
var _mechanism_time := 0.0
var _prompt: Label
var _status: Label
var _controls_panel: PanelContainer
var _rail_material: ShaderMaterial
var _gold_material: StandardMaterial3D
var _glass_material: StandardMaterial3D
var _stone_material: Material
var _nature_material: StandardMaterial3D
var _violet_material: StandardMaterial3D
var _canopy_material: StandardMaterial3D
var _dark_metal_material: Material
var _station_rainbow_materials: Array[StandardMaterial3D] = []
var _external_drive_commanded := false
var _station_fall_recovery := -1
var _island_rescue_cooldown := 0.0
# Station node -> station-local safe point at the foot of its arrival stairs.
var _station_safe_points := {}
# How far below a station platform a falling player drops before Milo catches
# them. Matches milo_fall_rescue.gd's RESCUE_DROP. The general rescue cannot
# cover stations alone: the ground 35 m below counts as a floor, so it would
# let the player land there.
const STATION_RESCUE_DROP := 16.0
# Seconds before a player still on a station island can be rescued again.
const ISLAND_RESCUE_COOLDOWN := 3.0


func get_station_disembark_position(index: int) -> Vector3:
	var platform := _station_nodes[posmod(index, STATIONS.size())].get_node("WalkablePlatform") as Node3D
	return platform.to_global(Vector3(8.75, 3.0, 0.0))


func _place_player_on_station() -> void:
	_player.global_position = get_station_disembark_position(_current_station)
	_player.velocity = Vector3.ZERO
	_station_fall_recovery = _current_station


func _physics_process(delta: float) -> void:
	if _player == null or _riding:
		return
	# A station's island is solid but has no way back up to the platform, so a
	# player standing on one is brought back to that station's platform. The
	# cooldown lets one rescue finish before another can start; triggering on
	# every frame spent on the island looped the rescue.
	_island_rescue_cooldown = maxf(0.0, _island_rescue_cooldown - delta)
	var island_station := _station_island_under_player()
	if island_station >= 0 and _island_rescue_cooldown <= 0.0:
		_island_rescue_cooldown = ISLAND_RESCUE_COOLDOWN
		_rescue_to_station(island_station)
		return
	# Arm only after reaching an elevated station or its docked train. Walking
	# down the access stairs or leaving the station clears the recovery region.
	for index in _station_nodes.size():
		var platform := _station_nodes[index].get_node("WalkablePlatform") as Node3D
		var local := platform.to_local(_player.global_position)
		if absf(local.x) < 18.0 and absf(local.z) < 34.0 \
				and local.y >= -1.5 and local.y < 16.0:
			_station_fall_recovery = index
			return
	if _station_fall_recovery < 0:
		return
	var platform := _station_nodes[_station_fall_recovery].get_node("WalkablePlatform") as Node3D
	var local := platform.to_local(_player.global_position)
	if _player.is_on_floor() or absf(local.x) > 45.0 or absf(local.z) > 60.0:
		_station_fall_recovery = -1
	elif local.y < -STATION_RESCUE_DROP and _player.velocity.y < 0.0:
		# Milo flies the player back to the platform. Without him (isolated test
		# scenes) the player is put back at the disembark point instead.
		_rescue_to_station(_station_fall_recovery)


## Brings a player who fell off a station (off the platform, or onto its
## island) to that station's safe point at the foot of its stairs. Only
## station falls come here; Milo's general rescue elsewhere is unchanged.
func _rescue_to_station(station_index: int) -> void:
	var station := _station_nodes[station_index]
	var fallback := station.to_global(_station_safe_points[station]) \
		if _station_safe_points.has(station) else get_station_disembark_position(station_index)
	var manager := get_node_or_null("/root/MiloCompanionManager")
	if manager != null and bool(manager.call("request_fall_rescue", fallback)):
		return
	_player.global_position = fallback
	_player.velocity = Vector3.ZERO


## Tags an island's collision body with its station, for the island rescue.
func _mark_station_island(body: Node) -> void:
	var node := body
	while node != null and not _station_nodes.has(node):
		node = node.get_parent()
	if body is StaticBody3D and node != null:
		body.set_meta("station_island", _station_nodes.find(node))


## The station whose island the player is standing on, or -1.
func _station_island_under_player() -> int:
	if not _player.is_on_floor():
		return -1
	for index in _player.get_slide_collision_count():
		var contact := _player.get_slide_collision(index)
		var collider := contact.get_collider()
		if collider != null and collider.has_meta("station_island") \
				and contact.get_normal().y > 0.5:
			return int(collider.get_meta("station_island"))
	return -1


func _ready() -> void:
	_player = get_node_or_null("../../Player3D") as CharacterBody3D
	if _player == null:
		_player = get_node_or_null("../Player3D") as CharacterBody3D
	_build_materials()
	_build_route()
	_build_stations()
	_build_heart_melody_entrance()
	_build_train()
	_build_hud()
	_refresh_station_lights()


func _process(delta: float) -> void:
	_refresh_station_lights()
	if _manual_driving:
		var throttle := Input.get_action_strength("move_forward") \
			- Input.get_action_strength("move_backward")
		if absf(throttle) >= 0.01:
			_advance_manual_drive(throttle, delta)
		elif _external_drive_commanded:
			_external_drive_commanded = false
		else:
			_advance_manual_drive(0.0, delta)
	elif _train != null and not _riding:
		# Keep the docked chassis exactly aligned with the level guideway.
		_train.position.y = ROUTE_HEIGHT
	# sync_to_physics applies the queued platform transform at the frame boundary.
	# Seat the driver from that visible transform before the follow camera runs;
	# relying only on the earlier queued target leaves the camera one frame behind.
	if _manual_driving or (_seated_passenger and _passenger_seat_index >= 0):
		_place_rider()
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
	return _train.to_global(_driver_seat.origin)


func get_nearest_passenger_seat_index(world_position: Vector3) -> int:
	if _train == null:
		return -1
	var nearest_index := -1
	var nearest_distance := SEAT_INTERACTION_RANGE
	for seat_index in _passenger_seats.size():
		var distance := world_position.distance_to(get_passenger_seat_position(seat_index))
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_index = seat_index
	return nearest_index


func get_passenger_seat_count() -> int:
	return _passenger_seats.size()


func get_driver_interaction_range() -> float:
	return DRIVER_INTERACTION_RANGE


func get_seat_interaction_range() -> float:
	return SEAT_INTERACTION_RANGE


func get_flexible_boarding_range() -> float:
	return FLEXIBLE_BOARDING_RANGE


func get_distance_to_train_footprint(world_position: Vector3) -> float:
	if _train == null:
		return INF
	var local := _train.to_local(world_position)
	# Measure from the whole player-facing shell, not one centre point, so 1/2
	# boarding is equally comfortable beside the engine or either coach.
	var closest := Vector3(
		clampf(local.x, -6.4, 6.4),
		clampf(local.y, 0.0, 9.0),
		clampf(local.z, -27.5, 22.0))
	return local.distance_to(closest)


func get_passenger_seat_position(seat_index: int) -> Vector3:
	if _train == null or seat_index < 0 or seat_index >= _passenger_seats.size():
		return Vector3.ZERO
	return _train.to_global(_passenger_seats[seat_index].origin)


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
		+ _reactor_mechanism_parts.size() + _steam_gear_parts.size() \
		+ _steam_rod_parts.size() + _steam_pressure_parts.size() \
		+ _steam_valve_parts.size() + _celestial_halo_parts.size() + _brake_needles.size()


func get_steam_engine_animation_state() -> Dictionary:
	return {
		"gear_count": _steam_gear_parts.size(),
		"rod_count": _steam_rod_parts.size(),
		"pressure_count": _steam_pressure_parts.size(),
		"valve_count": _steam_valve_parts.size(),
		"has_exhaust": _steam_exhaust_particles != null,
		"exhaust_emitting": _steam_exhaust_particles.emitting \
			if _steam_exhaust_particles != null else false,
		"celestial_halo_count": _celestial_halo_parts.size(),
	}


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
		"passenger_seats": _passenger_seats.size(),
		"analog_speed_mechanism": true,
		"closed_loop": true,
		"level_route": true,
		"proximity_interactions": true,
		"driver_interaction_range_m": DRIVER_INTERACTION_RANGE,
		"seat_interaction_range_m": SEAT_INTERACTION_RANGE,
		"flexible_boarding_range_m": FLEXIBLE_BOARDING_RANGE,
		"moving_platform_bodies": 1,
		"collision_mass_model": "infinite-mass animatable platform shells",
		"interaction_rule": "nearest cab or passenger seat",
		"boarding_gates": "centre opening on both sides of both coaches",
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
			if not _passenger_in_motion:
				_ride_seated_passenger_one_station()
			return true
		if _passenger_in_motion:
			_status.text = "PASSENGER RIDE IN PROGRESS  •  SWITCH TO DRIVER AT THE NEXT STATION"
			return false
		leave_passenger_seat()
	elif _riding:
		return false
	elif get_distance_to_train_footprint(_player.global_position) > FLEXIBLE_BOARDING_RANGE:
		return false
	if mode == "drive":
		_player.global_position = get_driver_interaction_position()
		return board_as_driver()
	var closest_seat := 0
	var closest_distance := INF
	for seat_index in _passenger_seats.size():
		var distance := _player.global_position.distance_to(get_passenger_seat_position(seat_index))
		if distance < closest_distance:
			closest_distance = distance
			closest_seat = seat_index
	_player.global_position = get_passenger_seat_position(closest_seat)
	return sit_in_passenger_seat(closest_seat)


func sit_in_passenger_seat(seat_index: int) -> bool:
	if _player == null or _train == null or _riding \
			or seat_index < 0 or seat_index >= _passenger_seats.size():
		return false
	if _player.global_position.distance_to(get_passenger_seat_position(seat_index)) > SEAT_INTERACTION_RANGE:
		return false
	_seated_passenger = true
	_passenger_seat_index = seat_index
	_riding = true
	_player.call("set_input_enabled", false)
	_seat_rider()
	_begin_ride_camera(14.0)
	_status.text = "PASSENGER MODE  •  2 RIDE  •  1 DRIVE AT A STATION  •  Q EXIT AT STATION"
	call_deferred("_ride_seated_passenger_one_station")
	return true


func leave_passenger_seat() -> bool:
	if not _seated_passenger or _player == null or _passenger_in_motion:
		return false
	_unseat_rider()
	_seated_passenger = false
	_passenger_in_motion = false
	_passenger_seat_index = -1
	_riding = false
	_place_player_on_station()
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
		_place_rider()
	_status.text = "DOCKED AT %s  •  Q EXIT AT STATION" % STATIONS[_current_station].title


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
	_seat_rider()
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
	_external_drive_commanded = absf(throttle) >= 0.01
	_advance_manual_drive(throttle, delta)


func _advance_manual_drive(throttle: float, delta: float) -> void:
	if not _manual_driving or _train == null:
		return
	var requested_direction := _drive_motion_direction
	if absf(throttle) >= 0.01:
		requested_direction = 1 if throttle > 0.0 else -1
	var changing_direction := requested_direction != _drive_motion_direction and _display_speed_kph > 0.5
	if not changing_direction and absf(throttle) >= 0.01:
		_drive_motion_direction = requested_direction
	var drive_direction := _drive_motion_direction
	if _drive_segment < 0 and not changing_direction and absf(throttle) >= 0.01:
		if not _begin_manual_segment(drive_direction):
			_display_speed_kph = 0.0
			return
	var target_speed := 0.0 if changing_direction else absf(throttle) * DISPLAY_MAX_SPEED_KPH
	# A held throttle still has to arrive like a train, not hit the station at
	# line speed and teleport to rest. Cap speed by the physical stopping distance
	# so both the platform and its ride camera decelerate continuously into docks.
	if _drive_segment >= 0 and target_speed > 0.0:
		var arrival_curve := _curves[_drive_segment]
		var remaining_progress := 1.0 - _drive_progress \
			if drive_direction > 0 else _drive_progress
		var remaining_distance := maxf(remaining_progress, 0.0) \
			* arrival_curve.get_baked_length()
		var braking_metres_per_second_sq := DISPLAY_BRAKING_KPH_S \
			/ DISPLAY_MAX_SPEED_KPH * MANUAL_DRIVE_SPEED
		var arrival_speed_cap := sqrt(2.0 * braking_metres_per_second_sq \
			* remaining_distance) / MANUAL_DRIVE_SPEED * DISPLAY_MAX_SPEED_KPH
		target_speed = minf(target_speed, arrival_speed_cap)
	var speed_rate := DISPLAY_ACCELERATION_KPH_S if target_speed > _display_speed_kph \
		else DISPLAY_BRAKING_KPH_S
	_display_speed_kph = move_toward(_display_speed_kph, target_speed, speed_rate * maxf(delta, 0.0))
	if _display_speed_kph < 0.05:
		_display_speed_kph = 0.0
		if _player != null:
			_place_rider()
		return
	var curve := _curves[_drive_segment]
	var progress_delta := (_display_speed_kph / DISPLAY_MAX_SPEED_KPH) \
		* MANUAL_DRIVE_SPEED * maxf(delta, 0.0) \
		/ maxf(curve.get_baked_length(), 1.0)
	_drive_progress = clampf(_drive_progress + progress_delta * float(drive_direction), 0.0, 1.0)
	_set_train_progress(_drive_segment, _drive_progress)
	_status.text = "DRIVING  •  %03d KM/H  •  %s  •  W/S MOVE  •  R HORN" \
		% [roundi(_display_speed_kph), _segment_destination_name(drive_direction)]
	# Arrival is the end of travel in the direction of travel, tested against the
	# clamp bounds exactly.
	#
	# is_equal_approx() was wrong here twice over. Its tolerance has an absolute
	# floor of CMP_EPSILON (1e-5) when comparing against zero, and the first
	# frames out of a station move the curve parameter by far less than that --
	# the train is accelerating from rest along a curve hundreds of metres long,
	# so the first non-zero progress measured ~5e-6. That read as "already at
	# progress 0". Testing both ends regardless of direction then made the
	# station just departed count as an arrival, so the train docked back where
	# it started, zeroed its speed, and repeated it the next frame: a held
	# throttle could not leave the platform at all. Which stations trapped it
	# depended on the length of the curve being left, and auto-drive was
	# unaffected because it does not come through here.
	if drive_direction > 0:
		if _drive_progress >= 1.0:
			_dock_manual_train(_drive_segment + 1)
	elif _drive_progress <= 0.0:
		_dock_manual_train(_drive_segment)


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
	# Preserve the continuously interpolated arrival heading. Incoming and
	# outgoing rails share one station tangent, so forcing a fresh basis here is
	# unnecessary and creates a visible final-frame snap on synchronized bodies.
	_train.transform = Transform3D(
		_train.basis, STATIONS[_current_station].position)
	if _player != null:
		_place_rider()
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
	_unseat_rider()
	if _player != null:
		_place_player_on_station()
		_player.call("set_input_enabled", true)
	_end_ride_camera()
	_status.text = "ARRIVED  •  Explore %s" % STATIONS[_current_station].title


func _boarding_position(station_index: int) -> Vector3:
	return to_global(STATIONS[station_index].position + BOARDING_OFFSET)


func station_unlocked_with(index: int, _treasure_flags: Dictionary) -> bool:
	# Railway travel is available from the start; world quests keep their own progress.
	return index >= 0 and index < STATIONS.size()


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
	_station_rainbow_materials.clear()
	for colour in [Color("ff557f"), Color("ff9f43"), Color("ffe66d"),
			Color("5ee58c"), Color("42d9ff"), Color("647dff"), Color("b56cff")]:
		_station_rainbow_materials.append(_material(colour, 0.30, colour, 0.85))


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
		# 0.89, not 0.87: the 0.14 m ribbon's underside then clears the beam
		# top (centre + 0.8) by 2 cm instead of sharing its plane and z-fighting
		# with the cull-disabled rainbow rail shader.
		ribbon_points.append(centre + Vector3.UP * 0.89)
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


## Each station's colour identity: accent and second colour, then paving
## light/dark/grout.
const STATION_PALETTES := {
	"gallery": ["8a5fe0", "f2b134", "d9c7a5", "c9b48e", "8a7350"],
	"mind": ["26c6f0", "3fd68a", "a9c6db", "95b5cc", "4a6a80"],
	"heart": ["f2589e", "f592c0", "e9b6c9", "dba1b7", "9a5f78"],
	"creator": ["ff8a1f", "ffc43d", "eccf98", "dfbd7f", "9a7646"],
}
const StationSurfaceShader := preload("res://shaders/station_surface.gdshader")

var _driver_walk_material: Material
var _passenger_walk_material: Material
var _tactile_material: Material


func _surface_material(pattern: int, base: Color, alt: Color, line: Color, tile: float,
		roughness: float = 0.8, metallic: float = 0.0, glow := Color.BLACK,
		glow_strength := 0.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = StationSurfaceShader
	material.set_shader_parameter("pattern", pattern)
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("alt_color", alt)
	material.set_shader_parameter("line_color", line)
	material.set_shader_parameter("tile_size", tile)
	material.set_shader_parameter("roughness_value", roughness)
	material.set_shader_parameter("metallic_value", metallic)
	material.set_shader_parameter("glow_color", glow)
	material.set_shader_parameter("glow_strength", glow_strength)
	return material


## Swaps the shared station materials for this station's textured palette.
func _apply_station_palette(station_id: String) -> void:
	var palette: Array = STATION_PALETTES[station_id]
	var accent := Color(palette[0])
	var second := Color(palette[1])
	_stone_material = _surface_material(0, Color(palette[2]), Color(palette[3]),
		Color(palette[4]), 1.2, 0.86)
	_dark_metal_material = _surface_material(1, accent.darkened(0.72), accent.darkened(0.5),
		accent.darkened(0.88), 2.0, 0.42, 0.45, accent, 0.6)
	_violet_material = _material(second, 0.32, second, 1.3)
	_glass_material = _material(Color(accent, 0.72), 0.20, accent, 1.6, true)
	_canopy_material = _material(Color(accent, 0.72), 0.3, accent, 0.25, true)
	_driver_walk_material = _surface_material(0, accent, accent.darkened(0.12),
		accent.darkened(0.45), 0.9, 0.85)
	_passenger_walk_material = _surface_material(0, second, second.darkened(0.12),
		second.darkened(0.45), 0.9, 0.85)


func _build_stations() -> void:
	var stations_root := Node3D.new()
	stations_root.name = "StoryStations"
	add_child(stations_root)
	var shared := [_stone_material, _dark_metal_material, _violet_material,
		_glass_material, _canopy_material]
	_tactile_material = _surface_material(2, Color("f5c518"), Color("fff0a0"),
		Color.BLACK, 1.0, 0.9)
	for index in STATIONS.size():
		var info: Dictionary = STATIONS[index]
		_apply_station_palette(String(info.id))
		var station := Node3D.new()
		station.name = "Station_%02d_%s" % [index + 1, info.id]
		station.position = info.position
		# Stations are authored with the track along local Z and the access
		# bridge along local X. A landing off the X axis turns the station so
		# its local -X points at it (the landing must be square to the track).
		var to_landing: Vector3 = info.landing - info.position
		if absf(to_landing.z) > 1.0:
			station.rotation.y = atan2(to_landing.z, -to_landing.x)
		stations_root.add_child(station)
		_station_nodes.append(station)
		_build_station_platform_from_scratch(station, index)
		_build_floating_dock_structure(station)
		if String(info.id) == "mind":
			_build_mind_spark_station_upgrade(station)
		else:
			_build_bio_magitech_pavilion(station)
		var landing_local: Vector3 = station.basis.inverse() * to_landing
		var dock_sign := signf(landing_local.x)
		if is_zero_approx(dock_sign):
			dock_sign = -1.0
		_build_world_access_bridge(station, landing_local, dock_sign)
		_build_train_fit_boarding_layout(station, dock_sign, index)
		var board_label := Label3D.new()
		board_label.name = "BoardTrainSign"
		board_label.text = "1  DRIVE   ✦   2  RIDE\nQ  USE SEAT"
		board_label.position = Vector3(-dock_sign * 22.0, 6.5, 18.0)
		board_label.font_size = 32
		board_label.outline_size = 8
		board_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		board_label.no_depth_test = false
		station.add_child(board_label)
		var beacon := OmniLight3D.new()
		beacon.name = "UnlockBeacon"
		beacon.position = Vector3(0.0, 13.0, 0.0)
		beacon.omni_range = 30.0
		beacon.light_energy = 3.0
		station.add_child(beacon)
		var label := Label3D.new()
		label.name = "StationSign"
		label.text = "%02d  %s\n%s" % [index + 1, info.title, info.subtitle]
		label.position = Vector3(0.0, 20.0, 0.0)
		label.font_size = 46
		label.outline_size = 10
		label.modulate = Color(STATION_PALETTES[info.id][0]).lightened(0.3)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = false
		station.add_child(label)
	# The train and everything after the stations keep the shared materials.
	_stone_material = shared[0]
	_dark_metal_material = shared[1]
	_violet_material = shared[2]
	_glass_material = shared[3]
	_canopy_material = shared[4]


func _build_station_platform_from_scratch(station: Node3D,
		station_index: int) -> void:
	# A twin-platform station matches the actual 54 m train envelope. Local -Z
	# follows the route, leaving a twelve-metre central monorail channel and two
	# independent eight-metre platform foundations.
	var platform := Node3D.new()
	platform.name = "WalkablePlatform"
	platform.basis = station.basis.inverse() * Basis.looking_at(
		get_route_forward_direction_at_station(station_index), Vector3.UP)
	platform.set_meta("design", "twin_train_fit_platform")
	platform.set_meta("platform_length_m", 57.0)
	platform.set_meta("central_train_clearance_m", 12.0)
	platform.set_meta("raised_boarding_top_y", 1.1)
	station.add_child(platform)

	const FOUNDATION_X := 10.0
	const FOUNDATION_WIDTH := 8.0
	const FOUNDATION_LENGTH := 57.0
	const FOUNDATION_CENTRE_Z := -1.5
	const RAISED_BOARDING_X := 8.75
	const RAISED_BOARDING_LENGTH := 40.0
	const RAISED_BOARDING_CENTRE_Z := 4.0
	for side in [-1.0, 1.0]:
		var side_name := "Left" if side < 0.0 else "Right"
		_add_box(platform, "%sStructuralDeck" % side_name,
			Vector3(float(side) * FOUNDATION_X, -2.2, FOUNDATION_CENTRE_Z),
			Vector3(FOUNDATION_WIDTH, 2.0, FOUNDATION_LENGTH),
			_stone_material, true)
		# The 2.3 m riser carries the colored driver/passenger walking surfaces at
		# train-step height instead of leaving those floors floating above the base.
		# Top at 1.08, 2 cm under the 1.1 m driver/passenger walkways laid on
		# it; flush, the two z-fought (the navy/cyan hatching on the platform).
		_add_box(platform, "%sRaisedBoardingBase" % side_name,
			Vector3(float(side) * RAISED_BOARDING_X, -0.06,
				RAISED_BOARDING_CENTRE_Z),
			# 2 cm inside the walkways' footprint on every side, so the base's
			# side and end faces are not in the same planes as theirs.
			Vector3(5.46, 2.28, RAISED_BOARDING_LENGTH - 0.04),
			_dark_metal_material, true)
		_add_segment_box(platform, "%sInnerGoldSafetyEdge" % side_name,
			Vector3(float(side) * 6.0, -1.0, -30.02),
			Vector3(float(side) * 6.0, -1.0, 27.02),
			Vector2(0.28, 0.42), _gold_material)
		_add_segment_box(platform, "%sOuterGoldFascia" % side_name,
			Vector3(float(side) * 14.0, -1.0, -30.02),
			Vector3(float(side) * 14.0, -1.0, 27.02),
			Vector2(0.32, 0.58), _gold_material)
		# Seven non-overlapping eight-metre light panels make the platform itself
		# rainbow while the continuous gold fascia keeps the station hierarchy.
		for colour_index in 7:
			_add_box(platform, "%sRainbowFascia_%02d" % [side_name, colour_index],
				Vector3(float(side) * 14.08, -1.82,
					-25.5 + float(colour_index) * 8.0),
				Vector3(0.16, 0.70, 7.72),
				_station_rainbow_materials[colour_index], false)

	# The lowered service bed makes the single centre rail readable and keeps all
	# station collision outside the train shell. It is intentionally non-walkable.
	_add_box(platform, "CentralMonorailServiceChannel",
		Vector3(0.0, -2.65, -1.5), Vector3(11.5, 0.7, 57.0),
		_dark_metal_material, false)
	_add_segment_box(platform, "LeftChannelLight",
		Vector3(-5.72, -2.18, -30.0), Vector3(-5.72, -2.18, 27.0),
		Vector2(0.20, 0.16), _glass_material)
	_add_segment_box(platform, "RightChannelLight",
		Vector3(5.72, -2.18, -30.0), Vector3(5.72, -2.18, 27.0),
		Vector2(0.20, 0.16), _glass_material)

	# The restored roof uses six columns in the original station axes. Give every
	# column a real plinth and an outrigger back to the twin structural decks.
	var roof_foundations := Node3D.new()
	roof_foundations.name = "OldRoofSupportFoundations"
	station.add_child(roof_foundations)
	for side in [-1.0, 1.0]:
		for support_index in 3:
			var support_z := -14.0 + float(support_index) * 14.0
			var support_position := Vector3(float(side) * 19.0, -1.4, support_z)
			_add_cylinder(roof_foundations,
				"RoofPlinth_%s_%02d" % ["L" if side < 0.0 else "R", support_index],
				support_position, 2.25, 2.8, _stone_material, true, 12)
			_add_torus(roof_foundations,
				"RoofPlinthGoldRing_%s_%02d" % ["L" if side < 0.0 else "R", support_index],
				support_position + Vector3.UP * 1.45, 1.72, 2.10, _gold_material)
			_add_walkway_between(roof_foundations,
				"RoofFoundationOutrigger_%s_%02d" % [
					"L" if side < 0.0 else "R", support_index],
				Vector3(float(side) * 13.5, -1.55, support_z),
				Vector3(float(side) * 17.2, -1.55, support_z),
				2.2, 1.1, _dark_metal_material, true)


func _build_train_fit_boarding_layout(station: Node3D, dock_sign: float,
		station_index: int) -> void:
	# Basis.looking_at aligns local -Z with the train's forward direction. Every
	# boarding surface is therefore authored in train space even though the four
	# stations face different directions around the Crown Line.
	var direction := get_route_forward_direction_at_station(station_index)
	var layout := Node3D.new()
	layout.name = "BoardingLane"
	layout.basis = station.basis.inverse() * Basis.looking_at(direction, Vector3.UP)
	layout.set_meta("aligned_to_train_route", true)
	layout.set_meta("train_clear_width_m", 12.0)
	layout.set_meta("train_clear_length_m", 54.0)
	station.add_child(layout)

	# The train shell is 12 m wide. These 5.5 m side platforms begin exactly at
	# x=+/-6 m, flush with its boarding steps, and never overlap its collision.
	# The forward violet section reaches the first-coach cab; the longer cyan
	# section serves the two passenger-coach gates at z=0 and z=15.
	for side in [-1.0, 1.0]:
		var side_name := "Left" if side < 0.0 else "Right"
		_add_box(layout, "DriverWalkway%s" % side_name,
			Vector3(float(side) * 8.75, 0.8, -7.0), Vector3(5.5, 0.6, 18.0),
			_driver_walk_material, true)
		# Starts 2 cm after the driver walkway ends, so the two do not share an
		# end face.
		_add_box(layout, "PassengerWalkway%s" % side_name,
			Vector3(float(side) * 8.75, 0.8, 13.01), Vector3(5.5, 0.6, 21.98),
			_passenger_walk_material, true)
		# Tactile warning band just inside the track-side fence (7.4 m), 3 cm
		# proud of the walkway so it never z-fights it.
		_add_box(layout, "TactileEdge%s" % side_name,
			Vector3(float(side) * 7.95, 1.115, 4.0), Vector3(0.7, 0.03, 39.9),
			_tactile_material, false)
		# Boarding bridges sit 4 cm below the walkway tops they overlap (and 2 cm
		# below the raised base top at 1.08).
		_add_box(layout, "DriverBoardingBridge%s" % side_name,
			Vector3(float(side) * 6.0, 0.76, 0.0), Vector3(1.2, 0.6, 4.2),
			_gold_material, true)
		_add_box(layout, "PassengerBoardingBridge%s" % side_name,
			Vector3(float(side) * 6.0, 0.76, 15.0), Vector3(1.2, 0.6, 4.2),
			_gold_material, true)

	# Join the top of the arrival stair to the nearest train-side platform. The
	# connector is calculated in route space, so it never asks the player to walk
	# across the train or centre monorail to reach a boarding gate.
	var stair_top_station := Vector3(7.5 * dock_sign, 1.1, 0.0)
	var stair_top_local := layout.transform.affine_inverse() * stair_top_station
	var access_side := signf(stair_top_local.x)
	if is_zero_approx(access_side):
		access_side = dock_sign
	var access_target := Vector3(access_side * 8.75, 1.1,
		clampf(stair_top_local.z, -14.5, 23.5))
	_add_walkway_between(layout, "EntranceToTrainWalkway", stair_top_local,
		access_target, 4.6, 0.6, _gold_material, true)

	_add_boarding_zone_label(layout, "DriverZoneSign",
		"DRIVER  •  1", Vector3(access_side * 11.9, 4.0, -7.0), Color("ffd45a"))
	_add_boarding_zone_label(layout, "PassengerZoneSign",
		"RIDING  •  2", Vector3(access_side * 11.9, 4.0, 13.0), Color("72eaff"))
	_build_platform_guardrails(station, layout.basis, access_side, access_target.z,
		dock_sign)
	_build_track_overpass(layout)


## A footbridge over the track behind the parked train, so a player who steps
## off on the far platform reaches the exit side without crossing the train.
## Route space: x across the track, z along it (rear of the platforms is +z).
func _build_track_overpass(layout: Node3D) -> void:
	const RAMP_X := 9.45
	const RAMP_WIDTH := 3.7
	const FOOT_Z := 24.0 # PassengerWalkway rear end
	# 17 degree ramps up to a deck whose underside (15.4 m) clears the train's
	# tallest part (14 m above the platform origin).
	const DECK_Z := 72.0
	const DECK_DEPTH := 4.0
	const FOOT_Y := 1.1
	const DECK_Y := 16.0
	const RAIL_HEIGHTS := [1.15, 2.35]
	var overpass := Node3D.new()
	overpass.name = "TrackOverpass"
	layout.add_child(overpass)
	var outer := RAMP_X + RAMP_WIDTH * 0.5 - 0.15
	var inner := RAMP_X - RAMP_WIDTH * 0.5 + 0.15
	for side in [-1.0, 1.0]:
		var side_name := "Left" if side < 0.0 else "Right"
		var foot := Vector3(float(side) * RAMP_X, FOOT_Y, FOOT_Z)
		var top := Vector3(float(side) * RAMP_X, DECK_Y, DECK_Z)
		_add_surface_ramp_mesh(overpass, "%sOverpassRamp" % side_name, foot, top,
			RAMP_WIDTH, 0.5, _dark_metal_material)
		_add_surface_ramp_collision(overpass, "%sOverpassRamp" % side_name, foot, top,
			RAMP_WIDTH, 0.5)
		_add_surface_ramp_mesh(overpass, "%sOverpassGlowStrip" % side_name,
			foot + Vector3.UP * 0.04, top + Vector3.UP * 0.04, 0.9, 0.06, _glass_material)
		for x in [inner, outer]:
			for h in RAIL_HEIGHTS:
				_add_walkway_between(overpass, "%sOverpassRampRail" % side_name,
					Vector3(float(side) * x, FOOT_Y + float(h), FOOT_Z),
					Vector3(float(side) * x, DECK_Y + float(h), DECK_Z),
					0.3, 0.3, _gold_material, true)
		# The deck's ends, beside each ramp's top.
		for h in RAIL_HEIGHTS:
			_add_walkway_between(overpass, "%sOverpassEndRail" % side_name,
				Vector3(float(side) * outer, DECK_Y + float(h), DECK_Z),
				Vector3(float(side) * outer, DECK_Y + float(h), DECK_Z + DECK_DEPTH),
				0.3, 0.3, _gold_material, true)
	_add_box(overpass, "OverpassDeck",
		Vector3(0.0, DECK_Y - 0.3, DECK_Z + DECK_DEPTH * 0.5),
		Vector3(outer * 2.0 + 0.3, 0.6, DECK_DEPTH), _dark_metal_material, true)
	_add_box(overpass, "OverpassDeckGlowStrip",
		Vector3(0.0, DECK_Y + 0.03, DECK_Z + DECK_DEPTH * 0.5),
		Vector3(outer * 2.0, 0.06, 0.9), _glass_material, false)
	for h in RAIL_HEIGHTS:
		# Far rail spans the whole deck; the near one stops at the ramp openings.
		_add_walkway_between(overpass, "OverpassFarRail",
			Vector3(-outer, DECK_Y + float(h), DECK_Z + DECK_DEPTH - 0.15),
			Vector3(outer, DECK_Y + float(h), DECK_Z + DECK_DEPTH - 0.15),
			0.3, 0.3, _gold_material, true)
		_add_walkway_between(overpass, "OverpassNearRail",
			Vector3(-inner, DECK_Y + float(h), DECK_Z + 0.15),
			Vector3(inner, DECK_Y + float(h), DECK_Z + 0.15),
			0.3, 0.3, _gold_material, true)
	_add_boarding_zone_label(overpass, "OverpassSign", "⇄  OTHER PLATFORM",
		Vector3(0.0, DECK_Y + 4.0, DECK_Z + DECK_DEPTH * 0.5), Color("72eaff"))


func _add_boarding_zone_label(parent: Node3D, node_name: String, text_value: String,
		position_value: Vector3, colour: Color) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text_value
	label.position = position_value
	label.font_size = 30
	label.outline_size = 8
	label.modulate = colour
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	parent.add_child(label)


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

	# The original split-wing roof uses twelve large cyan solar-glass leaves with
	# sand-gold outlines and an open centre above the train.
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
	# Same rule as the pavilion: no column standing on a platform or ramp.
	var to_route := (station.get_node("WalkablePlatform") as Node3D).transform.affine_inverse()
	for side in [-1.0, 1.0]:
		for support_index in 3:
			var z := -14.0 + float(support_index) * 14.0
			var x := float(side) * 19.0
			if _in_train_corridor(to_route, Vector3(x, 1.0, z)):
				continue
			_add_cylinder(restored_supports,
				"RestoredLivingColumn_%s_%02d" % [
					"L" if side < 0 else "R", support_index],
				Vector3(x, 5.2, z), 0.75, 10.4, _nature_material, false, 8)
			_add_cylinder(restored_supports,
				"RestoredEngineeringCollar_%s_%02d" % [
					"L" if side < 0 else "R", support_index],
				Vector3(x, 9.2, z), 1.15, 0.65, _gold_material, false, 12)

	# Four outer wayfinding pylons retain the Mind Spark skyline without turning
	# the platform rim into a wall of repeated monoliths.
	var monoliths := Node3D.new()
	monoliths.name = "CircuitMonolithGarden"
	upgrade.add_child(monoliths)
	var monolith_angles := [-2.35, -0.80, 0.80, 2.35]
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
		37.2, 0.30, floor_blue, true, 32)
	_mark_station_island(ground.get_child(ground.get_child_count() - 1))
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
	# Solid: it reads as the station's ground, and a player who slips off the
	# platform or through the train lands on it instead of falling through. The
	# station rescue in _physics_process brings them back up from there.
	_add_cylinder(structure, "SuspendedFoundation", Vector3(0, -8.0, 0), 32.0, 10.0,
		_stone_material, true, 16)
	_mark_station_island(structure.get_child(structure.get_child_count() - 1))
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
	# Restore the original twelve-leaf split-wing roof while preserving the open
	# central slot above the monorail and moving train.
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
	# Branching columns sit outside the 15 m boarding lane. Their gold collars
	# show where the living structure connects to engineered roof modules.
	var supports := Node3D.new()
	supports.name = "BranchingSupportColumns"
	pavilion.add_child(supports)
	# Where the track crosses the station at an angle a column can land on a
	# platform or the overpass ramp foot, where the player walked through it.
	var to_route := (station.get_node("WalkablePlatform") as Node3D).transform.affine_inverse()
	for side in [-1.0, 1.0]:
		for support_index in 3:
			var z := -14.0 + float(support_index) * 14.0
			var x := float(side) * 19.0
			if _in_train_corridor(to_route, Vector3(x, 1.0, z)):
				continue
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
	# A high energy ring identifies the Crown Line without adding a portal or
	# centre mast in front of the train.
	_add_torus(pavilion, "CanopyEnergyRing", Vector3(0.0, 12.1, 1.5),
		8.35, 8.8, _gold_material)
	for side in [-1.0, 1.0]:
		for planter_index in 2:
			var planter_z := -12.0 + float(planter_index) * 24.0
			_build_crystal_planter(pavilion,
				"CrystalPlanter_%s_%02d" % ["L" if side < 0 else "R", planter_index],
				Vector3(float(side) * 27.0, 0.2, planter_z))
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
		# Visual treads only (the ramp carries the player), so drop them 5 cm:
		# flush, the top tread z-fought the walkway (1.1); 5 cm also clears the
		# raised base top (1.08) beneath it.
		var top_y := lerpf(STAIR_BOTTOM_TOP_Y, STAIR_TOP_TOP_Y, ratio) - 0.05
		var x := lerpf(stair_start_x, stair_end_x, ratio)
		_add_box(stairs, "DockStep_%02d" % (index + 1),
			Vector3(x, top_y - TREAD_THICKNESS * 0.5, -SIDE_STAIR_Z),
			Vector3(STEP_DEPTH, TREAD_THICKNESS, SIDE_STAIR_WIDTH), _stone_material, false)
		_add_box(stairs, "DockStepRight_%02d" % (index + 1),
			Vector3(x, top_y - TREAD_THICKNESS * 0.5, SIDE_STAIR_Z),
			Vector3(STEP_DEPTH, TREAD_THICKNESS, SIDE_STAIR_WIDTH), _stone_material, false)
	var ramp_start := Vector3(stair_start_x + dock_sign * STEP_DEPTH * 0.5,
		STAIR_BOTTOM_TOP_Y - 0.04, 0.0)
	# Where Milo brings a player who fell off this station: the foot of its
	# arrival stairs, beside the station but outside its island.
	_station_safe_points[station] = ramp_start + Vector3.UP * 1.2
	# Reach platform height before its rotated outer edge crosses the access lane.
	# Continuing the old slope through that edge left a short riser in the centre
	# lane; the platform collision then deflected an ordinary straight walk into
	# the side guards. The level upper landing clears that seam without a jump.
	var ramp_plateau_start := Vector3(stair_end_x + dock_sign * 7.0,
		STAIR_TOP_TOP_Y + 0.16, 0.0)
	var ramp_finish := Vector3(stair_end_x - dock_sign * STEP_DEPTH * 0.5,
		STAIR_TOP_TOP_Y + 0.16, 0.0)
	_add_surface_ramp_mesh(stairs, "CentralAccessRamp", ramp_start, ramp_plateau_start,
		CENTRAL_RAMP_WIDTH, 0.24, _dark_metal_material)
	_add_surface_ramp_mesh(stairs, "CentralAccessLanding", ramp_plateau_start, ramp_finish,
		CENTRAL_RAMP_WIDTH, 0.24, _dark_metal_material)
	# 0.18 lift, not 0.15: at 0.15 the conduit top (1.41) shared the plane of
	# the guard rails' LowerRail tops it runs through and sat 1 cm over the gold
	# entrance walkway (1.40), and both z-fought.
	_add_surface_ramp_mesh(stairs, "CrystalEnergyConduit",
		ramp_start + Vector3.UP * 0.18, ramp_plateau_start + Vector3.UP * 0.18,
		1.05, 0.08, _glass_material)
	_add_surface_ramp_mesh(stairs, "CrystalEnergyLandingConduit",
		ramp_plateau_start + Vector3.UP * 0.18, ramp_finish + Vector3.UP * 0.18,
		1.05, 0.08, _glass_material)
	# One convex body carries the complete landing-to-platform route. Two boxes
	# that only touched at the stair foot exposed an internal end face, so the
	# player stopped at the exact bridge/stair seam despite both tops lining up.
	_add_combined_access_collision(stairs, "WalkableStairRamp",
		access_landing_surface,
		Vector3(stair_start_x + dock_sign * STEP_DEPTH * 0.5,
			STAIR_BOTTOM_TOP_Y - 0.10, 0.0),
		Vector3(ramp_plateau_start.x, STAIR_TOP_TOP_Y + 0.10, 0.0),
		Vector3(stair_end_x - dock_sign * STEP_DEPTH * 0.5,
			STAIR_TOP_TOP_Y + 0.10, 0.0), 15.6, 0.42)
	# Open rails replace the previous 2.6 m solid yellow walls, which filled the
	# camera and visually hid the stairs in the Web build.
	# The stairs follow the station's axes but the track crosses each station at
	# an angle, so the rails' upper ends ran into the docked train, and across
	# the far platform where they blocked the overpass ramp. Stop every rail at
	# the platform's outer fence and drop posts that would stand inside it.
	var to_route := (station.get_node("WalkablePlatform") as Node3D).transform.affine_inverse()
	for side in [-1.0, 1.0]:
		var side_z := float(side) * 7.55
		for post_index in 7:
			var ratio := float(post_index) / 6.0
			var x := lerpf(stair_start_x, stair_end_x, ratio)
			var tread_y := lerpf(STAIR_BOTTOM_TOP_Y, STAIR_TOP_TOP_Y, ratio)
			if _in_train_corridor(to_route, Vector3(x, tread_y, side_z)):
				continue
			_add_box(stairs, "StairRailPost", Vector3(x, tread_y + 1.25, side_z),
				Vector3(0.38, 2.5, 0.38), _gold_material, true)
		var rail_start := Vector3(stair_start_x, STAIR_BOTTOM_TOP_Y + 2.15, side_z)
		var rail_finish := _clip_out_of_train_corridor(to_route, rail_start,
			Vector3(stair_end_x, STAIR_TOP_TOP_Y + 2.15, side_z))
		_add_walkway_between(stairs,
			"StairGuardLeft" if side < 0 else "StairGuardRight",
			rail_start, rail_finish, 0.38, 0.38, _gold_material, true)
	# No inner handrails between the side stairs and the centre ramp: they were
	# visual only, and read as two stray yellow lines down the ramp.


## True when a station-local point lies on the train, the twin platforms or
## the overpass ramps behind them: within the 11.5 m outer fences, from the
## train's front to the overpass deck.
func _in_train_corridor(to_route: Transform3D, station_point: Vector3) -> bool:
	var p := to_route * station_point
	return absf(p.x) < 11.6 and p.z > -30.0 and p.z < 77.0


## Pull `finish` back towards `start` until the rail stays out of the train
## corridor. Returns `finish` unchanged when the rail never enters it.
func _clip_out_of_train_corridor(to_route: Transform3D, start: Vector3,
		finish: Vector3) -> Vector3:
	const SAMPLES := 200
	for i in SAMPLES + 1:
		var t := float(i) / float(SAMPLES)
		if _in_train_corridor(to_route, start.lerp(finish, t)):
			return start.lerp(finish, maxf(0.0, t - 1.0 / float(SAMPLES)))
	return finish


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
		landing_surface: Vector3, foot_surface: Vector3, plateau_surface: Vector3,
		top_surface: Vector3,
		width: float, _thickness: float) -> void:
	var body := StaticBody3D.new()
	body.name = "%sCollision" % node_name
	var shape_node := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	var surfaces := [landing_surface, foot_surface, plateau_surface, top_surface]
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


func _build_platform_guardrails(station: Node3D, route_basis: Basis,
		access_side: float, access_z: float, station_access_side: float) -> void:
	# Every barrier has one safety job and shares its corner posts with adjoining
	# sections. The inner rails protect the empty track/engine area while their
	# two deliberate gaps line up with the train's driver and passenger steps.
	# The collision shell is 6 m from centre, but the textured train body reaches
	# 6.4 m at rail height. At x=6.8 the rail's inner face (6.64) all but touched
	# it; at 7.4 it clears the body by ~0.84 m and leaves a 4.1 m walkway.
	const INNER_EDGE_X := 7.40
	const OUTER_EDGE_X := 11.50
	const PLATFORM_FRONT_Z := -16.0
	const PLATFORM_REAR_Z := 24.0
	# 6.4 m openings (were 4.6 m) so the player can step through without
	# snagging on the gate posts; the 4.2 m boarding bridges sit well inside.
	const DRIVER_GATE_HALF_LENGTH := 3.2
	const PASSENGER_GATE_Z := 15.0
	const PASSENGER_GATE_HALF_LENGTH := 3.2
	const ENTRANCE_GATE_HALF_LENGTH := 2.6
	# Preserve the direct opening marker used by traversal checks and older scene
	# integrations. The detailed guard sections now live under PlatformGuard*,
	# but this node still identifies which outer side owns the entrance gap.
	var entrance_marker := Node3D.new()
	entrance_marker.name = "PlatformGuardLeftFront" \
		if station_access_side < 0.0 else "PlatformGuardRightFront"
	entrance_marker.set_meta("entrance_gate_clear_z", Vector2(
		access_z - ENTRANCE_GATE_HALF_LENGTH,
		access_z + ENTRANCE_GATE_HALF_LENGTH))
	station.add_child(entrance_marker)
	for side in [-1.0, 1.0]:
		var guard := Node3D.new()
		guard.name = "PlatformGuardLeft" if side < 0.0 else "PlatformGuardRight"
		guard.basis = route_basis
		guard.set_meta("barrier_plan", "train_fit_no_overlap")
		guard.set_meta("train_side_clearance_m", INNER_EDGE_X - 6.0 - 0.16)
		guard.set_meta("driver_gate_clear_z", Vector2(-DRIVER_GATE_HALF_LENGTH,
			DRIVER_GATE_HALF_LENGTH))
		guard.set_meta("passenger_gate_clear_z", Vector2(
			PASSENGER_GATE_Z - PASSENGER_GATE_HALF_LENGTH,
			PASSENGER_GATE_Z + PASSENGER_GATE_HALF_LENGTH))
		station.add_child(guard)
		var inner_x := float(side) * INNER_EDGE_X
		var outer_x := float(side) * OUTER_EDGE_X
		_add_purpose_barrier_segment(guard, "EngineMachineryBarrier",
			Vector3(inner_x, 0.0, PLATFORM_FRONT_Z),
			Vector3(inner_x, 0.0, -DRIVER_GATE_HALF_LENGTH),
			"prevents access to the engine and empty guideway")
		_add_purpose_barrier_segment(guard, "CoachSeparationBarrier",
			Vector3(inner_x, 0.0, DRIVER_GATE_HALF_LENGTH),
			Vector3(inner_x, 0.0,
				PASSENGER_GATE_Z - PASSENGER_GATE_HALF_LENGTH),
			"keeps players on the platform between the two boarding gates")
		_add_purpose_barrier_segment(guard, "RearTrackBarrier",
			Vector3(inner_x, 0.0,
				PASSENGER_GATE_Z + PASSENGER_GATE_HALF_LENGTH),
			Vector3(inner_x, 0.0, PLATFORM_REAR_Z),
			"prevents stepping behind the rear coach")

		# Only the side reached by the station entrance receives an outer opening.
		# The opposite outer rail is continuous because it has no valid approach.
		if is_equal_approx(float(side), access_side):
			var gap_start := clampf(access_z - ENTRANCE_GATE_HALF_LENGTH,
				PLATFORM_FRONT_Z, PLATFORM_REAR_Z)
			var gap_end := clampf(access_z + ENTRANCE_GATE_HALF_LENGTH,
				PLATFORM_FRONT_Z, PLATFORM_REAR_Z)
			if gap_start - PLATFORM_FRONT_Z > 0.5:
				_add_purpose_barrier_segment(guard, "OuterFallGuardFront",
					Vector3(outer_x, 0.0, PLATFORM_FRONT_Z),
					Vector3(outer_x, 0.0, gap_start),
					"protects the raised outer walkway before the entrance")
			if PLATFORM_REAR_Z - gap_end > 0.5:
				_add_purpose_barrier_segment(guard, "OuterFallGuardRear",
					Vector3(outer_x, 0.0, gap_end),
					Vector3(outer_x, 0.0, PLATFORM_REAR_Z),
					"protects the raised outer walkway after the entrance")
			guard.set_meta("entrance_gate_clear_z", Vector2(gap_start, gap_end))
		else:
			_add_purpose_barrier_segment(guard, "OuterFallGuard",
				Vector3(outer_x, 0.0, PLATFORM_FRONT_Z),
				Vector3(outer_x, 0.0, PLATFORM_REAR_Z),
				"protects the raised platform edge away from the entrance")

		_add_purpose_barrier_segment(guard, "FrontPlatformEndStop",
			Vector3(inner_x, 0.0, PLATFORM_FRONT_Z),
			Vector3(outer_x, 0.0, PLATFORM_FRONT_Z),
			"stops players walking beyond the front of the platform")
		# The rear end stays open: it is the foot of the track overpass ramp.

		# One post per coordinate connects every rail span. Long sections receive
		# intermediate supports at no more than five-metre spacing, while adjoining
		# sections reuse the exact same corner post.
		var post_points := {}
		for segment in guard.get_children():
			if segment.has_meta("barrier_start"):
				var start_value: Vector3 = segment.get_meta("barrier_start")
				var finish_value: Vector3 = segment.get_meta("barrier_finish")
				var support_count := maxi(1,
					ceili(start_value.distance_to(finish_value) / 5.0))
				for support_index in support_count + 1:
					var support_ratio := float(support_index) / float(support_count)
					var support_position := start_value.lerp(finish_value, support_ratio)
					_add_unique_barrier_post(guard, post_points,
						Vector3(support_position.x, 1.65, support_position.z))
		guard.set_meta("shared_connection_post_count", post_points.size())


func _add_purpose_barrier_segment(parent: Node3D, node_name: String,
		start: Vector3, finish: Vector3, purpose: String) -> void:
	var section := Node3D.new()
	section.name = node_name
	section.set_meta("purpose", purpose)
	section.set_meta("barrier_start", start)
	section.set_meta("barrier_finish", finish)
	parent.add_child(section)
	var direction := (finish - start).normalized()
	var span_count := maxi(1, ceili(start.distance_to(finish) / 5.0))
	section.set_meta("connected_span_count", span_count)
	for span_index in span_count:
		var raw_span_start := start.lerp(finish,
			float(span_index) / float(span_count))
		var raw_span_finish := start.lerp(finish,
			float(span_index + 1) / float(span_count))
		# Stop every span at the face of its 0.38 m support posts. Neighboring
		# spans connect through one post but their collision boxes never overlap.
		var rail_start := raw_span_start + direction * 0.19
		var rail_finish := raw_span_finish - direction * 0.19
		for height in [1.25, 2.75]:
			_add_walkway_between(section,
				("LowerRail" if height < 2.0 else "UpperRail") + "_%02d" % span_index,
				rail_start + Vector3.UP * float(height),
				rail_finish + Vector3.UP * float(height),
				0.32, 0.32, _gold_material, true)


func _add_unique_barrier_post(parent: Node3D, used_points: Dictionary,
		position_value: Vector3) -> void:
	var point_key := "%.3f:%.3f" % [position_value.x, position_value.z]
	if used_points.has(point_key):
		return
	used_points[point_key] = true
	_add_box(parent, "BarrierPost", position_value,
		Vector3(0.38, 3.3, 0.38), _gold_material, true)


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
	var train_platform := AnimatableBody3D.new()
	_configure_train_platform_body(train_platform, "complete_train")
	_train = train_platform
	_train.name = "RainbowGalaxyTrain"
	_train.position = STATIONS[0].position
	add_child(_train)
	_rider_anchor = RemoteTransform3D.new()
	_rider_anchor.name = "RiderTransformAnchor"
	_rider_anchor.position = DRIVER_SEAT
	_rider_anchor.update_position = true
	# Riders face their seat and turn with the train on curves.
	_rider_anchor.update_rotation = true
	_rider_anchor.update_scale = false
	_train.add_child(_rider_anchor)
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
		# Solid roof proxy: a player landing from above stands on the authored
		# canopy instead of passing through its decorative Blender geometry.
		_add_box(carriage, "CoachRoofWalkway", Vector3(0.0, 7.18, 0.0),
			Vector3(10.8, 0.30, 12.6), body_material, true)
		# Split side rails leave a broad centre boarding gate. Low external steps
		# let the player walk or jump onto either coach from either platform side.
		for side in [-1.0, 1.0]:
			var side_name := "Left" if side < 0 else "Right"
			for guard_z in [-4.35, 4.35]:
				_add_box(carriage, "CoachGuard%s_%s" % [side_name,
					"Rear" if guard_z > 0.0 else "Front"],
					Vector3(side * 5.15, 2.0, guard_z), Vector3(0.7, 2.7, 4.3),
					_gold_material, true)
			_add_box(carriage, "BoardingStep%s" % side_name,
				Vector3(side * 5.82, 0.48, 0.0), Vector3(0.75, 0.55, 4.0),
				_gold_material, true)
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
				_add_cylinder(carriage, "StarWheel", Vector3(side * 5.4, 0.4, z), 2.1, 1.0,
					_gold_material, true, 16, Vector3(0.0, 0.0, 90.0))

	# Gangway plate bridging the two coaches. Each deck is 13 m long and they sit
	# 15 m apart, leaving a 2 m hole at z=6.5..8.5 that dropped the player
	# straight through the train to the rail below. The plate is flush with both
	# decks so walking between coaches is a continuous floor, not a jump.
	var gangway := Node3D.new()
	gangway.name = "CoachGangwayPlatform"
	_train.add_child(gangway)
	_add_box(gangway, "CoachGangway", Vector3(0.0, 0.65, 7.5), Vector3(4.0, 1.3, 2.6),
		_gold_material, true)
	for gangway_side in [-1.0, 1.0]:
		_add_box(gangway, "GangwayRail", Vector3(gangway_side * 2.35, 2.0, 7.5),
			Vector3(0.3, 2.7, 2.6), _gold_material, true)

	var engine := Node3D.new()
	engine.name = "MiloEngine"
	engine.position = Vector3(0.0, 0.0, -15.0)
	_train.add_child(engine)
	_add_box(engine, "EngineBody", Vector3(0.0, 4.0, 0.0), Vector3(12.0, 8.0, 17.0),
		_material(Color("724cc5"), 0.30, Color("aa84ff"), 1.3), true)
	_add_box(engine, "EngineNoseCollision", Vector3(0.0, 2.4, -10.2),
		Vector3(9.0, 4.8, 4.0), _gold_material, true)
	# Guard rail along the engine's rear roof edge. The roof is 8 m up and the
	# coach deck is at 1.3 m, so anyone who got onto the engine could walk off
	# the back and take a 6.7 m fall onto the deck. This closes that edge.
	_add_box(engine, "EngineRoofGuard", Vector3(0.0, 8.55, 8.2), Vector3(12.0, 1.1, 0.4),
		_gold_material, true)
	_add_cylinder(engine, "CrownChimney", Vector3(0.0, 10.0, -2.0), 2.6, 8.0,
		_gold_material, true, 12)
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
	# Keep the synchronized infinite-mass train collision and driver labels while
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
	detailed_train.set_meta("walkable_collision_source", "complete_animatable_train_shell")
	_train.add_child(detailed_train)
	_enhance_detailed_train_palette(detailed_train)
	_color_passenger_seats(detailed_train)
	_build_rider_seats()
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


## One colour per passenger bench, cycling the train's rainbow.
const SEAT_COLOURS := [
	Color("ff4f78"), Color("ff934d"), Color("ffe45b"), Color("5ee889"),
	Color("43e6ee"), Color("4d82ff"), Color("b16cff"), Color("ff7ad9"),
	Color("ffb347"), Color("9be85e"), Color("3fc9b0"), Color("8a7bff")]


## Gives every passenger bench its own colour.
##
## The seats are not separate objects: all of them are one "Seat_Navy" surface
## inside the merged CrownLineRuntimeTexturedSurface mesh, so a material can
## only colour them all at once. Instead the surface gets per-vertex colours -
## one per bench, the backrest and cushion matching - and its material uses
## them as albedo. Benches are found as connected pieces of that surface and
## paired by side (x) and row (z range). The driver's cab (z > 9 in the mesh)
## also uses Seat_Navy, for its seats and some controls, and keeps its colour.
func _color_passenger_seats(detailed_train: Node3D) -> void:
	var instance := detailed_train.find_child("CrownLineRuntimeTexturedSurface", true, false) \
		as MeshInstance3D
	if instance == null or not (instance.mesh is ArrayMesh):
		return
	var source := instance.mesh as ArrayMesh
	var seat_surface := -1
	for surface in source.get_surface_count():
		var material := source.surface_get_material(surface)
		if material != null and material.resource_name == "Seat_Navy":
			seat_surface = surface
	if seat_surface < 0:
		return

	var arrays := source.surface_get_arrays(seat_surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Connected pieces: union triangle corners, and vertices that share a
	# position (the importer splits them along hard edges).
	# An Array, not a PackedInt32Array: the lambda below must see later writes,
	# and packed arrays are copied into a lambda when it is created.
	var parent: Array[int] = []
	parent.resize(vertices.size())
	for i in vertices.size():
		parent[i] = i
	var find := func(i: int) -> int:
		while parent[i] != i:
			parent[i] = parent[parent[i]]
			i = parent[i]
		return i
	var welded := {}
	for i in vertices.size():
		var key := vertices[i].snapped(Vector3.ONE * 0.001)
		if welded.has(key):
			parent[find.call(i)] = find.call(welded[key])
		else:
			welded[key] = i
	for t in range(0, indices.size(), 3):
		for k in [1, 2]:
			parent[find.call(indices[t + k])] = find.call(indices[t])
	var pieces := {}
	for i in vertices.size():
		var root: int = find.call(i)
		pieces[root] = (pieces[root] as AABB).expand(vertices[i]) if pieces.has(root) \
			else AABB(vertices[i], Vector3.ZERO)

	# A bench is the backrest and cushion on one side sharing a z range.
	var cab_colour := Color("4169e8")  # what _enhance_detailed_train_palette gives "navy"
	var bench_of_piece := {}
	var benches: Array = []
	for root in pieces:
		var box: AABB = pieces[root]
		if box.get_center().z > 9.0:
			continue
		var bench := "%d:%.1f" % [signi(int(sign(box.get_center().x))), box.position.z]
		if not benches.has(bench):
			benches.append(bench)
		bench_of_piece[root] = bench
	benches.sort()
	var colours := PackedColorArray()
	colours.resize(vertices.size())
	for i in vertices.size():
		var root: int = find.call(i)
		colours[i] = SEAT_COLOURS[benches.find(bench_of_piece[root]) % SEAT_COLOURS.size()] \
			if bench_of_piece.has(root) else cab_colour
	arrays[Mesh.ARRAY_COLOR] = colours

	# Rebuild the mesh with the coloured seat surface; every other surface is
	# copied as is. A new mesh, so the imported GLB resource stays untouched.
	var rebuilt := ArrayMesh.new()
	for surface in source.get_surface_count():
		rebuilt.add_surface_from_arrays(source.surface_get_primitive_type(surface),
			arrays if surface == seat_surface else source.surface_get_arrays(surface))
		rebuilt.surface_set_material(surface, source.surface_get_material(surface))
		rebuilt.surface_set_name(surface, source.surface_get_name(surface))
	var overrides := []
	for surface in source.get_surface_count():
		overrides.append(instance.get_surface_override_material(surface))
	instance.mesh = rebuilt
	for surface in overrides.size():
		instance.set_surface_override_material(surface, overrides[surface])

	var seats := (instance.get_active_material(seat_surface) as StandardMaterial3D).duplicate() \
		as StandardMaterial3D
	seats.vertex_color_use_as_albedo = true
	seats.albedo_color = Color.WHITE
	# The palette pass gave Seat_Navy a blue glow, which would tint every bench
	# blue; a faint white glow keeps the lift without hiding their colours.
	seats.emission = Color.WHITE
	seats.emission_energy_multiplier = 0.06
	instance.set_surface_override_material(seat_surface, seats)
	instance.set_meta("passenger_bench_colours", benches.size())
	# Bench boxes in train space, for the rider seats.
	var to_train := _train.global_transform.affine_inverse() * instance.global_transform
	var boxes := {}
	for root in bench_of_piece:
		var bench: String = bench_of_piece[root]
		var box := to_train * (pieces[root] as AABB)
		boxes[bench] = (boxes[bench] as AABB).merge(box) if boxes.has(bench) else box
	_bench_boxes.clear()
	for bench in benches:
		_bench_boxes.append(boxes[bench])


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
	_steam_rod_parts.clear()
	_steam_pressure_parts.clear()
	_steam_valve_parts.clear()
	_steam_exhaust_particles = null
	_celestial_halo_parts.clear()
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
			or part_name.contains("Engine_SteamGovernorGear_") \
			or part_name.contains("Engine_SteamGearHub_") \
			or part_name.contains("Engine_SteamGearEnergyRing_"):
			_steam_gear_parts.append(part)
			var gear_ratio := 1.0
			if part_name.contains("Valve") or part_name.ends_with("_1"):
				gear_ratio = -1.45
			elif part_name.contains("Governor") or part_name.ends_with("_2"):
				gear_ratio = 2.05
			part.set_meta("mechanism_spin_ratio", gear_ratio)
		elif part_name.contains("Engine_SteamConnectingRod_"):
			_steam_rod_parts.append(part)
			part.set_meta("mechanism_base_position", part.position)
			part.set_meta("mechanism_base_rotation", part.rotation)
			part.set_meta("mechanism_phase", 0.0 if part_name.ends_with("_L") else PI)
		elif part_name.contains("Engine_SteamPressureOrb_") \
			or part_name.contains("Engine_SteamPressureHalo_"):
			_steam_pressure_parts.append(part)
			part.set_meta("mechanism_base_scale", part.scale)
			part.set_meta("mechanism_phase", 0.0 if part_name.ends_with("_0") else PI * .64)
		elif part_name.contains("Engine_SteamPipeValve_") \
			or part_name.contains("Engine_SteamChimneyEnergyRing"):
			_steam_valve_parts.append(part)
			if part_name.contains("Engine_SteamChimneyEnergyRing"):
				_build_steam_exhaust(part)
			else:
				# The pipe runs sideways through these rings' holes, so they sat
				# skewered on it. Turn each a quarter about the vertical: the pipe
				# then crosses the ring as a diameter and the ring whirls round it.
				part.rotate_y(PI * 0.5)
		elif part_name.contains("Engine_CelestialHaloOuterMechanism") \
			or part_name.contains("Engine_CelestialHaloInnerMechanism"):
			_celestial_halo_parts.append(part)
			part.set_meta("mechanism_spin_ratio",
				-1.35 if part_name.contains("Inner") else 1.0)
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
		var gear_ratio: float = steam_gear.get_meta("mechanism_spin_ratio", 1.0)
		# rotate_* turns about the PARENT's axis. The gears' parent X is their
		# axle (the same axis the wheels spin about above); Z is the direction of
		# travel, which spun them like propellers. Same sign as the wheels, so the
		# drive gear rolls with them and the valve gear (negative ratio) counters.
		steam_gear.rotate_x(signed_spin * gear_ratio * 1.22)
	var steam_phase := _mechanism_time * (2.6 + speed_ratio * 8.4)
	for rod_part in _steam_rod_parts:
		var rod_phase: float = rod_part.get_meta("mechanism_phase", 0.0)
		var rod_motion := sin(steam_phase + rod_phase)
		var rod_base_position: Vector3 = rod_part.get_meta("mechanism_base_position", Vector3.ZERO)
		var rod_base_rotation: Vector3 = rod_part.get_meta("mechanism_base_rotation", Vector3.ZERO)
		# The compact crank linkage uses a restrained stroke so it remains in its
		# dedicated clearance bay throughout the full animation cycle.
		rod_part.position = rod_base_position + Vector3(0.0, 0.0, rod_motion * .10)
		rod_part.rotation = rod_base_rotation + Vector3(rod_motion * .04, 0.0, rod_motion * .06)
	for pressure_part in _steam_pressure_parts:
		var pressure_phase: float = pressure_part.get_meta("mechanism_phase", 0.0)
		var base_pressure_scale: Vector3 = pressure_part.get_meta("mechanism_base_scale", Vector3.ONE)
		var pressure_pulse := 1.0 + sin(steam_phase * .72 + pressure_phase) \
			* (.035 + speed_ratio * .075)
		pressure_part.scale = base_pressure_scale * pressure_pulse
	for valve_part in _steam_valve_parts:
		# The three rings on each steam pipe stay still (quarter-turned across
		# the pipe at registration). Only the chimney ring spins, flat about
		# the vertical (rotate_* uses the parent's axes).
		if valve_part.name.contains("ChimneyEnergyRing"):
			valve_part.rotate_y(delta * (.35 + speed_ratio * 5.8))
	for halo_part in _celestial_halo_parts:
		var halo_ratio: float = halo_part.get_meta("mechanism_spin_ratio", 1.0)
		halo_part.rotate_y(delta * (.22 + speed_ratio * 2.25) * halo_ratio)
	if _steam_exhaust_particles != null:
		_steam_exhaust_particles.emitting = true
		_steam_exhaust_particles.amount_ratio = .12 + speed_ratio * .88
		_steam_exhaust_particles.speed_scale = .42 + speed_ratio * 1.35
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


func _build_steam_exhaust(chimney_ring: Node3D) -> void:
	var exhaust := GPUParticles3D.new()
	exhaust.name = "SteamOrbChimneyExhaust"
	exhaust.amount = 42
	exhaust.lifetime = 2.4
	exhaust.preprocess = 1.2
	exhaust.randomness = .42
	exhaust.fixed_fps = 30
	exhaust.local_coords = false
	exhaust.visibility_aabb = AABB(Vector3(-8.0, -2.0, -8.0), Vector3(16.0, 22.0, 16.0))
	var steam_motion := ParticleProcessMaterial.new()
	steam_motion.direction = Vector3.UP
	steam_motion.spread = 18.0
	steam_motion.initial_velocity_min = 1.8
	steam_motion.initial_velocity_max = 4.8
	steam_motion.gravity = Vector3(0.0, .75, 0.0)
	steam_motion.damping_min = .35
	steam_motion.damping_max = 1.1
	steam_motion.scale_min = .55
	steam_motion.scale_max = 1.65
	steam_motion.color = Color(0.58, 0.92, 1.0, .46)
	exhaust.process_material = steam_motion
	var puff_mesh := SphereMesh.new()
	puff_mesh.radius = .34
	puff_mesh.height = .68
	puff_mesh.radial_segments = 8
	puff_mesh.rings = 4
	var puff_material := StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.albedo_color = Color(0.66, 0.94, 1.0, .38)
	puff_material.emission_enabled = true
	puff_material.emission = Color(0.24, 0.68, 1.0)
	puff_material.emission_energy_multiplier = .75
	puff_mesh.material = puff_material
	exhaust.draw_pass_1 = puff_mesh
	chimney_ring.add_child(exhaust)
	_steam_exhaust_particles = exhaust


func _update_directional_movement_vfx(delta: float, motion_delta: Vector3) -> void:
	if _movement_vfx == null or _rainbow_trail_particles == null \
			or _gold_trail_particles == null:
		return
	var raw_speed := motion_delta.length() / maxf(delta, 0.0001)
	var has_motion_sample := raw_speed > 0.75 and motion_delta.length_squared() > 0.0001
	if has_motion_sample:
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
	# Render frames can outnumber physics frames. A frame with no new platform
	# transform is not a stopped train, so retain the commanded speed and echo
	# history between physics samples instead of flickering the trail off.
	var commanded_moving := _riding and _display_speed_kph > 0.5
	var target_ratio := clampf(_display_speed_kph / DISPLAY_MAX_SPEED_KPH, 0.0, 1.0) \
		if _manual_driving else (clampf(raw_speed / MANUAL_DRIVE_SPEED, 0.0, 1.0) \
		if has_motion_sample else _movement_vfx_speed_ratio)
	if not commanded_moving and not has_motion_sample:
		target_ratio = 0.0
	var response_delta := maxf(delta, 1.0 / 120.0)
	_movement_vfx_speed_ratio = move_toward(_movement_vfx_speed_ratio,
		target_ratio, response_delta * (3.8 if commanded_moving or has_motion_sample else 5.5))
	var should_emit := (commanded_moving or has_motion_sample) \
		and _movement_vfx_speed_ratio > 0.015
	_rainbow_trail_particles.emitting = should_emit
	_gold_trail_particles.emitting = should_emit
	if not commanded_moving and not has_motion_sample:
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
	canvas.layer = 20
	_controls_panel = PanelContainer.new()
	_controls_panel.name = "TrainControls"
	_controls_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_controls_panel.offset_left = -354
	_controls_panel.offset_right = -18
	_controls_panel.offset_top = -150
	_controls_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.09, 0.94)
	style.border_color = Color("70e5ff")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_controls_panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(_controls_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	_controls_panel.add_child(column)
	var heading := Label.new()
	heading.text = "CROWN LINE · TRAIN CONTROLS"
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color("70e5ff"))
	column.add_child(heading)
	_prompt = Label.new()
	_prompt.name = "Instructions"
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_color", Color.WHITE)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_prompt)
	_status = Label.new()
	_status.name = "JourneyStatus"
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", Color("ffe29a"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_controls_panel.visible = false


func _update_prompt() -> void:
	if _prompt == null:
		return
	_controls_panel.visible = _player != null and (_riding or \
		get_distance_to_train_footprint(_player.global_position) <= FLEXIBLE_BOARDING_RANGE)
	if not _controls_panel.visible:
		return
	if _manual_driving:
		_prompt.text = "DRIVER MODE\nW  Forward\nS  Reverse\nRelease W/S  Brake\nR  Sound horn\n2  Passenger mode at station\nQ  Exit when docked"
	elif _seated_passenger:
		_prompt.text = "PASSENGER MODE\nEnjoy the ride to the next station.\nAt each station:\n2  Continue to next station\n1  Take the controls\nQ  Exit onto platform"
	else:
		_prompt.text = "1  Drive the train\n2  Sit and ride\n\nALL FOUR STATIONS OPEN\nGallery → Mind Spark\n→ Heart Melody → Creator's Light\n→ Gallery"
	return

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
		_seat_rider()
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
		_unseat_rider()
		_place_player_on_station()
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

	var direction := ahead - behind
	var next_basis := _train.basis
	if direction.length_squared() > 0.01:
		var target_basis := Basis.looking_at(direction.normalized(), Vector3.UP)
		# Ease into the new heading so any residual step in the sampled tangent
		# arrives as a turn rather than a snap. Framerate-independent so the ride
		# feels the same whether the browser build runs at 30 or 60 fps.
		# Uncapped/headless render frames can report a near-zero process delta even
		# while the public drive API advances at a fixed simulation step. Keep a
		# 120 Hz floor so heading interpolation cannot fall far behind the curve and
		# then snap to the station tangent when docking.
		var blend_delta := maxf(get_process_delta_time(), 1.0 / 120.0)
		var blend := 1.0 - pow(0.0001, blend_delta)
		next_basis = _train.basis.slerp(target_basis, clampf(blend, 0.0, 1.0)) \
			if _manual_driving else target_basis
	# sync_to_physics defers transform changes. Assigning position and basis
	# separately made the basis assignment copy the old position over the queued
	# movement, so the speedometer advanced while the platform stayed docked.
	var next_transform := Transform3D(next_basis, point)
	_train.transform = next_transform
	_place_rider()


func _orient_train_at_station(station_index: int) -> void:
	if _train == null or _curves.is_empty():
		return
	var direction := Vector3.FORWARD
	var curve: Curve3D = _curves[posmod(station_index, _curves.size())]
	direction = curve.sample_baked(2.0) - curve.sample_baked(0.0)
	if direction.length_squared() > 0.01:
		# Keep station placement and heading in the same synchronized transform.
		# Separate position/basis assignments race inside AnimatableBody3D and can
		# leave a one-frame heading-only dock snap.
		_train.transform = Transform3D(
			Basis.looking_at(direction.normalized(), Vector3.UP),
			STATIONS[posmod(station_index, STATIONS.size())].position)


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
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		var collision_owner := _get_train_collision_owner(parent)
		if collision_owner != null:
			shape_node.name = "%s_%sCollision" % [parent.name, node_name]
			var source_transform := Transform3D(
				Basis.from_euler(Vector3(rotation_x, rotation_y, 0.0)), position_value)
			shape_node.transform = collision_owner.global_transform.affine_inverse() \
				* parent.global_transform * source_transform
			collision_owner.add_child(shape_node, true)
			return
		var body := StaticBody3D.new()
		body.name = "%sCollision" % node_name
		shape_node.name = "CollisionShape3D"
		shape_node.position = Vector3.ZERO
		shape_node.rotation = Vector3.ZERO
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
		var shape_node := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		shape_node.shape = shape
		var collision_owner := _get_train_collision_owner(parent)
		if collision_owner != null:
			shape_node.name = "%s_%sCollision" % [parent.name, node_name]
			var rotation_radians := Vector3(
				deg_to_rad(rotation_value.x), deg_to_rad(rotation_value.y), deg_to_rad(rotation_value.z))
			var source_transform := Transform3D(Basis.from_euler(rotation_radians), position_value)
			shape_node.transform = collision_owner.global_transform.affine_inverse() \
				* parent.global_transform * source_transform
			collision_owner.add_child(shape_node, true)
			return
		var body := StaticBody3D.new()
		shape_node.name = "CollisionShape3D"
		shape_node.position = Vector3.ZERO
		shape_node.rotation = Vector3.ZERO
		body.add_child(shape_node)
		body.position = position_value
		body.rotation_degrees = rotation_value
		parent.add_child(body)


func _configure_train_platform_body(body: AnimatableBody3D, shell_kind: String) -> void:
	body.sync_to_physics = true
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("ride_camera_ignore")
	body.set_meta("train_collision_shell", shell_kind)
	body.set_meta("mass_model", "infinite_mass_moving_platform")


func _attach_rider_anchor(local_seat: Transform3D) -> void:
	if _rider_anchor == null or _player == null \
			or not _rider_anchor.is_inside_tree() or not _player.is_inside_tree():
		return
	_rider_anchor.transform = local_seat
	_rider_anchor.remote_path = _rider_anchor.get_path_to(_player)


## The train-local seat the player currently rides in: the cab seat when
## driving, otherwise their passenger seat (seat 0 for a guided ride).
func _rider_seat() -> Transform3D:
	if _manual_driving or _passenger_seats.is_empty():
		return _driver_seat
	if _seated_passenger and _passenger_seat_index >= 0 \
			and _passenger_seat_index < _passenger_seats.size():
		return _passenger_seats[_passenger_seat_index]
	return _passenger_seats[0]


## Puts the player exactly in their seat, facing the way it faces. Riders used
## to have only their position set, with the walking body still running
## gravity, so they looked dragged along standing up.
func _place_rider() -> void:
	if _player == null or _train == null:
		return
	_player.global_transform = _train.global_transform * _rider_seat()
	_player.velocity = Vector3.ZERO


## Sits the player in the seat for the current mode and Milo beside them.
func _seat_rider() -> void:
	if _player == null or _train == null:
		return
	if _player.has_method("set_seated"):
		_player.call("set_seated", true)
	_place_rider()
	_attach_rider_anchor(_rider_seat())
	_seat_milo()


func _unseat_rider() -> void:
	if _rider_anchor != null:
		_rider_anchor.remote_path = NodePath()
	if _player != null and _player.has_method("set_seated"):
		_player.call("set_seated", false)
	_unseat_milo()


## Builds the passenger seats from the train model's seats (found while
## colouring them): one rider per seat - at the characters' scale each is a
## single armchair - just in front of the backrest on the outer wall, facing
## the aisle. Seat 0 is the place nearest the old seat 0, so
## everything that relied on it - the interaction boundary, guided rides - is
## unchanged. Falls back to the old hand-placed points without the model.
func _build_rider_seats() -> void:
	_passenger_seats.clear()
	_passenger_seat_bench.clear()
	var places: Array = []
	for bench_index in _bench_boxes.size():
		var box := _bench_boxes[bench_index]
		var on_left := box.get_center().x < 0.0
		var x := box.position.x + 1.15 if on_left else box.end.x - 1.15
		var cushion_top := box.position.y + 0.58
		var facing := Vector3.RIGHT if on_left else Vector3.LEFT
		places.append([_seat_transform(
			Vector3(x, cushion_top, box.get_center().z), facing), bench_index])
	if places.is_empty():
		for point in BENCH_SEATS:
			places.append([Transform3D(Basis.IDENTITY, point), -1])
	var legacy_first: Vector3 = BENCH_SEATS[0]
	places.sort_custom(func(a: Array, b: Array) -> bool:
		return (a[0] as Transform3D).origin.distance_to(legacy_first) \
			< (b[0] as Transform3D).origin.distance_to(legacy_first))
	for place in places:
		_passenger_seats.append(place[0])
		_passenger_seat_bench.append(place[1])
	_driver_seat = _seat_transform(CAB_SEATS[0], Vector3.FORWARD)
	_codriver_seat = _seat_transform(CAB_SEATS[1], Vector3.FORWARD)


## A rider's transform for a cushion: riders face +Z of their own body, and
## Basis.looking_at aims -Z, hence the negated facing.
func _seat_transform(cushion_top: Vector3, facing: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(-facing, Vector3.UP),
		cushion_top + Vector3.UP * RIDER_SEAT_LIFT)


func _active_milo() -> Node3D:
	for candidate in get_tree().get_nodes_in_group("milo"):
		if candidate is Node3D and candidate.has_method("sit_on") \
				and (candidate as Node3D).is_inside_tree():
			return candidate as Node3D
	return null


## Milo's seat: the cab's second seat beside a driver, otherwise the nearest
## seat on the passenger's side of the aisle (the next one along the row).
func _milo_seat() -> Transform3D:
	if _manual_driving or _passenger_seats.is_empty():
		return _codriver_seat
	var mine := _passenger_seat_index if _seated_passenger and _passenger_seat_index >= 0 else 0
	var origin := _passenger_seats[mine].origin
	var best := -1
	for seat_index in _passenger_seats.size():
		var other := _passenger_seats[seat_index].origin
		if seat_index == mine or signf(other.x) != signf(origin.x):
			continue
		if best < 0 or other.distance_to(origin) < _passenger_seats[best].origin.distance_to(origin):
			best = seat_index
	return _passenger_seats[best if best >= 0 else (mine + 1) % _passenger_seats.size()]


func _seat_milo() -> void:
	var milo := _active_milo()
	if milo == null or _train == null:
		return
	if _milo_anchor == null:
		_milo_anchor = RemoteTransform3D.new()
		_milo_anchor.name = "MiloSeatAnchor"
		_milo_anchor.update_scale = false
		_train.add_child(_milo_anchor)
	var seat := _milo_seat()
	seat.origin += seat.basis * MILO_SEAT_OFFSET - Vector3.UP * RIDER_SEAT_LIFT
	_milo_anchor.transform = seat
	milo.call("sit_on", _milo_anchor)


func _unseat_milo() -> void:
	if _milo_anchor != null:
		_milo_anchor.remote_path = NodePath()
	var milo := _active_milo()
	if milo != null and milo.has_method("stand_up"):
		milo.call("stand_up")


func _get_train_collision_owner(parent: Node3D) -> CollisionObject3D:
	if _train is AnimatableBody3D and (parent == _train or _train.is_ancestor_of(parent)):
		return _train as AnimatableBody3D
	if parent is CollisionObject3D:
		return parent as CollisionObject3D
	return null


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
	# The station's island is solid ground like every other station island.
	instance.create_trimesh_collision()
	_mark_station_island(instance.get_child(instance.get_child_count() - 1))


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


func _build_heart_melody_entrance() -> void:
	if _player == null:
		return
	var connection := Node3D.new()
	connection.name = "HeartMelodyConnection"
	connection.set_script(load("res://scripts/heart_melody/heart_overworld_connection.gd"))
	connection.set("player", _player)
	add_child(connection)
