extends Node

const WEB_TERRAIN_MESH_PATH := "res://resources/web_hub_terrain.res"
const COLLISION_SAMPLE_STEP := 4


func _enter_tree() -> void:
	if not OS.has_feature("web"):
		return
	# ProtonScatter's editor-authored stacks regenerate a very large number of
	# instances during scene startup. On the single-threaded Web runtime that
	# blocks the main loop long enough for browsers to kill the tab. The baked
	# terrain and the authored landmarks remain; only desktop scatter generation
	# is removed from this runtime.
	var environment := get_node_or_null("../Environment")
	if environment != null:
		# Only ProtonScatter's *generation* is a problem on the single-threaded
		# Web runtime, not the nodes themselves.  Freeing these subtrees also
		# destroyed every hand-placed child underneath them - bridges, props and
		# other authored landmarks - which is why they vanished on Web while
		# looking correct on desktop.
		#
		# Disable the scatter roots so they never kick off a rebuild, and
		# reparent anything the author placed by hand so it survives.
		for child_name in ["Grass", "Objects"]:
			var scatter_root := environment.get_node_or_null(child_name)
			if scatter_root == null:
				continue
			for authored in _authored_children(scatter_root):
				var keep_transform: Transform3D = (authored as Node3D).global_transform if authored is Node3D else Transform3D()
				scatter_root.remove_child(authored)
				environment.add_child(authored)
				authored.owner = environment.owner
				if authored is Node3D:
					authored.global_transform = keep_transform
			scatter_root.process_mode = Node.PROCESS_MODE_DISABLED
			scatter_root.visible = false
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

	var terrain = get_node_or_null("../Environment/Terrain3D")
	if terrain == null:
		push_warning("Web terrain mesh could not find Terrain3D.")
		return

	# Terrain3D's region-map uniform exceeds WebGL2's 16 KiB uniform-block
	# floor even with its minimum shader. Keep its collision/data active, but
	# replace its Web rendering with a compact mesh sampled from the same data.
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
	_add_collision(web_mesh)
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
	var arrays := mesh.surface_get_arrays(0)
	var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var side := int(round(sqrt(float(source_vertices.size()))))
	if side < 2 or side * side != source_vertices.size():
		push_warning("Web terrain mesh cannot be sampled for collision.")
		return
	var coarse_cells := int((side - 1) / COLLISION_SAMPLE_STEP)
	var faces := PackedVector3Array()
	faces.resize(coarse_cells * coarse_cells * 6)
	var face_index := 0
	for z_index in range(coarse_cells):
		for x_index in range(coarse_cells):
			var source_x := x_index * COLLISION_SAMPLE_STEP
			var source_z := z_index * COLLISION_SAMPLE_STEP
			var top_left := source_z * side + source_x
			var top_right := top_left + COLLISION_SAMPLE_STEP
			var bottom_left := top_left + COLLISION_SAMPLE_STEP * side
			var bottom_right := bottom_left + COLLISION_SAMPLE_STEP
			for source_index in [top_left, top_right, bottom_left,
					top_right, bottom_right, bottom_left]:
				faces[face_index] = source_vertices[source_index]
				face_index += 1
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = "WebTerrainCollision"
	body.collision_layer = 3
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _authored_children(scatter_root: Node) -> Array:
	# ProtonScatter's own machinery is its ScatterShape/ScatterItem children and
	# the MultiMeshInstance3D output it generates. Everything else under the
	# root was placed by hand in the editor and must be preserved.
	var authored: Array = []
	for child in scatter_root.get_children():
		var name_text := str(child.name)
		if name_text.begins_with("ScatterShape") or name_text.begins_with("ScatterItem"):
			continue
		if child is MultiMeshInstance3D:
			continue
		authored.append(child)
	return authored
