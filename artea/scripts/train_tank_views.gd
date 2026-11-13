extends Node3D
## Original exterior tank plus the existing low-profile driver-FPS rendering.
## Only visuals change; camera settings, collision and mechanisms are shared.

var first_person_active := false
var exterior_parts: Array[Node3D] = []
var fps_parts: Array[Node3D] = []
var moving_mounts: Array[Node3D] = []
var exterior_shell: MeshInstance3D
var fps_shell: MeshInstance3D
var fps_gear_covers: Node3D

func _ready() -> void:
	# CameraFollow updates at 100. Select the visual after its current mode/pose.
	process_priority = 101
	exterior_shell = MeshInstance3D.new()
	exterior_shell.name = "OriginalTankShell"
	exterior_shell.mesh = ArrayMesh.new()
	add_child(exterior_shell)
	fps_shell = MeshInstance3D.new()
	fps_shell.name = "FPSTankShell"
	fps_shell.mesh = ArrayMesh.new()
	fps_shell.visible = false
	add_child(fps_shell)
	exterior_parts.append(exterior_shell)
	fps_parts.append(fps_shell)

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var driver_fps: bool = camera != null and camera.has_method("get_view_mode") \
		and camera.call("get_view_mode") == "first" and camera.get("_mode") == "follow" \
		and camera.call("is_ride_view_active") and camera.get("_driver_view_train") == get_parent()
	set_first_person(driver_fps)

func set_first_person(active: bool) -> void:
	if active == first_person_active:
		return
	first_person_active = active
	if is_instance_valid(fps_gear_covers):
		fps_gear_covers.visible = active
	for part in exterior_parts:
		part.visible = not active
	for part in fps_parts:
		part.visible = active
	for mount in moving_mounts:
		mount.transform = mount.get_meta("fps_fit") if active else Transform3D.IDENTITY

func add_static_surface(original: Array, fitted: Array, indices: PackedInt32Array,
		pose: Transform3D, material: Material) -> void:
	exterior_shell.transform = pose
	fps_shell.transform = pose
	_append_surface(exterior_shell.mesh, original, indices, material)
	_append_surface(fps_shell.mesh, fitted, indices, material)

func add_moving_part(part: Node3D, fps_fit: Transform3D) -> void:
	# Put the placement transform above the original animated pivot. No duplicate
	# gears, pressure orbs, valves or exhaust emitters are registered/animated.
	var mount := Node3D.new()
	mount.name = "TankMechanismMount_%02d" % moving_mounts.size()
	part.get_parent().add_child(mount)
	part.reparent(mount)
	mount.set_meta("fps_fit", fps_fit)
	moving_mounts.append(mount)

func add_native_part(part: MeshInstance3D, fps_pose: Transform3D) -> void:
	var low := MeshInstance3D.new()
	low.name = "FPS_" + String(part.name)
	low.mesh = part.mesh
	low.material_override = part.material_override
	low.cast_shadow = part.cast_shadow
	part.get_parent().add_child(low)
	low.transform = fps_pose
	low.visible = false
	exterior_parts.append(part)
	fps_parts.append(low)

static func _append_surface(mesh: ArrayMesh, arrays: Array,
		indices: PackedInt32Array, material: Material) -> void:
	# Compact indexed components so bounds exclude unrelated train geometry.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	for index in indices:
		if normals.size() == vertices.size():
			tool.set_normal(normals[index])
		if uv.size() == vertices.size():
			tool.set_uv(uv[index])
		if uv2.size() == vertices.size():
			tool.set_uv2(uv2[index])
		if colors.size() == vertices.size():
			tool.set_color(colors[index])
		if tangents.size() == vertices.size() * 4:
			tool.set_tangent(Plane(Vector3(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2]), tangents[index * 4 + 3]))
		tool.add_vertex(vertices[index])
	tool.index()
	tool.commit(mesh)
