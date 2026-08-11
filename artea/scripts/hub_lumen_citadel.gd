# The Lumen Engine Citadel is Artéa's original roaming landmark.
#
# It deliberately avoids copying any existing film castle: this is a bright,
# restorative machine-city whose science is visible. Brass mechanisms collect
# the light made by the player, while constellations map the next gentle step
# in their journey. It is built at runtime so the large hub scene stays easy
# to edit in Godot.
extends Node3D

const THOUGHTS_PORTAL := Vector3(90.3, 15.0, -83.0)
const CASTLE_NAME := "building_castle_red2"
const STAGE_COLOURS := [
	Color("415777"), # sleeping blue-grey
	Color("86b7ff"), # a thought noticed
	Color("f5a95e"), # a feeling named
	Color("d98cff"), # a creation made
	Color("ffd66e"), # a whole constellation
]

const BRASS := Color("b78242")
const INK := Color("18243d")
const GLASS := Color("86dfff")

var _castle: Node3D
var _castle_start_position := Vector3.ZERO
var _time := 0.0
var _stage := 0
var _rotors: Array[Node3D] = []
var _light_materials: Array[StandardMaterial3D] = []
var _waypoint_lights: Array[OmniLight3D] = []
var _citadel_lamp: OmniLight3D
var _castle_fill: OmniLight3D
var _foundation: Node3D
var _foundation_start_y := 0.0


func _ready() -> void:
	# The packed hub finishes instancing its large castle before we attach the
	# living machinery. This also makes the script safe when previewed alone.
	await get_tree().process_frame
	_castle = get_parent().get_node_or_null(CASTLE_NAME) as Node3D
	if _castle == null:
		push_warning("Lumen Citadel: hub castle not found")
		return

	_castle_start_position = _castle.position
	_brighten_castle_materials(_castle)
	_build_castle_foundation()
	_build_high_aether_facade()
	_build_astral_observatory_crown()
	_build_reference_astral_machine()
	_build_citadel_rig()
	_build_skyway()
	apply_stage(_current_stage())


func _process(delta: float) -> void:
	if _castle == null:
		return

	_time += delta
	# Architecture connected to a fixed stair and courtyard must not bob. The
	# old 0.44 m peak-to-peak movement continuously opened and closed the seam at
	# the real front door, and moved StaticBody collision under a standing
	# player. Life now comes from the engine, orbit instruments and aether cores;
	# every walkable surface remains stable.
	_castle.position = _castle_start_position
	if _foundation != null:
		_foundation.position.y = _foundation_start_y

	for i in _rotors.size():
		var direction := 1.0 if i % 2 == 0 else -1.0
		_rotors[i].rotate_y(direction * delta * (0.18 + _stage * 0.12))


# Called by hub_awakening whenever the player returns with a new discovery.
func apply_stage(stage: int) -> void:
	_stage = clampi(stage, 0, STAGE_COLOURS.size() - 1)
	var glow: Color = STAGE_COLOURS[_stage]
	# Keep the dormant science channels readable against Artéa's bright sky,
	# while preserving almost the same stage-four ceiling as the old curve.
	var energy := 0.46 + float(_stage) * 0.30

	for material in _light_materials:
		material.emission = glow
		material.emission_energy_multiplier = energy

	for i in _waypoint_lights.size():
		# The route only reveals the next destination at first. Later lights
		# make the complete journey legible as one path, rather than a menu.
		_waypoint_lights[i].visible = i <= _stage
		_waypoint_lights[i].light_color = glow

	if _citadel_lamp != null:
		_citadel_lamp.light_color = glow
		_citadel_lamp.light_energy = 0.4 + float(_stage) * 0.28
	if _castle_fill != null:
		_castle_fill.light_color = glow.lightened(0.28)
		_castle_fill.light_energy = 0.62 + float(_stage) * 0.12


func set_vibrant(vibrant: bool) -> void:
	apply_stage(4 if vibrant else 0)


func is_vibrant() -> bool:
	return _stage > 0


# --- Citadel ---------------------------------------------------------

# The imported castle previously hovered as a bare building with open sky under
# its floor. This low-poly rock/engine island gives it physical weight, a future
# gallery plaza, and compact levitation anchors beneath its rock island.
func _build_castle_foundation() -> void:
	_foundation = Node3D.new()
	_foundation.name = "CastleFoundation"
	get_parent().add_child(_foundation)
	_foundation.position = Vector3(_castle.position.x, _castle.position.y - 4.2,
		_castle.position.z)
	_foundation_start_y = _foundation.position.y

	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_color = Color(0.30, 0.34, 0.42)
	rock_material.roughness = 0.92
	rock_material.emission_enabled = true
	rock_material.emission = Color(0.12, 0.15, 0.21)
	rock_material.emission_energy_multiplier = 0.08

	# A floating citadel needs a readable load path. The previous compressed
	# sphere looked like a smooth purple capsule and made the castle appear to
	# sit on a placeholder primitive. Two low-poly tapered masses create a broad
	# inhabited shelf, a rocky keel, and a silhouette that reads at village scale.
	var island := MeshInstance3D.new()
	island.name = "CitadelRockShelf"
	var island_mesh := CylinderMesh.new()
	island_mesh.top_radius = 16.5
	island_mesh.bottom_radius = 8.2
	island_mesh.height = 11.0
	island_mesh.radial_segments = 12
	island.mesh = island_mesh
	island.material_override = rock_material
	_foundation.add_child(island)

	var keel := MeshInstance3D.new()
	keel.name = "CitadelRockKeel"
	var keel_mesh := CylinderMesh.new()
	keel_mesh.top_radius = 8.2
	keel_mesh.bottom_radius = 1.8
	keel_mesh.height = 8.5
	keel_mesh.radial_segments = 10
	keel.mesh = keel_mesh
	keel.position.y = -9.5
	keel.material_override = rock_material
	_foundation.add_child(keel)

	# The raised citadel's entry is a deliberate open sector, not a solid disc
	# that cuts across the final stair. These three support decks preserve safe
	# footing on the rear and flanks while leaving a 12 m-wide, collision-free
	# procession from the court to the elevated threshold.
	_add_foundation_support("FoundationRearSupport", Vector3(-2.0, 4.7, 0.0),
		Vector3(20.0, 2.0, 22.0))
	_add_foundation_support("FoundationWestSupport", Vector3(11.0, 4.7, -10.5),
		Vector3(7.0, 2.0, 7.5))
	_add_foundation_support("FoundationEastSupport", Vector3(11.0, 4.7, 10.5),
		Vector3(7.0, 2.0, 7.5))

	# GALLERY_ANCHOR — future gallery/world content can attach here without
	# depending on the imported castle's internal glTF node names.
	var gallery_anchor := Node3D.new()
	gallery_anchor.name = "GALLERY_ANCHOR"
	gallery_anchor.position = Vector3(10.5, 5.8, 0.0)
	gallery_anchor.set_meta("purpose", "future_gallery_courtyard")
	_foundation.add_child(gallery_anchor)

	var plaza := MeshInstance3D.new()
	var plaza_mesh := CylinderMesh.new()
	plaza_mesh.top_radius = 7.0
	plaza_mesh.bottom_radius = 7.6
	plaza_mesh.height = 0.7
	plaza_mesh.radial_segments = 10
	plaza.mesh = plaza_mesh
	plaza.position = gallery_anchor.position
	plaza.material_override = _ink_material()
	_foundation.add_child(plaza)

	# Compact floating anchors replace the former 25–35 m cylinders beneath the
	# castle. Those read as canopy pipes from ground level and visually tangled
	# with the stair. Faceted shards and calibration rings retain the magitech
	# explanation without placing any tall vertical geometry near the doorway.
	_foundation.set_meta("pipe_free_foundation", true)
	var anchor_glow := _glow_material(STAGE_COLOURS[0])
	for i in 5:
		var angle := TAU * float(i) / 5.0 + 0.35
		var anchor := Node3D.new()
		anchor.name = "FloatingFoundationAnchor_%d" % (i + 1)
		anchor.position = Vector3(cos(angle) * (8.0 + float(i % 2) * 1.8),
			-7.0 - float(i % 2) * 1.1,
			sin(angle) * (6.5 + float((i + 1) % 2) * 1.8))
		_foundation.add_child(anchor)

		var shard := MeshInstance3D.new()
		var shard_mesh := SphereMesh.new()
		shard_mesh.radius = 1.0
		shard_mesh.height = 3.2
		shard_mesh.radial_segments = 6
		shard_mesh.rings = 3
		shard.mesh = shard_mesh
		shard.material_override = rock_material if i % 2 else anchor_glow
		shard.rotation_degrees = Vector3(8.0 * sin(angle), rad_to_deg(angle), 12.0 * cos(angle))
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		anchor.add_child(shard)

		var ring := MeshInstance3D.new()
		ring.mesh = _torus(1.18, 1.42)
		ring.rotation_degrees.x = 90.0
		ring.material_override = _brass_material()
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		anchor.add_child(ring)
		_rotors.append(ring)

	_castle_fill = OmniLight3D.new()
	_castle_fill.name = "CastleDetailFill"
	_castle_fill.position = Vector3(9.0, 18.0, 8.0)
	_castle_fill.light_color = Color(1.0, 0.78, 0.48)
	_castle_fill.light_energy = 1.05
	_castle_fill.omni_range = 58.0
	_castle_fill.omni_attenuation = 1.25
	_castle_fill.shadow_enabled = false
	_foundation.add_child(_castle_fill)


# The High Aether Citadel is a facade system, not a pile of props. Two
# outboard buttresses carry the visible vertical load at the entrance, a brass
# aperture turns the doorway into an observatory instrument, and a thin
# calibration band explains the castle's levitation without closing the route.
# All of these meshes are deliberately visual-only: the stair, threshold and
# side courts keep their authored collision and the player never encounters an
# invisible scientific-looking obstruction.
func _build_high_aether_facade() -> void:
	var facade := Node3D.new()
	facade.name = "HighAetherFacade"
	facade.set_meta("collision_policy", "visual_only_open_entry_sector")
	# The front door is 11.6 m along +X from the imported castle's centre. Keep
	# the framing just behind it and outside the 7.4 m central ascent.
	facade.position = Vector3(11.2, 0.0, 0.0)
	_foundation.add_child(facade)

	var stone := _ink_material()
	var brass := _brass_material()
	var cyan := _glow_material(Color("64dcff"))
	var violet := _glow_material(Color("c58dff"))

	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		var buttress := Node3D.new()
		buttress.name = "AetherButtress_L" if side < 0.0 else "AetherButtress_R"
		buttress.position = Vector3(0.0, 7.0, side * 5.45)
		facade.add_child(buttress)

		# Dark stone establishes the Gothic mass; a brass crown and luminous
		# conductor make its engineering legible as contemporary magitech.
		_add_mesh(buttress, _box(Vector3(1.15, 7.6, 0.95)), stone, Vector3.ZERO)
		_add_mesh(buttress, _box(Vector3(1.42, 0.22, 1.24)), brass,
			Vector3(0.0, 3.68, 0.0))
		_add_mesh(buttress, _box(Vector3(0.16, 4.75, 0.16)), cyan,
			Vector3(0.64, -0.18, 0.0))
		_add_mesh(buttress, _sphere(0.42, 0.78), violet,
			Vector3(0.64, 1.7, 0.0))
		_add_mesh(buttress, _cylinder(0.46, 0.46, 0.18), brass,
			Vector3(0.64, -2.75, 0.0), Vector3.ONE, Vector3(0.0, 0.0, PI * 0.5))

		var lamp := OmniLight3D.new()
		lamp.name = "ButtressAetherLight"
		lamp.position = Vector3(1.05, 1.4, 0.0)
		lamp.light_color = Color("a5eaff")
		lamp.light_energy = 0.65
		lamp.omni_range = 10.0
		lamp.shadow_enabled = false
		buttress.add_child(lamp)

	# A complete aperture is scientific enough to read as a calibration device,
	# while its pointed vertical proportion still belongs to a castle. It floats
	# well above the final tread and has no collider, so it cannot become a new
	# low-ceiling version of the old crown defect.
	var aperture := Node3D.new()
	aperture.name = "ObservatoryAperture"
	aperture.position = Vector3(-0.35, 9.0, 0.0)
	facade.add_child(aperture)
	_add_mesh(aperture, _torus(4.16, 4.46), brass,
		Vector3.ZERO, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.5))
	_add_mesh(aperture, _torus(3.88, 4.02), cyan,
		Vector3.ZERO, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.5))

	# The foundation already carries the visible heavy load through its faceted
	# rock shelf and paired entrance buttresses. The science layer should be
	# lighter: one calm orbital calibration band reads as an instrument around
	# the lower towers, rather than large struts that compete with the roofline.
	var band := Node3D.new()
	band.name = "AetherCalibrationBand"
	# Its front-most point stays at least 2.4 m above the new threshold, so it
	# reads as a survey instrument rather than a beam across the player route.
	band.position = Vector3(0.0, 10.7, 0.0)
	_foundation.add_child(band)
	_add_mesh(band, _torus(11.4, 11.72), brass, Vector3.ZERO)
	_add_mesh(band, _torus(10.92, 11.08), cyan, Vector3.ZERO)
	_rotors.append(band)

	# Six deliberately placed readings preserve bilateral balance while keeping
	# the entire +/- 45 degree front sector free for the player-facing facade.
	var calibration_angles := [PI / 3.0, PI * 2.0 / 3.0, PI * 5.0 / 6.0,
		PI * 7.0 / 6.0, PI * 4.0 / 3.0, PI * 5.0 / 3.0]
	for i in calibration_angles.size():
		var angle: float = calibration_angles[i]
		var instrument := Node3D.new()
		instrument.name = "AetherCalibrationNode_%02d" % (i + 1)
		instrument.position = Vector3(cos(angle) * 11.32, 0.0, sin(angle) * 11.32)
		band.add_child(instrument)
		_add_mesh(instrument, _sphere(0.28, 0.52), violet, Vector3.ZERO)
		_add_mesh(instrument, _cylinder(0.42, 0.42, 0.12), brass,
			Vector3(0.0, -0.22, 0.0))


# This is the design move that turns an ordinary castle into the Art Castle:
# its existing central tower becomes a working celestial observatory. The
# crown is deliberately compact and axial so it strengthens the silhouette
# instead of covering the imported red roofs or becoming a separate building.
func _build_astral_observatory_crown() -> void:
	var crown := Node3D.new()
	crown.name = "AstralObservatoryCrown"
	# Source mesh inspection gives a 3.98 local-Y maximum; with the castle's 10x
	# scene scale and the foundation 4.2 m below root, the flag reaches ~44.0 m
	# in this coordinate space. Seat the crown just above it so the new identity
	# is visible in the skyline rather than hidden inside the imported roof.
	crown.position = Vector3(0.0, 44.5, 0.0)
	crown.set_meta("collision_policy", "visual_only_roof_observatory")
	_foundation.add_child(crown)

	var stone := _ink_material()
	var brass := _brass_material()
	var cyan := _glow_material(Color("64dcff"))
	var violet := _glow_material(Color("c58dff"))

	var drum := _add_mesh(crown, _cylinder(3.34, 3.6, 0.42), stone,
		Vector3(0.0, -0.34, 0.0))
	drum.name = "ObservatoryDrum"
	var brass_halo := _add_mesh(crown, _torus(3.42, 3.72), brass, Vector3.ZERO)
	brass_halo.name = "ObservatoryBrassHalo"
	var lumen_halo := _add_mesh(crown, _torus(3.06, 3.20), cyan,
		Vector3(0.0, 0.14, 0.0))
	lumen_halo.name = "ObservatoryLumenHalo"

	for i in 4:
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var fin := Node3D.new()
		fin.name = "CrownAstralFin_%d" % (i + 1)
		# These tall fins physically stitch the halo back into the conical roof.
		# They are the crown's four load-bearing telescope yokes, not little
		# decorative posts floating underneath a ring.
		fin.position = Vector3(cos(angle) * 3.46, 0.45, sin(angle) * 3.46)
		fin.rotation.y = -angle
		crown.add_child(fin)
		_add_mesh(fin, _box(Vector3(0.42, 5.2, 0.92)), brass, Vector3.ZERO)
		_add_mesh(fin, _box(Vector3(0.14, 4.36, 0.18)), cyan,
			Vector3(0.24, 0.06, 0.0))
		_add_mesh(fin, _sphere(0.32, 0.68), violet, Vector3(0.0, 2.78, 0.0))

	var lens := Node3D.new()
	lens.name = "CrownLumenLens"
	lens.position = Vector3(0.0, 2.35, 0.0)
	crown.add_child(lens)
	_add_mesh(lens, _sphere(1.0, 1.84), cyan, Vector3.ZERO)
	_add_mesh(lens, _torus(1.22, 1.42), brass, Vector3.ZERO,
		Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0))
	var lens_light := OmniLight3D.new()
	lens_light.name = "CrownLumenLight"
	lens_light.light_color = Color("a5eaff")
	lens_light.light_energy = 0.9
	lens_light.omni_range = 16.0
	lens_light.shadow_enabled = false
	lens.add_child(lens_light)


# The reference artwork's identity comes from one readable astronomical
# machine woven through the castle silhouette, rather than many unrelated
# glowing props.  This whole assembly is visual-only and sits behind / outboard
# of the real entrance axis: the authored stair, court and door keep sole
# ownership of gameplay collision.
func _build_reference_astral_machine() -> void:
	var machine := Node3D.new()
	machine.name = "ReferenceAstralMachine"
	machine.set_meta("collision_policy", "visual_only_no_static_bodies")
	machine.set_meta("mesh_budget", 100)
	machine.set_meta("light_budget", 2)
	_foundation.add_child(machine)

	var stone := _ink_material()
	var brass := _brass_material()
	var cyan := _glow_material(Color("55e6ff"))
	var violet := _glow_material(Color("d68cff"))
	# The reference machine needs a stable cyan/violet material hierarchy even
	# before the journey awakens. Other citadel lights remain stage-driven.
	_light_materials.erase(cyan)
	_light_materials.erase(violet)
	cyan.emission_energy_multiplier = 0.86
	violet.emission_energy_multiplier = 0.72
	var panel_blue := StandardMaterial3D.new()
	panel_blue.albedo_color = Color("243c68")
	panel_blue.metallic = 0.68
	panel_blue.roughness = 0.38
	panel_blue.emission_enabled = true
	panel_blue.emission = Color("162c55")
	panel_blue.emission_energy_multiplier = 0.28

	# A 28 m measuring spire establishes the reference's dramatic vertical
	# ruler.  It is deliberately offset to the rear-west of the door and has a
	# deep, narrow section so it reads as architecture in side views as well as
	# a flat sign from the approach.
	var spire := Node3D.new()
	spire.name = "AetherMeasureSpire"
	spire.position = Vector3(-5.2, 20.0, 6.4)
	machine.add_child(spire)
	var spire_stone := stone.duplicate() as StandardMaterial3D
	spire_stone.albedo_color = Color("46587e")
	spire_stone.roughness = 0.55
	var monolith := _add_mesh(spire, _box(Vector3(4.6, 26.0, 4.2)), spire_stone,
		Vector3.ZERO)
	monolith.name = "AetherMeasureMonolith"
	var measure_face := _add_mesh(spire, _box(Vector3(4.18, 23.8, 0.18)), panel_blue,
		Vector3(0.0, 0.0, 2.14))
	measure_face.name = "AetherMeasureLayeredFace"
	for edge_index in 4:
		var edge_y := -9.4 + float(edge_index) * 6.25
		var edge := _add_mesh(spire, _box(Vector3(5.0, 0.42, 4.6)), brass,
			Vector3(0.0, edge_y, 0.0))
		edge.name = "AetherSpireBrassRail_%02d" % (edge_index + 1)
	for channel_index in 3:
		var channel := _add_mesh(spire,
			_box(Vector3(0.44, 18.0 - channel_index * 2.4, 0.30)), cyan,
			Vector3(-1.3 + channel_index * 1.3, -0.8 + channel_index * 0.7, 2.24))
		channel.name = "AetherSpireCyanChannel_%02d" % (channel_index + 1)
	var spire_base := _add_mesh(spire, _box(Vector3(5.6, 1.2, 5.2)), brass,
		Vector3(0.0, -13.55, 0.0))
	spire_base.name = "AetherSpireFoot"
	var spire_cap := _add_mesh(spire, _cylinder(1.5, 1.05, 1.5), brass,
		Vector3(0.0, 13.75, 0.0))
	spire_cap.name = "AetherSpireCrown"
	_add_astral_terminal(spire, "SpireTerminal", Vector3(0.0, 15.1, 0.0), brass, violet, 1.05)

	# The six-metre celestial core is integrated into the existing central tower
	# crown.  Three crossed instrument rings make the sphere read as a working
	# orrery from every approach angle.
	var core := Node3D.new()
	core.name = "CelestialCore"
	core.position = Vector3(0.0, 53.6, 0.0)
	machine.add_child(core)
	var core_glass := cyan.duplicate() as StandardMaterial3D
	core_glass.albedo_color = Color("7fd4f2")
	core_glass.emission = Color("55d9ff")
	core_glass.emission_energy_multiplier = 0.62
	var core_sphere := _add_mesh(core, _sphere(3.0, 6.0), core_glass, Vector3.ZERO)
	core_sphere.name = "CelestialCoreSphere"
	var core_heart := _add_mesh(core, _sphere(1.18, 2.36), violet, Vector3.ZERO)
	core_heart.name = "CelestialCoreHeart"
	for ring_index in 3:
		var ring_rotation: Vector3 = [Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0),
			Vector3(0.0, 0.0, PI * 0.5)][ring_index]
		var core_ring := _add_mesh(core, _torus(4.0, 4.34), brass,
			Vector3.ZERO, Vector3.ONE, ring_rotation)
		core_ring.name = "CelestialCoreRing_%02d" % (ring_index + 1)
	var core_stalk := _add_mesh(core, _cylinder(0.5, 0.85, 5.0), brass,
		Vector3(0.0, -5.6, 0.0))
	core_stalk.name = "CelestialCoreStalk"
	var core_light := OmniLight3D.new()
	core_light.name = "CelestialCoreLight"
	core_light.light_color = Color("9befff")
	core_light.light_energy = 0.45
	core_light.omni_range = 18.0
	core_light.shadow_enabled = false
	core.add_child(core_light)

	# Twin articulated skyline arms frame the tower like enormous telescope
	# yokes.  Every point remains far outside the +/-2.4 m entrance corridor.
	_build_lumen_arm(machine, 1,
		[Vector3(-3.6, 20.0, -3.4), Vector3(-3.0, 42.0, -13.2),
		Vector3(10.0, 31.0, -13.8)], brass, cyan, violet)
	_build_lumen_arm(machine, 2,
		[Vector3(-3.4, 19.0, 3.4), Vector3(-2.0, 38.0, 13.2),
		Vector3(9.0, 29.0, 13.8)], brass, violet, cyan)

	# A single slow archive cube supplies the reference's floating magical data
	# object.  Its six cyan inset faces remain legible during rotation.
	var archive := Node3D.new()
	archive.name = "FloatingArchiveCube"
	archive.position = Vector3(-2.0, 34.5, -8.6)
	archive.rotation_degrees = Vector3(18.0, 22.0, 10.0)
	machine.add_child(archive)
	var archive_body := _add_mesh(archive, _box(Vector3(5.4, 5.4, 5.4)), panel_blue,
		Vector3.ZERO)
	archive_body.name = "ArchiveCubeBody"
	var archive_glow := cyan.duplicate() as StandardMaterial3D
	archive_glow.emission_energy_multiplier = 1.05
	var face_specs := [
		[Vector3(2.76, 0.0, 0.0), Vector3(0.10, 3.6, 3.6)],
		[Vector3(-2.76, 0.0, 0.0), Vector3(0.10, 3.6, 3.6)],
		[Vector3(0.0, 2.76, 0.0), Vector3(3.6, 0.10, 3.6)],
		[Vector3(0.0, -2.76, 0.0), Vector3(3.6, 0.10, 3.6)],
		[Vector3(0.0, 0.0, 2.76), Vector3(3.6, 3.6, 0.10)],
		[Vector3(0.0, 0.0, -2.76), Vector3(3.6, 3.6, 0.10)],
	]
	for face_index in face_specs.size():
		var face := _add_mesh(archive, _box(face_specs[face_index][1]), archive_glow,
			face_specs[face_index][0])
		face.name = "ArchiveLuminousFace_%02d" % (face_index + 1)
	_rotors.append(archive)

	# An ordered script facade turns the rear elevation into a visibly working
	# computational archive.  Four stepped panels, a rune belt and a three-gear
	# train use strong low-poly shapes that remain readable from village scale.
	var script_facade := Node3D.new()
	script_facade.name = "MachineScriptFacade"
	script_facade.position = Vector3(-4.4, 13.0, -5.2)
	script_facade.rotation_degrees.y = -52.0
	machine.add_child(script_facade)
	for panel_index in 4:
		var panel := _add_mesh(script_facade,
			_box(Vector3(5.4 - panel_index * 0.24, 2.6, 0.34)), panel_blue,
			Vector3(0.0, panel_index * 2.35, 0.0))
		panel.name = "MachineScriptPanel_%02d" % (panel_index + 1)
		var script_line := _add_mesh(script_facade,
			_box(Vector3(4.3 - panel_index * 0.22, 0.18, 0.12)), cyan,
			Vector3(0.0, panel_index * 2.35, -0.22))
		script_line.name = "MachineScriptInset_%02d" % (panel_index + 1)
	var rune_belt := _add_mesh(script_facade, _box(Vector3(6.4, 0.62, 0.38)), stone,
		Vector3(0.9, -1.7, 0.0))
	rune_belt.name = "MachineRuneBelt"
	for rune_index in 5:
		var rune := _add_mesh(script_facade, _box(Vector3(0.78, 0.16, 0.12)), cyan,
			Vector3(-1.0 + rune_index * 1.25, -1.7, -0.24), Vector3.ONE,
			Vector3(0.0, 0.0, (-0.24 if rune_index % 2 == 0 else 0.24)))
		rune.name = "MachineRune_%02d" % (rune_index + 1)
	for gear_index in 3:
		_build_facade_gear(script_facade, gear_index + 1,
			Vector3(-1.6 + gear_index * 2.0, 0.1 + gear_index * 1.4, -0.95),
			1.05 - gear_index * 0.12, brass, violet)

	# Small violet terminals distribute magical charge at otherwise mechanical
	# load joints, completing the magic/science grammar without adding lights.
	for terminal_index in 4:
		var terminal_positions := [Vector3(-7.4, 6.6, -5.2),
			Vector3(-5.8, 6.2, 5.6), Vector3(4.8, 20.0, -9.4),
			Vector3(4.2, 18.5, 9.2)]
		_add_astral_terminal(machine, "JointTerminal_%02d" % (terminal_index + 1),
			terminal_positions[terminal_index], brass, violet, 0.48)


func _build_lumen_arm(parent: Node3D, index: int, points: Array,
		outer_material: Material, conductor_material: Material,
		terminal_material: Material) -> void:
	var arm := Node3D.new()
	arm.name = "LumenArm_%02d" % index
	parent.add_child(arm)
	for segment_index in 2:
		var outer := _add_beam_between(arm, points[segment_index],
			points[segment_index + 1], 0.76, outer_material)
		outer.name = "LumenArmOuterBeam_%02d_%02d" % [index, segment_index + 1]
		var conductor_offset := Vector3(0.0, 0.0,
			0.43 if (points[segment_index] as Vector3).z >= 0.0 else -0.43)
		var conductor := _add_beam_between(arm,
			(points[segment_index] as Vector3) + conductor_offset,
			(points[segment_index + 1] as Vector3) + conductor_offset,
			0.16, conductor_material)
		conductor.name = "LumenArmConductor_%02d_%02d" % [index, segment_index + 1]
		var paired_from := (points[segment_index] as Vector3) + Vector3.DOWN * 0.72
		var paired_to := (points[segment_index + 1] as Vector3) + Vector3.DOWN * 0.72
		var paired_rail := _add_beam_between(arm, paired_from, paired_to, 0.32,
			outer_material)
		paired_rail.name = "LumenArmPairedRail_%02d_%02d" % [index, segment_index + 1]
	var truss_chord := _add_beam_between(arm, points[0], points[2], 0.34,
		outer_material)
	truss_chord.name = "LumenArmTrussChord_%02d" % index
	for joint_index in points.size():
		_add_astral_terminal(arm, "LumenArmJoint_%02d_%02d" % [index, joint_index + 1],
			points[joint_index], outer_material, terminal_material,
			0.76 if joint_index == 1 else (0.86 if joint_index == 0 else 0.54))


func _add_astral_terminal(parent: Node3D, terminal_name: String, position: Vector3,
		collar_material: Material, crystal_material: Material, radius: float) -> Node3D:
	var terminal := Node3D.new()
	terminal.name = terminal_name
	terminal.position = position
	parent.add_child(terminal)
	var collar := _add_mesh(terminal, _cylinder(radius * 0.82, radius, radius * 0.45),
		collar_material, Vector3(0.0, -radius * 0.44, 0.0))
	collar.name = "%s_Collar" % terminal_name
	var crystal := _add_mesh(terminal, _sphere(radius, radius * 2.4),
		crystal_material, Vector3(0.0, radius * 0.62, 0.0))
	crystal.name = "%s_Crystal" % terminal_name
	return terminal


func _add_beam_between(parent: Node3D, from: Vector3, to: Vector3,
		thickness: float, material: Material) -> MeshInstance3D:
	var delta := to - from
	var beam := _add_mesh(parent, _box(Vector3(thickness, thickness, delta.length())),
		material, from.lerp(to, 0.5))
	beam.basis = Basis.looking_at(delta.normalized(), Vector3.UP)
	return beam


func _build_facade_gear(parent: Node3D, index: int, position: Vector3,
		radius: float, brass: Material, glow: Material) -> void:
	var gear := Node3D.new()
	gear.name = "MachineFacadeGear_%02d" % index
	gear.position = position
	gear.rotation.x = PI * 0.5
	parent.add_child(gear)
	var hub := _add_mesh(gear, _cylinder(radius * 0.34, radius * 0.34, 0.42),
		glow, Vector3.ZERO)
	hub.name = "MachineGearHub_%02d" % index
	var wheel := _add_mesh(gear, _torus(radius * 0.56, radius * 0.78), brass,
		Vector3.ZERO, Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0))
	wheel.name = "MachineGearWheel_%02d" % index
	for tooth_index in 6:
		var angle := TAU * float(tooth_index) / 6.0
		var tooth := _add_mesh(gear,
			_box(Vector3(radius * 0.38, radius * 0.22, 0.46)), brass,
			Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), Vector3.ONE,
			Vector3(0.0, -angle, 0.0))
		tooth.name = "MachineGearTooth_%02d_%02d" % [index, tooth_index + 1]


func _add_foundation_support(name: String, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.position = position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_foundation.add_child(body)


# Preserve the imported albedo texture in shadow by reusing it as a very low
# emission texture. Direct sunlight still supplies shape; this only prevents the
# castle from collapsing into a single mauve silhouette against the bright sky.
func _brighten_castle_materials(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_node := child as MeshInstance3D
			if mesh_node.mesh != null:
				for surface in mesh_node.mesh.get_surface_count():
					var source := mesh_node.get_active_material(surface)
					if source is StandardMaterial3D:
						var material := source.duplicate() as StandardMaterial3D
						material.emission_enabled = true
						material.emission = Color(0.34, 0.31, 0.29)
						material.emission_energy_multiplier = 0.13
						if material.albedo_texture != null:
							material.emission_texture = material.albedo_texture
						mesh_node.set_surface_override_material(surface, material)
		_brighten_castle_materials(child)

func _build_citadel_rig() -> void:
	var rig := Node3D.new()
	rig.name = "LumenEngineRig"
	_castle.add_child(rig)

	# The undercarriage gives the authored castle a singular identity: an
	# observatory, a power plant, and a sanctuary in the same silhouette.
	var engine := Node3D.new()
	engine.name = "Heart_Engine"
	engine.position = Vector3(0.0, -0.58, 0.0)
	rig.add_child(engine)
	_add_mesh(engine, _sphere(0.62, 1.12), _glow_material(STAGE_COLOURS[0]),
		Vector3.ZERO, Vector3(1.0, 0.62, 1.0))
	_add_mesh(engine, _cylinder(0.88, 0.88, 0.18), _brass_material(),
		Vector3(0.0, -0.23, 0.0))
	_add_mesh(engine, _torus(0.34, 0.76), _brass_material(),
		Vector3(0.0, 0.02, 0.0), Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0))

	_citadel_lamp = OmniLight3D.new()
	_citadel_lamp.position = Vector3(0.0, -0.2, 0.0)
	_citadel_lamp.omni_range = 18.0
	_citadel_lamp.shadow_enabled = false
	engine.add_child(_citadel_lamp)

	# Four articulated stabilisers read as a travelling machine, not a static
	# fantasy prop. They fold outward gently beneath the existing castle.
	for i in range(4):
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var leg := Node3D.new()
		leg.name = "Stabiliser_%d" % (i + 1)
		leg.position = Vector3(cos(angle) * 0.78, -0.42, sin(angle) * 0.78)
		leg.rotation.y = -angle
		rig.add_child(leg)
		_add_mesh(leg, _box(Vector3(0.17, 0.72, 0.18)), _brass_material(),
			Vector3(0.0, -0.35, 0.34), Vector3.ONE, Vector3(0.48, 0.0, 0.0))
		_add_mesh(leg, _box(Vector3(0.34, 0.13, 0.46)), _ink_material(),
			Vector3(0.0, -0.78, 0.62))

	# Three orbital instruments visibly turn. Their motion is intentionally
	# modest: a child-focused hub should feel wonderous, never frantic.
	for i in range(3):
		var rotor := Node3D.new()
		rotor.name = "Orbit_Instrument_%d" % (i + 1)
		rotor.position = Vector3(0.0, 0.95 + i * 0.25, 0.0)
		rotor.rotation_degrees = Vector3(28.0 + i * 19.0, i * 58.0, 0.0)
		rig.add_child(rotor)
		_add_mesh(rotor, _torus(0.48 + i * 0.14, 0.53 + i * 0.14), _brass_material(), Vector3.ZERO)
		var bead_position := Vector3(0.54 + i * 0.14, 0.0, 0.0)
		_add_mesh(rotor, _sphere(0.1, 0.1), _glow_material(STAGE_COLOURS[0]), bead_position)
		_rotors.append(rotor)

	# The castle is imported at 10x scale. Counter-scale its physical plaque so
	# it reads as entrance signage instead of a giant HUD title across the sky.
	var plaque := _add_title(rig, "LUMEN CITADEL", Vector3(0.0, 2.2, 0.0),
		Color("ffe5a1"), 34)
	plaque.scale = Vector3.ONE * 0.1


# --- Living map ------------------------------------------------------

func _build_skyway() -> void:
	var map := Node3D.new()
	map.name = "SkywayMap"
	get_parent().add_child(map)

	# A small, physical constellation is more useful than a full-screen map:
	# it literally connects the sleeping citadel to the first kingdom.
	var route := [
		Vector3(-28.0, 42.0, 22.0),
		Vector3(5.0, 39.0, 5.0),
		Vector3(35.0, 33.0, -20.0),
		Vector3(65.0, 27.0, -53.0),
		THOUGHTS_PORTAL + Vector3(0.0, 7.0, 0.0),
	]

	for i in route.size():
		var point: Vector3 = route[i]
		var star := MeshInstance3D.new()
		star.name = "Skyway_Star_%d" % (i + 1)
		star.mesh = _sphere(0.42 if i == route.size() - 1 else 0.22,
			0.42 if i == route.size() - 1 else 0.22)
		star.material_override = _glow_material(STAGE_COLOURS[0])
		star.position = point
		map.add_child(star)

		var lamp := OmniLight3D.new()
		lamp.position = point
		lamp.omni_range = 7.5
		lamp.light_energy = 0.8
		lamp.shadow_enabled = false
		map.add_child(lamp)
		_waypoint_lights.append(lamp)

		if i > 0:
			_add_route_segment(map, route[i - 1], point)

	var destination := Node3D.new()
	destination.name = "MindSparkWaypoint"
	destination.position = THOUGHTS_PORTAL + Vector3(0.0, 8.3, 0.0)
	map.add_child(destination)
	_add_mesh(destination, _torus(0.92, 1.02), _glow_material(STAGE_COLOURS[1]), Vector3.ZERO)
	_add_title(destination, "MIND SPARK KINGDOM", Vector3(0.0, 1.25, 0.0), Color("b9dfff"), 36)
	_add_title(destination, "Begin with one thought", Vector3(0.0, 0.78, 0.0), Color("eff7ff"), 22)


func _add_route_segment(parent: Node3D, from: Vector3, to: Vector3) -> void:
	# Long emissive cylinders crossed the camera as bright white cables. A
	# constellation should be read as points the eye completes, so the route is
	# now a restrained sequence of floating brass-and-blue beads.
	const BEADS := 7
	var bead_material := _glow_material(Color("789dcc"))
	for bead_index in BEADS:
		var t := (float(bead_index) + 1.0) / float(BEADS + 1)
		var bead := MeshInstance3D.new()
		bead.name = "Skyway_Bead"
		bead.mesh = _sphere(0.08, 0.08)
		bead.material_override = bead_material
		bead.position = from.lerp(to, t)
		bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Readable unique names make the generated route inspectable in Godot and
		# allow regression tests to count every bead rather than anonymous nodes.
		parent.add_child(bead, true)


# --- Tiny mesh/material helpers -------------------------------------

func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, position: Vector3,
		scale := Vector3.ONE, rotation := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = position
	part.scale = scale
	part.rotation = rotation
	parent.add_child(part)
	return part


func _add_title(parent: Node3D, title: String, position: Vector3, colour: Color,
		size: int) -> Label3D:
	var label := Label3D.new()
	label.text = title
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.font_size = size
	label.outline_size = 5
	label.modulate = colour
	label.pixel_size = 0.008
	parent.add_child(label)
	return label


func _glow_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 0.45
	material.metallic = 0.18
	material.roughness = 0.26
	_light_materials.append(material)
	return material


func _brass_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = BRASS
	material.metallic = 0.9
	material.roughness = 0.31
	return material


func _ink_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = INK
	material.metallic = 0.55
	material.roughness = 0.48
	return material


func _sphere(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


func _cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 12
	return mesh


func _torus(inner_radius: float, outer_radius: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 12
	mesh.ring_segments = 8
	return mesh


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _current_stage() -> int:
	var js := get_node_or_null("/root/JourneyState")
	return clampi(js.stage, 0, STAGE_COLOURS.size() - 1) if js != null else 0
