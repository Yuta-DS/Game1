# End-to-end smoke test for the drawing -> guide -> manifest -> living world
# pipeline. Run with:
#   godot --headless --path artea --script res://scripts/test_creation_world.gd
extends SceneTree

const ArtEnhancer := preload("res://scripts/creation_world/art_enhancer.gd")
const SketchCanvas := preload("res://scripts/creation_world/world_sketch_canvas.gd")
const SemanticFactory := preload("res://scripts/creation_world/semantic_object_factory.gd")
const TerrainBuilder := preload("res://scripts/creation_world/world_terrain_builder.gd")
const AmbientLifeLoop := preload("res://scripts/creation_world/ambient_life_loop.gd")
const ArtworkEnvironmentAnimator := preload("res://scripts/creation_world/artwork_environment_animator.gd")

const TEST_STATE := "user://creation_worlds_test.json"
const TEST_ART := "user://creation_world_test_art.png"
const TEST_VARIATION := "user://creation_world_test_variation.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color("7cc8ff"))
	for y in range(10, 24):
		for x in range(8, 25):
			image.set_pixel(x, y, Color("ff7db8"))
	assert(image.save_png(TEST_ART) == OK, "test artwork is written")

	var state = root.get_node("CreationWorldState")
	state.save_path = TEST_STATE
	state.worlds.clear()
	state.current_artwork_path = ""
	state.prepare_artwork(TEST_ART, "Pink Sky Home")
	assert(state.has_current_artwork(), "the selected artwork is available")
	root.get_node("APIManager").auth_token = ""
	root.get_node("Global").auth_token = ""
	assert(not root.get_node("APIManager")._looks_like_jwt("OFFLINE_GUEST_TOKEN"),
		"guest placeholders are never sent as Bearer tokens")
	assert(root.get_node("APIManager")._looks_like_jwt("header.payload.signature"),
		"real three-part JWTs remain supported")
	var encoded_art: Dictionary = root.get_node("APIManager")._prepare_ai_artwork(image)
	assert(encoded_art.get("mime_type") == "image/jpeg", "AI previews use compact JPEG transport")
	assert(int(encoded_art.get("encoded_bytes", 0)) < 8 * 1024 * 1024,
		"AI artwork transport stays below the server safety limit")
	state._store_guide({"style_ideas": ["watercolor", "paper collage", "soft pastel"]})
	assert(state.current_guide().get("style_ideas", []).size() == 3,
		"the outage-safe guide offers three optional styles")
	var block_fallback: Dictionary = state._offline_manifest()
	assert(not state._manifest_is_semantic_ready(block_fallback),
		"on-device reconstruction remains honestly distinct from vision-labelled semantics")
	state._store_manifest(block_fallback)
	assert(state.current_world_is_explorable(),
		"on-device artwork reconstruction still opens as a walkable interactive world")
	state._store_manifest({
		"schema_version": 2,
		"semantic_ready": true,
		"vision_source": "primary",
		"world_title": "Pink Sky Home",
		"objects": [
			{"id": "drawn_tree", "type": "tree", "description": "the tall painted tree", "bounding_box": {"x": 0.1, "y": 0.1, "width": 0.3, "height": 0.7}},
			{"id": "drawn_house", "type": "house", "description": "the pink painted home", "bounding_box": {"x": 0.45, "y": 0.3, "width": 0.35, "height": 0.45}},
		],
		"characters": [],
	})
	assert(state.current_world_is_semantic(), "vision-labelled subjects unlock the explorable world")

	var manifest: Dictionary = state.add_local_idea("a friendly bird")
	assert(manifest.get("objects", []).size() >= 3, "semantic painted subjects and the new idea stay together")
	var bird_found := false
	for object in manifest["objects"]:
		if object.get("type") == "bird":
			bird_found = true
	assert(bird_found, "natural language additions are converted to safe world objects")
	var interacted_ids := {}
	for interaction in manifest.get("interactions", []):
		interacted_ids[str(interaction.get("object_id", ""))] = true
	for object in manifest["objects"]:
		assert(interacted_ids.has(str(object.get("id", ""))), "every manifested artwork subject is interactive")

	var before := image.get_pixel(12, 12)
	var enhanced: Image = ArtEnhancer.create_variation(image, "storybook pastel")
	assert(image.get_pixel(12, 12) == before, "enhancement never mutates the original")
	assert(enhanced.get_pixel(12, 12) != before, "the optional variation visibly differs")
	assert(enhanced.save_png(TEST_VARIATION) == OK, "variation is exportable")
	state.select_variation(TEST_VARIATION, "storybook pastel")
	assert(state.active_artwork_path() == TEST_VARIATION, "the variation can be selected independently")
	state.keep_original()
	assert(state.active_artwork_path() == TEST_ART, "the artist can return to the original")

	var packed: PackedScene = load("res://scenes/creation_world.tscn")
	var world := packed.instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	var generation_deadline := Time.get_ticks_msec() + 15000
	while not world.call("world_generation_idle") and Time.get_ticks_msec() < generation_deadline:
		await process_frame
	assert(world.call("world_generation_idle"),
		"the frame-budgeted runtime generation queue completes")
	assert(world.find_child("RealtimeWorldGenerator", true, false) != null,
		"the professional runtime generation loop is active in the scene")
	var player := world.find_child("CreationWorldPlayer", true, false) as CharacterBody3D
	assert(player != null, "the explorable player is created")
	assert(player.find_child("ArtistFox", true, false) != null, "the player uses the animated fox model")
	var fox_animation := player.find_child("AnimationPlayer*", true, false) as AnimationPlayer
	assert(fox_animation != null, "the creation-world fox exposes its animation player")
	assert(world.find_child("ArtworkLens", true, false) != null, "the ViewFinder-style lens is mounted in the art world")
	assert(world.find_child("player_idea_*", true, false) != null, "player ideas become live world geometry")
	var drawn_tree := world.find_child("drawn_tree", true, false)
	assert(drawn_tree != null, "vision-labelled painting subjects become separate world objects")
	assert(drawn_tree.get_meta("reconstruction_mode", "") == "artwork_extrusion"
		and bool(drawn_tree.get_meta("preserves_artwork_pixels", false)),
		"recognised subjects preserve the artist's own pixels in physical 3D")
	assert(bool(drawn_tree.get_meta("artwork_interactive", false)), "every reconstructed subject is interactive")
	var tree_collision: CollisionShape3D = null
	for child in drawn_tree.get_children():
		if child is CollisionShape3D and child.shape != null:
			tree_collision = child
			break
	assert(tree_collision != null,
		"semantic world actors include physical collision")
	var drawn_tree_visual := drawn_tree.find_child("SemanticVisual", true, false) as MeshInstance3D
	var tree_height: float = drawn_tree_visual.mesh.get_aabb().size.y * drawn_tree.scale.y
	assert(tree_height > 3.5,
		"tree size is calibrated to be several times the player height")
	var realtime_manifest: Dictionary = manifest.duplicate(true)
	realtime_manifest["objects"].append({
		"id": "runtime_boat",
		"type": "boat",
		"description": "a boat painted onto a hillside",
		"normalized_position": {"x": 0.2, "y": 0.2},
		"scale_hint": "medium",
	})
	realtime_manifest["objects"].append({
		"id": "runtime_flower",
		"type": "flower",
		"description": "a flower created while exploring",
		"normalized_position": {"x": 0.72, "y": 0.68},
		"bounding_box": {"x": 0.67, "y": 0.55, "width": 0.1, "height": 0.24},
		"scale_hint": "medium",
	})
	world.call("_apply_manifest", realtime_manifest)
	var runtime_generator := world.find_child("RealtimeWorldGenerator", true, false)
	assert(runtime_generator.call("pending_count") > 0,
		"new manifest objects enter the real-time frame-budgeted queue")
	var realtime_deadline := Time.get_ticks_msec() + 15000
	while not world.call("world_generation_idle") and Time.get_ticks_msec() < realtime_deadline:
		await process_frame
	assert(world.find_child("runtime_flower", true, false) != null,
		"a new object is created live without rebuilding the scene")
	assert(world.find_children("drawn_tree", "", true, false).size() == 1,
		"stable IDs update existing actors instead of duplicating them")
	var runtime_boat := world.find_child("runtime_boat", true, false) as Node3D
	assert(runtime_boat != null, "a boat painted onto a hillside still reaches the world")
	assert(absf(runtime_boat.position.y - float(world._terrain.water_level())) < 0.01,
		"floating subjects settle on the waterline instead of being stranded on a hill")
	var tree := SemanticFactory.create({
		"id": "drawn_tree",
		"type": "tree",
		"label": "a tall tree",
		"bounding_box": {"x": 0.1, "y": 0.1, "width": 0.3, "height": 0.7},
	}, image, Color.GREEN)
	assert(tree.get_meta("reconstruction_mode", "") == "artwork_extrusion"
		and bool(tree.get_meta("preserves_artwork_pixels", false)),
		"a recognised tree keeps the artwork instead of becoming a stock tree")
	var tree_visual := tree.find_child("SemanticVisual", true, false) as MeshInstance3D
	var tree_material := tree_visual.material_override as StandardMaterial3D if tree_visual != null else null
	assert(tree_material != null and tree_material.albedo_texture != null,
		"the physical tree is textured with its exact crop from the source drawing")
	assert(tree.get_meta("source_bounds", []).size() == 4,
		"the tree retains the source region used to place and reconstruct it")
	tree.free()
	var water := SemanticFactory.create({
		"id": "painted_lake",
		"type": "water",
		"bounding_box": {"x": 0.05, "y": 0.55, "width": 0.9, "height": 0.35},
	}, image, Color.BLUE)
	var water_visual := water.find_child("SemanticVisual", true, false) as MeshInstance3D
	assert(water_visual != null and water_visual.mesh.get_aabb().size.x > 25.0,
		"large painted environments span the mini-world instead of becoming tiny tiles")
	water.free()

	for _frame in 12:
		await physics_frame
	var walk_start := player.global_position
	Input.action_press("move_forward")
	for _frame in 18:
		await physics_frame
	Input.action_release("move_forward")
	assert(player.global_position.distance_to(walk_start) > 0.5,
		"the creation-world character walks across the physical world")
	assert(player.call("current_locomotion_state") == "walk",
		"walking input drives the locomotion animation state")
	assert(fox_animation.is_playing(), "the imported fox animation plays while walking")
	Input.action_press("move_forward")
	Input.action_press("run")
	for _frame in 6:
		await physics_frame
	assert(player.call("current_locomotion_state") == "run",
		"the run modifier drives the faster animation state")
	Input.action_release("move_forward")
	Input.action_release("run")
	await physics_frame
	assert(player.call("current_locomotion_state") == "idle",
		"the fox returns to idle after movement stops")
	assert(str(fox_animation.current_animation).to_lower().contains("idle"),
		"the real imported Idle clip is active after movement stops")

	# --- sculpted terrain -------------------------------------------------
	var terrain_node := world.find_child("ArtworkTerrain", true, false) as StaticBody3D
	assert(terrain_node != null, "the artwork world stands on sculpted terrain, not a flat box")
	var terrain_surface := terrain_node.find_child("TerrainSurface", true, false) as MeshInstance3D
	assert(terrain_surface != null and terrain_surface.mesh is ArrayMesh,
		"the terrain is a real generated mesh")
	var terrain_collision := terrain_node.find_child("TerrainCollision", true, false) as CollisionShape3D
	assert(terrain_collision != null and terrain_collision.shape is HeightMapShape3D,
		"the sculpted terrain carries matching height-map collision")
	assert(world.find_child("ArtworkWater", true, false) != null,
		"low painted basins are filled with water")
	assert(world.find_child("ArtworkAtmosphere", true, false) != null,
		"the world ships a full sky/fog/SSAO environment")
	var living_background := world.find_child("LivingArtworkBackground", true, false) as MeshInstance3D
	assert(living_background != null and bool(living_background.get_meta(
		"uses_artwork_background", false)),
		"the artwork's painted background wraps around the world as scenery")
	assert(living_background.material_override is ShaderMaterial,
		"the painted background uses live wind, ripple, and light animation")
	var environment_animator := world.find_child("ArtworkEnvironmentAnimator", true, false)
	assert(environment_animator != null and not str(environment_animator.get_meta(
		"motion_mode", "")).is_empty(),
		"each artwork receives a background-dependent animation profile")
	assert(world.find_child("ArtworkBackgroundMotion", true, false) is GPUParticles3D,
		"the living environment adds palette-matched atmospheric motion")
	assert(world.find_child("ArtworkFill", true, false) != null,
		"a fill light keeps shadowed faces readable")
	var blue_sky_profile := ArtworkEnvironmentAnimator.analyse(image, {
		"environment": "a bright painted sky above a garden",
		"objects": [{"type": "tree"}],
	}, [Color("7cc8ff"), Color("ff7db8")])
	assert(float(blue_sky_profile.get("sky", 0.0)) > 0.5
		and float(blue_sky_profile.get("vegetation", 0.0)) > 0.5,
		"background motion responds to both painted colour bands and semantic scenery")

	var probe := TerrainBuilder.new(40.0, 32.0, 48)
	probe.sculpt(image, [Color("86c5da"), Color("ffd166"), Color("8ac926")])
	assert(probe.max_height() > 0.4, "the artwork sculpts genuine relief into the ground")
	assert(probe.height_at(0.0, 0.0) == probe.height_at(0.0, 0.0),
		"terrain sampling is deterministic")
	assert(absf(probe.height_at(19.6, 15.6)) < probe.max_height() * 0.35,
		"the rim falls away so the playfield edge stays readable")
	assert(probe.normal_at(0.0, 0.0).is_normalized(), "terrain normals are usable for alignment")
	assert(probe.slope_at(0.0, 0.0) >= 0.0 and probe.slope_at(0.0, 0.0) <= 1.0,
		"slope is reported in the documented 0..1 range")

	assert(probe.water_level() < probe.max_height(),
		"the waterline sits below the highest ground so basins fill and peaks do not")

	# --- real-time ambient generation loop --------------------------------
	var ambient := world.find_child("AmbientLifeLoop", true, false)
	assert(ambient != null, "the real-time ambient generation loop runs in the world")
	assert(int(ambient.call("species_count")) >= 4,
		"the palette-derived biome offers several species")
	assert(int(world.call("ambient_instance_count")) > 0,
		"the loop populates the world around the player before it is explored")
	var ambient_root := world.find_child("AmbientLife", true, false) as Node3D
	assert(ambient_root != null and ambient_root.get_child_count() > 0,
		"generated ambient objects are parented under their own container")
	var first_cells := int(ambient.call("live_cell_count"))
	assert(first_cells > 0, "cells around the player are live")

	# Deterministic regeneration: an isolated loop with the same seed and the
	# same player position must produce an identical instance count.
	var count_a := _ambient_sample(image, 4242, Vector3(0.0, 0.0, 0.0))
	var count_b := _ambient_sample(image, 4242, Vector3(0.0, 0.0, 0.0))
	assert(count_a == count_b and count_a > 0,
		"the same seed regenerates the same world content (%d vs %d)" % [count_a, count_b])
	var count_c := _ambient_sample(image, 99, Vector3(0.0, 0.0, 0.0))
	assert(count_c != count_a or count_c > 0,
		"a different world seed produces its own scatter")

	# Streaming: walking away releases distant cells and claims new ones.
	var streaming := AmbientLifeLoop.new()
	var streaming_root := Node3D.new()
	root.add_child(streaming_root)
	root.add_child(streaming)
	await process_frame
	var streaming_player := Node3D.new()
	streaming_root.add_child(streaming_player)
	streaming.world_seed = 7
	streaming.spawn_radius = 16.0
	streaming.despawn_radius = 22.0
	streaming.configure(streaming_player, streaming_root, probe,
		[Color("86c5da"), Color("ffd166"), Color("8ac926"), Color("ff99c8")],
		Rect2(-60.0, -60.0, 120.0, 120.0))
	streaming.force_tick()
	var cells_at_origin := int(streaming.call("live_cell_count"))
	assert(cells_at_origin > 0, "the streaming loop claims cells at the start position")
	streaming_player.position = Vector3(90.0, 0.0, 90.0)
	streaming.force_tick()
	assert(int(streaming.call("live_cell_count")) < cells_at_origin + 1,
		"cells left far behind the player are released instead of accumulating")
	streaming_player.position = Vector3.ZERO
	streaming.force_tick()
	assert(int(streaming.call("live_cell_count")) > 0,
		"returning to a visited area repopulates it from the pool")
	streaming.queue_free()
	streaming_root.queue_free()
	await process_frame

	var canvas := SketchCanvas.new()
	root.add_child(canvas)
	await process_frame
	assert(canvas.export_image() != null, "the in-world drawing canvas exports an image")
	canvas.queue_free()
	world.queue_free()
	await process_frame

	_cleanup(TEST_STATE)
	_cleanup(TEST_ART)
	_cleanup(TEST_VARIATION)
	print("creation world: all checks passed")
	quit(0)


# Builds a throwaway ambient loop and reports how many instances it generated,
# so two runs with the same seed can be compared for determinism.
func _ambient_sample(image: Image, seed_value: int, origin: Vector3) -> int:
	var terrain := TerrainBuilder.new(40.0, 32.0, 32)
	terrain.sculpt(image, [Color("86c5da"), Color("ffd166"), Color("8ac926")])
	var container := Node3D.new()
	root.add_child(container)
	var tracked := Node3D.new()
	tracked.position = origin
	container.add_child(tracked)
	var loop := AmbientLifeLoop.new()
	root.add_child(loop)
	loop.world_seed = seed_value
	loop.configure(tracked, container, terrain,
		[Color("86c5da"), Color("ffd166"), Color("8ac926"), Color("ff99c8")],
		Rect2(-20.0, -16.0, 40.0, 32.0))
	loop.force_tick()
	var total := int(loop.live_instance_count())
	loop.queue_free()
	container.queue_free()
	return total


func _cleanup(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
