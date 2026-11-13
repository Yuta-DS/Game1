extends "res://scripts/test_castle_rooftop_barrier_safety.gd"

const Style := preload("res://scripts/castle_reference_style.gd")
const COURT_Y := 69.18
const CENTRE_Z := 27.41

func _fail(message: String) -> void:
	push_error("MAIN_KEEP_STYLE_TEST: " + message)
	quit(1)

func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for frame in 90:
		await process_frame
		await physics_frame
	var entrance := hub.get_node("CastleEntrance/CastleEntrance")
	var turrets := entrance.get_node("KeepCourtTurrets").get_children()
	if turrets.size() != 4:
		_fail("expected four compact court turrets")
		return
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	player.set_physics_process(false)
	player.set_process_input(false)
	var space := player.get_world_3d().direct_space_state
	for turret: Node3D in turrets:
		var shaft := turret.get_node("SolidTurretShaft") as MeshInstance3D
		var bounds := shaft.global_transform * shaft.get_aabb()
		if absf(bounds.position.y - COURT_Y) > 0.002 or bounds.size.y > 3.21 \
				or absf(turret.global_position.z - CENTRE_Z) - bounds.size.z * 0.5 < 7.79:
			_fail("turret floats, retains tall-column proportions or obstructs the aisle")
			return
		if turret.find_children("ReferenceRoundArchWindow*", "Node3D", false, false).size() != 2:
			_fail("turret does not repeat the keep's recessed window style")
			return
		var roof := turret.get_node("TurretRedRoof") as MeshInstance3D
		var ray := PhysicsRayQueryParameters3D.create(turret.global_position + Vector3.UP * 6,
			turret.global_position + Vector3.UP * 3)
		ray.exclude = [player.get_rid()]
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or not roof.is_ancestor_of(hit.collider):
			_fail("turret roof is not physically solid")
			return
	var beds := entrance.get_node("KeepCourtHerbGarden").get_children()
	if beds.size() != 4:
		_fail("four matching low herb beds missing")
		return
	for bed: Node3D in beds:
		if not bed.has_node("MedievalHerbPlanting") or absf(bed.global_position.y - COURT_Y) > 0.002:
			_fail("herbs lost their species or floor alignment")
			return
	var stair := hub.get_node("CastleStairs/CastleStair")
	for label in ["OuterStoneParapet", "InnerStoneParapet"]:
		var wall := stair.get_node(label) as MeshInstance3D
		if not wall.get_meta("top_owned_by_coping", false):
			_fail("coping still overlays a duplicate wall-top face")
			return
		for normal: Vector3 in wall.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
			if normal.y > 0.5:
				_fail("duplicate upward wall faces can shimmer through the coping")
				return
	var original := hub.get_node("building_castle_red2/building_castle_red") as MeshInstance3D
	if (original.get_active_material(0) as StandardMaterial3D).albedo_texture == null \
			or Style.WALL.to_html(false) != "818c91" or Style.TRIM.to_html(false) != "586065":
		_fail("main keep atlas or audited primary stone hierarchy changed")
		return
	# Walk the real capsule along both new garden/turret aisles, then sprint into
	# each turret's inner face and escape. No decorative collision is assumed safe.
	for side: float in [-1.0, 1.0]:
		var z := CENTRE_Z + side * 7.15
		if not await _settle(player, Vector3(-31.7, COURT_Y + 2, z)):
			_fail("cannot stand in the side garden aisle")
			return
		for x: float in [-38.5, -31.7]:
			if not await _walk_to(player, Vector3(x, COURT_Y, z)) \
					or absf(player.global_position.y - COURT_Y) > 0.06:
				_fail("turret/planting aisle catches the player or changes floor height")
				return
		for x: float in [-38.3, -32.9]:
			var start := Vector3(x, COURT_Y, z)
			await _walk_to(player, start)
			await _run_direction(player, Vector3(0, 0, side), 16)
			if absf(player.global_position.z - CENTRE_Z) > 7.5 \
					or not await _walk_to(player, start):
				_fail("player crossed or became trapped against a turret")
				return
	print("MAIN_KEEP_STYLE_TEST: PASS — reference atlas retained, four grounded solid turrets, matching herb beds, single-surface coping; two aisles both ways and four impacts/escapes")
	quit(0)
