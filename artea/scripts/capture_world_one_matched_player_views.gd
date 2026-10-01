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
	var evidence_pose := world.get_quest_review_camera_pose(evidence)
	assert(not evidence_pose.is_empty())
	var evidence_eye: Vector3 = evidence_pose.eye
	var evidence_target: Vector3 = evidence_pose.target
	var constellation_center := world.get_zone_position("03_constellation_court")
	assert(Vector2(evidence_eye.x, evidence_eye.z).distance_to(
		Vector2(constellation_center.x, constellation_center.z)) <
		world.get_zone_radius("03_constellation_court"),
		"the matched Evidence Court camera must remain on the playable dais")
	if not await _capture_view(camera, "02_island_two_evidence_court",
		evidence_eye, evidence_target):
		return

	if not await _capture_view(camera, "03_island_three_stormworks_arrival",
		Vector3(245, 27, 25), Vector3(360, 34, 25)):
		return

	if not await _capture_view(camera, "04_island_three_reflection_grove",
		Vector3(520, 27, 15), Vector3(650, 34, -58)):
		return

	var island_three_views := [
		["05_island_three_storm_lens", "world_one.warden_anchor.1"],
		["06_island_three_resonance_forge", "world_one.warden_anchor.2"],
		["07_island_three_lightning_archive", "world_one.warden_anchor.3"],
		["08_island_three_rain_harvest", "world_one.calm_rain_basin"],
		["09_island_three_reflection_operator", "world_one.identity_reflection"],
	]
	for view_spec in island_three_views:
		var quest_object := _find_quest_object(world, str(view_spec[1]))
		assert(quest_object != null, "missing Island 3 review object: %s" % view_spec[1])
		var review_pose := world.get_quest_review_camera_pose(quest_object)
		assert(not review_pose.is_empty(),
			"missing Island 3 review camera pose: %s" % view_spec[1])
		if not await _capture_view(camera, str(view_spec[0]),
			review_pose.eye as Vector3, review_pose.target as Vector3):
			return

	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(STATE_PATH)
	print("WorldOneMatchedPlayerViews: PASS")
	quit()


func _find_quest_object(world: MindSparkWorldOne, save_id: String) -> QuestObjectBase:
	for quest_object in world.get_quest_objects():
		if quest_object.save_id == save_id:
			return quest_object
	return null


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
