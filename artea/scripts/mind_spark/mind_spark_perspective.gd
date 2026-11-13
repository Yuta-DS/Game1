class_name MindSparkPerspective
extends Node3D

## One original Mind Spark perspective. The root coordinator can configure two
## instances without either half knowing about the other scene tree.

signal role_interaction_requested(role_id: String)
signal role_ping_requested(role_id: String)

enum PerspectiveKind { ALARM_SCIENCE, HOPE_NATURE_MAGIC }
enum CameraMode { FIXED, FOLLOW }

const ALARM_BLUE := Color("#5de2ff")
const ALARM_DARK := Color("#07162d")
const HOPE_GOLD := Color("#ffe56d")
const HOPE_GREEN := Color("#183d34")
const RoleController := preload("res://scripts/mind_spark/mind_spark_role_controller.gd")
const QuestObjectScene := preload("res://scenes/mind_spark/quest_objects/quest_object_base.tscn")
const QuestObjectCatalog := preload("res://scripts/mind_spark/quest_objects/quest_object_catalog.gd")

@export var perspective_kind := PerspectiveKind.ALARM_SCIENCE
@export var role_id := "alarm"
@export var input_policy := "mind_alarm_keyboard"
@export var camera_mode := CameraMode.FOLLOW
@export var reduced_motion := false

@onready var role = $Role
@onready var camera: Camera3D = $Camera3D

var _configured_actions: Dictionary = {}
var _dressing: Node3D
var _camera_home := Vector3.ZERO
var _camera_mode_before_focus := CameraMode.FOLLOW
var _focus_mode := false
var _constellation_nodes: Array[MeshInstance3D] = []
var _interaction_station: Node3D
var _interaction_station_id := ""
var _support_objects: Array[QuestObjectBase] = []
var _quest_index := 0


func configure_perspective(
		kind: PerspectiveKind,
		new_role_id: String,
		new_input_policy: String,
		actions: Dictionary = {}
) -> void:
	perspective_kind = kind
	role_id = new_role_id
	input_policy = new_input_policy
	_configured_actions = actions.duplicate()
	if is_node_ready():
		for index in _support_objects.size():
			var support_id := "focus_bell" if index == 0 else "path_projector"
			_support_objects[index].configure(_support_objects[index].definition,
				"chapter.%s.support.%s" % [role_id, support_id])
		_apply_configuration()


func set_camera_mode(mode: CameraMode) -> void:
	camera_mode = mode
	if is_node_ready() and (mode == CameraMode.FIXED or reduced_motion):
		camera.position = _camera_home
		camera.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if not is_node_ready():
		return
	if enabled:
		camera.position = _camera_home
		camera.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)
	_update_focus_status()


## Makes the shared anchor's readiness legible by text and silhouette, not
## colour alone. Materials are per-instance, so one half cannot alter the
## other half's state.
func set_shared_anchor_active(active: bool) -> void:
	var anchor := $SharedAnchor as MeshInstance3D
	var label := $AnchorStatus as Label3D
	anchor.scale = Vector3(1.18, 1.45, 1.18) if active else Vector3(0.72, 0.55, 0.72)
	label.text = "ANCHOR READY" if active else "ANCHOR WAITING"
	$PerspectiveHUD/StatusRow/Anchor.text = "◆ ANCHOR READY" if active else "◇ ANCHOR WAITING"
	var material := anchor.material_override as StandardMaterial3D
	if material != null:
		material.emission_energy_multiplier = 1.65 if active else 0.18


## Accepts a bool for the final state or a 0..1 number for authored, untimed
## progress. The bridge grows in width and reports its status in text.
func set_bridge_integrated(value: Variant) -> void:
	var progress := (1.0 if value else 0.0) if value is bool else clampf(float(value), 0.0, 1.0)
	var bridge := $BridgeIndicator as MeshInstance3D
	var label := $BridgeStatus as Label3D
	bridge.scale.x = lerpf(0.12, 1.0, progress)
	bridge.visible = progress > 0.0
	label.visible = false
	if progress >= 1.0:
		label.text = "BRIDGE LINKED"
	elif progress <= 0.0:
		label.text = "BRIDGE WAITING"
	else:
		label.text = "BRIDGE FORMING • %d%%" % roundi(progress * 100.0)
	$PerspectiveHUD/StatusRow/Bridge.text = ("▰ BRIDGE LINKED" if progress >= 1.0 else \
		("▱ BRIDGE WAITING" if progress <= 0.0 else "▰ BRIDGE • %d%%" % roundi(progress * 100.0)))
	var material := bridge.material_override as StandardMaterial3D
	if material != null:
		material.emission_energy_multiplier = lerpf(0.25, 1.4, progress)


## Shows a compact constellation as filled/outlined shapes and an exact text
## count. Node creation is bounded to eight lights for mobile safety.
func set_constellation_progress(completed: int, total: int) -> void:
	total = clampi(total, 1, 8)
	completed = clampi(completed, 0, total)
	var label := $PerspectiveHUD/ConstellationStatus as Label
	label.text = "CONSTELLATION • %d / %d LIGHTS" % [completed, total]
	_ensure_constellation_nodes(total)
	for index in _constellation_nodes.size():
		var light := _constellation_nodes[index]
		light.visible = index < total
		light.scale = Vector3.ONE * (1.32 if index < completed else 0.66)
		var material := light.material_override as StandardMaterial3D
		if material != null:
			material.emission_energy_multiplier = 1.45 if index < completed else 0.08


## Focus mode freezes camera follow and declares that state visibly. It does
## not disable interaction or complete an objective.
func set_focus_mode(enabled: bool) -> void:
	if enabled == _focus_mode:
		return
	_focus_mode = enabled
	if enabled:
		_camera_mode_before_focus = camera_mode
		camera_mode = CameraMode.FIXED
		if is_node_ready():
			camera.position = _camera_home
			camera.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)
	else:
		camera_mode = CameraMode.FIXED if reduced_motion else _camera_mode_before_focus
	_update_focus_status()


func set_solo_companion(enabled: bool) -> void:
	role.set_companion_mode(enabled)


func command_companion(target: Vector3, activate_on_arrival: bool = false) -> void:
	role.command_solo(target, activate_on_arrival)


## Places one authored, role-specific objective inside this half of the world.
## The coordinator remains authoritative; this node only provides spatial
## affordance, proximity validation, and readable feedback.
func set_interaction_station(step_id: String, label_text: String, target: Vector3, active: bool) -> void:
	_interaction_station_id = step_id if active else ""
	if active and (not is_instance_valid(_interaction_station) \
			or str(_interaction_station.get_meta("step_id", "")) != step_id):
		if is_instance_valid(_interaction_station):
			remove_child(_interaction_station)
			_interaction_station.free()
		var object := QuestObjectScene.instantiate() as QuestObjectBase
		object.name = "InteractionStation"
		object.definition = QuestObjectCatalog.definition_for_step(step_id)
		object.save_id = "chapter.%s.%s" % [role_id, step_id]
		object.set_meta("step_id", step_id)
		add_child(object)
		_interaction_station = object
	if not is_instance_valid(_interaction_station):
		return
	_interaction_station.position = target
	_interaction_station.visible = active
	if active and _interaction_station is QuestObjectBase:
		(_interaction_station as QuestObjectBase).prompt.text = "%s\n%s" % [label_text,
			(_interaction_station as QuestObjectBase).prompt.text]


func interaction_station_position() -> Vector3:
	return _interaction_station.position if is_instance_valid(_interaction_station) else Vector3.ZERO


func role_is_near_station(max_distance := 1.65) -> bool:
	return is_instance_valid(_interaction_station) and _interaction_station.visible \
		and role.position.distance_to(_interaction_station.position) <= max_distance


func current_station_id() -> String:
	return _interaction_station_id


func interact_current_object(action: StringName = &"primary", value: Variant = null) -> Dictionary:
	if not _interaction_station is QuestObjectBase:
		return {"accepted": false, "reason": "no_quest_object", "completed": false}
	return (_interaction_station as QuestObjectBase).interact(action, value)


func current_object_actions() -> Array[StringName]:
	if _interaction_station is QuestObjectBase:
		return (_interaction_station as QuestObjectBase).available_actions()
	return []


func interact_support_if_near(max_distance := 1.5) -> Dictionary:
	for object in _support_objects:
		if is_instance_valid(object) and role.position.distance_to(object.position) <= max_distance:
			var result := object.interact(&"primary")
			result["handled"] = true
			result["object_name"] = object.definition.display_name
			return result
	return {"handled": false}


func set_quest_environment(index: int, quest_title: String) -> void:
	_quest_index = clampi(index, 0, 4)
	if is_node_ready():
		_build_dressing()
		$PerspectiveHUD/Header/Box/Purpose.text = "QUEST %d • %s" % [_quest_index + 1, quest_title]


func swap_role_policy(other) -> void:
	if other != null:
		role.swap_input_policy(other.role)
		input_policy = role.input_policy
		other.input_policy = other.role.input_policy


func _ready() -> void:
	_camera_home = camera.position
	_make_visual_resources_local()
	role.interaction_requested.connect(_on_role_interaction)
	role.ping_requested.connect(_on_role_ping)
	_apply_configuration()
	set_shared_anchor_active(false)
	set_bridge_integrated(false)
	set_constellation_progress(0, 3)
	_build_support_objects()
	_update_focus_status()


func _process(delta: float) -> void:
	if camera_mode != CameraMode.FOLLOW or reduced_motion or _focus_mode:
		return
	var desired := _camera_home + Vector3(role.position.x * 0.28, 0.0, role.position.z * 0.16)
	camera.position = camera.position.lerp(desired, minf(1.0, delta * 3.0))
	camera.look_at(role.position + Vector3(0.0, 0.8, 0.0), Vector3.UP)


func _apply_configuration() -> void:
	if role == null:
		return
	if _configured_actions.is_empty():
		_configured_actions = _default_actions(role_id)
	role.configure_role(role_id, input_policy, _configured_actions)
	_update_presentation()
	_build_dressing()


func _update_presentation() -> void:
	var alarm := perspective_kind == PerspectiveKind.ALARM_SCIENCE
	var title := $PerspectiveHUD/Header/Box/Title as Label
	var purpose := $PerspectiveHUD/Header/Box/Purpose as Label
	var side_marker := $PerspectiveHUD/SideMarker as ColorRect
	title.text = "ALARM LENS • SCIENCE" if alarm else "HOPE LENS • NATURE MAGIC"
	purpose.text = "Notice the signal. Map what it does." if alarm else "Grow a truthful, helpful next step."
	title.add_theme_color_override("font_color", ALARM_BLUE if alarm else HOPE_GOLD)
	purpose.add_theme_color_override("font_color", Color("#e8f6ff") if alarm else Color("#fffbe2"))
	side_marker.color = ALARM_BLUE if alarm else HOPE_GOLD
	var environment: Environment = $WorldEnvironment.environment
	if environment != null:
		environment.background_color = ALARM_DARK if alarm else HOPE_GREEN
	var light := $DirectionalLight3D as DirectionalLight3D
	light.light_color = Color("#b7efff") if alarm else Color("#fff1b5")


func _build_dressing() -> void:
	if is_instance_valid(_dressing):
		_dressing.queue_free()
	_dressing = Node3D.new()
	_dressing.name = "ProceduralDressing"
	add_child(_dressing)
	move_child(_dressing, 1)
	if perspective_kind == PerspectiveKind.ALARM_SCIENCE:
		_build_science_dressing()
	else:
		_build_magic_dressing()
	_build_quest_landmark()


func _build_quest_landmark() -> void:
	var color := ALARM_BLUE if perspective_kind == PerspectiveKind.ALARM_SCIENCE else HOPE_GOLD
	var material := _material(color, 0.45 + _quest_index * 0.2)
	match _quest_index:
		0:
			for index in 3:
				var dish := _mesh(TorusMesh.new(), material)
				(dish.mesh as TorusMesh).inner_radius = 0.28 + index * 0.12
				(dish.mesh as TorusMesh).outer_radius = 0.34 + index * 0.12
				dish.position = Vector3(-1.0 + index, 1.6 + index * 0.18, -2.7)
				dish.rotation.x = PI * 0.5
				_dressing.add_child(dish)
		1:
			for index in 4:
				var echo := _mesh(SphereMesh.new(), material)
				(echo.mesh as SphereMesh).radius = 0.18 + index * 0.05
				(echo.mesh as SphereMesh).height = (echo.mesh as SphereMesh).radius * 2.0
				echo.position = Vector3(-2.4 + index * 1.55, 1.25 + float(index % 2) * 0.5, -2.55)
				_dressing.add_child(echo)
		2:
			for index in 3:
				var relay := _mesh(BoxMesh.new(), material)
				(relay.mesh as BoxMesh).size = Vector3(0.32, 1.6, 0.32)
				relay.position = Vector3(-2.2 + index * 2.2, 0.8, -2.4)
				_dressing.add_child(relay)
		3:
			for index in 5:
				var storm_arc := _mesh(TorusMesh.new(), material)
				(storm_arc.mesh as TorusMesh).inner_radius = 0.34
				(storm_arc.mesh as TorusMesh).outer_radius = 0.4
				storm_arc.position = Vector3(-3.0 + index * 1.5, 1.1 + float(index % 2) * 0.55, -2.45)
				storm_arc.rotation = Vector3(PI * 0.5, 0.0, index * 0.4)
				_dressing.add_child(storm_arc)
		4:
			_ensure_constellation_nodes(5)


func _build_science_dressing() -> void:
	var cyan := _material(ALARM_BLUE, 1.4)
	var brass := _material(Color("#c89d4b"), 0.0, 0.82)
	for index in 5:
		var pylon := _mesh(BoxMesh.new(), cyan)
		(pylon.mesh as BoxMesh).size = Vector3(0.16, 1.2 + index * 0.18, 0.16)
		pylon.position = Vector3(-3.0 + index * 1.5, 0.6, -1.7)
		_dressing.add_child(pylon)
	for index in 3:
		var ring := _mesh(TorusMesh.new(), brass)
		(ring.mesh as TorusMesh).inner_radius = 0.42 + index * 0.18
		(ring.mesh as TorusMesh).outer_radius = 0.48 + index * 0.18
		ring.position = Vector3(-2.8 + index * 2.8, 0.72, 0.0)
		ring.rotation.x = PI * 0.5
		_dressing.add_child(ring)


func _build_magic_dressing() -> void:
	var leaf := _material(Color("#66d79b"), 0.15)
	var glow := _material(HOPE_GOLD, 1.25)
	for index in 7:
		var stem := _mesh(CylinderMesh.new(), leaf)
		(stem.mesh as CylinderMesh).top_radius = 0.05
		(stem.mesh as CylinderMesh).bottom_radius = 0.09
		(stem.mesh as CylinderMesh).height = 0.8 + float(index % 3) * 0.3
		stem.position = Vector3(-3.3 + index * 1.1, 0.4, -1.65 + float(index % 2) * 0.25)
		_dressing.add_child(stem)
		var light_seed := _mesh(SphereMesh.new(), glow)
		(light_seed.mesh as SphereMesh).radius = 0.13
		(light_seed.mesh as SphereMesh).height = 0.26
		light_seed.position = stem.position + Vector3(0.0, 0.55 + float(index % 3) * 0.15, 0.0)
		_dressing.add_child(light_seed)
	for index in 3:
		var rune := _mesh(TorusMesh.new(), glow)
		(rune.mesh as TorusMesh).inner_radius = 0.36 + index * 0.16
		(rune.mesh as TorusMesh).outer_radius = 0.4 + index * 0.16
		rune.position = Vector3(-2.8 + index * 2.8, 0.04, 0.0)
		_dressing.add_child(rune)


func _make_visual_resources_local() -> void:
	var world_environment := $WorldEnvironment as WorldEnvironment
	if world_environment.environment != null:
		world_environment.environment = world_environment.environment.duplicate(true)
		world_environment.environment.resource_local_to_scene = true
	for path in [NodePath("SharedAnchor"), NodePath("BridgeIndicator")]:
		var mesh_instance := get_node(path) as MeshInstance3D
		if mesh_instance.material_override != null:
			mesh_instance.material_override = mesh_instance.material_override.duplicate(true)


func _ensure_constellation_nodes(total: int) -> void:
	while _constellation_nodes.size() < total:
		var index := _constellation_nodes.size()
		var light := _mesh(SphereMesh.new(), _material(
			ALARM_BLUE if perspective_kind == PerspectiveKind.ALARM_SCIENCE else HOPE_GOLD, 0.08))
		(light.mesh as SphereMesh).radius = 0.11
		(light.mesh as SphereMesh).height = 0.22
		light.position = Vector3(-1.2 + index * 0.4, 2.45 + sin(index * 1.4) * 0.22, -1.45)
		$ConstellationLights.add_child(light)
		_constellation_nodes.append(light)


func _update_focus_status() -> void:
	if not is_node_ready():
		return
	var label := $PerspectiveHUD/FocusStatus as Label
	label.visible = _focus_mode or reduced_motion
	if _focus_mode:
		label.text = "FOCUS MODE • CAMERA STEADY"
	elif reduced_motion:
		label.text = "REDUCED MOTION • CAMERA STEADY"


func _build_support_objects() -> void:
	if not _support_objects.is_empty():
		return
	for support in [
		{"index": 6, "position": Vector3(-3.7, 0.0, -2.7), "id": "focus_bell"},
		{"index": 11, "position": Vector3(3.7, 0.0, -2.7), "id": "path_projector"},
	]:
		var object := QuestObjectScene.instantiate() as QuestObjectBase
		object.definition = QuestObjectCatalog.definition_at(int(support["index"]))
		object.save_id = "chapter.%s.support.%s" % [role_id, support["id"]]
		object.position = support["position"]
		object.scale = Vector3.ONE * 0.72
		add_child(object)
		_support_objects.append(object)


func _mesh(mesh: PrimitiveMesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _material(color: Color, emission_energy: float = 0.0, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.45
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	return material


func _default_actions(id: String) -> Dictionary:
	var prefix := "mind_alarm" if id == "alarm" else "mind_hope"
	return {
		"left": StringName(prefix + "_move_left"),
		"right": StringName(prefix + "_move_right"),
		"forward": StringName(prefix + "_move_forward"),
		"back": StringName(prefix + "_move_back"),
		"interact": StringName(prefix + "_interact"),
		"ping": StringName(prefix + "_ping"),
	}


func _on_role_interaction(requesting_role_id: String) -> void:
	role_interaction_requested.emit(requesting_role_id)


func _on_role_ping(requesting_role_id: String) -> void:
	role_ping_requested.emit(requesting_role_id)
