extends RefCounted

## Scene-owned immutable primitives: repeated railway and castle fittings share
## vertex buffers, while nodes, materials, transforms and collisions stay local.
var _boxes: Dictionary = {}
var _cylinders: Dictionary = {}
var _sphere: SphereMesh

func box(size: Vector3) -> BoxMesh:
	if not _boxes.has(size):
		var mesh := BoxMesh.new()
		mesh.size = size
		_boxes[size] = mesh
	return _boxes[size]

func cylinder(radius: float, height: float, segments: int) -> CylinderMesh:
	var key := Vector3(radius, height, float(segments))
	if not _cylinders.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = segments
		_cylinders[key] = mesh
	return _cylinders[key]

func sphere() -> SphereMesh:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 1.0
		_sphere.height = 2.0
		_sphere.radial_segments = 8
		_sphere.rings = 4
	return _sphere
