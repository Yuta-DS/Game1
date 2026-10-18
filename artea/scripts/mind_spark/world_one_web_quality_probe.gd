extends Node

## Opt-in production gameplay verifier. Enable with `?world_one_quality=1`.
##
## The probe drives every quest mini-game through the same keyboard and touch
## handlers used by players, verifies a partial and full save round-trip, then
## restores the live objects and identity tracker. No real player progress is
## kept or overwritten.

const Catalog := preload("res://scripts/mind_spark/world_one_object_minigame_catalog.gd")
const PanelScript := preload("res://scripts/mind_spark/world_one_object_minigame_panel.gd")
const StateStore := preload("res://scripts/mind_spark/quest_objects/quest_object_state_store.gd")

const EXPECTED_IDS := [
	"world_one.checkpoint.landing", "world_one.path_projector",
	"world_one.spark_socket", "world_one.checkpoint.network", "world_one.focus_bell",
	"world_one.evidence_scanner", "world_one.memory_board", "world_one.logic_gate",
	"world_one.perspective_lens", "world_one.truth_bridge",
	"world_one.warden_anchor.1", "world_one.warden_anchor.2", "world_one.warden_anchor.3",
	"world_one.calm_rain_basin", "world_one.identity_reflection",
]
const PARTIAL_OBJECT_COUNT := 7
const GROUND_ZONES := [
	["01_world_gate_landing", 125.0], ["02_living_network_forest", 155.0],
	["03_constellation_court", 150.0], ["04_hope_path_ridge", 122.0],
	["05_thought_storm_arena", 175.0], ["06_oldest_tree_sanctuary", 145.0],
]

var _world: MindSparkWorldOne
var _object_store_path := ""
var _identity_store_path := ""
var _object_snapshots: Array[Dictionary] = []
var _identity_snapshot: Dictionary = {}
var _identity_tracker: Node


func configure(world: MindSparkWorldOne) -> void:
	_world = world
	call_deferred("_begin")


func _begin() -> void:
	if _world == null or not is_instance_valid(_world):
		queue_free()
		return
	var nonce := "%d_%d" % [Time.get_ticks_msec(), randi()]
	_object_store_path = "user://world_one_web_quality_objects_%s.json" % nonce
	_identity_store_path = "user://world_one_web_quality_identity_%s.json" % nonce
	var store := StateStore.new(_object_store_path)
	store.clear()
	_snapshot_identity_tracker()
	var ordered_objects := _prepare_objects(store)
	var report := {
		"expected_objects": EXPECTED_IDS.size(),
		"fresh_completed": _count_completed(ordered_objects),
		"fresh_saved": _count_saved(store, EXPECTED_IDS),
		"partial_target": PARTIAL_OBJECT_COUNT,
		"partial_saved": 0,
		"accepted_rewards": 0,
		"saved_objects": 0,
		"durable_completed": 0,
		"modes": 0,
		"touch_modes": 0,
		"controller_modes": 0,
		"controller_close": false,
		"gates_verified": 0,
		"gates_traversed": 0,
		"gate_traveler": "",
		"ground_zones_verified": 0,
		"ground_saddles_verified": 0,
		"ground_samples_hit": 0,
		"expected_portals": 2,
		"portals_verified": 0,
		"expected_portal_trips": 0,
		"portal_trips_verified": 0,
		"state_restored": false,
		"identity_restored": false,
		"errors": [],
	}
	if ordered_objects.size() != EXPECTED_IDS.size():
		(report.errors as Array).append("expected 15 live quest objects, found %d" % ordered_objects.size())
	var actor := Node3D.new()
	actor.name = "WorldOneWebQualityActor"
	_world.add_child(actor)
	var modes := {}
	var touch_modes := {}
	var controller_modes := {}
	var controller_close_mapped := false
	var accepted_ids: Array[String] = []
	for index in ordered_objects.size():
		var object := ordered_objects[index] as QuestObjectBase
		var panel := PanelScript.new()
		panel.name = "WorldOneWebQualityPanel"
		_world.add_child(panel)
		panel.open_object(object, actor)
		# Keep the panel on the real station reward path while isolating the story
		# controller. Quest and identity writes go only to temporary stores.
		panel.set("world", null)
		var mode := str(panel.call("challenge_mode"))
		modes[mode] = true
		if not touch_modes.has(mode):
			if _exercise_touch_controls(panel):
				touch_modes[mode] = true
			else:
				(report.errors as Array).append("%s touch controls failed" % mode)
		if not controller_modes.has(mode):
			if _exercise_controller_controls(panel):
				controller_modes[mode] = true
			else:
				(report.errors as Array).append("%s controller controls failed" % mode)
		controller_close_mapped = controller_close_mapped or \
			str(panel.call("_joypad_button_command", JOY_BUTTON_B)) == "close"
		panel.call("_reset_round")
		var completion := await _complete_through_player_input(panel)
		var result: Dictionary = completion.get("result", {})
		if bool(completion.get("finished", false)) and bool(result.get("accepted", false)):
			accepted_ids.append(object.save_id)
		else:
			(report.errors as Array).append("%s did not complete through player input" % object.save_id)
		panel.free()
		if index + 1 == PARTIAL_OBJECT_COUNT:
			report.partial_saved = _count_saved(store, EXPECTED_IDS)
	report.accepted_rewards = accepted_ids.size()
	report.saved_objects = _count_saved(store, EXPECTED_IDS)
	report.durable_completed = _count_completed(ordered_objects)
	report.modes = modes.size()
	report.touch_modes = touch_modes.size()
	report.controller_modes = controller_modes.size()
	report.controller_close = controller_close_mapped
	for object in ordered_objects:
		var loaded := store.load_object(object.save_id)
		if not _states_equal(loaded, object.current_state):
			(report.errors as Array).append("%s save round-trip mismatch" % object.save_id)
	actor.free()
	_restore_objects()
	report.state_restored = _objects_match_snapshots()
	report.identity_restored = _restore_identity_tracker()
	await _verify_gate_frames(report)
	_verify_world_ground(report)
	await _verify_world_portals(report)
	store.clear()
	if not _identity_store_path.is_empty() and FileAccess.file_exists(_identity_store_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_identity_store_path))
	report.ok = (report.errors as Array).is_empty() \
		and int(report.fresh_completed) == 0 \
		and int(report.fresh_saved) == 0 \
		and int(report.partial_saved) == PARTIAL_OBJECT_COUNT \
		and int(report.accepted_rewards) == EXPECTED_IDS.size() \
		and int(report.saved_objects) == EXPECTED_IDS.size() \
		and int(report.durable_completed) == 10 \
		and int(report.modes) == 5 and int(report.touch_modes) == 5 \
		and int(report.controller_modes) == 5 and bool(report.controller_close) \
		and int(report.gates_verified) == 2 and int(report.gates_traversed) == 2 \
		and int(report.ground_zones_verified) == 6 \
		and int(report.ground_saddles_verified) == 3 \
		and int(report.ground_samples_hit) == 216 \
		and int(report.portals_verified) == int(report.expected_portals) \
		and int(report.portal_trips_verified) == int(report.expected_portal_trips) \
		and bool(report.state_restored) and bool(report.identity_restored)
	_world.set_meta("web_quality_results", report.duplicate(true))
	_world.set_meta("web_quality_probe_completed", true)
	if OS.has_feature("web"):
		# Keep the result on the page as well as in the console. Browser tooling
		# can reconnect after the heavy World One build and still read the exact
		# result without repeating the 445 MB production download.
		JavaScriptBridge.eval(
			"window.__ARTEA_WORLD_ONE_QUALITY__ = %s;" % JSON.stringify(report), true)
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		for gate_number in [1, 2, 3]:
			if "gate_view=%d" % gate_number in query:
				_install_gate_review_camera(gate_number)
				break
		for island_number in [2, 3]:
			if "island_view=%d" % island_number in query:
				_install_island_review_camera(island_number)
				break
		for portal_name in ["source", "entry_side", "entry", "return"]:
			if "portal_view=%s" % portal_name in query:
				_install_portal_review_camera(portal_name)
				break
	print("WORLD_ONE_WEB_QUALITY: %s" % JSON.stringify(report))
	queue_free()


func _install_gate_review_camera(gate_number: int) -> void:
	# Test-only view of the actual browser geometry. Leave the gameplay camera
	# untouched unless a screenshot run explicitly requests this viewpoint.
	var gate := _world.get_island_one_heavenly_star_gate() if gate_number == 1 else \
		_world.get_node_or_null(
			"WorldOneGeometry/SavedQuestProgressionGates/QuestGate_%d" % gate_number) as Node3D
	if gate == null:
		return
	var camera := Camera3D.new()
	camera.name = "WebGate%dReviewCamera" % gate_number
	_world.add_child(camera)
	if gate_number == 1:
		camera.global_position = gate.to_global(Vector3(0, 7.0, -36.0))
		camera.look_at(gate.to_global(Vector3(0, 13.0, 0)), Vector3.UP)
		camera.fov = 59.0
		camera.far = 800.0
		camera.current = true
		return
	var approach_sign := -1.0 if gate_number == 3 else 1.0
	var camera_distance := 30.0 if gate_number == 3 else 42.0
	camera.global_position = gate.global_position + gate.global_basis.z.normalized() * approach_sign * camera_distance + Vector3.UP * 7.0
	camera.look_at(gate.global_position + Vector3.UP * 11.0, Vector3.UP)
	camera.fov = 60.0
	camera.far = 800.0
	camera.current = true
	var player := _world.get("_player") as CharacterBody3D
	if player != null:
		player.global_position = camera.global_position - Vector3.UP * 5.0
		player.velocity = Vector3.ZERO


func _install_island_review_camera(island_number: int) -> void:
	var eye := Vector3.ZERO
	var target := Vector3.ZERO
	if island_number == 2:
		var object := _world.get_object_by_kind(QuestObjectDefinition.ObjectKind.EVIDENCE_SCANNER)
		if object == null:
			return
		var pose := _world.get_quest_review_camera_pose(object)
		if pose.is_empty():
			return
		eye = pose.eye
		target = pose.target
	else:
		eye = _world.to_global(Vector3(300, 27, 28))
		target = _world.to_global(Vector3(430, 35, 25))
	var camera := Camera3D.new()
	camera.name = "WebIsland%dGroundReviewCamera" % island_number
	_world.add_child(camera)
	camera.global_position = eye
	camera.look_at(target, Vector3.UP)
	camera.fov = 62.0
	camera.far = 900.0
	camera.current = true
	var player := _world.get("_player") as CharacterBody3D
	if player != null:
		player.global_position = eye - Vector3.UP * 5.0
		player.velocity = Vector3.ZERO


func _install_portal_review_camera(portal_name: String) -> void:
	var gate: MindSparkWorldGate
	if portal_name == "source":
		var floating_world := _world.get_parent() as Node3D
		gate = floating_world.get_node_or_null("MindSparkWorldGate") as MindSparkWorldGate if floating_world != null else null
	elif portal_name == "entry" or portal_name == "entry_side":
		gate = _world.get_node_or_null("WorldOneGeometry/01WorldGateLanding/EntryWorldGate") as MindSparkWorldGate
	else:
		gate = _world.get_node_or_null("WorldOneGeometry/06OldestTreeSanctuary/ReturnToArtCastleWorldGate") as MindSparkWorldGate
	if gate == null:
		return
	var camera := Camera3D.new()
	camera.name = "Web%sPortalReviewCamera" % portal_name.capitalize()
	_world.add_child(camera)
	var approach_sign := -1.0 if portal_name == "return" else 1.0
	var camera_distance := 36.0 if portal_name == "source" else 40.0
	camera.global_position = gate.global_position + gate.global_basis.z.normalized() \
		* approach_sign * camera_distance + Vector3.UP * 7.0
	if portal_name == "entry_side":
		camera.global_position -= gate.global_basis.x.normalized() * 12.0
	camera.look_at(gate.global_position + Vector3.UP * 5.0, Vector3.UP)
	camera.fov = 58.0
	camera.far = 900.0
	camera.current = true
	var player := _world.get("_player") as CharacterBody3D
	if player != null:
		player.global_position = camera.global_position - Vector3.UP * 5.0
		player.velocity = Vector3.ZERO


func _verify_world_portals(report: Dictionary) -> void:
	var portal_paths := [
		"WorldOneGeometry/01WorldGateLanding/EntryWorldGate",
		"WorldOneGeometry/06OldestTreeSanctuary/ReturnToArtCastleWorldGate",
	]
	for portal_path in portal_paths:
		var portal := _world.get_node_or_null(portal_path) as MindSparkWorldGate
		if not _portal_uses_shared_design(portal):
			(report.errors as Array).append("%s lacks the Island One teleport design" % portal_path)
		else:
			report.portals_verified += 1
	var entry := _world.get_node_or_null(portal_paths[0]) as MindSparkWorldGate
	var entry_arch := _world.get_node_or_null(
		"WorldOneGeometry/01WorldGateLanding/CelestialWorldGateArrival/GateArchitectureKit/03_ThresholdStructureKit/WorldGateCelestialArch") as Node3D
	var final_portal := _world.get_node_or_null(portal_paths[1]) as MindSparkWorldGate
	var final_arch := _world.get_node_or_null(
		"WorldOneGeometry/06OldestTreeSanctuary/ReturnWorldGate") as Node3D
	if entry == null or entry_arch == null \
			or entry.global_position.distance_to(entry_arch.global_position + Vector3.UP) > 0.05 \
			or absf(wrapf(entry.global_rotation.y - entry_arch.global_rotation.y, -PI, PI)) > 0.01:
		(report.errors as Array).append("Island One return portal does not match its arch")
	if final_portal == null or final_arch == null \
			or final_portal.global_position.distance_to(final_arch.global_position + Vector3.UP) > 0.05 \
			or absf(wrapf(final_portal.global_rotation.y - final_arch.global_rotation.y, -PI, PI)) > 0.01:
		(report.errors as Array).append("Island Three return portal does not match its arch")
	var floating_world := _world.get_parent() as Node3D
	if floating_world != null and floating_world.name == "ArtCastleFloatingWorld":
		report.expected_portals = 3
		report.expected_portal_trips = 3
		var source := floating_world.get_node_or_null("MindSparkWorldGate") as MindSparkWorldGate
		if not _portal_uses_shared_design(source):
			(report.errors as Array).append("Art Castle World One entrance lacks the shared teleport design")
		else:
			report.portals_verified += 1
		await _verify_live_portal_trips(report, floating_world, source, entry, final_portal)


func _verify_live_portal_trips(report: Dictionary, floating_world: Node3D,
		source: MindSparkWorldGate, entry: MindSparkWorldGate,
		final_portal: MindSparkWorldGate) -> void:
	var player := _world.get("_player") as CharacterBody3D
	if player == null or source == null or entry == null or final_portal == null:
		(report.errors as Array).append("live World One teleport player or portal is missing")
		return
	var original_transform := player.global_transform
	var original_velocity := player.velocity
	var originally_processing := player.is_physics_processing()
	player.set_physics_process(false)
	var safe_return := floating_world.to_global(Vector3(-650, 7, 1575))
	var island_one_arrival := floating_world.to_global(
		_world.position + _world.get_player_arrival_local())
	if await _travel_portal_with_q(source, player) \
			and player.global_position.distance_to(island_one_arrival) < 0.05 \
			and player.velocity.is_zero_approx():
		report.portal_trips_verified += 1
	else:
		(report.errors as Array).append("Art Castle portal Q input did not land at Island One")
	if await _travel_portal_with_q(entry, player) \
			and player.global_position.distance_to(safe_return) < 0.05 \
			and player.velocity.is_zero_approx():
		report.portal_trips_verified += 1
	else:
		(report.errors as Array).append("Island One portal Q input did not return to the safe forecourt")
	if await _travel_portal_with_q(final_portal, player) \
			and player.global_position.distance_to(safe_return) < 0.05 \
			and player.velocity.is_zero_approx():
		report.portal_trips_verified += 1
	else:
		(report.errors as Array).append("Island Three portal Q input did not return to the safe forecourt")
	player.global_transform = original_transform
	player.velocity = original_velocity
	player.set_physics_process(originally_processing)


func _travel_portal_with_q(portal: MindSparkWorldGate,
		player: CharacterBody3D) -> bool:
	player.global_position = portal.global_position + Vector3.UP * 1.5
	player.velocity = Vector3.ZERO
	for _frame in 4:
		await get_tree().physics_frame
	var entered: bool = portal.get("_player_inside") == player
	var prompt_visible := bool(portal.get_node("Prompt").visible)
	if not entered or not prompt_visible:
		print("WORLD_ONE_PORTAL_INPUT: %s" % JSON.stringify({
			"portal": portal.name, "entered": entered, "prompt": prompt_visible,
			"stage": "before_q"}))
		return false
	var q := InputEventKey.new()
	q.keycode = KEY_Q
	q.physical_keycode = KEY_Q
	q.pressed = true
	var mapped := q.is_action_pressed("interact")
	var browser_key := OS.has_feature("web") and "portal_key_audit=1" in str(
		JavaScriptBridge.eval("window.location.search", true))
	if browser_key:
		print("WORLD_ONE_PORTAL_READY: %s" % portal.name)
		for _frame in 180:
			await get_tree().physics_frame
			if portal.get("_player_inside") != player:
				break
	else:
		Input.parse_input_event(q)
		for _frame in 4:
			await get_tree().physics_frame
		q.pressed = false
		Input.parse_input_event(q)
	print("WORLD_ONE_PORTAL_INPUT: %s" % JSON.stringify({
		"portal": portal.name, "entered": entered, "prompt": prompt_visible,
		"mapped": mapped, "player_position": player.global_position,
		"portal_position": portal.global_position,
		"still_inside": portal.get("_player_inside") == player}))
	return portal.get("_player_inside") != player


func _portal_uses_shared_design(portal: MindSparkWorldGate) -> bool:
	if portal == null:
		return false
	var frame := portal.get_node_or_null("Portal/FinishedPortalInstrument") as Node3D
	return frame != null and frame.has_node("IvoryOuterCase") \
		and frame.has_node("CharcoalInnerBezel") \
		and frame.has_node("LavenderEnergyBand") \
		and frame.has_node("CyanNavigationSigil")


func _verify_world_ground(report: Dictionary) -> void:
	var zones: Dictionary = _world.get("_zone_nodes")
	var space := _world.get_world_3d().direct_space_state
	for zone_info in GROUND_ZONES:
		var zone := zones.get(zone_info[0]) as Node3D
		var body := zone.get_node_or_null("WalkableZoneFloorCollision") as StaticBody3D if zone != null else null
		var shape_node := body.get_child(0) as CollisionShape3D if body != null and body.get_child_count() > 0 else null
		var cylinder := shape_node.shape as CylinderShape3D if shape_node != null else null
		if body == null or cylinder == null or shape_node.disabled \
				or (body.collision_layer & 1) == 0 \
				or cylinder.radius < float(zone_info[1]) - 0.01:
			(report.errors as Array).append("%s lacks its full solid ground disk" % zone_info[0])
			continue
		report.ground_zones_verified += 1
		var center := _world.to_global(_world.get_zone_position(str(zone_info[0])))
		for radius_ratio in [0.0, 0.5, 0.85]:
			for spoke in 12:
				var angle := TAU * float(spoke) / 12.0
				var sample: Vector3 = center + Vector3(cos(angle), 0, sin(angle)) \
					* cylinder.radius * radius_ratio
				var query := PhysicsRayQueryParameters3D.create(
					sample + Vector3.UP * 60.0, sample - Vector3.UP * 60.0)
				query.collision_mask = 1
				if space.intersect_ray(query).is_empty():
					(report.errors as Array).append("%s ground sample has no collision" % zone_info[0])
				else:
					report.ground_samples_hit += 1
	var geometry := _world.get_node_or_null("WorldOneGeometry") as Node3D
	if geometry == null:
		(report.errors as Array).append("World One ground geometry is missing")
		return
	for island_number in [1, 2, 3]:
		var saddle := geometry.get_node_or_null(
			"ThreeFusedSuperIslands/FusedSuperIsland_%02d_%02d/SharedIvorySaddleCollision" \
			% [island_number * 2 - 1, island_number * 2]) as StaticBody3D
		var shape_node := saddle.get_child(0) as CollisionShape3D if saddle != null and saddle.get_child_count() > 0 else null
		if saddle == null or shape_node == null or shape_node.disabled \
				or (saddle.collision_layer & 1) == 0:
			(report.errors as Array).append("island %d lacks its solid joining saddle" % island_number)
		else:
			report.ground_saddles_verified += 1


func _verify_gate_frames(report: Dictionary) -> void:
	var geometry := _world.get_node_or_null("WorldOneGeometry") as Node3D
	if geometry == null:
		(report.errors as Array).append("World One gate geometry is missing")
		return
	_world.call("_find_player")
	var traveler := _world.get("_player") as CharacterBody3D
	var live_player := traveler != null and traveler.has_node("CollisionShape3D")
	var saved_transform := Transform3D.IDENTITY
	var saved_velocity := Vector3.ZERO
	var saved_physics := false
	var saved_input := false
	if live_player:
		saved_transform = traveler.global_transform
		saved_velocity = traveler.velocity
		saved_physics = traveler.is_physics_processing()
		saved_input = traveler.is_processing_input()
		traveler.set_physics_process(false)
		traveler.set_process_input(false)
		report.gate_traveler = "production_player"
	else:
		traveler = CharacterBody3D.new()
		traveler.name = "WorldOneGateTraversalProbe"
		traveler.collision_layer = 1
		traveler.collision_mask = 1
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.height = 2.0
		capsule.radius = 0.45
		shape.shape = capsule
		traveler.add_child(shape)
		_world.add_child(traveler)
		report.gate_traveler = "test_capsule"
	for gate_number in [2, 3]:
		var gate := geometry.get_node_or_null(
			"SavedQuestProgressionGates/QuestGate_%d" % gate_number) as AnimatableBody3D
		if gate == null:
			(report.errors as Array).append("quest gate %d is missing" % gate_number)
			continue
		var facade := gate.get_node_or_null("HeavenlyStarGateFamilyFacade") as Node3D
		if facade == null:
			(report.errors as Array).append("quest gate %d lacks its matched frame" % gate_number)
			continue
		var complete_reveal := true
		for segment in 14:
			if not facade.has_node("GiltCrownReveal_%02d" % (segment + 1)):
				complete_reveal = false
		if not complete_reveal:
			(report.errors as Array).append("quest gate %d has a broken arch reveal" % gate_number)
			continue
		var leaves := facade.get_node_or_null("SharedHeavenlyGateLeaves") as Node3D
		var west := leaves.get_node_or_null("WestCelestialLeaf") as AnimatableBody3D if leaves != null else null
		var east := leaves.get_node_or_null("EastCelestialLeaf") as AnimatableBody3D if leaves != null else null
		if west == null or east == null \
				or west.get_node_or_null("LeafCollision") == null \
				or east.get_node_or_null("LeafCollision") == null:
			(report.errors as Array).append("quest gate %d lacks solid paired leaves" % gate_number)
			continue
		var initially_open := _world.is_quest_gate_open(gate_number - 1)
		_world.set_quest_gate_open(gate_number - 1, false)
		for _frame in 4:
			await get_tree().physics_frame
		var sealed := absf(west.rotation.y) < 0.01 and absf(east.rotation.y) < 0.01
		var direction := gate.global_basis.z.normalized()
		var start := gate.global_position + direction * 12.0 + Vector3.UP * 1.5
		var motion := -direction * 16.0
		traveler.global_position = start
		for _frame in 2:
			await get_tree().physics_frame
		var closed_hit := traveler.move_and_collide(motion)
		var stopped_by_leaf := closed_hit != null \
			and closed_hit.get_collider() in [west, east]
		_world.set_quest_gate_open(gate_number - 1, true)
		for _frame in 4:
			await get_tree().physics_frame
		var opened := west.rotation.y < -1.5 and east.rotation.y > 1.5
		traveler.global_position = start
		for _frame in 2:
			await get_tree().physics_frame
		var open_hit := traveler.move_and_collide(motion)
		var crossed := open_hit == null \
			and (traveler.global_position - gate.global_position).dot(direction) < -3.0
		_world.set_quest_gate_open(gate_number - 1, initially_open)
		for _frame in 3:
			await get_tree().physics_frame
		if not sealed or not opened:
			(report.errors as Array).append("quest gate %d did not close and swing open" % gate_number)
			continue
		report.gates_verified += 1
		if stopped_by_leaf and crossed:
			report.gates_traversed += 1
		else:
			(report.errors as Array).append("quest gate %d did not block closed and allow crossing open" % gate_number)
	if live_player:
		traveler.global_transform = saved_transform
		traveler.velocity = saved_velocity
		traveler.set_process_input(saved_input)
		traveler.set_physics_process(saved_physics)
	else:
		traveler.free()


func _prepare_objects(store: RefCounted) -> Array[QuestObjectBase]:
	var by_id := {}
	for object in _world.get_quest_objects():
		by_id[object.save_id] = object
	var ordered: Array[QuestObjectBase] = []
	for save_id in EXPECTED_IDS:
		var object := by_id.get(save_id) as QuestObjectBase
		if object == null:
			continue
		_object_snapshots.append({
			"object": object,
			"state": object.current_state.duplicate(true),
			"interaction_enabled": object.interaction_enabled,
			"persist_state": object.persist_state,
			"state_store_path": object.state_store_path,
			"state_store": object.state_store,
			"completion_emitted": object.get("_completion_emitted"),
			"signals_blocked": object.is_blocking_signals(),
			"had_available_sparks": object.has_meta("available_sparks"),
			"available_sparks": object.get_meta("available_sparks", 0),
		})
		object.set_block_signals(true)
		object.interaction_enabled = true
		object.persist_state = true
		object.state_store_path = _object_store_path
		object.state_store = store
		object.current_state = object.call("_default_state")
		object.set("_completion_emitted", false)
		object.set_meta("available_sparks", object.definition.validated_total())
		object.call("_apply_visual_state", false)
		ordered.append(object)
	return ordered


func _restore_objects() -> void:
	for snapshot in _object_snapshots:
		var object := snapshot.object as QuestObjectBase
		if object == null or not is_instance_valid(object):
			continue
		object.current_state = (snapshot.state as Dictionary).duplicate(true)
		object.interaction_enabled = bool(snapshot.interaction_enabled)
		object.persist_state = bool(snapshot.persist_state)
		object.state_store_path = str(snapshot.state_store_path)
		object.state_store = snapshot.state_store
		object.set("_completion_emitted", bool(snapshot.completion_emitted))
		if bool(snapshot.had_available_sparks):
			object.set_meta("available_sparks", snapshot.available_sparks)
		else:
			object.remove_meta("available_sparks")
		object.call("_apply_visual_state", false)
		object.set_block_signals(bool(snapshot.signals_blocked))


func _objects_match_snapshots() -> bool:
	for snapshot in _object_snapshots:
		var object := snapshot.object as QuestObjectBase
		if object == null or not is_instance_valid(object):
			return false
		if not _states_equal(object.current_state, snapshot.state):
			return false
		if object.interaction_enabled != bool(snapshot.interaction_enabled) \
				or object.persist_state != bool(snapshot.persist_state) \
				or object.state_store_path != str(snapshot.state_store_path) \
				or object.state_store != snapshot.state_store \
				or bool(object.get("_completion_emitted")) != bool(snapshot.completion_emitted) \
				or object.is_blocking_signals() != bool(snapshot.signals_blocked):
			return false
		if bool(snapshot.had_available_sparks):
			if not object.has_meta("available_sparks") \
					or object.get_meta("available_sparks") != snapshot.available_sparks:
				return false
		elif object.has_meta("available_sparks"):
			return false
	return true


func _snapshot_identity_tracker() -> void:
	_identity_tracker = get_node_or_null("/root/PlayerIdentityTracker")
	if _identity_tracker == null:
		return
	_identity_snapshot = {
		"save_path": str(_identity_tracker.get("save_path")),
		"evidence": (_identity_tracker.get("evidence") as Dictionary).duplicate(true),
		"counts": (_identity_tracker.get("identity_axis_counts") as Dictionary).duplicate(true),
		"ids": PackedStringArray(_identity_tracker.get("identity_evidence_ids")),
		"history": (_identity_tracker.get("identity_answer_history") as Array).duplicate(true),
		"result_code": str(_identity_tracker.get("identity_result_code")),
		"locked": bool(_identity_tracker.get("identity_locked")),
		"reveal_seen": bool(_identity_tracker.get("identity_reveal_seen")),
		"signals_blocked": _identity_tracker.is_blocking_signals(),
	}
	_identity_tracker.set_block_signals(true)
	_identity_tracker.set("save_path", _identity_store_path)
	_identity_tracker.call("clear_evidence")


func _restore_identity_tracker() -> bool:
	if _identity_tracker == null or _identity_snapshot.is_empty():
		return false
	_identity_tracker.set("save_path", _identity_snapshot.save_path)
	_identity_tracker.set("evidence", (_identity_snapshot.evidence as Dictionary).duplicate(true))
	_identity_tracker.set("identity_axis_counts", (_identity_snapshot.counts as Dictionary).duplicate(true))
	_identity_tracker.set("identity_evidence_ids", PackedStringArray(_identity_snapshot.ids))
	var restored_history: Array[Dictionary] = []
	for item in _identity_snapshot.history:
		restored_history.append((item as Dictionary).duplicate(true))
	_identity_tracker.set("identity_answer_history", restored_history)
	_identity_tracker.set("identity_result_code", _identity_snapshot.result_code)
	_identity_tracker.set("identity_locked", _identity_snapshot.locked)
	_identity_tracker.set("identity_reveal_seen", _identity_snapshot.reveal_seen)
	_identity_tracker.set_block_signals(bool(_identity_snapshot.signals_blocked))
	return _states_equal(_identity_tracker.get("evidence"), _identity_snapshot.evidence) \
		and _states_equal(_identity_tracker.get("identity_axis_counts"), _identity_snapshot.counts) \
		and PackedStringArray(_identity_tracker.get("identity_evidence_ids")) == PackedStringArray(_identity_snapshot.ids) \
		and JSON.parse_string(JSON.stringify(_identity_tracker.get("identity_answer_history"))) \
			== JSON.parse_string(JSON.stringify(_identity_snapshot.history)) \
		and str(_identity_tracker.get("identity_result_code")) == str(_identity_snapshot.result_code) \
		and bool(_identity_tracker.get("identity_locked")) == bool(_identity_snapshot.locked) \
		and bool(_identity_tracker.get("identity_reveal_seen")) == bool(_identity_snapshot.reveal_seen) \
		and str(_identity_tracker.get("save_path")) == str(_identity_snapshot.save_path) \
		and _identity_tracker.is_blocking_signals() == bool(_identity_snapshot.signals_blocked)


func _count_saved(store: RefCounted, ids: Array) -> int:
	var total := 0
	for save_id in ids:
		if not store.call("load_object", save_id).is_empty():
			total += 1
	return total


func _count_completed(objects: Array) -> int:
	var total := 0
	for object in objects:
		if bool(object.current_state.get("completed", false)):
			total += 1
	return total


func _states_equal(first: Dictionary, second: Dictionary) -> bool:
	# JSON object key order is not stable after a storage round-trip. Parse both
	# serializations back to values so equality compares fields and values.
	return JSON.parse_string(JSON.stringify(first)) == JSON.parse_string(JSON.stringify(second))


func _complete_through_player_input(panel: CanvasLayer) -> Dictionary:
	match panel.call("challenge_mode"):
		"align":
			for target in panel.get("_spec").get("targets", []):
				_steer_cursor(panel, float(target), float(panel.get("_spec").get("speed", .65)))
				_send_key(panel, KEY_SPACE)
		"route":
			var route: Array = panel.get("_spec").get("route", [])
			var hazards: Array = panel.get("_spec").get("hazards", [])
			var guard := 0
			while int(panel.get("_score")) < int(panel.get("_spec").goal) and guard < 100:
				guard += 1
				var target: Vector2i = route[int(panel.get("_score"))]
				for command in _grid_path(panel.get("_grid"), target, hazards):
					_send_command_key(panel, command)
		"rhythm":
			for command in panel.get("_spec").get("sequence", []):
				_send_command_key(panel, str(command))
		"catch", "dodge":
			_drive_falling_game(panel)
	return {"finished": bool(panel.get("_finished")), "result": panel.call("completion_result")}


func _drive_falling_game(panel: CanvasLayer) -> void:
	var guard := 0
	while not bool(panel.get("_finished")) and guard < 2400:
		guard += 1
		var desired := .5
		var falling: Array = panel.get("_falling")
		if not falling.is_empty():
			var nearest: Dictionary = falling[0]
			for item in falling:
				if float(item.y) > float(nearest.y):
					nearest = item
			if panel.call("challenge_mode") == "catch" and not bool(nearest.bad):
				desired = float(nearest.x)
			else:
				desired = .05 if float(nearest.x) > .5 else .95
		_set_keyboard_direction(panel, desired)
		panel.call("_process", .05)
		if panel.call("challenge_mode") == "dodge" and bool(panel.get("_ready_to_strike")):
			_send_key(panel, KEY_SPACE)
	_set_keyboard_direction(panel, float((panel.get("_cursor") as Vector2).x))


func _steer_cursor(panel: CanvasLayer, target: float, speed: float) -> void:
	var current := float((panel.get("_cursor") as Vector2).x)
	if absf(target - current) <= .002:
		return
	var command := "right" if target > current else "left"
	_send_direction(panel, command, true)
	panel.call("_process", absf(target - current) / speed)
	_send_direction(panel, command, false)


func _set_keyboard_direction(panel: CanvasLayer, target: float) -> void:
	var current := float((panel.get("_cursor") as Vector2).x)
	_send_direction(panel, "left", target < current - .018)
	_send_direction(panel, "right", target > current + .018)


func _send_command_key(panel: CanvasLayer, command: String) -> void:
	var keys := {"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN}
	if keys.has(command):
		_send_key(panel, keys[command])


func _send_key(panel: CanvasLayer, keycode: Key) -> void:
	_send_key_state(panel, keycode, true)
	_send_key_state(panel, keycode, false)


func _send_direction(panel: CanvasLayer, command: String, pressed: bool) -> void:
	_send_key_state(panel, KEY_LEFT if command == "left" else KEY_RIGHT, pressed)


func _send_key_state(panel: CanvasLayer, keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	panel.call("_unhandled_input", event)


func _grid_path(start: Vector2i, target: Vector2i, hazards: Array) -> Array[String]:
	var frontier: Array[Vector2i] = [start]
	var paths := {start: []}
	var steps := {"left": Vector2i.LEFT, "right": Vector2i.RIGHT,
		"up": Vector2i.UP, "down": Vector2i.DOWN}
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		if cell == target:
			var result: Array[String] = []
			result.assign(paths[cell])
			return result
		for command in steps:
			var next: Vector2i = cell + steps[command]
			if next.x < 0 or next.x > 2 or next.y < 0 or next.y > 2:
				continue
			if next in hazards or paths.has(next):
				continue
			var next_path: Array[String] = []
			next_path.assign(paths[cell])
			next_path.append(command)
			paths[next] = next_path
			frontier.append(next)
	return []


func _exercise_touch_controls(panel: CanvasLayer) -> bool:
	var buttons := {}
	for candidate in panel.find_children("*", "Button", true, false):
		var button := candidate as Button
		if button.has_meta("minigame_command"):
			buttons[str(button.get_meta("minigame_command"))] = button
	if not buttons.has("left") or not buttons.has("right") or not buttons.has("action"):
		return false
	match panel.call("challenge_mode"):
		"align", "catch", "dodge":
			var before := float((panel.get("_cursor") as Vector2).x)
			(buttons.left as Button).button_down.emit()
			panel.call("_process", .12)
			(buttons.left as Button).button_up.emit()
			return float((panel.get("_cursor") as Vector2).x) < before
		"route", "rhythm":
			(buttons.left as Button).pressed.emit()
			(buttons.action as Button).pressed.emit()
			return int(panel.get("_score")) <= 1
	return false


func _exercise_controller_controls(panel: CanvasLayer) -> bool:
	match panel.call("challenge_mode"):
		"align":
			var before := float((panel.get("_cursor") as Vector2).x)
			_send_joy_axis(panel, JOY_AXIS_LEFT_X, -1.0)
			panel.call("_process", .12)
			_send_joy_axis(panel, JOY_AXIS_LEFT_X, 0.0)
			var moved := float((panel.get("_cursor") as Vector2).x) < before
			var targets: Array = panel.get("_spec").get("targets", [])
			if targets.is_empty():
				return false
			panel.set("_cursor", Vector2(float(targets[0]), .5))
			_send_joy_button(panel, "action")
			return moved and int(panel.get("_score")) == 1
		"catch", "dodge":
			var before := float((panel.get("_cursor") as Vector2).x)
			_send_joy_axis(panel, JOY_AXIS_LEFT_X, -1.0)
			panel.call("_process", .12)
			_send_joy_axis(panel, JOY_AXIS_LEFT_X, 0.0)
			return float((panel.get("_cursor") as Vector2).x) < before
		"route":
			var route: Array = panel.get("_spec").get("route", [])
			var hazards: Array = panel.get("_spec").get("hazards", [])
			if route.is_empty() or int(panel.get("_score")) >= route.size():
				return false
			var path := _grid_path(panel.get("_grid"), route[int(panel.get("_score"))], hazards)
			if path.is_empty():
				return false
			var before: Vector2i = panel.get("_grid")
			_send_joy_button(panel, path[0])
			return (panel.get("_grid") as Vector2i) != before
		"rhythm":
			var sequence: Array = panel.get("_spec").get("sequence", [])
			if sequence.is_empty():
				return false
			_send_joy_button(panel, str(sequence[0]))
			return int(panel.get("_score")) == 1
	return false


func _send_joy_button(panel: CanvasLayer, command: String) -> void:
	var buttons := {
		"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT,
		"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN,
		"action": JOY_BUTTON_A,
	}
	var event := InputEventJoypadButton.new()
	event.button_index = buttons[command]
	event.pressed = true
	panel.call("_unhandled_input", event)
	event.pressed = false
	panel.call("_unhandled_input", event)


func _send_joy_axis(panel: CanvasLayer, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	panel.call("_unhandled_input", event)
