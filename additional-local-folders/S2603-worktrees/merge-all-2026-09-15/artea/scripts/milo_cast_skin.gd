extends Node3D

# Milo deliberately uses the same animated GLB and material language as the
# town's market villagers. Every visible part is fitted to that rig: the source
# warrior meshes are hidden and replaced by one compact low-poly cat-mayor
# silhouette. This keeps Milo visually consistent with the market cast.

var _flat_shader: Shader


func _ready() -> void:
	_flat_shader = Shader.new()
	_flat_shader.code = """
shader_type spatial;
render_mode diffuse_burley;
uniform vec3 tint : source_color = vec3(1.0);
void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.88;
}
"""
	_hide_adventurer_equipment()
	_apply_cast_palette()
	_add_mayor_accessories()
	_install_npc_animation_aliases()


func _cast_material(name: String, color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = name
	material.shader = _flat_shader
	material.set_shader_parameter("tint", color)
	return material


func _apply_cast_palette() -> void:
	var palette := {
		"Barbarian_Head": Color("b9aa94"),
		"Barbarian_Body": Color("17334d"),
		"Barbarian_ArmLeft": Color("234866"),
		"Barbarian_ArmRight": Color("234866"),
		"Barbarian_LegLeft": Color("4b342a"),
		"Barbarian_LegRight": Color("4b342a"),
	}
	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if palette.has(mesh_instance.name):
			mesh_instance.material_override = _cast_material(
				"Milo_%s" % mesh_instance.name, palette[mesh_instance.name])


func _hide_adventurer_equipment() -> void:
	for part_name in ["1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe",
			"2H_Axe", "Mug", "Barbarian_Hat", "Barbarian_Cape",
			"Barbarian_Head", "Barbarian_Body", "Barbarian_ArmLeft",
			"Barbarian_ArmRight", "Barbarian_LegLeft", "Barbarian_LegRight"]:
		var part := find_child(part_name, true, false) as Node3D
		if part != null:
			part.visible = false


func _mesh_part(parent: Node, name: String, mesh: PrimitiveMesh,
		position: Vector3, scale: Vector3, material: Material,
		rotation := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name
	part.mesh = mesh
	part.position = position
	part.scale = scale
	part.rotation = rotation
	part.material_override = material
	parent.add_child(part)
	return part


func _orient_local_y_toward_global(part: Node3D, attachment: BoneAttachment3D,
		target_axis: Vector3) -> void:
	var local_axis := (attachment.global_basis.inverse() * target_axis).normalized()
	part.quaternion = Quaternion(Vector3.UP, local_axis)


func _star_mesh() -> ImmediateMesh:
	var star := ImmediateMesh.new()
	star.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(10):
		var a0 := -PI * 0.5 + TAU * float(i) / 10.0
		var a1 := -PI * 0.5 + TAU * float(i + 1) / 10.0
		var r0 := 0.075 if i % 2 == 0 else 0.035
		var r1 := 0.075 if (i + 1) % 2 == 0 else 0.035
		star.surface_add_vertex(Vector3.ZERO)
		star.surface_add_vertex(Vector3(cos(a0) * r0, sin(a0) * r0, 0))
		star.surface_add_vertex(Vector3(cos(a1) * r1, sin(a1) * r1, 0))
	star.surface_end()
	return star


func _triangle_mesh() -> ImmediateMesh:
	var triangle := ImmediateMesh.new()
	triangle.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	triangle.surface_add_vertex(Vector3(-0.075, 0.075, 0))
	triangle.surface_add_vertex(Vector3(0.075, 0.075, 0))
	triangle.surface_add_vertex(Vector3(0, -0.085, 0))
	triangle.surface_end()
	return triangle


func _add_mesh(parent: Node, name: String, mesh: Mesh, position: Vector3,
		material: Material, rotation := Vector3.ZERO,
		scale := Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name
	part.mesh = mesh
	part.position = position
	part.rotation = rotation
	part.scale = scale
	part.material_override = material
	parent.add_child(part)
	return part


func _add_bone_part(skeleton: Skeleton3D, socket_name: String,
		bone_name: String, part_name: String, mesh: PrimitiveMesh,
		position: Vector3, scale: Vector3, material: Material,
		rotation := Vector3.ZERO) -> MeshInstance3D:
	var socket := BoneAttachment3D.new()
	socket.name = socket_name
	socket.bone_name = bone_name
	skeleton.add_child(socket)
	return _mesh_part(socket, part_name, mesh, position, scale, material, rotation)


func _rounded_limb(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


func _add_mayor_accessories() -> void:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return

	var gold := _cast_material("MiloGold", Color("c79638"))
	var navy := _cast_material("MiloNavySuit", Color("28577a"))
	var cream := _cast_material("MiloCream", Color("d8bea0"))
	var white_fur := _cast_material("MiloWhiteFur", Color("f1eadf"))
	var purple := _cast_material("MiloPurple", Color("65476e"))
	var teal := _cast_material("MiloTealPiping", Color("3293a4"))
	var green := _cast_material("MiloLeafPin", Color("68a94d"))
	var cyan := _cast_material("MiloDiamondPin", Color("57c8dc"))
	var star_purple := _cast_material("MiloStarPin", Color("8b5cad"))
	var dark := _cast_material("MiloEye", Color("262a2d"))
	var pink := _cast_material("MiloCatPink", Color("d79b91"))
	var brown := _cast_material("MiloShoes", Color("5a4033"))
	var trousers := _cast_material("MiloTrousers", Color("24303b"))

	var head := BoneAttachment3D.new()
	head.name = "MayorCatHead"
	head.bone_name = "head"
	skeleton.add_child(head)

	# The villager rig supplies animation only; its human head is hidden above.
	# Build a complete rounded cat head so Milo reads as a cat from every angle,
	# instead of cat accessories floating over a human Barbarian face.
	var head_base := SphereMesh.new()
	head_base.radius = 0.36
	head_base.height = 0.64
	head_base.radial_segments = 10
	head_base.rings = 5
	_mesh_part(head, "CatHeadBase", head_base, Vector3(0, 0.02, 0.16),
		Vector3(1.08, 1.0, 0.86), cream)

	# Soft side-cheek tufts and the small forehead marking reproduce the elderly
	# cream-cat silhouette from the approved Mayor Milo references.
	for side in [-1.0, 1.0]:
		for tuft_index in range(2):
			var cheek_tuft := SphereMesh.new()
			cheek_tuft.radius = 0.105
			cheek_tuft.height = 0.21
			cheek_tuft.radial_segments = 8
			cheek_tuft.rings = 4
			_mesh_part(head, "CheekTuft_%s_%d" % [side, tuft_index], cheek_tuft,
				Vector3((0.31 + tuft_index * 0.035) * side,
					-0.02 - tuft_index * 0.11, 0.23),
				Vector3(0.9, 0.62, 0.72), white_fur)
	var marking_material := _cast_material("MiloForeheadMarking", Color("a9957f"))
	_add_mesh(head, "CatForeheadMark", _triangle_mesh(),
		Vector3(0, 0.25, 0.465), marking_material)

	# Broad triangular ears keep Milo unmistakably feline at normal gameplay
	# distance while retaining the same chunky low-poly language as villagers.
	for side in [-1.0, 1.0]:
		var ear := PrismMesh.new()
		ear.size = Vector3(0.24, 0.38, 0.12)
		_mesh_part(head, "CatEar_%s" % ("L" if side < 0 else "R"), ear,
			Vector3(0.24 * side, 0.30, 0.02), Vector3.ONE, cream,
			Vector3(0, 0, -0.18 * side))
		var inner_ear := PrismMesh.new()
		inner_ear.size = Vector3(0.12, 0.23, 0.025)
		_mesh_part(head, "CatEarInner_%s" % ("L" if side < 0 else "R"), inner_ear,
			Vector3(0.24 * side, 0.30, 0.135), Vector3.ONE, pink,
			Vector3(0, 0, -0.18 * side))

	# Gold round spectacles, bright eyes, a pink nose and white moustache match
	# the approved Cat Mayor reference without replacing the villager rig.
	for side in [-1.0, 1.0]:
		var eyebrow := SphereMesh.new()
		eyebrow.radius = 0.075
		eyebrow.height = 0.15
		eyebrow.radial_segments = 8
		eyebrow.rings = 3
		_mesh_part(head, "WhiteEyebrow_%s" % side, eyebrow,
			Vector3(0.13 * side, 0.225, 0.455), Vector3(1.15, 0.30, 0.35), white_fur,
			Vector3(0, 0, -0.12 * side))
		var eye_white := SphereMesh.new()
		eye_white.radius = 0.11
		eye_white.height = 0.22
		eye_white.radial_segments = 12
		eye_white.rings = 6
		_mesh_part(head, "CatEyeWhite_%s" % side, eye_white,
			Vector3(0.115 * side, 0.075, 0.405), Vector3(0.82, 1.0, 0.34), white_fur)
		var pupil := SphereMesh.new()
		pupil.radius = 0.052
		pupil.height = 0.13
		pupil.radial_segments = 12
		pupil.rings = 6
		_mesh_part(head, "CatEye_%s" % side, pupil,
			Vector3(0.115 * side, 0.07, 0.445), Vector3(0.72, 1.0, 0.28), dark)
		var lens_ring := TorusMesh.new()
		lens_ring.inner_radius = 0.112
		lens_ring.outer_radius = 0.137
		lens_ring.rings = 14
		lens_ring.ring_segments = 5
		_mesh_part(head, "GlassesRing_%s" % ("L" if side < 0 else "R"), lens_ring,
			Vector3(0.115 * side, 0.075, 0.475), Vector3.ONE, gold,
			Vector3(PI * 0.5, 0, 0))
	var glasses_bridge := BoxMesh.new()
	glasses_bridge.size = Vector3(0.09, 0.025, 0.025)
	_mesh_part(head, "GlassesBridge", glasses_bridge,
		Vector3(0, 0.075, 0.475), Vector3.ONE, gold)
	var nose := SphereMesh.new()
	nose.radius = 0.07
	nose.height = 0.12
	nose.radial_segments = 10
	nose.rings = 5
	_mesh_part(head, "CatNose", nose, Vector3(0, -0.055, 0.475),
		Vector3(1.05, 0.72, 0.62), pink)

	for side in [-1.0, 1.0]:
		var moustache := SphereMesh.new()
		moustache.radius = 0.13
		moustache.height = 0.26
		moustache.radial_segments = 10
		moustache.rings = 5
		_mesh_part(head, "Moustache_%s" % ("L" if side < 0 else "R"), moustache,
			Vector3(0.105 * side, -0.12, 0.39), Vector3(1.05, 0.34, 0.42), white_fur,
			Vector3(0, 0, 0.18 * side))

	var chest := BoneAttachment3D.new()
	chest.name = "MayorCoatDetails"
	chest.bone_name = "chest"
	skeleton.add_child(chest)
	var suit_torso := SphereMesh.new()
	suit_torso.radius = 0.35
	suit_torso.height = 0.70
	suit_torso.radial_segments = 10
	suit_torso.rings = 5
	_mesh_part(chest, "MayorSuitTorso", suit_torso, Vector3(0, -0.10, 0.075),
		Vector3(1.0, 1.0, 0.66), navy)
	var shirt_collar := BoxMesh.new()
	shirt_collar.size = Vector3(0.24, 0.10, 0.035)
	_mesh_part(chest, "MayorShirtCollar", shirt_collar,
		Vector3(0, 0.20, 0.294), Vector3.ONE, white_fur)
	var waistcoat := PrismMesh.new()
	waistcoat.size = Vector3(0.34, 0.39, 0.055)
	_mesh_part(chest, "Waistcoat", waistcoat, Vector3(0, -0.11, 0.305),
		Vector3.ONE, purple, Vector3(0, 0, PI))
	var tie := PrismMesh.new()
	tie.size = Vector3(0.09, 0.18, 0.045)
	_mesh_part(chest, "ProfessorTie", tie, Vector3(0, 0.10, 0.326),
		Vector3.ONE, purple, Vector3(0, 0, PI))
	for side in [-1.0, 1.0]:
		for y in [-0.10, 0.05]:
			var button := SphereMesh.new()
			button.radius = 0.025
			button.height = 0.05
			button.radial_segments = 6
			button.rings = 3
			_mesh_part(chest, "CoatButton_%s_%s" % [side, y], button,
				Vector3(0.105 * side, y, 0.340), Vector3.ONE, gold)

	# Teal lapel piping and restrained gold edging follow the approved suit
	# reference while staying chunky enough for the village's low-poly language.
	for side in [-1.0, 1.0]:
		var lapel := BoxMesh.new()
		lapel.size = Vector3(0.025, 0.31, 0.022)
		_mesh_part(chest, "TealLapel_%s" % side, lapel,
			Vector3(0.12 * side, 0.10, 0.330), Vector3.ONE, teal,
			Vector3(0, 0, -0.48 * side))
		var coat_edge := BoxMesh.new()
		coat_edge.size = Vector3(0.022, 0.40, 0.022)
		_mesh_part(chest, "GoldCoatEdge_%s" % side, coat_edge,
			Vector3(0.185 * side, -0.12, 0.315), Vector3.ONE, gold)
		var pocket := BoxMesh.new()
		pocket.size = Vector3(0.13, 0.025, 0.025)
		_mesh_part(chest, "GoldPocketTrim_%s" % side, pocket,
			Vector3(0.14 * side, -0.25, 0.325), Vector3.ONE, gold,
			Vector3(0, 0, 0.08 * side))
	var hem := BoxMesh.new()
	hem.size = Vector3(0.42, 0.025, 0.025)
	_mesh_part(chest, "GoldCoatHem", hem, Vector3(0, -0.34, 0.315),
		Vector3.ONE, gold)

	# The three permanent identity pins: cyan diamond, green leaf, purple star.
	var diamond := BoxMesh.new()
	diamond.size = Vector3(0.075, 0.075, 0.026)
	_mesh_part(chest, "Pin_Diamond", diamond, Vector3(-0.145, 0.18, 0.345),
		Vector3.ONE, cyan, Vector3(0, 0, PI * 0.25))
	var leaf := SphereMesh.new()
	leaf.radius = 0.065
	leaf.height = 0.13
	leaf.radial_segments = 7
	leaf.rings = 3
	_mesh_part(chest, "Pin_Leaf", leaf, Vector3(-0.19, 0.095, 0.345),
		Vector3(0.48, 1.0, 0.28), green, Vector3(0, 0, -0.55))
	_add_mesh(chest, "Pin_Star", _star_mesh(), Vector3(-0.105, 0.095, 0.358),
		star_purple, Vector3.ZERO, Vector3.ONE)

	# Every limb is fitted to the actual market-villager bone chain. Slightly
	# overlapping joints keep the silhouette compact during all NPC animations.
	for side_spec in [["L", ".l"], ["R", ".r"]]:
		var side: String = side_spec[0]
		var suffix: String = side_spec[1]
		_add_bone_part(skeleton, "MayorUpperSleeveSocket_%s" % side,
			"upperarm%s" % suffix, "MayorUpperSleeve_%s" % side,
			_rounded_limb(0.145, 0.38), Vector3(0, 0.105, 0),
			Vector3(1.05, 1.0, 1.05), navy)
		_add_bone_part(skeleton, "MayorLowerSleeveSocket_%s" % side,
			"lowerarm%s" % suffix, "MayorLowerSleeve_%s" % side,
			_rounded_limb(0.135, 0.36), Vector3(0, 0.12, 0),
			Vector3.ONE, navy)
		_add_bone_part(skeleton, "MayorPawSocket_%s" % side,
			"hand%s" % suffix, "MayorPaw_%s" % side,
			_rounded_limb(0.14, 0.25), Vector3(0, 0.07, 0),
			Vector3(1.0, 1.0, 0.92), cream)

		_add_bone_part(skeleton, "MayorUpperTrouserSocket_%s" % side,
			"upperleg%s" % suffix, "MayorUpperTrouser_%s" % side,
			_rounded_limb(0.145, 0.34), Vector3(0, 0.10, 0),
			Vector3(1.0, 1.0, 0.92), trousers)
		_add_bone_part(skeleton, "MayorLowerTrouserSocket_%s" % side,
			"lowerleg%s" % suffix, "MayorLowerTrouser_%s" % side,
			_rounded_limb(0.125, 0.26), Vector3(0, 0.075, 0),
			Vector3(1.0, 1.0, 0.92), trousers)
		_add_bone_part(skeleton, "MayorShoeSocket_%s" % side,
			"foot%s" % suffix, "MayorShoe_%s" % side,
			_rounded_limb(0.16, 0.28), Vector3(0, 0.075, 0.035),
			Vector3(1.05, 1.0, 1.28), brown)

	# Gold cuffs bridge the sleeves and cream paws instead of floating over them.
	for side_spec in [["L", ".l"], ["R", ".r"]]:
		var cuff := CylinderMesh.new()
		cuff.top_radius = 0.145
		cuff.bottom_radius = 0.145
		cuff.height = 0.045
		cuff.radial_segments = 8
		_add_bone_part(skeleton, "MayorCuffSocket_%s" % side_spec[0],
			"hand%s" % side_spec[1], "MayorGoldCuff_%s" % side_spec[0], cuff,
			Vector3(0, -0.015, 0), Vector3.ONE, gold)

	# Keep a named facial anchor for tests and future dialogue-look controls.
	var face_anchor := Node3D.new()
	face_anchor.name = "VillagerStyleFace"
	head.add_child(face_anchor)
	face_anchor.set_meta("material_language", dark.resource_name)

	# A short raised tail completes the silhouette but stays clear of the cane.
	var tail_socket := Node3D.new()
	tail_socket.name = "TailSocket"
	chest.add_child(tail_socket)
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0.25, -0.30, -0.18)
	tail_socket.add_child(tail)
	for i in range(4):
		var tail_segment := SphereMesh.new()
		tail_segment.radius = 0.075 - float(i) * 0.008
		tail_segment.height = (0.075 - float(i) * 0.008) * 2.0
		tail_segment.radial_segments = 8
		tail_segment.rings = 4
		_mesh_part(tail, "TailSegment%02d" % i, tail_segment,
			Vector3(0.08 * i, 0.10 * i, -0.015 * i),
			Vector3(1.15, 1.0, 0.90),
			marking_material if i % 2 == 1 else cream)


func _add_guidance_cane(character_root: Node3D, wood: Material,
		gold: Material) -> void:
	var cane := Node3D.new()
	cane.name = "CaneSocket"
	cane.position = Vector3(-0.54, 1.30, 0.08)
	character_root.add_child(cane)
	var cane_parts := Node3D.new()
	cane_parts.name = "GuidanceCane"
	cane.add_child(cane_parts)

	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.035
	shaft.bottom_radius = 0.035
	shaft.height = 1.28
	shaft.radial_segments = 8
	_mesh_part(cane_parts, "CaneWoodShaft", shaft, Vector3(0, -0.63, 0),
		Vector3.ONE, wood)

	for band_spec in [["CaneGoldCollar", 0.0, 0.055, 0.10],
			["CaneGoldFerrule", -1.30, 0.050, 0.14]]:
		var band := CylinderMesh.new()
		band.top_radius = float(band_spec[2])
		band.bottom_radius = float(band_spec[2])
		band.height = float(band_spec[3])
		band.radial_segments = 8
		_mesh_part(cane_parts, str(band_spec[0]), band,
			Vector3(0, float(band_spec[1]), 0), Vector3.ONE, gold)

	# A faceted crook assembled from overlapping low-poly gold beads. It stays
	# readable at gameplay distance and is clearly a walking cane, not a weapon.
	var hook_points := [
		Vector2(0.00, 0.08), Vector2(0.03, 0.15), Vector2(0.09, 0.20),
		Vector2(0.16, 0.20), Vector2(0.21, 0.16), Vector2(0.22, 0.09),
		Vector2(0.19, 0.03), Vector2(0.14, 0.00),
	]
	for i in range(hook_points.size()):
		var bead := SphereMesh.new()
		bead.radius = 0.060
		bead.height = 0.12
		bead.radial_segments = 7
		bead.rings = 3
		var point: Vector2 = hook_points[i]
		_mesh_part(cane_parts, "CaneCrook%02d" % i, bead,
			Vector3(point.x, point.y, 0), Vector3.ONE, gold)


func _install_npc_animation_aliases() -> void:
	var animation_player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		return
	var library := animation_player.get_animation_library("")
	if library == null:
		return
	var aliases := {
		"Idle_3": "Idle",
		"Walk": "Walking_A",
		"Walking": "Walking_A",
		"Run": "Running_A",
		"Running": "Running_A",
		"Wave_One_Hand": "Cheer",
	}
	for alias in aliases:
		var source: String = aliases[alias]
		if not library.has_animation(alias) and animation_player.has_animation(source):
			library.add_animation(alias, animation_player.get_animation(source).duplicate())
