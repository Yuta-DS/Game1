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
	var bridge := world.get_node("CreatorBridge") as Node3D
	var studio := world.get_node("CreatorsLightStudio") as Node3D
	var player := gallery.get_node("Player3D") as CharacterBody3D
	if bridge.get_meta("visual_style", "") != "creator_studio_processional_bridge_v1" \
			or studio.get_node_or_null("CreatorStudioGroundFinish/CreatorArrivalApronCollision") == null:
		_fail("finished Creator bridge or continuous studio arrival is missing")
		return
	var first_easel := studio.get_node("PaintingEasel_00") as Node3D
	if first_easel.get_node_or_null("PaintedSky") == null \
			or absf(first_easel.rotation.y - PI * 0.5) > 0.01:
		_fail("studio painting finish is missing or faces away from the bridge")
		return
	for old_wall in bridge.find_children("SafetyRail", "MeshInstance3D", false, false):
		if (old_wall as MeshInstance3D).visible:
			_fail("unfinished white bridge wall is still visible")
			return
	player.set_physics_process(false)
	player.set_process_input(false)
	player.global_position = world.to_global(Vector3(224.0, 3.0, 1640.0))
	player.velocity = Vector3.ZERO
	for _frame in 120:
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			break
	if not player.is_on_floor():
		_fail("player cannot stand at Creator bridge entrance")
		return
	var airborne_frames := 0
	var best_x := world.to_local(player.global_position).x
	var stalled_frames := 0
	var walking_to_studio := true
	for _frame in 1800:
		var local := world.to_local(player.global_position)
		if walking_to_studio and local.x >= 461.0:
			if not player.is_on_floor() or local.y < 1.9:
				_fail("player reached studio without a supported floor: %s" % local)
				return
			walking_to_studio = false
			best_x = local.x
			stalled_frames = 0
		if not walking_to_studio and local.x <= 224.0:
			if not player.is_on_floor():
				_fail("player returned to bridge entrance without a supported floor")
				return
			print("CREATOR_BRIDGE_STUDIO_WALK: PASS — player crossed between bridge and studio in both directions without jumping")
			quit()
			return
		player.velocity.x = WALK_SPEED if walking_to_studio else -WALK_SPEED
		player.velocity.z = 0.0
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		airborne_frames = 0 if player.is_on_floor() else airborne_frames + 1
		if airborne_frames > 8:
			_fail("unsupported floor transition at %s" % world.to_local(player.global_position))
			return
		local = world.to_local(player.global_position)
		if (walking_to_studio and local.x > best_x + 0.01) \
				or (not walking_to_studio and local.x < best_x - 0.01):
			best_x = local.x
			stalled_frames = 0
		else:
			stalled_frames += 1
		if stalled_frames > 90:
			_fail("player blocked at %s" % local)
			return
		await physics_frame
	_fail("player did not complete the bridge round trip; last x=%.2f" % best_x)


func _fail(message: String) -> void:
	push_error("CREATOR_BRIDGE_STUDIO_WALK: " + message)
	quit(1)
