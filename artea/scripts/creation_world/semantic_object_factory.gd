extends RefCounted

# Converts one detected subject into an independent physical 3D object.
# Anything that came from a bounded region of the artwork keeps that exact crop
# as a thick, collidable extrusion. Curated models are reserved for new ideas
# added by the player that do not have pixels in the source artwork.

const ASSETS := {
	"tree": "res://assets3D/houses/gltf/tree_large.gltf",
	"house": "res://assets3D/houses/gltf/house.gltf",
	"home": "res://assets3D/houses/gltf/house.gltf",
	"building": "res://assets3D/houses/gltf/house.gltf",
	"pagoda": "res://assets3D/houses/gltf/house.gltf",
	"castle": "res://assets3D/houses/red/building_castle_red.gltf",
	"boat": "res://scenes/boat.tscn",
	"mountain": "res://assets3D/stylizedNature/Rock_Medium_1.gltf",
	"rock": "res://assets3D/stylizedNature/Rock_Medium_1.gltf",
	"flower": "res://assets/models/Low-Poly Plant_.fbx",
	"cloud": "res://assets3D/worlds/Floating_Cloud_1031084848_texture.glb",
	"fox": "res://assets3D/Animated Animal Pack-glb/Fox.glb",
	"deer": "res://assets3D/Animated Animal Pack-glb/Deer.glb",
	"horse": "res://assets3D/Animated Animal Pack-glb/Horse.glb",
	"cow": "res://assets3D/Animated Animal Pack-glb/Cow.glb",
	"bull": "res://assets3D/Animated Animal Pack-glb/Bull.glb",
	"wolf": "res://assets3D/Animated Animal Pack-glb/Wolf.glb",
	"dog": "res://assets3D/Animated Animal Pack-glb/Shiba Inu.glb",
	"husky": "res://assets3D/Animated Animal Pack-glb/Husky.glb",
	"donkey": "res://assets3D/Animated Animal Pack-glb/Donkey.glb",
	"alpaca": "res://assets3D/Animated Animal Pack-glb/Alpaca.glb",
	"stag": "res://assets3D/Animated Animal Pack-glb/Stag.glb",
	"person": "res://assets3D/characters/Father_output.glb",
	"human": "res://assets3D/characters/Father_output.glb",
	"character": "res://assets3D/characters/Father_output.glb",
	"avatar": "res://assets3D/characters/Father_output.glb",
}


static func create(spec: Dictionary, source_image: Image, fallback_colour: Color) -> StaticBody3D:
	var type_name := _canonical_type(spec)
	var asset_path := asset_path_for_spec(spec)
	var body: StaticBody3D
	if type_name in ["water", "river", "lake", "road", "path", "bridge", "ground"]:
		body = _primitive_surface(type_name, fallback_colour, source_image, spec)
	# Anything identified from a bounded region of the artwork must continue to
	# look like what the artist drew. The previous branch chose a stock tree,
	# house, animal or person model here and discarded the subject's painted
	# appearance. A thick crop extrusion keeps the exact pixels, silhouette,
	# colours and proportions while giving it collision and 3D placement.
	elif _has_artwork_bounds(spec) and source_image != null and not source_image.is_empty():
		body = _art_extrusion(source_image, spec, fallback_colour)
	elif not asset_path.is_empty() and ResourceLoader.exists(asset_path):
		# Player-added ideas without a source region can still use curated assets.
		body = _from_asset(asset_path, type_name)
	elif type_name in ["sun", "moon", "planet", "star", "light", "friendly_light"]:
		body = _primitive_sphere(fallback_colour)
	else:
		body = _art_extrusion(source_image, spec, fallback_colour)
	_configure_metadata(body, spec, type_name)
	return body


static func _has_artwork_bounds(spec: Dictionary) -> bool:
	var bounds = spec.get("bounding_box", spec.get("bounds", null))
	if bounds is Dictionary:
		return bounds.has("x") and bounds.has("y") \
			and (bounds.has("width") or bounds.has("w")) \
			and (bounds.has("height") or bounds.has("h"))
	return bounds is Array and bounds.size() >= 4


static func asset_path_for_spec(spec: Dictionary) -> String:
	var type_name := _canonical_type(spec)
	return _asset_for(type_name, str(spec.get("label", spec.get("description", ""))))


static func _canonical_type(spec: Dictionary) -> String:
	var combined := (str(spec.get("type", "")) + " " + str(spec.get("id", "")) + " " \
		+ str(spec.get("label", "")) + " " + str(spec.get("description", "")) + " " \
		+ str(spec.get("asset_hint", ""))).to_lower()
	for known in ["butterfly", "bird", "flower", "tree", "pagoda", "castle", "house", "home", "building", "bridge", "boat", "fish", "cat", "dog", "fox", "deer", "horse", "cow", "bull", "wolf", "husky", "donkey", "alpaca", "stag", "cloud", "sun", "moon", "star", "planet", "river", "lake", "water", "road", "path", "mountain", "rock", "person", "human", "character", "avatar", "symbol"]:
		if combined.contains(known):
			return known
	var raw := str(spec.get("type", "art_shape")).to_lower().strip_edges()
	return raw if not raw.is_empty() else "art_shape"


static func _asset_for(type_name: String, label: String) -> String:
	if ASSETS.has(type_name):
		return ASSETS[type_name]
	var lower := label.to_lower()
	for candidate in ASSETS:
		if lower.contains(candidate):
			return ASSETS[candidate]
	return ""


static func _from_asset(path: String, type_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	var packed = load(path)
	if packed is PackedScene:
		var model: Node = packed.instantiate()
		model.name = "Semantic3DModel"
		model.scale = Vector3.ONE * _model_scale(type_name)
		body.add_child(model)
		_play_first_animation(model)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = _collision_size(type_name)
	collision.shape = shape
	collision.position.y = shape.size.y * 0.5
	body.add_child(collision)
	body.set_meta("reconstruction_mode", "curated_3d_asset")
	return body


static func _primitive_sphere(colour: Color) -> StaticBody3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.9
	mesh.height = 1.8
	return _body_from_mesh(mesh, colour, "procedural_3d")


static func _primitive_surface(type_name: String, colour: Color,
		source_image: Image, spec: Dictionary) -> StaticBody3D:
	var bounds := normalized_bounds(spec)
	var painted_width := clampf(bounds.size.x * 34.0, 2.0, 34.0)
	var painted_depth := clampf(bounds.size.y * 26.0, 1.5, 24.0)
	var mesh := BoxMesh.new()
	if type_name == "bridge":
		mesh.size = Vector3(clampf(painted_width, 5.0, 14.0), 0.45,
			clampf(painted_depth, 1.8, 4.0))
	elif type_name in ["road", "path"]:
		mesh.size = Vector3(clampf(painted_width, 2.0, 7.0), 0.18,
			clampf(painted_depth, 4.0, 20.0))
	else:
		mesh.size = Vector3(painted_width, 0.16, painted_depth)
	var body := _body_from_mesh(mesh, colour, "procedural_3d")
	var texture := _crop_texture(source_image, spec)
	if texture != null:
		var visual := body.get_node_or_null("SemanticVisual") as MeshInstance3D
		var material := visual.material_override as StandardMaterial3D
		material.albedo_texture = texture
	return body


static func _art_extrusion(source_image: Image, spec: Dictionary, colour: Color) -> StaticBody3D:
	var bounds := normalized_bounds(spec)
	var width := clampf(bounds.size.x * 13.0, 0.9, 6.5)
	var height := clampf(bounds.size.y * 8.0, 0.9, 6.0)
	var depth := clampf(float(spec.get("depth", 0.65)), 0.35, 1.5)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, depth)
	var body := _body_from_mesh(mesh, colour, "artwork_extrusion")
	var visual := body.get_node_or_null("SemanticVisual") as MeshInstance3D
	var material := visual.material_override as StandardMaterial3D
	var texture := _crop_texture(source_image, spec)
	if texture != null:
		material.albedo_texture = texture
		material.albedo_color = Color.WHITE
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	body.set_meta("source_bounds", [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y])
	body.set_meta("preserves_artwork_pixels", true)
	return body


static func _body_from_mesh(mesh: PrimitiveMesh, colour: Color, mode: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	var visual := MeshInstance3D.new()
	visual.name = "SemanticVisual"
	visual.mesh = mesh
	visual.position.y = mesh.get_aabb().size.y * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.72
	visual.material_override = material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_convex_shape()
	collision.position.y = mesh.get_aabb().size.y * 0.5
	body.add_child(collision)
	body.set_meta("reconstruction_mode", mode)
	return body


static func _crop_texture(image: Image, spec: Dictionary) -> Texture2D:
	if image == null or image.is_empty():
		return null
	var bounds := normalized_bounds(spec)
	var rect := Rect2i(
		clampi(int(bounds.position.x * image.get_width()), 0, image.get_width() - 1),
		clampi(int(bounds.position.y * image.get_height()), 0, image.get_height() - 1),
		maxi(1, int(bounds.size.x * image.get_width())),
		maxi(1, int(bounds.size.y * image.get_height())))
	rect.size.x = mini(rect.size.x, image.get_width() - rect.position.x)
	rect.size.y = mini(rect.size.y, image.get_height() - rect.position.y)
	var crop := image.get_region(rect)
	return ImageTexture.create_from_image(crop) if not crop.is_empty() else null


static func normalized_bounds(spec: Dictionary) -> Rect2:
	var raw = spec.get("bounding_box", spec.get("bounds", {}))
	var x := 0.35
	var y := 0.30
	var width := 0.30
	var height := 0.40
	if raw is Dictionary:
		x = float(raw.get("x", raw.get("left", x)))
		y = float(raw.get("y", raw.get("top", y)))
		width = float(raw.get("width", raw.get("w", width)))
		height = float(raw.get("height", raw.get("h", height)))
	elif raw is Array and raw.size() >= 4:
		x = float(raw[0])
		y = float(raw[1])
		width = float(raw[2])
		height = float(raw[3])
	return Rect2(
		clampf(x, 0.0, 0.98), clampf(y, 0.0, 0.98),
		clampf(width, 0.02, 1.0 - clampf(x, 0.0, 0.98)),
		clampf(height, 0.02, 1.0 - clampf(y, 0.0, 0.98)))


static func _configure_metadata(body: StaticBody3D, spec: Dictionary, type_name: String) -> void:
	body.collision_layer = 8
	body.collision_mask = 1
	body.set_meta("artwork_interactive", true)
	body.set_meta("artwork_kind", type_name)
	body.set_meta("artwork_description", str(spec.get("description", spec.get("label", type_name.replace("_", " ")))))


static func _model_scale(type_name: String) -> float:
	if type_name in ["tree", "cloud", "mountain"]:
		return 1.4
	if type_name in ["house", "home", "building", "pagoda", "castle"]:
		return 1.1
	if type_name in ["person", "human", "character", "avatar"]:
		return 0.8
	return 1.15


static func _collision_size(type_name: String) -> Vector3:
	if type_name == "tree":
		return Vector3(1.8, 5.0, 1.8)
	if type_name == "mountain":
		return Vector3(5.5, 4.5, 5.5)
	if type_name in ["house", "home", "building", "pagoda", "castle"]:
		return Vector3(4.5, 3.8, 4.5)
	if type_name == "boat":
		return Vector3(2.8, 1.4, 5.5)
	if type_name == "flower":
		return Vector3(0.8, 1.4, 0.8)
	if type_name == "cloud":
		return Vector3(4.0, 1.5, 2.5)
	if type_name in ["person", "human", "character", "avatar"]:
		return Vector3(1.2, 2.2, 1.2)
	return Vector3(2.0, 1.8, 2.6)


static func _play_first_animation(node: Node) -> void:
	var player := node.find_child("AnimationPlayer*", true, false) as AnimationPlayer
	if player == null:
		return
	for animation_name in player.get_animation_list():
		if animation_name != "RESET":
			player.play(animation_name)
			return
