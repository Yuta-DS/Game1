extends RefCounted

## Forces the renderer to compile a scene's shaders while the loading screen is
## still up, instead of the first time each one is drawn in gameplay.
##
## Deliberately has no `class_name`, for the same reason as scene_loader.gd and
## world_streaming_director.gd: the headless `--script` suites run without the
## editor-generated global class cache.
##
## Why
## ---
## The Compatibility renderer - the only one the Web export can use - compiles a
## material's shader synchronously the first time it actually draws with it.
## loading_scene.gd already notes this and waits for frames to settle before it
## hands over, but waiting is not the same as compiling: it only covers what
## happens to be on screen in those first frames. Everything else compiles later,
## mid-play, one hitch per new material as the player turns a corner.
##
## The streaming director makes that worse on purpose. It keeps distant cells
## hidden, so their materials are now guaranteed not to have been drawn during
## the settle frames, and every cell that pops in as the player walks out of the
## castle would be a fresh compile. Warming up front is what makes the culling
## free rather than a trade of steady cost for spikes.
##
## How
## ---
## Every material in the scene is drawn once, on a 4x4 quad, inside a tiny
## offscreen SubViewport behind the loading screen. Shader compilation is global
## to the RenderingServer, so compiling in that viewport's World3D is what the
## real scene will hit a cache for.
##
## Materials are grouped by what actually determines the compiled program, not by
## instance: a StandardMaterial3D's shader comes from its feature and flag set,
## so a thousand materials that differ only in albedo colour share one variant
## and only need drawing once. The castle has ~2,600 material instances and far
## fewer distinct variants, and collapsing them is the difference between a
## warmup that costs a fraction of a second and one that costs longer than the
## stutter it is preventing.

## Each variant is drawn both as a single mesh and as a MultiMesh instance.
## The Compatibility renderer compiles a separate program for instanced
## geometry, and the world is full of MultiMesh batches (190 of them), so
## warming only the single-mesh form would leave every batch to compile on
## first sight anyway.
const WARM_INSTANCED := true

## Hard ceiling on distinct variants drawn, so a scene that defeats the
## grouping can never turn the loading screen into a longer wait than the
## stutter it is there to remove.
const MAX_VARIANTS := 600


## Walk `scene` and return one representative Material per distinct shader
## variant.
static func collect(scene: Node) -> Array[Material]:
	var by_key: Dictionary = {}
	var stack: Array = [scene]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			_note(mesh_instance.material_override, by_key)
			_note(mesh_instance.material_overlay, by_key)
			if mesh_instance.mesh != null:
				for surface in mesh_instance.mesh.get_surface_count():
					_note(mesh_instance.get_surface_override_material(surface), by_key)
					_note(mesh_instance.mesh.surface_get_material(surface), by_key)
		elif node is MultiMeshInstance3D:
			var multi_instance := node as MultiMeshInstance3D
			_note(multi_instance.material_override, by_key)
			_note(multi_instance.material_overlay, by_key)
			var multi := multi_instance.multimesh
			if multi != null and multi.mesh != null:
				for surface in multi.mesh.get_surface_count():
					_note(multi.mesh.surface_get_material(surface), by_key)
		elif node is GPUParticles3D:
			# The VFX case. A particle system that has never emitted has never
			# compiled its draw-pass material, which is exactly the hitch that
			# shows up the first time an effect fires in front of the player.
			var particles := node as GPUParticles3D
			_note(particles.material_override, by_key)
			for pass_index in particles.draw_passes:
				var draw_mesh := particles.get_draw_pass_mesh(pass_index)
				if draw_mesh == null:
					continue
				for surface in draw_mesh.get_surface_count():
					_note(draw_mesh.surface_get_material(surface), by_key)
		elif node is CPUParticles3D:
			_note((node as CPUParticles3D).material_override, by_key)
		elif node is Sprite3D or node is AnimatedSprite3D or node is Label3D:
			_note((node as GeometryInstance3D).material_override, by_key)

	var result: Array[Material] = []
	for key in by_key:
		result.append(by_key[key])
		if result.size() >= MAX_VARIANTS:
			break
	return result


static func _note(material: Material, by_key: Dictionary) -> void:
	if material == null:
		return
	var key := _variant_key(material)
	if not by_key.has(key):
		by_key[key] = material
	# A next_pass is a second draw with a second program, so it needs warming
	# in its own right.
	if material.next_pass != null:
		_note(material.next_pass, by_key)


## What the compiled program depends on. For a ShaderMaterial that is the Shader
## resource itself. For a BaseMaterial3D it is the feature and flag set that
## Godot generates the shader from - colours, strengths and textures do not
## change the program, so they are deliberately not part of the key.
static func _variant_key(material: Material) -> String:
	if material is ShaderMaterial:
		var shader := (material as ShaderMaterial).shader
		return "shader:%d" % (shader.get_instance_id() if shader != null else 0)
	if material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		var features := 0
		for feature in [BaseMaterial3D.FEATURE_EMISSION, BaseMaterial3D.FEATURE_NORMAL_MAPPING,
				BaseMaterial3D.FEATURE_RIM, BaseMaterial3D.FEATURE_CLEARCOAT,
				BaseMaterial3D.FEATURE_ANISOTROPY, BaseMaterial3D.FEATURE_AMBIENT_OCCLUSION,
				BaseMaterial3D.FEATURE_HEIGHT_MAPPING, BaseMaterial3D.FEATURE_SUBSURFACE_SCATTERING,
				BaseMaterial3D.FEATURE_BACKLIGHT, BaseMaterial3D.FEATURE_REFRACTION,
				BaseMaterial3D.FEATURE_DETAIL]:
			features = (features << 1) | (1 if base.get_feature(feature) else 0)
		var flags := 0
		for flag in [BaseMaterial3D.FLAG_USE_POINT_SIZE, BaseMaterial3D.FLAG_ALBEDO_FROM_VERTEX_COLOR,
				BaseMaterial3D.FLAG_SRGB_VERTEX_COLOR, BaseMaterial3D.FLAG_USE_SHADOW_TO_OPACITY,
				BaseMaterial3D.FLAG_FIXED_SIZE, BaseMaterial3D.FLAG_UV1_USE_TRIPLANAR,
				BaseMaterial3D.FLAG_UV2_USE_TRIPLANAR, BaseMaterial3D.FLAG_DISABLE_DEPTH_TEST,
				BaseMaterial3D.FLAG_PARTICLE_TRAILS_MODE, BaseMaterial3D.FLAG_DISABLE_FOG]:
			flags = (flags << 1) | (1 if base.get_flag(flag) else 0)
		return "std:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d" % [
			base.shading_mode, base.transparency, base.blend_mode, base.cull_mode,
			base.depth_draw_mode, base.diffuse_mode, base.specular_mode,
			base.billboard_mode, features, flags]
	return "other:%d" % material.get_instance_id()


## How many variants are revealed per frame by `reveal_next`. Compiling is
## synchronous, so the frame that reveals a batch is as long as that batch takes
## - measured on the castle's 32 variants the whole set costs ~4.4 s, which is
## 4.4 s of in-game stutter being moved somewhere it can be shown honestly.
## Small batches keep each frame short enough for the progress bar to actually
## repaint between them instead of the screen locking up for the whole run.
const VARIANTS_PER_FRAME := 2

## Key under which the rig keeps the nodes waiting to be drawn.
const WARM_NODES_META := "warm_nodes"


## Build an offscreen rig for every variant, with the geometry hidden. The
## caller adds it to the tree and then calls `reveal_next` until it returns
## true, one call per frame, so the compile cost is spread across frames that
## the loading screen can still report progress between.
static func build_rig(materials: Array[Material]) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "ShaderWarmupViewport"
	# Big enough that nothing is degenerate, small enough that the fill cost of
	# drawing several hundred quads is irrelevant.
	viewport.size = Vector2i(64, 64)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Its own World3D, so none of this can interact with the real scene.
	viewport.own_world_3d = true

	var camera := Camera3D.new()
	camera.position = Vector3.ZERO
	camera.near = 0.05
	camera.far = 100.0
	viewport.add_child(camera)
	camera.make_current()

	# An unshadowed light, because an unlit scene can skip the lighting path of
	# the very shaders this is trying to compile.
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 0.0, -1.0)
	light.omni_range = 40.0
	light.shadow_enabled = false
	viewport.add_child(light)

	var quad := QuadMesh.new()
	quad.size = Vector2(4.0, 4.0)

	var warm_nodes: Array[Node3D] = []
	for index in materials.size():
		var material := materials[index]
		# Spread them along -Z so they are all in front of the camera and each
		# one is actually rasterised rather than hidden behind the first.
		var depth := -1.0 - float(index) * 0.01

		var single := MeshInstance3D.new()
		single.mesh = quad
		single.material_override = material
		single.position = Vector3(0.0, 0.0, depth)
		# Never culled away before it has had the chance to compile.
		single.extra_cull_margin = 16384.0
		single.custom_aabb = AABB(Vector3(-8192, -8192, -8192), Vector3(16384, 16384, 16384))
		single.visible = false
		viewport.add_child(single)
		warm_nodes.append(single)

		if not WARM_INSTANCED:
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = quad
		multi.instance_count = 1
		multi.set_instance_transform(0, Transform3D.IDENTITY)
		var batched := MultiMeshInstance3D.new()
		batched.multimesh = multi
		batched.material_override = material
		batched.position = Vector3(0.0, 0.0, depth - 0.005)
		batched.extra_cull_margin = 16384.0
		batched.custom_aabb = AABB(Vector3(-8192, -8192, -8192), Vector3(16384, 16384, 16384))
		batched.visible = false
		viewport.add_child(batched)
		warm_nodes.append(batched)

	viewport.set_meta(WARM_NODES_META, warm_nodes)
	return viewport


## Reveal the next batch of variants so the coming frame draws - and therefore
## compiles - them. Returns true once every variant has been revealed.
##
## Nothing is hidden again afterwards: a variant that has been drawn once is
## compiled, and re-hiding it would only cost another state change. The whole
## rig is freed by the caller when the run finishes.
static func reveal_next(viewport: SubViewport, cursor: int) -> int:
	if viewport == null or not viewport.has_meta(WARM_NODES_META):
		return -1
	var warm_nodes: Array = viewport.get_meta(WARM_NODES_META)
	if cursor >= warm_nodes.size():
		return -1
	var revealed := 0
	var index := cursor
	# One "variant" is its single-mesh and MultiMesh form, so a batch of
	# VARIANTS_PER_FRAME reveals twice that many nodes when both are warmed.
	var budget := VARIANTS_PER_FRAME * (2 if WARM_INSTANCED else 1)
	while index < warm_nodes.size() and revealed < budget:
		var node := warm_nodes[index] as Node3D
		if node != null and is_instance_valid(node):
			node.visible = true
		index += 1
		revealed += 1
	return index


static func warm_node_count(viewport: SubViewport) -> int:
	if viewport == null or not viewport.has_meta(WARM_NODES_META):
		return 0
	return (viewport.get_meta(WARM_NODES_META) as Array).size()
