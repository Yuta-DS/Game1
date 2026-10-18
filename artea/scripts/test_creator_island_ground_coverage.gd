extends SceneTree


const GALLERY_SCENE := "res://scenes/art_gallery_3d_inprogress.tscn"
const WALK_SPEED := 24.0
const GRAVITY := 28.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gallery := (load(GALLERY_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(gallery)
	current_scene = gallery
	for _frame in 12:
		await physics_frame
	var world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var studio := world.get_node("CreatorsLightStudio") as Node3D
	var deck := studio.get_node("WalkableDeck") as MeshInstance3D
	var deck_collision := studio.get_node("WalkableDeckCollision") as StaticBody3D
	var floor := studio.get_node("StudioFloor") as MeshInstance3D
	var finish := studio.get_node("CreatorStudioGroundFinish") as Node3D
	var table := studio.get_node("ArtistMaterialsTable") as Node3D
	var landmarks := world.get_node("CreatorsLightQuestLandmarks") as Node3D
	var table_offset := table.position - Vector3(600.0, 2.0, 1640.0)
	# A quarter-turned table is 38 m across the studio and 72 m along it.
	if absf(table_offset.x) + 19.0 >= 150.0 \
			or absf(table_offset.z) + 36.0 >= 120.0:
		_fail("art table extends beyond the studio floor")
		return
	for index in 6:
		var easel := studio.get_node("PaintingEasel_%02d" % index) as Node3D
		if Vector2(table.position.x - easel.position.x,
				table.position.z - easel.position.z).length() < 45.0:
			_fail("art table crowds PaintingEasel_%02d" % index)
			return
	for removed_studio_prop in ["CREATORSLIGHTPortalFrame", "StudioBackWall",
			"SunRuneOuter", "SunRuneInner", "SunRay"]:
		if studio.get_node_or_null(removed_studio_prop) != null:
			_fail("removed Creator studio prop is still present: %s" % removed_studio_prop)
			return
	for landmark_name in ["DrawingStudio", "DreamDoorWorkshop",
			"RestingPlaceCanvas", "ArtRealGarden", "PerfectBlankSanctuary"]:
		var anchor := landmarks.get_node_or_null(landmark_name) as Node3D
		if anchor == null or not anchor.get_children().is_empty():
			_fail("Creator quest anchor is missing or still has a freestanding prop: %s" % landmark_name)
			return
	if landmarks.get_child_count() != 5:
		_fail("Creator light poles or other unwanted studio props remain")
		return
	var east := world.get_node("EastObservatory") as Node3D
	if east.get_node_or_null("CompassRing") != null \
			or east.get_node_or_null("SkyCypress") != null:
		_fail("Creator observatory still has the gold ring or purple decoration")
		return
	var east_ground := (east.get_node("WalkableDeck") as MeshInstance3D).material_override \
		as ShaderMaterial
	if east_ground == null or absf(float(east_ground.get_shader_parameter(
			"island_radius")) - 70.0) > 0.01 \
			or not bool(east_ground.get_shader_parameter("lookout_finish")):
		_fail("Creator observatory paving does not fit its walkable disk")
		return
	if deck.material_override != floor.material_override:
		_fail("outer Creator island still has an unfinished ground material")
		return
	if finish.get_node_or_null("StudioPaver_00_00") != null:
		_fail("separate studio pavers still hide the aligned island grid")
		return
	if not (deck.material_override is ShaderMaterial):
		_fail("Creator paving does not cover the circular island")
		return
	var deck_mesh := deck.mesh as CylinderMesh
	var deck_shape := (deck_collision.get_child(0) as CollisionShape3D).shape as CylinderShape3D
	if deck_collision.position.distance_to(deck.position) > 0.01 \
			or absf(deck_shape.radius - deck_mesh.top_radius) > 0.01 \
			or absf(deck_shape.height - deck_mesh.height) > 0.01 \
			or deck_collision.get_meta("mass_class", "") != "infinite_static_mass":
		_fail("Creator island paving and solid ground do not match")
		return
	var creator_global := world.to_global(Vector3(600.0, 0.0, 1640.0))
	var paving_center := (deck.material_override as ShaderMaterial).get_shader_parameter(
		"island_center") as Vector2
	if paving_center.distance_to(Vector2(creator_global.x, creator_global.z)) > 0.01:
		_fail("Creator paving is not anchored to the island in the gallery")
		return
	var size := (floor.mesh as BoxMesh).size
	if Vector2(size.x, size.z).length() * 0.5 >= 195.0:
		_fail("studio floor corners overhang the circular island")
		return
	for side in ["North", "South", "East", "WestNorth", "WestSouth"]:
		if finish.get_node_or_null(side + "CourtyardRampCollision") == null:
			_fail("raised studio has no walkable %s courtyard transition" % side)
			return
		if (finish.get_node(side + "CourtyardRamp") as MeshInstance3D).material_override \
				!= floor.material_override:
			_fail("%s courtyard ramp paving is not aligned with the studio" % side)
			return
	var space := world.get_world_3d().direct_space_state
	# Sample the paved annulus through the visible edge; every point must hit
	# the deck's own collision, not a decorative paver or the island underside.
	for radius in [182.0, 188.0, 194.0]:
		for index in 32:
			var angle := TAU * float(index) / 32.0
			var rim_point := Vector3(600.0 + cos(angle) * radius, 0.0,
				1640.0 + sin(angle) * radius)
			var rim_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				world.to_global(rim_point + Vector3.UP * 12.0),
				world.to_global(rim_point + Vector3.DOWN * 12.0)))
			var on_ramp: bool = rim_hit.get("collider") in [
				world.get_node("CreatorBridge/WalkwayCollision"),
				finish.get_node("CreatorArrivalApronCollision"),
				finish.get_node("NorthCourtyardRampCollision"),
				finish.get_node("SouthCourtyardRampCollision"),
				finish.get_node("EastCourtyardRampCollision"),
				finish.get_node("WestNorthCourtyardRampCollision"),
				finish.get_node("WestSouthCourtyardRampCollision")]
			var surface_y: float = world.to_local(rim_hit.position).y if not rim_hit.is_empty() else -100.0
			if rim_hit.is_empty() or (rim_hit.collider != deck_collision and not on_ramp) \
					or surface_y < -0.15 or surface_y > (2.2 if on_ramp else 0.35):
				_fail("Creator island rim has unsupported ground at %s" % rim_point)
				return
	for point in [Vector3(600, 0, 1460), Vector3(600, 0, 1820),
			Vector3(780, 0, 1640), Vector3(430, 0, 1700)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			world.to_global(point + Vector3.UP * 12.0),
			world.to_global(point + Vector3.DOWN * 12.0)))
		if hit.is_empty() or world.to_local(hit.position).y < -0.15 \
				or world.to_local(hit.position).y > 2.2:
			_fail("Creator island ground is missing at %s" % point)
			return
	var player := gallery.get_node("Player3D") as CharacterBody3D
	player.set_physics_process(false)
	player.set_process_input(false)
	for edge_offset in [Vector3(133, 0, 133), Vector3(-133, 0, 133),
			Vector3(133, 0, -133), Vector3(-133, 0, -133)]:
		player.global_position = world.to_global(Vector3(600, 3, 1640) + edge_offset)
		player.velocity = Vector3.ZERO
		for _frame in 120:
			player.velocity.y -= GRAVITY / 60.0
			player.move_and_slide()
			await physics_frame
			if player.is_on_floor():
				break
		if not player.is_on_floor() or absf(world.to_local(player.global_position).y - 1.0) > 0.5:
			_fail("player cannot stand on the paved Creator rim at %s" % edge_offset)
			return
	player.global_position = world.to_global(Vector3(432, 3, 1714))
	player.velocity = Vector3.ZERO
	for _frame in 180:
		player.velocity.x = WALK_SPEED
		player.velocity.z = 0.0
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		await physics_frame
		if world.to_local(player.global_position).x >= 468.0:
			break
	if world.to_local(player.global_position).x < 468.0 or not player.is_on_floor():
		_fail("player cannot walk from the west island deck onto the studio: %s floor=%s" \
			% [world.to_local(player.global_position), player.is_on_floor()])
		return
	player.global_position = world.to_global(Vector3(600, 3, 1480))
	player.velocity = Vector3.ZERO
	for _frame in 120:
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			break
	if not player.is_on_floor():
		_fail("player cannot stand on the outer Creator island")
		return
	var returning := false
	var airborne_frames := 0
	for _frame in 420:
		var local := world.to_local(player.global_position)
		if not returning and local.z >= 1540.0:
			if not player.is_on_floor():
				_fail("north courtyard ramp does not reach the studio floor")
				return
			returning = true
		if returning and local.z <= 1480.0:
			if not player.is_on_floor():
				_fail("player left the studio without a supported island floor")
				return
			print("CREATOR_ISLAND_GROUND_COVERAGE: PASS — full circular ground and studio courtyard walked both ways")
			quit()
			return
		player.velocity.x = 0.0
		player.velocity.z = -WALK_SPEED if returning else WALK_SPEED
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		airborne_frames = 0 if player.is_on_floor() else airborne_frames + 1
		if airborne_frames > 8:
			_fail("unsupported ground at %s" % world.to_local(player.global_position))
			return
		await physics_frame
	_fail("player did not complete the island-to-studio walk")


func _fail(message: String) -> void:
	push_error("CREATOR_ISLAND_GROUND_COVERAGE: " + message)
	quit(1)
