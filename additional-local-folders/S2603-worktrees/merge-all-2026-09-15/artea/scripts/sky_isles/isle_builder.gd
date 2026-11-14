# Shared island-geometry library for Sky Isles.
#
# Every floating island in this world is built the same way: a low-poly top
# surface an island agent decorates, a tapering cone underside that vanishes
# into the fog, and a scatter of root/chain geometry hanging off the bottom
# so the island reads as torn loose rather than as a clean primitive. This
# file is the one place that shape lives, so all four islands feel like the
# same world instead of four different art directions.
#
# Usage (island agents B): call `IsleBuilder.build_island(...)` once in your
# `_ready()`, parent the returned Node3D under your Isle_* root, then add
# your own buildings/props as further children. The builder does not touch
# the metadata or `state_targets()` contract — that is each island's own job.
#
# Everything here is primitive meshes (SphereMesh / CylinderMesh / BoxMesh /
# PrismMesh) with low segment counts, per the perf budget in CONTRACT.md.
extends RefCounted
class_name IsleBuilder


# Builds one floating island body: top mound + tapering root spike + hanging
# chain/root debris. Returns a Node3D ready to parent under an Isle_* node.
#
# Params:
#   radius       Horizontal size of the island's top surface, in meters.
#                 Matches the `radius` field from CONTRACT.md's ISLES table.
#   color        Base albedo for the island's rock/earth body. Callers pass
#                 the dormant or vibrant PALETTE colour for their isle.
#   detail       Segment/ring density knob, 0..2. 0 = cheapest (background
#                 or distant islands), 1 = normal, 2 = hero islands like the
#                 castle. Drives SphereMesh/CylinderMesh segment counts.
#   seed         Deterministic RNG seed so root/chain scatter is stable
#                 across reloads instead of jittering every run.
#
# Returns a Node3D named "IsleBody" containing:
#   - MeshInstance3D "Mound"     top surface (squashed low-poly sphere)
#   - MeshInstance3D "Root"      tapering underside spike (PrismMesh)
#   - Node3D "Roots"             scattered hanging root/chain fragments
static func build_island(radius: float, color: Color, detail: int = 1, seed: int = 0) -> Node3D:
	var body := Node3D.new()
	body.name = "IsleBody"

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.metallic = 0.0

	body.add_child(_build_mound(radius, material, detail))
	body.add_child(_build_root_spike(radius, material, detail))
	body.add_child(_build_hanging_roots(radius, material, detail, seed))

	return body


# Convenience for callers that already have a StandardMaterial3D they want
# reused across meshes (e.g. to share one material instance for state
# swapping via isle_state.gd's `state_targets()`). Same shape as
# `build_island` but takes the material directly instead of building one.
static func build_island_with_material(radius: float, material: StandardMaterial3D, detail: int = 1, seed: int = 0) -> Node3D:
	var body := Node3D.new()
	body.name = "IsleBody"

	body.add_child(_build_mound(radius, material, detail))
	body.add_child(_build_root_spike(radius, material, detail))
	body.add_child(_build_hanging_roots(radius, material, detail, seed))

	return body


# --- construction ------------------------------------------------------

# The top surface islanders stand on: a sphere squashed flat and pushed
# upward so only its dome shows, like an iceberg of dirt.
static func _build_mound(radius: float, material: StandardMaterial3D, detail: int) -> MeshInstance3D:
	var segments := 8 + detail * 4
	var rings := 4 + detail * 2

	var mound := MeshInstance3D.new()
	mound.name = "Mound"

	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.1
	mesh.radial_segments = segments
	mesh.rings = rings
	mound.mesh = mesh
	mound.material_override = material

	# Squash vertically and sink it so the flat-ish top sits near local Y=0
	# and the round underside tapers away below, where the root spike takes
	# over the silhouette.
	mound.scale = Vector3(1.0, 0.42, 1.0)
	mound.position.y = -radius * 0.12

	return mound


# The tapering underside: a wide prism narrowing to a point, giving the
# classic floating-island silhouette without a single high-poly mesh.
static func _build_root_spike(radius: float, material: StandardMaterial3D, detail: int) -> MeshInstance3D:
	var spike := MeshInstance3D.new()
	spike.name = "Root"

	var mesh := PrismMesh.new()
	mesh.size = Vector3(radius * 1.5, radius * 2.4, radius * 1.5)
	mesh.left_to_right = 0.5
	spike.mesh = mesh
	spike.material_override = material

	# Prisms build pointing up; flip so the point hangs down into the fog.
	spike.rotation.z = PI
	spike.position.y = -radius * 1.5

	return spike


# Small root/chain fragments dangling off the underside — the detail that
# reads as "torn from the ground" rather than "modeled as a cone". Kept to a
# handful of cheap cylinders; count scales with detail level.
static func _build_hanging_roots(radius: float, material: StandardMaterial3D, detail: int, seed: int) -> Node3D:
	var roots := Node3D.new()
	roots.name = "Roots"

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var count := 3 + detail * 3
	for i in count:
		var strand := MeshInstance3D.new()

		var mesh := CylinderMesh.new()
		mesh.top_radius = radius * 0.045
		mesh.bottom_radius = radius * 0.02
		mesh.height = radius * rng.randf_range(0.6, 1.4)
		mesh.radial_segments = 4
		strand.mesh = mesh
		strand.material_override = material

		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(0.0, radius * 0.55)
		strand.position = Vector3(
			cos(angle) * dist,
			-radius * 1.9 - mesh.height * 0.5,
			sin(angle) * dist)
		strand.rotation.x = rng.randf_range(-0.3, 0.3)
		strand.rotation.z = rng.randf_range(-0.3, 0.3)

		roots.add_child(strand)

	return roots
