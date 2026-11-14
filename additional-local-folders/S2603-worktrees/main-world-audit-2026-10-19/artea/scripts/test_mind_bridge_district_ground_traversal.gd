extends SceneTree

## Regression for the exact route described by the player: leave the Tree of
## Imagination, turn onto MindBridge, then walk into MindSparkDistrict. The real
## gallery fox crosses the bridge/island seam without any jump input.

const START := Vector3(-395.0, 0.0, 1640.0)
const FINISH := Vector3(-600.0, 0.0, 1640.0)
const WALK_SPEED := 16.0
const GRAVITY := 28.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 12:
		await physics_frame

	var floating_world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var player := gallery.get_node("Player3D") as CharacterBody3D
	assert(player.get_node_or_null("FoxVisuals/Fox") != null,
		"the production fox character must perform this traversal")
	player.set_physics_process(false)
	player.set_process_input(false)

	var start_global := floating_world.to_global(START)
	var finish_global := floating_world.to_global(FINISH)
	player.global_position = start_global + Vector3.UP * 2.5
	player.velocity = Vector3.ZERO
	for _frame in 90:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			break
	assert(player.is_on_floor(), "the real player must settle on MindBridge")
	var settled_y := player.global_position.y
	var peak_y := settled_y
	var best_distance := _horizontal_distance(player.global_position, finish_global)
	var stalled_frames := 0

	for _frame in 900:
		var offset := finish_global - player.global_position
		offset.y = 0.0
		if offset.length() < 1.25:
			break
		var direction := offset.normalized()
		player.velocity.x = direction.x * WALK_SPEED
		player.velocity.z = direction.z * WALK_SPEED
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		peak_y = maxf(peak_y, player.global_position.y)
		var distance := _horizontal_distance(player.global_position, finish_global)
		if distance < best_distance - 0.02:
			best_distance = distance
			stalled_frames = 0
		else:
			stalled_frames += 1
		assert(stalled_frames < 90,
			"the fox jammed while walking from MindBridge onto the Mind island")
		await physics_frame

	assert(_horizontal_distance(player.global_position, finish_global) < 1.25,
		"the fox must reach the Mind district center without jumping")
	assert(peak_y <= settled_y + 0.15,
		"the bridge-to-island route must remain level and require no step-up")
	assert(player.is_on_floor(), "the fox must finish grounded on the continuous island deck")
	print("MindBridgeDistrictGroundTraversal: PASS — real fox walked bridge to centered Mind ground without jumping")
	quit()


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
