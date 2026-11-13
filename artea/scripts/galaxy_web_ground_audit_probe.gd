extends Node

## Opt-in browser check for the two Galaxy floors repaired during this session.
## Run through ./web verify --url 'http://localhost:8801/index.html?galaxy_audit=creator'
## or galaxy_audit=heart. Normal gameplay never creates this node.

const CREATOR := Vector3(600.0, 0.0, 1640.0)
const HEART := Vector3(0.0, 0.0, 2290.0)
const GRAVITY := 28.0
const WALK_SPEED := 24.0

var gallery: Node3D
var world: Node3D
var view := ""
var errors: Array[String] = []


func configure(gallery_node: Node3D, world_node: Node3D, requested_view: String) -> void:
	gallery = gallery_node
	world = world_node
	view = requested_view
	_run.call_deferred()


func _run() -> void:
	for _frame in 12:
		await get_tree().physics_frame
	var report := {"view": view, "ok": false, "errors": errors,
		"ground_points": 0, "walked": false, "teleported": false}
	if view == "creator":
		await _check_creator(report)
	elif view == "heart":
		await _check_heart(report)
	else:
		errors.append("unknown Galaxy audit view")
	_set_review_camera()
	report.ok = errors.is_empty() and bool(report.walked) \
		and (view != "heart" or bool(report.teleported))
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__ARTEA_GALAXY_AUDIT__ = %s;" % JSON.stringify(report), true)
	print("GALAXY_WEB_AUDIT: %s" % JSON.stringify(report))


func _check_creator(report: Dictionary) -> void:
	var studio := world.get_node_or_null("CreatorsLightStudio") as Node3D
	if studio == null:
		errors.append("Creator studio is missing")
		return
	var deck := studio.get_node_or_null("WalkableDeck") as MeshInstance3D
	var deck_collision := studio.get_node_or_null("WalkableDeckCollision") as StaticBody3D
	var floor := studio.get_node_or_null("StudioFloor") as MeshInstance3D
	if deck == null or deck_collision == null or floor == null \
			or not (deck.material_override is ShaderMaterial) \
			or floor.material_override != deck.material_override:
		errors.append("Creator paving or its solid ground does not cover the island and studio")
		return
	var landmarks := world.get_node_or_null("CreatorsLightQuestLandmarks") as Node3D
	if landmarks == null or landmarks.get_child_count() != 5 \
			or studio.get_node_or_null("StudioBackWall") != null \
			or studio.get_node_or_null("SunRuneOuter") != null:
		errors.append("removed Creator studio props still appear in the Web scene")
		return
	for anchor in landmarks.get_children():
		if anchor.get_child_count() != 0:
			errors.append("removed Creator portal or light props still appear in the Web scene")
			return
	if world.get_node_or_null("EastObservatoryBridge") != null \
			or world.get_node_or_null("EastObservatoryBridgeTwin") != null:
		errors.append("retired Creator lookout bridge is still present")
		return
	var table := studio.get_node_or_null("ArtistMaterialsTable") as Node3D
	if table == null or table.position.distance_to(
			CREATOR + Vector3(115.0, 2.0, 0.0)) > 0.01 \
			or table.get_node_or_null("Top") == null \
			or table.find_children("PaintPot_*", "MeshInstance3D", false, false).size() != 8:
		errors.append("Creator materials table is missing or not aligned on the studio east edge")
		return
	var floor_top := floor.position.y + (floor.mesh as BoxMesh).size.y * 0.5
	for leg_x in [-29.0, 29.0]:
		for leg_z in [-12.0, 12.0]:
			var foot := table.to_global(Vector3(leg_x, 0.0, leg_z))
			if absf(foot.y - world.to_global(Vector3(0.0, floor_top, 0.0)).y) > 0.05:
				errors.append("Creator materials table leg does not meet the studio floor")
				return
	var centre := world.to_global(CREATOR)
	var shader_centre := (deck.material_override as ShaderMaterial).get_shader_parameter(
		"island_center") as Vector2
	if shader_centre.distance_to(Vector2(centre.x, centre.z)) > 0.01:
		errors.append("Creator paving is offset from the gallery island")
		return
	var space := world.get_world_3d().direct_space_state
	for lane_z in [1622.0, 1658.0]:
		var former_span := PhysicsRayQueryParameters3D.create(
			world.to_global(Vector3(825.0, 10.0, lane_z)),
			world.to_global(Vector3(825.0, -20.0, lane_z)))
		if not space.intersect_ray(former_span).is_empty():
			errors.append("retired Creator lookout bridge still has collision")
			return
	for radius in [182.0, 188.0, 194.0]:
		for index in 32:
			var angle := TAU * float(index) / 32.0
			var point := CREATOR + Vector3(cos(angle) * radius, 0.0,
				sin(angle) * radius)
			var ray := PhysicsRayQueryParameters3D.create(
				world.to_global(point + Vector3.UP * 0.15),
				world.to_global(point + Vector3.DOWN * 12.0))
			ray.collision_mask = 1
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or hit.collider != deck_collision \
					or absf(world.to_local(hit.position).y) > 0.15:
				errors.append("unsupported Creator rim point %d at radius %.1f" % [index, radius])
				return
			report.ground_points += 1
	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	if player == null:
		errors.append("gallery player is missing")
		return
	player.set_physics_process(false)
	player.set_process_input(false)
	player.global_position = world.to_global(Vector3(600.0, 3.0, 1480.0))
	player.velocity = Vector3.ZERO
	for _frame in 120:
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	if not player.is_on_floor():
		errors.append("player could not stand on Creator island")
		return
	var returning := false
	var unsupported := 0
	for _frame in 420:
		var local := world.to_local(player.global_position)
		if not returning and local.z >= 1540.0:
			returning = true
		if returning and local.z <= 1480.0:
			report.walked = player.is_on_floor()
			return
		player.velocity.x = 0.0
		player.velocity.z = -WALK_SPEED if returning else WALK_SPEED
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		unsupported = 0 if player.is_on_floor() else unsupported + 1
		if unsupported > 8:
			errors.append("player lost Creator ground at %s" % world.to_local(player.global_position))
			return
		await get_tree().physics_frame
	errors.append("player did not finish Creator island round trip")


func _check_heart(report: Dictionary) -> void:
	var heart := world.get_node_or_null("HeartMelodyTemple") as Node3D
	if heart == null or heart.get_node_or_null("HeartIslandRockMantleCollision") == null:
		errors.append("Heart Melody outer ground lacks solid mass")
		return
	if world.get_node_or_null("NorthObservatoryBridge") != null \
			or world.get_node_or_null("NorthObservatoryBridgeTwin") != null:
		errors.append("retired Heart Melody lookout bridge is still present")
		return
	var former_span := PhysicsRayQueryParameters3D.create(
		world.to_global(Vector3(-165.0, 20.0, 2443.0)),
		world.to_global(Vector3(-165.0, -20.0, 2443.0)))
	if not world.get_world_3d().direct_space_state.intersect_ray(former_span).is_empty():
		errors.append("retired Heart Melody lookout bridge still has collision")
		return
	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	if player == null:
		errors.append("gallery player is missing")
		return
	player.set_physics_process(false)
	player.set_process_input(false)
	player.global_position = world.to_global(HEART + Vector3(0.0, 10.0, 140.0))
	player.velocity = Vector3.ZERO
	for _frame in 120:
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	if not player.is_on_floor() or world.to_local(player.global_position).y < 4.5:
		errors.append("player landed beneath Heart Melody ground")
		return
	for _frame in 180:
		if world.to_local(player.global_position).z >= HEART.z + 168.0:
			report.walked = true
			break
		player.velocity.z = WALK_SPEED
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		await get_tree().physics_frame
		if not player.is_on_floor() or world.to_local(player.global_position).y < 4.5:
			errors.append("player fell through Heart Melody ground")
			return
	if not report.walked:
		errors.append("player could not cross the Heart Melody outer ground")
		return
	var gate := world.get_node_or_null("HeartMelodyWorldGate") as MindSparkWorldGate
	var destination := world.get_node_or_null("HeartMelodyWorld") as Node3D
	if gate == null or destination == null:
		errors.append("Heart Melody teleport or destination is missing")
		return
	var was_enabled := gate.gate_enabled
	gate.set_gate_enabled(true)
	var arrived := gate.teleport_player(player)
	gate.set_gate_enabled(was_enabled)
	report.teleported = arrived and bool(destination.get("built")) \
		and player.global_position.distance_to(
			world.to_global(gate.destination_world_local)) < 0.1
	if not report.teleported:
		errors.append("Heart Melody gate did not carry the player to the built island")


func _set_review_camera() -> void:
	for layer in gallery.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var streaming := world.get_node_or_null("WorldStreamingDirector")
	if streaming != null:
		streaming.set_process(false)
		streaming.show_all_managed_cells()
	var focus := world.to_global(CREATOR if view == "creator" \
		else HEART + Vector3(-110.0, 0.0, 95.0))
	var camera := Camera3D.new()
	camera.name = "GalaxyAuditCamera"
	var studio_view := view == "creator" and OS.has_feature("web") \
		and "studio_view=1" in str(JavaScriptBridge.eval("window.location.search", true))
	if studio_view:
		camera.fov = 67.0
		camera.near = 0.1
		camera.far = 900.0
		world.add_child(camera)
		camera.global_position = world.to_global(CREATOR + Vector3(165.0, 130.0, 190.0))
		camera.look_at(world.to_global(CREATOR + Vector3(0.0, 18.0, 0.0)), Vector3.UP)
		camera.make_current()
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 445.0 if view == "creator" else 590.0
	camera.near = 0.1
	camera.far = 900.0
	world.add_child(camera)
	camera.global_position = focus + Vector3.UP * 420.0
	camera.look_at(focus, Vector3(0.0, 0.0, -1.0))
	camera.make_current()
