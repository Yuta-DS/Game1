extends Node3D
## World-space interpretation of the same persistent state used by the controls.
const Rules := preload("res://scripts/mind_spark/unfinished_light_rules.gd")
const Bricks := preload("res://scripts/altar/AltarParts.gd")
var world: MindSparkWorldOne
var stations: Dictionary = {}
var leaves: Array[Node3D] = []
var beams: Array[Node3D] = []
var _elapsed := 0.0
var _mats: Dictionary

func build(source: MindSparkWorldOne) -> void:
	world = source
	name = "GardenOfUnfinishedLight"
	set_meta("preserve_authored_nodes", true)
	_mats = world.get("_materials")
	_mats = _mats.duplicate()
	var foliage := StandardMaterial3D.new()
	foliage.albedo_color = Color("528367")
	foliage.roughness = .82
	_mats["garden_foliage"] = foliage
	# The retired jump-course slabs intersect both the gate swing and the new
	# conservatory basin. Keep their authored nodes for recovery, but replace
	# their raised visual/collision surfaces with the existing continuous deck.
	var zones: Dictionary = world.get("_zone_nodes")
	var hope: Node3D = zones["04_hope_path_ridge"]
	for pattern in ["HopePathTile_*", "HopePathIvoryPlinth_*", "HopePathGiltReveal_*", "HopePathMeasure_*"]:
		for old in hope.find_children(pattern, "Node3D", true, false):
			old.visible = false
			old.set_meta("replaced_by", "GardenOfUnfinishedLight/ConservatoryOfPossibleTomorrow")
			if old is CollisionObject3D:
				old.collision_layer = 0
				old.collision_mask = 0
	for station in world.get_quest_objects():
		if station.save_id in Rules.IDS:
			station.set_meta("unfinished_light", true)
			station.definition = station.definition.duplicate()
			station.definition.display_name = ["Evidence inspection", "Mechanical recorder", "Causal reconstruction", "Perspective workshop", "Living light projector"][Rules.IDS.find(station.save_id)]
			station.definition.success_message = "Discovery saved. Follow the next research light."
			stations[station.save_id] = station
	# Keep canopies outside the actual operating aprons, including the projector
	# whose front now faces its garden instead of the outgoing bridge.
	var moved := 0
	for zone_id in ["03_constellation_court", "04_hope_path_ridge"]:
		var zone: Node3D = zones[zone_id]
		for tree in zone.find_children("*", "Node3D", true, false):
			if not tree.get_meta("island_two_palette_override", false): continue
			for station in stations.values():
				if Vector2(tree.global_position.x - station.global_position.x, tree.global_position.z - station.global_position.z).length() < 18:
					var angle := -.65 + moved * .43
					tree.global_position = zone.to_global(Vector3(cos(angle) * 104, 0, sin(angle) * 104))
					moved += 1
					break
	_build_research_court()
	_build_conservatory()
	_refine_terrace_planting(hope)
	for enemy in world.get_enemies():
		if enemy.encounter_id in ["constellation", "ridge"]:
			_retire_replaced_enemy(enemy)
	_sync()


func _retire_replaced_enemy(enemy: MindSparkEnemyBase) -> void:
	## Island Two's evidence and hope encounters are now peaceful research
	## activities. Their former combat actors stay in the scene only for save
	## compatibility, so every physics surface must retire with the visuals.
	## Disabling just the CharacterBody left each invisible Hurtbox on layer 1.
	enemy.visible = false
	enemy.active = false
	enemy.velocity = Vector3.ZERO
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.collision_layer = 0
	enemy.collision_mask = 0
	enemy.set_meta("replaced_by", "GardenOfUnfinishedLight peaceful research sequence")
	enemy.set_meta("retired_collision_disabled", true)
	var navigation := enemy.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if navigation != null:
		navigation.avoidance_enabled = false
	for collision_object in enemy.find_children("*", "CollisionObject3D", true, false):
		var body := collision_object as CollisionObject3D
		body.collision_layer = 0
		body.collision_mask = 0
		if body is Area3D:
			(body as Area3D).monitoring = false
			(body as Area3D).monitorable = false
	for collision_shape in enemy.find_children("*", "CollisionShape3D", true, false):
		(collision_shape as CollisionShape3D).disabled = true

func _box(parent: Node3D, title: String, at: Vector3, size: Vector3, mat: Material, solid := false) -> Node3D:
	return world.call("_add_box", parent, title, at, size, mat, solid) as Node3D

func _build_research_court() -> void:
	var court := Node3D.new()
	court.name = "CrescentInvestigationCourt"
	court.position = world.get_zone_position("03_constellation_court")
	add_child(court)
	for i in 7:
		var angle := PI * .16 + float(i) * PI * .68 / 6.0
		var at := Vector3(cos(angle) * 96, .5, -sin(angle) * 88)
		_planter(court, at, i)
	for i in 3:
		var station: Node3D = stations[Rules.IDS[i]]
		var case := Node3D.new()
		case.name = "InvestigationBackdrop_%d" % i
		case.position = world.to_local(station.global_position)
		case.rotation.y = station.rotation.y
		add_child(case)
		_box(case, "TealInstrumentBack", Vector3(0, 6, -4), Vector3(12, 8, .8), _mats.bio_gunmetal, true)
		for side in [-1, 1]:
			_box(case, "BrassFrame%d" % side, Vector3(side * 6.2, 6, -3.4), Vector3(.3, 8.6, .3), _mats.astral_brass)
		world.call("_add_label", case, ["01 · INSPECT THE EVENT", "02 · REPLAY THE RECORD", "03 · TEST AN EXPLANATION"][i], Vector3(0, 11, -3), Color("fff0d3"), 20)
		for module in 3:
			world.call("_add_sphere", case, "EvidenceLens%d" % module, Vector3(-3.5 + module * 3.5, 7, -3.2), Vector3(.8, .8, .24), _mats.arrival_glass)
	var archive := world.get_node_or_null("IslandTwoMemoryCampus/EvidenceObservatory") as Node3D
	if archive != null:
		# The central bay remains open; give the long ribs a supported lower order.
		for side in [-1, 1]:
			_box(court, "LaboratoryBench%d" % side, Vector3(side * 52, 1.8, -64), Vector3(22, 3.6, 7), _mats.sanctum_ivory, true)

func _planter(parent: Node3D, at: Vector3, index: int) -> void:
	preload("res://scripts/mind_spark/research_planter.gd").build(world,parent,at,index,_mats)

func _build_conservatory() -> void:
	var gallery := Node3D.new()
	gallery.name = "ConservatoryOfPossibleTomorrow"
	gallery.position = world.get_zone_position("04_hope_path_ridge") + Vector3(0, 0, -50)
	add_child(gallery)
	for i in 5:
		var z := -20.0 + i * 10.0
		for side in [-1, 1]:
			world.call("_add_brick", gallery, "PierFoot%d_%d" % [i, side], Vector3(side * 35, .3, z), Bricks.build_bevel_box(Vector3(2.4, .6, 2.4), .12), _mats.sanctum_ivory)
			preload("res://scripts/mind_spark/research_bay_mount.gd")._solid(gallery,"PierFootSolid%d_%d"%[i,side],Vector3(side*35,.3,z),Vector3(2.4,.6,2.4))
			world.call("_add_cylinder", gallery, "GlasshousePier%d_%d" % [i, side], Vector3(side * 35, 12, z), .7, 24, _mats.sanctum_ivory, true, 12)
			world.call("_add_brick", gallery, "PierCapital%d_%d" % [i, side], Vector3(side * 35, 23.6, z), Bricks.build_bevel_box(Vector3(2.3, .8, 2.3), .15), _mats.sanctum_ivory)
		for segment in 16:
			var a := PI * float(segment) / 16
			var b := PI * float(segment + 1) / 16
			world.call("_add_cable_between", gallery, "CanopyRib%d_%d" % [i, segment], Vector3(cos(a) * 35, 24 + sin(a) * 12, z), Vector3(cos(b) * 35, 24 + sin(b) * 12, z), .4, .4, _mats.astral_brass, 10)
	_build_glasshouse_roof(gallery)
	for i in 2: _planter(gallery, Vector3(-22 + i * 44, 0, -23), 20 + i)
	var machine := Node3D.new()
	machine.name = "LivingProjectionMachine"
	machine.position = Vector3(0, 0, 0)
	gallery.add_child(machine)
	world.call("_add_cylinder", machine, "GardenBasin", Vector3(0, 1.3, 0), 18, 2.6, _mats.sanctum_ivory, true, 32)
	world.call("_add_cylinder", machine, "WaterRecess", Vector3(0, 2.65, 0), 16.6, .18, _mats.arrival_glass, false, 32)
	world.call("_add_cylinder", machine, "RootEngine", Vector3(0, 6, 0), 3, 7, _mats.bio_gunmetal, true, 16)
	for i in 9:
		var angle := TAU * float(i) / 9
		var tip := Vector3(cos(angle) * 11, 12 + i % 3 * 3, sin(angle) * 11)
		world.call("_add_cable_between", machine, "MechanicalStem%d" % i, Vector3(0, 5, 0), tip, .45, .22, _mats.astral_brass, 10)
		var leaf := world.call("_add_brick", machine, "UnfoldingLeaf%d" % i, tip, _leaf_mesh(), _mats.garden_foliage, angle) as Node3D
		leaves.append(leaf)
	for i in 3:
		var beam := _box(machine, "ProjectionRay%d" % i, Vector3(-6 + i * 6, 17, 0), Vector3(.25, .25, 24), _mats.arrival_glass)
		beams.append(beam)
	world.call("_add_label", gallery, "ARI'S GARDEN · AN UNFINISHED EXPERIMENT", Vector3(0, 30, 8), Color("fff0d3"), 24)
	var ari := Node3D.new()
	ari.name = "AriMemoryProjection"
	ari.position = Vector3(24, 0, 6)
	gallery.add_child(ari)
	world.call("_add_cylinder", ari, "ProjectionPedestal", Vector3(0, .6, 0), 3, 1.2, _mats.sanctum_ivory, true, 16)
	world.call("_add_tapered_cylinder", ari, "ApprenticeCoat", Vector3(0, 4.2, 0), .9, 1.5, 4.8, _mats.arrival_glass, 12)
	world.call("_add_sphere", ari, "ApprenticeFace", Vector3(0, 7.4, 0), Vector3.ONE * 1.1, _mats.arrival_glass)
	world.call("_add_label", ari, "ARI · MEMORY PROJECTION", Vector3(0, 10, 0), Color("fff0d3"), 16)

func _roof_point(segment: int, z: float) -> Vector3:
	var angle := PI * float(segment) / 16.0
	return Vector3(cos(angle)*35,24+sin(angle)*12,z)

func _build_glasshouse_roof(gallery: Node3D) -> void:
	# Longitudinal members stop exactly at the two end arches. Side ribbons
	# receive framed glazing; the central roof stays open for light/ventilation.
	var roof := Node3D.new()
	roof.name="FramedConservatoryRoof"
	gallery.add_child(roof)
	for segment in [0,2,4,8,12,14,16]:
		var start := _roof_point(segment,-20)
		var finish := _roof_point(segment,20)
		var member := world.call("_add_cable_between",roof,"LongitudinalMember%d"%segment,start,finish,.28,.28,_mats.astral_brass,10) as Node3D
		member.set_meta("support_start",start)
		member.set_meta("support_end",finish)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for bay in 4:
		for segment in [2,3,12,13]:
			var a := _roof_point(segment,-20+bay*10)
			var b := _roof_point(segment+1,-20+bay*10)
			var c := _roof_point(segment+1,-10+bay*10)
			var d := _roof_point(segment,-10+bay*10)
			for vertex in [a,b,c,a,c,d]: surface.add_vertex(vertex)
	surface.generate_normals()
	var glazing := MeshInstance3D.new()
	glazing.name="FramedSideGlazing"
	glazing.mesh=surface.commit()
	var glass := StandardMaterial3D.new()
	glass.albedo_color=Color(.72,.84,.79,.22)
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	glass.roughness=.3
	glazing.material_override=glass
	glazing.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	roof.add_child(glazing)
	roof.set_meta("open_central_vent",true)
	roof.set_meta("glazing_collision_policy","overhead decoration; unreachable from normal player route")

func _refine_terrace_planting(hope: Node3D) -> void:
	var terraces := hope.get_node_or_null("CelestialHopeUpperDistrict/CurvedSunriseGardenTerraces") as Node3D
	if terraces == null: return
	terraces.set_meta("preserve_authored_nodes",true)
	terraces.set_meta("planting_revision","rooted_sage_terraces")
	var soil := StandardMaterial3D.new()
	soil.albedo_color=Color("4d5140")
	soil.roughness=.95
	var leaf_mesh := preload("res://scripts/mind_spark/research_planter.gd")._leaf_mesh()
	for index in 12:
		for prefix in ["SunriseGardenCrown_","SunriseGardenBloom_"]:
			var old := terraces.get_node(prefix+"%02d"%(index+1)) as Node3D
			old.visible=false
			old.set_meta("replaced_by","RootedTerraceFoliage_%02d"%(index+1))
		var surface := terraces.get_node("SunriseGiltPlanterCap_%02d"%(index+1)) as MeshInstance3D
		surface.material_override=soil
		var start := deg_to_rad(126.0+index*10.0)
		var finish := deg_to_rad(134.0+index*10.0)
		for radius in [78.0,98.0]:
			world.call("_add_radial_plate",terraces,"SoilRetainingLip_%02d_%d"%[index+1,int(radius)],start,finish,radius,radius+1.0,1.25,1.82,_mats.sanctum_ivory)
		for angle in [start,finish]:
			world.call("_add_cable_between",terraces,"TerraceEndCap",Vector3(sin(angle)*78.5,1.65,cos(angle)*78.5),Vector3(sin(angle)*98.5,1.65,cos(angle)*98.5),.28,.28,_mats.sanctum_ivory,8)
		var foliage := MultiMeshInstance3D.new()
		foliage.name="RootedTerraceFoliage_%02d"%(index+1)
		foliage.multimesh=MultiMesh.new()
		foliage.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		foliage.multimesh.mesh=leaf_mesh
		foliage.multimesh.instance_count=72
		foliage.material_override=_mats.garden_foliage
		terraces.add_child(foliage)
		for plant in 9:
			var radius := 83.0+float(plant%3)*5.5
			var angle := lerpf(start,finish,.30+float(plant/3)*.20)
			var root_at := Vector3(sin(angle)*radius,1.48,cos(angle)*radius)
			for leaf in 8:
				var turn := TAU*leaf/8.0+plant*.4
				foliage.multimesh.set_instance_transform(plant*8+leaf,Transform3D(Basis(Vector3.UP,turn),root_at))

func _leaf_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1, 1]:
		for i in 12:
			var a := TAU * float(i) / 12
			var b := TAU * float(i + 1) / 12
			var first := Vector3(cos(a) * 4.4, 0, sin(a) * 1.8)
			var second := Vector3(cos(b) * 4.4, 0, sin(b) * 1.8)
			surface.add_vertex(Vector3(0, side * .42, 0))
			surface.add_vertex(first if side < 0 else second)
			surface.add_vertex(second if side < 0 else first)
	surface.generate_normals()
	return surface.commit()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < .1: return
	_elapsed = 0
	_sync()

func _sync() -> void:
	if not stations.has("world_one.truth_bridge"): return
	var state: Dictionary = stations["world_one.truth_bridge"].current_state
	var solved := bool(state.get("completed", false))
	var optics: Array = state.get("optics", [0, 0, 0])
	# The production projector replaces and releases the prototype machine after
	# this presenter is built. Drop those stale animation references before the
	# periodic story-state refresh touches them.
	for index in range(beams.size() - 1, -1, -1):
		if not is_instance_valid(beams[index]):
			beams.remove_at(index)
	for index in range(leaves.size() - 1, -1, -1):
		if not is_instance_valid(leaves[index]):
			leaves.remove_at(index)
	for i in beams.size():
		beams[i].rotation.y = float(optics[i]) * PI / 8
		beams[i].visible = state.has("approach") or solved
	for i in leaves.size():
		leaves[i].rotation.z = lerpf(leaves[i].rotation.z, 0.0 if solved else 1.15, .2)
	var legacy_court := world.get_node_or_null("IslandTwoMemoryCampus/EliteGuardianCourt") as Node3D
	if legacy_court != null: legacy_court.visible = false
