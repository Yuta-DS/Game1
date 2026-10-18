extends SceneTree


const GALLERY_SCENE := "res://scenes/art_gallery_3d_inprogress.tscn"
const WALK_SPEED := 22.0
const GRAVITY := 28.0
const HEART := Vector3(0.0, 0.0, 2290.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gallery := (load(GALLERY_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(gallery)
	current_scene = gallery
	for _frame in 12:
		await physics_frame
	var world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var player := gallery.get_node("Player3D") as CharacterBody3D
	var heart := world.get_node("HeartMelodyTemple") as Node3D
	var heart_ground := heart.get_node("HeartIslandRockMantle") as MeshInstance3D
	var heart_finish := heart_ground.material_override as ShaderMaterial
	if heart_finish == null or heart_finish.shader.resource_path != \
			"res://shaders/heart_island_ground.gdshader":
		_fail("Heart Melody ground is missing its finished surface")
		return
	var north := world.get_node("NorthObservatory") as Node3D
	if north.get_node_or_null("CompassRing") != null \
			or north.get_node_or_null("SkyCypress") != null:
		_fail("Heart observatory still has the gold ring or purple decoration")
		return
	if not (north.get_node("WalkableDeck") as MeshInstance3D).material_override \
			is ShaderMaterial:
		_fail("Heart observatory ground is unfinished")
		return
	if heart.get_node_or_null("HeartIslandRockMantleCollision") == null:
		_fail("the visible outer Heart Melody ground has no solid mass")
		return
	player.set_physics_process(false)
	player.set_process_input(false)
	player.global_position = world.to_global(Vector3(0.0, 7.0, 2108.0))
	player.velocity = Vector3.ZERO
	for _frame in 120:
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			break
	if not player.is_on_floor():
		_fail("player cannot stand at the Heart bridge arrival")
		return
	var unsupported_frames := 0
	var walking_to_garden := true
	for _frame in 900:
		var local := world.to_local(player.global_position)
		if walking_to_garden and local.z >= 2220.0:
			walking_to_garden = false
		if not walking_to_garden and local.z <= 2108.0:
			if not await _walk_outer_mantle(player, world):
				return
			print("HEART_MELODY_GROUND_WALK: PASS — player crossed bridge, conservatory, garden, and outer rock ground")
			quit()
			return
		player.velocity.z = WALK_SPEED if walking_to_garden else -WALK_SPEED
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		await physics_frame
		local = world.to_local(player.global_position)
		unsupported_frames = 0 if player.is_on_floor() else unsupported_frames + 1
		if unsupported_frames > 8:
			_fail("floor vanished on the Heart Melody approach at %s" % local)
			return
		if local.z >= 2150.0 and local.z <= 2200.0 and local.y < 4.8:
			_fail("player passed underneath the conservatory terrace at %s" % local)
			return
	_fail("player could not cross the Heart Melody ground; last position=%s" % world.to_local(player.global_position))


func _walk_outer_mantle(player: CharacterBody3D, world: Node3D) -> bool:
	player.global_position = world.to_global(HEART + Vector3(0.0, 10.0, 140.0))
	player.velocity = Vector3.ZERO
	for _frame in 120:
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			break
	if not player.is_on_floor() or world.to_local(player.global_position).y < 4.5:
		_fail("player landed beneath the visible outer Heart Melody ground")
		return false
	for _frame in 180:
		var local := world.to_local(player.global_position)
		if local.z >= HEART.z + 168.0:
			return true
		player.velocity.z = WALK_SPEED
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		await physics_frame
		if not player.is_on_floor() or world.to_local(player.global_position).y < 4.5:
			_fail("player fell through the visible outer Heart Melody ground")
			return false
	_fail("player could not cross the outer Heart Melody ground")
	return false


func _fail(message: String) -> void:
	push_error("HEART_MELODY_GROUND_WALK: " + message)
	quit(1)
