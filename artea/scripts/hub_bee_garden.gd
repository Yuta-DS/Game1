extends Node3D

## Web-safe life for the hub meadow. The full 252-bee population is rendered
## by one MultiMesh and updated as transforms, rather than as hundreds of
## independent scene trees. Bees travel between real scattered flowers and a
## few visible homes are attached to real scattered tree positions.

@export var flower_scatter_path: NodePath
@export var tree_scatter_path: NodePath
@export_range(1, 400, 1) var bee_count := 252
@export_range(1, 12, 1) var bee_home_count := 6

const ORIGINAL_BEE_COUNT := 14
const POPULATION_MULTIPLIER := 18
const BASE_SCALE := 0.45
const SIZE_VARIANTS := [0.90, 1.0, 1.10]
const FLOWER_ITEM_PREFIX := "ScatterItemFlower"
const TREE_ITEM_NAMES := [
	"ScatterItem", "ScatterItem2", "ScatterItem3", "ScatterItem4",
	"ScatterItem5", "ScatterItem6", "ScatterItem7", "ScatterItem8",
]
const FALLBACK_FLOWERS := [
	Vector3(-32.0, 27.0, -18.0),
	Vector3(18.0, 27.0, -42.0),
	Vector3(54.0, 28.0, 12.0),
	Vector3(-58.0, 28.0, 44.0),
	Vector3(10.0, 27.0, 58.0),
]
const FALLBACK_TREES := [
	Vector3(-48.0, 26.0, -34.0),
	Vector3(62.0, 27.0, -18.0),
	Vector3(-70.0, 27.0, 52.0),
]

var _flower_points: Array[Vector3] = []
var _bees: Array[Dictionary] = []
var _bee_multimesh: MultiMesh
var _bee_instances: MultiMeshInstance3D
var _elapsed := 0.0
var _yellow: StandardMaterial3D
var _black: StandardMaterial3D
var _wing: StandardMaterial3D
var _hive: StandardMaterial3D


func _ready() -> void:
	_build_shared_materials()
	_build_batched_bees()
	_place_garden.call_deferred()


func _process(delta: float) -> void:
	if _bee_multimesh == null or _flower_points.is_empty():
		return
	_elapsed += delta
	for index in _bees.size():
		var bee_data := _bees[index]
		var progress: float = bee_data["progress"] + delta / float(bee_data["duration"])
		if progress >= 1.0:
			var source_index: int = bee_data["target"]
			bee_data["source"] = source_index
			bee_data["target"] = _next_flower_index(source_index, index)
			bee_data["duration"] = 3.4 + float(index % 9) * 0.31
			progress = fmod(progress, 1.0)
		bee_data["progress"] = progress
		_bees[index] = bee_data
		_update_bee_transform(index, bee_data)


func _place_garden() -> void:
	var flower_scatter := get_node_or_null(flower_scatter_path)
	var tree_scatter := get_node_or_null(tree_scatter_path)
	await _wait_for_scatter(flower_scatter)
	await _wait_for_scatter(tree_scatter)

	_flower_points = _collect_scatter_points(flower_scatter, true)
	if _flower_points.is_empty():
		for point in FALLBACK_FLOWERS:
			_flower_points.append(to_local(point))

	_seed_flight_paths()
	var tree_points := _collect_scatter_points(tree_scatter, false)
	if tree_points.is_empty():
		for point in FALLBACK_TREES:
			tree_points.append(to_local(point))
	_place_bee_homes(tree_points)


func _wait_for_scatter(scatter: Node) -> void:
	if scatter == null:
		return
	# Desktop may build in a worker while Web uses deferred synchronous work.
	# The frame budget supports both without blocking scene hand-off forever.
	for frame in 180:
		if int(scatter.get("build_version")) >= 1:
			return
		await get_tree().process_frame


func _collect_scatter_points(scatter: Node, flowers: bool) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if scatter == null:
		return points
	var output_root := scatter.get("output_root") as Node3D
	if output_root == null:
		return points

	for item_root in output_root.get_children():
		var item_name := String(item_root.name)
		if flowers:
			if not item_name.begins_with(FLOWER_ITEM_PREFIX):
				continue
		elif not item_name in TREE_ITEM_NAMES:
			continue
		for child in item_root.get_children():
			var multimesh_instance := child as MultiMeshInstance3D
			if multimesh_instance == null or multimesh_instance.multimesh == null:
				continue
			var multimesh := multimesh_instance.multimesh
			for instance_index in multimesh.instance_count:
				var world_transform := multimesh_instance.global_transform \
					* multimesh.get_instance_transform(instance_index)
				points.append(to_local(world_transform.origin))
	return points


func _build_batched_bees() -> void:
	_bee_instances = MultiMeshInstance3D.new()
	_bee_instances.name = "BatchedBees"
	_bee_instances.add_to_group("hub_bees")
	add_child(_bee_instances)

	_bee_multimesh = MultiMesh.new()
	_bee_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_bee_multimesh.mesh = _build_bee_mesh()
	_bee_multimesh.instance_count = bee_count
	_bee_instances.multimesh = _bee_multimesh
	_bee_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bee_instances.visibility_range_end = 95.0


func _build_bee_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.16
	body_mesh.height = 0.42
	body_mesh.radial_segments = 8
	body_mesh.rings = 3
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.13
	head_mesh.height = 0.26
	head_mesh.radial_segments = 8
	head_mesh.rings = 4
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(0.31, 0.25, 0.045)
	var wing_mesh := SphereMesh.new()
	wing_mesh.radius = 0.13
	wing_mesh.height = 0.30
	wing_mesh.radial_segments = 8
	wing_mesh.rings = 3

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.append_from(body_mesh, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
	surface.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, _yellow)

	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.append_from(head_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.21)))
	for stripe_z in [-0.07, 0.07]:
		surface.append_from(stripe_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, stripe_z)))
	surface.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, _black)

	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var wing_basis := Basis.IDENTITY.scaled(Vector3(1.25, 0.16, 0.70))
		wing_basis = Basis(Vector3.FORWARD, side * 0.42) * wing_basis
		surface.append_from(wing_mesh, 0,
			Transform3D(wing_basis, Vector3(side * 0.18, 0.13, -0.02)))
	surface.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, _wing)
	return mesh


func _seed_flight_paths() -> void:
	_bees.clear()
	for index in bee_count:
		var source_index := index % _flower_points.size()
		var target_index := _next_flower_index(source_index, index)
		var data := {
			"source": source_index,
			"target": target_index,
			"progress": fmod(float(index) * 0.173, 1.0),
			"duration": 3.4 + float(index % 9) * 0.31,
			"phase": float(index) * 2.39996,
			"size_class": index % SIZE_VARIANTS.size(),
		}
		_bees.append(data)
		_update_bee_transform(index, data)


func _next_flower_index(source_index: int, bee_index: int) -> int:
	if _flower_points.size() <= 1:
		return source_index
	var stride := 1 + (bee_index * 7 + source_index * 3) % (_flower_points.size() - 1)
	return (source_index + stride) % _flower_points.size()


func _update_bee_transform(index: int, bee_data: Dictionary) -> void:
	var from := _flower_points[int(bee_data["source"])]
	var to := _flower_points[int(bee_data["target"])]
	var progress: float = bee_data["progress"]
	var eased := smoothstep(0.0, 1.0, progress)
	var position := from.lerp(to, eased)
	var phase: float = bee_data["phase"]
	position.y += 0.60 + sin(PI * progress) * 1.35 \
		+ sin(_elapsed * 8.0 + phase) * 0.10
	position.x += sin(PI * progress * 2.0 + phase) * 0.18

	var direction := to - from
	var yaw := atan2(direction.x, direction.z) if direction.length_squared() > 0.001 else 0.0
	var size_class: int = bee_data["size_class"]
	var scale_value: float = BASE_SCALE * float(SIZE_VARIANTS[size_class])
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_value)
	_bee_multimesh.set_instance_transform(index, Transform3D(basis, position))


func _place_bee_homes(tree_points: Array[Vector3]) -> void:
	var homes := Node3D.new()
	homes.name = "BeeHomes"
	add_child(homes)
	var count := mini(bee_home_count, tree_points.size())
	for index in count:
		var point_index := int(floor(float(index) * float(tree_points.size()) / float(count)))
		var home := _make_bee_home(index)
		home.position = tree_points[point_index] + Vector3(
			0.65 if index % 2 == 0 else -0.65,
			3.4 + float(index % 3) * 0.35,
			0.25
		)
		homes.add_child(home)


func _make_bee_home(index: int) -> Node3D:
	var home := Node3D.new()
	home.name = "BeeHome_%02d" % (index + 1)
	home.add_to_group("hub_bee_homes")
	for tier in 4:
		var shell := MeshInstance3D.new()
		var shell_mesh := SphereMesh.new()
		shell_mesh.radius = 0.42 - absf(1.5 - float(tier)) * 0.055
		shell_mesh.height = 0.34
		shell_mesh.radial_segments = 10
		shell_mesh.rings = 3
		shell.mesh = shell_mesh
		shell.position.y = float(tier) * 0.22
		shell.material_override = _hive
		home.add_child(shell)
	var entrance := MeshInstance3D.new()
	entrance.name = "Entrance"
	var entrance_mesh := SphereMesh.new()
	entrance_mesh.radius = 0.105
	entrance_mesh.height = 0.12
	entrance_mesh.radial_segments = 8
	entrance_mesh.rings = 3
	entrance.mesh = entrance_mesh
	entrance.position = Vector3(0.0, 0.33, 0.40)
	entrance.material_override = _black
	home.add_child(entrance)
	return home


func _build_shared_materials() -> void:
	_yellow = StandardMaterial3D.new()
	_yellow.albedo_color = Color(1.0, 0.68, 0.06)
	_yellow.roughness = 0.72
	_black = StandardMaterial3D.new()
	_black.albedo_color = Color(0.09, 0.065, 0.04)
	_black.roughness = 0.82
	_wing = StandardMaterial3D.new()
	_wing.albedo_color = Color(0.82, 0.94, 1.0, 0.58)
	_wing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wing.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wing.cull_mode = BaseMaterial3D.CULL_DISABLED
	_hive = StandardMaterial3D.new()
	_hive.albedo_color = Color(0.82, 0.52, 0.12)
	_hive.roughness = 0.92
