extends SceneTree
## Runs against an exported PCK with `--main-pack` to prove that resources
## loaded by path at runtime survived the dependency-scoped Web export.

const WORLD_SCENE := "res://scenes/mind_spark/mind_spark_world_one.tscn"
const GALLERY_SCENE := "res://scenes/art_gallery_3d_inprogress.tscn"
const REQUIRED_DYNAMIC_RESOURCES := [
	"res://default_bus_layout.tres",
	"res://resources/web_hub_surface_map.png",
	"res://scenes/art_gallery_3d_inprogress.tscn",
	"res://scenes/popThoughtsMenu.tscn",
	"res://scenes/music_minigame.tscn",
	"res://scenes/drawing_tool.tscn",
	"res://scenes/heart_melody/heart_garden_entry.tscn",
	"res://scenes/viewfinder/crown_of_life_story.tscn",
	"res://assets3D/characters/milo_exact_target_parts.glb",
	"res://assets3D/crown_line_train/crown_line_runtime_textured.glb",
	"res://assets3D/crown_line_train/crown_line_engine_cover_blueprint.json",
	"res://assets3D/trees/tree_1_c_color_12.tscn",
	"res://assets3D/trees/tree_2_b_color_12.tscn",
	"res://assets3D/trees/tree_3_a_color_12.tscn",
	"res://assets3D/trees/tree_4_a_color_12.tscn",
	"res://assets3D/tree_of_life/glb/artea_tree_of_life.glb",
	"res://assets3D/tree_of_life/trunk_core/glb/simple_trunk_core.glb",
	"res://assets3D/tree_of_life/heart_crystal/glb/realistic_heart_crystal.glb",
	"res://assets3D/tree_of_life/canopy/glb/crystal_branch_canopy.glb",
	"res://assets3D/tree_of_life/gravity_leaf_bough/glb/gravity_leaf_bough_runtime.glb",
	"res://assets3D/castle_galaxy_bridge/glb/castle_galaxy_bridge_gate.glb",
	"res://assets3D/tree_processional_bridge/glb/tree_processional_bridge.glb",
	"res://assets/audio/tree_of_life_christmas_ambience.wav",
	"res://assets/SFX/fairy dust.ogg",
	"res://assets/audio/Ocean_Ambience_Loop.ogg",
	"res://assets3D/mind_spark/celestial_islands_v08/shared_paving.glb",
	"res://assets3D/mind_spark/celestial_islands_v11/island_01.glb",
	"res://assets3D/mind_spark/celestial_verdant_v12/island_02.glb",
	"res://assets3D/mind_spark/celestial_astral_v16/island_03.glb",
	"res://assets3D/mind_spark/celestial_dawn_v17/island_04.glb",
	"res://assets3D/mind_spark/celestial_islands_v11/island_05.glb",
	"res://assets3D/mind_spark/celestial_islands_v11/island_06.glb",
	"res://assets3D/mind_spark/anycreature/root_stalker.glb",
	"res://assets3D/mind_spark/unfinished_light/inspection_bay/inspection_bay.glb",
	"res://assets3D/mind_spark/unfinished_light/recorder_bay/recorder_bay.glb",
	"res://assets3D/mind_spark/unfinished_light/tester_bay/tester_bay.glb",
	"res://assets3D/mind_spark/unfinished_light/perspective_bay/perspective_bay.glb",
	"res://assets3D/mind_spark/unfinished_light/projector/projector.glb",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for path in REQUIRED_DYNAMIC_RESOURCES:
		assert(ResourceLoader.exists(path), "Web pack omitted runtime resource: %s" % path)
		if not path.contains("/unfinished_light/"):
			assert(load(path) != null, "Web pack cannot load runtime resource: %s" % path)
	var quest_definitions := DirAccess.get_files_at(
		"res://resources/mind_spark/quest_objects")
	assert(quest_definitions.size() >= 12,
		"Web pack must contain all twelve quest definition resources")
	var gallery_packed := load(GALLERY_SCENE) as PackedScene
	assert(gallery_packed != null, "Web pack can load the production gallery entry")
	var gallery := gallery_packed.instantiate()
	root.add_child(gallery)
	for _frame in 8:
		await process_frame
	await physics_frame
	var floating_world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var player := gallery.get_node("Player3D") as CharacterBody3D
	var world := floating_world.get_node("MindSparkWorldOne") as MindSparkWorldOne
	assert(world != null, "exported gallery mounts World One")
	var arrival := world.to_global(world.get_player_arrival_local())
	var spawn_offset := Vector2(
		player.global_position.x - arrival.x,
		player.global_position.z - arrival.z).length()
	assert(spawn_offset < 0.25,
		"exported player starts at World One: player=%s arrival=%s" \
		% [str(player.global_position), str(arrival)])
	assert((world.call("get_quest_objects") as Array).size() == 15,
		"exported World One mounts all fifteen quest objects")
	for path in REQUIRED_DYNAMIC_RESOURCES:
		if path.contains("/unfinished_light/"):
			assert(load(path) != null,
				"Web pack cannot load registered research resource: %s" % path)
	for node_name in ["ProductionInspectionBay", "ProductionRecorderBay",
			"ProductionTesterBay", "ProductionPerspectiveBay", "ProductionLivingProjector"]:
		assert(world.find_child(node_name, true, false) != null,
			"exported World One mounts %s" % node_name)
	print("WEB PACK SMOKE: PASS — scoped pack opens the gallery at World One with six islands and 15 quests")
	gallery.queue_free()
	await process_frame
	quit(0)
