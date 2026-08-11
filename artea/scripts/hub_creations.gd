# Stage 3's castle change — the world fills with what the player made.
#
# The journey design describes hanging creations "on the Hub World walls" via
# PaintingArea.gd / ArtFrame.tscn. Those turned out to be empty stubs, and the
# hub is an open outdoor village with no interior walls to hang anything on.
# So the same idea takes the form the world actually supports: free-standing
# framed canvases along the village square, raised as the player makes things.
#
# Attached to the HubWorld root alongside hub_awakening.gd. Spawns at runtime
# from JourneyState.creations, so New_Hub_World.tscn stays untouched and an
# empty journey costs nothing.
extends Node

const ArtworkWorldPortal := preload("res://scripts/creation_world/artwork_world_portal.gd")

# Where the canvases stand, in hub world space.
#
# Anchored to Milo's plaza rather than the map origin: the hub's ground sits
# around Y=20-34, so origin-relative spots would bury every canvas underground.
# Milo (-32.3, 20, -2) is also the right place thematically — the companion who
# witnessed the making stands among the results.
#
# Offsets are from ANCHOR, arranged in a shallow arc facing the plaza. Ordered
# so the first thing the player makes lands in the most visible spot rather
# than off behind a barn. Each entry is offset + Y rotation in degrees.
const ANCHOR := Vector3(-32.3, 20.0, -2.0)

const EASEL_SPOTS := [
	{"offset": Vector3(4.0, 0.0, 4.5), "yaw": 205.0},
	{"offset": Vector3(-3.5, 0.0, 5.0), "yaw": 155.0},
	{"offset": Vector3(7.5, 0.0, 0.5), "yaw": 250.0},
	{"offset": Vector3(-7.0, 0.0, 1.0), "yaw": 110.0},
	{"offset": Vector3(1.5, 0.0, 8.0), "yaw": 195.0},
	{"offset": Vector3(-2.0, 0.0, 8.5), "yaw": 165.0},
]

# Canvas size in metres. Big enough to read while walking past.
const CANVAS_SIZE := Vector2(1.9, 1.9)
const FRAME_MARGIN := 0.14
const CANVAS_HEIGHT := 1.75  # centre height, roughly eye level

const RAISE_SECONDS := 1.1


func _ready() -> void:
	# Let the hub finish building before adding to it.
	await get_tree().process_frame

	# Absolute node paths error out when this node is not inside the active
	# scene tree. Nothing here is worth a crash — an empty village is the
	# correct fallback.
	if not is_inside_tree():
		return

	var js := get_node_or_null("/root/JourneyState")
	if js == null:
		return

	_raise_all(js)


func _raise_all(js) -> void:
	var root := get_parent()
	if root == null:
		return

	var holder := Node3D.new()
	holder.name = "PlayerCreations"
	root.add_child(holder)

	# Most recent first — what the player just made is what they want to see.
	var shown := 0
	for i in range(js.creations.size() - 1, -1, -1):
		if shown >= EASEL_SPOTS.size():
			break

		var entry = js.creations[i]
		var path: String = entry.get("path", "")
		if path.is_empty():
			continue

		var texture := _load_creation(path)
		if texture == null:
			continue

		var spot: Dictionary = EASEL_SPOTS[shown]
		var final_pos: Vector3 = ANCHOR + spot["offset"]

		var easel := _build_easel(texture, entry.get("title", ""), path)
		easel.position = final_pos
		easel.rotation_degrees.y = spot["yaw"]
		holder.add_child(easel)

		_raise(easel, final_pos, shown)
		shown += 1


# A creation the player deleted from disk is skipped, not fatal — the journey
# record outlives the file, and a missing PNG must not break the hub.
func _load_creation(path: String) -> ImageTexture:
	if not FileAccess.file_exists(path):
		return null

	var image := Image.new()
	if image.load(path) != OK:
		return null

	return ImageTexture.create_from_image(image)


func _build_easel(texture: ImageTexture, title: String, artwork_path: String = "") -> Node3D:
	var easel := Node3D.new()

	# Frame — a slightly larger dark quad sitting just behind the canvas.
	var frame := MeshInstance3D.new()
	var frame_mesh := QuadMesh.new()
	frame_mesh.size = CANVAS_SIZE + Vector2(FRAME_MARGIN, FRAME_MARGIN) * 2.0
	frame.mesh = frame_mesh
	frame.position = Vector3(0, CANVAS_HEIGHT, -0.02)

	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = Color(0.24, 0.17, 0.11)
	frame_material.roughness = 0.9
	frame.material_override = frame_material
	easel.add_child(frame)

	# Canvas — the artwork itself, lit so it reads at any stage of the day.
	var canvas := MeshInstance3D.new()
	var canvas_mesh := QuadMesh.new()
	canvas_mesh.size = CANVAS_SIZE
	canvas.mesh = canvas_mesh
	canvas.position = Vector3(0, CANVAS_HEIGHT, 0)

	var canvas_material := StandardMaterial3D.new()
	canvas_material.albedo_texture = texture
	# Drawings are saved with transparency where the player did not paint.
	canvas_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# The art is the player's, not the lighting's — keep it legible even in
	# a stage-0 world that is deliberately dim.
	canvas_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	canvas_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	canvas.material_override = canvas_material
	easel.add_child(canvas)

	# Post holding it up.
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.12, CANVAS_HEIGHT, 0.12)
	post.mesh = post_mesh
	post.position = Vector3(0, CANVAS_HEIGHT * 0.5, -0.04)
	post.material_override = frame_material
	easel.add_child(post)

	if not title.is_empty():
		easel.add_child(_title_label(title))

	if not artwork_path.is_empty():
		var portal := Area3D.new()
		portal.name = "EnterArtworkWorld"
		portal.set_script(ArtworkWorldPortal)
		portal.call("configure", artwork_path, title)
		portal.position = Vector3(0, CANVAS_HEIGHT, 0.7)
		var portal_collision := CollisionShape3D.new()
		var portal_shape := BoxShape3D.new()
		portal_shape.size = Vector3(CANVAS_SIZE.x + 1.2, CANVAS_SIZE.y + 1.0, 2.0)
		portal_collision.shape = portal_shape
		portal.add_child(portal_collision)
		easel.add_child(portal)

	return easel


func _title_label(title: String) -> Label3D:
	var label := Label3D.new()
	label.text = title
	label.font_size = 48
	label.pixel_size = 0.002
	label.position = Vector3(0, CANVAS_HEIGHT - CANVAS_SIZE.y * 0.5 - 0.22, 0.01)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.modulate = Color(1.0, 0.95, 0.85)
	label.outline_size = 10
	label.outline_modulate = Color(0.1, 0.08, 0.06, 0.9)
	return label


# Each canvas rises out of the ground, staggered, so returning to the hub
# after painting is something the player watches happen.
func _raise(easel: Node3D, final_pos: Vector3, index: int) -> void:
	var sunken := final_pos
	sunken.y -= CANVAS_HEIGHT + CANVAS_SIZE.y
	easel.position = sunken

	var tween := easel.create_tween()
	tween.tween_interval(0.25 * index)
	tween.tween_property(easel, "position", final_pos, RAISE_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
