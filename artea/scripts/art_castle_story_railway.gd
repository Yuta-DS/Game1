extends Node3D

# The Rainbow Galaxy Train follows the story's open Crown Line. It is not a
# loop: players progress Gallery -> Mind -> Heart -> Creator, then may ride
# back through the unlocked worlds for the castle celebration.

const STATIONS := [
	{"id": "gallery", "title": "ARTÉA GALLERY", "subtitle": "RIGHT-SIDE SKY DOCK", "position": Vector3(260.0, 28.0, 820.0), "landing": Vector3(150.0, 2.0, 820.0)},
	{"id": "mind", "title": "MIND SPARK", "subtitle": "EAST FLOATING STATION", "position": Vector3(-1900.0, 35.0, 3940.0), "landing": Vector3(-2100.0, 2.0, 3940.0)},
	{"id": "heart", "title": "HEART MELODY", "subtitle": "EAST FLOATING STATION", "position": Vector3(1700.0, 35.0, 7640.0), "landing": Vector3(1500.0, 2.0, 7640.0)},
	{"id": "creator", "title": "CREATOR'S LIGHT", "subtitle": "EAST FLOATING STATION", "position": Vector3(5300.0, 35.0, 3940.0), "landing": Vector3(5100.0, 2.0, 3940.0)},
]

const CONTROL_POINTS := [
	[Vector3(900.0, 120.0, 2200.0), Vector3(-1750.0, 125.0, 3200.0)],
	[Vector3(1800.0, 155.0, 5200.0), Vector3(2050.0, 150.0, 6500.0)],
	[Vector3(5600.0, 155.0, 7200.0), Vector3(5600.0, 135.0, 5000.0)],
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
	"minimum_rail_elevation_m": 26.6,
}

const RIDE_SECONDS := 14.0
const INTERACTION_RANGE := 48.0
const PASSENGER_SEAT := Vector3(0.0, 3.1, 0.0)
const BOARDING_OFFSET := Vector3(0.0, 0.0, 11.0)
const ACCESS_DECK_THICKNESS := 1.0
const LANDING_PLAYER_CLEARANCE := 2.0
const MANUAL_DRIVE_SPEED := 420.0
const STAIR_STEP_COUNT := 12
const STAIR_START_X := -29.5
const STAIR_END_X := -7.5
const STAIR_BOTTOM_TOP_Y := -0.65
const STAIR_TOP_TOP_Y := 1.10

@export var ride_duration := RIDE_SECONDS

var _curves: Array[Curve3D] = []
var _station_nodes: Array[Node3D] = []
var _player: CharacterBody3D
var _train: Node3D
var _train_glow: OmniLight3D
var _current_station := 0
var _direction := 1
var _riding := false
var _manual_driving := false
var _drive_segment := -1
var _drive_progress := 0.0
var _prompt: Label
var _status: Label
var _rail_material: StandardMaterial3D
var _gold_material: StandardMaterial3D
var _glass_material: StandardMaterial3D
var _stone_material: StandardMaterial3D


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
		_train.position.y = STATIONS[_current_station].position.y + sin(Time.get_ticks_msec() * 0.002) * 0.45
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _player == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		if _manual_driving:
			if _drive_segment < 0:
				request_disembark()
			else:
				_status.text = "SLOW TO A STATION BEFORE LEAVING THE DRIVER DECK"
			get_viewport().set_input_as_handled()
			return
		if _riding:
			return
		if _player.global_position.distance_to(_boarding_position(_current_station)) <= INTERACTION_RANGE:
			board_as_driver()
			get_viewport().set_input_as_handled()


func get_station_count() -> int:
	return STATIONS.size()


func get_segment_count() -> int:
	return _curves.size()


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


func get_current_station() -> int:
	return _current_station


func is_riding() -> bool:
	return _riding


func is_driving() -> bool:
	return _manual_driving


func get_drive_segment() -> int:
	return _drive_segment


func get_drive_progress() -> float:
	return _drive_progress


func request_ride() -> bool:
	if _riding or _player == null:
		return false
	if _player.global_position.distance_to(_boarding_position(_current_station)) > INTERACTION_RANGE:
		return false
	return _try_depart()


func board_as_driver() -> bool:
	if _riding or _player == null:
		return false
	if _player.global_position.distance_to(_boarding_position(_current_station)) > INTERACTION_RANGE:
		return false
	_riding = true
	_manual_driving = true
	_drive_segment = -1
	_drive_progress = 0.0
	_train.position = STATIONS[_current_station].position
	_train.rotation.y = 0.0
	_player.call("set_input_enabled", false)
	_player.velocity = Vector3.ZERO
	_player.global_position = _train.to_global(PASSENGER_SEAT)
	_status.text = "DRIVER MODE  •  HOLD W FORWARD  •  HOLD S REVERSE  •  Q EXIT AT A STATION"
	return true


func request_disembark() -> bool:
	if not _manual_driving or _drive_segment >= 0:
		return false
	_disembark_driver()
	return true


# Public so the runtime and focused tests use the exact same driving path.
# Positive throttle follows Gallery -> Mind -> Heart -> Creator; negative
# throttle reverses along the same open Crown Line.
func drive_manual(throttle: float, delta: float) -> void:
	if not _manual_driving or _train == null or absf(throttle) < 0.01:
		if _manual_driving and _player != null:
			_player.global_position = _train.to_global(PASSENGER_SEAT)
		return
	var drive_direction := 1 if throttle > 0.0 else -1
	if _drive_segment < 0:
		if not _begin_manual_segment(drive_direction):
			return
	var curve := _curves[_drive_segment]
	var progress_delta := absf(throttle) * MANUAL_DRIVE_SPEED * maxf(delta, 0.0) \
		/ maxf(curve.get_baked_length(), 1.0)
	_drive_progress = clampf(_drive_progress + progress_delta * float(drive_direction), 0.0, 1.0)
	_set_train_progress(_drive_segment, _drive_progress)
	_status.text = "DRIVING  •  %s  •  W FORWARD / S REVERSE" % _segment_destination_name(drive_direction)
	if is_equal_approx(_drive_progress, 0.0):
		_dock_manual_train(_drive_segment)
	elif is_equal_approx(_drive_progress, 1.0):
		_dock_manual_train(_drive_segment + 1)


func _begin_manual_segment(drive_direction: int) -> bool:
	var target := _current_station + drive_direction
	if target < 0 or target >= STATIONS.size():
		_status.text = "END OF THE CROWN LINE  •  DRIVE THE OTHER WAY"
		return false
	if drive_direction > 0 and not is_station_unlocked(target):
		_status.text = _locked_message(target)
		return false
	_drive_segment = mini(_current_station, target)
	_drive_progress = 0.0 if drive_direction > 0 else 1.0
	return true


func _dock_manual_train(station_index: int) -> void:
	_current_station = clampi(station_index, 0, STATIONS.size() - 1)
	_drive_segment = -1
	_train.position = STATIONS[_current_station].position
	_train.rotation.y = 0.0
	if _player != null:
		_player.global_position = _train.to_global(PASSENGER_SEAT)
		_player.velocity = Vector3.ZERO
	_status.text = "DOCKED AT %s  •  Q EXIT  •  W/S KEEP DRIVING" % STATIONS[_current_station].title


func _segment_destination_name(drive_direction: int) -> String:
	if _drive_segment < 0:
		return STATIONS[_current_station].title
	var target := _drive_segment + 1 if drive_direction > 0 else _drive_segment
	return STATIONS[target].title


func _disembark_driver() -> void:
	if not _manual_driving or _drive_segment >= 0:
		return
	_manual_driving = false
	_riding = false
	if _player != null:
		_player.global_position = to_global(STATIONS[_current_station].position + Vector3(25.0, 2.0, 0.0))
		_player.velocity = Vector3.ZERO
		_player.call("set_input_enabled", true)
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


func is_station_unlocked(index: int) -> bool:
	var journey := get_node_or_null("/root/JourneyState")
	var flags: Dictionary = {}
	if journey != null:
		flags = journey.get("treasures") as Dictionary
	return station_unlocked_with(index, flags)


func _build_materials() -> void:
	_rail_material = _material(Color("e8d8ff"), 0.36, Color("9b6cff"), 1.6)
	_gold_material = _material(Color("f6cb67"), 0.42, Color("f3a936"), 1.2)
	_glass_material = _material(Color(0.18, 0.86, 0.97, 0.72), 0.20, Color("36dcff"), 1.7, true)
	_stone_material = _material(Color("d7d7e5"), 0.84)


func _build_route() -> void:
	var routes := Node3D.new()
	routes.name = "CrownLineRoute"
	add_child(routes)
	for index in STATIONS.size() - 1:
		var curve := Curve3D.new()
		# The curve is the train's centre origin, including at both station docks.
		# Previously it was 3 m above STATIONS, causing a snap and boarding gap.
		var start: Vector3 = STATIONS[index].position
		var finish: Vector3 = STATIONS[index + 1].position
		curve.add_point(start, Vector3.ZERO, CONTROL_POINTS[index][0] - start)
		curve.add_point(finish, CONTROL_POINTS[index][1] - finish, Vector3.ZERO)
		curve.bake_interval = 12.0
		_curves.append(curve)
		var segment_root := Node3D.new()
		segment_root.name = "StorySegment_%d_%s_to_%s" % [index + 1, STATIONS[index].id, STATIONS[index + 1].id]
		routes.add_child(segment_root)
		_build_track_mesh(segment_root, curve)


func _build_track_mesh(parent: Node3D, curve: Curve3D) -> void:
	var length := curve.get_baked_length()
	# Long 3 km links use broad 40 m pieces to keep draw-call count reasonable.
	var sample_count := maxi(2, int(length / 40.0))
	var previous := curve.sample_baked(0.0)
	for sample_index in range(1, sample_count + 1):
		var distance := length * float(sample_index) / float(sample_count)
		var point := curve.sample_baked(distance)
		var direction := point - previous
		# One structural beam sits exactly below the train centreline. No paired
		# rails or transverse sleepers remain, so the vehicle is visibly supported.
		_add_segment_box(parent, "CenterMonorailBeam", previous - Vector3.UP * 1.4,
			point - Vector3.UP * 1.4, Vector2(3.2, 1.6), _rail_material, true)
		previous = point


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
		_build_world_access_bridge(station, info.landing - info.position)
		_add_cylinder(station, "DestinationWheel", Vector3(0.0, -0.6, 0.0), 17.0, 1.0, _glass_material, false)
		# The access stair is built by the skybridge function on the same east-west
		# axis as the world bridge. A former north-facing ramp left a gap at this
		# exact dock edge even though both pieces existed visually.
		_add_box(station, "BoardingLane", Vector3(0.0, 0.8, 11.0), Vector3(15.0, 0.6, 28.0),
			_glass_material, true)
		_build_platform_guardrails(station)
		var board_label := Label3D.new()
		board_label.name = "BoardTrainSign"
		board_label.text = "DRIVER PLATFORM  ✦  [ Q ] BOARD\nW FORWARD  ✦  S REVERSE  ✦  Q EXIT"
		board_label.position = Vector3(0.0, 7.0, 24.0)
		board_label.font_size = 28
		board_label.outline_size = 8
		board_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		board_label.no_depth_test = true
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
		label.no_depth_test = true
		station.add_child(label)


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


func _build_world_access_bridge(station: Node3D, landing_local: Vector3) -> void:
	var bridge := Node3D.new()
	bridge.name = "KingdomAccessSkybridge"
	station.add_child(bridge)
	var dock_edge := Vector3(-31.0, -1.2, 0.0)
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
		ACCESS_DECK_THICKNESS, _stone_material, true)
	_build_dock_arrival_stairs(station)
	var direction := landing - dock_edge
	var side_axis := Vector3(-direction.z, 0, direction.x).normalized()
	for side in [-1.0, 1.0]:
		var lateral: Vector3 = side_axis * float(side) * 7.4 + Vector3.UP * 2.0
		_add_walkway_between(bridge, "SkybridgeGuardLeft" if side < 0 else "SkybridgeGuardRight",
			dock_edge + lateral, landing + lateral, 0.65, 3.2, _gold_material, true)


func _build_dock_arrival_stairs(station: Node3D) -> void:
	var stairs := Node3D.new()
	stairs.name = "AccessRamp"
	station.add_child(stairs)
	# Keep the visible stair rhythm, but let one continuous ramp carry the
	# player. The old cumulative collision boxes all extended to one shared
	# bottom and their upper faces combined into the tall wall seen at the dock.
	const STEP_DEPTH := 2.4
	const TREAD_THICKNESS := 0.12
	for index in STAIR_STEP_COUNT:
		var ratio := float(index) / float(STAIR_STEP_COUNT - 1)
		var top_y := lerpf(STAIR_BOTTOM_TOP_Y, STAIR_TOP_TOP_Y, ratio)
		var x := lerpf(STAIR_START_X, STAIR_END_X, ratio)
		_add_box(stairs, "DockStep_%02d" % (index + 1),
			Vector3(x, top_y - TREAD_THICKNESS * 0.5, 0.0),
			Vector3(STEP_DEPTH, TREAD_THICKNESS, 16.0), _stone_material, false)
	_add_surface_ramp_collision(stairs, "WalkableStairRamp",
		Vector3(STAIR_START_X - STEP_DEPTH * 0.5, STAIR_BOTTOM_TOP_Y - 0.10, 0.0),
		Vector3(STAIR_END_X + STEP_DEPTH * 0.5, STAIR_TOP_TOP_Y + 0.10, 0.0),
		15.6, 0.32)
	# Open rails replace the previous 2.6 m solid yellow walls, which filled the
	# camera and visually hid the stairs in the Web build.
	for side in [-1.0, 1.0]:
		var side_z := float(side) * 7.55
		for post_index in 7:
			var ratio := float(post_index) / 6.0
			var x := lerpf(STAIR_START_X, STAIR_END_X, ratio)
			var tread_y := lerpf(STAIR_BOTTOM_TOP_Y, STAIR_TOP_TOP_Y, ratio)
			_add_box(stairs, "StairRailPost", Vector3(x, tread_y + 1.25, side_z),
				Vector3(0.38, 2.5, 0.38), _gold_material, true)
		var rail_start := Vector3(STAIR_START_X, STAIR_BOTTOM_TOP_Y + 2.15, side_z)
		var rail_finish := Vector3(STAIR_END_X, STAIR_TOP_TOP_Y + 2.15, side_z)
		_add_walkway_between(stairs,
			"StairGuardLeft" if side < 0 else "StairGuardRight",
			rail_start, rail_finish, 0.38, 0.38, _gold_material, true)


func _add_surface_ramp_collision(parent: Node3D, node_name: String, start_surface: Vector3,
		finish_surface: Vector3, width: float, thickness: float) -> void:
	var direction := finish_surface - start_surface
	var length := direction.length()
	if length < 0.01:
		return
	var basis := Basis.looking_at(direction.normalized(), Vector3.UP)
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


func _build_platform_guardrails(station: Node3D) -> void:
	for side in [-1.0, 1.0]:
		var side_x := float(side) * 18.0
		for post_index in 6:
			var z := -16.0 + float(post_index) * 8.0
			# The arrival stair crosses the platform's left edge at z=0. The old
			# centre post and continuous rails made that entrance a solid wall.
			if side < 0.0 and absf(z) < 6.0:
				continue
			_add_box(station, "PlatformRailPost", Vector3(side_x, 1.7, z),
				Vector3(0.42, 3.4, 0.42), _gold_material, true)
		for height in [1.4, 3.1]:
			if side < 0.0:
				_add_walkway_between(station, "PlatformGuardLeft",
					Vector3(side_x, height, -16.0), Vector3(side_x, height, -6.0),
					0.38, 0.38, _gold_material, true)
				_add_walkway_between(station, "PlatformGuardLeftFront",
					Vector3(side_x, height, 6.0), Vector3(side_x, height, 24.0),
					0.38, 0.38, _gold_material, true)
			else:
				_add_walkway_between(station, "PlatformGuardRight",
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
	for carriage_index in 3:
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
		_add_box(carriage, "JumpBench", Vector3(0.0, 1.65, 2.8), Vector3(5.5, 2.0, 2.2),
			_glass_material, true)
		if carriage_index == 0:
			_add_box(carriage, "DriverConsole", Vector3(0.0, 2.0, -4.5),
				Vector3(4.8, 2.7, 1.2), _glass_material, true)
			var driver_label := Label3D.new()
			driver_label.name = "DriverControls"
			driver_label.text = "CROWN LINE DRIVER\nW  FORWARD   •   S  REVERSE"
			driver_label.position = Vector3(0.0, 4.2, -4.4)
			driver_label.font_size = 22
			driver_label.outline_size = 6
			driver_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			driver_label.no_depth_test = true
			carriage.add_child(driver_label)
		for side in [-1.0, 1.0]:
			for z in [-4.0, 4.0]:
				_add_cylinder(carriage, "StarWheel", Vector3(side * 5.4, 0.4, z), 2.1, 1.0, _gold_material, false, 16, Vector3(0.0, 0.0, 90.0))
	var engine := Node3D.new()
	engine.name = "MiloEngine"
	engine.position = Vector3(0.0, 0.0, -15.0)
	_train.add_child(engine)
	_add_box(engine, "EngineBody", Vector3(0.0, 4.0, 0.0), Vector3(12.0, 8.0, 17.0),
		_material(Color("724cc5"), 0.30, Color("aa84ff"), 1.3), true)
	_add_cylinder(engine, "CrownChimney", Vector3(0.0, 10.0, -2.0), 2.6, 8.0, _gold_material, false, 12)
	_train_glow = OmniLight3D.new()
	_train_glow.name = "GuidingLight"
	_train_glow.position = Vector3(0.0, 7.0, -10.0)
	_train_glow.light_color = Color("a8eeff")
	_train_glow.light_energy = 7.0
	_train_glow.omni_range = 38.0
	_train.add_child(_train_glow)


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
			_prompt.text = "YOU ARE DRIVING  •  HOLD W FORWARD  •  HOLD S REVERSE  •  Q EXIT WHEN DOCKED"
		else:
			_prompt.text = "RAINBOW GALAXY TRAIN  •  MILO IS GUIDING THE CROWN LINE"
		return
	if _player == null or _player.global_position.distance_to(_boarding_position(_current_station)) > INTERACTION_RANGE:
		_prompt.text = "CROWN LINE  •  Follow the glowing rails to a station"
		return
	var target := _current_station + _direction
	if target < 0 or target >= STATIONS.size():
		_direction *= -1
		target = _current_station + _direction
	if is_station_unlocked(target):
		_prompt.text = "Q  BOARD AS DRIVER  •  W/S DRIVE TO %s" % STATIONS[target].title
	else:
		_prompt.text = _locked_message(target)


func _locked_message(target: int) -> String:
	if target == 2:
		return "HEART MELODY IS LOCKED  •  Earn the Star of Wisdom in Mind Spark"
	if target == 3:
		return "CREATOR'S LIGHT IS LOCKED  •  Earn the Harmony Jewel in Heart Melody"
	return "THIS STATION HAS NOT AWAKENED YET"


func _try_depart() -> bool:
	var target := _current_station + _direction
	if target < 0 or target >= STATIONS.size():
		_direction *= -1
		target = _current_station + _direction
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
		_player.global_position = _train.to_global(PASSENGER_SEAT)
	var segment_index := mini(_current_station, target)
	var forward := target > _current_station
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(progress: float) -> void:
		_set_train_progress(segment_index, progress if forward else 1.0 - progress), 0.0, 1.0, ride_duration)
	await tween.finished
	_current_station = target
	if _current_station == STATIONS.size() - 1:
		_direction = -1
	elif _current_station == 0:
		_direction = 1
	_train.position = STATIONS[_current_station].position
	if _player != null:
		_player.global_position = to_global(STATIONS[_current_station].position + Vector3(25.0, 2.0, 0.0))
		_player.velocity = Vector3.ZERO
		_player.call("set_input_enabled", true)
	_status.text = "ARRIVED  •  Explore %s" % STATIONS[_current_station].title
	_riding = false


func _set_train_progress(segment_index: int, progress: float) -> void:
	var curve := _curves[segment_index]
	var distance := curve.get_baked_length() * clampf(progress, 0.0, 1.0)
	var point := curve.sample_baked(distance)
	var next_point := curve.sample_baked(minf(distance + 2.0, curve.get_baked_length()))
	_train.position = point
	var direction := next_point - point
	if direction.length_squared() > 0.01:
		_train.rotation.y = atan2(direction.x, direction.z)
	if _player != null:
		_player.global_position = _train.to_global(PASSENGER_SEAT)


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
		material: Material, collision: bool = false, rotation_x: float = 0.0) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position_value
	instance.rotation.x = rotation_x
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
		body.rotation.x = rotation_x
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
