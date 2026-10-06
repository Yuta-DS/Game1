class_name MindSparkWorldGate
extends Area3D

signal travelled(destination_world_local: Vector3)

@export var destination_world_local := Vector3.ZERO
@export var gate_enabled := true
@export var prompt_text := "Q • ENTER MIND SPARK"
## Empty preserves the original Mind Spark destination contract.
@export var target_world_path: NodePath
@export var build_world_on_travel := true
@export var use_target_world_arrival := false

var _player_inside: CharacterBody3D


func _ready() -> void:
	_build_finished_portal_instrument()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_enabled()


func _build_finished_portal_instrument() -> void:
	## The original functional portal was only one emissive torus and a flat
	## disc. Wrap those stable nodes in a collision-free architectural instrument
	## so every World Gate reads clearly from the front, side, and rear.
	var portal := get_node_or_null("Portal") as Node3D
	if portal == null or portal.has_node("FinishedPortalInstrument"):
		return
	var frame := Node3D.new()
	frame.name = "FinishedPortalInstrument"
	frame.set_meta("design_revision", "celestial_instrument_ring_v2")
	frame.set_meta("collision_free", true)
	frame.set_meta("segmented_case_count", 12)
	frame.set_meta("compact_tick_count", 8)
	portal.add_child(frame)

	var ivory := _portal_material(Color("eee4ce"), 0.72)
	var charcoal := _portal_material(Color("172634"), 0.42)
	var cyan := _portal_material(Color("62c6d1"), 0.38, Color("61d8e4"), 0.48)
	var lavender := _portal_material(Color("9b78c8"), 0.40,
		Color("a67cdb"), 0.42)
	_add_portal_torus(frame, "IvoryOuterCase", 5.62, 6.30, ivory)
	_add_portal_torus(frame, "CharcoalInnerBezel", 4.35, 4.78, charcoal)
	_add_portal_torus(frame, "LavenderEnergyBand", 5.08, 5.38, lavender)

	for segment_index in 12:
		var angle := TAU * float(segment_index) / 12.0
		var segment := _add_portal_box(frame,
			"IvoryCaseSegment_%02d" % (segment_index + 1),
			Vector3(sin(angle) * 6.10, cos(angle) * 6.10, 0.0),
			Vector3(1.30, 0.54, 0.72), ivory)
		segment.rotation.z = -angle
	# Four substantial clamps make the energy ring feel held by the case rather
	# than painted onto it. They remain visual only, outside the player trigger.
	for clamp_index in 4:
		var angle := TAU * float(clamp_index) / 4.0
		var clamp := _add_portal_box(frame,
			"CardinalClamp_%02d" % (clamp_index + 1),
			Vector3(sin(angle) * 5.82, cos(angle) * 5.82, 0.0),
			Vector3(1.05, 1.70, 0.96), charcoal)
		clamp.rotation.z = -angle
		_add_portal_box(frame, "ClampCyanInset_%02d" % (clamp_index + 1),
			Vector3(sin(angle) * 5.84, cos(angle) * 5.84, -0.52),
			Vector3(0.42, 0.78, 0.10), cyan).rotation.z = -angle

	for tick_index in 8:
		var angle := TAU * float(tick_index) / 8.0
		var tick := _add_portal_box(frame, "ApertureTick_%02d" % (tick_index + 1),
			Vector3(sin(angle) * 4.05, cos(angle) * 4.05, -0.22),
			Vector3(0.30, 0.86, 0.18), ivory)
		tick.rotation.z = -angle

	# A small central navigation sigil and crown crystal provide a clear focal
	# hierarchy without brightening the complete portal surface.
	var sigil := _add_portal_box(frame, "CyanNavigationSigil",
		Vector3(0.0, 0.0, -0.34), Vector3(0.80, 1.34, 0.18), cyan)
	sigil.rotation.z = PI * 0.25
	var crown := _add_portal_box(frame, "LavenderCrownCrystal",
		Vector3(0.0, 7.25, 0.0), Vector3(1.18, 1.90, 0.92), lavender)
	crown.rotation.z = PI * 0.25
	_add_portal_box(frame, "CrownCrystalSocket", Vector3(0.0, 6.35, 0.0),
		Vector3(2.35, 0.58, 1.18), charcoal)
	for side in [-1.0, 1.0]:
		var side_name := "Left" if side < 0.0 else "Right"
		_add_portal_box(frame, "%sGroundedFoot" % side_name,
			Vector3(float(side) * 4.75, -4.70, 0.0),
			Vector3(2.65, 0.72, 2.25), ivory)
		var brace := _add_portal_box(frame, "%sRakingBrace" % side_name,
			Vector3(float(side) * 5.15, -2.75, 0.0),
			Vector3(0.70, 4.25, 0.92), charcoal)
		brace.rotation.z = float(side) * 0.34


func _portal_material(albedo: Color, roughness: float,
		emission := Color.TRANSPARENT, emission_energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material


func _add_portal_torus(parent: Node3D, node_name: String, inner_radius: float,
		outer_radius: float, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 32
	mesh.ring_segments = 8
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.rotation_degrees.x = 90.0
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_portal_box(parent: Node3D, node_name: String, position_value: Vector3,
		size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = material
	parent.add_child(instance)
	return instance


func set_gate_enabled(enabled: bool) -> void:
	gate_enabled = enabled
	_apply_enabled()


func teleport_player(player: CharacterBody3D) -> bool:
	if not gate_enabled or player == null:
		return false
	var floating_world := _find_floating_world()
	if floating_world == null:
		return false
	# World One may be built lazily to keep the art gallery within the web
	# export's memory budget, so make sure it exists before travelling into it -
	# otherwise the player lands in empty space where the world should be.
	var destination_world := get_node_or_null(target_world_path) if not target_world_path.is_empty() \
		else floating_world.get_node_or_null("MindSparkWorldOne")
	if build_world_on_travel and destination_world != null and destination_world.has_method("ensure_world_built"):
		var result: Variant = destination_world.call("ensure_world_built")
		if result is bool and not result:
			return false
	# World One's supported entrance is deliberately offset from the district
	# centre to clear the Observatory architecture and checkpoint machinery. The
	# old gate stored the zone centre before the deferred world existed, landing
	# the player hundreds of metres away from the authored arrival marker.
	if use_target_world_arrival and destination_world != null \
			and destination_world.has_method("get_player_arrival_local"):
		destination_world_local = destination_world.position \
			+ destination_world.call("get_player_arrival_local")
	if floating_world.has_method("remove_pink_purple_sphere_placeholders"):
		floating_world.call("remove_pink_purple_sphere_placeholders")
	player.global_position = floating_world.to_global(destination_world_local)
	player.velocity = Vector3.ZERO
	if build_world_on_travel and destination_world != null and destination_world.has_method("activate"):
		destination_world.call("activate", player)
	travelled.emit(destination_world_local)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if _player_inside != null and event.is_action_pressed("interact") and teleport_player(_player_inside):
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.is_in_group("Player"):
		_player_inside = body
		$Prompt.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body == _player_inside:
		_player_inside = null
		$Prompt.visible = false


func _find_floating_world() -> Node3D:
	var current: Node = self
	while current != null:
		if current.name == "ArtCastleFloatingWorld" or current.has_method("get_kingdom_exploration_size"):
			return current as Node3D
		current = current.get_parent()
	return null


func _apply_enabled() -> void:
	monitoring = gate_enabled
	$Prompt.text = prompt_text if gate_enabled else "WORLD GATE • COMPLETE THE CURRENT QUEST"
	$Portal.visible = gate_enabled
	$Light.visible = gate_enabled
