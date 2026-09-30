extends SceneTree

class Regions:
	extends Node3D
	var queries := 0
	func get_kingdom_centers() -> Dictionary:
		queries += 1
		return {"mind": Vector3(8000, 0, 8000)}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var regions := Regions.new()
	world.add_child(regions)
	var player := CharacterBody3D.new()
	world.add_child(player)
	var map := preload("res://scripts/art_castle_minimap.gd").new()
	root.add_child(map)
	await process_frame
	map.set_process(false)
	map._world = world
	map._regions = regions
	map._player = player
	map._refresh_landscape_sampling()
	var queries_before := regions.queries
	for i in 1000:
		map._landscape_color(Vector3(i, 0, i))
	assert(regions.queries == queries_before, "Terrain tiles must reuse the per-redraw snapshot")
	assert(map._sample_kingdom_centres.size() == 1, "Missing kingdoms must not paint over the origin")
	world.position.x = 123.0
	map._refresh_landscape_sampling()
	assert((map._sample_world_to_local * Vector3(123, 0, 0)).is_equal_approx(Vector3.ZERO))
	assert(regions.queries == queries_before + 1, "Next redraw refreshes live world data")
	map._refresh_compact_landscape_texture()
	assert(map._compact_landscape_texture != null \
		and map._compact_landscape_image.get_size() == Vector2i(26, 26),
		"Compact terrain must reuse one small texture instead of hundreds of Canvas rectangles")
	assert(int(map.get_meta("compact_landscape_canvas_submissions", 0)) == 1 \
		and int(map.get_meta("compact_landscape_sample_cells", 0)) > 400,
		"Compact terrain must preserve the circular sample coverage in one Canvas submission")
	map._process(1.0 / 60.0)
	var redraws := 0
	for i in 60:
		var before: float = map._redraw_cooldown
		map._process(1.0 / 60.0)
		if map._redraw_cooldown > before: redraws += 1
	assert(redraws <= 13 and redraws >= 9, "Stationary minimap must not redraw at frame rate")
	player.position.x += 10.0
	assert(map._view_moved(), "Large player movement must bypass the cadence limit")
	map._process(0.001)
	assert(map._last_drawn_position.is_equal_approx(player.global_position))
	map._facing_world = Vector2(1, 0)
	map._last_drawn_facing = Vector2(0, 1)
	assert(map._view_moved(), "Turning must bypass the cadence limit")
	map.free()
	world.free()
	print("MINIMAP_RENDER_BUDGET: PASS — one-texture landscape, cached tile queries, refreshed transforms, bounded idle redraws, responsive movement/turns")
	quit()
