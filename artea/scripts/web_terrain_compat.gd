extends Node

const WEB_TERRAIN_MESH_PATH := "res://resources/web_hub_terrain.res"
const GRASS_MATERIAL_PATH := "res://assets3D/kkNatureForest/Stylized3DGrass.tres"

# The Grass scatter is authored at 60500 instances, and 220 of its 2320
# proportion units are tree_1_c_color_12 - about 5700 full-size trees, which is
# what walls the horizon in. Thin both for Web.
const WEB_GRASS_AMOUNT := 24000
const WEB_GRASS_TREE_PROPORTION := 15

# Blade size. ProtonScatter only offers a uniform multiplier
# (scatter_item.gd process_transform scales by Vector3.ONE * this), so this
# shortens and narrows together rather than squashing height alone. Applied as
# a factor so the authored A/B size difference (1.0 vs 1.15) is preserved.
const WEB_GRASS_SCALE := 0.55

var _collision_built := false


func _enter_tree() -> void:
	if not OS.has_feature("web"):
		return

	# The ground has to be collidable before anything else is ready, not in
	# _ready() alongside the visual mesh. ProtonScatter places instances by
	# raycasting onto whatever solid exists at the moment it builds, and with
	# Terrain3D's own collision switched off just above, this heightmap is the
	# only ground there is. Building it in _ready() left the two racing on node
	# order, and a scatter that wins the race projects onto nothing.
	var early_mesh := load(WEB_TERRAIN_MESH_PATH) as ArrayMesh
	if early_mesh != null:
		_add_collision(early_mesh)


func _apply_web_scatter_tuning() -> void:
	# This has to run from _ready(), not _enter_tree().
	#
	# WebTerrainCompatibility is declared at line 357 of New_Hub_World.tscn and
	# Environment at line 402, so the sibling does not exist yet while this node
	# is entering the tree - get_node_or_null("../Environment") returns null and
	# every line below is skipped. That silently disabled this whole block for as
	# long as it has existed, including the original scatter-disabling code and
	# the Terrain3D collision_mode reset, neither of which ever ran on Web.
	#
	# _ready() is safe: the whole scene is in the tree by then, and because this
	# node is declared before Environment its _ready() still fires before the
	# scatter roots ready themselves and build.
	var environment := get_node_or_null("../Environment")
	if environment != null:
		# ProtonScatter has to build on Web, not be switched off.
		#
		# This block used to disable both scatter roots outright, which is why
		# the Web build had no grass and no trees at all while desktop looked
		# correct. The three things that actually break scatter on Web are
		# fixed individually below; the roots themselves stay live.
		for child_name in ["Grass", "Objects"]:
			var scatter_root := environment.get_node_or_null(child_name)
			if scatter_root == null:
				continue

			# ProtonScatter spawns a real Thread to run its build
			# (scatter.gd:148-153). The Web export runs without WASM thread
			# support - terrain_3d's web binary is non-threaded-only - so that
			# Thread never executes while is_thread_running() reports true
			# forever. The initial build then produces nothing and every later
			# rebuild() just sets a flag and returns. Its own escape hatch runs
			# the same work synchronously.
			if "dbg_disable_thread" in scatter_root:
				scatter_root.dbg_disable_thread = true

			# show_output_in_tree is off, so the generated instances are not
			# saved into the scene. Web therefore has to build them at load or
			# there is nothing to render and nothing to collide with. This was
			# previously forced to false, which guaranteed an empty world even
			# without the disable above.
			if "force_rebuild_on_load" in scatter_root:
				scatter_root.force_rebuild_on_load = true

			# The Relax modifier is O(n^2) on the CPU and only avoids that via
			# a compute shader, which needs a RenderingDevice backend. Web is
			# on gl_compatibility, so create_local_rendering_device() returns
			# null and it silently falls back to the CPU path - measured at
			# 10-14 seconds per hub load on this scene's 3000-point Grass node.
			if "modifier_stack" in scatter_root:
				var stack = scatter_root.modifier_stack
				if stack != null and "stack" in stack:
					for modifier in stack.stack:
						var script = modifier.get_script() if modifier else null
						if script != null and script.resource_path.ends_with("relax.gd"):
							modifier.iterations = 0
						# Thin the grass field. 60500 instances is a desktop
						# figure; on the single-threaded Web runtime it is both
						# a long synchronous build and a lot of draw setup.
						if child_name == "Grass" and "amount" in modifier:
							modifier.amount = WEB_GRASS_AMOUNT

			if child_name == "Grass":
				_retune_grass_items(scatter_root)

			# Trees are authored as "Create Copies", which instantiates a whole
			# scene per instance. That is fine on desktop and far too heavy for
			# the single-threaded Web runtime, so Web renders them through the
			# MultiMesh path instead. That path builds no nodes, so it also
			# builds no colliders - keep_static_colliders is what registers the
			# source scene's shapes straight with the PhysicsServer. Both are
			# required: scatter.gd:567 bails if either the flag is off or
			# render_mode is still 1, and with the flag off every instanced
			# tree is a hologram you walk through.
			if child_name == "Objects":
				if "keep_static_colliders" in scatter_root:
					scatter_root.keep_static_colliders = true
				if "render_mode" in scatter_root:
					scatter_root.render_mode = 0

		# Terrain3D's own rendering still cannot run here (see _ready), and its
		# collision is replaced by the heightmap built from the baked mesh.
		var terrain = environment.get_node_or_null("Terrain3D")
		if terrain != null:
			terrain.visible = false
			terrain.process_mode = Node.PROCESS_MODE_DISABLED
			terrain.set("collision_mode", 0)


func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return
	var dome := get_node_or_null("WebSkyDome") as MeshInstance3D
	var camera := get_viewport().get_camera_3d()
	if dome != null and camera != null:
		dome.global_position = camera.global_position


func _ready() -> void:
	if not OS.has_feature("web"):
		return

	_apply_web_scatter_tuning()

	var terrain = get_node_or_null("../Environment/Terrain3D")
	if terrain == null:
		push_warning("Web terrain mesh could not find Terrain3D.")
		return

	# Terrain3D's region-map uniform exceeds WebGL2's 16 KiB uniform-block
	# floor even with its minimum shader, so Web gets a compact mesh sampled
	# from the same data instead.
	#
	# Its collision is NOT still live here: _enter_tree() above already set
	# collision_mode to 0 and disabled the node's processing. Everything the
	# player stands on from this point is WebTerrainCollision, built below.
	terrain.visible = false
	var web_mesh := load(WEB_TERRAIN_MESH_PATH) as ArrayMesh
	if web_mesh == null:
		push_warning("Web terrain mesh asset is missing.")
		return
	var fallback := MeshInstance3D.new()
	fallback.name = "WebTerrainMesh"
	fallback.mesh = web_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.92
	fallback.material_override = material
	add_child(fallback)
	_add_collision(web_mesh)  # no-op if _enter_tree already built it
	_add_web_sky_dome()

	var day_night := get_node_or_null("../Environment/DayNite")
	if day_night != null:
		var animation_player := day_night.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if animation_player != null:
			animation_player.stop()
		var world_environment := day_night.get_node_or_null("WorldEnvironment") as WorldEnvironment
		if world_environment != null and world_environment.environment != null:
			world_environment.environment.background_mode = Environment.BG_COLOR
			world_environment.environment.background_color = Color(0.38, 0.67, 0.92)
			world_environment.environment.sky = null
	call_deferred("_apply_web_environment")


func _apply_web_environment() -> void:
	# HubWorld's root script duplicates and retunes the shared Environment in
	# its own _ready(), after this child has run. Re-apply the Web-safe sky once
	# all scene-ready hooks have completed.
	var world_environment := get_node_or_null(
		"../Environment/DayNite/WorldEnvironment") as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		return
	var environment := world_environment.environment
	var sky_color := Color(0.38, 0.67, 0.92)
	RenderingServer.set_default_clear_color(sky_color)
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.background_color = sky_color
	environment.sky = null
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.82, 0.92)


func _add_web_sky_dome() -> void:
	# Some Compatibility/WebGL drivers clear BG_COLOR/BG_CLEAR_COLOR to white
	# when the original procedural Sky resource has already initialized. An
	# inexpensive inward-facing dome makes the fallback deterministic.
	var dome_mesh := SphereMesh.new()
	# Keep the dome inside the camera far plane and follow the camera so the
	# player can travel without ever reaching its edge.
	dome_mesh.radius = 1000.0
	dome_mesh.height = 2000.0
	dome_mesh.radial_segments = 24
	dome_mesh.rings = 12
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.38, 0.67, 0.92)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	material.disable_receive_shadows = true
	var dome := MeshInstance3D.new()
	dome.name = "WebSkyDome"
	dome.mesh = dome_mesh
	dome.material_override = material
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)


func _add_collision(mesh: ArrayMesh) -> void:
	if _collision_built:
		return
	var arrays := mesh.surface_get_arrays(0)
	var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var side := int(round(sqrt(float(source_vertices.size()))))
	if side < 2 or side * side != source_vertices.size():
		push_warning("Web terrain mesh cannot be sampled for collision.")
		return

	# The bake writes a regular grid, so a heightmap describes it exactly and a
	# triangle soup never needed to be involved.
	#
	# The previous version built a ConcavePolygonShape3D from every fourth
	# vertex. That put physics on 32 m triangles underneath an 8 m surface, and
	# because it sampled rather than averaged, any rise or dip narrower than a
	# coarse cell did not exist to the character body at all: the player walked
	# through visible mounds, floated over visible hollows, sank wherever a
	# chord cut below a convex ridge, and caught on the seams between coarse
	# triangles - which read as wall to floor_max_angle and kicked _try_step_up
	# in on flat ground.
	#
	# A heightmap stores one float per vertex and needs no BVH, so matching the
	# visual mesh vertex for vertex here is cheaper than the coarse soup it
	# replaces, not more expensive.
	var heights := PackedFloat32Array()
	heights.resize(source_vertices.size())
	for index in source_vertices.size():
		heights[index] = source_vertices[index].y

	var shape := HeightMapShape3D.new()
	shape.map_width = side
	shape.map_depth = side
	shape.map_data = heights

	# HeightMapShape3D is one unit per cell and centres itself on its own
	# origin, which already matches the bake's centred grid. Read the real
	# spacing off the mesh rather than hardcoding it, so this keeps agreeing
	# with GRID_SPACING if the bake changes. Y stays 1.0 - the stored heights
	# are already world units and must not be scaled.
	var spacing := source_vertices[1].x - source_vertices[0].x
	if spacing <= 0.0:
		push_warning("Web terrain mesh has no usable grid spacing.")
		return

	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.scale = Vector3(spacing, 1.0, spacing)

	var body := StaticBody3D.new()
	body.name = "WebTerrainCollision"
	body.collision_layer = 3
	body.add_child(collision)
	add_child(body)
	_collision_built = true


func _retune_grass_items(scatter_root: Node) -> void:
	# Two separate faults live in the Grass scatter's item list.
	#
	# 1. grass.glb ships a StandardMaterial3D whose albedo is pure white with no
	#    texture and no vertex-colour albedo, so every blade renders white and
	#    reads as invisible against the ground. The stylised material that was
	#    authored for it sits unused next to the mesh; assign it here.
	# 2. The item named "ScatterItemBush" is not a bush - it points at
	#    assets3D/trees/tree_1_c_color_12.tscn. At proportion 220 of 2320 it
	#    produces thousands of full-size trees out of the *grass* scatter, which
	#    is what fills the skyline rather than the 188-instance tree scatter.
	var grass_material := load(GRASS_MATERIAL_PATH) as Material
	for item in scatter_root.get_children():
		if not ("proportion" in item and "path" in item):
			continue
		var source_path := str(item.path)
		if source_path.begins_with("res://assets3D/trees/"):
			item.proportion = WEB_GRASS_TREE_PROPORTION
		else:
			if grass_material != null and "override_material" in item:
				item.override_material = grass_material
			if "source_scale_multiplier" in item:
				item.source_scale_multiplier *= WEB_GRASS_SCALE
