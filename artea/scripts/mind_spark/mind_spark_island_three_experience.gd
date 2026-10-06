class_name MindSparkIslandThreeExperience
extends Node3D

## Island Three's authored storm-to-sanctuary layer. The quest controller owns
## durable progress; this node owns spatial interaction and environmental pose.

signal progress_requested(action: String, value: Variant)

const LIGHT_IDS := ["notice", "evidence", "perspective", "choice"]
const LIGHT_LABELS := {
	"notice": "NOTICE • I can pause and observe",
	"evidence": "EVIDENCE • I can test what is true",
	"perspective": "PERSPECTIVE • I can look again",
	"choice": "CHOICE • I can choose one next step",
}
const INTERACTION_RANGE := 12.0
const STORM_DIRECTIONS := ["WEST → EAST", "NORTH → SOUTH", "INWARD SPIRAL"]
const STORM_PHASES := ["RISING", "FALLING"]
const STORM_APERTURES := ["WIDE", "NARROW"]
const CORRECT_READER_STATE := {"direction": 0, "phase": 1, "aperture": 1}

var _compact := false
var _task_index := -1
var _state := {}
var _stations := {}
var _light_nodes := {}
var _link_nodes: Array[MeshInstance3D] = []
var _storm_lines: Array[MeshInstance3D] = []
var _storm_light: OmniLight3D
var _sanctuary_light: OmniLight3D
var _rain: GPUParticles3D
var _tree_crown: Node3D
var _star: Node3D
var _reader_pointers: Array[MeshInstance3D] = []
var _reader_glass: MeshInstance3D
var _reader_feedback_strip: MeshInstance3D
var _material_cache := {}


func configure(world: Node3D, compact: bool) -> void:
	_compact = compact
	name = "IslandThreeStormToSanctuary"
	set_meta("preserve_authored_nodes", true)
	set_meta("districts", PackedStringArray(["05_thought_storm_arena", "06_oldest_tree_sanctuary"]))
	set_meta("design_contract", "observe, dodge, repair, transform, recall, connect, choose")
	var storm_center: Vector3 = world.call("get_zone_position", "05_thought_storm_arena")
	var sanctuary_center: Vector3 = world.call("get_zone_position", "06_oldest_tree_sanctuary")
	_build_storm_arena(storm_center)
	_build_sanctuary(sanctuary_center)


func restore_state(state: Dictionary, task_index: int, world_complete: bool) -> void:
	var previous_reader := Vector3i(
		int(_state.get("reader_direction", -1)),
		int(_state.get("reader_phase", -1)),
		int(_state.get("reader_aperture", -1)))
	_state = state.duplicate(true)
	_task_index = task_index
	var preview_read := bool(_state.get("storm_preview_read", false)) or task_index > 8
	var rain_started := bool(_state.get("rain_started", false)) or world_complete
	var recalled: Array = _state.get("recalled_lights", [])
	var links: Array = _state.get("constellation_links", [])
	for line in _storm_lines:
		line.visible = task_index == 8 and not preview_read
	_storm_light.light_color = Color("9869d8") if not rain_started else Color("76c9cf")
	_storm_light.light_energy = 1.55 if not rain_started else 0.48
	_sanctuary_light.light_energy = 1.15 if rain_started else 0.22
	_rain.emitting = rain_started
	_tree_crown.visible = rain_started
	for light_id in LIGHT_IDS:
		_set_light_pose(light_id, recalled.has(light_id))
	for index in _link_nodes.size():
		_link_nodes[index].visible = index < links.size() or world_complete
	_star.visible = not str(_state.get("star_choice", "")).is_empty() or world_complete
	var current_reader := Vector3i(
		int(_state.get("reader_direction", 2)),
		int(_state.get("reader_phase", 0)),
		int(_state.get("reader_aperture", 0)))
	_apply_reader_pose(previous_reader.x >= 0 and previous_reader != current_reader)
	_update_station_labels()


func prompt_for_player(player: Node3D) -> Dictionary:
	var station_id := _nearest_station_id(player)
	if station_id.is_empty():
		return {}
	match station_id:
		"storm_reader":
			return {
				"prompt": "1 DIRECTION  •  2 PHASE  •  3 APERTURE  •  Q TEST",
				"status": "%s  |  %s  |  %s" % [
					STORM_DIRECTIONS[int(_state.get("reader_direction", 2))],
					STORM_PHASES[int(_state.get("reader_phase", 0))],
					STORM_APERTURES[int(_state.get("reader_aperture", 0))],
				],
			}
		"constellation":
			return {"prompt": "Q • CONNECT THE NEXT TWO EARNED LIGHTS", "status": "%d/3 connections • any connected shape is valid" % (_state.get("constellation_links", []) as Array).size()}
		"star":
			return {"prompt": "1 RECEIVE   2 CARRY BESIDE ME   3 JOIN THE CROWN", "status": "Every choice grants the same Star of Wisdom"}
		_:
			if station_id.begins_with("light_"):
				var light_id := station_id.trim_prefix("light_")
				return {"prompt": "Q • RECALL " + light_id.to_upper(), "status": LIGHT_LABELS[light_id]}
	return {}


func handle_input(event: InputEvent, player: Node3D) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	var station_id := _nearest_station_id(player)
	if station_id.is_empty():
		return false
	if station_id == "star" and event.keycode in [KEY_1, KEY_2, KEY_3]:
		progress_requested.emit("choose_star", ["receive", "carry_beside", "join_crown"][event.keycode - KEY_1])
		return true
	if station_id == "storm_reader" and event.keycode in [KEY_1, KEY_2, KEY_3]:
		var control: String = ["direction", "phase", "aperture"][event.keycode - KEY_1]
		var current := int(_state.get("reader_" + control, 0))
		var option_count: int = [STORM_DIRECTIONS.size(), STORM_PHASES.size(), STORM_APERTURES.size()][event.keycode - KEY_1]
		progress_requested.emit("adjust_storm_reader", {"control": control, "value": (current + 1) % option_count})
		return true
	if event.keycode != KEY_Q:
		return false
	if station_id == "storm_reader":
		progress_requested.emit("test_storm_reader", {
			"direction": int(_state.get("reader_direction", 2)),
			"phase": int(_state.get("reader_phase", 0)),
			"aperture": int(_state.get("reader_aperture", 0)),
		})
	elif station_id.begins_with("light_"):
		progress_requested.emit("recall_light", station_id.trim_prefix("light_"))
	elif station_id == "constellation":
		progress_requested.emit("connect_lights", null)
	else:
		return false
	return true


func interact_for_test(station_id: String, action := "primary", value: Variant = null) -> bool:
	if station_id == "storm_reader":
		if action == "adjust" and value is Dictionary:
			progress_requested.emit("adjust_storm_reader", value)
		elif action == "test":
			progress_requested.emit("test_storm_reader", value)
		else:
			# Compatibility path for existing automated story tests.
			progress_requested.emit("read_storm", "west_to_east")
	elif station_id.begins_with("light_"): progress_requested.emit("recall_light", station_id.trim_prefix("light_"))
	elif station_id == "constellation": progress_requested.emit("connect_lights", null)
	elif station_id == "star" and action == "choose": progress_requested.emit("choose_star", value)
	else: return false
	return true


func station_ids() -> PackedStringArray:
	return PackedStringArray(_stations.keys())


func _nearest_station_id(player: Node3D) -> String:
	if player == null:
		return ""
	var best := ""
	var best_distance := INTERACTION_RANGE if _compact else INTERACTION_RANGE * 2.2
	for station_id in _stations:
		var station := _stations[station_id] as Node3D
		if not station.visible:
			continue
		var distance := player.global_position.distance_to(station.global_position)
		if distance < best_distance:
			best = station_id
			best_distance = distance
	return best


func _build_storm_arena(center: Vector3) -> void:
	var root := Node3D.new()
	root.name = "StormworksBastion"
	root.position = center
	add_child(root)
	var scale_factor := 1.0 if _compact else 2.8
	# A readable storm harvester occupies the rear edge, leaving the combat apron clear.
	for side in [-1.0, 1.0]:
		var bank := Vector3(side * 18, 3.2, 18) * scale_factor
		_cylinder(root, "PressureBankFoot", Vector3(bank.x, 0.5 * scale_factor, bank.z),
			3.4 * scale_factor, 1.0 * scale_factor, Color("e8dfc7"), 10)
		_cylinder(root, "PressureBank", bank, 2.6 * scale_factor, 6.4 * scale_factor, Color("263f4a"), 10)
		_torus(root, "PressureCollar", bank + Vector3.UP * 2.1 * scale_factor, 2.7 * scale_factor, 3.15 * scale_factor, Color("d0aa58"))
		_torus(root, "PressureLowerCollar", bank - Vector3.UP * 2.1 * scale_factor, 2.7 * scale_factor, 3.15 * scale_factor, Color("d0aa58"))
		_box(root, "PressureSightGlass", bank + Vector3(0, 0, -2.62 * scale_factor),
			Vector3(1.2, 3.8, 0.22) * scale_factor, Color("65c9c8"), false)
		_box(root, "ProtectedServiceGallery", Vector3(side * 18, 0.7, 9) * scale_factor, Vector3(8, 1.1, 3) * scale_factor, Color("e5ddca"), true)
	var anchor_positions: Array[Vector3] = [Vector3(-28, 1, 12), Vector3(0, 1, -28), Vector3(28, 1, 12)]
	for index in 3:
		var anchor_at: Vector3 = anchor_positions[index] * scale_factor
		_beam(root, "AnchorConduit%02d" % (index + 1), anchor_at + Vector3.UP * scale_factor, Vector3(0, 1, 0), 0.28 * scale_factor, Color("9d63d8"))
	var reader_at := Vector3(-20, 1.2, -18) * scale_factor
	var reader := _station(root, "storm_reader", "StormLineReader", reader_at)
	reader.set_meta("low_poly_production_object", true)
	reader.set_meta("visual_verb", "read direction")
	# A small instrument portico gives the reader an architectural home and a
	# clear frontal approach, matching the observatory stations on Island One.
	for side in [-1.0, 1.0]:
		_box(reader, "ReaderPorticoFoot", Vector3(side * 4.2, 0.5, 1.0) * scale_factor,
			Vector3(2.0, 1.0, 3.0) * scale_factor, Color("e8dfc7"), true)
		_beam(reader, "ReaderPorticoPier", Vector3(side * 4.2, 1.0, 1.0) * scale_factor,
			Vector3(side * 4.2, 7.0, 1.0) * scale_factor, 0.72 * scale_factor,
			Color("e8dfc7"))
		_beam(reader, "ReaderGiltBrace", Vector3(side * 4.2, 6.5, 0.8) * scale_factor,
			Vector3(side * 1.3, 8.2, 0.8) * scale_factor, 0.22 * scale_factor,
			Color("cba653"))
	_beam(reader, "ReaderPorticoCrown", Vector3(-4.2, 7.0, 1.0) * scale_factor,
		Vector3(4.2, 7.0, 1.0) * scale_factor, 0.86 * scale_factor,
		Color("e8dfc7"))
	_cylinder(reader, "ReaderIvoryFoot", Vector3(0, 0.25, 0) * scale_factor,
		3.4 * scale_factor, 0.5 * scale_factor, Color("e8dfc7"), 10, true)
	_cylinder(reader, "ReaderBrassStep", Vector3(0, 0.58, 0) * scale_factor,
		2.9 * scale_factor, 0.28 * scale_factor, Color("cba653"), 10)
	_box(reader, "ReaderConsole", Vector3(0, 1.45, 0) * scale_factor,
		Vector3(4.8, 1.45, 2.4) * scale_factor, Color("e7dfcd"), true)
	_box(reader, "ReaderTealFace", Vector3(0, 1.62, -1.22) * scale_factor,
		Vector3(3.7, 0.82, 0.16) * scale_factor, Color("315e63"), false)
	_reader_feedback_strip = reader.get_node("ReaderTealFace") as MeshInstance3D
	for dial_index in 3:
		_cylinder(reader, "BearingSelector%02d" % (dial_index + 1),
			Vector3(-1.25 + dial_index * 1.25, 2.26, -0.55) * scale_factor,
			0.34 * scale_factor, 0.22 * scale_factor, Color("71d6cf"), 8)
		var pointer := _box(reader, "SelectorPointer%02d" % (dial_index + 1),
			Vector3(-1.25 + dial_index * 1.25, 2.41, -0.78) * scale_factor,
			Vector3(0.12, 0.11, 0.52) * scale_factor, Color("d0aa58"), false)
		_reader_pointers.append(pointer)
	for side in [-1.0, 1.0]:
		_beam(reader, "LensBrace", Vector3(side * 1.7, 2.0, 0) * scale_factor,
			Vector3(side * 1.7, 4.6, 0) * scale_factor, 0.20 * scale_factor, Color("cba653"))
	_torus(reader, "ForecastLens", Vector3(0, 4.25, 0) * scale_factor,
		1.45 * scale_factor, 1.82 * scale_factor, Color("d0aa58"), Vector3(90, 0, 0))
	_reader_glass = _cylinder(reader, "ForecastGlass", Vector3(0, 4.25, 0) * scale_factor, 1.25 * scale_factor,
		0.12 * scale_factor, Color("65c9c8"), 10)
	_reader_glass.rotation_degrees.x = 90
	_reader_glass.material_override = _glass_material(Color("65c9c8", 0.54), false)
	_label(reader, "READ THE STORM", Vector3(0, 6.2, 0) * scale_factor, Color("efe8ff"), 30)
	for index in 3:
		var line := _box(root, "ForecastLine%02d" % index, Vector3(-8 + index * 8, 0.5, -4 + index * 5) * scale_factor, Vector3(13, 0.18, 1.1) * scale_factor, Color("bb72ee"), false)
		line.rotation.y = -0.25 + index * 0.25
		_storm_lines.append(line)
	_storm_light = OmniLight3D.new()
	_storm_light.name = "StormPressureLight"
	_storm_light.position = center + Vector3(0, 18, 0) * scale_factor
	_storm_light.omni_range = 52 * scale_factor
	_storm_light.shadow_enabled = false
	add_child(_storm_light)


func _build_sanctuary(center: Vector3) -> void:
	var root := Node3D.new()
	root.name = "CrownrootSanctuary"
	root.position = center
	add_child(root)
	var scale_factor := 1.0 if _compact else 2.4
	# Four low-poly memory instruments make the earned ideas readable as one
	# coherent machine court around the Crown Wisdom Engine.
	for index in 4:
		var angle := -PI * 0.75 + index * PI * 0.5
		var at := Vector3(cos(angle) * 17, 0.5, sin(angle) * 17) * scale_factor
		var light_id: String = LIGHT_IDS[index]
		var station := _station(root, "light_" + light_id, "MemoryLight" + light_id.to_pascal_case(), at)
		station.set_meta("low_poly_production_object", true)
		station.set_meta("visual_verb", "recall earned light")
		_cylinder(station, "MemoryIvoryFoot", Vector3.ZERO, 4.2 * scale_factor,
			0.7 * scale_factor, Color("e8dfc7"), 10, true)
		_cylinder(station, "MemoryBrassStep", Vector3.UP * 0.46 * scale_factor,
			3.45 * scale_factor, 0.24 * scale_factor, Color("cba653"), 10)
		for petal_index in 6:
			var petal_angle := TAU * float(petal_index) / 6.0
			var petal := _box(station, "MemoryPetal%02d" % (petal_index + 1),
				Vector3(cos(petal_angle) * 2.35, 0.72, sin(petal_angle) * 2.35) * scale_factor,
				Vector3(2.4, 0.22, 1.05) * scale_factor, Color("f0eadb"), false)
			petal.rotation.y = -petal_angle
		_cylinder(station, "MemoryCoreSocket", Vector3.UP * 1.25 * scale_factor,
			1.2 * scale_factor, 1.9 * scale_factor, Color("304e58"), 8)
		var crystal := _cylinder(station, "EarnedLight", Vector3.UP * 2.65 * scale_factor,
			0.72 * scale_factor, 1.6 * scale_factor, Color("56748a"), 6)
		crystal.set_meta("base_scale", crystal.scale)
		_light_nodes[light_id] = crystal
		_torus(station, "MemoryFocusRing", Vector3.UP * 2.65 * scale_factor,
			0.88 * scale_factor, 1.12 * scale_factor, Color("d0aa58"))
		_label(station, light_id.to_upper(), Vector3(0, 4.3, 0) * scale_factor, Color("f6f1df"), 26)
		# Each recalled idea visibly feeds the shared engine instead of reading as
		# an isolated pedestal dropped onto the floor.
		_beam(root, "MemoryRootConduit%02d" % (index + 1),
			at + Vector3.UP * 0.35 * scale_factor,
			Vector3(cos(angle) * 6.0, 0.85, sin(angle) * 6.0) * scale_factor,
			0.24 * scale_factor, Color("cba653"))
	var constellation := _station(root, "constellation", "PersonalConstellationDais", Vector3(0, 0.7, -24) * scale_factor)
	constellation.set_meta("low_poly_production_object", true)
	constellation.set_meta("visual_verb", "connect earned lights")
	_cylinder(constellation, "ConstellationFloor", Vector3.ZERO, 7.5 * scale_factor, 1.0 * scale_factor, Color("e8dfc7"), 12, true)
	_cylinder(constellation, "ConstellationTealTable", Vector3.UP * 0.62 * scale_factor,
		6.4 * scale_factor, 0.24 * scale_factor, Color("315e63"), 12)
	_torus(constellation, "ConstellationBrassRim", Vector3.UP * 0.78 * scale_factor,
		5.8 * scale_factor, 6.45 * scale_factor, Color("d0aa58"))
	for index in 4:
		var angle := -PI * 0.75 + index * PI * 0.5
		_beam(constellation, "ConstellationArm%02d" % index, Vector3(0, 0.86, 0) * scale_factor,
			Vector3(cos(angle) * 3.3, 0.86, sin(angle) * 3.3) * scale_factor,
			0.16 * scale_factor, Color("cba653"))
		_cylinder(constellation, "ConstellationNode%02d" % index,
			Vector3(cos(angle) * 3.3, 1.12, sin(angle) * 3.3) * scale_factor,
			0.62 * scale_factor, 0.55 * scale_factor, Color("f2cf68"), 8)
	for index in 3:
		var a_angle := -PI * 0.75 + index * PI * 0.5
		var b_angle := -PI * 0.75 + (index + 1) * PI * 0.5
		var link := _beam(constellation, "AuthoredConnection%02d" % index, Vector3(cos(a_angle) * 3.3, 1.0, sin(a_angle) * 3.3) * scale_factor, Vector3(cos(b_angle) * 3.3, 1.0, sin(b_angle) * 3.3) * scale_factor, 0.12 * scale_factor, Color("f2cf68"))
		link.visible = false
		_link_nodes.append(link)
	var star_station := _station(root, "star", "StarChoicePedestal", Vector3(0, 0.8, -35) * scale_factor)
	star_station.set_meta("low_poly_production_object", true)
	star_station.set_meta("visual_verb", "choose how to carry wisdom")
	_cylinder(star_station, "StarPedestalFoot", Vector3.ZERO, 4.6 * scale_factor,
		0.8 * scale_factor, Color("e8dfc7"), 10, true)
	_cylinder(star_station, "StarPedestalGoldStep", Vector3.UP * 0.52 * scale_factor,
		3.7 * scale_factor, 0.24 * scale_factor, Color("cba653"), 10)
	_cylinder(star_station, "StarPedestalColumn", Vector3.UP * 2.0 * scale_factor,
		1.3 * scale_factor, 3.0 * scale_factor, Color("304e58"), 8)
	_torus(star_station, "StarPedestalCrown", Vector3.UP * 3.45 * scale_factor,
		1.35 * scale_factor, 1.75 * scale_factor, Color("d0aa58"))
	_star = Node3D.new()
	_star.name = "EarnedStarOfWisdom"
	_star.position = Vector3(0, 4.2, 0) * scale_factor
	star_station.add_child(_star)
	for index in 8:
		var ray := _box(_star, "StarRay%02d" % index, Vector3.ZERO, Vector3(3.0, 0.35, 0.5) * scale_factor, Color("f0c75e"), false)
		ray.rotation.y = TAU * float(index) / 8.0
	_sphere(_star, "StarCore", Vector3.ZERO, Vector3.ONE * scale_factor, Color("fff0a0"))
	_star.visible = false
	_label(star_station, "1 RECEIVE  •  2 CARRY  •  3 CROWN", Vector3(0, 7, 0) * scale_factor, Color("fff0b2"), 25)
	_tree_crown = Node3D.new()
	_tree_crown.name = "AwakenedWisdomEngineCrown"
	# This is an activation layer on the permanent Crown Wisdom Engine, not a
	# second floating ring. Its radial fins occupy the engine's vertical crown.
	_tree_crown.position = Vector3(0, 27, 18) * scale_factor
	root.add_child(_tree_crown)
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var fin := _box(_tree_crown, "CrownEnergyFin%02d" % index,
			Vector3(cos(angle) * 7.0, sin(angle) * 7.0, 0.35) * scale_factor,
			Vector3(7.0, 0.55, 0.5) * scale_factor, Color("f0c75e"), false)
		fin.rotation.z = angle
		_sphere(_tree_crown, "CrownMemoryNode%02d" % index,
			Vector3(cos(angle) * 11.2, sin(angle) * 11.2, 0.4) * scale_factor,
			Vector3.ONE * 0.7 * scale_factor, Color("7ce2d4"))
	_rain = _build_rain(root, scale_factor)
	_sanctuary_light = OmniLight3D.new()
	_sanctuary_light.name = "SanctuaryAwakeningLight"
	_sanctuary_light.position = center + Vector3(0, 20, 0) * scale_factor
	_sanctuary_light.light_color = Color("ffd98b")
	_sanctuary_light.omni_range = 48 * scale_factor
	_sanctuary_light.shadow_enabled = false
	add_child(_sanctuary_light)


func _update_station_labels() -> void:
	_set_station_active("storm_reader", _task_index == 8 and not bool(_state.get("storm_preview_read", false)))
	var finale := bool(_state.get("rain_started", false)) and _task_index >= 9
	for light_id in LIGHT_IDS:
		_set_station_active("light_" + light_id, finale)
	var recalled: Array = _state.get("recalled_lights", [])
	_set_station_active("constellation", finale and recalled.size() == 4)
	var links: Array = _state.get("constellation_links", [])
	_set_station_active("star", finale and links.size() >= 3)


func _set_station_active(station_id: String, active: bool) -> void:
	var station := _stations[station_id] as Node3D
	station.visible = active
	for collision in station.find_children("*", "CollisionShape3D", true, false):
		(collision as CollisionShape3D).set_deferred("disabled", not active)


func _set_light_pose(light_id: String, active: bool) -> void:
	var crystal := _light_nodes[light_id] as MeshInstance3D
	crystal.material_override = _material(Color("7ce2c4") if active else Color("56748a"), active)
	var base_scale: Vector3 = crystal.get_meta("base_scale", Vector3.ONE)
	crystal.scale = base_scale * (1.25 if active else 1.0)


func _apply_reader_pose(animated: bool) -> void:
	if _reader_pointers.size() != 3 or _reader_glass == null or _reader_feedback_strip == null:
		return
	var values := [
		int(_state.get("reader_direction", 2)),
		int(_state.get("reader_phase", 0)),
		int(_state.get("reader_aperture", 0)),
	]
	var ranges := [STORM_DIRECTIONS.size(), STORM_PHASES.size(), STORM_APERTURES.size()]
	for index in 3:
		var target_angle := -PI * 0.65 + TAU * float(values[index]) / float(ranges[index])
		if animated:
			create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(
				_reader_pointers[index], "rotation:y", target_angle, 0.24)
		else:
			_reader_pointers[index].rotation.y = target_angle
	var correct: bool = values[0] == int(CORRECT_READER_STATE.direction) \
		and values[1] == int(CORRECT_READER_STATE.phase) \
		and values[2] == int(CORRECT_READER_STATE.aperture)
	var aperture_scale := 0.62 if values[2] == 1 else 1.0
	if animated:
		create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(
			_reader_glass, "scale", Vector3(aperture_scale, 1.0, aperture_scale), 0.2)
	else:
		_reader_glass.scale = Vector3(aperture_scale, 1.0, aperture_scale)
	_reader_glass.material_override = _glass_material(
		Color("8ce8d8", 0.68) if correct else Color("65aeba", 0.48), correct)
	_reader_feedback_strip.material_override = _material(Color("3e8b78") if correct else Color("315e63"), correct)


func _station(parent: Node3D, id: String, node_name: String, at: Vector3) -> Node3D:
	var station := Node3D.new()
	station.name = node_name
	station.position = at
	station.set_meta("station_id", id)
	parent.add_child(station)
	_stations[id] = station
	return station


func _box(parent: Node3D, node_name: String, at: Vector3, size: Vector3, color: Color, collide: bool) -> MeshInstance3D:
	var mesh := BoxMesh.new(); mesh.size = size
	var instance := MeshInstance3D.new(); instance.name = node_name; instance.mesh = mesh; instance.position = at; instance.material_override = _material(color)
	parent.add_child(instance)
	if collide: _box_collision(parent, node_name + "Collision", at, size)
	return instance


func _cylinder(parent: Node3D, node_name: String, at: Vector3, radius: float, height: float, color: Color, sides: int, collide := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new(); mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height; mesh.radial_segments = sides
	var instance := MeshInstance3D.new(); instance.name = node_name; instance.mesh = mesh; instance.position = at; instance.material_override = _material(color)
	parent.add_child(instance)
	if collide:
		var body := StaticBody3D.new(); body.name = node_name + "Collision"; body.position = at; parent.add_child(body)
		var shape := CollisionShape3D.new(); var cylinder := CylinderShape3D.new(); cylinder.radius = radius; cylinder.height = height; shape.shape = cylinder; body.add_child(shape)
	return instance


func _sphere(parent: Node3D, node_name: String, at: Vector3, scale_value: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new(); mesh.radius = 0.5; mesh.height = 1.0; mesh.radial_segments = 8; mesh.rings = 4
	var instance := MeshInstance3D.new(); instance.name = node_name; instance.mesh = mesh; instance.position = at; instance.scale = scale_value; instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


func _torus(parent: Node3D, node_name: String, at: Vector3, inner: float, outer: float, color: Color, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new(); mesh.inner_radius = inner; mesh.outer_radius = outer; mesh.rings = 18; mesh.ring_segments = 6
	var instance := MeshInstance3D.new(); instance.name = node_name; instance.mesh = mesh; instance.position = at; instance.rotation_degrees = rotation; instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


func _beam(parent: Node3D, node_name: String, start: Vector3, finish: Vector3, width: float, color: Color) -> MeshInstance3D:
	var beam := _box(parent, node_name, start.lerp(finish, 0.5), Vector3(width, width, start.distance_to(finish)), color, false)
	var direction := start.direction_to(finish)
	var safe_up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
	beam.look_at_from_position(start.lerp(finish, 0.5), finish, safe_up)
	return beam


func _box_collision(parent: Node3D, node_name: String, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new(); body.name = node_name; body.position = at; parent.add_child(body)
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; collision.shape = shape; body.add_child(collision)


func _label(parent: Node3D, text: String, at: Vector3, color: Color, size: int) -> Label3D:
	var label := Label3D.new(); label.name = text.get_slice("•", 0).strip_edges().to_pascal_case() + "Label"; label.text = text; label.position = at; label.modulate = color; label.font_size = size; label.outline_size = 8; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label


func _material(color: Color, glow := false) -> StandardMaterial3D:
	var key := "%s:%s" % [color.to_html(true), glow]
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = 0.72
	if glow: material.emission_enabled = true; material.emission = color; material.emission_energy_multiplier = 1.1
	_material_cache[key] = material
	return material


func _glass_material(color: Color, glow: bool) -> StandardMaterial3D:
	var key := "glass:%s:%s" % [color.to_html(true), glow]
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.24
	material.metallic = 0.12
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = 0.8
	_material_cache[key] = material
	return material


func _build_rain(parent: Node3D, scale_factor: float) -> GPUParticles3D:
	var rain := GPUParticles3D.new(); rain.name = "IslandThreeGentleRain"; rain.amount = 110; rain.lifetime = 2.4; rain.position = Vector3(0, 24, 0) * scale_factor; rain.visibility_aabb = AABB(Vector3(-30, -30, -30) * scale_factor, Vector3(60, 60, 60) * scale_factor)
	var process := ParticleProcessMaterial.new(); process.direction = Vector3.DOWN; process.initial_velocity_min = 8 * scale_factor; process.initial_velocity_max = 12 * scale_factor; process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX; process.emission_box_extents = Vector3(28, 2, 28) * scale_factor; rain.process_material = process
	var drop := QuadMesh.new(); drop.size = Vector2(0.04, 0.45) * scale_factor; var drop_material := StandardMaterial3D.new(); drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; drop_material.albedo_color = Color(0.55, 0.82, 0.95, 0.72); drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; drop.material = drop_material; rain.draw_pass_1 = drop; rain.emitting = false
	parent.add_child(rain)
	return rain
