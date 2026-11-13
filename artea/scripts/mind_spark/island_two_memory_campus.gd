extends RefCounted

## Island Two turns the two overlapping legacy districts into one readable
## Evidence Observatory. Revision 04 preserves the complete useful older
## architecture as a heritage layer instead of replacing the island with sparse
## quest courts. Only components that physically or visually duplicate the new
## route are retired.

const Bricks := preload("res://scripts/altar/AltarParts.gd")

# Canonical Island Two placement contract. Coordinates are local to the named
# gameplay district; approach is the point from which the player operates the
# station. Keeping this in one table prevents the world builder, court builder
# and quest guidance from drifting into different layouts.
const STATION_LAYOUT := {
	"world_one.evidence_scanner": {
		"zone":"03_constellation_court", "position":Vector3(-48,4,-10),
		"approach":Vector3(-60,4,-10), "order":1, "chapter":"evidence",
	},
	"world_one.memory_board": {
		"zone":"03_constellation_court", "position":Vector3(0,4,10),
		"approach":Vector3(-12,4,10), "order":2, "chapter":"evidence",
	},
	"world_one.focus_bell": {
		"zone":"02_living_network_forest", "position":Vector3(72,.05,-74),
		"approach":Vector3(61,.05,-70), "order":0, "chapter":"island_one_support",
	},
	"world_one.logic_gate": {
		"zone":"03_constellation_court", "position":Vector3(58,4,6),
		"approach":Vector3(46,4,6), "order":3, "chapter":"evidence",
	},
	"world_one.perspective_lens": {
		"zone":"04_hope_path_ridge", "position":Vector3(-24,3,6),
		"approach":Vector3(-36,3,6), "order":4, "chapter":"hope",
	},
	"world_one.truth_bridge": {
		"zone":"04_hope_path_ridge", "position":Vector3(20,3,-12),
		"approach":Vector3(28,3,-2), "order":5, "chapter":"hope",
	},
}

static func apply(world: MindSparkWorldOne) -> void:
	if world.has_node("IslandTwoMemoryCampus"):
		return
	var geometry := world.get_node("WorldOneGeometry") as Node3D
	var gate := geometry.get_node("SavedQuestProgressionGates/QuestGate_2") as AnimatableBody3D
	var zones: Dictionary = world.get("_zone_nodes")
	var constellation := zones["03_constellation_court"] as Node3D
	var hope := zones["04_hope_path_ridge"] as Node3D
	var campus := Node3D.new()
	campus.name = "IslandTwoMemoryCampus"
	campus.set_meta("preserve_authored_nodes", true)
	campus.set_meta("physical_island", 2)
	# The observatory and Hope district form one compact composition. Wider
	# spatial cells consolidate matching inert masonry without touching station
	# controls, collision, saved state, or the independently animated bays.
	campus.set_meta("static_render_merge_cell_size", 384.0)
	campus.set_meta("style", "heavenly evidence observatory; ivory, brass, teal glass and restrained lavender")
	campus.set_meta("story_sequence", ["Observe evidence", "Name the prediction", "Choose a useful next step", "Open the Hope Archive"])
	campus.set_meta("architectural_rules", [
		"one shared promenade rather than a duplicate bridge",
		"gate sits on the actual district threshold",
		"each puzzle object has a readable research bay",
		"all bridge edges receive physical rails",
	])
	world.add_child(campus)
	_relocate_quest_stations(world, zones)
	_consolidate_legacy_gates(world, constellation)
	_restore_legacy_heritage_layer(world, constellation, hope)
	_hide_legacy_internal_bridge(geometry)
	_apply_station_finish_and_collision(world)
	_build_memory_gate(world, gate)
	_build_memory_promenade(world, campus, constellation, hope, gate)
	_build_evidence_observatory(world, campus, constellation)
	_build_evidence_aether_bus(world, campus, constellation, gate)
	_build_station_courts(world, campus)
	_build_echo_seed_receiver(world, campus)
	_build_hope_optics_gallery(world, campus, hope)
	_build_hope_materialisation_conduit(world, campus, hope)
	_build_island_two_landscaping(world, campus, constellation, hope)
	_relocate_island_two_trees_from_gateways(world, campus, constellation, hope)
	_build_story_guidance(world, campus, constellation, hope, gate)
	_build_guard_court(world,campus,hope)
	_build_chapter_lighting(world, campus, constellation, hope)
	var garden := Node3D.new()
	garden.set_script(preload("res://scripts/mind_spark/unfinished_light_garden.gd"))
	world.add_child(garden)
	garden.call("build", world)
	# The live projector below replaces and purges the garden script's only
	# animated visual branch. Its remaining conservatory, court and planting are
	# static architecture and may be spatially batched while this presenter node
	# continues to synchronize story state.
	garden.set_meta("allow_static_render_batching", true)
	garden.set_meta("physical_island", 2)
	garden.set_meta("static_render_merge_cell_size", 384.0)
	# The conservatory replaces this earlier combat court. Keeping its hidden
	# masonry solid left invisible pillars and a reward plinth in the player route.
	_retire_assembly(campus.get_node("EliteGuardianCourt"),
		"GardenOfUnfinishedLight/ConservatoryOfPossibleTomorrow")
	for station in world.get_quest_objects():
		if station.save_id != "world_one.evidence_scanner": continue
		_retire_assembly(campus.get_node("EvidenceReadingCourt"), "ProductionInspectionBay")
		_retire_assembly(garden.get_node("InvestigationBackdrop_0"), "ProductionInspectionBay")
		var bay := Node3D.new()
		bay.set_script(preload("res://scripts/mind_spark/inspection_bay_presenter.gd"))
		station.add_child(bay)
		bay.call("configure", station, world)
		_build_production_station_marker(world, station, "EVIDENCE", 0)
	for station in world.get_quest_objects():
		if station.save_id != "world_one.memory_board": continue
		_retire_assembly(campus.get_node("MemoryWeavingCourt"), "ProductionRecorderBay")
		_retire_assembly(garden.get_node("InvestigationBackdrop_1"), "ProductionRecorderBay")
		var recorder := Node3D.new()
		recorder.set_script(preload("res://scripts/mind_spark/recorder_bay_presenter.gd"))
		station.add_child(recorder)
		recorder.call("configure", station, world)
		_build_production_station_marker(world, station, "MEMORY", 1)
	world.call("_repair_island_one_legacy_openings", geometry, 2)
	for station in world.get_quest_objects():
		if station.save_id != "world_one.logic_gate": continue
		_retire_assembly(campus.get_node("ArchiveLogicCourt"), "ProductionTesterBay")
		_retire_assembly(garden.get_node("InvestigationBackdrop_2"), "ProductionTesterBay")
		var tester := Node3D.new()
		tester.set_script(preload("res://scripts/mind_spark/tester_bay_presenter.gd"))
		station.add_child(tester)
		tester.call("configure",station,world)
		_build_production_station_marker(world, station, "LOGIC", 3)
	_build_departure_threshold(world, geometry)
	for station in world.get_quest_objects():
		if station.save_id != "world_one.perspective_lens": continue
		_retire_assembly(campus.get_node("PerspectiveGallery"), "ProductionPerspectiveBay")
		var viewer := Node3D.new()
		viewer.set_script(preload("res://scripts/mind_spark/perspective_bay_presenter.gd"))
		station.add_child(viewer)
		viewer.call("configure",station,world)
		_build_production_station_marker(world, station, "PERSPECTIVE", 4)
	_refine_external_bridges(world, geometry)
	for station in world.get_quest_objects():
		if station.save_id != "world_one.truth_bridge": continue
		_retire_assembly(campus.get_node("TruthMaterialisationCourt"), "ProductionLivingProjector")
		_retire_assembly(garden.get_node("ConservatoryOfPossibleTomorrow/LivingProjectionMachine"), "ProductionLivingProjector")
		var projector := Node3D.new()
		projector.set_script(preload("res://scripts/mind_spark/projector_presenter.gd"))
		station.add_child(projector)
		projector.call("configure",station,world)
		_build_production_station_marker(world, station, "TRUTH", 5)
	world.set_meta("island_two_environment_style", "heavenly research observatory")
	world.set_meta("island_two_layout_revision", "observatory_of_understanding_05_heavenly_hierarchy")
	world.set_meta("island_two_style_alignment", "island_one_shared_grammar_v05_heavenly_hierarchy")


static func _build_departure_threshold(world: MindSparkWorldOne, geometry: Node3D) -> void:
	var gate := geometry.get_node("SavedQuestProgressionGates/QuestGate_3") as AnimatableBody3D
	# This parent is stationary; only its hinged child bodies are animated.
	# Disable physics-transform synchronization before relocating the landing.
	gate.sync_to_physics = false
	var center := world.get_zone_position("04_hope_path_ridge")
	var onward := world.get_zone_position("05_thought_storm_arena")
	var direction := (onward - center) * Vector3(1, 0, 1)
	direction = direction.normalized()
	gate.position = center + direction * (world.get_zone_radius("04_hope_path_ridge") - 22.0)
	gate.position.y = world.call("_zone_floor_surface_y", center)
	gate.rotation.y = atan2(direction.x, direction.z)
	gate.set_meta("closed_position", gate.position)
	_build_memory_gate(world, gate)
	gate.set_meta("architectural_role", "Island Two departure forecourt; before the bridge to Island Three")
	gate.set_meta("landing_setback", 22.0)
	for label in gate.find_children("*", "Label3D", true, false):
		label.text = "CARRY UNDERSTANDING INTO THE STORM"
	# The existing quest gate ID is retained: saved progress owns this door.
	# Neither a second unlock condition nor a replacement bridge is introduced.


static func _refine_external_bridges(world: MindSparkWorldOne, geometry: Node3D) -> void:
	var mats: Dictionary = world.get("_materials")
	var fittings := Node3D.new()
	fittings.name = "IslandTwoBridgeFittings"
	fittings.set_meta("preserve_authored_nodes", true)
	fittings.set_meta("design_revision", "continuous_ivory_parapet_v3")
	fittings.set_meta("duplicate_joint_piers_removed", true)
	fittings.set_meta("gold_route_handrails_removed", true)
	fittings.set_meta("bridge_joint_sightline_clear", true)
	fittings.set_meta("detached_bridge_ornaments_removed", true)
	fittings.set_meta("decorative_lantern_count", 0)
	fittings.set_meta("island_three_arrival_uses_authored_solid_rails", true)
	geometry.add_child(fittings)
	for route_index in [2, 4]:
		for half in ["A", "B"]:
			var key := "CircuitRoute_%02d_%s" % [route_index, half]
			var deck := geometry.find_child(key, true, false) as MeshInstance3D
			if deck == null: continue
			deck.material_override = mats.sanctum_ivory
			var seam := deck.get_parent().get_node_or_null(key + "CyanSeam") as Node3D
			if seam != null: seam.visible = false
			var assembly := Node3D.new()
			assembly.name = key + "CivicBalustrade"
			fittings.add_child(assembly)
			assembly.global_transform = deck.global_transform
			var length := (deck.mesh as BoxMesh).size.z
			var clear_island_three_arrival: bool = route_index == 4 and half == "B"
			assembly.set_meta("arrival_sightline_clear", clear_island_three_arrival)
			for side in [-1, 1]:
				var old_name := key + ("LeftRail" if side < 0 else "RightRail")
				var old := deck.get_parent().get_node_or_null(old_name) as MeshInstance3D
				if old != null: old.material_override = mats.sanctum_ivory
				# The final authored bridge half already has two collision-backed solid
				# rails. Extra parapet end caps sit directly inside the normal arrival
				# camera and read as detached baskets at the edge of the frame. Let those
				# original ivory rails carry this short threshold without a duplicate
				# cosmetic layer; every earlier bridge half keeps the civic parapet.
				if clear_island_three_arrival:
					continue
				# A low matte parapet reads as one complete bridge edge from the player
				# camera. The former transparent infill plus repeated piers and lanterns
				# became detached wire baskets and floating shadows when viewed edge-on
				# during the Island 3 arrival. Keep the same side clearance and physical
				# safety envelope with one simple collision-backed civic wall.
				world.call("_add_box", assembly, "IvoryParapet%d" % side,
					Vector3(side * 13.3, 3.45, 0), Vector3(.80, 2.5, length),
					mats.sanctum_ivory, true)
				world.call("_add_box", assembly, "IvoryHandrail%d" % side,
					Vector3(side * 13.3, 4.88, 0), Vector3(1.05, .38, length),
					mats.sanctum_ivory)


static func _relocate_quest_stations(world: MindSparkWorldOne, zones: Dictionary) -> void:
	for station in world.get_quest_objects():
		if not STATION_LAYOUT.has(station.save_id):
			continue
		var spec: Dictionary=STATION_LAYOUT[station.save_id]
		var zone := zones[str(spec.zone)] as Node3D
		# All six objects already belong to their corresponding gameplay zone. Use
		# the canonical zone anyway so an accidental legacy alias cannot offset the
		# station into another district.
		if station.get_parent()!=zone:
			station.reparent(zone)
		station.position=spec.position
		var direction: Vector3=(spec.approach as Vector3)-(spec.position as Vector3)
		direction.y=0
		station.rotation.y=atan2(direction.x,direction.z)
		station.set_meta("island_two_route_order",int(spec.order))
		station.set_meta("island_two_chapter",str(spec.chapter))
		station.set_meta("operator_approach_local",spec.approach)
		# These reusable stations are authored with their presentation face on +Z.
		# Godot names +Z BACK, while FORWARD means -Z.
		station.set_meta("front_axis",Vector3.BACK)
		station.set_meta("minimum_operator_apron_m",4.0)
		station.set_meta("canonical_layout",true)


static func _consolidate_legacy_gates(world: MindSparkWorldOne,
		constellation: Node3D) -> void:
	var arrival_arch := constellation.get_node_or_null("FearGate") as Node3D
	if arrival_arch != null:
		# The legacy arch was authored across local X while the bridge enters from
		# local -X. Turn its opening toward the route and centre it on the landing.
		var previous := world.get_zone_position("02_living_network_forest")
		var incoming := previous - constellation.position
		incoming.y = 0.0
		incoming = incoming.normalized()
		arrival_arch.position = incoming * 138.0
		arrival_arch.rotation.y = atan2(incoming.x, incoming.z)
		arrival_arch.scale = Vector3(0.78, 0.78, 0.92)
		arrival_arch.set_meta("architectural_role","Island Two arrival observatory portico")
		arrival_arch.set_meta("former_role","legacy fear gate")
		arrival_arch.set_meta("approach_axis", Vector3.LEFT)
		arrival_arch.set_meta("redesign_reason", "aligned to incoming bridge and crowned as a heavenly science threshold")
		for label in arrival_arch.find_children("*","Label3D",true,false):
			(label as Label3D).text="ISLAND TWO • OBSERVATORY OF UNDERSTANDING"
		_build_heavenly_arrival_portico_details(world, arrival_arch)
	var duplicate := constellation.get_node_or_null("Proof_LogicGate") as Node3D
	if duplicate != null:
		_retire_assembly(duplicate,
			"SavedQuestProgressionGates/QuestGate_2/IslandTwoMemoryGate")


static func _build_heavenly_arrival_portico_details(world: MindSparkWorldOne,
		arrival_arch: Node3D) -> void:
	if arrival_arch.has_node("HeavenlyArrivalPorticoDetails"):
		return
	var mats: Dictionary = world.get("_materials")
	# Retain the collision-bearing legacy masonry, but give it the same material
	# grammar as the new laboratories.
	for structural_name in ["Left", "Right", "Top"]:
		var structural := arrival_arch.get_node_or_null(structural_name) as MeshInstance3D
		if structural != null:
			structural.material_override = mats.sanctum_ivory
	var details := Node3D.new()
	details.name = "HeavenlyArrivalPorticoDetails"
	details.set_meta("reusable_component_family", "heavenly observatory arrival portico")
	details.set_meta("silhouette", "grounded twin piers, shallow sunrise arch and faceted wisdom beacon")
	arrival_arch.add_child(details)
	for side in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		var x := float(side) * 17.0
		world.call("_add_brick", details, "%sLayeredFoot" % side_name,
			Vector3(x, .65, 0), Bricks.build_bevel_box(Vector3(8.0, 1.3, 10.0), .28),
			mats.sanctum_ivory)
		world.call("_add_brick", details, "%sBrassPlinthReveal" % side_name,
			Vector3(x, 1.36, -.35), Bricks.build_bevel_box(Vector3(6.7, .24, 8.7), .09),
			mats.astral_brass)
		world.call("_add_box", details, "%sTealPilasterInlay" % side_name,
			Vector3(x, 24.0, -3.62), Vector3(1.15, 27.0, .18), mats.arrival_glass, false)
		for collar_y in [5.5, 33.8, 45.4]:
			world.call("_add_brick", details,
				"%sPierCollar_%02d" % [side_name, int(collar_y * 10.0)],
				Vector3(x, collar_y, 0),
				Bricks.build_bevel_box(Vector3(7.2, .72, 8.6), .14), mats.sanctum_ivory)
		world.call("_add_sphere", details, "%sWelcomeLantern" % side_name,
			Vector3(x, 47.4, 0), Vector3(.95, 1.35, .95), mats.arrival_glass)
	# A double shallow arch masks the old flat-frame reading from the approach.
	for segment in 20:
		var angle_a := PI - PI * float(segment) / 20.0
		var angle_b := PI - PI * float(segment + 1) / 20.0
		var outer_a := Vector3(cos(angle_a) * 18.4, 43.2 + sin(angle_a) * 9.2, 0)
		var outer_b := Vector3(cos(angle_b) * 18.4, 43.2 + sin(angle_b) * 9.2, 0)
		world.call("_add_cable_between", details,
			"IvorySunriseArch_%02d" % (segment + 1), outer_a, outer_b,
			.72, .72, mats.sanctum_ivory, 12)
		world.call("_add_cable_between", details,
			"BrassSunriseReveal_%02d" % (segment + 1),
			outer_a + Vector3(0, 0, -.72), outer_b + Vector3(0, 0, -.72),
			.16, .16, mats.astral_brass, 8)
	# The crest is a vertical crystal and winged rays, not another decorative ring.
	world.call("_add_brick", details, "WisdomBeacon",
		Vector3(0, 55.0, -.45), Bricks.build_crystal(1.35, 4.8, .34, 8),
		mats.green_glow)
	for side in [-1.0, 1.0]:
		for ray in 3:
			world.call("_add_cable_between", details,
				"BeaconWing_%s_%02d" % ["West" if side < 0.0 else "East", ray + 1],
				Vector3(float(side) * 1.2, 54.6 - ray * .55, -.35),
				Vector3(float(side) * (4.0 + ray * 2.3), 55.8 - ray * 1.35, -.35),
				.17, .10, mats.astral_brass, 8)


static func _restore_legacy_heritage_layer(world: MindSparkWorldOne,
		constellation: Node3D, hope: Node3D) -> void:
	# The older version contained important spatial layers: a civic landmark,
	# garden framing, mature vegetation and memory lights. Revision 02 retired
	# whole assemblies and made the gameplay deck feel unfinished. Revision 04
	# restores every useful legacy environment part while suppressing only the
	# actual oversized rings that compete with the authored quest instruments.
	var memory_nodes := constellation.find_children("MemoryNode_*", "Node3D", true, false)
	for index in memory_nodes.size():
		var memory_node := memory_nodes[index] as Node3D
		_set_heritage_visibility(memory_node, true, "restored archive memory lantern")
		memory_node.scale = Vector3.ONE * 0.65
		memory_node.position.y = 6.5 + float(index % 3) * 1.6
		memory_node.set_meta("heritage_role", "archive memory lantern")
	constellation.set_meta("restrained_memory_lantern_count", memory_nodes.size())
	constellation.set_meta("memory_lantern_design_revision", "eight_compact_archive_lanterns_v1")
	constellation.set_meta("memory_lantern_scale", .65)

	var tree_palette := _build_island_two_tree_palette()
	for grove in constellation.find_children("*DesignedBioTreeGrove", "Node3D", false, false):
		_restore_complete_grove(grove as Node3D, "evidence garden frame", tree_palette)
	for grove in hope.find_children("*DesignedBioTreeGrove", "Node3D", false, false):
		_restore_complete_grove(grove as Node3D, "hope garden frame", tree_palette)
	var upper := hope.get_node_or_null("CelestialHopeUpperDistrict") as Node3D
	if upper != null:
		var pavilion := upper.get_node_or_null("AetherLiftPavilion") as Node3D
		if pavilion != null:
			_restore_assembly(pavilion, "heritage aether lift landmark behind the quest route")
			for pattern in [
				"PavilionOuterGiltFloorRing", "PavilionInnerEnergyFloorRing",
				"AetherLiftHalo", "AetherLiftHaloRay_*",
				"TruthPortal_01", "TruthPortal_02", "TruthPortal_03",
			]:
				for node in pavilion.find_children(pattern, "Node3D", true, false):
					_set_heritage_visibility(node as Node3D, false,
						"oversized ring removed; new Truth Foundry carries this role")
			# Revision 03 used `TruthPortal_*`, which also caught these structural
			# supports. Keep them as a three-bay archive colonnade with real mass.
			for pattern in ["TruthPortalPier_*", "TruthPortalPierInlay"]:
				for node in pavilion.find_children(pattern, "Node3D", true, false):
					_set_heritage_visibility(node as Node3D, true,
						"restored Hall of Hope archive buttress")
			pavilion.set_meta("revision_04_preserved_parts", PackedStringArray([
				"ivory dais", "eight columns", "segmented sunrise canopy",
				"aether lift core", "open canopy ribs", "opal crown",
				"six archive buttresses and brass inlays",
			]))
		var condensers := upper.get_node_or_null("TwinUpperPressureCondenserHouses") as Node3D
		if condensers != null:
			_restore_assembly(condensers,
				"restored twin condenser houses powering the floating foundation")
		var terraces := upper.get_node_or_null("CurvedSunriseGardenTerraces") as Node3D
		if terraces != null:
			_restore_assembly(terraces, "restored civic garden frame")
	for flower in hope.find_children("ThoughtFlower", "Node3D", true, false):
		_set_heritage_visibility(flower as Node3D, true, "restored Hope Path planting")


static func _restore_complete_grove(grove: Node3D, role: String,
		palette: Dictionary) -> void:
	grove.visible = true
	grove.set_meta("heritage_role", role)
	grove.set_meta("revision_04_policy", "all authored mature trees retained")
	var tree_index := 0
	for child in grove.get_children():
		if not child is Node3D:
			continue
		_set_heritage_visibility(child as Node3D, true, "restored mature bio-data tree")
		_apply_island_two_tree_palette(child as Node3D, palette, tree_index)
		tree_index += 1


static func _build_island_two_tree_palette() -> Dictionary:
	return {
		"emerald": _island_two_material(Color("2f7055"), .63, Color("3f936b"), .12),
		"sage": _island_two_material(Color("6c9f72"), .69, Color("8eb78c"), .08),
		"jade": _island_two_material(Color("43866b"), .66, Color("59a17e"), .10),
		"nutrient": _island_two_material(Color("4d9b65"), .42, Color("66c884"), .52),
		"gold_green": _island_two_material(Color("b7a354"), .34, Color("d6ca72"), .38),
		"aqua": _island_two_material(Color("58aaa0"), .30, Color("87d4c4"), .42),
	}


static func _apply_island_two_tree_palette(tree: Node3D, palette: Dictionary,
		variant: int) -> void:
	var canopy_materials := [palette["emerald"], palette["sage"], palette["jade"]]
	tree.set_meta("island_two_palette_override", true)
	tree.set_meta("visual_system",
		"warm emerald canopy + living nutrient fibres + teal data + restrained gold")
	for mesh_node in tree.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		var lower := mesh.name.to_lower()
		if lower.contains("mushroomcap") or lower.contains("crownmushroom"):
			mesh.material_override = canopy_materials[
				(variant + mesh.get_index()) % canopy_materials.size()]
		elif lower.contains("magicfiber"):
			mesh.material_override = palette["gold_green"]
		elif lower.contains("nutrientfiber"):
			mesh.material_override = palette["nutrient"]
		elif lower.contains("crowncrystal"):
			mesh.material_override = palette["aqua"]


static func _island_two_material(base: Color, roughness: float,
		emission := Color.BLACK, emission_energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base
	material.roughness = roughness
	material.metallic = .12 if roughness > .50 else .34
	material.metallic_specular = .58
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material


static func _relocate_island_two_trees_from_gateways(world: MindSparkWorldOne,
		_campus: Node3D, constellation: Node3D, hope: Node3D) -> void:
	var gate := world.get_node(
		"WorldOneGeometry/SavedQuestProgressionGates/QuestGate_2") as Node3D
	var gate_world := world.to_local(gate.global_position)
	var arrival_arch := constellation.get_node("FearGate") as Node3D
	var arrival_world := world.to_local(arrival_arch.global_position)
	var relocation_index := 0
	for zone in [constellation, hope]:
		var safe_radius := 118.0 if zone == constellation else 96.0
		for grove in zone.find_children("*DesignedBioTreeGrove", "Node3D", false, false):
			for candidate in grove.get_children():
				if not candidate is Node3D:
					continue
				var tree := candidate as Node3D
				var tree_world := world.to_local(tree.global_position)
				var memory_distance := Vector2(
					tree_world.x - gate_world.x, tree_world.z - gate_world.z).length()
				var arrival_distance := Vector2(
					tree_world.x - arrival_world.x, tree_world.z - arrival_world.z).length()
				var entry_offset := tree_world - arrival_world
				var inside_entry_sightline := entry_offset.x < 10.0 \
					and entry_offset.x > -90.0 and absf(entry_offset.z) < 30.0
				if memory_distance >= 28.0 and arrival_distance >= 58.0 \
						and not inside_entry_sightline:
					continue
				var direction := Vector2(tree.position.x, tree.position.z)
				if direction.length() < .1:
					direction = Vector2(-1.0, 0.0)
				direction = direction.normalized().rotated(
					(-.65 if relocation_index % 2 == 0 else .65)
					* float(1 + relocation_index / 2))
				tree.position.x = direction.x * safe_radius
				tree.position.z = direction.y * safe_radius
				tree.set_meta("relocated_for_gate_clearance", true)
				tree.set_meta("clearance_radius_m", 58.0)
				tree.set_meta("relocated_from",
					"arrival portico" if arrival_distance < 58.0 or inside_entry_sightline
					else "Memory Gate")
				relocation_index += 1
	gate.set_meta("heritage_tree_clearance_m", 28.0)
	gate.set_meta("relocated_heritage_tree_count", relocation_index)
	arrival_arch.set_meta("heritage_tree_clearance_m", 58.0)
	arrival_arch.set_meta("relocated_heritage_tree_count", relocation_index)


static func _restore_assembly(node: Node3D, role: String) -> void:
	_set_heritage_visibility(node, true, role)
	node.set_meta("restored_from_older_island_two", true)


static func _set_heritage_visibility(node: Node3D, enabled: bool, role: String) -> void:
	node.visible = enabled
	node.set_meta("heritage_role", role)
	node.set_meta("retired_collision_disabled", not enabled)
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 1 if enabled else 0
		(node as CollisionObject3D).collision_mask = 1 if enabled else 0
	for body in node.find_children("*", "CollisionObject3D", true, false):
		(body as CollisionObject3D).collision_layer = 1 if enabled else 0
		(body as CollisionObject3D).collision_mask = 1 if enabled else 0


static func _retire_assembly(node: Node3D, replacement: String) -> void:
	node.visible = false
	node.set_meta("replaced_by", replacement)
	node.set_meta("retired_collision_disabled", true)
	node.set_process(false)
	node.set_physics_process(false)
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for body in node.find_children("*", "CollisionObject3D", true, false):
		(body as CollisionObject3D).collision_layer = 0
		(body as CollisionObject3D).collision_mask = 0
	# These assemblies are compatibility markers after their production
	# replacements are installed. Hiding the old hierarchy still kept every mesh,
	# material and collision resource resident in Web memory. All live stateful
	# visuals now live under their production replacements, so release every
	# retired child immediately.
	var released_children := 0
	for child in node.get_children():
		child.free()
		released_children += 1
	if node is MeshInstance3D:
		(node as MeshInstance3D).mesh = null
	if node is MultiMeshInstance3D:
		(node as MultiMeshInstance3D).multimesh = null
	if node is CollisionShape3D:
		(node as CollisionShape3D).shape = null
	node.set_meta("retired_geometry_purged", true)
	node.set_meta("released_child_count", released_children)


static func _apply_station_finish_and_collision(world: MindSparkWorldOne) -> void:
	var mats: Dictionary = world.get("_materials")
	for station in world.get_quest_objects():
		if not STATION_LAYOUT.has(station.save_id):
			continue
		station.set_meta("finish_family", "warm heavenly research instrument")
		# State meshes keep their authored feedback. Structural pieces receive the
		# same role-based finish as Island One without mutating shared resources.
		for mesh_node in station.find_children("*", "MeshInstance3D", true, false):
			var mesh := mesh_node as MeshInstance3D
			var lower := mesh.name.to_lower()
			if _is_state_mesh_name(lower):
				mesh.set_meta("finish_role", "state_feedback_preserved")
				continue
			if lower.contains("marker_slate"):
				mesh.material_override = mats.quest_teal_enamel
				mesh.set_meta("finish_role", "compact_teal_wayfinding_tablet")
			elif _contains_any(lower, ["brass", "gold", "trim", "band", "rim", "handle", "gear", "axle", "bolt", "rail", "pin"]):
				mesh.material_override = mats.astral_brass
				mesh.set_meta("finish_role", "champagne_brass_mechanism")
			elif _contains_any(lower, ["panel", "recess", "screen", "enamel"]):
				mesh.material_override = mats.bio_gunmetal
				mesh.set_meta("finish_role", "deep_teal_recess")
			else:
				mesh.material_override = mats.sanctum_ivory
				mesh.set_meta("finish_role", "warm_ivory_structure")
		# Interaction areas are sensors, not mass. This simple static body gives the
		# visible cabinet a grounded obstruction while leaving the operator apron free.
		if not station.has_node("IslandTwoStationSolid"):
			var body := StaticBody3D.new()
			body.name = "IslandTwoStationSolid"
			body.set_meta("mass_class", "infinite_static_mass")
			body.set_meta("collision_role", "simplified reachable instrument housing")
			var collision := CollisionShape3D.new()
			collision.name = "HousingCollision"
			collision.position = Vector3(0, .48, 0)
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.36, .96, .82)
			collision.shape = shape
			body.add_child(collision)
			station.add_child(body)


static func _is_state_mesh_name(lower_name: String) -> bool:
	return _contains_any(lower_name, [
		"inactive", "active", "completed", "state", "crystal", "glass",
		"core", "beam", "glyph", "jewel", "energy", "reading", "light",
	])


static func _contains_any(value: String, needles: Array) -> bool:
	for needle in needles:
		if value.contains(str(needle)):
			return true
	return false


static func _hide_legacy_internal_bridge(geometry: Node3D) -> void:
	# Route 03 was a generic two-slab sky bridge placed inside the already fused
	# foundation. Its collision remains as a coplanar safety floor; its duplicate
	# deck, cyan seam, and block rails are replaced by the Memory Promenade.
	for name in [
		"CircuitRoute_03_A", "CircuitRoute_03_B",
		"CircuitRoute_03_ACyanSeam", "CircuitRoute_03_BCyanSeam",
		"CircuitRoute_03_ALeftRail", "CircuitRoute_03_ARightRail",
		"CircuitRoute_03_BLeftRail", "CircuitRoute_03_BRightRail",
	]:
		var node := geometry.get_node_or_null("MainStoryCircuitRoute/" + name) as Node3D
		if node != null:
			node.visible = false
			node.set_meta("replaced_by", "IslandTwoMemoryCampus/MemoryPromenade")
			if name.ends_with("Rail"):
				_retire_assembly(node,"IslandTwoMemoryCampus/MemoryPromenade")
	# The fused foundation has a second, older promenade. Its full-length gold
	# rails continue across both gardens after the new threshold was built. Keep
	# the safety saddle and foundation machinery; retire only duplicate fittings.
	var fused := geometry.get_node_or_null("ThreeFusedSuperIslands/FusedSuperIsland_03_04") as Node3D
	if fused != null:
		for pattern in ["*PromenadeRail","*PromenadeLamp_*","*PromenadeGlow_*","InternalPromenadeInlay","AetherFlowChannel"]:
			for fitting in fused.find_children(pattern,"Node3D",false,false):
				_retire_assembly(fitting,"IslandTwoMemoryCampus/MemoryPromenade")


static func _build_memory_gate(world: MindSparkWorldOne, gate: AnimatableBody3D) -> void:
	var mats: Dictionary = world.get("_materials")
	var old_barrier := gate.get_node_or_null("Barrier") as MeshInstance3D
	if old_barrier != null:
		old_barrier.visible = false
		old_barrier.set_meta("replaced_reason", "opaque violet wall did not express a threshold or opening logic")
	var collision := gate.get_node("CollisionShape3D") as CollisionShape3D
	var collision_shape := collision.shape as BoxShape3D
	collision_shape.size = Vector3(19.0, 13.0, 1.25)
	collision.position = Vector3(0, 6.5, 0)
	gate.set_meta("custom_gate_motion", "island_two_memory_hinges")
	gate.set_meta("architectural_role", "Evidence-to-Hope threshold")
	gate.set_meta("opening_logic", "two solid hinged leaves; sweep pauses on obstruction and resumes when clear")
	var portal := Node3D.new()
	portal.name = "IslandTwoMemoryGate"
	# Every ornament must inherit its leaf transform. Global static batching
	# otherwise leaves bars and seals suspended across the unlocked passage.
	portal.set_meta("preserve_authored_nodes", true)
	portal.set_meta("reusable_parts", PackedStringArray(["pier", "hinge leaf", "arch voussoir", "lantern", "aether panel"]))
	portal.set_meta("gate_finish_revision", "framed_archive_leaves_v2")
	portal.set_meta("cyan_surface_policy", "small inset memory panes only")
	gate.add_child(portal)
	for side in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		var x := float(side) * 10.2
		world.call("_add_brick", portal, "%sFoundation" % side_name, Vector3(x, .55, 0),
			Bricks.build_bevel_box(Vector3(3.7, 1.1, 4.4), .24), mats.sanctum_ivory)
		world.call("_add_brick", portal, "%sPlinth" % side_name, Vector3(x, 1.42, 0),
			Bricks.build_bevel_box(Vector3(2.9, .72, 3.5), .18), mats.sanctum_ivory)
		world.call("_add_tapered_cylinder", portal, "%sFlutedPier" % side_name,
			Vector3(x, 6.55, 0), 1.20, 1.56, 9.6, mats.sanctum_ivory, 18)
		world.call("_add_torus", portal, "%sPierCollar" % side_name, Vector3(x, 3.15, 0),
			1.24, 1.62, mats.astral_brass, Vector3(90, 0, 0))
		world.call("_add_box", portal, "%sAetherInlay" % side_name, Vector3(x, 6.65, -.92),
			Vector3(.34, 5.8, .12), mats.arrival_glass, false)
		world.call("_add_sphere", portal, "%sLanternPearl" % side_name, Vector3(x, 12.0, 0),
			Vector3(.68, .95, .68), mats.arrival_glass)
		var leaf := AnimatableBody3D.new()
		leaf.name = "%sMemoryLeaf" % side_name
		leaf.position = Vector3(float(side) * 8.2, 0, -.16)
		leaf.collision_layer = 1
		leaf.collision_mask = 3
		leaf.sync_to_physics = false
		leaf.set_meta("closed_rotation_y", 0.0)
		leaf.set_meta("open_rotation_y", float(side) * PI * .5)
		leaf.set_meta("hinge_side", side_name)
		portal.add_child(leaf)
		var leaf_offset := -float(side) * 4.1
		var leaf_shape := CollisionShape3D.new()
		leaf_shape.name = "GateLeafCollision"
		var leaf_box := BoxShape3D.new()
		leaf_box.size = Vector3(8.0, 11.0, 1.0)
		leaf_shape.shape = leaf_box
		leaf_shape.position = Vector3(leaf_offset, 6.2, 0)
		leaf.add_child(leaf_shape)
		world.call("_add_brick", leaf, "IvoryLeafFrame", Vector3(leaf_offset, 6.2, 0),
			Bricks.build_bevel_box(Vector3(8.1, 11.7, .48), .16), mats.sanctum_ivory)
		# The route can be approached from either district. Finish both sides of each
		# physical leaf so the closed gate never presents an untextured ivory slab.
		# A full-height cyan sheet dominated the Hope district after the doors opened
		# and read like detached prototype geometry.  The finished door is a dark
		# archive lattice with six individually framed memory-glass panes instead.
		for face in [-1.0, 1.0]:
			var face_name := "Evidence" if face < 0.0 else "Hope"
			world.call("_add_box", leaf, "%sTealMemoryPanel" % face_name,
				Vector3(leaf_offset, 6.15, face * .30),
				Vector3(6.85, 9.80, .10), mats.bio_gunmetal, false)
			for pane_row in 3:
				for pane_column in 2:
					var pane_x := leaf_offset + (-1.62 if pane_column == 0 else 1.62)
					var pane_y := 3.55 + float(pane_row) * 2.62
					var pane := world.call("_add_brick", leaf,
						"%sMemoryGlassPane_%02d" % [face_name, pane_row * 2 + pane_column + 1],
						Vector3(pane_x, pane_y, face * .39),
						Bricks.build_bevel_box(Vector3(2.50, 1.88, .10), .10),
						mats.arrival_glass) as Node3D
					pane.set_meta("decorative_glazing", true)
			for bar_index in 3:
				world.call("_add_box", leaf,
					"%sBrassMemoryBar_%02d" % [face_name, bar_index + 1],
					Vector3(leaf_offset, 3.3 + float(bar_index) * 2.85, face * .40),
					Vector3(6.35, .18, .12), mats.astral_brass, false)
			for stile_index in 3:
				world.call("_add_box", leaf,
					"%sBrassMemoryStile_%02d" % [face_name, stile_index + 1],
					Vector3(leaf_offset - 2.15 + float(stile_index) * 2.15,
						6.15, face * .41),
					Vector3(.14, 9.10, .13), mats.astral_brass, false)
			world.call("_add_cable_between", leaf,
				"%sMemoryWingBraceUpper" % face_name,
				Vector3(leaf_offset - float(side) * 2.8, 3.0, face * .48),
				Vector3(leaf_offset + float(side) * 2.8, 9.4, face * .48),
				.12, .12, mats.astral_brass, 8)
			world.call("_add_cable_between", leaf,
				"%sMemoryWingBraceLower" % face_name,
				Vector3(leaf_offset - float(side) * 2.8, 9.4, face * .48),
				Vector3(leaf_offset + float(side) * 2.8, 3.0, face * .48),
				.12, .12, mats.astral_brass, 8)
			world.call("_add_torus", leaf, "%sMemorySeal" % face_name,
				Vector3(leaf_offset, 6.2, face * .55), .72, 1.05,
				mats.astral_brass, Vector3(90, 0, 0))
			world.call("_add_brick", leaf, "%sMemoryLeafJewel" % face_name,
				Vector3(leaf_offset, 6.2, face * .68),
				Bricks.build_crystal(.44, 1.45, .14, 6), mats.green_glow)
			world.call("_add_torus", leaf, "%sHingeEngine" % face_name,
				Vector3(0, 6.2, face * .48), .72, 1.05,
				mats.astral_brass, Vector3(90, 0, 0))
	for segment in 16:
		var a := PI - PI * float(segment) / 16.0
		var b := PI - PI * float(segment + 1) / 16.0
		var start := Vector3(cos(a) * 10.2, 11.0 + sin(a) * 8.3, 0)
		var finish := Vector3(cos(b) * 10.2, 11.0 + sin(b) * 8.3, 0)
		world.call("_add_cable_between", portal, "IvoryArchVoussoir_%02d" % (segment + 1),
			start, finish, .66, .66, mats.sanctum_ivory, 10)
		if segment % 2 == 0:
			world.call("_add_brick", portal, "GiltArchKey_%02d" % (segment + 1),
				start + Vector3(0, 0, -.48), Bricks.build_bevel_box(Vector3(.52, .68, .22), .06), mats.astral_brass)
	world.call("_add_brick", portal, "ArchiveCrownPediment", Vector3(0, 19.65, .10),
		Bricks.build_bevel_box(Vector3(7.4, .82, 1.55), .16), mats.sanctum_ivory)
	world.call("_add_brick", portal, "ArchiveCrownGiltReveal", Vector3(0, 19.43, -.72),
		Bricks.build_bevel_box(Vector3(6.55, .20, .18), .05), mats.astral_brass)
	world.call("_add_brick", portal, "ArchiveWisdomKeystone", Vector3(0, 20.55, -.55),
		Bricks.build_crystal(.92, 2.7, .22, 8), mats.green_glow)
	for side in [-1.0, 1.0]:
		world.call("_add_cable_between", portal,
			"ArchiveCrownWing_%s" % ("West" if side < 0.0 else "East"),
			Vector3(float(side) * .8, 20.3, -.42),
			Vector3(float(side) * 5.2, 19.5, -.42), .16, .10,
			mats.astral_brass, 8)
	world.call("_add_brick", portal, "MemoryThresholdInset", Vector3(0, .20, -1.1),
		Bricks.build_bevel_box(Vector3(17.8, .12, 3.8), .10), mats.bio_gunmetal)
	world.call("_add_label", portal, "EVIDENCE ARCHIVE  •  OBSERVE, NAME, CHOOSE",
		Vector3(0, 21.4, 0), Color("fff0c9"), 18)
	var motion := Node.new()
	motion.name = "SafeMemoryGateMotion"
	motion.set_script(preload("res://scripts/mind_spark/safe_gate_motion.gd"))
	portal.add_child(motion)
	for side in [-1, 1]:
		var boundary := 40.0
		for zone_id in ["03_constellation_court", "04_hope_path_ridge"]:
			var center := gate.to_local(world.to_global(world.get_zone_position(zone_id)))
			var radius := world.get_zone_radius(zone_id)
			if absf(center.z) < radius:
				boundary = maxf(boundary, side * center.x + sqrt(radius * radius - center.z * center.z) + 1.0)
		var wall_width := boundary - 11.0
		world.call("_add_box", portal, "ThresholdSideWall%d" % side,
			Vector3(side * (11 + wall_width * .5), 3, 0), Vector3(wall_width, 6, 2), mats.sanctum_ivory, true)


static func _build_memory_promenade(world: MindSparkWorldOne, campus: Node3D,
		constellation: Node3D, hope: Node3D, gate: AnimatableBody3D) -> void:
	var mats: Dictionary = world.get("_materials")
	var start_global := constellation.global_position
	var finish_global := hope.global_position
	var flat := Vector3(finish_global.x - start_global.x, 0, finish_global.z - start_global.z).normalized()
	var side := Vector3(flat.z, 0, -flat.x)
	var start := start_global + flat * 63.0
	var finish := finish_global - flat * 51.0
	start.y = gate.global_position.y + .15
	finish.y = start.y
	var length := start.distance_to(finish)
	var middle := start.lerp(finish, .5)
	var yaw := atan2(flat.x, flat.z)
	var bridge := Node3D.new()
	bridge.name = "MemoryPromenade"
	bridge.set_meta("purpose", "continuous protected walk from Evidence Court to Hope Archive")
	bridge.set_meta("deck_width_m", 24.0)
	bridge.set_meta("rail_clearance_m", 1.25)
	bridge.set_meta("replaces", "duplicate CircuitRoute_03 bridge slabs")
	campus.add_child(bridge)
	for section in 3:
		var at := middle + flat * (float(section) - 1.0) * length / 3.0
		world.call("_add_brick", bridge, "IvoryDeckModule_%02d" % (section + 1), world.to_local(at),
			Bricks.build_bevel_box(Vector3(24, .32, length / 3.0 + .45), .12), mats.sanctum_ivory, yaw)
		# Bevel bricks are visual meshes. Back every module with an invisible
		# primitive floor so the production capsule is supported for the full span.
		var deck_support := world.call("_add_box", bridge,
			"IvoryDeckSupport_%02d" % (section + 1), world.to_local(at),
			Vector3(24, .32, length / 3.0 + .45), mats.sanctum_ivory, true, yaw) as MeshInstance3D
		deck_support.visible = false
		world.call("_add_box", bridge, "BrassDeckReveal_%02d" % (section + 1),
			world.to_local(at + Vector3.UP * .22), Vector3(1.18, .08, length / 3.0 - .40), mats.astral_brass, false, yaw)
	# The raised Constellation Dais is 2.4 m above the promenade. Its old vertical
	# rim allowed travel only in the downhill direction. This sloped transition
	# begins at the real dais edge and supports travel in both directions.
	var dais_edge := constellation.global_position + flat * 81.0
	var access_span := 24.0
	var access_finish := dais_edge + flat * access_span
	var deck_surface_y := start.y + .16
	var access_rise := constellation.global_position.y + 2.4 - deck_surface_y
	var access_middle := dais_edge.lerp(access_finish, .5)
	access_middle.y = (constellation.global_position.y + 2.4 + deck_surface_y) * .5
	var access_thickness := .8
	var access_ramp := world.call("_add_box", bridge, "EvidenceDaisAccessRamp",
		world.to_local(access_middle - Vector3.UP * access_thickness * .5),
		Vector3(20.0, access_thickness, sqrt(access_span * access_span + access_rise * access_rise)),
		mats.sanctum_ivory, true, yaw) as MeshInstance3D
	access_ramp.rotation.x = atan2(access_rise, access_span)
	(bridge.get_node("EvidenceDaisAccessRampCollision") as StaticBody3D).rotation = access_ramp.rotation
	# The deck also sat a few centimetres above the Hope floor. Add a short
	# continuation so the controller can enter the promenade on the return trip.
	var hope_surface_y := float(world.call("_zone_floor_surface_y", hope.global_position))
	var hope_access_span := 10.0
	var hope_access_finish := finish + flat * hope_access_span
	var hope_access_rise := deck_surface_y - hope_surface_y
	var hope_access_middle := finish.lerp(hope_access_finish, .5)
	hope_access_middle.y = (deck_surface_y + hope_surface_y) * .5
	var hope_ramp := world.call("_add_box", bridge, "HopeFloorAccessRamp",
		world.to_local(hope_access_middle - Vector3.UP * .20),
		Vector3(20.0, .40, sqrt(hope_access_span * hope_access_span \
			+ hope_access_rise * hope_access_rise)), mats.sanctum_ivory, true, yaw) as MeshInstance3D
	hope_ramp.rotation.x = atan2(hope_access_rise, hope_access_span)
	(bridge.get_node("HopeFloorAccessRampCollision") as StaticBody3D).rotation = hope_ramp.rotation
	for rail_side in [-1.0, 1.0]:
		var rail_start: Vector3 = start + side * rail_side * 11.0 + Vector3.UP * .72
		var rail_finish: Vector3 = finish + side * rail_side * 11.0 + Vector3.UP * .72
		world.call("_add_box", bridge, "PhysicalParapet%s" % rail_side,
			world.to_local(rail_start.lerp(rail_finish, .5) + Vector3.UP * .5),
			Vector3(.6, 2.6, length), mats.sanctum_ivory, true, yaw)
		world.call("_add_cable_between", bridge, "BrassHandrail_%s" % ("West" if rail_side < 0 else "East"),
			world.to_local(rail_start), world.to_local(rail_finish), .14, .14, mats.astral_brass, 10)
		for post_index in 5:
			var post: Vector3 = rail_start.lerp(rail_finish, float(post_index) / 4.0)
			world.call("_add_tapered_cylinder", bridge, "RailPost_%s_%02d" % ["West" if rail_side < 0 else "East", post_index + 1],
				world.to_local(post + Vector3.UP * .65), .12, .18, 1.8, mats.astral_brass, 10)
			if post_index in [0, 2, 4]:
				world.call("_add_sphere", bridge, "RailLight_%s_%02d" % ["West" if rail_side < 0 else "East", post_index + 1],
					world.to_local(post + Vector3.UP * 1.92), Vector3.ONE * .34, mats.arrival_glass)
	var gate_marker := gate.global_position + Vector3.UP * .16
	world.call("_add_brick", bridge, "GateLanding", world.to_local(gate_marker),
		Bricks.build_bevel_box(Vector3(20.4, .40, 7.4), .16), mats.sanctum_ivory, yaw)


static func _build_evidence_observatory(world: MindSparkWorldOne, campus: Node3D,
		constellation: Node3D) -> void:
	var mats: Dictionary = world.get("_materials")
	var observatory := Node3D.new()
	observatory.name = "EvidenceObservatory"
	observatory.position = constellation.position
	observatory.set_meta("architectural_role", "Island Two primary evidence department")
	observatory.set_meta("dominant_landmark", "suspended celestial archive orrery")
	observatory.set_meta("clear_working_aisle_m", 6.0)
	observatory.set_meta("evidence_camera_canopy_clear", true)
	observatory.set_meta("canopy_rib_composition", "alternating_open_sightline_v1")
	observatory.set_meta("reusable_component_families", PackedStringArray([
		"observatory buttress", "rib", "archive spindle", "department sign",
	]))
	campus.add_child(observatory)

	# Short perimeter ribs frame the court without drawing six long beams across
	# the player camera or hiding the five working stations below them.
	var rib_depths := [-34.0, 0.0, 34.0]
	for rib_index in rib_depths.size():
		var z := float(rib_depths[rib_index])
		for side in [-1.0, 1.0]:
			# The east rear bay is the authored entrance to Memory Promenade.
			# A complete buttress assembly here previously stood on the deck
			# centreline and made the Hope district unreachable by the player.
			if side > 0.0 and rib_index == 2:
				continue
			var side_name := "West" if side < 0.0 else "East"
			var x := float(side) * 74.0
			world.call("_add_brick", observatory,
				"%sRibButtressFoot_%02d" % [side_name, rib_index + 1],
				Vector3(x, .38, z), Bricks.build_bevel_box(Vector3(4.2, .76, 5.4), .18),
				mats.sanctum_ivory)
			world.call("_add_cylinder", observatory,
				"%sRibButtress_%02d" % [side_name, rib_index + 1],
				Vector3(x, 6.5, z), 1.05, 11.5, mats.sanctum_ivory, true, 14)
			world.call("_add_torus", observatory,
				"%sRibCollar_%02d" % [side_name, rib_index + 1],
				Vector3(x, 11.9, z), .98, 1.38, mats.astral_brass,
				Vector3(90, 0, 0))
		# Leave the west middle bay open above the Evidence Scanner. Its short rib
		# sat ten metres in front of the interaction camera and rendered as an
		# unexplained ivory wedge across the top of every player-height view. The
		# buttress remains, while alternating west/east ribs retain the archive
		# rhythm without putting trim inside the camera frustum.
		if rib_index != 1:
			world.call("_add_cable_between", observatory,
				"ArchiveCanopyRib_%02d_West" % (rib_index + 1),
				Vector3(-74, 11.9, z), Vector3(-55, 16.0, z),
				.64, .38, mats.sanctum_ivory, 12)
		if rib_index != 2:
			world.call("_add_cable_between", observatory,
				"ArchiveCanopyRib_%02d_East" % (rib_index + 1),
				Vector3(55, 16.0, z), Vector3(74, 11.9, z),
				.38, .64, mats.sanctum_ivory, 12)
		for side in [-1.0, 1.0]:
			if side > 0.0 and rib_index == 2:
				continue
			world.call("_add_brick", observatory,
				"ArchiveAquaKeystone_%02d_%s" % [rib_index + 1, side],
				Vector3(float(side) * 55.0, 16.0, z),
				Bricks.build_bevel_box(Vector3(3.0, .85, 1.6), .16),
				mats.arrival_glass)

	# A suspended landmark explains the chapter at overview scale without becoming
	# another input. Rings are appropriate here because this is an orrery, not one
	# of the six quest-station silhouettes.
	var orrery := Node3D.new()
	orrery.name = "CelestialArchiveOrrery"
	orrery.position = Vector3(0, 19.5, -7.0)
	orrery.set_meta("interactive", false)
	orrery.set_meta("story_role", "visualises observations becoming an ordered model")
	observatory.add_child(orrery)
	world.call("_add_cable_between", orrery, "ArchiveSpindle",
		Vector3(0, -6.8, 0), Vector3(0, 7.0, 0), .34, .20,
		mats.astral_brass, 12)
	for ring_index in 3:
		var ring := world.call("_add_torus", orrery,
			"ArchiveOrbit_%02d" % (ring_index + 1), Vector3.ZERO,
			4.2 + ring_index * 1.55, 4.55 + ring_index * 1.55,
			mats.astral_brass if ring_index != 1 else mats.arrival_glass,
			Vector3(22.0 - ring_index * 18.0, ring_index * 30.0, 62.0)) as Node3D
		ring.set_meta("landmark_only", true)
	world.call("_add_sphere", orrery, "ArchiveKnowledgeCore", Vector3.ZERO,
		Vector3.ONE * 1.45, mats.arrival_glass)
	for anchor_index in 4:
		var angle := TAU * float(anchor_index) / 4.0
		world.call("_add_cable_between", observatory,
			"OrrerySuspension_%02d" % (anchor_index + 1),
			Vector3(sin(angle) * 18.0, 24.0, -7 + cos(angle) * 5.0),
			Vector3(sin(angle) * 5.8, 20.0, -7 + cos(angle) * 2.2),
			.14, .08, mats.astral_brass, 8)

	_build_evidence_synthesis_table(world, observatory)
	_build_department_sign(world, observatory, Vector3(-68, 1.0, -54),
		"EVIDENCE OBSERVATORY\nREAD • CONNECT • VERIFY", 0.18)


static func _build_evidence_synthesis_table(world: MindSparkWorldOne,
		observatory: Node3D) -> void:
	var mats: Dictionary = world.get("_materials")
	var table := Node3D.new()
	table.name = "EvidenceSynthesisTable"
	# The quest machines are spread across the forward half of the court. This
	# table sits behind them and below the orrery, leaving every operator apron
	# and the approach between scanner, recorder and verifier open.
	table.position = Vector3(0, 0, -26)
	table.set_meta("story_role", "three observations become one verified account")
	table.set_meta("clear_operator_approaches", true)
	table.set_meta("design_revision", "low_profile_evidence_tablets_v2")
	table.set_meta("evidence_page_height_m", 2.2)
	observatory.add_child(table)
	world.call("_add_box", table, "CharcoalTableFoot",
		Vector3(0, .32, 0), Vector3(39.0, .64, 16.0),
		mats.bio_gunmetal, true)
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			world.call("_add_box", table,
				"IvoryTableLeg_%s_%s" % [side, end],
				Vector3(float(side) * 18.0, 1.75, float(end) * 7.0),
				Vector3(1.7, 2.9, 1.7), mats.sanctum_ivory, true)
	world.call("_add_box", table, "IvoryWorktop",
		Vector3(0, 3.45, 0), Vector3(42.0, .72, 18.0),
		mats.sanctum_ivory, true)
	world.call("_add_brick", table, "RecessedEvidenceSlate",
		Vector3(0, 3.86, 0),
		Bricks.build_bevel_box(Vector3(37.4, .08, 12.0), .06),
		mats.bio_gunmetal)
	for index in 3:
		var x := float(index - 1) * 12.0
		world.call("_add_brick", table,
			"IvoryEvidenceFrame_%02d" % (index + 1),
			Vector3(x, 4.06, 0),
			Bricks.build_bevel_box(Vector3(9.2, .30, 9.0), .12),
			mats.sanctum_ivory)
		var page := world.call("_add_brick", table,
			"CharcoalEvidencePage_%02d" % (index + 1),
			Vector3(x, 5.35, -1.52),
			Bricks.build_bevel_box(Vector3(4.8, 2.2, .36), .12),
			mats.quest_teal_enamel) as MeshInstance3D
		page.rotation.x = deg_to_rad(-12.0)
		var evidence_signal := world.call("_add_brick", table,
			"EvidenceSignal_%02d" % (index + 1),
			Vector3(x, 5.35, -1.30),
			Bricks.build_bevel_box(Vector3(3.8, 1.15, .08), .04),
			mats.arrival_glass) as MeshInstance3D
		evidence_signal.rotation.x = page.rotation.x
		evidence_signal.visible = false
		world.call("_add_brick", table,
			"IvoryEvidenceHeader_%02d" % (index + 1),
			Vector3(x, 6.52, -1.76),
			Bricks.build_bevel_box(Vector3(5.2, .26, .48), .08),
			mats.sanctum_ivory)
		for glyph_index in 3:
			world.call("_add_brick", table,
				"DormantEvidenceGlyph_%02d_%02d" % [index + 1, glyph_index + 1],
				Vector3(x - .72 + float(glyph_index) * .72, 5.35, -1.27),
				Bricks.build_bevel_box(Vector3(.30, .30, .06), .04),
				mats.arrival_glass)
	var label := world.call("_add_label", table, "OBSERVE  •  CONNECT  •  VERIFY",
		Vector3(0, 5.6, 9.15), Color("fff2d9"), 22) as Label3D
	label.pixel_size = .012
	label.outline_size = 2


static func _build_evidence_aether_bus(world: MindSparkWorldOne, campus: Node3D,
		constellation: Node3D, gate: AnimatableBody3D) -> void:
	var mats: Dictionary = world.get("_materials")
	var bus := Node3D.new()
	bus.name = "EvidenceAetherBus"
	bus.position = constellation.position
	bus.set_meta("source", "Echo Seed Receiver and verified evidence stations")
	bus.set_meta("destination", "Island Two Memory Gate")
	bus.set_meta("reachable_service_policy", "guarded bus; floor feeds are non-solid light")
	campus.add_child(bus)

	for module_index in 7:
		var x := -54.0 + float(module_index) * 18.0
		world.call("_add_brick", bus, "ArchiveBusPlinth_%02d" % (module_index + 1),
			Vector3(x, .38, 31.5), Bricks.build_bevel_box(Vector3(12.8, .76, 3.2), .14),
			mats.sanctum_ivory)
		world.call("_add_brick", bus, "ArchiveBusRecess_%02d" % (module_index + 1),
			Vector3(x, .82, 31.5), Bricks.build_bevel_box(Vector3(10.8, .18, 1.7), .07),
			mats.bio_gunmetal)
		world.call("_add_sphere", bus, "ArchiveBusReading_%02d" % (module_index + 1),
			Vector3(x, 1.18, 31.5), Vector3.ONE * .22, mats.arrival_glass)
	world.call("_add_cable_between", bus, "GuardedEvidenceMain",
		Vector3(-63, 1.15, 31.5), Vector3(63, 1.15, 31.5),
		.30, .30, mats.astral_brass, 10)

	var feed_specs := [
		["Scanner", Vector3(-48, .30, -3), Vector3(-48, .30, 31.5)],
		["Memory", Vector3(0, .30, 17), Vector3(0, .30, 31.5)],
		["Verifier", Vector3(58, .30, 13), Vector3(54, .30, 31.5)],
	]
	for feed in feed_specs:
		var channel := world.call("_add_cable_between", bus,
			"%sFloorLightFeed" % str(feed[0]), feed[1], feed[2],
			.10, .10, mats.arrival_glass, 8) as Node3D
		channel.set_meta("intentionally_non_solid", true)
		channel.set_meta("service_endpoint", str(feed[0]))
	var gate_local := world.to_local(gate.global_position) - constellation.position
	world.call("_add_cable_between", bus, "VerifiedOutputToMemoryGate",
		Vector3(63, 1.15, 31.5), gate_local + Vector3(0, 1.15, 0),
		.24, .16, mats.astral_brass, 10)


static func _build_department_sign(world: MindSparkWorldOne, parent: Node3D,
		at: Vector3, text: String, yaw: float) -> void:
	var mats: Dictionary = world.get("_materials")
	var sign := Node3D.new()
	sign.name = "IslandTwoDepartmentSign"
	sign.position = at
	sign.rotation.y = yaw
	sign.set_meta("collision_role", "solid mounted wayfinding")
	parent.add_child(sign)
	world.call("_add_brick", sign, "SignIvoryFoot", Vector3(0, .32, 0),
		Bricks.build_bevel_box(Vector3(6.8, .64, 2.4), .14), mats.sanctum_ivory)
	world.call("_add_box", sign, "SignBrassPost", Vector3(0, 2.1, 0),
		Vector3(.34, 3.2, .34), mats.astral_brass, true)
	world.call("_add_brick", sign, "SignTealDirectory", Vector3(0, 4.2, 0),
		Bricks.build_bevel_box(Vector3(10.8, 3.1, .42), .12), mats.bio_gunmetal)
	var label := world.call("_add_label", sign, text, Vector3(0, 4.2, .26),
		Color("fff2d9"), 20) as Label3D
	label.pixel_size = .008
	label.outline_size = 2


static func _build_station_courts(world: MindSparkWorldOne, campus: Node3D) -> void:
	var mats: Dictionary = world.get("_materials")
	for spec in [
		["world_one.evidence_scanner", "EvidenceReadingCourt", "EVIDENCE LAB • WHAT HAPPENED?", "READ", 0],
		["world_one.memory_board", "MemoryWeavingCourt", "MEMORY ATELIER • NOTICE → NAME → CHOOSE", "WEAVE", 1],
		["world_one.focus_bell", "FocusBellAlcove", "OPTIONAL SUPPORT • REVEAL THE NEXT STEP", "LISTEN", 2],
		["world_one.logic_gate", "ArchiveLogicCourt", "ARCHIVE ENGINE • VERIFY THE PATTERN", "VERIFY", 3],
		["world_one.perspective_lens", "PerspectiveGallery", "PERSPECTIVE LAB • TURN THE VIEW", "REFRAME", 4],
		["world_one.truth_bridge", "TruthMaterialisationCourt", "TRUTH FOUNDRY • MAKE THE PATH SOLID", "BUILD", 5],
	]:
		var station: QuestObjectBase
		for candidate in world.get_quest_objects():
			if candidate.save_id == str(spec[0]):
				station = candidate
				break
		if station == null:
			continue
		var court := Node3D.new()
		court.name = str(spec[1])
		# This pass is built during the world's _ready construction, before every
		# child has entered the scene tree. Compose the two unrotated zone-local
		# transforms directly instead of reading an unavailable global transform.
		var station_parent := station.get_parent() as Node3D
		court.position = station_parent.position + station.position
		court.set_meta("station", station.save_id)
		court.set_meta("role", "framed non-blocking research court")
		court.set_meta("interaction_verb",str(spec[3]))
		court.set_meta("route_order",int(STATION_LAYOUT[station.save_id].order))
		court.rotation.y=station.rotation.y
		var court_parent := campus
		if station.save_id == "world_one.focus_bell" \
				and world.has_node("IslandOneResearchCampus"):
			court_parent = world.get_node("IslandOneResearchCampus") as Node3D
		court_parent.add_child(court)
		var optional := station.save_id=="world_one.focus_bell"
		var apron_size := Vector3(10.0,.24,8.0) if optional else Vector3(15.0,.24,11.0)
		world.call("_add_brick", court, "IvoryStationApron", Vector3(0,-.18,0),
			Bricks.build_bevel_box(apron_size,.14),mats.sanctum_ivory)
		var recess_size := Vector3(7.4,.07,4.7) if optional else Vector3(11.8,.07,7.1)
		world.call("_add_brick", court, "TealResearchBayRecess", Vector3(0,-.025,-.55),
			Bricks.build_bevel_box(recess_size,.10),mats.bio_gunmetal)
		world.call("_add_brick", court, "TealOperatorInset", Vector3(0,-.02,3.55 if not optional else 2.6),
			Bricks.build_bevel_box(Vector3(5.6,.08,2.0),.10),mats.arrival_glass)
		for side in [-1.0, 1.0]:
			var x := float(side)*(6.7 if not optional else 4.2)
			world.call("_add_brick", court, "InstrumentPier_%s" % side, Vector3(x, 1.45, 2.7),
				Bricks.build_bevel_box(Vector3(1.05, 2.9, 1.05), .12), mats.sanctum_ivory)
			world.call("_add_sphere", court, "InstrumentLight_%s" % side, Vector3(x, 3.10, 2.7),
				Vector3.ONE * .38, mats.arrival_glass)
		world.call("_add_box", court, "BrassReadingRule", Vector3(0, .18, 4.25),
			Vector3(9.8, .08, .20), mats.astral_brass, false)
		var label := world.call("_add_label", court, str(spec[2]), Vector3(0, 5.5, 3.2), Color("fff0c9"), 15) as Label3D
		label.pixel_size = .010
		label.outline_size = 2
		_add_court_emblem(world,court,int(spec[4]),mats)


static func _build_production_station_marker(world: MindSparkWorldOne,
		station: QuestObjectBase, title: String, emblem: int) -> void:
	var mats: Dictionary = world.get("_materials")
	var marker := Node3D.new()
	marker.name = "ProductionStationMarker"
	marker.set_script(preload("res://scripts/mind_spark/island_two_station_marker.gd"))
	marker.set_meta("purpose", "distinct grounded silhouette and state beacon for the live quest instrument")
	marker.set_meta("design_revision", "open_teal_station_marker_v2")
	marker.set_meta("silhouette_profile", [
		"split evidence lens", "stepped memory archive", "unused focus bell",
		"logic roof", "asymmetric perspective fins", "ascending truth bridge"
	][emblem])
	station.add_child(marker)
	for side in [-1.0, 1.0]:
		world.call("_add_box", marker, "IvoryMarkerPier_%s" % side,
			Vector3(float(side) * 5.5, 3.9, -4.8),
			Vector3(.9, 7.8, .9), mats.sanctum_ivory, true)
	world.call("_add_brick", marker, "CharcoalMarkerSlate",
		Vector3(0, 6.0, -4.65),
		Bricks.build_bevel_box(Vector3(6.8, 1.45, .24), .08),
		mats.quest_teal_enamel)
	var label := world.call("_add_label", marker, title,
		Vector3(0, 6.15, -4.02), Color("fff0c9"), 24) as Label3D
	label.pixel_size = .012
	label.outline_size = 2
	_add_court_emblem(world, marker, emblem, mats)
	var emblem_root := marker.get_node("QuestVerbEmblem") as Node3D
	emblem_root.position = Vector3(0, 5.45, -4.36)
	emblem_root.scale = Vector3(1.8, 1.8, 1.8)
	_build_station_marker_crown(world, marker, emblem, mats)
	marker.call("bind", station, mats)


static func _build_station_marker_crown(world: MindSparkWorldOne, marker: Node3D,
		emblem: int, mats: Dictionary) -> void:
	match emblem:
		0: # Evidence: two shutters focus on one raised lens.
			for side in [-1.0, 1.0]:
				var wing := world.call("_add_brick", marker, "EvidenceCrownWing_%s" % side,
					Vector3(float(side) * 3.15, 8.25, -4.8),
					Bricks.build_bevel_box(Vector3(5.2, .62, 1.0), .12),
					mats.sanctum_ivory) as Node3D
				wing.rotation.z = float(side) * -.16
		1: # Memory: three ordered archive cards create a stepped skyline.
			for card_index in 3:
				world.call("_add_brick", marker, "MemoryCrownCard_%02d" % (card_index + 1),
					Vector3((card_index - 1) * 3.25, 8.15 + float(card_index) * .48, -4.8),
					Bricks.build_bevel_box(Vector3(2.65, 1.0 + float(card_index) * .18, .95), .12),
					mats.sanctum_ivory)
		3: # Logic: a peaked proof roof makes the station read as a gate.
			for side in [-1.0, 1.0]:
				var roof := world.call("_add_brick", marker, "LogicCrownSlope_%s" % side,
					Vector3(float(side) * 2.8, 8.55, -4.8),
					Bricks.build_bevel_box(Vector3(6.2, .68, 1.05), .12),
					mats.sanctum_ivory) as Node3D
				roof.rotation.z = float(side) * .25
		4: # Perspective: unequal fins show the same scene from shifted viewpoints.
			for fin_index in 3:
				var fin_height: float = [2.2, 3.5, 1.5][fin_index]
				var fin := world.call("_add_brick", marker,
					"PerspectiveCrownFin_%02d" % (fin_index + 1),
					Vector3(-3.5 + float(fin_index) * 3.5, 8.0 + fin_height * .5, -4.8),
					Bricks.build_bevel_box(Vector3(1.05, fin_height, .95), .12),
					mats.sanctum_ivory) as Node3D
				fin.rotation.z = deg_to_rad(float([-8.0, 0.0, 11.0][fin_index]))
		5: # Truth: three courses rise toward the onward bridge.
			for step_index in 3:
				world.call("_add_brick", marker, "TruthCrownStep_%02d" % (step_index + 1),
					Vector3(-3.5 + float(step_index) * 3.5, 7.9 + float(step_index) * .62, -4.8),
					Bricks.build_bevel_box(Vector3(3.25, .72, 1.0), .12),
					mats.sanctum_ivory)
		_:
			world.call("_add_brick", marker, "IvoryMarkerHeader", Vector3(0, 8.0, -4.8),
				Bricks.build_bevel_box(Vector3(11.8, .8, 1.1), .14), mats.sanctum_ivory)

	# State feedback is inset into the readable slate instead of floating above
	# the architecture. This keeps the crown silhouette clean at player height.
	var beacon_y := 7.92
	world.call("_add_brick", marker, "MarkerStateBeacon", Vector3(0, beacon_y, -4.30),
		Bricks.build_crystal(.52, 1.15, .14, 6), mats.astral_lavender)
	var active_wings := Node3D.new()
	active_wings.name = "ActiveStateWings"
	marker.add_child(active_wings)
	for side in [-1.0, 1.0]:
		world.call("_add_brick", active_wings, "ActiveWing_%s" % side,
			Vector3(float(side) * 1.05, beacon_y - .10, -4.29),
			Bricks.build_bevel_box(Vector3(1.4, .18, .34), .05), mats.arrival_glass)
	active_wings.visible = false
	var completed_wings := Node3D.new()
	completed_wings.name = "CompletedStateWings"
	marker.add_child(completed_wings)
	for side in [-1.0, 1.0]:
		var leaf := world.call("_add_brick", completed_wings, "CompletedLeaf_%s" % side,
			Vector3(float(side) * 1.10, beacon_y - .06, -4.29),
			Bricks.build_bevel_box(Vector3(1.8, .26, .48), .06), mats.green_glow) as Node3D
		leaf.rotation.z = float(side) * .28
	completed_wings.visible = false


static func _add_court_emblem(world: MindSparkWorldOne, court: Node3D,
		emblem: int, mats: Dictionary) -> void:
	var root := Node3D.new()
	root.name="QuestVerbEmblem"
	root.position=Vector3(0,3.6,3.0)
	root.set_meta("editable_component",true)
	court.add_child(root)
	match emblem:
		0: # Evidence: three separate fragments entering one lens.
			for index in 3:
				world.call("_add_brick",root,"EvidenceFragment_%02d"%(index+1),Vector3((index-1)*.62,float(index%2)*.28,0),Bricks.build_bevel_box(Vector3(.42,.72,.18),.06),mats.arrival_glass)
		1: # Memory: an ordered three-card sequence.
			for index in 3:
				world.call("_add_brick",root,"MemoryCard_%02d"%(index+1),Vector3((index-1)*.78,0,0),Bricks.build_bevel_box(Vector3(.58,.82,.18),.06),mats.sanctum_ivory)
				if index<2: world.call("_add_box",root,"MemoryLink_%02d"%(index+1),Vector3(-.39+index*.78,0,.02),Vector3(.22,.10,.12),mats.astral_brass,false)
		2: # Focus: a single calm downward marker.
			world.call("_add_tapered_cylinder",root,"FocusBell",Vector3(0,0,0),.50,.20,.86,mats.astral_brass,12)
		3: # Logic: two verified inputs meet at one key.
			for side in [-1.0,1.0]:
				world.call("_add_box",root,"LogicInput_%s"%side,Vector3(side*.72,.18,0),Vector3(.78,.18,.18),mats.arrival_glass,false,float(side)*.34)
			world.call("_add_sphere",root,"LogicKey",Vector3(0,-.18,0),Vector3.ONE*.34,mats.gold)
		4: # Perspective: offset planes communicate a changed viewpoint.
			for index in 3:
				var plane := world.call("_add_brick",root,"ViewPlane_%02d"%(index+1),Vector3((index-1)*.45,(index-1)*.18,0),Bricks.build_bevel_box(Vector3(.32,1.10,.16),.05),mats.arrival_glass) as Node3D
				plane.rotation.z=deg_to_rad(float(index-1)*14.0)
		5: # Truth: three stable bridge courses, no decorative ring.
			for index in 3:
				world.call("_add_brick",root,"TruthCourse_%02d"%(index+1),Vector3(0,float(index)*.28,0),Bricks.build_bevel_box(Vector3(2.0-float(index)*.35,.18,.32),.05),mats.gold if index==2 else mats.sanctum_ivory)


static func _build_echo_seed_receiver(world: MindSparkWorldOne, campus: Node3D) -> void:
	var mats: Dictionary = world.get("_materials")
	var station: QuestObjectBase
	for candidate in world.get_quest_objects():
		if candidate.save_id == "world_one.evidence_scanner":
			station = candidate
			break
	if station == null:
		return
	var receiver := Node3D.new()
	receiver.name = "EchoSeedArrivalReceiver"
	# Keep this noninteractive story prop in the station's rear side bay. Its old
	# +Z placement sat between the normal camera and the scanner, turning a handoff
	# detail into the largest foreground silhouette in the evidence court.
	var receiver_offset := station.basis * Vector3(-12.0, 0, -5.5)
	receiver.position = (station.get_parent() as Node3D).position + station.position + receiver_offset
	receiver.set_meta("story_role", "receives the Echo Seed sent by Island One and makes the handoff visible")
	receiver.set_meta("gameplay_collision", "clear of the main approach and station interaction radius")
	receiver.set_meta("design_revision", "open_ivory_echo_reliquary_v2")
	campus.add_child(receiver)
	world.call("_add_brick", receiver, "IvoryReceiverPlinth", Vector3(0, .45, 0),
		Bricks.build_bevel_box(Vector3(3.4, .9, 3.4), .18), mats.sanctum_ivory)
	world.call("_add_tapered_cylinder", receiver, "IvoryReceiverPedestal",
		Vector3(0, 1.82, 0), .58, .96, 2.25, mats.sanctum_ivory, 10)
	world.call("_add_cylinder", receiver, "CharcoalReceiverWaist", Vector3(0, 2.78, 0),
		.70, .24, mats.bio_gunmetal, false, 10)
	# Three open arms make the handoff read as a protected civic instrument rather
	# than the former solid brass cone and floating ring. Their footprint stays
	# inside the existing plinth, so the evidence-station approach remains clear.
	for support_index in 3:
		var angle := TAU * float(support_index) / 3.0 + PI / 6.0
		var lower := Vector3(sin(angle) * .52, 2.72, cos(angle) * .52)
		var upper := Vector3(sin(angle) * 1.05, 4.05, cos(angle) * 1.05)
		world.call("_add_cable_between", receiver,
			"IvoryReliquaryArm_%02d" % (support_index + 1), lower, upper,
			.18, .12, mats.sanctum_ivory, 7)
		world.call("_add_brick", receiver,
			"LavenderReliquaryTip_%02d" % (support_index + 1), upper,
			Bricks.build_crystal(.20, .72, .08, 5), mats.sanctum_lavender_glass)
	world.call("_add_cylinder", receiver, "DormantHalo", Vector3(0, 3.92, 0),
		.76, .14, mats.sanctum_ivory, false, 10)
	var invited := world.call("_add_cylinder", receiver, "InvitedHalo", Vector3(0, 3.99, 0),
		.88, .12, mats.arrival_glass, false, 10) as MeshInstance3D
	var seed := world.call("_add_sphere", receiver, "ReceivedEchoSeed", Vector3(0, 4.25, 0),
		Vector3(.62, .82, .62), mats.arrival_glass) as MeshInstance3D
	invited.visible = false
	seed.visible = false
	var label := world.call("_add_label", receiver, "ECHO SEED RECEIVER • DORMANT",
		Vector3(0, 5.72, 0), Color("fff0c9"), 14) as Label3D
	label.name = "ReceiverStateLabel"
	label.pixel_size = .009


static func _build_hope_optics_gallery(world: MindSparkWorldOne, campus: Node3D,
		hope: Node3D) -> void:
	var mats: Dictionary = world.get("_materials")
	var gallery := Node3D.new()
	gallery.name = "HopeOpticsGallery"
	gallery.position = hope.position
	gallery.set_meta("architectural_role", "lighter second chapter and perspective laboratory")
	gallery.set_meta("primary_silhouette", "asymmetric open ribs; no complete decorative route ring")
	gallery.set_meta("clear_route_m", 6.0)
	campus.add_child(gallery)

	# The lens pavilion is intentionally asymmetrical. Its four feet stand behind
	# the Perspective operator line and support three open optical ribs.
	var lens_center := Vector3(-62, 0, -18)
	for support_index in 4:
		var support_offsets := [
			Vector3(-13, 5.5, -11), Vector3(13, 5.5, -11),
			Vector3(-13, 5.5, 11), Vector3(13, 5.5, 11),
		]
		var support_at: Vector3 = lens_center + support_offsets[support_index]
		world.call("_add_brick", gallery, "LensPavilionFoot_%02d" % (support_index + 1),
			support_at - Vector3.UP * 5.0,
			Bricks.build_bevel_box(Vector3(3.0, 1.0, 3.0), .16), mats.sanctum_ivory)
		world.call("_add_cylinder", gallery, "LensPavilionPier_%02d" % (support_index + 1),
			support_at, .72, 9.6, mats.sanctum_ivory, true, 14)
		world.call("_add_torus", gallery, "LensPavilionCollar_%02d" % (support_index + 1),
			support_at + Vector3.UP * 4.45, .70, 1.02, mats.astral_brass,
			Vector3(90, 0, 0))
	for rib_index in 3:
		var z := lens_center.z - 9.0 + float(rib_index) * 9.0
		var apex := lens_center + Vector3(2.5 + rib_index * 1.4, 15.0 + rib_index * 1.2,
			z - lens_center.z)
		world.call("_add_cable_between", gallery,
			"PerspectiveRib_%02d_West" % (rib_index + 1),
			Vector3(lens_center.x - 13, 10.0, z), apex,
			.46, .28, mats.sanctum_ivory, 10)
		world.call("_add_cable_between", gallery,
			"PerspectiveRib_%02d_East" % (rib_index + 1), apex,
			Vector3(lens_center.x + 13, 10.0, z),
			.28, .46, mats.sanctum_ivory, 10)
		var pane := world.call("_add_brick", gallery,
			"PerspectiveSuspendedPane_%02d" % (rib_index + 1),
			lens_center + Vector3(-4.2 + rib_index * 4.2, 11.0 + rib_index * .8, 3.5),
			Bricks.build_bevel_box(Vector3(3.2, 5.8, .22), .10), mats.arrival_glass) as Node3D
		pane.rotation.z = deg_to_rad(-12.0 + rib_index * 14.0)
	world.call("_add_brick", gallery, "PerspectiveSightCrown",
		lens_center + Vector3(3.8, 18.3, 0),
		Bricks.build_crystal(1.15, 3.8, .28, 8), mats.arrival_glass)

	# The Truth Materialiser is a supported foundry frame, not another portal ring.
	# Build the architecture from the station's authored facing direction.  The
	# previous frame sat eight metres toward the operator and its lintel/courses
	# crossed the normal third-person camera.  This rear frame leaves the complete
	# twelve-metre approach apron open while still giving the small instrument a
	# landmark silhouette from the district route.
	var foundry_center := Vector3(20, 0, -12)
	var truth_station: QuestObjectBase
	for candidate in world.get_quest_objects():
		if candidate.save_id == "world_one.truth_bridge":
			truth_station = candidate
			break
	var foundry_yaw := truth_station.rotation.y if truth_station != null else 0.0
	var foundry_front := Vector3.BACK.rotated(Vector3.UP, foundry_yaw)
	var foundry_side := Vector3.RIGHT.rotated(Vector3.UP, foundry_yaw)
	var foundry_back := foundry_center - foundry_front * 8.5
	gallery.set_meta("truth_foundry_revision", "rear_crystalline_frame_v2")
	gallery.set_meta("truth_foundry_clear_operator_apron_m", 12.0)
	for side in [-1.0, 1.0]:
		var pier_at: Vector3 = foundry_back + foundry_side * float(side) * 10.5
		world.call("_add_brick", gallery, "TruthFoundryFoot_%s" % side,
			pier_at + Vector3.UP * .48,
			Bricks.build_bevel_box(Vector3(3.6, .96, 4.2), .16), mats.sanctum_ivory)
		world.call("_add_cylinder", gallery, "TruthFoundryPier_%s" % side,
			pier_at + Vector3.UP * 6.0, .86, 10.4,
			mats.sanctum_ivory, true, 14)
		var pier_inlay := world.call("_add_box", gallery,
			"TruthFoundryPierInlay_%s" % side,
			pier_at + foundry_front * .92 + Vector3.UP * 6.2,
			Vector3(.38, 6.2, .14), mats.astral_brass, false, foundry_yaw) as Node3D
		pier_inlay.set_meta("frame_side", "west" if side < 0.0 else "east")
	var lintel := world.call("_add_brick", gallery, "TruthFoundryLintel",
		foundry_back + Vector3.UP * 11.4,
		Bricks.build_bevel_box(Vector3(24.8, 1.8, 3.2), .18),
		mats.sanctum_ivory, foundry_yaw) as Node3D
	lintel.set_meta("behind_operator", true)
	for course_index in 3:
		var course := world.call("_add_brick", gallery,
			"TruthFoundryCourse_%02d" % (course_index + 1),
			foundry_back - foundry_front * .82 + Vector3.UP * (3.2 + course_index * 2.15),
			Bricks.build_bevel_box(Vector3(12.4 - course_index * 1.8, .78, .28), .08),
			mats.gold if course_index == 2 else (
				mats.arrival_glass if course_index == 1 else mats.sanctum_ivory),
			foundry_yaw) as Node3D
		course.set_meta("rear_display_course", true)
	# A compact vertical crystal supplies the colour focus that the old long
	# horizontal courses tried to provide, without becoming another barrier.
	var truth_focus := world.call("_add_brick", gallery, "TruthFoundryFocusCrystal",
		foundry_back - foundry_front * 1.0 + Vector3.UP * 8.2,
		Bricks.build_crystal(1.15, 4.4, .28, 8), mats.arrival_glass,
		foundry_yaw) as Node3D
	truth_focus.set_meta("landmark_only", true)
	for side in [-1.0, 1.0]:
		var planter_at: Vector3 = foundry_back + foundry_side * float(side) * 15.0 \
			+ foundry_front * 1.5
		world.call("_add_brick", gallery, "TruthFoundryPlanter_%s" % side,
			planter_at + Vector3.UP * .42,
			Bricks.build_bevel_box(Vector3(5.8, .84, 4.2), .16), mats.sanctum_ivory,
			foundry_yaw)
		world.call("_add_brick", gallery, "TruthFoundryPlanting_%s" % side,
			planter_at + Vector3.UP * .92,
			Bricks.build_bevel_box(Vector3(4.7, .24, 3.1), .20), mats.green_glow,
			foundry_yaw)

	# Six low modules visually join the two research bays. They remain nearly
	# flush with the deck and never become a mandatory jump course.
	for terrace_index in 6:
		var t := float(terrace_index + 1) / 7.0
		var at := lens_center.lerp(foundry_center, t) + Vector3(0, .18, 0)
		world.call("_add_brick", gallery, "HopeGalleryTerrace_%02d" % (terrace_index + 1),
			at, Bricks.build_bevel_box(Vector3(10.5, .18, 7.5), .12),
			mats.sanctum_ivory)
		world.call("_add_brick", gallery, "HopeGalleryMeasure_%02d" % (terrace_index + 1),
			at + Vector3.UP * .12,
			Bricks.build_bevel_box(Vector3(5.6, .06, .46), .04), mats.arrival_glass)
	_build_department_sign(world, gallery, Vector3(-44, 1.0, -52),
		"HOPE OPTICS GALLERY\nREFRAME • BUILD • CONTINUE", -0.12)


static func _build_hope_materialisation_conduit(world: MindSparkWorldOne,
		campus: Node3D, hope: Node3D) -> void:
	var mats: Dictionary = world.get("_materials")
	var conduit := Node3D.new()
	conduit.name = "HopeMaterialisationConduit"
	conduit.position = hope.position
	conduit.set_meta("source", "Perspective Carousel and Truth Materialiser")
	conduit.set_meta("destination", "Conservatory Understanding Reward Shrine")
	conduit.set_meta("path_class", "protected service edge plus non-solid floor signal")
	campus.add_child(conduit)
	var service_points: Array[Vector3] = [
		Vector3(-62, .45, -8), Vector3(-30, .45, 18), Vector3(10, .45, 18),
		Vector3(42, .45, 2), Vector3(30, .45, -30), Vector3(0, .45, -50),
	]
	for segment_index in service_points.size() - 1:
		var channel := world.call("_add_cable_between", conduit,
			"HopeSignalSegment_%02d" % (segment_index + 1),
			service_points[segment_index], service_points[segment_index + 1],
			.11, .11, mats.arrival_glass, 8) as Node3D
		channel.set_meta("intentionally_non_solid", true)
		channel.set_meta("narrative_flow", "perspective to truth to guardian")
	for support_index in 4:
		var at: Vector3 = service_points[support_index + 1]
		world.call("_add_brick", conduit, "ConduitIvorySocket_%02d" % (support_index + 1),
			at, Bricks.build_bevel_box(Vector3(1.5, .50, 1.5), .10), mats.sanctum_ivory)
		world.call("_add_sphere", conduit, "ConduitReading_%02d" % (support_index + 1),
			at + Vector3.UP * .38, Vector3.ONE * .20, mats.arrival_glass)
	_build_understanding_reward_shrine(world, conduit, service_points[-1])


static func _build_understanding_reward_shrine(world: MindSparkWorldOne,
		conduit: Node3D, at: Vector3) -> void:
	## The chapter reward belongs to the live route rather than the invisible
	## compatibility shell for the retired Guardian Court. The low exedra makes
	## the conduit destination readable from the Hope district while retaining a
	## broad, level approach to the bridge for Island Three.
	var mats: Dictionary = world.get("_materials")
	var shrine := Node3D.new()
	shrine.name = "GuardianRewardSocket"
	shrine.position = at + Vector3(0.0, -.45, 0.0)
	shrine.set_meta("energy_source", "HopeMaterialisationConduit")
	shrine.set_meta("reward_role", "visible Island Two chapter completion focus")
	shrine.set_meta("production_replacement_for", "EliteGuardianCourt/GuardianRewardSocket")
	shrine.set_meta("clear_player_approach_m", 8.0)
	conduit.add_child(shrine)
	world.call("_add_cylinder", shrine, "RewardIvoryCradle", Vector3(0, .36, 0),
		3.6, .72, mats.sanctum_ivory, true, 12)
	world.call("_add_cylinder", shrine, "RewardTealInset", Vector3(0, .74, 0),
		2.8, .10, mats.arrival_glass, false, 12)
	for side in [-1.0, 1.0]:
		world.call("_add_cylinder", shrine,
			"UnderstandingPier_%s" % ("West" if side < 0.0 else "East"),
			Vector3(side * 4.8, 3.0, 1.6), .72, 5.4,
			mats.sanctum_ivory, true, 10)
		world.call("_add_brick", shrine,
			"UnderstandingFin_%s" % ("West" if side < 0.0 else "East"),
			Vector3(side * 4.8, 6.0, 1.6),
			Bricks.build_crystal(.72, 2.0, .20, 6), mats.green_glow)
	world.call("_add_brick", shrine, "UnderstandingLintel", Vector3(0, 5.65, 1.6),
		Bricks.build_bevel_box(Vector3(11.2, .55, .70), .12), mats.sanctum_ivory)
	var reward := world.call("_add_brick", shrine, "RewardHopeCrystal",
		Vector3(0, 2.35, 0), Bricks.build_crystal(1.05, 3.8, .30, 8),
		mats.green_glow) as Node3D
	reward.visible = false
	reward.set_meta("story_state", "guardian_freed")
	world.call("_add_label", shrine, "UNDERSTANDING RESTORED",
		Vector3(0, 7.5, 1.8), Color("eaffd9"), 17)


static func _build_island_two_landscaping(world: MindSparkWorldOne,
		campus: Node3D, constellation: Node3D, hope: Node3D) -> void:
	var landscaping := Node3D.new()
	landscaping.name = "IslandTwoGroupedLandscaping"
	landscaping.set_meta("planting_policy", "framed groups; quiet space around all interactions")
	landscaping.set_meta("replaces", "evenly scattered fourteen-tree rings in each district")
	campus.add_child(landscaping)
	var tree_palette := _build_island_two_tree_palette()
	var groups := [
		[constellation.position + Vector3(-44, 2.7, 52), 0],
		[constellation.position + Vector3(44, 2.7, 52), 1],
		[constellation.position + Vector3(0, 2.7, -66), 2],
		[hope.position + Vector3(-86, 2.6, 42), 3],
		[hope.position + Vector3(84, 2.6, 42), 4],
		[hope.position + Vector3(0, 2.6, 52), 5],
	]
	for group in groups:
		_add_low_poly_canopy_tree(world, landscaping, group[0], int(group[1]), tree_palette)


static func _add_low_poly_canopy_tree(world: MindSparkWorldOne, parent: Node3D,
		at: Vector3, variant: int, palette: Dictionary) -> void:
	var mats: Dictionary = world.get("_materials")
	var tree := Node3D.new()
	tree.name = "ObservatoryCanopyTree_%02d" % (variant + 1)
	tree.position = at
	tree.set_meta("reusable_component_family", "Island One aligned low-poly canopy tree")
	tree.set_meta("collision_class", "solid planter and trunk; overhead canopy non-solid")
	tree.set_meta("foliage_palette", "emerald, sage, jade, teal data and restrained gold")
	parent.add_child(tree)
	world.call("_add_cylinder", tree, "IvoryPlanter", Vector3(0, .24, 0),
		2.7, .48, mats.sanctum_ivory, true, 16)
	world.call("_add_torus", tree, "PlanterBrassCap", Vector3(0, .52, 0),
		2.25, 2.65, mats.astral_brass)
	world.call("_add_cylinder", tree, "SolidTrunk", Vector3(0, 3.1, 0),
		.46, 5.4, mats.bio_bark, true, 8)
	for branch_index in 5:
		var angle := TAU * float(branch_index) / 5.0 + variant * .23
		var branch_end := Vector3(sin(angle) * 2.6, 6.8 + float(branch_index % 2) * .65,
			cos(angle) * 2.6)
		world.call("_add_cable_between", tree, "CanopyBranch_%02d" % (branch_index + 1),
			Vector3(0, 5.1, 0), branch_end, .25, .10, mats.bio_bark, 8)
		world.call("_add_brick", tree, "FacetedCanopy_%02d" % (branch_index + 1),
			branch_end, Bricks.build_bevel_box(Vector3(3.6, 1.45, 3.0), .42),
			palette["sage"] if branch_index == variant % 5 else (
				palette["emerald"] if branch_index % 2 == 0 else palette["jade"]),
			angle)
	world.call("_add_brick", tree, "CanopyCrown", Vector3(0, 7.8, 0),
		Bricks.build_bevel_box(Vector3(4.2, 1.8, 3.8), .48), palette["sage"],
		variant * .21)
	world.call("_add_sphere", tree, "HopeBud", Vector3(0, 8.9, 0),
		Vector3.ONE * .34, palette["gold_green"])


static func _build_story_guidance(world: MindSparkWorldOne, campus: Node3D,
		constellation: Node3D, hope: Node3D, gate: AnimatableBody3D) -> void:
	var mats: Dictionary=world.get("_materials")
	var route := Node3D.new()
	route.name="IslandTwoQuestRoute"
	route.set_meta("story_sequence",PackedStringArray([
		"receive","read evidence","weave memory","verify","reframe","build truth","clear guard"]))
	route.set_meta("guidance_style","discrete floor facets; no solid coloured line or floating ring")
	campus.add_child(route)
	var evidence_points: Array[Vector3]=[
		world.to_local((constellation.get_node("FearGate") as Node3D).global_position) + Vector3.UP * .20,
		constellation.position+Vector3(-66,.20,-10),
		constellation.position+Vector3(-20,.20,10),
		constellation.position+Vector3(38,.20,6),
		world.to_local(gate.global_position),
	]
	var hope_points: Array[Vector3]=[
		world.to_local(gate.global_position),
		hope.position+Vector3(-80,.20,-18),
		hope.position+Vector3(-28,.20,4),
		hope.position+Vector3(0,.20,32),
		hope.position+Vector3(22,.20,10),
		hope.position+Vector3(42,.20,-8),
		hope.position+Vector3(0,.20,72),
	]
	_add_guidance_facets(world,route,evidence_points,"Evidence",mats.arrival_glass)
	_add_guidance_facets(world,route,hope_points,"Hope",mats.gold)
	var evidence_label := world.call("_add_label",route,
		"OBSERVE  →  NAME  →  VERIFY",constellation.position+Vector3(0,8,-18),Color("d9fff4"),18) as Label3D
	evidence_label.pixel_size=.010
	var hope_label := world.call("_add_label",route,
		"REFRAME  →  BUILD  →  MOVE WITH HOPE",hope.position+Vector3(0,9,58),Color("fff0c9"),18) as Label3D
	hope_label.pixel_size=.010


static func _add_guidance_facets(world: MindSparkWorldOne, parent: Node3D,
		points: Array[Vector3], prefix: String, material: Material) -> void:
	var marker_number := 0
	for segment_index in points.size()-1:
		var start := points[segment_index]
		var finish := points[segment_index+1]
		var distance := start.distance_to(finish)
		var count := maxi(2,int(distance/8.0))
		var direction := finish-start
		var yaw := atan2(direction.x,direction.z)
		for step in count:
			marker_number+=1
			var progress := float(step+1)/float(count+1)
			var marker := world.call("_add_brick",parent,
				"%sGuidanceFacet_%02d"%[prefix,marker_number],start.lerp(finish,progress),
				Bricks.build_bevel_box(Vector3(.72,.10,1.25),.08),material,yaw) as Node3D
			marker.set_meta("route_chapter",prefix.to_lower())
			marker.set_meta("non_solid_guidance",true)


static func _build_guard_court(world: MindSparkWorldOne, campus: Node3D,
		hope: Node3D) -> void:
	var mats: Dictionary=world.get("_materials")
	var court := Node3D.new()
	court.name="EliteGuardianCourt"
	court.position=hope.position+Vector3(0,3.0,72)
	court.set_meta("purpose","combat happens after reasoning and outside every station interaction apron")
	court.set_meta("encounter_id","ridge")
	campus.add_child(court)
	world.call("_add_brick",court,"GuardCourtIvoryFloor",Vector3(0,-.22,0),
		Bricks.build_bevel_box(Vector3(42,.30,24),.16),mats.sanctum_ivory)
	for side in [-1.0,1.0]:
		world.call("_add_tapered_cylinder",court,"GuardianBoundaryPier_%s"%side,
			Vector3(side*19,2.4,-9),.42,.64,4.6,mats.sanctum_ivory,12)
		world.call("_add_sphere",court,"GuardianBoundaryLight_%s"%side,
			Vector3(side*19,4.9,-9),Vector3.ONE*.46,mats.gold)
	var label := world.call("_add_label",court,"GUARDIAN COURT • REASONING COMPLETE",
		Vector3(0,7.2,-8.5),Color("fff0c9"),17) as Label3D
	label.pixel_size=.010
	# A shallow exedra gives the combat conclusion a back wall and reward focus
	# while leaving the enemy movement area and onward route open.
	for bay_index in 7:
		var x := -18.0 + float(bay_index) * 6.0
		var depth := 8.8 + absf(x) * .08
		world.call("_add_cylinder", court, "GuardianExedraPier_%02d" % (bay_index + 1),
			Vector3(x, 3.7, depth), .48, 6.4, mats.sanctum_ivory, true, 12)
		world.call("_add_sphere", court, "GuardianExedraLamp_%02d" % (bay_index + 1),
			Vector3(x, 7.2, depth), Vector3.ONE * .32,
			mats.gold if bay_index in [0, 3, 6] else mats.arrival_glass)
		if bay_index > 0:
			var previous_x := -18.0 + float(bay_index - 1) * 6.0
			var previous_depth := 8.8 + absf(previous_x) * .08
			world.call("_add_cable_between", court,
				"GuardianExedraRail_%02d" % bay_index,
				Vector3(previous_x, 6.2, previous_depth), Vector3(x, 6.2, depth),
				.16, .16, mats.astral_brass, 8)
	var reward := Node3D.new()
	reward.name = "GuardianRewardSocket"
	reward.position = Vector3(0, .50, 6.8)
	reward.set_meta("energy_source", "HopeMaterialisationConduit")
	reward.set_meta("reward_role", "chapter completion focus")
	court.add_child(reward)
	world.call("_add_cylinder", reward, "RewardIvoryCradle", Vector3.ZERO,
		2.2, .72, mats.sanctum_ivory, true, 18)
	world.call("_add_torus", reward, "RewardBrassBezel", Vector3(0, .42, 0),
		1.55, 2.08, mats.astral_brass)
	world.call("_add_brick", reward, "RewardHopeCrystal", Vector3(0, 2.0, 0),
		Bricks.build_crystal(.82, 2.8, .24, 8), mats.green_glow)


static func _build_chapter_lighting(world: MindSparkWorldOne, campus: Node3D,
		constellation: Node3D, hope: Node3D) -> void:
	var evidence_light := world.call("_add_zone_light",campus,
		constellation.position+Vector3(0,30,2),Color("9edfdc"),95.0,1.05) as OmniLight3D
	evidence_light.name="EvidenceChapterLight"
	var gate_light := world.call("_add_zone_light",campus,
		world.to_local((world.get_node("WorldOneGeometry/SavedQuestProgressionGates/QuestGate_2") as Node3D).global_position)+Vector3.UP*13,
		Color("ffe1a3"),52.0,1.20) as OmniLight3D
	gate_light.name="ArchiveThresholdLight"
	var hope_light := world.call("_add_zone_light",campus,
		hope.position+Vector3(0,32,32),Color("ffd49b"),105.0,1.18) as OmniLight3D
	hope_light.name="HopeChapterLight"
