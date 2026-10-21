extends Node3D

# A wooden signpost outside each minigame door in the hub village, so players
# can tell which building leads where.
#
# Each signpost is placed from its door trigger and the building it belongs to,
# rather than from fixed coordinates: if a building is moved (and its trigger
# with it), the signpost follows. It stands just outside the door and off to one
# side, facing the player as they walk up.

const SIGNS := [
	{"trigger": "Popthought_world", "building": "building_church_red2", "title": "POP THOUGHTS"},
	# Despite its name, the Drawing_Tool2 trigger opens the music minigame.
	{"trigger": "Drawing_Tool2", "building": "building_home_A_red2", "title": "MUSIC"},
	{"trigger": "Drawing_Tool", "building": "building_home_A_red4", "title": "DRAWING"},
]
const SUBTITLE := "MINIGAME"
# How far out from the door and how far to its side the signpost stands.
const OUT_FROM_DOOR := 3.5
const BESIDE_DOOR := 3.2
const POST_HEIGHT := 2.6
const BOARD_SIZE := Vector3(3.4, 1.5, 0.18)

var _wood := _material(Color("8a5a36"))
var _board := _material(Color("e9d3a6"))


func _ready() -> void:
	var hub := get_parent()
	for info in SIGNS:
		var trigger := hub.get_node_or_null("%s/CollisionShape3D" % info.trigger) as Node3D
		var building := hub.get_node_or_null(info.building) as Node3D
		if trigger == null or building == null:
			push_warning("hub_minigame_signs: missing %s or %s" % [info.trigger, info.building])
			continue
		_build_sign(info.title, trigger.global_position, building.global_position)


func _build_sign(title: String, door: Vector3, building: Vector3) -> void:
	var outward := Vector3(door.x - building.x, 0.0, door.z - building.z).normalized()
	var side := outward.cross(Vector3.UP)
	var signpost := Node3D.new()
	signpost.name = "MinigameSign_%s" % title.to_pascal_case()
	add_child(signpost)
	signpost.global_position = Vector3(door.x, building.y, door.z) \
		+ outward * OUT_FROM_DOOR + side * BESIDE_DOOR
	# Local +Z faces out, toward a player walking up to the door.
	signpost.global_basis = Basis.looking_at(-outward)

	_add_box(signpost, Vector3(0.0, POST_HEIGHT * 0.5, 0.0), Vector3(0.22, POST_HEIGHT, 0.22), _wood)
	var board_y := POST_HEIGHT + BOARD_SIZE.y * 0.5 - 0.2
	_add_box(signpost, Vector3(0.0, board_y, 0.0), BOARD_SIZE, _board)
	# Trim so the board reads as a framed plank.
	_add_box(signpost, Vector3(0.0, board_y, 0.0), BOARD_SIZE + Vector3(0.16, 0.16, -0.04), _wood)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, POST_HEIGHT + BOARD_SIZE.y, 0.3)
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	body.add_child(shape)
	signpost.add_child(body)

	# Longer titles get smaller text so they stay on the board.
	var title_size := mini(96, 760 / title.length())
	# Readable from both sides: one label per face.
	for face in [1.0, -1.0]:
		var z: float = (BOARD_SIZE.z * 0.5 + 0.02) * face
		var label_basis := Basis.IDENTITY if face > 0.0 else Basis(Vector3.UP, PI)
		_add_label(signpost, title, Vector3(0.0, board_y + 0.18, z), label_basis, title_size)
		_add_label(signpost, SUBTITLE, Vector3(0.0, board_y - 0.42, z), label_basis, 44)


func _add_box(parent: Node3D, position_value: Vector3, size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position_value
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)


func _add_label(parent: Node3D, text: String, position_value: Vector3, label_basis: Basis,
		font_size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.006
	label.modulate = Color("3b2414")
	label.outline_size = 0
	label.double_sided = false
	label.transform = Transform3D(label_basis, position_value)
	parent.add_child(label)


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
