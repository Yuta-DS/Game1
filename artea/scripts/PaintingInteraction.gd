extends Sprite3D

@export var painting_id: int = 0
@export var camera_path: NodePath

const FRAME_DEPTH := 0.10
const OUTER_WIDTH := 0.36
const BRASS_WIDTH := 0.22
const INNER_WIDTH := 0.07

var _frame_root: Node3D


func _ready() -> void:
	# Several authored triggers were high above the floor. Give every picture
	# the same reachable area on the room side of its wall.
	var trigger := get_node_or_null("InteractionArea/CollisionShape3D") as CollisionShape3D
	if trigger != null:
		var shape := BoxShape3D.new()
		shape.size = Vector3(5.8, 5.8, 5.5)
		trigger.shape = shape
		trigger.scale = Vector3.ONE
		trigger.position = Vector3(0, -2.3, 2.5)


# GalleryManager assigns the picture after this node enters the scene. Size the
# surround from the displayed image so replacement art stays in its frame.
func refresh_frame() -> void:
	if texture == null:
		return
	if _frame_root != null:
		remove_child(_frame_root)
		_frame_root.queue_free()
	_frame_root = Node3D.new()
	_frame_root.name = "ArtworkSurround"
	add_child(_frame_root)

	var size := texture.get_size() * pixel_size
	var outer := StandardMaterial3D.new()
	outer.albedo_color = Color("4b342b")
	outer.metallic = 0.1
	outer.roughness = 0.55
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("b88b49")
	brass.metallic = 0.65
	brass.roughness = 0.34
	var inner := StandardMaterial3D.new()
	inner.albedo_color = Color("e8d7ad")
	inner.roughness = 0.72
	_add_rails(size, OUTER_WIDTH, 0.04, outer)
	_add_rails(size, BRASS_WIDTH, 0.10, brass)
	_add_rails(size, INNER_WIDTH, 0.16, inner)
	_add_corner_pins(size, brass)


func _add_rails(size: Vector2, width: float, front: float,
		material: StandardMaterial3D) -> void:
	var half := size * 0.5
	_add_rail(Vector3(0, half.y + width * 0.5, front),
		Vector3(size.x + 2.0 * width, width, FRAME_DEPTH), material)
	_add_rail(Vector3(0, -half.y - width * 0.5, front),
		Vector3(size.x + 2.0 * width, width, FRAME_DEPTH), material)
	_add_rail(Vector3(-half.x - width * 0.5, 0, front),
		Vector3(width, size.y, FRAME_DEPTH), material)
	_add_rail(Vector3(half.x + width * 0.5, 0, front),
		Vector3(width, size.y, FRAME_DEPTH), material)


func _add_rail(at: Vector3, dimensions: Vector3,
		material: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var rail := MeshInstance3D.new()
	rail.mesh = mesh
	rail.material_override = material
	rail.position = at
	_frame_root.add_child(rail)


func _add_corner_pins(size: Vector2, material: StandardMaterial3D) -> void:
	for x_sign in [-1.0, 1.0]:
		for y_sign in [-1.0, 1.0]:
			var pin_mesh := SphereMesh.new()
			pin_mesh.radius = 0.075
			pin_mesh.height = 0.15
			pin_mesh.radial_segments = 10
			pin_mesh.rings = 5
			var pin := MeshInstance3D.new()
			pin.mesh = pin_mesh
			pin.material_override = material
			pin.position = Vector3(x_sign * (size.x * 0.5 + OUTER_WIDTH * 0.5),
				y_sign * (size.y * 0.5 + OUTER_WIDTH * 0.5), 0.21)
			_frame_root.add_child(pin)
