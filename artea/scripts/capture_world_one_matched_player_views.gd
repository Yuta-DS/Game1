extends SceneTree

const OUTPUT_DIR := "res://artifacts/world_one_matched_player_views"
const STATE_PATH := "user://capture_world_one_matched_player_views.json"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1400, 788)
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(STATE_PATH)

	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") \
		as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = STATE_PATH
	world.get_node("QuestController").enabled = false
	stage.add_child(world)
	world.set_island_two_story_state("truth_materialised")
	world.set_quest_gate_open(1, true)
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false

	var containing := load("res://scenes/art_castle_floating_world.tscn").instantiate() as Node3D
	for node_name in ["WorldEnvironment", "Sun", "FillLight"]:
		var node := containing.get_node(node_name)
		containing.remove_child(node)
		node.owner = null
		stage.add_child(node)
	containing.free()

	var camera := Camera3D.new()
	camera.near = .1
	camera.far = 5000.0
	camera.fov = 62.0
	stage.add_child(camera)
	camera.make_current()
	for _frame in 12:
		await process_frame

	var island_one_hero := world.find_child("EchoGardenHeroBenchmark", true, false) as Node3D
	assert(island_one_hero != null)
	if not await _capture_view(camera, "01_island_one_tree_court",
		island_one_hero.global_position + Vector3(50, 6, 100),
		island_one_hero.global_position + Vector3(0, 18, 0)):
		return

	var evidence := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.EVIDENCE_SCANNER)
	assert(evidence != null)
	var evidence_parent := evidence.get_parent() as Node3D
	var evidence_approach: Vector3 = evidence.get_meta("operator_approach_local")
	# Quest objects are enlarged presentation models. Applying a camera offset
	# through the object's scaled transform put the review camera outside the
	# raised evidence dais, where its vertical rim filled the lower third of the
	# frame. Anchor the shot to the real, unscaled operator position used by the
	# production player instead.
	var evidence_operator := evidence_parent.to_global(evidence_approach)
	var evidence_outward := evidence_operator - evidence.global_position
	evidence_outward.y = 0.0
	evidence_outward = evidence_outward.normalized()
	# Match the production third-person boom: the camera sits behind the capsule,
	# while the capsule itself remains at the authored interaction point.
	var evidence_eye := evidence_operator + evidence_outward * 8.0 + Vector3.UP * 6.5
	var evidence_target := evidence.global_position + Vector3.UP * 5.0
	var constellation_center := world.get_zone_position("03_constellation_court")
	assert(Vector2(evidence_eye.x, evidence_eye.z).distance_to(
		Vector2(constellation_center.x, constellation_center.z)) <
		world.get_zone_radius("03_constellation_court"),
		"the matched Evidence Court camera must remain on the playable dais")
	if not await _capture_view(camera, "02_island_two_evidence_court",
		evidence_eye, evidence_target):
		return

	if not await _capture_view(camera, "03_island_three_stormworks_arrival",
		Vector3(300, 27, 28), Vector3(430, 35, 25)):
		return

	if not await _capture_view(camera, "04_island_three_reflection_grove",
		Vector3(520, 27, 15), Vector3(650, 34, -58)):
		return

	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(STATE_PATH)
	print("WorldOneMatchedPlayerViews: PASS")
	quit()


func _capture_view(camera: Camera3D, file_name: String,
		eye: Vector3, target: Vector3) -> bool:
	camera.global_position = eye
	camera.look_at(target, Vector3.UP)
	for _frame in 45:
		await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image == null:
		push_error("Matched player capture requires a rendering display: %s" % file_name)
		quit(1)
		return false
	var output_path := "%s/%s.png" % [OUTPUT_DIR, file_name]
	if image.save_png(output_path) != OK:
		push_error("Matched player capture could not write %s" % output_path)
		quit(1)
		return false
	return true
