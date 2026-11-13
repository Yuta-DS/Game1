extends Node3D

## Builds the open-air ARTÉA Castle sanctuary around the existing Crown
## Chamber story nodes. The world stays deliberately modular: every island,
## bridge, arch and landmark is made from web-friendly primitive meshes.

const CENTRAL_SPAWN := Vector3(0, 2.0, 7.0)
const MIND_CENTRE := Vector3(-28, 0, -7)
const HEART_CENTRE := Vector3(0, 0, -30)
const CREATOR_CENTRE := Vector3(28, 0, -7)

@export var fall_recovery_height: float = -14.0

var _materials: Dictionary = {}
var _player: Node3D = null


func _ready() -> void:
	_retire_enclosed_room()
	_make_materials()
	_build_central_sanctuary()
	_build_mind_island()
	_build_heart_island()
	_build_creator_island()
	_build_bridges()
	_build_clouds_and_skyline()
	_add_world_lighting()
	call_deferred("_find_player")


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_find_player()
		return
	if _player.global_position.y < fall_recovery_height:
		_player.global_position = CENTRAL_SPAWN
		if _player is CharacterBody3D:
			_player.velocity = Vector3.ZERO


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D


func _retire_enclosed_room() -> void:
	var room := get_parent().get_node_or_null("Architecture")
	if room == null:
		return
	room.visible = false
	room.process_mode = Node.PROCESS_MODE_DISABLED
	for child in room.find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).disabled = true


func _make_materials() -> void:
	_materials.white = _material(Color("e8edf0"), Color("18232e"), 0.12)
	_materials.white_bright = _material(Color("f8f4e9"), Color("f8e9bd"), 0.28)
	_materials.stone = _material(Color("77718e"), Color("332a52"), 0.16)
	_materials.gold = _material(Color("e9b85c"), Color("f5c96b"), 1.25, 0.45)
	_materials.cyan = _material(Color("4fd8e8"), Color("4fd8e8"), 1.8)
	_materials.pink = _material(Color("fa72a7"), Color("fa72a7"), 1.8)
	_materials.amber = _material(Color("f4ae45"), Color("f4ae45"), 1.8)
	_materials.violet = _material(Color("7446a7"), Color("6f3da3"), 0.45)
	_materials.lavender = _material(Color("b66ce2"), Color("8b4bbd"), 0.5)
	_materials.trunk = _material(Color("594561"), Color("2b2035"), 0.1)
	_materials.cloud = _material(Color("ddd7ed"), Color("8275ac"), 0.24)


func _material(
	albedo: Color,
	emission: Color,
	emission_energy: float,
	metallic: float = 0.0
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.78 if metallic == 0.0 else 0.28
	material.metallic = metallic
	material.emission_enabled = emission_energy > 0.0
	material.emission = emission
	material.emission_energy_multiplier = emission_energy
	return material


func _build_central_sanctuary() -> void:
	_add_cylinder("CentralGarden", Vector3(0, -0.8, 0), 12.0, 1.6, _materials.white, true)
	_add_cylinder("GardenRing", Vector3(0, 0.04, 0), 7.4, 0.18, _materials.stone, false)
	_add_cylinder("InnerGarden", Vector3(0, 0.15, 0), 5.2, 0.28, _materials.violet, false)

	# A small luminous tree gives the hub one landmark visible from every island.
	_add_cylinder("SanctuaryTreeTrunk", Vector3(0, 2.0, 0), 0.62, 4.0, _materials.trunk, false)
	for offset in [Vector3(0, 4.7, 0), Vector3(-1.3, 4.1, 0), Vector3(1.3, 4.1, 0)]:
		_add_sphere("SanctuaryTreeCrown", offset, Vector3(2.2, 1.7, 2.2), _materials.lavender)

	# Open castle arches keep the Crown Chamber identity without enclosing it.
	_build_arch(Vector3(-5.8, 0, 2.5), 0.0, 5.0, 6.0, _materials.white_bright)
	_build_arch(Vector3(5.8, 0, 2.5), 0.0, 5.0, 6.0, _materials.white_bright)

	var title := Label3D.new()
	title.name = "FloatingCastleTitle"
	title.position = Vector3(0, 5.7, 8.1)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.text = "ARTÉA  •  CASTLE IN THE STARS"
	title.font_size = 54
	title.pixel_size = 0.008
	title.modulate = Color("f7d785")
	add_child(title)

	for angle in [0.45, 2.0, 3.5, 5.05]:
		var position := Vector3(cos(angle) * 8.7, 0.0, sin(angle) * 8.7)
		_add_planter(position, _materials.lavender)


func _build_mind_island() -> void:
	_add_cylinder("MindIsland", MIND_CENTRE + Vector3(0, -0.9, 0), 9.5, 1.8, _materials.white, true)
	_add_cylinder("MindGarden", MIND_CENTRE + Vector3(0, 0.12, 0), 6.6, 0.24, _materials.cyan, false)

	# Readable geometric puzzle field.
	for data in [
		[Vector3(-31.5, 0.9, -5.0), Vector3(2.2, 1.8, 2.2)],
		[Vector3(-28.5, 1.45, -8.0), Vector3(2.0, 2.9, 2.0)],
		[Vector3(-25.3, 0.65, -5.2), Vector3(2.4, 1.3, 2.4)],
		[Vector3(-30.8, 0.45, -10.0), Vector3(1.6, 0.9, 1.6)],
	]:
		_add_box("MindPuzzleBlock", data[0], data[1], _materials.cyan, true)

	_build_arch(MIND_CENTRE + Vector3(0, 0, -5.5), 0.0, 5.5, 5.6, _materials.white_bright)
	_add_planter(MIND_CENTRE + Vector3(-6.7, 0, 1.5), _materials.violet)
	_add_planter(MIND_CENTRE + Vector3(6.7, 0, 1.5), _materials.violet)


func _build_heart_island() -> void:
	_add_cylinder("HeartIsland", HEART_CENTRE + Vector3(0, -0.9, 0), 10.0, 1.8, _materials.white, true)
	_add_cylinder("HeartGarden", HEART_CENTRE + Vector3(0, 0.12, 0), 7.0, 0.24, _materials.pink, false)

	# A short, playable melody path leads directly to the world doorway.
	for index in 7:
		var x := (float(index) - 3.0) * 1.75
		var z := -28.5 - absf(float(index) - 3.0) * 0.28
		_add_cylinder("MelodyStone", Vector3(x, 0.38, z), 0.78, 0.34, _materials.pink, true)

	_build_arch(HEART_CENTRE + Vector3(0, 0, -5.8), 0.0, 5.8, 6.0, _materials.white_bright)
	for x in [-6.8, 6.8]:
		_add_tree(Vector3(x, 0, -31.0), _materials.lavender)


func _build_creator_island() -> void:
	_add_cylinder("CreatorIsland", CREATOR_CENTRE + Vector3(0, -0.9, 0), 9.5, 1.8, _materials.white, true)
	_add_box("CreatorStudioFloor", CREATOR_CENTRE + Vector3(0, 0.15, 0), Vector3(13.5, 0.3, 11.5), _materials.amber, true)

	# Blank canvases make the activity legible without introducing heavy assets.
	for data in [
		[Vector3(24.2, 2.2, -9.2), -0.18],
		[Vector3(28.0, 2.4, -10.0), 0.0],
		[Vector3(31.8, 2.2, -9.2), 0.18],
	]:
		_add_canvas(data[0], data[1])

	_add_box("StudioTable", Vector3(28, 1.0, -4.1), Vector3(5.6, 0.35, 2.0), _materials.gold, true)
	_build_arch(CREATOR_CENTRE + Vector3(0, 0, -5.5), 0.0, 5.5, 5.6, _materials.white_bright)
	_add_planter(CREATOR_CENTRE + Vector3(-6.5, 0, 2.0), _materials.lavender)
	_add_planter(CREATOR_CENTRE + Vector3(6.5, 0, 2.0), _materials.lavender)


func _build_bridges() -> void:
	_add_bridge(Vector3(-8.0, 0, -1.5), Vector3(-20.0, 0, -5.2), _materials.cyan)
	_add_bridge(Vector3(0, 0, -9.0), Vector3(0, 0, -21.0), _materials.pink)
	_add_bridge(Vector3(8.0, 0, -1.5), Vector3(20.0, 0, -5.2), _materials.amber)

	# The Mind bridge passes through a golden picture frame: an original,
	# Artea-specific nod to perspective becoming a traversable path.
	var direction := (MIND_CENTRE - Vector3.ZERO).normalized()
	var yaw := atan2(direction.x, direction.z)
	_build_arch(Vector3(-15.7, 0, -3.9), yaw, 5.0, 5.2, _materials.gold)


func _add_bridge(from: Vector3, to: Vector3, accent: Material) -> void:
	var delta := to - from
	var middle := (from + to) * 0.5
	var length := Vector2(delta.x, delta.z).length()
	var yaw := atan2(delta.x, delta.z)
	_add_box("FloatingBridge", middle + Vector3(0, -0.18, 0), Vector3(5.2, 0.55, length), _materials.white, true, yaw)

	# Repeating luminous insets show direction while keeping the route wide.
	for step in 5:
		var t := (float(step) + 0.5) / 5.0
		var marker := from.lerp(to, t) + Vector3(0, 0.12, 0)
		_add_cylinder("BridgeLight", marker, 0.22, 0.12, accent, false)


func _build_clouds_and_skyline() -> void:
	for cloud in [
		Vector3(-18, -7, 5), Vector3(16, -8, 2), Vector3(0, -7, -17),
		Vector3(-36, -8, -28), Vector3(36, -9, -25), Vector3(4, -10, 20),
	]:
		_add_cloud(cloud)

	# Distant simple towers strengthen the castle-in-a-galaxy silhouette.
	for data in [
		[Vector3(-46, -7, -38), 18.0], [Vector3(44, -9, -42), 22.0],
		[Vector3(-34, -10, -52), 28.0], [Vector3(28, -12, -58), 34.0],
	]:
		var base: Vector3 = data[0]
		var height: float = data[1]
		_add_box("DistantTower", base + Vector3(0, height * 0.5, 0), Vector3(5.0, height, 5.0), _materials.stone, false)
		_build_arch(base + Vector3(0, height - 2.0, 0), 0.0, 3.2, 5.0, _materials.white, false)


func _add_world_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "FloatingWorldSun"
	sun.rotation_degrees = Vector3(-52, -34, 0)
	sun.light_color = Color("fff0d1")
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	add_child(sun)


func _add_canvas(position: Vector3, yaw: float) -> void:
	_add_box("Canvas", position, Vector3(2.4, 3.2, 0.18), _materials.white_bright, false, yaw)
	_add_box("CanvasStand", position + Vector3(0, -2.0, 0), Vector3(0.28, 1.8, 0.28), _materials.gold, false, yaw)


func _add_planter(position: Vector3, foliage: Material) -> void:
	_add_box("Planter", position + Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 2.4), _materials.white, true)
	for offset in [Vector3(-0.55, 1.2, 0), Vector3(0.5, 1.1, 0.35), Vector3(0, 1.35, -0.5)]:
		_add_sphere("PlanterFoliage", position + offset, Vector3(0.75, 1.15, 0.75), foliage)


func _add_tree(position: Vector3, foliage: Material) -> void:
	_add_cylinder("TreeTrunk", position + Vector3(0, 1.7, 0), 0.42, 3.4, _materials.trunk, false)
	_add_sphere("TreeCrown", position + Vector3(0, 4.2, 0), Vector3(2.2, 2.3, 2.2), foliage)


func _add_cloud(position: Vector3) -> void:
	for offset in [Vector3(-2.2, 0, 0), Vector3(0, 0.7, 0), Vector3(2.2, 0, 0), Vector3(0.7, -0.2, 1.5)]:
		_add_sphere("Cloud", position + offset, Vector3(3.0, 1.6, 2.2), _materials.cloud)


func _build_arch(
	position: Vector3,
	yaw: float,
	width: float,
	height: float,
	material: Material,
	collidable: bool = true
) -> void:
	var side := width * 0.5
	var left := position + Vector3(-side, height * 0.5, 0).rotated(Vector3.UP, yaw)
	var right := position + Vector3(side, height * 0.5, 0).rotated(Vector3.UP, yaw)
	_add_box("ArchPillar", left, Vector3(0.7, height, 0.9), material, collidable, yaw)
	_add_box("ArchPillar", right, Vector3(0.7, height, 0.9), material, collidable, yaw)
	_add_box("ArchLintel", position + Vector3(0, height, 0), Vector3(width + 0.7, 0.8, 0.9), material, collidable, yaw)


func _add_box(
	object_name: String,
	position: Vector3,
	size: Vector3,
	material: Material,
	collidable: bool,
	yaw: float = 0.0
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = object_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.rotation.y = yaw
	add_child(mesh_instance)

	if collidable:
		var body := StaticBody3D.new()
		body.name = object_name + "Body"
		body.position = position
		body.rotation.y = yaw
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
	return mesh_instance


func _add_cylinder(
	object_name: String,
	position: Vector3,
	radius: float,
	height: float,
	material: Material,
	collidable: bool
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = object_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.92
	mesh.height = height
	mesh.radial_segments = 32
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	add_child(mesh_instance)

	if collidable:
		var body := StaticBody3D.new()
		body.name = object_name + "Body"
		body.position = position
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
	return mesh_instance


func _add_sphere(object_name: String, position: Vector3, scale: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = object_name
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.scale = scale
	add_child(mesh_instance)
	return mesh_instance
