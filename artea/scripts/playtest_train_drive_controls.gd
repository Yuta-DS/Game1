extends SceneTree

# Plays the Crown Line the way a player does, with a real character.
#
# Nothing here teleports the player onto an interaction point. The fox walks the
# coach deck under injected W/A/S/D key events, presses the real Q binding to
# take the cab, then holds W and S to drive. Each stage is rendered to
# res://artifacts so the controls can be checked by eye as well as by assertion.

const OUTPUT_DIR := "res://artifacts"
const RAILWAY_SCRIPT := "res://scripts/art_castle_story_railway.gd"
const STATION_TITLES := ["ARTÉA GALLERY", "MIND SPARK", "HEART MELODY", "CREATOR'S LIGHT"]

var _root_world: Node3D
var _player: CharacterBody3D
var _railway: Node3D
var _train: Node3D
var _camera: Camera3D
var _held: Dictionary = {}


func _init() -> void:
	call_deferred("_play")


func _fail(message: String) -> void:
	push_error("TRAIN_PLAYTEST: %s" % message)
	_release_all()
	quit(1)


# --- input injection ----------------------------------------------------
#
# Real InputEventKey presses through Input.parse_input_event, so the player's
# Input.get_vector() and the railway's is_action_pressed("interact") both see
# exactly what a keyboard would deliver. The project binds movement and Q by
# physical keycode, so these events must set physical_keycode too.

func _key_event(physical_keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	event.keycode = physical_keycode
	event.pressed = pressed
	return event


func _hold(physical_keycode: Key) -> void:
	if _held.has(physical_keycode):
		return
	_held[physical_keycode] = true
	Input.parse_input_event(_key_event(physical_keycode, true))


func _release(physical_keycode: Key) -> void:
	if not _held.has(physical_keycode):
		return
	_held.erase(physical_keycode)
	Input.parse_input_event(_key_event(physical_keycode, false))


func _release_all() -> void:
	for physical_keycode in _held.keys():
		Input.parse_input_event(_key_event(physical_keycode, false))
	_held.clear()


func _tap(physical_keycode: Key) -> void:
	Input.parse_input_event(_key_event(physical_keycode, true))
	await process_frame
	Input.parse_input_event(_key_event(physical_keycode, false))
	await process_frame


# Runs the game forward for a real span of time while any held keys stay down.
func _play_frames(frame_count: int) -> void:
	for _frame in frame_count:
		await process_frame


func _save(path: String) -> void:
	for _frame in 4:
		await process_frame
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		_fail("display renderer did not provide a viewport texture")
		return
	var image := viewport_texture.get_image()
	if image == null:
		_fail("display renderer did not provide a viewport image")
		return
	if image.save_png(path) != OK:
		_fail("could not write %s" % path)
		return
	print("TRAIN_PLAYTEST: saved %s" % path)


# Keeps the chase camera behind the fox, looking up the train toward the cab.
# The player moves camera-relative, so this is not set dressing: it defines
# which way W walks. The offset is expressed in the train's own axes because the
# train yaws to face its route, so a fixed world offset would point the camera
# across the deck instead of along it at three of the four stations.
func _follow_player(_look_offset := Vector3(0.0, 1.2, 0.0)) -> void:
	# CameraFollow orbits itself; the playtest only decides which way it faces,
	# because that is what defines the direction W walks. Aim it down the train's
	# own +Z so holding W carries the fox forward along the deck toward the cab.
	if _camera == null or _train == null:
		return
	# The cab is at the train's -Z end and the benches are at +Z, so the fox has
	# to walk along -Z. CameraFollow places itself at
	# focus + (sin(yaw), _, cos(yaw)) * distance and looks back along that, so
	# the camera must sit on the +Z side for its forward to point at the cab.
	var walk_direction := -_train.global_transform.basis.z
	_camera.set("_yaw", atan2(-walk_direction.x, -walk_direction.z))
	# CameraFollow eases toward its orbit target, so a freshly set yaw needs a
	# few frames before the camera's basis actually points that way. The player
	# moves relative to that basis, so walking before it settles goes sideways.
	_camera.call("_snap_to_follow_target")


func _play() -> void:
	root.size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	_root_world = Node3D.new()
	_root_world.name = "ArtCastleFloatingWorld"
	root.add_child(_root_world)

	_player = CharacterBody3D.new()
	_player.name = "Player3D"
	_player.set_script(load("res://player_3d.gd"))
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.8
	body_shape.shape = capsule
	_player.add_child(body_shape)
	# The same fox used by the live castle world, so these are character
	# screenshots rather than an invisible capsule sliding around.
	var fox_scene := load("res://assets3D/characters/fox.glb") as PackedScene
	if fox_scene != null:
		var fox := fox_scene.instantiate() as Node3D
		fox.name = "Fox"
		fox.scale = Vector3.ONE * 3.0
		fox.position = Vector3(0.0, -0.98, 0.0)
		_player.add_child(fox)
	_root_world.add_child(_player)

	_railway = Node3D.new()
	_railway.name = "StoryCrownRailway"
	_railway.set_script(load(RAILWAY_SCRIPT))
	# The scenic passenger ride is 14 s of real time. Shorten it here so the
	# playtest is not mostly spent watching scenery; the controls under test are
	# unaffected by how long the automatic leg takes.
	_railway.set("ride_duration", 2.5)
	_root_world.add_child(_railway)

	for _frame in 6:
		await process_frame

	_train = _railway.get_node_or_null("RainbowGalaxyTrain") as Node3D
	if _train == null:
		_fail("the Crown Line train was not built")
		return

	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color("142b42")
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("bfe7ff")
	environment_resource.ambient_light_energy = 0.5
	environment.environment = environment_resource
	_root_world.add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("fff0c9")
	sun.light_energy = 0.8
	_root_world.add_child(sun)

	# The real third-person camera, so scroll zoom and the 1/2 view keys are
	# exercised here exactly as the gallery scene runs them.
	_camera = Camera3D.new()
	_camera.fov = 60.0
	_camera.set_script(load("res://scripts/CameraFollow.gd"))
	_camera.set("capture_mouse", false)
	# player_path must be set before the camera enters the tree: CameraFollow
	# resolves it in _ready, and a path assigned afterwards leaves it following
	# nothing for the rest of the run.
	_camera.set("player_path", NodePath("../Player3D"))
	_camera.add_to_group("follow_camera")
	_root_world.add_child(_camera)
	_camera.make_current()

	# Stand the fox on the rear of the coach deck: the passenger end, away from
	# the cab. Everything after this point is walking and key presses.
	_player.global_position = _train.to_global(Vector3(0.0, 2.6, 4.5))
	for _frame in 20:
		_follow_player()
		await process_frame

	if String(_railway.call("get_interaction_mode_for_position",
			_player.global_position)) != "sit":
		_fail("standing at the bench end of the deck did not offer a seat")
		return
	_follow_player()
	await _save(OUTPUT_DIR + "/playtest_01_standing_on_deck.png")

	# 1. Sit down with the real Q binding, then stand back up with it.
	await _tap(KEY_Q)
	await _play_frames(4)
	if not bool(_railway.call("is_passenger_seated")):
		_fail("Q at the benches did not seat the character")
		return
	_follow_player()
	await _save(OUTPUT_DIR + "/playtest_02_seated_passenger.png")
	print("TRAIN_PLAYTEST: Q seated the character as a passenger")

	# Sitting departs for the next station by design, and Q is refused while the
	# coach is moving ("EXIT AT THE NEXT STATION"). Ride it out, which also
	# proves the passenger trip itself works, then stand up at the far platform.
	if not bool(_railway.call("is_passenger_train_moving")):
		_fail("sitting down did not start the passenger ride")
		return
	var ride_guard := 0
	while bool(_railway.call("is_passenger_train_moving")) and ride_guard < 6000:
		if ride_guard % 40 == 0:
			_camera.global_position = _train.to_global(Vector3(22.0, 10.0, 26.0))
			_camera.look_at(_train.to_global(Vector3(0.0, 3.0, 0.0)), Vector3.UP)
		await process_frame
		ride_guard += 1
	if bool(_railway.call("is_passenger_train_moving")):
		_fail("the passenger ride never arrived at the next station")
		return
	print("TRAIN_PLAYTEST: rode as a passenger to %s"
		% STATION_TITLES[int(_railway.call("get_current_station"))])
	await _save(OUTPUT_DIR + "/playtest_02b_passenger_arrived.png")

	await _tap(KEY_Q)
	await _play_frames(4)
	if bool(_railway.call("is_passenger_seated")):
		_fail("Q did not stand the character back up after arriving")
		return

	# 2a. Walk the full length of the train, starting from the rear coach, so the
	#     route crosses the gangway between the two carriages. That gap used to
	#     be an open hole straight through to the rail.
	_player.global_position = _train.to_global(Vector3(0.0, 2.6, 19.0))
	for _frame in 20:
		_follow_player()
		await process_frame
	# Long enough to cover the ~25 m from the rear bench to the cab at walking
	# pace, checking every frame that the floor is still under the character.
	_hold(KEY_W)
	for _frame in 600:
		_follow_player()
		await process_frame
		var crossing_y := _train.to_local(_player.global_position).y
		if crossing_y < 1.0:
			_release(KEY_W)
			_fail("the character fell through the train while crossing between coaches (local y %.2f)"
				% crossing_y)
			return
		if _train.to_local(_player.global_position).z <= 0.0:
			break
	_release(KEY_W)
	await _play_frames(6)
	var crossed_to := _train.to_local(_player.global_position).z
	if crossed_to > 6.0:
		_fail("the character never crossed the gangway into the front coach (stopped at z %.1f)"
			% crossed_to)
		return
	print("TRAIN_PLAYTEST: walked the full train across the gangway to z %.1f" % crossed_to)
	_follow_player()
	await _save(OUTPUT_DIR + "/playtest_02c_crossed_gangway.png")

	# 2. Walk forward along the deck to the cab. The player moves relative to the
	#    camera, which sits behind the fox looking up the train, so holding W
	#    carries it toward the engine.
	var walk_start := _player.global_position
	_hold(KEY_W)
	for _frame in 90:
		_follow_player()
		await process_frame
	_release(KEY_W)
	await _play_frames(6)
	var walked := _player.global_position.distance_to(walk_start)
	if walked < 1.0:
		_fail("holding W did not walk the character along the deck (%.2f m)" % walked)
		return
	# Walking the deck must not drop the character through it. The coach floor is
	# at local y=1.3, so anything well below that means they fell between the
	# carriages or off the side rather than walking the length of the train.
	var deck_local_y := _train.to_local(_player.global_position).y
	if deck_local_y < 1.0:
		_fail("the character fell off or through the deck while walking (local y %.2f)"
			% deck_local_y)
		return
	print("TRAIN_PLAYTEST: walked %.2f m up the deck toward the cab" % walked)

	var mode := String(_railway.call("get_interaction_mode_for_position",
		_player.global_position))
	if mode != "drive":
		_fail("walking to the front of the deck offered '%s', not the driver cab" % mode)
		return
	_follow_player()
	await _save(OUTPUT_DIR + "/playtest_03_walked_to_cab.png")

	# 3. Take the cab with Q.
	await _tap(KEY_Q)
	await _play_frames(4)
	if not bool(_railway.call("is_driving")):
		_fail("Q at the cab did not take control of the train")
		return
	print("TRAIN_PLAYTEST: Q took the driver cab")

	# Boarding must force the third-person view, whatever the player was using.
	if String(_camera.call("get_view_mode")) != "third":
		_fail("taking the cab did not switch to the third-person view")
		return
	if not bool(_camera.call("is_ride_view_active")):
		_fail("taking the cab did not engage the ride camera")
		return

	# 1 drops to first person, 2 comes back out, both while driving.
	await _tap(KEY_1)
	if String(_camera.call("get_view_mode")) != "first":
		_fail("pressing 1 did not switch to first person")
		return
	await _play_frames(4)
	# The camera sits at the character's eye, so the character's own mesh must be
	# hidden — otherwise first person is just the inside of the fox's head.
	var fox_visual := _player.get_node_or_null("Fox") as Node3D
	if fox_visual != null and fox_visual.visible:
		_fail("first person did not hide the character's own model")
		return
	await _save(OUTPUT_DIR + "/playtest_04a_first_person_cab.png")
	await _tap(KEY_2)
	if String(_camera.call("get_view_mode")) != "third":
		_fail("pressing 2 did not switch back to third person")
		return
	print("TRAIN_PLAYTEST: 1 and 2 switch first/third person while driving")

	# Scroll wheel widens the view for sightseeing.
	var zoom_before := float(_camera.get("follow_distance"))
	for _scroll in 5:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		Input.parse_input_event(wheel)
		await process_frame
	var zoom_after := float(_camera.get("follow_distance"))
	if zoom_after <= zoom_before:
		_fail("scrolling did not widen the third-person view (%.1f -> %.1f)"
			% [zoom_before, zoom_after])
		return
	print("TRAIN_PLAYTEST: scroll widened the view %.1f -> %.1f m"
		% [zoom_before, zoom_after])
	_camera.global_position = _train.to_global(Vector3(16.0, 9.0, 18.0))
	_camera.look_at(_train.to_global(Vector3(0.0, 3.0, -6.0)), Vector3.UP)
	await _save(OUTPUT_DIR + "/playtest_04_driving_cab.png")

	# 4. Hold W: the train must pull away and gain speed.
	var drive_start := _train.global_position
	_hold(KEY_W)
	for _frame in 150:
		await process_frame
	var forward_speed := float(_railway.call("get_display_speed_kph"))
	var forward_travel := _train.global_position.distance_to(drive_start)
	_release(KEY_W)
	if forward_travel < 5.0:
		_fail("holding W did not move the train (%.2f m)" % forward_travel)
		return
	if forward_speed <= 0.0:
		_fail("holding W did not build any speed")
		return
	print("TRAIN_PLAYTEST: W drove the train %.1f m forward at %d km/h"
		% [forward_travel, roundi(forward_speed)])
	_camera.global_position = _train.to_global(Vector3(26.0, 12.0, 30.0))
	_camera.look_at(_train.to_global(Vector3(0.0, 3.0, -8.0)), Vector3.UP)
	await _save(OUTPUT_DIR + "/playtest_05_driving_forward.png")

	# The driver must still be in the cab, not left standing on the platform.
	if _player.global_position.distance_to(
			_railway.call("get_driver_seat_position")) > 1.5:
		_fail("the driver did not travel with the train")
		return

	# 5. Hold S: the train must slow, stop and come back the other way.
	var reverse_start := _train.global_position
	_hold(KEY_S)
	for _frame in 260:
		await process_frame
	_release(KEY_S)
	await _play_frames(6)
	var came_back := _train.global_position.distance_to(drive_start) \
		< reverse_start.distance_to(drive_start)
	if not came_back:
		_fail("holding S did not drive the train back the way it came")
		return
	print("TRAIN_PLAYTEST: S reversed the train back toward Gallery Station")
	_camera.global_position = _train.to_global(Vector3(26.0, 12.0, 30.0))
	_camera.look_at(_train.to_global(Vector3(0.0, 3.0, -8.0)), Vector3.UP)
	await _save(OUTPUT_DIR + "/playtest_06_driving_reverse.png")

	# 6. Roll back into the dock and leave the cab with Q.
	_hold(KEY_S)
	var guard := 0
	while int(_railway.call("get_drive_segment")) >= 0 and guard < 3000:
		await process_frame
		guard += 1
	_release(KEY_S)
	await _play_frames(6)
	if int(_railway.call("get_drive_segment")) >= 0:
		_fail("the train never rolled back into a station")
		return

	await _tap(KEY_Q)
	await _play_frames(6)
	if bool(_railway.call("is_driving")):
		_fail("Q at the dock did not release the driver")
		return
	if not bool(_player.get("input_enabled")):
		_fail("walking control was not handed back after leaving the cab")
		return
	print("TRAIN_PLAYTEST: Q left the cab and returned walking control")
	_follow_player()
	await _save(OUTPUT_DIR + "/playtest_07_left_the_cab.png")

	_release_all()
	print("TRAIN_PLAYTEST: PASS — walked the deck, Q sat, Q drove, W forward, S reverse, Q exited")
	quit()
