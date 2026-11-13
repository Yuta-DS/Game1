extends SceneTree


func _init() -> void:
	var mesh := load("res://resources/web_hub_terrain.res") as ArrayMesh
	if mesh == null or mesh.get_surface_count() != 1:
		push_error("WEB_HUB_TERRAIN_ASSET_TEST: baked mesh is missing or malformed")
		quit(1)
		return
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if vertices.size() < 250000:
		push_error("WEB_HUB_TERRAIN_ASSET_TEST: baked mesh is unexpectedly sparse")
		quit(1)
		return
	var minimum_height := INF
	var maximum_height := -INF
	for vertex in vertices:
		minimum_height = minf(minimum_height, vertex.y)
		maximum_height = maxf(maximum_height, vertex.y)
	if maximum_height - minimum_height < 20.0:
		push_error("WEB_HUB_TERRAIN_ASSET_TEST: terrain is effectively flat")
		quit(1)
		return
	print("WEB_HUB_TERRAIN_ASSET_TEST: PASS — %d vertices, height %.2f to %.2f" % [
		vertices.size(), minimum_height, maximum_height])
	quit()
