"""Build the reference-faithful crystal branch canopy for the Tree of Life.

The canopy is a visual-only overlay. It preserves the production tree's trunk,
root collision, and 9.5 m player arch while replacing the old low-poly foliage.

Run with:
  blender --background --python tools/blender/build_crystal_branch_canopy.py
"""

from __future__ import annotations

import json
import math
import os
from dataclasses import dataclass
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT = Path(__file__).resolve().parents[2]
ROOT = PROJECT / "assets3D/tree_of_life/canopy"
BLEND_PATH = ROOT / "source/crystal_branch_canopy.blend"
GLB_PATH = ROOT / "glb/crystal_branch_canopy.glb"
MANIFEST_PATH = ROOT / "crystal_branch_canopy_manifest.json"
PREVIEW_PATH = PROJECT / "artifacts/tree_of_life_canopy/crystal_branch_canopy.png"
LEAF_SOURCE = PROJECT / "assets3D/tree_of_life/leaves/reference_faithful/source"


@dataclass(frozen=True)
class LeafSource:
    slug: str
    blend_name: str
    object_name: str


LEAF_SOURCES = (
    LeafSource("living_leaf_fan", "living_leaf_fan_reference_faithful.blend", "LivingLeafFanReferenceRelief"),
    LeafSource("magic_rune_leaf", "magic_rune_leaf_reference_faithful.blend", "MagicRuneLeafReferenceRelief"),
    LeafSource("solar_glass_science_leaf", "solar_glass_science_leaf_reference_faithful.blend", "SolarGlassScienceLeafReferenceRelief"),
    LeafSource("emerald_sensor_leaf", "emerald_sensor_leaf_reference_faithful.blend", "EmeraldSensorLeafReferenceRelief"),
)


# Each limb is a tapered black bio-tech spine. The same centerline also drives
# a raised cyan sap conduit and the positions of brass articulation collars.
LIMBS = (
    ((0, 0, 25), (-7, 0, 29), (-16, 1, 34), (-27, 3, 39), (-36, 5, 43)),
    ((0, 0, 25), (7, 0, 29), (16, -1, 34), (27, -3, 39), (36, -5, 43)),
    ((-2, 0, 27), (-5, -4, 33), (-10, -11, 39), (-16, -18, 44)),
    ((2, 0, 27), (5, 4, 33), (10, 11, 39), (16, 18, 44)),
    ((-3, 1, 27), (-10, 6, 34), (-18, 13, 40), (-24, 21, 44)),
    ((3, -1, 27), (10, -6, 34), (18, -13, 40), (24, -21, 44)),
    ((-1, 0, 28), (-3, 1, 35), (-5, 3, 42), (-7, 5, 49)),
    ((1, 0, 28), (3, -1, 35), (5, -3, 42), (7, -5, 49)),
    ((-1, 0, 27), (-8, -2, 34), (-18, -5, 39), (-29, -9, 42)),
    ((1, 0, 27), (8, 2, 34), (18, 5, 39), (29, 9, 42)),
)


TWIGS = (
    ((-16, 1, 34), (-20, -4, 39), (-23, -8, 44)),
    ((-27, 3, 39), (-29, 10, 43), (-29, 15, 47)),
    ((16, -1, 34), (20, 4, 39), (23, 8, 44)),
    ((27, -3, 39), (29, -10, 43), (29, -15, 47)),
    ((-10, -11, 39), (-18, -12, 44), (-24, -11, 47)),
    ((10, 11, 39), (18, 12, 44), (24, 11, 47)),
    ((-18, 13, 40), (-25, 12, 44), (-31, 10, 46)),
    ((18, -13, 40), (25, -12, 44), (31, -10, 46)),
    ((-5, 3, 42), (-13, 5, 46), (-18, 8, 49)),
    ((5, -3, 42), (13, -5, 46), (18, -8, 49)),
    ((-18, -5, 39), (-23, 1, 43), (-27, 5, 46)),
    ((18, 5, 39), (23, -1, 43), (27, -5, 46)),
)


def _make_lower_limb(index: int):
    """Create one broad lower-canopy bough immediately above the root crown."""
    angle = math.tau * index / 12.0 + math.radians(7.5)
    handed = -1.0 if index % 2 else 1.0
    points = []
    for radius, height, bend in (
            (4.8, 18.2, 0.00),
            (10.5, 20.8, handed * 0.055),
            (20.0, 23.7, -handed * 0.065),
            (31.5, 26.0, handed * 0.075),
            (41.0, 27.8, -handed * 0.035)):
        local_angle = angle + bend
        points.append((math.cos(local_angle) * radius,
            math.sin(local_angle) * radius, height))
    return tuple(points)


LOWER_LIMBS = tuple(_make_lower_limb(index) for index in range(12))


def _make_lower_twig(index: int):
    parent = LOWER_LIMBS[index]
    source = Vector(parent[2])
    base_angle = math.atan2(source.y, source.x)
    side = -1.0 if index % 2 else 1.0
    middle_angle = base_angle + side * 0.22
    end_angle = base_angle + side * 0.34
    return (
        tuple(source),
        (math.cos(middle_angle) * 29.0, math.sin(middle_angle) * 29.0,
            27.0 + 0.45 * (index % 3)),
        (math.cos(end_angle) * 38.0, math.sin(end_angle) * 38.0,
            29.0 + 0.55 * (index % 4)),
    )


LOWER_TWIGS = tuple(_make_lower_twig(index) for index in range(12))


# Interleaved family cycle for the full 20,000-leaf crown. Green remains the
# living base while violet, solar glass and emerald recur between every few
# green leaves instead of forming isolated color blocks. Ten thousand entries
# produce exact counts of 7500 / 5000 / 5000 / 2500.
LEAF_FAMILY_PATTERN = (0, 1, 2, 0, 3, 1, 0, 2)


def generate_root_system():
    """Return broad buttress roots plus low secondary ground roots.

    The two front roots are authored separately to frame the production 9.5 m
    passage. Other roots spiral around the mound and overlap like load-bearing
    ribs instead of radiating as identical tent poles.
    """
    main_roots = []

    # Entrance-framing roots: broad at the paving, tall through the arch, then
    # narrow where they merge into the trunk crown.
    for side in (-1.0, 1.0):
        points = (
            (side * 11.8, -19.2, 0.55),
            (side * 9.7, -15.6, 1.9),
            (side * 7.8, -11.4, 4.8),
            (side * 6.05, -6.9, 8.1),
            (side * 5.25, -4.6, 11.2),
            (side * 5.15, -3.0, 12.8),
            (side * 5.05, -1.5, 14.2),
        )
        main_roots.append((points,
            (2.85, 2.55, 2.16, 1.72, 1.48, 1.24, 1.04),
            (0.84, 1.05, 1.38, 1.65, 1.72, 1.50, 1.20), True))

    # Rear and side buttresses. The front sector remains open, while unequal
    # twist and height profiles avoid a procedural radial-star silhouette.
    angles = (-165, -140, -40, -15, 18, 48, 78, 108, 138, 168)
    for index, angle_degrees in enumerate(angles):
        angle = math.radians(angle_degrees)
        handed = -1.0 if index % 2 else 1.0
        twist = handed * (0.13 + 0.025 * (index % 3))
        points = []
        for radius, height, twist_factor in (
                (19.2, 0.48, 0.0), (15.8, 1.35, 0.75), (12.6, 3.6, -0.45),
                (9.6, 6.7, 0.60), (7.2, 10.1, -0.25), (5.4, 13.0, 0.25),
                (3.7, 15.3, 0.0)):
            local_angle = angle + twist * twist_factor
            points.append((math.cos(local_angle) * radius, math.sin(local_angle) * radius, height))
        pillar_side = 1.0 if math.cos(angle) >= 0.0 else -1.0
        points[-2] = (pillar_side * 6.35, math.sin(angle) * 2.5, 10.8 + 0.55 * (index % 3))
        points[-1] = (pillar_side * 6.05, math.sin(angle) * 1.25, 12.7 + 0.65 * (index % 4))
        width_bias = 0.12 * (index % 3)
        main_roots.append((tuple(points),
            (2.80 + width_bias, 2.70, 2.42, 2.08, 1.72, 1.38, 1.04),
            (0.72, 0.88, 1.12, 1.40, 1.60, 1.46, 1.14), False))

    secondary_roots = []
    for index, (points, _, _, _) in enumerate(main_roots):
        source = Vector(points[1])
        radial_angle = math.atan2(source.y, source.x)
        branch_angle = radial_angle + (0.32 if index % 2 else -0.32)
        secondary_roots.append((
            tuple(source.lerp(Vector((math.cos(branch_angle) * 21.0,
                math.sin(branch_angle) * 21.0, 0.32)), step / 4.0)
                + Vector((0.0, 0.0, 0.7 * math.sin(math.pi * step / 4.0)))
                for step in range(5)),
            (1.48, 1.24, 0.96, 0.62, 0.24),
            (0.70, 0.58, 0.46, 0.30, 0.12),
        ))
    return main_roots, secondary_roots


def generate_leaf_system(branch_paths):
    """Build an explicit branch -> support twig -> compound leaf hierarchy."""
    family_scale = (1.00, 0.94, 0.92, 0.70)
    cluster_specs = []
    branch_points = [Vector(point) for path in branch_paths for point in path]
    for path_index, path in enumerate(branch_paths):
        for control_offset in (-3, -2, -1):
            anchor = Vector(path[control_offset])
            center = anchor.copy()
            outward = Vector((center.x, center.y, 0.0))
            if outward.length_squared > 0.0001:
                outward.normalize()
            end_bias = {-3: -0.35, -2: 0.30, -1: 0.85}[control_offset]
            center += outward * end_bias
            center.z += 0.32 * ((path_index % 5) - 2)
            center.z -= max(0.0, Vector((center.x, center.y)).length - 12.0) * 0.075
            cluster_specs.append((anchor, center))

    inner_centers = [Vector((0.0, 0.0, 38.6))]
    for ring_radius, ring_count, ring_height, phase in (
            (7.5, 8, 37.2, 0.18),
            (14.5, 12, 35.3, 0.41)):
        for ring_index in range(ring_count):
            ring_angle = math.tau * ring_index / ring_count + phase
            inner_centers.append(Vector((
                math.cos(ring_angle) * ring_radius,
                math.sin(ring_angle) * ring_radius,
                ring_height + 0.65 * math.sin(ring_angle * 2.0),
            )))
    for center in inner_centers:
        # Inner crown pads are not allowed to float: explicitly connect each
        # one to the nearest authored limb control point.
        anchor = min(branch_points, key=lambda point: (point - center).length_squared)
        cluster_specs.append((anchor.copy(), center))

    support_paths = []
    support_twigs_per_cluster = 9
    for cluster_index, (anchor, center) in enumerate(cluster_specs):
        radial_angle = math.atan2(center.y, center.x)
        if Vector((center.x, center.y)).length < 1.0:
            radial_angle = 0.35
        for twig_index in range(support_twigs_per_cluster):
            spread = (twig_index / (support_twigs_per_cluster - 1) - 0.5) * math.radians(150.0)
            twig_angle = radial_angle + spread
            twig_length = 4.35 + 0.70 * math.sin(cluster_index * 1.17 + twig_index * 0.83)
            direction = Vector((math.cos(twig_angle), math.sin(twig_angle), 0.0))
            middle = center + direction * (twig_length * 0.38)
            middle.z += 0.50 + 0.48 * math.sin(twig_index * 1.43 + cluster_index)
            end = center + direction * twig_length
            end.z += -0.45 + 1.15 * math.cos(twig_index * 0.91 + cluster_index * 0.37)
            support_paths.append((tuple(anchor), tuple(middle), tuple(end)))

    total_leaves = 20000
    cluster_count = len(cluster_specs)
    leaves_per_cluster = math.ceil(total_leaves / cluster_count)
    ranks_per_twig = math.ceil(leaves_per_cluster / support_twigs_per_cluster)
    placements = []
    for global_index in range(total_leaves):
        cluster_index = global_index % cluster_count
        local_index = global_index // cluster_count
        twig_index = local_index % support_twigs_per_cluster
        rank_index = local_index // support_twigs_per_cluster
        path = support_paths[cluster_index * support_twigs_per_cluster + twig_index]
        start, middle, end = (Vector(point) for point in path)
        t = 0.22 + 0.76 * (rank_index + 0.5) / ranks_per_twig
        one_minus_t = 1.0 - t
        position = start * (one_minus_t * one_minus_t)
        position += middle * (2.0 * one_minus_t * t) + end * (t * t)
        tangent = (middle - start) * (2.0 * one_minus_t) + (end - middle) * (2.0 * t)
        lateral = Vector((-tangent.y, tangent.x, 0.0))
        if lateral.length_squared > 0.0001:
            lateral.normalize()
        ordered_offset = ((rank_index % 3) - 1) * 0.24
        position += lateral * ordered_offset
        position.z += 0.22 * math.sin(rank_index * 1.41 + twig_index * 0.77)
        family = LEAF_FAMILY_PATTERN[global_index % len(LEAF_FAMILY_PATTERN)]
        scale = (0.34 + 0.070 * t) * family_scale[family]
        scale *= 0.94 + 0.10 * math.sin(global_index * 0.73)
        rotation_z = math.degrees(math.atan2(tangent.y, tangent.x)) + 90.0
        rotation_z += ((rank_index % 2) * 2 - 1) * 11.0
        tilt_x = 30.0 + 22.0 * t + 5.0 * math.sin(twig_index * 1.19)
        tilt_y = ((rank_index % 3) - 1) * 7.0
        placements.append((family, tuple(position), rotation_z, scale, tilt_x, tilt_y))
    return placements, support_paths, cluster_count, support_twigs_per_cluster


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def material(name: str, color, metallic: float, roughness: float, emission=None, strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color[:3], color[3] if len(color) > 3 else 1.0)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = mat.diffuse_color
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if emission is not None:
        if "Emission Color" in shader.inputs:
            shader.inputs["Emission Color"].default_value = (*emission, 1.0)
            shader.inputs["Emission Strength"].default_value = strength
        elif "Emission" in shader.inputs:
            shader.inputs["Emission"].default_value = (*emission, 1.0)
            shader.inputs["Emission Strength"].default_value = strength
    return mat


def make_tube(name: str, points, radii, sides: int, mat, collection) -> bpy.types.Object:
    vectors = [Vector(point) for point in points]
    vertices = []
    for index, point in enumerate(vectors):
        if index == 0:
            tangent = (vectors[1] - point).normalized()
        elif index == len(vectors) - 1:
            tangent = (point - vectors[index - 1]).normalized()
        else:
            tangent = (vectors[index + 1] - vectors[index - 1]).normalized()
        reference = Vector((0, 0, 1))
        if abs(tangent.dot(reference)) > 0.92:
            reference = Vector((0, 1, 0))
        right = tangent.cross(reference).normalized()
        up = right.cross(tangent).normalized()
        radius = radii[index]
        for side in range(sides):
            angle = math.tau * side / sides
            offset = right * math.cos(angle) * radius + up * math.sin(angle) * radius
            vertices.append(tuple(point + offset))
    faces = []
    for ring in range(len(vectors) - 1):
        start = ring * sides
        following = (ring + 1) * sides
        for side in range(sides):
            nxt = (side + 1) % sides
            faces.append((start + side, start + nxt, following + nxt, following + side))
    faces.append(tuple(reversed(range(sides))))
    final_start = (len(vectors) - 1) * sides
    faces.append(tuple(final_start + side for side in range(sides)))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    return obj


def make_buttress_root(name: str, points, widths, heights, materials, collection) -> bpy.types.Object:
    """Build a faceted, elliptic root with alternating bark armor panels."""
    control_points = [Vector(point) for point in points]

    # Catmull-Rom interpolation removes the beam-like straight spans while the
    # low-sided cross-section retains the large carved bark facets.
    vectors = []
    dense_widths = []
    dense_heights = []
    subdivisions = 4
    for segment in range(len(control_points) - 1):
        p0 = control_points[max(0, segment - 1)]
        p1 = control_points[segment]
        p2 = control_points[segment + 1]
        p3 = control_points[min(len(control_points) - 1, segment + 2)]
        for substep in range(subdivisions):
            t = substep / subdivisions
            t2 = t * t
            t3 = t2 * t
            point = 0.5 * ((2.0 * p1) + (-p0 + p2) * t
                + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
                + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
            smooth_t = t * t * (3.0 - 2.0 * t)
            vectors.append(point)
            dense_widths.append(widths[segment] + (widths[segment + 1] - widths[segment]) * smooth_t)
            dense_heights.append(heights[segment] + (heights[segment + 1] - heights[segment]) * smooth_t)
    vectors.append(control_points[-1])
    dense_widths.append(widths[-1])
    dense_heights.append(heights[-1])

    sides = 12
    vertices = []
    for index, point in enumerate(vectors):
        if index == 0:
            tangent = (vectors[1] - point).normalized()
        elif index == len(vectors) - 1:
            tangent = (point - vectors[index - 1]).normalized()
        else:
            tangent = (vectors[index + 1] - vectors[index - 1]).normalized()
        reference = Vector((0, 0, 1))
        if abs(tangent.dot(reference)) > 0.93:
            reference = Vector((0, 1, 0))
        right = tangent.cross(reference).normalized()
        up = right.cross(tangent).normalized()
        for side in range(sides):
            angle = math.tau * side / sides
            irregularity = 1.0 + 0.055 * math.sin(index * 2.17 + side * 1.61)
            offset = right * math.cos(angle) * dense_widths[index] * irregularity
            offset += up * math.sin(angle) * dense_heights[index] * irregularity
            vertices.append(tuple(point + offset))

    faces = []
    material_indices = []
    for ring in range(len(vectors) - 1):
        for side in range(sides):
            nxt = (side + 1) % sides
            start = ring * sides
            following = (ring + 1) * sides
            faces.append((start + side, start + nxt, following + nxt, following + side))
            # Broad alternating axial panels create the armored bark segmentation
            # visible in the reference without relying on a flat painted texture.
            material_indices.append((side // 2 + ring // (subdivisions * 2)) % len(materials))
    faces.append(tuple(reversed(range(sides))))
    material_indices.append(0)
    final_start = (len(vectors) - 1) * sides
    faces.append(tuple(final_start + side for side in range(sides)))
    material_indices.append(1)

    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    for mat in materials:
        mesh.materials.append(mat)
    for polygon, material_index in zip(mesh.polygons, material_indices):
        polygon.material_index = material_index
        polygon.use_smooth = False
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return obj


def add_collar(name: str, position, tangent: Vector, radius: float, mat, collection) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=0.20, major_segments=16, minor_segments=6, location=position)
    collar = bpy.context.object
    collar.name = name
    collar.rotation_mode = "QUATERNION"
    collar.rotation_quaternion = tangent.normalized().to_track_quat("Z", "Y")
    collar.data.materials.append(mat)
    for owner in list(collar.users_collection):
        owner.objects.unlink(collar)
    collection.objects.link(collar)
    return collar


def append_leaf_template(source: LeafSource, collection) -> bpy.types.Object:
    path = LEAF_SOURCE / source.blend_name
    with bpy.data.libraries.load(str(path), link=False) as (available, requested):
        if source.object_name not in available.objects:
            raise RuntimeError(f"{source.object_name} missing from {path}")
        requested.objects = [source.object_name]
    template = requested.objects[0]
    collection.objects.link(template)
    template.hide_render = True
    template.hide_viewport = True
    template.name = f"TEMPLATE_{source.object_name}"
    # Small leaves need to retain their painted color under both daylight and
    # cyan night lighting. Reuse the albedo as a very low-strength emissive map.
    for mat in template.data.materials:
        if mat is None or not mat.use_nodes:
            continue
        shader = next((node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED"), None)
        texture = next((node for node in mat.node_tree.nodes if node.type == "TEX_IMAGE"), None)
        if shader is None or texture is None:
            continue
        emission_input = shader.inputs.get("Emission Color") or shader.inputs.get("Emission")
        strength_input = shader.inputs.get("Emission Strength")
        if emission_input is not None and strength_input is not None:
            mat.node_tree.links.new(texture.outputs["Color"], emission_input)
            strength_input.default_value = 0.32
    return template


def add_crystal_hub(materials, collection) -> None:
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=2.9, depth=1.5, location=(0, 0, 25.6))
    base = bpy.context.object
    base.name = "CentralCrystalBrassSocket"
    base.data.materials.append(materials["brass"])
    for owner in list(base.users_collection):
        owner.objects.unlink(base)
    collection.objects.link(base)

    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=1.75, radius2=1.05, depth=4.8, location=(0, 0, 28.7))
    crystal = bpy.context.object
    crystal.name = "CentralCrystalPowerNode"
    crystal.data.materials.append(materials["crystal"])
    for owner in list(crystal.users_collection):
        owner.objects.unlink(crystal)
    collection.objects.link(crystal)

    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=1.05, radius2=0.0, depth=2.4, location=(0, 0, 32.3))
    tip = bpy.context.object
    tip.name = "CentralCrystalPowerNodeTip"
    tip.data.materials.append(materials["crystal"])
    for owner in list(tip.users_collection):
        owner.objects.unlink(tip)
    collection.objects.link(tip)

    bpy.ops.mesh.primitive_torus_add(major_radius=2.3, minor_radius=0.28, major_segments=20, minor_segments=8, location=(0, 0, 27.0))
    ring = bpy.context.object
    ring.name = "CentralCrystalArticulationRing"
    ring.data.materials.append(materials["brass"])
    for owner in list(ring.users_collection):
        owner.objects.unlink(ring)
    collection.objects.link(ring)


def build_canopy() -> tuple[list[bpy.types.Object], dict]:
    clear_scene()
    branch_collection = bpy.data.collections.new("CrystalBranchSystems")
    leaf_collection = bpy.data.collections.new("ReferenceFaithfulLeaves")
    bpy.context.scene.collection.children.link(branch_collection)
    bpy.context.scene.collection.children.link(leaf_collection)

    materials = {
        "wood": material("MAT_CanopyBlackBioTechWood", (0.13, 0.062, 0.030, 1), 0.20, 0.30),
        "root_dark": material("MAT_RootBarkShadow", (0.28, 0.055, 0.012, 1), 0.08, 0.78, (0.16, 0.018, 0.003), 0.18),
        "root_mid": material("MAT_RootBarkUmber", (0.48, 0.115, 0.025, 1), 0.10, 0.68, (0.28, 0.035, 0.005), 0.16),
        "root_warm": material("MAT_RootBarkWarmPlate", (0.68, 0.245, 0.055, 1), 0.12, 0.60, (0.38, 0.075, 0.010), 0.14),
        "cyan": material("MAT_CanopyCyanSapEnergy", (0.01, 0.32, 0.42, 1), 0.15, 0.24, (0.05, 0.85, 1.0), 6.0),
        "root_cyan": material("MAT_RootCyanSapInlay", (0.01, 0.25, 0.34, 1), 0.12, 0.28, (0.03, 0.72, 0.92), 3.2),
        "root_cavity": material("MAT_RootEntranceCavity", (0.008, 0.012, 0.018, 1), 0.04, 0.94),
        "road_metal": material("MAT_PoweredMeshRouteMetal", (0.055, 0.075, 0.095, 1), 0.72, 0.34),
        "road_mesh": material("MAT_PoweredMeshRouteGrid", (0.16, 0.20, 0.23, 1), 0.64, 0.42),
        "brass": material("MAT_CanopyBrassArticulation", (0.68, 0.31, 0.055, 1), 0.82, 0.24),
        "crystal": material("MAT_CanopyCrystalPowerNode", (0.06, 0.40, 0.72, 0.92), 0.18, 0.12, (0.15, 0.75, 1.0), 8.0),
        "root_relay_crystal": material("MAT_RootRelayCrystal", (0.025, 0.30, 0.52, 0.96), 0.12, 0.18, (0.03, 0.62, 0.88), 2.0),
    }
    export_objects = []

    def add_tech_box(name, location, dimensions, mat):
        bpy.ops.mesh.primitive_cube_add(location=location)
        obj = bpy.context.object
        obj.name = name
        obj.scale = tuple(value * 0.5 for value in dimensions)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.data.materials.append(mat)
        for owner in list(obj.users_collection):
            owner.objects.unlink(obj)
        branch_collection.objects.link(obj)
        export_objects.append(obj)
        return obj

    # LIMBS were authored against the unscaled concept sheet. Compress them at
    # source level so the parent scene's 1.65x transform does not inflate the
    # canopy and expose long bare branch tips.
    def game_ready_path(path):
        # Branch tips now reach the same crown radius as the small leaf layers,
        # preventing the former large-leaf / short-branch mismatch.
        return tuple((x, y, 25.0 + (z - 25.0) * 0.56) for x, y, z in path)

    major_paths = list(LIMBS) + list(LOWER_LIMBS)
    twig_paths = list(TWIGS) + list(LOWER_TWIGS)
    all_paths = [game_ready_path(path) for path in (major_paths + twig_paths)]
    major_path_count = len(major_paths)
    leaf_placements, leaf_support_paths, foliage_cluster_count, support_twigs_per_cluster = \
        generate_leaf_system(all_paths)

    # Recessed dark chamber behind the buttresses. Its arched silhouette and
    # cyan well make the entrance legible instead of showing bright sky through
    # a random gap between roots.
    cavity_vertices = (
        (-4.7, 2.4, 0.15), (4.7, 2.4, 0.15), (4.7, 2.4, 7.0),
        (3.8, 2.4, 9.2), (2.2, 2.4, 10.8), (0.0, 2.4, 11.5),
        (-2.2, 2.4, 10.8), (-3.8, 2.4, 9.2), (-4.7, 2.4, 7.0),
    )
    cavity_mesh = bpy.data.meshes.new("RootEntranceCavityMesh")
    cavity_mesh.from_pydata(cavity_vertices, [], (tuple(range(len(cavity_vertices))),))
    cavity_mesh.materials.append(materials["root_cavity"])
    cavity = bpy.data.objects.new("RootEntranceDarkCavity", cavity_mesh)
    branch_collection.objects.link(cavity)
    export_objects.append(cavity)

    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=2.0, depth=0.28, location=(0, -2.8, 0.82))
    well = bpy.context.object
    well.name = "RootChamberEnergyWell"
    well.data.materials.append(materials["crystal"])
    for owner in list(well.users_collection):
        owner.objects.unlink(well)
    branch_collection.objects.link(well)
    export_objects.append(well)
    bpy.ops.mesh.primitive_torus_add(major_radius=2.35, minor_radius=0.16,
        major_segments=24, minor_segments=6, location=(0, -2.8, 0.92))
    well_ring = bpy.context.object
    well_ring.name = "RootChamberBrassWellRing"
    well_ring.data.materials.append(materials["brass"])
    for owner in list(well_ring.users_collection):
        owner.objects.unlink(well_ring)
    branch_collection.objects.link(well_ring)
    export_objects.append(well_ring)
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.52, radius2=0.08,
        depth=3.2, location=(0, -2.8, 2.42))
    beacon = bpy.context.object
    beacon.name = "RootChamberCyanBeacon"
    beacon.data.materials.append(materials["root_relay_crystal"])
    for owner in list(beacon.users_collection):
        owner.objects.unlink(beacon)
    branch_collection.objects.link(beacon)
    export_objects.append(beacon)

    # Dedicated living-root jambs make the central opening read as an authored
    # doorway instead of an incidental space between radial buttresses.  Each
    # jamb stays outside a 9.8 m clear ground opening and bends inward only
    # above player height, forming the root arch visible in the reference.
    doorway_root_count = 2
    doorway_joint_count = 0
    doorway_electric_fiber_count = 0
    for side, side_name in ((-1.0, "Left"), (1.0, "Right")):
        doorway_points = (
            (side * 6.55, -15.8, 0.62),
            (side * 6.35, -12.8, 2.7),
            (side * 5.95, -9.7, 5.8),
            (side * 5.15, -7.0, 8.2),
            (side * 3.45, -4.8, 10.1),
            (side * 0.35, -3.35, 11.55),
        )
        doorway_widths = (1.48, 1.42, 1.28, 1.08, 0.90, 0.78)
        doorway_heights = (0.82, 1.05, 1.28, 1.35, 1.18, 0.88)
        doorway_widths = tuple(value * 0.86 for value in doorway_widths)
        doorway_heights = tuple(value * 0.90 for value in doorway_heights)
        doorway_root = make_buttress_root(
            f"DoorwayLivingRootJamb_{side_name}", doorway_points,
            doorway_widths, doorway_heights,
            (materials["root_dark"], materials["root_mid"], materials["root_warm"]),
            branch_collection)
        export_objects.append(doorway_root)
        # One dominant sap vein and two shorter tributaries follow each living
        # jamb. The tributaries converge into the main line instead of running
        # as parallel cables, matching the organically branching reference.
        fiber_specs = (
            ((0, 1, 2, 3, 4, 5), (0.0, 0.0, 0.0, 0.0, 0.0, 0.0), 0.15),
            ((0, 1, 2, 3), (0.72, 0.56, 0.32, 0.0), 0.085),
            ((1, 2, 3, 4, 5), (-0.62, -0.48, -0.30, -0.14, 0.0), 0.080),
        )
        for fiber_index, (point_indices, lateral_factors, base_radius) in enumerate(fiber_specs):
            fiber_points = tuple(
                (doorway_points[index][0] + side * lateral_factors[offset] * doorway_widths[index],
                    doorway_points[index][1] - doorway_heights[index] * 0.82,
                    doorway_points[index][2] + doorway_heights[index] *
                        (0.42 + 0.06 * abs(lateral_factors[offset])))
                for offset, index in enumerate(point_indices))
            doorway_fiber = make_tube(
                f"DoorwayElectricFiber_{side_name}_{fiber_index:02d}", fiber_points,
                tuple(base_radius * (1.0 - 0.045 * index)
                    for index in range(len(fiber_points))),
                7, materials["root_cyan"], branch_collection)
            export_objects.append(doorway_fiber)
            doorway_electric_fiber_count += 1
        doorway_vectors = [Vector(point) for point in doorway_points]
        for joint_index in range(1, len(doorway_points) - 1):
            tangent = doorway_vectors[joint_index + 1] - doorway_vectors[joint_index - 1]
            joint = add_collar(
                f"EditableDoorwayRootJoint_{side_name}_{joint_index:02d}",
                doorway_points[joint_index], tangent,
                doorway_widths[joint_index] * 1.02,
                materials["root_warm" if joint_index % 2 else "root_dark"],
                branch_collection)
            joint.scale = (1.0, 0.68, 1.0)
            export_objects.append(joint)
            doorway_joint_count += 1

    # Walkable route overlay: the production court remains the collision floor;
    # these visual rails, grating bars and cables create the powered mesh road.
    route_start_y = -29.0
    route_end_y = -4.7
    route_plate_count = 12
    for plate_index in range(route_plate_count):
        plate_y = route_start_y + (route_end_y - route_start_y) * \
            (plate_index + 0.5) / route_plate_count
        add_tech_box(f"PoweredRouteDeckPlate_{plate_index:02d}",
            (0.0, plate_y, 0.86), (6.55, 1.58, 0.16), materials["road_metal"])
    for rail_index, x in enumerate((-3.15, -1.55, 0.0, 1.55, 3.15)):
        rail_mat = materials["brass"] if rail_index == 2 else materials["road_mesh"]
        rail = make_tube(f"PoweredRouteLongitudinalRail_{rail_index:02d}",
            ((x, route_start_y, 0.86), (x, route_end_y, 0.86)),
            (0.07, 0.07), 6, rail_mat, branch_collection)
        export_objects.append(rail)
    crossbar_count = 17
    for crossbar in range(crossbar_count):
        y = route_start_y + (route_end_y - route_start_y) * crossbar / (crossbar_count - 1)
        bar = make_tube(f"PoweredRouteMeshCrossbar_{crossbar:02d}",
            ((-3.2, y, 0.87), (3.2, y, 0.87)), (0.055, 0.055), 6,
            materials["road_mesh"], branch_collection)
        export_objects.append(bar)
        if crossbar % 4 == 0:
            add_tech_box(f"PoweredRouteBrassCoupler_{crossbar:02d}",
                (0.0, y, 0.94), (0.75, 0.36, 0.20), materials["brass"])
    for cable_index, x in enumerate((-2.62, 2.62)):
        cable = make_tube(f"PoweredRouteCyanCable_{cable_index:02d}",
            ((x, route_start_y, 0.98), (x, -12.0, 0.98),
             (x * 0.55, route_end_y, 0.98), (0.0, -2.8, 0.98)),
            (0.11, 0.11, 0.10, 0.09), 7, materials["root_cyan"], branch_collection)
        export_objects.append(cable)

    # Levitating power relays make the root technology readable around the
    # full circumference rather than concentrating every device at the door.
    floating_node_count = 8
    relay_angles = (-160, -136, -44, -18, 20, 56, 102, 142)
    for node_index, angle_degrees in enumerate(relay_angles):
        angle = math.radians(angle_degrees)
        radius = 14.8
        location = Vector((math.cos(angle) * radius, math.sin(angle) * radius,
            4.2 + 0.6 * math.sin(node_index * 1.7)))
        bpy.ops.mesh.primitive_torus_add(major_radius=0.82, minor_radius=0.12,
            major_segments=16, minor_segments=5, location=location)
        relay_ring = bpy.context.object
        relay_ring.name = f"FloatingRootRelayBrassRing_{node_index:02d}"
        relay_ring.data.materials.append(materials["brass"])
        for owner in list(relay_ring.users_collection):
            owner.objects.unlink(relay_ring)
        branch_collection.objects.link(relay_ring)
        export_objects.append(relay_ring)
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.48, radius2=0.02,
            depth=1.75, location=location + Vector((0, 0, 0.75)))
        relay_crystal = bpy.context.object
        relay_crystal.name = f"FloatingRootRelayCrystal_{node_index:02d}"
        relay_crystal.data.materials.append(materials["root_relay_crystal"])
        for owner in list(relay_crystal.users_collection):
            owner.objects.unlink(relay_crystal)
        branch_collection.objects.link(relay_crystal)
        export_objects.append(relay_crystal)

    root_paths, secondary_root_paths = generate_root_system()
    root_bark_materials = (materials["root_dark"], materials["root_mid"], materials["root_warm"])
    editable_primary_joint_count = 0
    for index, (points, widths, heights, entrance_root) in enumerate(root_paths):
        widths = tuple(value * 0.84 for value in widths)
        heights = tuple(value * 0.88 for value in heights)
        root = make_buttress_root(
            f"LivingButtressRoot_{index:02d}", points, widths, heights,
            root_bark_materials, branch_collection)
        export_objects.append(root)
        channel_points = tuple((x, y, z + heights[i] * 0.82) for i, (x, y, z) in enumerate(points))
        channel_radii = tuple(0.105 + 0.025 * math.sin(i * 1.7 + index) for i in range(len(points)))
        channel = make_tube(f"RootCyanSapInlay_{index:02d}", channel_points, channel_radii, 6, materials["root_cyan"], branch_collection)
        export_objects.append(channel)
        # Separate bark joints expose each control span as a selectable editing
        # module in Blender/Godot and give the large roots layered construction.
        point_vectors = [Vector(point) for point in points]
        for section_index in range(1, len(points) - 1):
            tangent = point_vectors[section_index + 1] - point_vectors[section_index - 1]
            bark_joint = add_collar(
                f"EditablePrimaryRootJoint_{index:02d}_{section_index:02d}",
                points[section_index], tangent, widths[section_index] * 1.015,
                root_bark_materials[(index + section_index) % len(root_bark_materials)],
                branch_collection)
            bark_joint.scale = (1.0, 0.62, 1.0)
            export_objects.append(bark_joint)
            editable_primary_joint_count += 1
        # Two smaller surface circuits merge into the main sap line, producing
        # the branching embedded network shown in the conduit reference.
        for branch_side in (-1.0, 1.0):
            tributary_points = []
            tributary_radii = []
            for point_index in range(1, len(points) - 1):
                point = Vector(points[point_index])
                radial = Vector((point.x, point.y, 0.0)).normalized()
                lateral = Vector((-radial.y, radial.x, 0.0))
                merge = (point_index - 1) / max(1, len(points) - 3)
                offset = lateral * branch_side * widths[point_index] * 0.42 * (1.0 - merge)
                offset += Vector((0, 0, heights[point_index] * (0.48 + 0.34 * merge)))
                tributary_points.append(tuple(point + offset))
                tributary_radii.append(0.075 - 0.018 * merge)
            tributary = make_tube(
                f"RootCyanTributary_{index:02d}_{'L' if branch_side < 0 else 'R'}",
                tributary_points, tributary_radii, 6, materials["root_cyan"], branch_collection)
            export_objects.append(tributary)

        # Heavy double articulation clamps on the doorway roots and alternating
        # outer buttresses make the technology part of the root structure.
        if entrance_root or index % 2 == 0:
            vectors = [Vector(point) for point in points]
            joint_index = 3
            tangent = (vectors[joint_index + 1] - vectors[joint_index - 1]).normalized()
            for band_index, displacement in enumerate((-0.26, 0.26)):
                band_position = Vector(points[joint_index]) + tangent * displacement
                collar = add_collar(
                    f"RootMechanicalClamp_{index:02d}_{band_index:02d}", band_position, tangent,
                    max(widths[joint_index], heights[joint_index]) * 1.06,
                    materials["brass"], branch_collection)
                collar.scale = (1.0, 0.78, 1.0)
                export_objects.append(collar)
            add_tech_box(f"RootClampPowerBlock_{index:02d}",
                tuple(Vector(points[joint_index]) + Vector((0, 0, heights[joint_index] * 1.02))),
                (0.72, 0.72, 0.46), materials["brass"])

    # Six distribution cables leave the chamber well and feed alternate major
    # roots, visibly closing the road -> chamber -> root power circuit.
    for feeder_index, root_index in enumerate(range(0, len(root_paths), 2)):
        root_point = Vector(root_paths[root_index][0][0])
        halfway = Vector((root_point.x * 0.55, root_point.y * 0.55, 0.58))
        feeder = make_tube(f"RootRadialPowerFeeder_{feeder_index:02d}",
            ((0.0, -2.8, 0.98), (halfway.x, halfway.y, 0.94),
             (root_point.x * 0.88, root_point.y * 0.88, 0.90),
             (root_point.x, root_point.y, root_point.z + 0.45)),
            (0.085, 0.09, 0.085, 0.06), 7, materials["root_cyan"], branch_collection)
        export_objects.append(feeder)

    editable_secondary_joint_count = 0
    for index, (points, widths, heights) in enumerate(secondary_root_paths):
        widths = tuple(value * 0.82 for value in widths)
        heights = tuple(value * 0.86 for value in heights)
        root = make_buttress_root(
            f"SecondaryGroundRoot_{index:02d}", points, widths, heights,
            root_bark_materials, branch_collection)
        export_objects.append(root)
        point_vectors = [Vector(point) for point in points]
        for section_index in range(1, len(points) - 1):
            tangent = point_vectors[section_index + 1] - point_vectors[section_index - 1]
            bark_joint = add_collar(
                f"EditableSecondaryRootJoint_{index:02d}_{section_index:02d}",
                points[section_index], tangent, widths[section_index] * 1.02,
                root_bark_materials[(index + section_index + 1) % len(root_bark_materials)],
                branch_collection)
            bark_joint.scale = (1.0, 0.56, 1.0)
            export_objects.append(bark_joint)
            editable_secondary_joint_count += 1
        # Every ground root now carries a visible electric fibre, closing the
        # energy network across the full circumference of the foundation.
        channel_points = tuple((point.x, point.y, point.z + heights[i] * 0.86)
            for i, point in enumerate(points))
        channel = make_tube(
            f"SecondaryRootCyanInlay_{index:02d}", channel_points,
            tuple(0.075 for _ in points), 6, materials["root_cyan"], branch_collection)
        export_objects.append(channel)
    for index, points in enumerate(all_paths):
        is_twig = index >= major_path_count
        start_radius = 0.78 if is_twig else 1.58
        end_radius = 0.28 if is_twig else 0.52
        radii = tuple(start_radius + (end_radius - start_radius) * i / (len(points) - 1) for i in range(len(points)))
        branch = make_tube(f"BioTechBranch_{index:02d}", points, radii, 10, materials["wood"], branch_collection)
        export_objects.append(branch)
        channel_points = tuple((x, y, z + radii[i] * 0.74) for i, (x, y, z) in enumerate(points))
        channel_radii = tuple(max(0.08, radius * 0.105) for radius in radii)
        channel = make_tube(f"CyanSapChannel_{index:02d}", channel_points, channel_radii, 7, materials["cyan"], branch_collection)
        export_objects.append(channel)
        if not is_twig or index % 2 == 0:
            vectors = [Vector(point) for point in points]
            for joint_index in range(1, len(points) - 1):
                tangent = vectors[joint_index + 1] - vectors[joint_index - 1]
                collar = add_collar(
                    f"BrassArticulationCollar_{index:02d}_{joint_index:02d}",
                    points[joint_index], tangent, radii[joint_index] * 1.08,
                    materials["brass"], branch_collection)
                export_objects.append(collar)

    # Every foliage pad owns an ordered fan of visible twigs. Leaves are placed
    # directly on the corresponding quadratic path, so none of the crown is a
    # disconnected spatial scatter. One powered twig per pad carries cyan sap
    # visibly from its parent limb into the leaf fan.
    leaf_support_channel_count = 0
    for support_index, points in enumerate(leaf_support_paths):
        support_radii = (0.28, 0.15, 0.055)
        support = make_tube(
            f"LeafSupportTwig_{support_index:04d}", points, support_radii,
            6, materials["wood"], branch_collection)
        export_objects.append(support)
        if support_index % support_twigs_per_cluster == support_twigs_per_cluster // 2:
            powered_points = tuple((x, y, z + support_radii[i] * 0.72)
                for i, (x, y, z) in enumerate(points))
            powered_support = make_tube(
                f"LeafSupportCyanChannel_{support_index:04d}", powered_points,
                (0.035, 0.028, 0.016), 5, materials["cyan"], branch_collection)
            export_objects.append(powered_support)
            leaf_support_channel_count += 1

    before_hub = set(bpy.data.objects)
    add_crystal_hub(materials, branch_collection)
    export_objects.extend(obj for obj in bpy.data.objects if obj not in before_hub)

    templates = [append_leaf_template(source, leaf_collection) for source in LEAF_SOURCES]
    leaf_counts = {source.slug: 0 for source in LEAF_SOURCES}
    for index, (family, position, rotation_z, scale, tilt_x, tilt_y) in enumerate(leaf_placements):
        template = templates[family]
        leaf = template.copy()
        leaf.data = template.data
        leaf.hide_render = False
        leaf.hide_viewport = False
        leaf.name = f"CanopyLeaf_{LEAF_SOURCES[family].slug}_{index:03d}"
        leaf.location = position
        leaf.rotation_euler = tuple(math.radians(value) for value in (tilt_x, tilt_y, rotation_z))
        leaf.scale = (scale, scale, scale)
        leaf_collection.objects.link(leaf)
        export_objects.append(leaf)
        leaf_counts[LEAF_SOURCES[family].slug] += 1

    for template in templates:
        bpy.data.objects.remove(template, do_unlink=True)

    metadata = {
        "major_limbs": len(major_paths),
        "secondary_twigs": len(twig_paths),
        "foliage_branch_clusters": foliage_cluster_count,
        "leaf_support_twigs": len(leaf_support_paths),
        "leaf_support_cyan_channels": leaf_support_channel_count,
        "leaves_attached_to_support_twigs": True,
        "living_root_trunks": len(root_paths),
        "secondary_ground_roots": len(secondary_root_paths),
        "entrance_framing_roots": 2,
        "doorway_living_root_jambs": doorway_root_count,
        "doorway_editable_joints": doorway_joint_count,
        "doorway_electric_fibers": doorway_electric_fiber_count,
        "doorway_metal_frame": False,
        "editable_primary_root_joints": editable_primary_joint_count,
        "editable_secondary_root_joints": editable_secondary_joint_count,
        "secondary_root_cyan_inlays": len(secondary_root_paths),
        "powered_root_door_clear_width_m": 9.6,
        "powered_route_mesh_crossbars": crossbar_count,
        "powered_route_deck_plates": route_plate_count,
        "powered_route_cables": 2,
        "root_radial_power_feeders": 6,
        "floating_root_relays": floating_node_count,
        "root_cyan_tributaries": len(root_paths) * 2,
        "root_mechanical_clamp_sets": len([index for index in range(len(root_paths)) if index < 2 or index % 2 == 0]),
        "leaf_instances": len(leaf_placements),
        "canopy_diameter_m": 84.0,
        "leaf_cluster_width_range_m": [0.90, 4.20],
        "individual_leaflet_width_range_m": [0.22, 1.05],
        "leaf_counts": leaf_counts,
        "branch_meshes": len(all_paths),
        "cyan_channel_meshes": len(all_paths),
        "brass_collars": len([obj for obj in export_objects if obj.name.startswith("BrassArticulationCollar")]),
    }
    return export_objects, metadata


def add_preview_scene() -> None:
    world = bpy.context.scene.world or bpy.data.worlds.new("CanopyPreviewWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.002, 0.010, 0.025, 1.0)
    background.inputs["Strength"].default_value = 0.62

    camera_data = bpy.data.cameras.new("CanopyPreviewCamera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 78.0
    camera = bpy.data.objects.new("CanopyPreviewCamera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = (0, -92, 96)
    camera.rotation_euler = ((Vector((0, 0, 34)) - camera.location).to_track_quat("-Z", "Y").to_euler())
    bpy.context.scene.camera = camera

    key_data = bpy.data.lights.new("CanopyPreviewKey", "AREA")
    key_data.energy = 3600
    key_data.size = 28
    key = bpy.data.objects.new("CanopyPreviewKey", key_data)
    bpy.context.scene.collection.objects.link(key)
    key.location = (-25, -25, 70)
    fill_data = bpy.data.lights.new("CanopyPreviewFill", "AREA")
    fill_data.energy = 2400
    fill_data.color = (0.18, 0.55, 1.0)
    fill_data.size = 30
    fill = bpy.data.objects.new("CanopyPreviewFill", fill_data)
    bpy.context.scene.collection.objects.link(fill)
    fill.location = (28, 10, 58)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 760
    scene.render.resolution_y = 560
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_PATH)


def main() -> None:
    export_objects, metadata = build_canopy()
    add_preview_scene()
    for path in (BLEND_PATH.parent, GLB_PATH.parent, PREVIEW_PATH.parent):
        path.mkdir(parents=True, exist_ok=True)
    bpy.context.scene["asset_name"] = "Artéa Crystal Branch Canopy"
    bpy.context.scene["integration_role"] = "visual-only Tree of Life canopy replacement"
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in export_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = export_objects[0]
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH), export_format="GLB", use_selection=True,
        export_materials="EXPORT", export_yup=True,
    )
    preview_rendered = os.environ.get("ARTEA_SKIP_PREVIEW", "0") != "1"
    if preview_rendered:
        bpy.context.scene.render.filepath = str(PREVIEW_PATH)
        bpy.ops.render.render(write_still=True)

    manifest = {
        "asset": "artea_crystal_branch_canopy",
        "version": 1,
        "design_reference": "crystal-powered leaf system branch architecture",
        "source_blend": str(BLEND_PATH.relative_to(PROJECT)),
        "game_glb": str(GLB_PATH.relative_to(PROJECT)),
        "preview": str(PREVIEW_PATH.relative_to(PROJECT)),
        "preview_rendered_this_build": preview_rendered,
        "materials": ["black_biotech_wood", "cyan_sap_energy", "brass_articulation", "crystal_power_node"],
        "collision_included": False,
        "replaces_old_foliage_only": True,
        **metadata,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
