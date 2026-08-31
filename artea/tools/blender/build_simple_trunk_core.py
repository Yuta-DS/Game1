"""Build the blueprint-approved modular Tree of Life trunk core.

Outputs an editable Blender source, a compact Godot GLB, and a manifest. The
asset is intentionally static: Godot animates only the vein material.
"""

import json
import math
import os
import random

import bpy
from mathutils import Vector


PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSET_ROOT = os.path.join(PROJECT_ROOT, "assets3D", "tree_of_life", "trunk_core")
SOURCE_DIR = os.path.join(ASSET_ROOT, "source")
GLB_DIR = os.path.join(ASSET_ROOT, "glb")
BLEND_PATH = os.path.join(SOURCE_DIR, "simple_trunk_core.blend")
GLB_PATH = os.path.join(GLB_DIR, "simple_trunk_core.glb")
MANIFEST_PATH = os.path.join(ASSET_ROOT, "simple_trunk_core_manifest.json")
COMPONENT_MANIFEST_PATH = os.path.join(ASSET_ROOT, "tree_of_life_editable_components.json")
RENDER_DIR = os.path.join(ASSET_ROOT, "renders")
HERO_RENDER_PATH = os.path.join(RENDER_DIR, "tree_of_life_blender_hero.png")
TRUNK_RENDER_PATH = os.path.join(RENDER_DIR, "tree_of_life_trunk_detail.png")
CANOPY_RENDER_PATH = os.path.join(RENDER_DIR, "tree_of_life_canopy_detail.png")
LEAF_RENDER_PATH = os.path.join(RENDER_DIR, "tree_of_life_leaf_mesh_detail.png")
ROOT_RENDER_PATH = os.path.join(RENDER_DIR, "tree_of_life_root_fiber_detail.png")
FIBER_RENDER_PATH = os.path.join(RENDER_DIR, "tree_of_life_trunk_fiber_detail.png")
HEART_RENDER_PATH = os.path.join(RENDER_DIR, "tree_of_life_heart_crystal_detail.png")
BLUEPRINT_FRONT_RENDER_PATH = os.path.join(RENDER_DIR, "tree_of_life_blueprint_front.png")
ROOT_PLAN_RENDER_PATH = os.path.join(RENDER_DIR, "tree_of_life_root_plan.png")
BRANCH_ATTACHMENT_RENDER_PATH = os.path.join(
    RENDER_DIR, "tree_of_life_gravity_bough_attachment_detail.png")
FOUNDATION_RENDER_PATH = os.path.join(
    RENDER_DIR, "tree_of_life_blueprint_foundation_front.png")
GRAVITY_BOUGH_BLEND_PATH = os.path.join(
    PROJECT_ROOT, "assets3D", "tree_of_life", "gravity_leaf_bough",
    "source", "gravity_leaf_bough_runtime.blend")
GRAVITY_BOUGH_MANIFEST_PATH = os.path.join(
    PROJECT_ROOT, "assets3D", "tree_of_life", "gravity_leaf_bough",
    "gravity_leaf_bough_manifest.json")

HEIGHT = 48.0
ROOT_SPREAD_RADIUS = 19.6
BASE_TRUNK_RADIUS = 9.0
NECK_RADIUS = 2.5
DOOR_WIDTH = 6.0
DOOR_HEIGHT = 8.0
HEART_CENTER = 14.0
HEART_WIDTH = 12.0
HEART_HEIGHT = 8.0
HEART_DEPTH = 1.2
RIB_COUNT = 12
VEIN_COUNT = 6
SOCKET_COUNT = 8
PRIMARY_ROOT_COUNT = 18
ROOTLETS_PER_PRIMARY = 3
HEART_FEEDER_COUNT = 2
CROWN_VEIN_COUNT = 16
FOUNDATION_SEGMENT_COUNT = 32
FOUNDATION_STAIR_COUNT = 6
RADIAL_SEGMENTS = 36
MAJOR_BOUGH_COUNT = 8
SECONDARY_BOUGHS_PER_MAJOR = 3
FOLIAGE_CLUSTER_COUNT = MAJOR_BOUGH_COUNT * SECONDARY_BOUGHS_PER_MAJOR * 3
CROWN_LEADER_COUNT = 5
CROWN_BRANCHLET_COUNT = CROWN_LEADER_COUNT * 2
FOLIAGE_CLUSTER_COUNT += CROWN_BRANCHLET_COUNT * 3
CHRISTMAS_TIER_SPECS = (
    (14, 12.0, 18.0, -15.0, 0.10),
    (14, 18.0, 18.0, -13.0, 0.48),
    (13, 24.0, 17.0, -11.0, 0.22),
    (12, 30.0, 16.0, -9.0, 0.63),
    (11, 36.0, 15.0, -8.0, 0.34),
    (10, 42.0, 14.0, -7.0, 0.74),
    (10, 46.0, 14.0, -6.0, 0.10),
    (9, 50.0, 12.5, -3.0, 0.42),
    (8, 54.0, 11.0, 2.0, 0.74),
    (7, 58.0, 8.0, 8.0, 0.16),
    (5, 62.0, 5.0, 18.0, 0.55),
)
CHRISTMAS_TIER_BOUGH_COUNT = sum(spec[0] for spec in CHRISTMAS_TIER_SPECS)
FOLIAGE_CLUSTER_COUNT += CHRISTMAS_TIER_BOUGH_COUNT * 2
LEAVES_PER_CLUSTER = 19
LEAF_HALF_LENGTH_RANGE_M = (1.00, 1.60)
LEAF_HALF_WIDTH_RANGE_M = (0.38, 0.65)
LEAF_SOLIDIFY_THICKNESS_M = 0.060
LEAF_FACES_PER_BLADE = 11
LEAF_LOWER_TIER_SCALE = 3.0
LEAF_MIDDLE_TIER_SCALE = 2.6
LEAF_CROWN_TIER_SCALE = 2.2
APPROVED_BOUGH_TIER_SPECS = (
    # root height, uniform scale, radial bough count, phase, leaf stride.
    # The approved source is a one-sided 36 m cantilever rooted at X=-18 m.
    # A 0.50 lower scale therefore gives the blueprint's 18 m canopy radius.
    (14.0, 0.50, 8, 0.10, 3),
    (16.8, 0.48, 8, 0.48, 3),
    (19.6, 0.46, 8, 0.21, 3),
    (22.4, 0.44, 8, 0.59, 3),
    (25.2, 0.42, 8, 0.12, 3),
    (28.0, 0.40, 8, 0.50, 3),
    (30.8, 0.38, 7, 0.18, 4),
    (33.6, 0.36, 7, 0.61, 4),
    (36.4, 0.34, 7, 0.15, 4),
    (39.2, 0.32, 7, 0.57, 4),
    (42.0, 0.30, 6, 0.22, 4),
    (44.8, 0.28, 6, 0.66, 4),
    (47.6, 0.26, 6, 0.19, 5),
    (50.4, 0.24, 6, 0.63, 5),
    (53.2, 0.22, 5, 0.25, 5),
    (55.8, 0.20, 5, 0.72, 5),
    (58.2, 0.18, 4, 0.28, 5),
    (60.4, 0.16, 4, 0.76, 6),
    (62.4, 0.145, 4, 0.32, 6),
    (64.2, 0.13, 3, 0.82, 6),
    (66.0, 0.115, 3, 0.36, 6),
)
APPROVED_BOUGH_SOURCE_ROOT = Vector((-18.0, 0.0, 1.0))
APPROVED_BOUGH_INSTANCE_COUNT = sum(spec[2] for spec in APPROVED_BOUGH_TIER_SPECS)


def leaf_scale_at(height):
    """Match leaf size to the massive trunk while preserving crown taper."""
    if height <= 24.0:
        return LEAF_LOWER_TIER_SCALE
    if height <= 42.0:
        t = (height - 24.0) / 18.0
        return LEAF_LOWER_TIER_SCALE + \
            (LEAF_MIDDLE_TIER_SCALE - LEAF_LOWER_TIER_SCALE) * t
    t = min(1.0, max(0.0, (height - 42.0) / 20.0))
    return LEAF_MIDDLE_TIER_SCALE + \
        (LEAF_CROWN_TIER_SCALE - LEAF_MIDDLE_TIER_SCALE) * t


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials,
                       bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def new_collection(name):
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def new_child_collection(parent, name):
    collection = bpy.data.collections.new(name)
    parent.children.link(collection)
    return collection


def link_only(obj, collection):
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


def make_material(name, colour, metallic=0.0, roughness=0.6, emission=None):
    material = bpy.data.materials.new(name)
    material.diffuse_color = colour
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = colour
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if emission is not None:
        emission_input = shader.inputs.get("Emission Color") or shader.inputs.get("Emission")
        strength_input = shader.inputs.get("Emission Strength")
        if emission_input is not None:
            emission_input.default_value = emission
        if strength_input is not None:
            strength_input.default_value = 4.0
    return material


def radius_at(height):
    """Blueprint cross-section radius with the root spread authored separately."""
    taper_bands = (
        (0.0, BASE_TRUNK_RADIUS),
        (8.0, 12.0),
        (16.0, 9.0),
        (24.0, 6.5),
        (32.0, 4.5),
        (40.0, 3.0),
        (48.0, NECK_RADIUS),
    )
    clamped = max(0.0, min(HEIGHT, height))
    for index in range(len(taper_bands) - 1):
        start_height, start_radius = taper_bands[index]
        end_height, end_radius = taper_bands[index + 1]
        if clamped <= end_height:
            t = (clamped - start_height) / (end_height - start_height)
            eased = t * t * (3.0 - 2.0 * t)
            return start_radius + (end_radius - start_radius) * eased
    return NECK_RADIUS


def centre_at(height):
    """Subtle whole-trunk lean shared by shell, stems and energy routes."""
    t = max(0.0, min(1.0, height / HEIGHT))
    return Vector((0.86 * math.sin(t * math.pi * 1.08),
                   0.52 * math.sin(t * math.pi * 1.62 + 0.35), 0.0))


def angular_delta(angle, target):
    return (angle - target + math.pi) % (math.tau) - math.pi


def opening_at(angle, height):
    front = -math.pi * 0.5
    radius = max(radius_at(height), 0.01)
    if height <= DOOR_HEIGHT + 0.01:
        half_angle = math.asin(min(0.94, DOOR_WIDTH * 0.5 / radius))
        if abs(angular_delta(angle, front)) < half_angle:
            return True
    if HEART_CENTER - HEART_HEIGHT * 0.5 - 0.01 <= height \
            <= HEART_CENTER + HEART_HEIGHT * 0.5 + 0.01:
        half_angle = math.asin(min(0.94, HEART_WIDTH * 0.5 / radius))
        if abs(angular_delta(angle, front)) < half_angle:
            return True
    return False


def create_inner_shell(collection, materials):
    ring_heights = sorted(set([
        0.0, DOOR_HEIGHT, HEART_CENTER - HEART_HEIGHT * 0.5,
        HEART_CENTER + HEART_HEIGHT * 0.5, 16.0, 24.0, 32.0, 40.0, HEIGHT,
    ]))
    vertices = []
    for height in ring_heights:
        radius = radius_at(height)
        for segment in range(RADIAL_SEGMENTS):
            angle = math.tau * segment / RADIAL_SEGMENTS
            # Low-amplitude, layered radial noise breaks the machined-cylinder
            # silhouette while keeping the authored doorway and collision size.
            organic_radius = radius * (1.0
                + math.sin(angle * 3.0 + height * 0.19) * 0.055
                + math.sin(angle * 7.0 - height * 0.31) * 0.028)
            centre = centre_at(height)
            vertices.append((centre.x + math.cos(angle) * organic_radius,
                             centre.y + math.sin(angle) * organic_radius, height))
    faces = []
    for ring_index in range(len(ring_heights) - 1):
        mid_height = (ring_heights[ring_index] + ring_heights[ring_index + 1]) * 0.5
        for segment in range(RADIAL_SEGMENTS):
            next_segment = (segment + 1) % RADIAL_SEGMENTS
            mid_angle = math.tau * (segment + 0.5) / RADIAL_SEGMENTS
            if opening_at(mid_angle, mid_height):
                continue
            a = ring_index * RADIAL_SEGMENTS + segment
            b = ring_index * RADIAL_SEGMENTS + next_segment
            c = (ring_index + 1) * RADIAL_SEGMENTS + next_segment
            d = (ring_index + 1) * RADIAL_SEGMENTS + segment
            faces.append((a, b, c, d))
    mesh = bpy.data.meshes.new("TOL_InnerShellMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("TOL_InnerShell", mesh)
    collection.objects.link(obj)
    for material in materials:
        obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        # Vertical bands create restrained low-poly bark colour variation
        # without textures, custom shaders, or extra Web draw-heavy meshes.
        polygon.material_index = (polygon.index % RADIAL_SEGMENTS) % len(materials)
    solidify = obj.modifiers.new("AuthoredWallThickness", "SOLIDIFY")
    solidify.thickness = -0.72
    solidify.use_even_offset = True
    bevel = obj.modifiers.new("SoftBarkEdges", "BEVEL")
    bevel.width = 0.10
    bevel.segments = 2
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_smooth()
    obj.select_set(False)
    obj["module"] = "inner_shell"
    obj["simple_collision_source"] = True
    return obj


def curve_object(name, points, bevel_depth, material, collection):
    data = bpy.data.curves.new(name + "Curve", "CURVE")
    data.dimensions = "3D"
    data.resolution_u = 1
    data.bevel_depth = bevel_depth
    data.bevel_resolution = 1
    data.resolution_v = 0
    data.use_fill_caps = True
    spline = data.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for index, point in enumerate(points):
        spline.points[index].co = (*point, 1.0)
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def safe_angle(angle, height):
    front = -math.pi * 0.5
    delta = angular_delta(angle, front)
    side = 1.0 if delta >= 0.0 else -1.0
    distance = abs(delta)

    door_influence = max(0.0, min(1.0, 1.0 - height / (DOOR_HEIGHT + 1.4)))
    door_influence = door_influence * door_influence * (3.0 - 2.0 * door_influence)
    if distance < 0.46 and door_influence > 0.0:
        distance += (0.46 - distance) * door_influence

    heart_distance = abs(height - HEART_CENTER)
    heart_influence = max(0.0, min(1.0,
        1.0 - heart_distance / (HEART_HEIGHT * 0.5 + 2.2)))
    heart_influence = heart_influence * heart_influence * (3.0 - 2.0 * heart_influence)
    if distance < 1.03 and heart_influence > 0.0:
        distance += (1.03 - distance) * heart_influence
    return front + side * distance


def braided_path(index, offset, count):
    points = []
    steps = 30
    base = math.tau * index / count
    twist = math.radians(36.0 + 11.0 * (index % 4))
    for step in range(steps + 1):
        t = step / steps
        height = HEIGHT * t
        angle = base + twist * t
        angle += math.sin(t * math.pi * (1.5 + 0.2 * (index % 3)) + index) * 0.075
        angle = safe_angle(angle, height)
        radius = radius_at(height) + offset
        centre = centre_at(height)
        points.append((centre.x + math.cos(angle) * radius,
                       centre.y + math.sin(angle) * radius, height))
    return points


def create_ribs(collection, bark_materials, vein_material):
    ribs = []
    veins = []
    for index in range(RIB_COUNT):
        rib = curve_object(f"TOL_BarkRib_{index + 1:02d}",
                           braided_path(index, 0.22, RIB_COUNT),
                           1.02 - 0.07 * (index % 3),
                           bark_materials[index % len(bark_materials)], collection)
        rib["module"] = "structural_bark_rib"
        rib["heart_clear_zone_respected"] = True
        rib["continuous_from_root_socket"] = True
        ribs.append(rib)
    for index in range(VEIN_COUNT):
        vein = curve_object(f"TOL_EnergyVein_{index + 1:02d}",
                            braided_path(index, 1.18, VEIN_COUNT),
                            0.12, vein_material, collection)
        vein["module"] = "primary_energy_vein"
        vein["route_index"] = index + 1
        veins.append(vein)
    return ribs, veins


def create_doorway_arch(collection, material):
    """Build the blueprint's tall pointed south doorway frame."""
    points = []
    front_y = -radius_at(DOOR_HEIGHT * 0.5) - 0.42
    points.append((-DOOR_WIDTH * 0.5, front_y, 0.0))
    points.extend([
        (-DOOR_WIDTH * 0.5, front_y, 3.75),
        (-DOOR_WIDTH * 0.46, front_y, 4.85),
        (-DOOR_WIDTH * 0.37, front_y, 5.95),
        (-DOOR_WIDTH * 0.23, front_y, 7.02),
        (0.0, front_y, DOOR_HEIGHT),
        (DOOR_WIDTH * 0.23, front_y, 7.02),
        (DOOR_WIDTH * 0.37, front_y, 5.95),
        (DOOR_WIDTH * 0.46, front_y, 4.85),
        (DOOR_WIDTH * 0.5, front_y, 3.75),
    ])
    points.append((DOOR_WIDTH * 0.5, front_y, 0.0))
    arch = curve_object("TOL_DoorwayArch", points, 0.42, material, collection)
    arch["module"] = "walkable_doorway_arch"
    arch["clear_width_m"] = DOOR_WIDTH
    arch["clear_height_m"] = DOOR_HEIGHT
    arch["silhouette"] = "blueprint_pointed_gothic_arch"
    return arch


def create_doorway_energy_detail(collection, cyan_material):
    """Add the blueprint's pointed cyan reveal and central threshold beam."""
    front_y = -radius_at(DOOR_HEIGHT * 0.5) - 0.55
    half_width = 2.58
    height = 7.45
    profile = [
        (-half_width, front_y, 0.82),
        (-half_width, front_y, 3.65),
        (-2.34, front_y, 4.70),
        (-1.80, front_y, 5.78),
        (-1.05, front_y, 6.70),
        (0.0, front_y, height),
        (1.05, front_y, 6.70),
        (1.80, front_y, 5.78),
        (2.34, front_y, 4.70),
        (half_width, front_y, 3.65),
        (half_width, front_y, 0.82),
    ]
    inlay = curve_object(
        "TOL_FoundationDoorwayEnergyInlay", profile, 0.095,
        cyan_material, collection)
    inlay["module"] = "pointed_doorway_energy_reveal"
    inlay["editable_component"] = True
    inlay["blueprint_rule"] = "cyan_reveal_traces_the_pointed_walkthrough_arch"
    beam = curve_object(
        "TOL_FoundationDoorwayAxisBeam",
        [(0.0, front_y - 0.03, 0.84), (0.0, front_y - 0.03, 6.95)],
        0.055, cyan_material, collection)
    beam["module"] = "doorway_center_energy_axis"
    beam["editable_component"] = True
    beam["blueprint_rule"] = "stair_energy_route_continues_vertically_inside_doorway"
    return [inlay, beam]


def create_foundation_architecture(collection, stone_materials, cyan_material):
    """Build the blueprint's segmented ring, landing and centered stair axis."""
    components = []
    inner_radius = 18.65
    outer_radius = 20.55
    bottom_z = -0.72
    top_z = 0.0
    gap = math.radians(0.34)
    for index in range(FOUNDATION_SEGMENT_COUNT):
        angle_0 = math.tau * index / FOUNDATION_SEGMENT_COUNT + gap
        angle_1 = math.tau * (index + 1) / FOUNDATION_SEGMENT_COUNT - gap
        vertices = []
        for z in (bottom_z, top_z):
            vertices.extend([
                (math.cos(angle_0) * inner_radius, math.sin(angle_0) * inner_radius, z),
                (math.cos(angle_0) * outer_radius, math.sin(angle_0) * outer_radius, z),
                (math.cos(angle_1) * outer_radius, math.sin(angle_1) * outer_radius, z),
                (math.cos(angle_1) * inner_radius, math.sin(angle_1) * inner_radius, z),
            ])
        faces = [
            (0, 3, 2, 1), (4, 5, 6, 7),
            (0, 1, 5, 4), (1, 2, 6, 5),
            (2, 3, 7, 6), (3, 0, 4, 7),
        ]
        mesh = bpy.data.meshes.new(f"TOL_FoundationSegment_{index + 1:02d}Mesh")
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        segment = bpy.data.objects.new(f"TOL_FoundationSegment_{index + 1:02d}", mesh)
        collection.objects.link(segment)
        segment.data.materials.append(stone_materials[index % len(stone_materials)])
        segment["module"] = "segmented_circular_tree_foundation"
        segment["editable_component"] = True
        segment["blueprint_rule"] = "thirty_two_stone_segments_form_the_tree_court_ring"
        bevel = segment.modifiers.new("FoundationEdgeSoftening", "BEVEL")
        bevel.width = 0.055
        bevel.segments = 2
        components.append(segment)

    bpy.ops.mesh.primitive_cylinder_add(
        vertices=96, radius=inner_radius, depth=0.28, location=(0.0, 0.0, -0.14))
    terrace = link_only(bpy.context.object, collection)
    terrace.name = "TOL_FoundationInnerTerrace"
    terrace.data.materials.append(stone_materials[0])
    terrace["module"] = "circular_tree_foundation_terrace"
    terrace["editable_component"] = True
    components.append(terrace)

    stair_depth = 1.62
    stair_width = 6.8
    outer_y = -20.30
    for index in range(FOUNDATION_STAIR_COUNT):
        top = 0.14 + index * 0.12
        centre_y = outer_y + stair_depth * (index + 0.5)
        bpy.ops.mesh.primitive_cube_add(
            size=1.0, location=(0.0, centre_y, (top - 0.34) * 0.5))
        stair = link_only(bpy.context.object, collection)
        stair.name = f"TOL_ApproachStair_{index + 1:02d}"
        stair.scale = (stair_width, stair_depth + 0.10, top + 0.34)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        stair.data.materials.append(stone_materials[(index + 1) % len(stone_materials)])
        stair["module"] = "centered_blueprint_approach_stair"
        stair["editable_component"] = True
        stair["stair_index"] = index + 1
        components.append(stair)

        bpy.ops.mesh.primitive_cube_add(
            size=1.0, location=(0.0, centre_y, top + 0.025))
        inlay = link_only(bpy.context.object, collection)
        inlay.name = f"TOL_ApproachEnergyInlay_{index + 1:02d}"
        inlay.scale = (0.075, stair_depth * 0.46, 0.025)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        inlay.data.materials.append(cyan_material)
        inlay["module"] = "centered_foundation_energy_route"
        inlay["editable_component"] = True
        components.append(inlay)

    landing_top = 0.86
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, -10.75, (landing_top - 0.34) * 0.5))
    landing = link_only(bpy.context.object, collection)
    landing.name = "TOL_DoorwayThresholdLanding"
    landing.scale = (7.2, 2.4, landing_top + 0.34)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    landing.data.materials.append(stone_materials[1])
    landing["module"] = "doorway_threshold_landing"
    landing["editable_component"] = True
    landing["protected_clear_width_m"] = DOOR_WIDTH
    components.append(landing)
    return components


def create_recess(collection, dark_material):
    radius = radius_at(HEART_CENTER)
    centre = centre_at(HEART_CENTER)
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=24, ring_count=12,
        location=(centre.x, centre.y - radius + HEART_DEPTH * 0.90, HEART_CENTER))
    recess = link_only(bpy.context.object, collection)
    recess.name = "TOL_HeartRecess"
    recess.scale = (HEART_WIDTH * 0.56, HEART_DEPTH * 0.52, HEART_HEIGHT * 0.58)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    recess.data.materials.append(dark_material)
    recess["module"] = "heart_recess"
    recess["silhouette"] = "organic_oval_hollow"
    recess["clear_zone_m"] = (HEART_WIDTH, HEART_HEIGHT, HEART_DEPTH)
    return recess


def create_root_manifold(collection, vein_material):
    bpy.ops.mesh.primitive_torus_add(major_radius=5.15, minor_radius=0.14,
                                    major_segments=48, minor_segments=8,
                                    location=(0.0, 0.0, 0.34))
    manifold = link_only(bpy.context.object, collection)
    manifold.name = "TOL_RootManifold"
    manifold.data.materials.append(vein_material)
    manifold["module"] = "eighteen_intake_six_collector_root_manifold"
    manifold["root_intakes"] = PRIMARY_ROOT_COUNT
    manifold["buttress_collectors"] = VEIN_COUNT
    return manifold


def create_socket_empties(collection, parent=None):
    sockets = []
    for index in range(SOCKET_COUNT):
        angle = math.tau * index / SOCKET_COUNT
        socket = bpy.data.objects.new(f"SOCKET_Bough_{index + 1:02d}", None)
        collection.objects.link(socket)
        socket.empty_display_type = "SPHERE"
        socket.empty_display_size = 0.20
        socket.location = (math.cos(angle) * (NECK_RADIUS + 0.15),
                           math.sin(angle) * (NECK_RADIUS + 0.15), HEIGHT)
        socket.rotation_euler[2] = angle
        socket["socket_index"] = index + 1
        socket["energy_route"] = 3 if index == 3 else 4 if index == 5 else min(index + 1, 6)
        if parent is not None:
            socket.parent = parent
        sockets.append(socket)
    return sockets


def add_bark_microdetail(material, scale=3.2, strength=0.24):
    """Add render-only directional bark breakup while retaining glTF base colour."""
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = nodes.get("Principled BSDF")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.name = "LongitudinalBarkNoise"
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 5.0
    noise.inputs["Roughness"].default_value = 0.72
    mapping = nodes.new("ShaderNodeMapping")
    mapping.name = "VerticalBarkMapping"
    mapping.inputs["Scale"].default_value = (1.4, 1.4, 7.5)
    texcoord = nodes.new("ShaderNodeTexCoord")
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = strength
    bump.inputs["Distance"].default_value = 0.22
    links.new(texcoord.outputs["Generated"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], shader.inputs["Normal"])


def tapered_tube(name, points, start_radius, end_radius, material, collection,
                 radial_segments=8, radius_profile=None):
    """Create a low-poly tapered bough with stable rings along an authored path."""
    vertices = []
    faces = []
    for index, point_value in enumerate(points):
        point = Vector(point_value)
        previous = Vector(points[max(0, index - 1)])
        following = Vector(points[min(len(points) - 1, index + 1)])
        tangent = (following - previous).normalized()
        side = tangent.cross(Vector((0.0, 0.0, 1.0)))
        if side.length < 0.01:
            side = tangent.cross(Vector((0.0, 1.0, 0.0)))
        side.normalize()
        normal = side.cross(tangent).normalized()
        t = index / max(1, len(points) - 1)
        radius = (radius_profile(t) if radius_profile is not None else
                  start_radius * (1.0 - t) ** 0.72 + end_radius * t)
        radius *= 1.0 + 0.055 * math.sin(index * 1.73 + start_radius * 4.0)
        for segment in range(radial_segments):
            angle = math.tau * segment / radial_segments
            offset = side * math.cos(angle) * radius + normal * math.sin(angle) * radius
            vertices.append(tuple(point + offset))
    for ring in range(len(points) - 1):
        for segment in range(radial_segments):
            next_segment = (segment + 1) % radial_segments
            a = ring * radial_segments + segment
            b = ring * radial_segments + next_segment
            c = (ring + 1) * radial_segments + next_segment
            d = (ring + 1) * radial_segments + segment
            faces.append((a, b, c, d))
    faces.append(tuple(range(radial_segments - 1, -1, -1)))
    final_ring = (len(points) - 1) * radial_segments
    faces.append(tuple(final_ring + segment for segment in range(radial_segments)))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.data.materials.append(material)
    obj["editable_component"] = True
    bevel = obj.modifiers.new("SoftNaturalEdges", "BEVEL")
    bevel.width = min(start_radius * 0.09, 0.055)
    bevel.segments = 2
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_smooth()
    obj.select_set(False)
    return obj


def create_doorway_buttresses(collection, pale_wood, warm_wood):
    """Build the blueprint's left/right load paths around the south passage."""
    buttresses = []
    front_y = -radius_at(DOOR_HEIGHT * 0.5) - 0.30
    for side_index, side in enumerate((-1.0, 1.0)):
        points = [
            (side * 10.8, -13.8, 0.08),
            (side * 7.8, -12.2, 0.35),
            (side * 5.0, front_y - 0.7, 1.1),
            (side * 3.85, front_y, 4.2),
            (side * 3.65, front_y, 7.8),
            (side * 2.55, front_y + 0.55, 10.2),
        ]
        buttress = tapered_tube(
            f"TOL_DoorwayButtress_{'Left' if side < 0.0 else 'Right'}",
            points, 0.96, 0.68,
            pale_wood if side_index == 0 else warm_wood, collection, 10,
            radius_profile=lambda t: 0.74 + 0.62 * math.sin(math.pi * t) ** 0.72)
        buttress["module"] = "walkthrough_doorway_root_buttress"
        buttress["side"] = "left" if side < 0.0 else "right"
        buttress["protected_clear_width_m"] = DOOR_WIDTH
        buttress["protected_clear_height_m"] = DOOR_HEIGHT
        buttress["blueprint_rule"] = \
            "paired_buttress_load_paths_frame_but_never_cross_south_doorway"
        buttresses.append(buttress)
    return buttresses


def create_root_cambium_webbing(collection, dark_wood, _warm_wood):
    """Fill the root skirt naturally while preserving the south gateway."""
    ring_specs = (
        (0.035, 16.20),
        (0.85, 14.60),
        (2.15, 12.85),
        (3.85, 11.25),
        (5.75, 10.05),
        (7.35, 9.25),
    )
    segments = 72
    front = -math.pi * 0.5
    doorway_half_angle = math.asin((DOOR_WIDTH * 0.5 + 1.15) / ring_specs[0][1])
    vertices = []
    for ring_index, (height, radius) in enumerate(ring_specs):
        for segment in range(segments):
            angle = math.tau * segment / segments
            organic_radius = radius * (1.0
                + 0.035 * math.sin(angle * 5.0 + ring_index * 0.73)
                + 0.018 * math.sin(angle * 11.0 - ring_index * 0.41))
            organic_height = height
            if ring_index > 0:
                organic_height += 0.08 * math.sin(angle * 7.0 + ring_index)
            vertices.append((math.cos(angle) * organic_radius,
                             math.sin(angle) * organic_radius, organic_height))
    faces = []
    for ring_index in range(len(ring_specs) - 1):
        for segment in range(segments):
            next_segment = (segment + 1) % segments
            mid_angle = math.tau * (segment + 0.5) / segments
            # Keep a slightly wider opening than the six-metre doorway so the
            # cambium never intrudes into the stairs or player shoulder space.
            if abs(angular_delta(mid_angle, front)) < doorway_half_angle:
                continue
            lower = ring_index * segments
            upper = (ring_index + 1) * segments
            faces.append((lower + segment, lower + next_segment,
                          upper + next_segment, upper + segment))
    mesh = bpy.data.meshes.new("TOL_RootCambiumWebbingMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    webbing = bpy.data.objects.new("TOL_RootCambiumWebbing", mesh)
    collection.objects.link(webbing)
    webbing.data.materials.append(dark_wood)
    webbing["module"] = "continuous_organic_root_cambium_webbing"
    webbing["editable_component"] = True
    webbing["natural_ground_transition"] = True
    webbing["protected_gateway_width_m"] = DOOR_WIDTH
    webbing["blueprint_rule"] = \
        "continuous_root_fiber_web_fills_all_gaps_except_the_south_gateway"
    bevel = webbing.modifiers.new("SoftCambiumTransitions", "BEVEL")
    bevel.width = 0.08
    bevel.segments = 1
    return webbing


def create_branch_architecture(collection, pale_wood, warm_wood):
    """Build the reference's co-dominant, horizontally sweeping crown skeleton."""
    major_paths = []
    secondary_paths = []
    for index in range(MAJOR_BOUGH_COUNT):
        angle = math.tau * index / MAJOR_BOUGH_COUNT + math.radians(-9.0 + 5.0 * (index % 3))
        reach = (10.0 + 1.45 * (index % 4)) * 1.18
        base_height = 44.3 + 0.62 * (index % 3)
        points = []
        for step in range(15):
            t = step / 14.0
            sweep_angle = angle + math.sin(t * math.pi) * (0.12 if index % 2 else -0.10)
            radius = 2.4 + reach * (t ** 0.82)
            centre = centre_at(min(HEIGHT, base_height + t * 3.0))
            height = base_height + 2.1 * t + 1.7 * math.sin(t * math.pi)
            height += 0.35 * math.sin(t * math.pi * 2.0 + index)
            points.append((centre.x + math.cos(sweep_angle) * radius,
                           centre.y + math.sin(sweep_angle) * radius, height))
        branch = tapered_tube(f"TOL_MajorBough_{index + 1:02d}", points,
                              0.72 - 0.055 * (index % 3), 0.17,
                              pale_wood if index % 3 else warm_wood, collection, 10)
        branch["module"] = "major_sweeping_bough"
        major_paths.append(points)

        for secondary_index, start_t in enumerate((0.43, 0.62, 0.77)):
            start_index = int(start_t * (len(points) - 1))
            start = Vector(points[start_index])
            fan = (-0.34, 0.27, -0.18)[secondary_index]
            secondary_angle = angle + fan + (0.11 if index % 2 else -0.07)
            secondary_reach = (4.6 + 0.7 * ((index + secondary_index) % 3)) * 1.18
            secondary = []
            for step in range(10):
                t = step / 9.0
                horizontal = secondary_reach * (t ** 0.8)
                secondary.append((start.x + math.cos(secondary_angle) * horizontal,
                                  start.y + math.sin(secondary_angle) * horizontal,
                                  start.z + 1.25 * t + 0.72 * math.sin(t * math.pi)
                                  + 0.18 * math.sin(step + index)))
            twig = tapered_tube(
                f"TOL_SecondaryBough_{index + 1:02d}_{secondary_index + 1:02d}",
                secondary, 0.29, 0.055,
                pale_wood if (index + secondary_index) % 2 else warm_wood,
                collection, 7)
            twig["module"] = "secondary_canopy_bough"
            secondary_paths.append(secondary)
    return major_paths, secondary_paths


def create_crown_leaders(collection, pale_wood, warm_wood):
    """Continue the trunk through the crown so it never reads as a cut stump."""
    leaders = []
    branchlets = []
    for index in range(CROWN_LEADER_COUNT):
        base_angle = math.tau * index / CROWN_LEADER_COUNT + 0.24
        leader = []
        for step in range(14):
            t = step / 13.0
            angle = base_angle + math.radians(38.0 + index * 7.0) * t
            radius = 1.55 + 1.45 * t + 0.32 * math.sin(t * math.pi)
            height = 45.0 + 14.4 * t + 0.55 * math.sin(t * math.pi * 1.5 + index)
            centre = centre_at(min(height, HEIGHT))
            leader.append((centre.x + math.cos(angle) * radius,
                           centre.y + math.sin(angle) * radius, height))
        obj = tapered_tube(f"TOL_CrownLeader_{index + 1:02d}", leader,
                           0.58 - 0.045 * (index % 2), 0.10,
                           pale_wood if index % 2 else warm_wood, collection, 9)
        obj["module"] = "co_dominant_crown_leader"
        leaders.append(leader)
        for branch_index, start_t in enumerate((0.53, 0.72)):
            start = Vector(leader[int(start_t * (len(leader) - 1))])
            angle = base_angle + (-0.62 if branch_index == 0 else 0.66) + index * 0.05
            branch = []
            for step in range(9):
                t = step / 8.0
                reach = (4.2 + 0.45 * (index % 3)) * (t ** 0.8)
                branch.append((start.x + math.cos(angle) * reach,
                               start.y + math.sin(angle) * reach,
                               start.z + 1.7 * t + 0.52 * math.sin(t * math.pi)))
            twig = tapered_tube(
                f"TOL_CrownBranchlet_{index + 1:02d}_{branch_index + 1:02d}",
                branch, 0.25, 0.05, pale_wood, collection, 7)
            twig["module"] = "rising_crown_branchlet"
            branchlets.append(branch)
    return leaders, branchlets


def create_christmas_tier_architecture(collection, pale_wood, warm_wood):
    """Mirror the production canopy's fir whorls at the Blender asset scale."""
    tier_paths = []
    tier_profile = []
    for tier_index, (count, height, reach, pitch_degrees, phase) in enumerate(
            CHRISTMAS_TIER_SPECS):
        tier_profile.append({
            "tier": tier_index + 1,
            "count": count,
            "height_m": height,
            "reach_m": reach,
            "pitch_degrees": pitch_degrees,
            "phase_radians": phase,
        })
        for bough_index in range(count):
            irregularity = math.sin(bough_index * 2.17 + tier_index * 0.43)
            angle = math.tau * bough_index / count + phase + irregularity * 0.095
            # The foliage now begins immediately above the root flare. Split the
            # lowest south-facing boughs around the ceremonial axis so this denser
            # skirt never covers the doorway or the heart crystal.
            if height <= 24.0 and math.sin(angle) < -0.55:
                side = -1.0 if math.cos(angle) < 0.0 else 1.0
                angle = -math.pi * 0.5 + side * 0.95
            start_radius = 1.55 + tier_index * 0.10
            pitch = math.radians(pitch_degrees + irregularity * 3.5)
            path = []
            for step in range(12):
                t = step / 11.0
                radial_distance = start_radius + reach * 1.16 * (t ** 0.82)
                sweep = angle + math.sin(t * math.pi) * irregularity * 0.045
                lift = math.tan(pitch) * reach * t
                lift += math.sin(t * math.pi) * (0.58 + tier_index * 0.05)
                centre = centre_at(min(height, HEIGHT))
                path.append((centre.x + math.cos(sweep) * radial_distance,
                             centre.y + math.sin(sweep) * radial_distance,
                             height + lift))
            bough = tapered_tube(
                f"TOL_ChristmasTier_{tier_index + 1:02d}_Bough_{bough_index + 1:02d}",
                path, 0.34 - tier_index * 0.025, 0.045,
                pale_wood if (tier_index + bough_index) % 3 else warm_wood,
                collection, 7)
            bough["module"] = "christmas_tree_tier_bough"
            bough["blueprint_tier"] = tier_index + 1
            bough["pitch_degrees"] = pitch_degrees
            bough["blueprint_rule"] = "wide_drooping_base_to_narrow_lifted_crown"
            tier_paths.append(path)

    spire_path = []
    for step in range(17):
        t = step / 16.0
        height = 45.0 + 24.0 * t
        centre = centre_at(min(height, HEIGHT))
        spire_path.append((centre.x + math.sin(t * math.pi * 1.6) * 0.34,
                           centre.y + math.sin(t * math.pi * 1.2 + 0.4) * 0.25,
                           height))
    spire = tapered_tube("TOL_ChristmasCentralLeader", spire_path, 0.62, 0.035,
                         pale_wood, collection, 9)
    spire["module"] = "christmas_tree_central_leader"
    spire["blueprint_rule"] = "single_readable_apex_above_tapered_whorls"
    return tier_paths, tier_profile, spire


def append_approved_gravity_bough_canopy(collection):
    """Root approved one-sided boughs into radial, tapered crown whorls.

    The imported objects remain in unlinked source collections. Each visible
    bough is translated so its authored proximal point (-18, 0, 1) meets the
    living trunk centre. Its joined branch structure and a deterministic subset
    of socket-authored leaves retain identical local transforms, so thinning
    the canopy never disconnects a leaf from its twig or energy fiber.
    """
    wanted_names = (
        "02_Alternating_Laterals",
        "04_Socket_Attached_Leaves",
        "05_Biofiber_Main_Braid",
    )
    with bpy.data.libraries.load(GRAVITY_BOUGH_BLEND_PATH, link=False) as (
            source_data, loaded_data):
        loaded_data.collections = [
            name for name in source_data.collections if name in wanted_names]
    loaded = {item.name: item for item in loaded_data.collections if item is not None}
    structure_objects = list(loaded["02_Alternating_Laterals"].objects)
    leaf_objects = list(loaded["04_Socket_Attached_Leaves"].objects)
    flow_objects = list(loaded["05_Biofiber_Main_Braid"].objects)
    instances = []
    logical_leaves = 0
    for tier_index, (height, scale, radial_count, phase, stride) in enumerate(
            APPROVED_BOUGH_TIER_SPECS):
        for radial_index in range(radial_count):
            leaf_offset = (tier_index * 3 + radial_index) % stride
            tier_source = bpy.data.collections.new(
                f"TOL_APPROVED_GRAVITY_BOUGH_SOURCE_TIER_"
                f"{tier_index + 1:02d}_{radial_index + 1:02d}")
            for source_object in (*structure_objects, *flow_objects):
                tier_source.objects.link(source_object)
            selected_leaves = [
                leaf for leaf_index, leaf in enumerate(leaf_objects)
                if leaf_index % stride == leaf_offset]
            for leaf in selected_leaves:
                tier_source.objects.link(leaf)
            logical_leaves += len(selected_leaves)

            instance = bpy.data.objects.new(
                f"TOL_ApprovedGravityBoughTier_{tier_index + 1:02d}_"
                f"{radial_index + 1:02d}", None)
            collection.objects.link(instance)
            instance.instance_type = "COLLECTION"
            instance.instance_collection = tier_source
            trunk_centre = centre_at(min(height, HEIGHT))
            yaw = phase + math.tau * radial_index / radial_count
            root_x = APPROVED_BOUGH_SOURCE_ROOT.x * scale
            root_y = APPROVED_BOUGH_SOURCE_ROOT.y * scale
            rotated_root_x = math.cos(yaw) * root_x - math.sin(yaw) * root_y
            rotated_root_y = math.sin(yaw) * root_x + math.cos(yaw) * root_y
            instance.location = (
                trunk_centre.x - rotated_root_x,
                trunk_centre.y - rotated_root_y,
                height - APPROVED_BOUGH_SOURCE_ROOT.z * scale)
            instance.rotation_euler.z = yaw
            instance.scale = (scale, scale, scale)
            instance["module"] = "approved_gravity_leaf_bough_tier"
            instance["blueprint_tier"] = tier_index + 1
            instance["radial_bough"] = radial_index + 1
            instance["radial_bough_count"] = radial_count
            instance["root_socket_world_m"] = (
                trunk_centre.x, trunk_centre.y, height)
            instance["source_blend"] = os.path.relpath(
                GRAVITY_BOUGH_BLEND_PATH, PROJECT_ROOT)
            instance["source_socket_attached_leaves"] = len(selected_leaves)
            instance["maximum_source_socket_error_m"] = 9.830249847454215e-07
            instance["blueprint_rule"] = \
                "proximal_root_meets_trunk_and_socket_leaves_keep_source_transforms"
            instances.append(instance)
    return instances, logical_leaves


def hide_superseded_presentation_canopy():
    """Retain older editable experiments but render only approved bough tiers."""
    superseded_modules = {
        "major_sweeping_bough", "secondary_canopy_bough",
        "co_dominant_crown_leader", "rising_crown_branchlet",
        "christmas_tree_tier_bough", "stylized_foliage_mass",
        "editable_curved_lanceolate_leaf_mesh_cluster",
        "individual_lanceolate_leaves", "soft_lilac_flower_mass",
        "lilac_flower_plumes", "editable_gold_mechanical_branch_graft",
    }
    hidden = 0
    for obj in bpy.context.scene.objects:
        if obj.get("module", "") in superseded_modules:
            obj.hide_render = True
            hidden += 1
    return hidden


def create_editable_fiber_system(collection, pale_wood, warm_wood, dark_wood,
                                 capillary_material):
    """Layer independent root, lath, groove and capillary objects over the shell."""
    components = {"ground_root_fibers": [], "secondary_rootlets": [],
                  "root_energy_channels": [], "heart_feeders": [],
                  "crown_veins": [], "surface_laths": [],
                  "grain_grooves": [], "energy_capillaries": []}
    front = -math.pi * 0.5
    corridor_half_angle = math.asin((DOOR_WIDTH * 0.5 + 0.8) / ROOT_SPREAD_RADIUS)
    available_arc = math.tau - corridor_half_angle * 2.0
    for index in range(PRIMARY_ROOT_COUNT):
        # The eighteen roots fill the radial plan while leaving the south doorway
        # corridor empty between the two flanking buttress roots.
        base_angle = front + corridor_half_angle \
            + available_arc * index / (PRIMARY_ROOT_COUNT - 1)
        base_angle += 0.035 * math.sin(index * 1.7)
        corridor_side = 1.0 if angular_delta(base_angle, front) >= 0.0 else -1.0
        path = []
        for step in range(28):
            t = step / 27.0
            height = 0.08 + (10.2 + 0.55 * (index % 3)) * (t ** 1.78)
            radial_distance = ROOT_SPREAD_RADIUS * (1.0 - t) \
                + (radius_at(height) + 0.62) * t
            raw_angle = base_angle + math.radians(10.0 + 3.0 * (index % 4)) \
                * math.sin(t * math.pi)
            # Keep roots beside the south entrance on the same side on which
            # they began. Without this normalization the last root crosses the
            # +/-PI seam and draws a false diagonal through the doorway.
            angle = front + corridor_side * abs(angular_delta(raw_angle, front))
            angle = safe_angle(angle, height)
            centre = centre_at(height)
            path.append((centre.x + math.cos(angle) * radial_distance,
                         centre.y + math.sin(angle) * radial_distance, height))
        # Thick structural members matching the braided-rib blueprint, while
        # the south doorway remains protected by the existing angular corridor.
        profile = lambda t, index=index: (0.34 + (1.76 + 0.12 * (index % 3))
                                          * (math.sin(math.pi * t * 0.5) ** 0.68))
        root_fiber = tapered_tube(
            f"TOL_EditablePrimaryRoot_{index + 1:02d}", path, 0.34, 2.34,
            pale_wood if index % 3 else warm_wood, collection, 10,
            radius_profile=profile)
        root_fiber["module"] = "editable_grounded_primary_root"
        root_fiber["root_index"] = index + 1
        root_fiber["blueprint_rule"] = \
            "one_of_eighteen_primary_roots_continuously_interlocks_with_braided_trunk"
        root_fiber["thick_braided_structural_radius_range_m"] = (0.34, 2.34)
        components["ground_root_fibers"].append(root_fiber)

        # Each primary root splits into three independently editable rootlets,
        # giving the expanded 18 + 54 hierarchy shown in the top-down plan.
        for rootlet_index, split_t in enumerate((0.22, 0.34, 0.46)):
            source_index = int(split_t * (len(path) - 1))
            start = Vector(path[source_index])
            side = -1.0 if rootlet_index == 0 else 1.0
            rootlet = []
            start_angle = math.atan2(start.y, start.x)
            for step in range(10):
                t = step / 9.0
                fan_offset = (-0.22, 0.0, 0.22)[rootlet_index]
                target_angle = base_angle + fan_offset + side * 0.035
                angle = start_angle + angular_delta(target_angle, start_angle) * t
                target_radius = min(ROOT_SPREAD_RADIUS,
                                    start.xy.length + (3.1 + 0.35 * (index % 3)) * t)
                rootlet.append((math.cos(angle) * target_radius,
                                math.sin(angle) * target_radius,
                                max(0.04, start.z * (1.0 - t) + 0.05)))
            rootlet_object = tapered_tube(
                f"TOL_EditableSecondaryRootlet_{index + 1:02d}_{rootlet_index + 1:02d}",
                rootlet, 0.72, 0.16,
                warm_wood if (index + rootlet_index) % 3 == 0 else pale_wood,
                collection, 8)
            rootlet_object["module"] = "editable_secondary_rootlet"
            rootlet_object["parent_root_index"] = index + 1
            rootlet_object["blueprint_rule"] = \
                "three_secondary_rootlets_per_primary_root_form_a_clear_radial_fan"
            components["secondary_rootlets"].append(rootlet_object)

        energy_path = []
        for point_index, point in enumerate(path):
            t = point_index / (len(path) - 1)
            point_value = Vector(point)
            previous = Vector(path[max(0, point_index - 1)])
            following = Vector(path[min(len(path) - 1, point_index + 1)])
            tangent = (following - previous).normalized()
            surface_normal = Vector((0.0, 0.0, 1.0)) \
                - tangent * tangent.dot(Vector((0.0, 0.0, 1.0)))
            if surface_normal.length < 0.01:
                surface_normal = Vector((point_value.x, point_value.y, 0.0)).normalized()
            surface_normal.normalize()
            energy_path.append(tuple(
                point_value + surface_normal * (profile(t) + 0.035)))
        channel = curve_object(
            f"TOL_EditableRootEnergyChannel_{index + 1:02d}", energy_path,
            0.092, capillary_material, collection)
        channel["module"] = "editable_primary_root_energy_intake"
        channel["root_index"] = index + 1
        channel["surface_fit_method"] = "local_tangent_projected_surface_normal"
        channel["maximum_surface_gap_m"] = 0.035
        channel["embedded_in_bark_groove"] = True
        channel["blueprint_rule"] = \
            "eighteen_surface_fitted_root_intakes_feed_six_buttress_collectors"
        components["root_energy_channels"].append(channel)

    for index in range(28):
        start_angle = math.tau * index / 28.0 + 0.055 * math.sin(index * 2.1)
        path = []
        for step in range(26):
            t = step / 25.0
            height = 0.45 + (46.7 + 0.35 * (index % 3)) * t
            twist = math.radians(28.0 + 9.0 * (index % 5))
            angle = safe_angle(start_angle + twist * t + 0.045 * math.sin(t * math.tau * 2.0 + index),
                               height)
            radial_distance = radius_at(min(height, HEIGHT)) + 0.46 + 0.06 * math.sin(t * 17.0 + index)
            centre = centre_at(min(height, HEIGHT))
            path.append((centre.x + math.cos(angle) * radial_distance,
                         centre.y + math.sin(angle) * radial_distance, height))
        lath = tapered_tube(
            f"TOL_EditableBarkLath_{index + 1:02d}", path,
            0.20 + 0.025 * (index % 4), 0.055,
            pale_wood if index % 4 else warm_wood, collection, 7)
        lath["module"] = "editable_longitudinal_bark_lath"
        lath["blueprint_rule"] = "pale_exposed_fibers_over_recessed_heartwood"
        components["surface_laths"].append(lath)

    for index in range(20):
        start_angle = math.tau * (index + 0.5) / 20.0
        points = []
        for step in range(27):
            t = step / 26.0
            height = 0.8 + 46.2 * t
            angle = safe_angle(start_angle + math.radians(18.0 + 7.0 * (index % 4)) * t,
                               height)
            radial_distance = radius_at(height) + 0.57
            centre = centre_at(height)
            points.append((centre.x + math.cos(angle) * radial_distance,
                           centre.y + math.sin(angle) * radial_distance, height))
        groove = curve_object(f"TOL_EditableGrainGroove_{index + 1:02d}", points,
                              0.040 + 0.008 * (index % 3), dark_wood, collection)
        groove["module"] = "editable_recessed_grain_groove"
        groove["editable_component"] = True
        groove["blueprint_rule"] = "dark_cambium_between_pale_load_bearing_ridges"
        components["grain_grooves"].append(groove)

    for index in range(12):
        start_angle = math.tau * index / 12.0 + 0.18
        points = []
        for step in range(23):
            t = step / 22.0
            height = 1.2 + 45.5 * t
            angle = safe_angle(start_angle + math.radians(42.0 + 8.0 * (index % 3)) * t,
                               height)
            radial_distance = radius_at(height) + 0.72
            centre = centre_at(height)
            points.append((centre.x + math.cos(angle) * radial_distance,
                           centre.y + math.sin(angle) * radial_distance, height))
        capillary = curve_object(f"TOL_EditableEnergyCapillary_{index + 1:02d}", points,
                                 0.028, capillary_material, collection)
        capillary["module"] = "editable_secondary_energy_capillary"
        capillary["editable_component"] = True
        capillary["blueprint_rule"] = "secondary_flow_feeds_six_primary_energy_veins"
        components["energy_capillaries"].append(capillary)

    for index in range(HEART_FEEDER_COUNT):
        side = -1.0 if index == 0 else 1.0
        points = []
        for step in range(13):
            t = step / 12.0
            height = 5.4 + (HEART_CENTER - 5.4) * t
            radius = radius_at(height) + 1.05
            angle = front + side * (0.58 - 0.34 * t)
            centre = centre_at(height)
            points.append((centre.x + math.cos(angle) * radius,
                           centre.y + math.sin(angle) * radius, height))
        feeder = curve_object(f"TOL_EditableHeartFeeder_{index + 1:02d}", points,
                              0.13, capillary_material, collection)
        feeder["module"] = "editable_heart_energy_feeder"
        feeder["blueprint_rule"] = "two_feeders_focus_root_energy_into_heart_crystal"
        components["heart_feeders"].append(feeder)

    for index in range(CROWN_VEIN_COUNT):
        start_angle = math.tau * index / CROWN_VEIN_COUNT + 0.11
        points = []
        for step in range(25):
            t = step / 24.0
            height = HEART_CENTER + 2.0 + (HEIGHT - HEART_CENTER - 2.0) * t
            angle = safe_angle(start_angle + math.radians(32.0 + 4.0 * (index % 4)) * t,
                               height)
            radial_distance = radius_at(height) + 0.82
            centre = centre_at(height)
            points.append((centre.x + math.cos(angle) * radial_distance,
                           centre.y + math.sin(angle) * radial_distance, height))
        crown_vein = curve_object(f"TOL_EditableCrownVein_{index + 1:02d}", points,
                                  0.055, capillary_material, collection)
        crown_vein["module"] = "editable_crown_energy_distribution_vein"
        crown_vein["blueprint_rule"] = "sixteen_crown_veins_distribute_energy_above_heart"
        components["crown_veins"].append(crown_vein)
    return components


def create_foliage_materials():
    greens = [
        make_material("MAT_LeafNatureDeepGreen", (0.06, 0.30, 0.12, 1.0), roughness=0.82),
        make_material("MAT_LeafNatureSunlitGreen", (0.30, 0.68, 0.24, 1.0), roughness=0.76),
        make_material("MAT_LeafTechnologyBlue", (0.04, 0.48, 0.94, 1.0), metallic=0.18,
                      roughness=0.42),
        make_material("MAT_LeafMagicViolet", (0.48, 0.16, 0.86, 1.0), roughness=0.58),
    ]
    blossoms = [
        make_material("MAT_BlossomDeepLilac", (0.35, 0.16, 0.55, 1.0), roughness=0.68),
        make_material("MAT_BlossomLilac", (0.60, 0.38, 0.80, 1.0), roughness=0.64),
        make_material("MAT_BlossomSunlitLavender", (0.82, 0.64, 0.94, 1.0), roughness=0.60),
    ]
    leaf_veins = [
        make_material("MAT_LeafVeinNatureDeep", (0.018, 0.11, 0.028, 1.0), roughness=0.70),
        make_material("MAT_LeafVeinNatureSunlit", (0.12, 0.35, 0.055, 1.0), roughness=0.64),
        make_material("MAT_LeafVeinTechnologyCyan", (0.01, 0.48, 0.76, 1.0),
                      metallic=0.28, roughness=0.26,
                      emission=(0.01, 0.62, 0.92, 1.0)),
        make_material("MAT_LeafVeinMagicLilac", (0.44, 0.08, 0.72, 1.0),
                      metallic=0.08, roughness=0.38,
                      emission=(0.62, 0.12, 0.92, 1.0)),
    ]
    # A small diffuse self-fill preserves readable leaf and petal colour under
    # the dense overlapping canopy without turning either system into neon.
    for material in (*greens, *leaf_veins, *blossoms):
        shader = material.node_tree.nodes.get("Principled BSDF")
        emission_input = shader.inputs.get("Emission Color") or shader.inputs.get("Emission")
        strength_input = shader.inputs.get("Emission Strength")
        if emission_input is not None:
            emission_input.default_value = material.diffuse_color
        if strength_input is not None:
            strength_input.default_value = 0.13
    return greens, leaf_veins, blossoms


def create_canopy_mass(collection, secondary_paths, green_materials,
                       fractions=(0.52, 0.76, 1.0), name_prefix="Canopy"):
    rng = random.Random(260823)
    cluster_centres = []
    for path_index, path in enumerate(secondary_paths):
        for fraction in fractions:
            index = min(len(path) - 1, int(fraction * (len(path) - 1)))
            point = Vector(path[index])
            point += Vector((rng.uniform(-0.75, 0.75), rng.uniform(-0.75, 0.75),
                             rng.uniform(-0.25, 0.85)))
            cluster_centres.append(point)
    for index, centre in enumerate(cluster_centres):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=centre)
        cloud = link_only(bpy.context.object, collection)
        cloud.name = f"TOL_{name_prefix}FoliageCloud_{index + 1:03d}"
        tier_scale = leaf_scale_at(centre.z)
        footprint_scale = 1.0 + (tier_scale - 1.0) * 0.35
        scale = ((1.92 + rng.random() * 1.14) * footprint_scale,
                 (1.64 + rng.random() * 1.02) * footprint_scale,
                 (1.12 + rng.random() * 0.84) * (1.0 + (tier_scale - 1.0) * 0.24))
        cloud.scale = scale
        cloud.rotation_euler = (rng.uniform(-0.18, 0.18), rng.uniform(-0.18, 0.18),
                                rng.uniform(0.0, math.tau))
        cloud.data.materials.append(green_materials[index % len(green_materials)])
        cloud["module"] = "stylized_foliage_mass"
        cloud["editable_component"] = True
        cloud["tier_leaf_scale_multiplier"] = tier_scale
        cloud["blueprint_rule"] = "approved_green_leaf_mass_with_lilac_flower_overlay"
    return cluster_centres


def create_individual_leaves(collection, cluster_centres, green_materials,
                             leaf_vein_materials):
    rng = random.Random(180319)
    total_leaf_count = 0
    for cluster_index, centre in enumerate(cluster_centres):
        tier_scale = leaf_scale_at(centre.z)
        vertices = []
        faces = []
        material_indices = []
        for leaf_index in range(LEAVES_PER_CLUSTER):
            yaw = rng.uniform(0.0, math.tau)
            pitch = rng.uniform(-0.72, 0.72)
            radial = Vector((math.cos(yaw), math.sin(yaw), math.sin(pitch))).normalized()
            leaf_centre = centre + radial * rng.uniform(1.30, 2.65) \
                * (1.0 + (tier_scale - 1.0) * 0.40)
            length_axis = Vector((math.cos(yaw), math.sin(yaw),
                                  0.38 + 0.30 * math.sin(pitch))).normalized()
            width_axis = Vector((-math.sin(yaw), math.cos(yaw),
                                 rng.uniform(-0.12, 0.12))).normalized()
            surface_normal = length_axis.cross(width_axis).normalized()
            if surface_normal.dot(radial) < 0.0:
                surface_normal.negate()
            half_length = rng.uniform(*LEAF_HALF_LENGTH_RANGE_M) * tier_scale
            half_width = rng.uniform(*LEAF_HALF_WIDTH_RANGE_M) * tier_scale
            camber = rng.uniform(0.10, 0.22) * tier_scale

            base_centre = leaf_centre - length_axis * half_length
            first_centre = leaf_centre - length_axis * (half_length * 0.28) \
                + surface_normal * (camber * 0.72)
            second_centre = leaf_centre + length_axis * (half_length * 0.42) \
                + surface_normal * camber
            tip_centre = leaf_centre + length_axis * half_length \
                + surface_normal * (camber * 0.34)
            base = len(vertices)
            vertices.extend([
                tuple(base_centre),
                tuple(first_centre - width_axis * (half_width * 0.72)),
                tuple(first_centre),
                tuple(first_centre + width_axis * (half_width * 0.72)),
                tuple(second_centre - width_axis * half_width),
                tuple(second_centre),
                tuple(second_centre + width_axis * half_width),
                tuple(tip_centre),
            ])
            blade_faces = [
                (base, base + 1, base + 2),
                (base, base + 2, base + 3),
                (base + 1, base + 4, base + 5),
                (base + 1, base + 5, base + 2),
                (base + 2, base + 5, base + 6),
                (base + 2, base + 6, base + 3),
                (base + 4, base + 7, base + 5),
                (base + 5, base + 7, base + 6),
            ]
            faces.extend(blade_faces)
            leaf_material = (cluster_index + leaf_index) % len(green_materials)
            material_indices.extend([leaf_material] * len(blade_faces))

            # A raised mesh strip makes the biological/science/magic vein readable
            # in grazing light instead of painting a flat line onto the leaf.
            vein_base = len(vertices)
            vein_half_width = max(0.022, half_width * 0.075)
            for vein_centre in (base_centre, first_centre, second_centre, tip_centre):
                raised = vein_centre + surface_normal * (0.024 * tier_scale)
                vertices.extend([
                    tuple(raised - width_axis * vein_half_width),
                    tuple(raised + width_axis * vein_half_width),
                ])
            vein_faces = [
                (vein_base, vein_base + 2, vein_base + 3, vein_base + 1),
                (vein_base + 2, vein_base + 4, vein_base + 5, vein_base + 3),
                (vein_base + 4, vein_base + 6, vein_base + 7, vein_base + 5),
            ]
            faces.extend(vein_faces)
            material_indices.extend(
                [len(green_materials) + leaf_material] * len(vein_faces))
        mesh = bpy.data.meshes.new(f"TOL_LeafCluster_{cluster_index + 1:03d}Mesh")
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        leaves = bpy.data.objects.new(f"TOL_EditableLeafCluster_{cluster_index + 1:03d}", mesh)
        collection.objects.link(leaves)
        for material in (*green_materials, *leaf_vein_materials):
            leaves.data.materials.append(material)
        for polygon, material_index in zip(leaves.data.polygons, material_indices):
            polygon.material_index = material_index
        solidify = leaves.modifiers.new("LeafBladeThickness", "SOLIDIFY")
        solidify.thickness = LEAF_SOLIDIFY_THICKNESS_M * max(1.5, tier_scale * 0.72)
        solidify.offset = 0.0
        solidify.use_even_offset = True
        bevel = leaves.modifiers.new("LeafEdgeSoftening", "BEVEL")
        bevel.width = 0.018 * tier_scale
        bevel.segments = 2
        leaves["module"] = "editable_curved_lanceolate_leaf_mesh_cluster"
        leaves["editable_component"] = True
        leaves["leaf_count"] = len(faces)
        leaves["individual_leaf_count"] = LEAVES_PER_CLUSTER
        leaves["faces_per_leaf"] = LEAF_FACES_PER_BLADE
        leaves["tier_scale_multiplier"] = tier_scale
        leaves["leaf_full_length_range_m"] = [
            LEAF_HALF_LENGTH_RANGE_M[0] * 2.0 * tier_scale,
            LEAF_HALF_LENGTH_RANGE_M[1] * 2.0 * tier_scale,
        ]
        leaves["leaf_full_width_range_m"] = [
            LEAF_HALF_WIDTH_RANGE_M[0] * 2.0 * tier_scale,
            LEAF_HALF_WIDTH_RANGE_M[1] * 2.0 * tier_scale,
        ]
        leaves["mesh_construction"] = "curved_eight_vertex_blade_plus_raised_vein_and_solidify"
        leaves["blueprint_rule"] = \
            "large_curved_mesh_leaves_break_the_foliage_cloud_silhouette"
        total_leaf_count += LEAVES_PER_CLUSTER
    controller = bpy.data.objects.new("TOL_IndividualLeaves", None)
    collection.objects.link(controller)
    controller["module"] = "individual_lanceolate_leaves"
    controller["leaf_count"] = total_leaf_count
    controller["cluster_count"] = len(cluster_centres)
    controller["leaf_full_length_range_m"] = [
        LEAF_HALF_LENGTH_RANGE_M[0] * 2.0 * LEAF_CROWN_TIER_SCALE,
        LEAF_HALF_LENGTH_RANGE_M[1] * 2.0 * LEAF_LOWER_TIER_SCALE,
    ]
    controller["leaf_full_width_range_m"] = [
        LEAF_HALF_WIDTH_RANGE_M[0] * 2.0 * LEAF_CROWN_TIER_SCALE,
        LEAF_HALF_WIDTH_RANGE_M[1] * 2.0 * LEAF_LOWER_TIER_SCALE,
    ]
    controller["lower_tier_scale_multiplier"] = LEAF_LOWER_TIER_SCALE
    controller["middle_tier_scale_multiplier"] = LEAF_MIDDLE_TIER_SCALE
    controller["crown_tier_scale_multiplier"] = LEAF_CROWN_TIER_SCALE
    controller["faces_per_leaf"] = LEAF_FACES_PER_BLADE
    controller["solidify_thickness_m"] = LEAF_SOLIDIFY_THICKNESS_M
    return controller


def create_lilac_blossoms(collection, cluster_centres, blossom_materials):
    rng = random.Random(110624)
    template_meshes = []
    for material_index, material in enumerate(blossom_materials):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0)
        template = bpy.context.object
        template.name = f"TOL_BlossomTemplate_{material_index}"
        template.data.name = f"TOL_BlossomCloudMesh_{material_index}"
        template.data.materials.append(material)
        template.data.use_fake_user = True
        template_meshes.append(template.data)
        bpy.data.objects.remove(template, do_unlink=True)
    blossom_mass_count = 0
    for cluster_index, centre in enumerate(cluster_centres):
        mass_count = 4 + (cluster_index % 3)
        for mass_index in range(mass_count):
            angle = rng.uniform(0.0, math.tau)
            distance = rng.uniform(0.45, 1.22)
            origin = Vector(centre) + Vector((math.cos(angle) * distance,
                                             math.sin(angle) * distance,
                                             rng.uniform(0.55, 1.35)))
            mesh = template_meshes[(cluster_index + mass_index) % len(template_meshes)]
            blossom = bpy.data.objects.new(
                f"TOL_LilacBlossomMass_{blossom_mass_count + 1:03d}", mesh)
            collection.objects.link(blossom)
            blossom.location = origin
            blossom.scale = (rng.uniform(0.22, 0.38), rng.uniform(0.20, 0.36),
                              rng.uniform(0.32, 0.56))
            blossom.rotation_euler = (rng.uniform(-0.16, 0.16),
                                      rng.uniform(-0.16, 0.16), rng.uniform(0.0, math.tau))
            blossom["module"] = "soft_lilac_flower_mass"
            blossom["editable_component"] = True
            blossom["blueprint_rule"] = "approved_lilac_flower_mass_above_green_foliage"
            blossom_mass_count += 1
    controller = bpy.data.objects.new("TOL_LilacBlossomPlumes", None)
    collection.objects.link(controller)
    controller["module"] = "lilac_flower_plumes"
    controller["mass_count"] = blossom_mass_count
    controller["plume_count"] = blossom_mass_count * 2
    return controller


def create_heart_presentation(collection, gold_material, crystal_material,
                              magic_material, core_material, dark_wood_material,
                              warm_wood_material):
    radius = radius_at(HEART_CENTER)
    centre = centre_at(HEART_CENTER)
    front_y = centre.y - radius - 0.28
    components = []

    # Recess the mechanism into a continuous cambium socket before placing any
    # metal. This dark liner supplies contact shadow and makes the concentric
    # clearance around the gear legible in player-distance close-ups.
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=64, radius=7.32, depth=0.72,
        location=(centre.x, front_y + 0.54, HEART_CENTER),
        rotation=(math.pi * 0.5, 0.0, 0.0))
    recess_back = link_only(bpy.context.object, collection)
    recess_back.name = "TOL_HeartTreeSocketShadowRecess"
    recess_back.data.materials.append(dark_wood_material)
    recess_back["module"] = "heart_tree_socket_shadow_recess"
    recess_back["editable_component"] = True
    recess_back["blueprint_rule"] = "gear_is_recessed_into_living_cambium_not_floating"
    components.append(recess_back)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=7.08, minor_radius=0.58,
        major_segments=64, minor_segments=10,
        location=(centre.x, front_y + 0.26, HEART_CENTER),
        rotation=(math.pi * 0.5, 0.0, 0.0))
    socket_liner = link_only(bpy.context.object, collection)
    socket_liner.name = "TOL_HeartTreeSocketCambiumLiner"
    socket_liner.data.materials.append(dark_wood_material)
    socket_liner["module"] = "heart_tree_socket_cambium_liner"
    socket_liner["editable_component"] = True
    socket_liner["gear_clearance_m"] = 0.38
    components.append(socket_liner)

    # The Blender presentation now carries the same unmistakable cog silhouette
    # as the Godot shrine: a structural torus plus 24 forged teeth, all seated
    # inside the cambium liner instead of hovering over it.
    bpy.ops.mesh.primitive_torus_add(
        major_radius=5.72, minor_radius=0.34,
        major_segments=64, minor_segments=10,
        location=(centre.x, front_y - 0.02, HEART_CENTER),
        rotation=(math.pi * 0.5, 0.0, 0.0))
    gear_rim = link_only(bpy.context.object, collection)
    gear_rim.name = "TOL_HeartTreeSocketMainGearRim"
    gear_rim.data.materials.append(gold_material)
    gear_rim["module"] = "heart_tree_socket_load_bearing_gear_rim"
    gear_rim["editable_component"] = True
    gear_rim["tooth_count"] = 24
    components.append(gear_rim)
    for tooth_index in range(24):
        tooth_angle = math.tau * tooth_index / 24.0
        tooth_radial = Vector((math.cos(tooth_angle), 0.0, math.sin(tooth_angle)))
        tooth_location = Vector((centre.x, front_y - 0.04, HEART_CENTER)) \
            + tooth_radial * 6.18
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=tooth_location)
        tooth = link_only(bpy.context.object, collection)
        tooth.name = f"TOL_HeartTreeSocketGearTooth_{tooth_index + 1:02d}"
        tooth.rotation_euler.y = -tooth_angle
        tooth.scale = (0.28, 0.30, 0.58)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        tooth_bevel = tooth.modifiers.new("ForgedToothEdge", "BEVEL")
        tooth_bevel.width = 0.07
        tooth_bevel.segments = 2
        tooth.data.materials.append(gold_material)
        tooth["module"] = "heart_tree_socket_forged_gear_tooth"
        tooth["editable_component"] = True
        components.append(tooth)

    # Eight slightly asymmetric fibers grow from the trunk into the metal rim.
    # Each terminates beneath a clamp, giving every bright component a visible
    # load path into the tree rather than leaving an ornamental gap.
    anchor_radius = 6.66
    for anchor_index in range(8):
        angle = math.tau * anchor_index / 8.0
        radial = Vector((math.cos(angle), 0.0, math.sin(angle)))
        tangent = Vector((-math.sin(angle), 0.0, math.cos(angle)))
        sway = 0.42 if anchor_index % 2 == 0 else -0.42
        points = [
            Vector((centre.x, front_y + 1.22, HEART_CENTER)) + radial * 9.05 + tangent * sway,
            Vector((centre.x, front_y + 0.72, HEART_CENTER)) + radial * 7.82 - tangent * sway * 0.45,
            Vector((centre.x, front_y + 0.18, HEART_CENTER)) + radial * anchor_radius,
        ]
        anchor = tapered_tube(
            f"TOL_HeartTreeSocketAnchor_{anchor_index + 1:02d}", points,
            0.82, 0.28, warm_wood_material, collection, radial_segments=9)
        anchor["module"] = "heart_tree_socket_living_wood_anchor"
        anchor["editable_component"] = True
        anchor["terminates_at_gear_rim"] = True
        components.append(anchor)

        clamp_centre = Vector((centre.x, front_y - 0.03, HEART_CENTER)) \
            + radial * anchor_radius
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=clamp_centre)
        clamp = link_only(bpy.context.object, collection)
        clamp.name = f"TOL_HeartTreeSocketBrassClamp_{anchor_index + 1:02d}"
        clamp.rotation_euler.y = angle + math.pi * 0.5
        clamp.scale = (1.18, 0.22, 0.38)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        bevel = clamp.modifiers.new("SoftForgedEdges", "BEVEL")
        bevel.width = 0.10
        bevel.segments = 2
        clamp.data.materials.append(gold_material)
        clamp["module"] = "heart_tree_socket_brass_clamp"
        clamp["editable_component"] = True
        clamp["seats_wood_anchor_to_gear"] = True
        components.append(clamp)
        for bolt_side in (-1.0, 1.0):
            bolt_location = clamp_centre + tangent * bolt_side * 0.66 + Vector((0.0, -0.27, 0.0))
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=12, radius=0.15, depth=0.16, location=bolt_location,
                rotation=(math.pi * 0.5, 0.0, 0.0))
            bolt = link_only(bpy.context.object, collection)
            bolt.name = (f"TOL_HeartTreeSocketBolt_{anchor_index + 1:02d}_"
                         f"{'A' if bolt_side < 0.0 else 'B'}")
            bolt.data.materials.append(gold_material)
            bolt["module"] = "heart_tree_socket_brass_bolt"
            bolt["editable_component"] = True
            components.append(bolt)
    for ring_index, (ring_radius, minor_radius, tilt_x, tilt_z) in enumerate((
            (5.70, 0.20, 0.0, 0.0),
            (6.10, 0.13, math.radians(54.0), 0.0),
            (6.45, 0.12, 0.0, math.radians(58.0)))):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=ring_radius, minor_radius=minor_radius,
            major_segments=48, minor_segments=8,
            location=(centre.x, front_y + ring_index * 0.03, HEART_CENTER),
            rotation=(math.pi * 0.5 + tilt_x, 0.0, tilt_z))
        frame = link_only(bpy.context.object, collection)
        frame.name = f"TOL_HeartAstrolabeOrbit_{ring_index + 1:02d}"
        frame.data.materials.append(gold_material)
        frame["module"] = "editable_gold_heart_astrolabe_orbit"
        frame["editable_component"] = True
        frame["blueprint_rule"] = "science_orbits_magic_runes_around_living_crystal"
        components.append(frame)

    for spoke_index in range(8):
        angle = math.tau * spoke_index / 8.0
        length = 2.65
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(centre.x + math.cos(angle) * 3.05, front_y + 0.06,
                      HEART_CENTER + math.sin(angle) * 3.05),
            rotation=(math.pi * 0.5, angle, 0.0))
        spoke = link_only(bpy.context.object, collection)
        spoke.name = f"TOL_HeartFrameRadialSpoke_{spoke_index + 1:02d}"
        spoke.scale = (length, 0.085, 0.11)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        spoke.data.materials.append(gold_material)
        spoke["module"] = "editable_gold_heart_radial_spoke"
        spoke["editable_component"] = True
        components.append(spoke)

    for rune_index in range(8):
        angle = math.tau * rune_index / 8.0
        rune_x = centre.x + math.cos(angle) * 6.80
        rune_z = HEART_CENTER + math.sin(angle) * 6.80
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.38, minor_radius=0.10, major_segments=18, minor_segments=6,
            location=(rune_x, front_y - 0.04, rune_z),
            rotation=(math.pi * 0.5, 0.0, 0.0))
        socket = link_only(bpy.context.object, collection)
        socket.name = f"TOL_HeartFrameRuneSocket_{rune_index + 1:02d}"
        socket.data.materials.append(gold_material)
        socket["module"] = "editable_gold_heart_rune_socket"
        socket["editable_component"] = True
        components.append(socket)

        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=1, radius=0.22,
            location=(rune_x, front_y - 0.09, rune_z))
        jewel = link_only(bpy.context.object, collection)
        jewel.name = f"TOL_HeartFrameRuneJewel_{rune_index + 1:02d}"
        jewel.scale = (0.72, 0.45, 1.35)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        jewel.data.materials.append(crystal_material if rune_index % 2 == 0 else magic_material)
        jewel["module"] = "editable_heart_rune_jewel"
        jewel["editable_component"] = True
        components.append(jewel)

    crystal_vertices = [(-1.42, 0.0, 0.0), (0.0, -0.68, 0.0), (1.42, 0.0, 0.0),
                        (0.0, 0.68, 0.0), (0.0, 0.0, 2.85), (0.0, 0.0, -2.85)]
    crystal_faces = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4),
                     (1, 0, 5), (2, 1, 5), (3, 2, 5), (0, 3, 5)]
    mesh = bpy.data.meshes.new("TOL_HeartCrystalMesh")
    mesh.from_pydata(crystal_vertices, [], crystal_faces)
    mesh.update()
    crystal = bpy.data.objects.new("TOL_HeartCrystal", mesh)
    collection.objects.link(crystal)
    pivot = bpy.data.objects.new("TOL_HeartCrystalSpinPivot", None)
    collection.objects.link(pivot)
    pivot.location = (centre.x, front_y - 0.18, HEART_CENTER)
    pivot["module"] = "heart_crystal_rotation_controller"
    pivot["animation"] = "continuous_self_rotation"
    crystal.parent = pivot
    crystal.location = (0.0, 0.0, 0.0)
    crystal.data.materials.append(crystal_material)
    crystal["module"] = "faceted_rotating_heart_crystal"
    crystal["editable_component"] = True
    pivot.rotation_euler.z = 0.0
    spin_driver = pivot.driver_add("rotation_euler", 2).driver
    spin_driver.type = "SCRIPTED"
    spin_driver.expression = "frame * 2 * pi / 240"
    core = bpy.data.objects.new("TOL_HeartCrystalInnerCore", mesh.copy())
    collection.objects.link(core)
    core.parent = pivot
    core.scale = (0.44, 0.44, 0.62)
    core.data.materials.append(core_material)
    core["module"] = "counter_rotating_heart_crystal_inner_core"
    core["editable_component"] = True
    bpy.ops.object.light_add(type="POINT", location=(centre.x, front_y - 1.2, HEART_CENTER))
    glow = link_only(bpy.context.object, collection)
    glow.name = "TOL_HeartCrystalGlow"
    glow.data.color = (0.04, 0.72, 1.0)
    glow.data.energy = 360.0
    glow.data.shadow_soft_size = 2.0
    return components, crystal


def create_gold_branch_collars(collection, branch_paths, gold_material):
    """Seat an editable mechanical gold graft around each major living bough."""
    collars = []
    for index, path in enumerate(branch_paths):
        root = Vector(path[0])
        tangent = (Vector(path[min(2, len(path) - 1)]) - root).normalized()
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.46, minor_radius=0.085,
            major_segments=18, minor_segments=6, location=root)
        collar = link_only(bpy.context.object, collection)
        collar.name = f"TOL_EditableGoldBranchCollar_{index + 1:03d}"
        # A torus starts with its normal on Z; align that opening to the bough.
        collar.rotation_mode = "QUATERNION"
        collar.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(tangent)
        collar.data.materials.append(gold_material)
        collar["module"] = "editable_gold_mechanical_branch_graft"
        collar["editable_component"] = True
        collar["blueprint_rule"] = "gold_engineering_supports_living_wood_not_leaves"
        collars.append(collar)
    return collars


def create_presentation_ground(collection, material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=22.0, depth=0.55,
                                       location=(0.0, 0.0, -0.32))
    ground = link_only(bpy.context.object, collection)
    ground.name = "TOL_PresentationMeadow"
    ground.data.materials.append(material)
    bevel = ground.modifiers.new("MeadowEdge", "BEVEL")
    bevel.width = 0.35
    bevel.segments = 3
    return ground


def point_camera(camera, target):
    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def add_render_camera(collection, name, location, target, lens):
    data = bpy.data.cameras.new(name + "Data")
    data.lens = lens
    data.sensor_width = 36.0
    camera = bpy.data.objects.new(name, data)
    collection.objects.link(camera)
    camera.location = location
    point_camera(camera, target)
    return camera


def setup_render_world(scene, collection):
    world = bpy.data.worlds.new("TOL_GardenWorld") if scene.world is None else scene.world
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.012, 0.025, 0.022, 1.0)
    background.inputs["Strength"].default_value = 0.55
    bpy.ops.object.light_add(type="SUN", location=(8.0, -12.0, 24.0))
    sun = link_only(bpy.context.object, collection)
    sun.name = "TOL_WarmKeySun"
    sun.rotation_euler = (math.radians(24.0), math.radians(-18.0), math.radians(-28.0))
    sun.data.energy = 2.2
    sun.data.angle = math.radians(12.0)
    sun.data.color = (1.0, 0.82, 0.64)
    bpy.ops.object.light_add(type="AREA", location=(-12.0, -10.0, 19.0))
    fill = link_only(bpy.context.object, collection)
    fill.name = "TOL_CoolCanopyFill"
    fill.data.energy = 1850.0
    fill.data.shape = "DISK"
    fill.data.size = 12.0
    fill.data.color = (0.45, 0.60, 1.0)
    point_camera(fill, (0.0, 0.0, 34.0))
    bpy.ops.object.light_add(type="AREA", location=(18.0, -28.0, 16.0))
    root_fill = link_only(bpy.context.object, collection)
    root_fill.name = "TOL_WarmRootFiberFill"
    root_fill.data.energy = 1050.0
    root_fill.data.shape = "DISK"
    root_fill.data.size = 10.0
    root_fill.data.color = (1.0, 0.68, 0.42)
    point_camera(root_fill, (0.0, -0.5, 10.0))


def render_presentation(scene, collection):
    os.makedirs(RENDER_DIR, exist_ok=True)
    # Blender 5.2 exposes Eevee through the stable BLENDER_EEVEE identifier.
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    scene.render.resolution_percentage = 100
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1200
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.look = "AgX - Medium High Contrast"
    requested_cameras = {
        name.strip() for name in os.environ.get(
            "ARTEA_TRUNK_RENDER_FILTER", "").split(",") if name.strip()}
    cameras = [
        ("TOL_BlueprintFrontCamera", (0.0, -150.0, 33.0), (0.0, 0.0, 32.0), 45.0,
         BLUEPRINT_FRONT_RENDER_PATH),
        ("TOL_RootPlanCamera", (0.0, 0.0, 82.0), (0.0, 0.0, 0.0), 52.0,
         ROOT_PLAN_RENDER_PATH),
        ("TOL_HeroCamera", (70.0, -122.0, 55.0), (0.0, 0.0, 31.0), 58.0,
         HERO_RENDER_PATH),
        ("TOL_TrunkDetailCamera", (34.0, -67.0, 27.0), (0.0, -0.4, 20.0), 62.0,
         TRUNK_RENDER_PATH),
        ("TOL_CanopyDetailCamera", (46.0, -78.0, 68.0), (0.0, 0.5, 56.0), 66.0,
         CANOPY_RENDER_PATH),
        ("TOL_LeafMeshDetailCamera", (-6.3, -30.0, 52.5),
         (-6.1, -20.5, 50.0), 68.0, LEAF_RENDER_PATH),
        ("TOL_RootFiberDetailCamera", (25.0, -46.0, 10.0), (0.0, -1.5, 5.0), 58.0,
         ROOT_RENDER_PATH),
        ("TOL_TrunkFiberDetailCamera", (28.0, -55.0, 38.0), (0.0, -0.7, 30.0), 66.0,
         FIBER_RENDER_PATH),
        ("TOL_HeartCrystalDetailCamera", (0.4, -44.0, 14.0), (0.0, -12.2, 14.0), 55.0,
         HEART_RENDER_PATH),
        ("TOL_GravityBoughAttachmentCamera", (31.0, -50.0, 22.0),
         (0.0, 0.0, 18.0), 62.0, BRANCH_ATTACHMENT_RENDER_PATH),
        ("TOL_BlueprintFoundationCamera", (0.0, -70.0, 11.0),
         (0.0, -1.8, 4.2), 58.0, FOUNDATION_RENDER_PATH),
    ]
    for name, location, target, lens, output in cameras:
        if requested_cameras and name not in requested_cameras:
            continue
        camera = add_render_camera(collection, name, location, target, lens)
        scene.camera = camera
        scene.render.filepath = output
        hidden_for_plan = []
        if name == "TOL_RootPlanCamera":
            root_tokens = (
                "PrimaryRoot", "SecondaryRootlet", "RootEnergyChannel",
                "RootManifold", "RootCambium", "DoorwayButtress", "DoorwayArch", "Foundation",
                "ApproachStair", "ApproachEnergyInlay", "DoorwayThreshold",
                "PresentationMeadow",
            )
            # Use every scene object here rather than only the source collection.
            # The editable canopy lives in a nested detail collection, and Blender's
            # render dependency graph may otherwise retain those child objects.
            for candidate in scene.objects:
                if candidate.type in ("MESH", "CURVE", "EMPTY") \
                        and not any(token in candidate.name for token in root_tokens):
                    hidden_for_plan.append((candidate, candidate.hide_render))
                    candidate.hide_render = True
            bpy.context.view_layer.update()
        elif name in {
                "TOL_TrunkDetailCamera", "TOL_RootFiberDetailCamera",
                "TOL_TrunkFiberDetailCamera", "TOL_HeartCrystalDetailCamera",
                "TOL_BlueprintFoundationCamera"}:
            for candidate in scene.objects:
                if candidate.get("module", "") == "approved_gravity_leaf_bough_tier":
                    hidden_for_plan.append((candidate, candidate.hide_render))
                    candidate.hide_render = True
            bpy.context.view_layer.update()
        bpy.ops.render.render(write_still=True)
        for candidate, previous_state in hidden_for_plan:
            candidate.hide_render = previous_state
        if hidden_for_plan:
            bpy.context.view_layer.update()


def duplicate_as_mesh(source, collection, parent):
    duplicate = source.copy()
    duplicate.data = source.data.copy()
    collection.objects.link(duplicate)
    duplicate.parent = parent
    duplicate.matrix_world = source.matrix_world.copy()
    if duplicate.type == "CURVE":
        bpy.ops.object.select_all(action="DESELECT")
        duplicate.select_set(True)
        bpy.context.view_layer.objects.active = duplicate
        bpy.ops.object.convert(target="MESH")
    return duplicate


def join_objects(objects, name, parent):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    joined.data.name = name + "Mesh"
    joined.parent = parent
    return joined


def apply_modifiers(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def add_longitudinal_uv(mesh_obj):
    mesh = mesh_obj.data
    uv_layer = mesh.uv_layers.get("EnergyFlowUV") or mesh.uv_layers.new(name="EnergyFlowUV")
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex = mesh.vertices[mesh.loops[loop_index].vertex_index]
            uv_layer.data[loop_index].uv = (0.5, max(0.0, min(1.0, vertex.co.z / HEIGHT)))
    mesh_obj["longitudinal_uv"] = True


def build_export(source_objects, export_collection):
    root = bpy.data.objects.new("SimpleTrunkCore", None)
    export_collection.objects.link(root)
    root["height_m"] = HEIGHT
    root["root_diameter_m"] = ROOT_SPREAD_RADIUS * 2.0
    root["base_trunk_diameter_m"] = BASE_TRUNK_RADIUS * 2.0
    root["neck_diameter_m"] = NECK_RADIUS * 2.0
    root["heart_niche_m"] = (HEART_WIDTH, HEART_HEIGHT, HEART_DEPTH)
    root["primary_energy_veins"] = VEIN_COUNT
    root["primary_roots"] = PRIMARY_ROOT_COUNT
    root["secondary_rootlets"] = PRIMARY_ROOT_COUNT * ROOTLETS_PER_PRIMARY
    root["heart_feeders"] = HEART_FEEDER_COUNT
    root["crown_energy_veins"] = CROWN_VEIN_COUNT
    root["bough_sockets"] = SOCKET_COUNT

    direct_names = {"TOL_InnerShell": "InnerShell", "TOL_DoorwayArch": "DoorwayArch",
                    "TOL_HeartRecess": "HeartRecess", "TOL_RootManifold": "RootManifold"}
    exported = []
    rib_exports = []
    vein_exports = []
    detail_exports = {
        "PrimaryRoots": [],
        "SecondaryRootlets": [],
        "RootCambiumWebbing": [],
        "DoorwayButtresses": [],
        "RootEnergyChannels": [],
        "HeartFeeders": [],
        "CrownVeins": [],
        "BarkLaths": [],
        "GrainGrooves": [],
        "EnergyCapillaries": [],
        "FoundationArchitecture": [],
    }
    for source in source_objects:
        duplicate = duplicate_as_mesh(source, export_collection, root)
        if source.name.startswith("TOL_BarkRib_"):
            rib_exports.append(duplicate)
        elif source.name.startswith("TOL_EnergyVein_"):
            vein_exports.append(duplicate)
        elif source.name.startswith("TOL_EditablePrimaryRoot_"):
            detail_exports["PrimaryRoots"].append(duplicate)
        elif source.name.startswith("TOL_EditableSecondaryRootlet_"):
            detail_exports["SecondaryRootlets"].append(duplicate)
        elif source.name.startswith("TOL_RootCambiumWebbing"):
            detail_exports["RootCambiumWebbing"].append(duplicate)
        elif source.name.startswith("TOL_DoorwayButtress_"):
            detail_exports["DoorwayButtresses"].append(duplicate)
        elif source.name.startswith("TOL_EditableRootEnergyChannel_"):
            detail_exports["RootEnergyChannels"].append(duplicate)
        elif source.name.startswith("TOL_EditableHeartFeeder_"):
            detail_exports["HeartFeeders"].append(duplicate)
        elif source.name.startswith("TOL_EditableCrownVein_"):
            detail_exports["CrownVeins"].append(duplicate)
        elif source.name.startswith("TOL_EditableBarkLath_"):
            detail_exports["BarkLaths"].append(duplicate)
        elif source.name.startswith("TOL_EditableGrainGroove_"):
            detail_exports["GrainGrooves"].append(duplicate)
        elif source.name.startswith("TOL_EditableEnergyCapillary_"):
            detail_exports["EnergyCapillaries"].append(duplicate)
        elif source.name.startswith("TOL_Foundation") \
                or source.name.startswith("TOL_Approach") \
                or source.name.startswith("TOL_DoorwayThreshold"):
            detail_exports["FoundationArchitecture"].append(duplicate)
        else:
            duplicate.name = direct_names.get(source.name, source.name)
            if duplicate.name == "InnerShell":
                apply_modifiers(duplicate)
            exported.append(duplicate)
    ribs = join_objects(rib_exports, "BarkRibs", root)
    ribs["structural_ribs"] = RIB_COUNT
    veins = join_objects(vein_exports, "EnergyVeins", root)
    veins["primary_veins"] = VEIN_COUNT
    veins["heart_clear_zone_respected"] = True
    add_longitudinal_uv(veins)
    exported.extend([ribs, veins])
    for export_name, detail_objects in detail_exports.items():
        joined = join_objects(detail_objects, export_name, root)
        # Source objects keep their soft bevels for Blender renders. Runtime
        # batches use the authored base topology to remain inside the Web GLB
        # triangle budget; joining otherwise retains the active bevel modifier.
        for modifier in list(joined.modifiers):
            joined.modifiers.remove(modifier)
        # Keep every editable rootlet at full detail in Blender, while simplifying
        # only their joined runtime batch. This preserves the denser 18/54 root
        # silhouette and avoids spending laptop triangles on hidden tube loops.
        if export_name == "SecondaryRootlets":
            decimate = joined.modifiers.new("LaptopRootletSimplification", "DECIMATE")
            decimate.ratio = 0.68
            decimate.use_collapse_triangulate = True
            apply_modifiers(joined)
        joined["editable_source_components"] = len(detail_objects)
        joined["runtime_batch"] = True
        if export_name in ("EnergyCapillaries", "RootEnergyChannels",
                           "HeartFeeders", "CrownVeins"):
            add_longitudinal_uv(joined)
        exported.append(joined)
    sockets = create_socket_empties(export_collection, root)
    return root, exported, sockets


def triangle_count(objects):
    count = 0
    for obj in objects:
        if obj.type != "MESH":
            continue
        obj.data.calc_loop_triangles()
        count += len(obj.data.loop_triangles)
    return count


def component_shape_family(obj):
    module = str(obj.get("module", ""))
    if "primary_root" in module:
        return "grounded_tapered_primary_root"
    if "rootlet" in module:
        return "secondary_rootlet_split"
    if "doorway_root_buttress" in module:
        return "walkthrough_doorway_buttress"
    if "root_fiber" in module:
        return "tapered_ground_root_fiber"
    if "bark_lath" in module or "bark_rib" in module:
        return "twisting_longitudinal_wood_ribbon"
    if "grain_groove" in module:
        return "recessed_dark_cambium_curve"
    if "energy" in module or "vein" in module:
        return "glowing_cyan_flow_curve"
    if "christmas_tree_tier" in module:
        return "tapered_fir_whorl_bough"
    if "bough" in module or "branch" in module or "leader" in module:
        return "tapered_branch_tube"
    if "foliage" in module:
        return "irregular_low_poly_leaf_cloud"
    if "leaf_cluster" in module or "lanceolate" in module:
        return "nineteen_curved_lanceolate_mesh_leaves_with_raised_veins"
    if "flower" in module:
        return "low_poly_lilac_flower_mass"
    if "heart" in module:
        return "organic_heart_niche_component"
    return obj.type.lower()


def write_component_manifest(source_collection, group_counts, tier_profile):
    components = []
    for obj in sorted(source_collection.all_objects, key=lambda candidate: candidate.name):
        materials = []
        if getattr(obj, "data", None) is not None and hasattr(obj.data, "materials"):
            materials = [material.name for material in obj.data.materials if material is not None]
        components.append({
            "name": obj.name,
            "object_type": obj.type,
            "shape_family": component_shape_family(obj),
            "module": str(obj.get("module", "presentation_support")),
            "editable_component": bool(obj.get("editable_component", True)),
            "blueprint_rule": str(obj.get("blueprint_rule", "presentation_support")),
            "materials": materials,
            "location_m": [round(value, 4) for value in obj.location],
            "scale": [round(value, 4) for value in obj.scale],
        })
    manifest = {
        "asset": "tree_of_life_editable_blender_components",
        "version": 2,
        "source_blend": "assets3D/tree_of_life/trunk_core/source/simple_trunk_core.blend",
        "blueprint": "design/tree_of_life/blueprints/trunk_core_reference_redesign_v2.md",
        "editing_contract": {
            "object_names_are_stable": True,
            "major_shapes_are_separate_objects": True,
            "leaf_clusters_are_separate_edit_mode_islands": True,
            "leaf_blades_are_curved_solid_meshes": True,
            "leaf_centre_veins_are_raised_mesh_strips": True,
            "canopy_presentation_geometry_is_excluded_from_game_glb": True,
            "trunk_and_root_sources_are_batched_into_nine_runtime_meshes": True,
            "door_and_heart_exclusion_zones_are_preserved": True,
        },
        "blueprint_alignment": [
            "continuous_ground_root_to_trunk_load_paths",
            "eighteen_primary_roots_each_split_into_three_secondary_rootlets",
            "eighteen_root_intakes_feed_six_collectors_two_heart_feeders_and_sixteen_crown_veins",
            "pale_exposed_fibers_over_dark_cambium_grooves",
            "six_primary_energy_veins_with_secondary_capillaries",
            "production_christmas_tree_whorl_taper_and_pitch",
            "continuous_foliage_from_twelve_meter_root_flare_to_apex",
            "tier_scaled_leaves_three_times_lower_two_point_two_times_crown",
            "approved_green_leaf_and_lilac_flower_language",
            "large_curved_leaf_meshes_with_nature_technology_magic_veins",
            "south_doorway_and_heart_projection_clear",
        ],
        "group_counts": group_counts,
        "christmas_tier_profile": tier_profile,
        "component_count": len(components),
        "components": components,
    }
    with open(COMPONENT_MANIFEST_PATH, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")
    return manifest


def select_recursive(obj):
    obj.select_set(True)
    for child in obj.children:
        select_recursive(child)


def main():
    os.makedirs(SOURCE_DIR, exist_ok=True)
    os.makedirs(GLB_DIR, exist_ok=True)
    os.makedirs(RENDER_DIR, exist_ok=True)
    reset_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.length_unit = "METERS"
    scene.render.engine = "BLENDER_EEVEE"
    scene["asset_title"] = "ARTEA TREE OF LIFE — TRUNK, BOUGHS, LEAVES AND LILAC BLOSSOMS"
    scene["blueprint"] = "design/tree_of_life/blueprints/trunk_core_reference_redesign_v2.md"
    scene["heart_blueprint"] = "design/tree_of_life/blueprints/heart_crystal_century_canopy_v3.md"

    source_collection = new_collection("TOL_TRUNK_CORE_SOURCE")
    detail_collection = new_child_collection(source_collection, "TOL_EDITABLE_DETAIL_COMPONENTS")
    export_collection = new_collection("TOL_TRUNK_CORE_EXPORT")
    export_collection.hide_render = True
    heartwood = make_material("MAT_WoodHeartwood", (0.075, 0.038, 0.022, 1.0), roughness=0.94)
    warm_bark = make_material("MAT_WoodWarmBark", (0.27, 0.14, 0.068, 1.0), roughness=0.90)
    sunlit_bark = make_material("MAT_WoodSunlitBark", (0.50, 0.30, 0.14, 1.0), roughness=0.86)
    bark_materials = [heartwood, warm_bark, sunlit_bark, warm_bark]
    rib_materials = [sunlit_bark, warm_bark, sunlit_bark, heartwood]
    dark = make_material("MAT_HeartRecessDarkWood", (0.035, 0.012, 0.008, 1.0), roughness=0.94)
    cyan = make_material("MAT_EnergyVeinCyan", (0.01, 0.55, 0.86, 1.0), metallic=0.1,
                         roughness=0.18, emission=(0.01, 0.80, 1.0, 1.0))
    capillary_cyan = make_material(
        "MAT_EnergyCapillaryCyan", (0.015, 0.24, 0.36, 1.0), metallic=0.05,
        roughness=0.28, emission=(0.01, 0.42, 0.56, 1.0))
    capillary_shader = capillary_cyan.node_tree.nodes.get("Principled BSDF")
    if capillary_shader.inputs.get("Emission Strength") is not None:
        capillary_shader.inputs["Emission Strength"].default_value = 0.72
    gold = make_material("MAT_HeartShrineGold", (0.72, 0.43, 0.08, 1.0), metallic=0.72,
                         roughness=0.24)
    crystal = make_material("MAT_HeartCrystalCyan", (0.01, 0.52, 0.92, 1.0), metallic=0.08,
                            roughness=0.10, emission=(0.0, 0.78, 1.0, 1.0))
    magic_crystal = make_material("MAT_HeartRuneArcBlue", (0.08, 0.22, 0.92, 1.0),
                                  metallic=0.06, roughness=0.16,
                                  emission=(0.12, 0.46, 1.0, 1.0))
    crystal_core = make_material("MAT_HeartCrystalInnerCore", (0.38, 0.82, 1.0, 1.0),
                                 roughness=0.08, emission=(0.45, 0.90, 1.0, 1.0))
    for heart_material, strength in ((crystal, 1.35), (magic_crystal, 1.1),
                                     (crystal_core, 1.8)):
        heart_shader = heart_material.node_tree.nodes.get("Principled BSDF")
        if heart_shader.inputs.get("Emission Strength") is not None:
            heart_shader.inputs["Emission Strength"].default_value = strength
    meadow = make_material("MAT_PresentationMeadow", (0.055, 0.16, 0.055, 1.0), roughness=0.95)
    foundation_stone = [
        make_material("MAT_FoundationDeepSlate", (0.035, 0.075, 0.095, 1.0),
                      metallic=0.12, roughness=0.72),
        make_material("MAT_FoundationBlueStone", (0.075, 0.16, 0.20, 1.0),
                      metallic=0.16, roughness=0.64),
    ]
    green_materials, leaf_vein_materials, blossom_materials = create_foliage_materials()
    for bark_material in (heartwood, warm_bark, sunlit_bark, dark):
        add_bark_microdetail(bark_material)

    shell = create_inner_shell(source_collection, bark_materials)
    ribs, veins = create_ribs(source_collection, rib_materials, cyan)
    doorway = create_doorway_arch(source_collection, heartwood)
    doorway_buttresses = create_doorway_buttresses(
        detail_collection, sunlit_bark, warm_bark)
    root_cambium_webbing = create_root_cambium_webbing(
        detail_collection, heartwood, warm_bark)
    foundation_components = create_foundation_architecture(
        detail_collection, foundation_stone, cyan)
    foundation_components.extend(create_doorway_energy_detail(
        detail_collection, cyan))
    recess = create_recess(source_collection, dark)
    manifold = create_root_manifold(source_collection, cyan)
    create_socket_empties(source_collection)
    major_paths, secondary_paths = create_branch_architecture(
        source_collection, sunlit_bark, warm_bark)
    crown_leaders, crown_branchlets = create_crown_leaders(
        source_collection, sunlit_bark, warm_bark)
    christmas_paths, christmas_tier_profile, christmas_spire = \
        create_christmas_tier_architecture(source_collection, sunlit_bark, warm_bark)
    gold_branch_collars = create_gold_branch_collars(
        detail_collection, [*major_paths, *christmas_paths], gold)
    reference_cluster_centres = create_canopy_mass(
        source_collection, [*secondary_paths, *crown_branchlets], green_materials)
    christmas_cluster_centres = create_canopy_mass(
        source_collection, christmas_paths, green_materials,
        fractions=(0.68, 1.0), name_prefix="ChristmasTier")
    cluster_centres = [*reference_cluster_centres, *christmas_cluster_centres]
    leaves = create_individual_leaves(
        source_collection, cluster_centres, green_materials, leaf_vein_materials)
    blossoms = create_lilac_blossoms(source_collection, cluster_centres, blossom_materials)
    approved_bough_instances, approved_bough_leaf_instances = \
        append_approved_gravity_bough_canopy(source_collection)
    superseded_canopy_objects = hide_superseded_presentation_canopy()
    fiber_components = create_editable_fiber_system(
        detail_collection, sunlit_bark, warm_bark, dark, capillary_cyan)
    create_heart_presentation(
        source_collection, gold, crystal, magic_crystal, crystal_core,
        dark, warm_bark)
    create_presentation_ground(source_collection, meadow)
    setup_render_world(scene, source_collection)
    source_objects = [shell, doorway, recess, manifold, *ribs, *veins,
                      *doorway_buttresses,
                      root_cambium_webbing,
                      *foundation_components,
                      *fiber_components["ground_root_fibers"],
                      *fiber_components["secondary_rootlets"],
                      *fiber_components["root_energy_channels"],
                      *fiber_components["heart_feeders"],
                      *fiber_components["crown_veins"],
                      *fiber_components["surface_laths"],
                      *fiber_components["grain_grooves"],
                      *fiber_components["energy_capillaries"]]
    export_root, export_meshes, sockets = build_export(source_objects, export_collection)

    if os.environ.get("TOL_SKIP_PRESENTATION_RENDERS") != "1":
        render_presentation(scene, source_collection)
    component_group_counts = {
        "structural_bark_ribs": len(ribs),
        "ground_root_fibers": len(fiber_components["ground_root_fibers"]),
        "secondary_rootlets": len(fiber_components["secondary_rootlets"]),
        "doorway_root_buttresses": len(doorway_buttresses),
        "root_cambium_webbing": 1,
        "foundation_segments": FOUNDATION_SEGMENT_COUNT,
        "foundation_stairs": FOUNDATION_STAIR_COUNT,
        "root_energy_channels": len(fiber_components["root_energy_channels"]),
        "heart_energy_feeders": len(fiber_components["heart_feeders"]),
        "crown_energy_veins": len(fiber_components["crown_veins"]),
        "surface_bark_laths": len(fiber_components["surface_laths"]),
        "recessed_grain_grooves": len(fiber_components["grain_grooves"]),
        "secondary_energy_capillaries": len(fiber_components["energy_capillaries"]),
        "gold_mechanical_branch_collars": len(gold_branch_collars),
		"heart_tree_socket_recesses": 1,
		"heart_tree_socket_liners": 1,
		"heart_tree_socket_wood_anchors": 8,
		"heart_tree_socket_brass_clamps": 8,
		"heart_tree_socket_brass_bolts": 16,
		"heart_tree_socket_main_gear_rims": 1,
		"heart_tree_socket_forged_gear_teeth": 24,
        "christmas_tier_boughs": len(christmas_paths),
        "christmas_central_leaders": 1,
        "major_sweeping_boughs": len(major_paths),
        "secondary_canopy_boughs": len(secondary_paths),
        "co_dominant_crown_leaders": len(crown_leaders),
        "rising_crown_branchlets": len(crown_branchlets),
        "foliage_clouds": len(cluster_centres),
        "editable_leaf_clusters": int(leaves.get("cluster_count", 0)),
        "individual_leaves": int(leaves.get("leaf_count", 0)),
        "lilac_flower_plumes": int(blossoms.get("plume_count", 0)),
        "approved_gravity_bough_tiers": len(APPROVED_BOUGH_TIER_SPECS),
        "approved_gravity_bough_instances": len(approved_bough_instances),
        "approved_socket_attached_leaf_instances": approved_bough_leaf_instances,
        "superseded_canopy_objects_hidden": superseded_canopy_objects,
    }
    component_manifest = write_component_manifest(
        source_collection, component_group_counts, christmas_tier_profile)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    bpy.ops.object.select_all(action="DESELECT")
    select_recursive(export_root)
    bpy.context.view_layer.objects.active = export_root
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        use_selection=True,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=True,
    )

    manifest = {
        "asset": "simple_trunk_core",
        "version": 6,
        "blueprint": "design/tree_of_life/blueprints/trunk_core_reference_redesign_v2.md",
        "heart_blueprint": "design/tree_of_life/blueprints/heart_crystal_century_canopy_v3.md",
        "source_blend": "assets3D/tree_of_life/trunk_core/source/simple_trunk_core.blend",
        "game_glb": "assets3D/tree_of_life/trunk_core/glb/simple_trunk_core.glb",
        "dimensions_m": {
            "height": HEIGHT,
            "root_diameter": ROOT_SPREAD_RADIUS * 2.0,
            "base_trunk_diameter": BASE_TRUNK_RADIUS * 2.0,
            "neck_diameter": NECK_RADIUS * 2.0,
            "doorway_width": DOOR_WIDTH,
            "doorway_height": DOOR_HEIGHT,
            "heart_center": HEART_CENTER,
            "heart_clear_width": HEART_WIDTH,
            "heart_clear_height": HEART_HEIGHT,
            "heart_recess_depth": HEART_DEPTH,
        },
        "systems": {
            "inner_shells": 1,
            "structural_bark_ribs": RIB_COUNT,
            "primary_energy_veins": VEIN_COUNT,
            "root_manifolds": 1,
            "bough_sockets": SOCKET_COUNT,
            "major_sweeping_boughs": len(major_paths),
            "secondary_canopy_boughs": len(secondary_paths),
            "co_dominant_crown_leaders": len(crown_leaders),
            "rising_crown_branchlets": len(crown_branchlets),
            "christmas_tier_boughs": len(christmas_paths),
            "christmas_central_leaders": 1,
            "editable_ground_root_fibers": len(fiber_components["ground_root_fibers"]),
            "editable_secondary_rootlets": len(fiber_components["secondary_rootlets"]),
			"primary_root_radius_range_m": [0.34, 2.34],
			"secondary_rootlet_radius_range_m": [0.16, 0.72],
			"root_energy_maximum_surface_gap_m": 0.035,
			"root_energy_channels_embedded_in_bark_grooves": True,
            "doorway_root_buttresses": len(doorway_buttresses),
            "continuous_root_cambium_webbing": 1,
            "foundation_segments": FOUNDATION_SEGMENT_COUNT,
            "foundation_stairs": FOUNDATION_STAIR_COUNT,
            "foundation_outer_diameter_m": 41.1,
            "pointed_doorway_arch": True,
            "primary_root_energy_intakes": len(fiber_components["root_energy_channels"]),
            "heart_energy_feeders": len(fiber_components["heart_feeders"]),
            "crown_energy_veins": len(fiber_components["crown_veins"]),
            "editable_surface_bark_laths": len(fiber_components["surface_laths"]),
            "editable_recessed_grain_grooves": len(fiber_components["grain_grooves"]),
            "editable_secondary_energy_capillaries": len(fiber_components["energy_capillaries"]),
            "runtime_trunk_detail_batches": 9,
            "editable_gold_mechanical_branch_collars": len(gold_branch_collars),
            "heart_astrolabe_orbits": 3,
            "heart_frame_rune_sockets": 8,
            "heart_frame_radial_spokes": 8,
            "foliage_clouds": len(cluster_centres),
            "lowest_foliage_tier_m": CHRISTMAS_TIER_SPECS[0][1],
            "highest_foliage_tier_m": CHRISTMAS_TIER_SPECS[-1][1],
            "continuous_root_to_crown_foliage": True,
            "editable_leaf_clusters": int(leaves.get("cluster_count", 0)),
            "individual_leaves": int(leaves.get("leaf_count", 0)),
            "approved_gravity_bough_tiers": len(APPROVED_BOUGH_TIER_SPECS),
            "approved_gravity_bough_instances": len(approved_bough_instances),
            "approved_socket_attached_leaf_instances": approved_bough_leaf_instances,
            "approved_gravity_bough_source": os.path.relpath(
                GRAVITY_BOUGH_BLEND_PATH, PROJECT_ROOT),
            "approved_gravity_bough_maximum_socket_error_m":
                9.830249847454215e-07,
            "superseded_canopy_objects_hidden": superseded_canopy_objects,
            "leaf_mesh_faces_per_leaf": LEAF_FACES_PER_BLADE,
            "leaf_full_length_min_m": leaves["leaf_full_length_range_m"][0],
            "leaf_full_length_max_m": leaves["leaf_full_length_range_m"][1],
            "leaf_full_width_min_m": leaves["leaf_full_width_range_m"][0],
            "leaf_full_width_max_m": leaves["leaf_full_width_range_m"][1],
            "leaf_lower_tier_scale_multiplier": LEAF_LOWER_TIER_SCALE,
            "leaf_middle_tier_scale_multiplier": LEAF_MIDDLE_TIER_SCALE,
            "leaf_crown_tier_scale_multiplier": LEAF_CROWN_TIER_SCALE,
            "leaf_projected_area_multiplier_lower": LEAF_LOWER_TIER_SCALE ** 2,
            "leaf_projected_area_multiplier_crown": LEAF_CROWN_TIER_SCALE ** 2,
            "leaf_solidify_thickness_m": LEAF_SOLIDIFY_THICKNESS_M,
            "lilac_flower_plumes": int(blossoms.get("plume_count", 0)),
        },
        "root_transition": {
            "root_spread_radius_m": ROOT_SPREAD_RADIUS,
            "core_base_radius_m": BASE_TRUNK_RADIUS,
            "radial_overlap_m": 3.0,
            "continuous_buttress_stems": RIB_COUNT,
        },
        "visual_language": "pale_buttressed_living_wood_with_cyan_energy_veins",
        "presentation_visual_language": "century_old_fibered_tree_with_blue_crystal_technology_green_nature_leaves_and_gold_mechanics",
        "editable_component_manifest": "assets3D/tree_of_life/trunk_core/tree_of_life_editable_components.json",
        "editable_component_count": int(component_manifest["component_count"]),
        "blender_renders": [
            "assets3D/tree_of_life/trunk_core/renders/tree_of_life_blender_hero.png",
            "assets3D/tree_of_life/trunk_core/renders/tree_of_life_trunk_detail.png",
            "assets3D/tree_of_life/trunk_core/renders/tree_of_life_canopy_detail.png",
            "assets3D/tree_of_life/trunk_core/renders/tree_of_life_leaf_mesh_detail.png",
            "assets3D/tree_of_life/trunk_core/renders/tree_of_life_root_fiber_detail.png",
            "assets3D/tree_of_life/trunk_core/renders/tree_of_life_trunk_fiber_detail.png",
            "assets3D/tree_of_life/trunk_core/renders/tree_of_life_heart_crystal_detail.png",
            "assets3D/tree_of_life/trunk_core/renders/tree_of_life_blueprint_front.png",
            "assets3D/tree_of_life/trunk_core/renders/tree_of_life_root_plan.png",
            "assets3D/tree_of_life/trunk_core/renders/"
            "tree_of_life_gravity_bough_attachment_detail.png",
            "assets3D/tree_of_life/trunk_core/renders/"
            "tree_of_life_blueprint_foundation_front.png",
        ],
        "wood_materials": [material.name for material in [
            heartwood, warm_bark, sunlit_bark, dark]],
        "game_mesh_nodes": len(export_meshes),
        "game_triangles": triangle_count(export_meshes),
        "longitudinal_energy_uv": True,
        "runtime_booleans": False,
        "runtime_bones": False,
        "web_compatible": True,
    }
    with open(MANIFEST_PATH, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")

    assert len(ribs) == RIB_COUNT
    assert len(veins) == VEIN_COUNT
    assert len(sockets) == SOCKET_COUNT
    assert len(major_paths) == MAJOR_BOUGH_COUNT
    assert len(secondary_paths) == MAJOR_BOUGH_COUNT * SECONDARY_BOUGHS_PER_MAJOR
    assert len(crown_leaders) == CROWN_LEADER_COUNT
    assert len(crown_branchlets) == CROWN_BRANCHLET_COUNT
    assert len(christmas_paths) == CHRISTMAS_TIER_BOUGH_COUNT
    assert len(cluster_centres) == FOLIAGE_CLUSTER_COUNT
    assert int(leaves.get("leaf_count", 0)) >= 1300
    assert int(blossoms.get("plume_count", 0)) >= 300
    assert len(fiber_components["ground_root_fibers"]) == PRIMARY_ROOT_COUNT
    assert len(fiber_components["secondary_rootlets"]) == \
        PRIMARY_ROOT_COUNT * ROOTLETS_PER_PRIMARY
    assert len(fiber_components["root_energy_channels"]) == PRIMARY_ROOT_COUNT
    assert len(fiber_components["heart_feeders"]) == HEART_FEEDER_COUNT
    assert len(fiber_components["crown_veins"]) == CROWN_VEIN_COUNT
    assert len(doorway_buttresses) == 2
    assert root_cambium_webbing.get("natural_ground_transition", False)
    assert len(foundation_components) == FOUNDATION_SEGMENT_COUNT \
        + FOUNDATION_STAIR_COUNT * 2 + 4
    assert len(fiber_components["surface_laths"]) == 28
    assert len(fiber_components["grain_grooves"]) == 20
    assert len(fiber_components["energy_capillaries"]) == 12
    assert len(gold_branch_collars) == MAJOR_BOUGH_COUNT + CHRISTMAS_TIER_BOUGH_COUNT
    assert len(approved_bough_instances) == APPROVED_BOUGH_INSTANCE_COUNT
    assert approved_bough_leaf_instances >= 4000
    assert int(component_manifest["component_count"]) > 1000
    assert all(os.path.isfile(path) for path in (
        HERO_RENDER_PATH, TRUNK_RENDER_PATH, CANOPY_RENDER_PATH, LEAF_RENDER_PATH,
        ROOT_RENDER_PATH, FIBER_RENDER_PATH, HEART_RENDER_PATH,
        BLUEPRINT_FRONT_RENDER_PATH, ROOT_PLAN_RENDER_PATH,
        BRANCH_ATTACHMENT_RENDER_PATH, FOUNDATION_RENDER_PATH))
    assert manifest["game_triangles"] < 60000
    print("SIMPLE_TRUNK_CORE_BUILD: PASS")
    print(f"SIMPLE_TRUNK_CORE_BUILD: blend={BLEND_PATH}")
    print(f"SIMPLE_TRUNK_CORE_BUILD: glb={GLB_PATH}")
    print(f"SIMPLE_TRUNK_CORE_BUILD: triangles={manifest['game_triangles']}")
    print(f"SIMPLE_TRUNK_CORE_BUILD: presentation={len(major_paths)} major boughs, "
          f"{len(secondary_paths)} secondary boughs, {len(crown_leaders)} crown leaders, "
          f"{len(crown_branchlets)} crown branchlets, {len(cluster_centres)} foliage clouds, "
          f"{int(leaves.get('leaf_count', 0))} leaves, "
          f"{len(APPROVED_BOUGH_TIER_SPECS)} approved gravity-bough tiers, "
          f"{len(approved_bough_instances)} trunk-rooted radial bough instances, "
          f"{approved_bough_leaf_instances} socket leaves, "
          f"{int(blossoms.get('plume_count', 0))} lilac plumes")
    print(f"SIMPLE_TRUNK_CORE_BUILD: editable={component_manifest['component_count']} objects, "
          f"{len(christmas_paths)} Christmas-tier boughs, "
          f"{sum(len(group) for group in fiber_components.values())} root/fiber/vein details")
    print(f"SIMPLE_TRUNK_CORE_BUILD: renders={RENDER_DIR}")


if __name__ == "__main__":
    main()
