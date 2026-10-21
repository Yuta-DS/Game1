extends RefCounted

## Unshaded materials for small decoration on the web.
##
## Deliberately has no `class_name`, like scene_loader.gd: callers preload it.
##
## Entering the Art Castle on the web is mostly shader compilation: Chrome
## turns every lit material into a program through its Direct3D translator, a
## lit one taking about twice as long as an unshaded one, and the castle's
## props each bring their own. Small decoration (lamps, rails, crystals,
## flowers) reads the same without lighting at the size it is seen, so on the
## web it is drawn unshaded. Landscape, trees and characters stay lit.

## A mesh smaller than this (world radius, m) is decoration.
const DECOR_RADIUS := 4.0

## Unlit colour is the material's full albedo; lit surfaces around it rarely
## reach that. Scaling it down keeps decoration from looking brighter than the
## world it sits in.
const UNLIT_TONE := 0.8

## Features that only feed lighting. Turned off on the unshaded copies, so they
## also collapse into fewer distinct shaders.
const LIGHTING_FEATURES := [
	BaseMaterial3D.FEATURE_EMISSION, BaseMaterial3D.FEATURE_NORMAL_MAPPING,
	BaseMaterial3D.FEATURE_RIM, BaseMaterial3D.FEATURE_CLEARCOAT,
	BaseMaterial3D.FEATURE_ANISOTROPY, BaseMaterial3D.FEATURE_AMBIENT_OCCLUSION,
	BaseMaterial3D.FEATURE_SUBSURFACE_SCATTERING, BaseMaterial3D.FEATURE_BACKLIGHT,
]


## Gives every small, unskinned mesh under `root` unshaded copies of its
## standard materials. One copy per original material, shared by every
## decoration that used it. Returns how many meshes changed.
static func make_decoration_unshaded(root: Node) -> int:
	var copies := {}
	var changed := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D:
			changed += int(_convert_mesh(node as MeshInstance3D, copies))
		elif node is MultiMeshInstance3D:
			changed += int(_convert_multimesh(node as MultiMeshInstance3D, copies))
	return changed


static func _convert_mesh(node: MeshInstance3D, copies: Dictionary) -> bool:
	# Skinned meshes are characters, which stay lit.
	if node.mesh == null or node.skin != null or node.get_parent() is Skeleton3D \
			or _radius(node, node.mesh) >= DECOR_RADIUS:
		return false
	if node.material_override != null:
		var copy := _unshaded(node.material_override, copies)
		if copy == null:
			return false
		node.material_override = copy
		return true
	var any := false
	for surface in node.mesh.get_surface_count():
		var copy := _unshaded(node.get_active_material(surface), copies)
		if copy != null:
			node.set_surface_override_material(surface, copy)
			any = true
	return any


static func _convert_multimesh(node: MultiMeshInstance3D, copies: Dictionary) -> bool:
	var multi := node.multimesh
	if multi == null or multi.mesh == null or _radius(node, multi.mesh) >= DECOR_RADIUS:
		return false
	if node.material_override != null:
		var copy := _unshaded(node.material_override, copies)
		if copy == null:
			return false
		node.material_override = copy
		return true
	# A MultiMesh has no per-surface overrides, so its mesh gets copied with the
	# unshaded materials in place. Only this batch's mesh changes; other meshes
	# sharing the materials keep the lit ones.
	var mesh := multi.mesh as ArrayMesh
	if mesh == null:
		return false
	var lit := mesh
	mesh = mesh.duplicate() as ArrayMesh
	var any := false
	for surface in mesh.get_surface_count():
		var copy := _unshaded(lit.surface_get_material(surface), copies)
		if copy != null:
			mesh.surface_set_material(surface, copy)
			any = true
	if any:
		multi.mesh = mesh
	return any


static func _unshaded(material: Material, copies: Dictionary) -> Material:
	var lit := material as BaseMaterial3D
	if lit == null or lit.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return null
	if not copies.has(lit):
		var copy := lit.duplicate() as BaseMaterial3D
		copy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var colour := lit.albedo_color
		if lit.emission_enabled:
			# A glowing piece keeps its glow as colour.
			var glow := lit.emission * lit.emission_energy_multiplier
			colour = Color(minf(colour.r + glow.r, 1.0), minf(colour.g + glow.g, 1.0),
				minf(colour.b + glow.b, 1.0), colour.a)
		else:
			colour = Color(colour.r * UNLIT_TONE, colour.g * UNLIT_TONE, colour.b * UNLIT_TONE, colour.a)
		copy.albedo_color = colour
		for feature in LIGHTING_FEATURES:
			copy.set_feature(feature, false)
		copies[lit] = copy
	return copies[lit]


static func _radius(node: Node3D, mesh: Mesh) -> float:
	var scale := node.global_transform.basis.get_scale()
	var size := mesh.get_aabb().size
	return Vector3(size.x * scale.x, size.y * scale.y, size.z * scale.z).length() * 0.5
