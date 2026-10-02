class_name MindSparkWardenBoss
extends StaticBody3D

signal phase_changed(phase: int)
signal anchor_window_opened(index: int)
signal combat_stopped
signal defeated(xp_reward: int)

enum Phase { INTRO, PHASE_1, TRANSITION, PHASE_2, PHASE_3, COMPLETE }

const DEFAULT_DEFINITION := preload("res://resources/mind_spark/enemies/thought_storm_warden.tres")

@export var definition: Resource = DEFAULT_DEFINITION

@onready var shell: Node3D = $VisualRoot/BlightShell
@onready var core: MeshInstance3D = $VisualRoot/CrystalCore
@onready var core_label: Label3D = $CoreLabel
@onready var storm_line: MeshInstance3D = $StormLineTelegraph
@onready var rain: GPUParticles3D = $GentleRain

var phase := Phase.INTRO
var current_health := 300.0
var active := false
var anchors: Array[QuestObjectBase] = []
var broken_anchor_count := 0
var _cycle_time := 1.15
var _damage_applied := false
var _player: CharacterBody3D
var _storm_crown: Node3D
var _visual_time := 0.0


func _ready() -> void:
	if definition == null or not definition.is_valid():
		push_error("MindSparkWardenBoss requires a valid balance definition")
		set_physics_process(false)
		return
	current_health = definition.max_health
	_build_storm_crown()
	core.visible = false
	storm_line.visible = false
	rain.emitting = false
	_find_player.call_deferred()


func _process(delta: float) -> void:
	_visual_time += delta
	if not is_visible_in_tree():
		return
	if _storm_crown != null:
		_storm_crown.rotation.y = _visual_time * (0.22 if active else 0.08)
		_storm_crown.position.y = sin(_visual_time * 1.15) * 0.35
	if core.visible:
		core.scale = Vector3.ONE * (1.0 + sin(_visual_time * 3.2) * 0.06)


func bind_anchors(new_anchors: Array[QuestObjectBase]) -> void:
	anchors = new_anchors.duplicate()
	broken_anchor_count = 0
	for index in anchors.size():
		var anchor := anchors[index]
		if not anchor.completed.is_connected(_on_anchor_completed):
			anchor.completed.connect(_on_anchor_completed.bind(index))
		if bool(anchor.current_state.get("completed", false)):
			broken_anchor_count += 1
	if broken_anchor_count >= 3:
		_open_core()


func start_battle() -> void:
	if phase == Phase.COMPLETE:
		return
	active = true
	_set_phase(Phase.PHASE_1)
	_cycle_time = _assisted_telegraph_seconds()
	storm_line.visible = true
	core_label.text = "DODGE THE WIDE STORM LINE"


func reset_battle() -> void:
	current_health = definition.max_health
	active = false
	broken_anchor_count = 0
	shell.visible = true
	core.visible = false
	storm_line.visible = false
	rain.emitting = false
	_set_phase(Phase.INTRO)
	for anchor in anchors:
		anchor.reset_warden_anchor(false)


func restart_current_phase() -> int:
	## Adaptive assistance restarts the current phase rather than erasing the
	## whole encounter. Broken anchors remain authoritative; unfinished anchors
	## return to their readable telegraph state and the open core restarts with
	## full health when phase three was reached.
	if phase == Phase.COMPLETE:
		return phase
	broken_anchor_count = 0
	for anchor in anchors:
		anchor.reset_warden_anchor(true)
		if bool(anchor.current_state.get("completed", false)):
			broken_anchor_count += 1
	active = true
	_damage_applied = false
	_cycle_time = _assisted_telegraph_seconds()
	shell.visible = true
	rain.emitting = false
	if broken_anchor_count >= 3:
		current_health = definition.max_health
		core.visible = true
		storm_line.visible = false
		_set_phase(Phase.PHASE_3)
		core_label.text = "PHASE RESTART • OPEN CORE • %d / %d" \
			% [ceili(current_health), ceili(definition.max_health)]
	elif broken_anchor_count > 0:
		core.visible = false
		storm_line.visible = true
		_set_phase(Phase.PHASE_2)
		core_label.text = "PHASE RESTART • SHIELD LAYERS %d/3" % broken_anchor_count
	else:
		current_health = definition.max_health
		core.visible = false
		storm_line.visible = true
		_set_phase(Phase.PHASE_1)
		core_label.text = "PHASE RESTART • DODGE THE WIDE STORM LINE"
	return phase


func take_damage(amount: float, _source: Node = null) -> float:
	if not active or phase != Phase.PHASE_3 or amount <= 0.0:
		core_label.text = "BREAK ALL THREE OPEN ANCHORS FIRST • %d/3" % broken_anchor_count
		return 0.0
	var applied := minf(current_health, amount)
	current_health -= applied
	core_label.text = "OPEN CORE • %d / %d" % [ceili(current_health), ceili(definition.max_health)]
	if current_health <= 0.0:
		_free_warden()
	return applied


func restore_combat_stopped() -> void:
	current_health = 0.0
	active = false
	broken_anchor_count = 3
	shell.visible = false
	core.visible = true
	storm_line.visible = false
	_set_phase(Phase.COMPLETE)
	core_label.text = "COMBAT STOPPED • PLACE THE FINAL SPARK"


func set_gentle_rain() -> void:
	restore_combat_stopped()
	rain.emitting = true
	core_label.text = "THE STORM IS NOW GENTLE RAIN"


func _physics_process(delta: float) -> void:
	if not active or phase in [Phase.INTRO, Phase.COMPLETE, Phase.PHASE_3]:
		return
	_cycle_time -= delta
	if _cycle_time > 0.0:
		storm_line.visible = true
		return
	storm_line.visible = false
	if not _damage_applied and _player != null \
			and _player.global_position.distance_to(global_position) < definition.storm_radius:
		_player.call("take_damage", definition.storm_damage, self)
		_damage_applied = true
	var next_anchor := _next_unbroken_anchor()
	if next_anchor >= 0:
		var result := anchors[next_anchor].interact(&"dodge")
		if bool(result.get("accepted", false)):
			anchor_window_opened.emit(next_anchor)
			core_label.text = "ANCHOR %d OPEN • STRIKE THE CRYSTAL RING" % (next_anchor + 1)
	_cycle_time = definition.recovery_seconds + _assisted_telegraph_seconds()
	_damage_applied = false


func _on_anchor_completed(_save_id: String, _result: Dictionary, _index: int) -> void:
	broken_anchor_count = 0
	for anchor in anchors:
		if bool(anchor.current_state.get("completed", false)):
			broken_anchor_count += 1
	core_label.text = "SHIELD LAYERS • %d/3" % broken_anchor_count
	if broken_anchor_count == 1:
		_set_phase(Phase.TRANSITION)
		_set_phase(Phase.PHASE_2)
	elif broken_anchor_count >= 3:
		_open_core()


func _open_core() -> void:
	broken_anchor_count = 3
	storm_line.visible = false
	core.visible = true
	_set_phase(Phase.PHASE_3)
	core_label.text = "OPEN CRYSTAL CORE • %d / %d" \
		% [ceili(definition.max_health), ceili(definition.max_health)]


func _free_warden() -> void:
	active = false
	storm_line.visible = false
	shell.visible = false
	core.visible = true
	core_label.text = "COMBAT STOPPED • PLACE THE FINAL SPARK"
	_set_phase(Phase.COMPLETE)
	combat_stopped.emit()
	defeated.emit(definition.xp_reward)


func _next_unbroken_anchor() -> int:
	for index in anchors.size():
		if not bool(anchors[index].current_state.get("completed", false)):
			return index
	return -1


func _set_phase(next_phase: int) -> void:
	phase = next_phase
	phase_changed.emit(phase)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("Player")
	if not players.is_empty():
		_player = players[0] as CharacterBody3D


func _assisted_telegraph_seconds() -> float:
	var multiplier := 1.0
	var progression := get_node_or_null("/root/WorldOneProgression")
	if progression != null:
		var settings: Dictionary = progression.get("assist_settings")
		multiplier = float(settings.get("telegraph_multiplier", 1.0))
	return float(definition.telegraph_seconds) * multiplier


func _build_storm_crown() -> void:
	if shell.has_node("StormCrown"):
		_storm_crown = shell.get_node("StormCrown") as Node3D
		return
	_storm_crown = Node3D.new()
	_storm_crown.name = "StormCrown"
	_storm_crown.set_meta("visual_revision", "island_three_civic_storm_engine_v3_faceted_shell")
	_storm_crown.set_meta("giant_ring_count", 0)
	_storm_crown.set_meta("palette", "ivory_charcoal_cyan_lavender")
	_storm_crown.set_meta("faceted_shell", true)
	_storm_crown.set_meta("ivory_shell_panel_count", 8)
	shell.add_child(_storm_crown)
	var ivory := _material(Color("ded8ca"), Color("72d7df"), 0.16, 0.76)
	var charcoal := _material(Color("222832"), Color("284b59"), 0.22, 0.58)
	var storm := _material(Color("514661"), Color("8f78ae"), 0.58, 0.42)
	var crystal := _material(Color("69dce6"), Color("38cbd9"), 1.8, 0.24)

	# Four grounded pylons turn the boss into a piece of the Stormworks civic
	# architecture. Their broad feet meet the arena floor while the inward braces
	# frame the existing dark shell without obscuring the vulnerable cyan core.
	for index in 4:
		var angle := TAU * float(index) / 4.0 + PI * 0.25
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var pylon_root := radial * 8.8 + Vector3.DOWN * 3.2
		_add_cylinder_part(_storm_crown, "IvoryPylon%02d" % (index + 1),
			pylon_root, 0.85, 7.4, ivory, 8, 1.20)
		_add_box_part(_storm_crown, "PylonFoot%02d" % (index + 1),
			pylon_root + Vector3.DOWN * 3.55, Vector3(3.2, 0.7, 3.2), charcoal)
		_add_beam(_storm_crown, "InwardBrace%02d" % (index + 1),
			pylon_root + Vector3.UP * 2.2, radial * 4.8 + Vector3.UP * 4.0,
			0.62, charcoal)
		_add_beam(_storm_crown, "CyanConductor%02d" % (index + 1),
			pylon_root + Vector3.UP * 3.0, radial * 5.4 + Vector3.UP * 4.8,
			0.23, crystal)
		var cap := _add_prism_part(_storm_crown, "PylonCap%02d" % (index + 1),
			pylon_root + Vector3.UP * 4.5, Vector3(1.9, 2.8, 1.9), ivory)
		cap.rotation.y = -angle

	# Short, faceted shield vanes replace the former giant luminous rings. The
	# alternating height keeps the boss readable from every approach while the
	# open gaps preserve sightlines through the Grand Court.
	for index in 12:
		var angle := TAU * float(index) / 12.0
		var height := 3.6 + float(index % 3) * 0.65
		var shard := _add_prism_part(_storm_crown, "CrownFin%02d" % (index + 1),
			Vector3(cos(angle) * 6.15, 4.1 + height * 0.5, sin(angle) * 6.15),
			Vector3(0.82, height, 1.15), crystal if index % 3 == 0 else storm)
		shard.rotation = Vector3(0.0, -angle, -0.20)

	# Eight open armor plates break up the former near-black sphere while leaving
	# charcoal gaps for the storm state and a clear view of the vulnerable core.
	# Their ivory masonry ties the boss to the three surrounding civic buildings;
	# each plate remains part of the same four-pass animated crown batch.
	for index in 4:
		var angle := TAU * float(index) / 4.0
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var waist_panel := _add_prism_part(_storm_crown,
			"IvoryShellWaistPanel%02d" % (index + 1),
			radial * 6.48 + Vector3.UP * 0.25,
			Vector3(2.2, 5.4, 0.72), ivory)
		waist_panel.rotation.y = -angle + PI * 0.5
		var conductor := _add_box_part(_storm_crown,
			"CyanShellConductor%02d" % (index + 1),
			radial * 6.88 + Vector3.UP * 0.25,
			Vector3(0.48, 3.3, 0.16), crystal)
		conductor.rotation.y = -angle + PI * 0.5
		var shoulder_angle := angle + PI * 0.25
		var shoulder_radial := Vector3(cos(shoulder_angle), 0.0, sin(shoulder_angle))
		var shoulder_panel := _add_prism_part(_storm_crown,
			"IvoryShellShoulderPanel%02d" % (index + 1),
			shoulder_radial * 5.9 + Vector3.UP * 3.8,
			Vector3(2.5, 3.8, 0.72), ivory)
		shoulder_panel.rotation = Vector3(0.0, -shoulder_angle + PI * 0.5, -0.12)

	# A restrained bank of low-poly storm masses supports the story state without
	# becoming the dominant silhouette or washing the ivory court in purple.
	for index in 5:
		var cloud_angle := TAU * float(index) / 5.0
		var cloud := _add_sphere_part(_storm_crown, "StormMass%02d" % (index + 1),
			Vector3(cos(cloud_angle) * 4.4, -0.8 + float(index % 2) * 1.25,
				sin(cloud_angle) * 4.4), 2.15 + float(index % 2) * 0.35, charcoal)
		cloud.scale = Vector3(1.22, 0.62, 0.92)

	_add_cylinder_part(_storm_crown, "StormEngineWaist", Vector3(0.0, -2.7, 0.0),
		5.5, 1.15, charcoal, 12, 5.5)
	for index in 4:
		var angle := TAU * float(index) / 4.0
		_add_box_part(_storm_crown, "CoreWindow%02d" % (index + 1),
			Vector3(cos(angle) * 6.55, 0.35, sin(angle) * 6.55),
			Vector3(1.85, 3.4, 0.22), crystal).rotation.y = -angle + PI * 0.5

	var crown_light := OmniLight3D.new()
	crown_light.name = "StormCrownLight"
	crown_light.light_color = Color("79dbe5")
	crown_light.light_energy = 2.4
	crown_light.omni_range = 18.0
	_storm_crown.add_child(crown_light)
	_merge_crown_static_visuals()


func _merge_crown_static_visuals() -> void:
	# Every architectural part of the crown rotates and bobs as one assembly.
	# Keeping its forty-two primitives as separate render submissions made the
	# Stormworks court unnecessarily expensive on WebGL. Bake them into one mesh
	# per material under the same animated parent: the silhouette, named source
	# nodes and animation remain intact while the crown draws in four passes.
	var groups := {}
	for child in _storm_crown.get_children():
		if not child is MeshInstance3D:
			continue
		var part := child as MeshInstance3D
		if part.mesh == null or part.mesh.get_surface_count() != 1 \
				or part.material_override == null:
			continue
		var material_id := part.material_override.get_instance_id()
		if not groups.has(material_id):
			groups[material_id] = []
		groups[material_id].append(part)
	var batch_index := 0
	var source_count := 0
	for material_id in groups:
		var members: Array = groups[material_id]
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for member_value in members:
			var member := member_value as MeshInstance3D
			surface.append_from(member.mesh, 0, member.transform)
		var combined := surface.commit()
		if combined == null or combined.get_surface_count() == 0:
			continue
		var batch := MeshInstance3D.new()
		batch.name = "CrownRenderBatch%02d" % (batch_index + 1)
		batch.mesh = combined
		batch.material_override = (members[0] as MeshInstance3D).material_override
		batch.set_meta("render_role", "animated crown material batch")
		batch.set_meta("merged_static_source_count", members.size())
		_storm_crown.add_child(batch)
		for member_value in members:
			var member := member_value as MeshInstance3D
			member.layers = 0
			member.set_meta("render_merged_into", batch.name)
			source_count += 1
		batch_index += 1
	_storm_crown.set_meta("render_batch_count", batch_index)
	_storm_crown.set_meta("merged_static_source_count", source_count)


func _add_box_part(parent: Node3D, node_name: String, at: Vector3, size: Vector3,
		material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh_part(parent, node_name, at, mesh, material)


func _add_cylinder_part(parent: Node3D, node_name: String, at: Vector3,
		bottom_radius: float, height: float, material: Material, sides: int = 10,
		top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = bottom_radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = sides
	return _add_mesh_part(parent, node_name, at, mesh, material)


func _add_prism_part(parent: Node3D, node_name: String, at: Vector3, size: Vector3,
		material: Material) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _add_mesh_part(parent, node_name, at, mesh, material)


func _add_sphere_part(parent: Node3D, node_name: String, at: Vector3, radius: float,
		material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.65
	mesh.radial_segments = 12
	mesh.rings = 6
	return _add_mesh_part(parent, node_name, at, mesh, material)


func _add_mesh_part(parent: Node3D, node_name: String, at: Vector3,
		mesh: PrimitiveMesh, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = node_name
	part.position = at
	part.mesh = mesh
	part.material_override = material
	parent.add_child(part)
	return part


func _add_beam(parent: Node3D, node_name: String, from: Vector3, to: Vector3,
		width: float, material: Material) -> MeshInstance3D:
	var beam := _add_box_part(parent, node_name, from.lerp(to, 0.5),
		Vector3(width, width, from.distance_to(to)), material)
	beam.look_at(to, Vector3.UP)
	return beam


func _material(albedo: Color, emission: Color, energy: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = 0.42
	material.roughness = roughness
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
