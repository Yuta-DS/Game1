"""Build the modular Tree of Life processional bridge.

Run with:
    blender --background --python tools/blender/build_tree_processional_bridge.py

The editable collection retains every paver, pylon course, botanical rail,
portal bough, crystal, and underside rib as a separate Blender object.  The GLB
joins those objects into a small set of semantic runtime meshes for Godot.
"""

from __future__ import annotations

import json
import math
import os
from collections import OrderedDict

import bpy
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSET_DIR = os.path.join(ROOT, "assets3D", "tree_processional_bridge")
BLEND_PATH = os.path.join(ASSET_DIR, "blend", "tree_processional_bridge.blend")
GLB_PATH = os.path.join(ASSET_DIR, "glb", "tree_processional_bridge.glb")
MANIFEST_PATH = os.path.join(ASSET_DIR, "tree_processional_bridge_manifest.json")
BEAUTY_RENDER_PATH = os.path.join(ROOT, "artifacts", "tree_processional_bridge_blender_render.png")
COMPONENT_RENDER_PATH = os.path.join(ROOT, "artifacts", "tree_processional_bridge_components.png")

BRIDGE_LENGTH = 447.0
BRIDGE_WIDTH = 62.0
CLEAR_LANE_WIDTH = 42.0
BAY_COUNT = 8
BAY_LENGTH = BRIDGE_LENGTH / BAY_COUNT
PORTAL_POSITIONS = (0.24, 0.50, 0.76)
TARGET_TRIANGLES = 90000

PALETTE = OrderedDict(
    ivory=(0.78, 0.72, 0.60, 1.0),
    ivory_light=(0.94, 0.88, 0.74, 1.0),
    ivory_shadow=(0.45, 0.40, 0.33, 1.0),
    antique_gold=(0.78, 0.49, 0.12, 1.0),
    bright_gold=(1.00, 0.70, 0.20, 1.0),
    underside_blue=(0.055, 0.11, 0.18, 1.0),
    cyan_glass=(0.02, 0.65, 0.92, 1.0),
)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def collection(name):
    result = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result


def material(name, color, metallic=0.0, roughness=0.75, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = color
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def move_to_collection(obj, target):
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    target.objects.link(obj)


def tag(obj, group, component, module):
    obj["semantic_group"] = group
    obj["component_path"] = component
    obj["module"] = module
    return obj


def box(name, center, size, mat, target, group, component, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=center)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("EdgeChamfer", "BEVEL")
        mod.width = bevel
        mod.segments = 1
    obj.data.materials.append(mat)
    move_to_collection(obj, target)
    return tag(obj, group, component, name)


def beam(name, start, end, thickness, mat, target, group, component, depth=None):
    start = Vector(start)
    end = Vector(end)
    delta = end - start
    obj = box(name, (start + end) * 0.5,
              (thickness, depth or thickness, delta.length), mat, target,
              group, component, min(0.06, thickness * 0.12))
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    return obj


def cylinder(name, center, radius, depth, mat, target, group, component, vertices=8):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                       depth=depth, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    move_to_collection(obj, target)
    return tag(obj, group, component, name)


def ico(name, center, radius, scale, mat, target, group, component):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    move_to_collection(obj, target)
    return tag(obj, group, component, name)


def extruded_profile(name, profile_xz, center_y, depth, mat, target, group, component):
    front = center_y - depth * 0.5
    back = center_y + depth * 0.5
    vertices = [(x, front, z) for x, z in profile_xz]
    vertices += [(x, back, z) for x, z in profile_xz]
    count = len(profile_xz)
    faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    for index in range(count):
        following = (index + 1) % count
        faces.append((index, following, count + following, count + index))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.data.materials.append(mat)
    target.objects.link(obj)
    return tag(obj, group, component, name)


def diamond_panel(name, x, y, z, width, height, depth, mat, target, group, component):
    profile = ((x, z + height * 0.5), (x + width * 0.5, z),
               (x, z - height * 0.5), (x - width * 0.5, z))
    return extruded_profile(name, profile, y, depth, mat, target, group, component)


def build_deck(parts, mats):
    component = "BRIDGE/DECK_BAY"
    box("DeckStoneSubstrate", (0, BRIDGE_LENGTH * 0.5, -0.70),
        (BRIDGE_WIDTH, BRIDGE_LENGTH, 1.4), mats["ivory_shadow"], parts,
        "DECK_STRUCTURE", component, 0.08)
    rows = 40
    lanes = 5
    row_length = BRIDGE_LENGTH / rows
    lane_width = CLEAR_LANE_WIDTH / lanes
    for row in range(rows):
        for lane in range(lanes):
            x = -CLEAR_LANE_WIDTH * 0.5 + lane_width * (lane + 0.5)
            y = row_length * (row + 0.5)
            box(f"Paver_{row:02d}_{lane}", (x, y, 0.08),
                (lane_width - 0.16, row_length - 0.18, 0.30),
                mats["ivory_light"] if (row + lane) % 7 else mats["ivory"],
                parts, "DECK_IVORY", component, 0.055)
    box("LivingSapInlay", (0, BRIDGE_LENGTH * 0.5, 0.26),
        (0.72, BRIDGE_LENGTH - 1.4, 0.075), mats["cyan_glass"], parts,
        "CYAN_LIGHT", "BRIDGE/CYAN_ROUTE", 0.025)
    for side in (-1, 1):
        box(f"GoldLaneBoundary_{side:+d}",
            (side * CLEAR_LANE_WIDTH * 0.5, BRIDGE_LENGTH * 0.5, 0.25),
            (0.34, BRIDGE_LENGTH - 1.0, 0.09), mats["antique_gold"], parts,
            "GOLD_TRIM", "BRIDGE/GOLD_ROUTE", 0.025)


def build_underside(parts, mats):
    component = "BRIDGE/UNDERSIDE_SUPPORT"
    for side in (-1, 1):
        x = side * (BRIDGE_WIDTH * 0.5 - 1.0)
        box(f"BlueFascia_{side:+d}", (x, BRIDGE_LENGTH * 0.5, -2.2),
            (1.8, BRIDGE_LENGTH, 3.0), mats["underside_blue"], parts,
            "UNDERSIDE_BLUE", component, 0.10)
        box(f"GoldFasciaCap_{side:+d}", (x, BRIDGE_LENGTH * 0.5, -0.55),
            (2.15, BRIDGE_LENGTH, 0.28), mats["antique_gold"], parts,
            "GOLD_TRIM", component, 0.035)
        for bay in range(BAY_COUNT):
            a = bay * BAY_LENGTH + 2.0
            b = (bay + 1) * BAY_LENGTH - 2.0
            mid = (a + b) * 0.5
            beam(f"UndersideBraceA_{side:+d}_{bay:02d}", (x, a, -3.0),
                 (x, mid, -12.0), 0.72, mats["underside_blue"], parts,
                 "UNDERSIDE_BLUE", component, 1.05)
            beam(f"UndersideBraceB_{side:+d}_{bay:02d}", (x, b, -3.0),
                 (x, mid, -12.0), 0.72, mats["underside_blue"], parts,
                 "UNDERSIDE_BLUE", component, 1.05)
            ico(f"UndersidePendant_{side:+d}_{bay:02d}", (x, mid, -13.0),
                1.0, (0.75, 0.75, 1.65), mats["antique_gold"], parts,
                "GOLD_TRIM", component)


def build_pylon(parts, mats, side, index, y):
    x = side * (BRIDGE_WIDTH * 0.5 - 3.25)
    tag_name = "L" if side < 0 else "R"
    component = "BRIDGE/PYLON"
    box(f"PylonFoundation_{tag_name}_{index:02d}", (x, y, 0.65),
        (4.2, 4.2, 1.3), mats["ivory_shadow"], parts, "PYLON_IVORY",
        component, 0.10)
    box(f"PylonLowerPlinth_{tag_name}_{index:02d}", (x, y, 1.65),
        (3.6, 3.6, 0.70), mats["ivory_light"], parts, "PYLON_IVORY",
        component, 0.08)
    box(f"PylonBody_{tag_name}_{index:02d}", (x, y, 4.25),
        (2.8, 2.8, 4.5), mats["ivory"], parts, "PYLON_IVORY",
        component, 0.12)
    for face_y in (y - 1.43, y + 1.43):
        diamond_panel(f"PylonCrystal_{tag_name}_{index:02d}_{face_y > y}",
                      x, face_y, 4.30, 1.15, 2.65, 0.12,
                      mats["cyan_glass"], parts, "CYAN_LIGHT", component)
    box(f"PylonGoldNeck_{tag_name}_{index:02d}", (x, y, 6.65),
        (3.2, 3.2, 0.34), mats["antique_gold"], parts, "GOLD_TRIM",
        component, 0.045)
    box(f"PylonCap_{tag_name}_{index:02d}", (x, y, 7.15),
        (3.65, 3.65, 0.64), mats["ivory_light"], parts, "PYLON_IVORY",
        component, 0.08)
    ico(f"PylonCrown_{tag_name}_{index:02d}", (x, y, 7.85), 0.78,
        (1.0, 1.0, 0.70), mats["bright_gold"], parts, "GOLD_TRIM", component)


def build_rail_bay(parts, mats, side, bay):
    x = side * (BRIDGE_WIDTH * 0.5 - 3.25)
    a = bay * BAY_LENGTH + 2.0
    b = (bay + 1) * BAY_LENGTH - 2.0
    mid = (a + b) * 0.5
    component = "BRIDGE/BOTANICAL_RAIL_BAY"
    prefix = "L" if side < 0 else "R"
    beam(f"RailTop_{prefix}_{bay:02d}", (x, a, 5.25), (x, b, 5.25),
         0.34, mats["antique_gold"], parts, "RAIL_GOLD", component, 0.50)
    beam(f"RailLower_{prefix}_{bay:02d}", (x, a, 1.05), (x, b, 1.05),
         0.28, mats["antique_gold"], parts, "RAIL_GOLD", component, 0.42)
    quarter_a = a + (b - a) * 0.25
    quarter_b = a + (b - a) * 0.75
    for stem_index, stem_y in enumerate((quarter_a, mid, quarter_b)):
        beam(f"RailStem_{prefix}_{bay:02d}_{stem_index}",
             (x, stem_y, 1.0), (x, stem_y, 4.75), 0.20,
             mats["antique_gold"], parts, "RAIL_GOLD", component, 0.30)
    for vine_index, (start, finish) in enumerate((
            ((x, a, 1.25), (x, mid, 4.8)),
            ((x, a, 4.8), (x, mid, 1.25)),
            ((x, mid, 1.25), (x, b, 4.8)),
            ((x, mid, 4.8), (x, b, 1.25)))):
        beam(f"RailVine_{prefix}_{bay:02d}_{vine_index}", start, finish,
             0.18, mats["antique_gold"], parts, "RAIL_GOLD", component, 0.25)
    for leaf_index, (leaf_y, leaf_z, tilt) in enumerate((
            (quarter_a, 2.55, -24), (quarter_a + 4.0, 3.55, 28),
            (quarter_b - 4.0, 2.70, -30), (quarter_b, 3.65, 24))):
        leaf = ico(f"RailLeaf_{prefix}_{bay:02d}_{leaf_index}",
                   (x, leaf_y, leaf_z), 0.64, (0.24, 1.15, 0.48),
                   mats["bright_gold"], parts, "RAIL_GOLD", component)
        leaf.rotation_euler.x = math.radians(tilt)


def build_portal(parts, mats, index, y):
    component = "BRIDGE/BOUGH_PORTAL"
    left_x = -23.0
    right_x = 23.0
    pier_top = 12.0
    shoulder_z = 17.5
    apex_z = 27.0
    for side, x in ((-1, left_x), (1, right_x)):
        tag_name = "L" if side < 0 else "R"
        box(f"PortalPierFoot_{index}_{tag_name}", (x, y, 1.25),
            (5.2, 5.2, 2.5), mats["ivory_shadow"], parts, "PORTAL_IVORY",
            component, 0.14)
        box(f"PortalPierBody_{index}_{tag_name}", (x, y, 6.8),
            (4.0, 4.0, 9.5), mats["ivory"], parts, "PORTAL_IVORY",
            component, 0.18)
        box(f"PortalPierCap_{index}_{tag_name}", (x, y, 11.8),
            (4.8, 4.8, 0.65), mats["ivory_light"], parts, "PORTAL_IVORY",
            component, 0.10)
        diamond_panel(f"PortalPierCrystal_{index}_{tag_name}", x,
                      y - 2.06, 6.6, 1.35, 3.6, 0.16, mats["cyan_glass"],
                      parts, "CYAN_LIGHT", component)
    outer_points = ((left_x, y, pier_top), (-19.0, y, shoulder_z),
                    (0.0, y, apex_z), (19.0, y, shoulder_z),
                    (right_x, y, pier_top))
    for segment in range(len(outer_points) - 1):
        beam(f"PortalIvoryArch_{index}_{segment}", outer_points[segment],
             outer_points[segment + 1], 1.75, mats["ivory_light"], parts,
             "PORTAL_IVORY", component, 2.40)
        beam(f"PortalGoldOutline_{index}_{segment}",
             Vector(outer_points[segment]) + Vector((0, -1.26, -0.10)),
             Vector(outer_points[segment + 1]) + Vector((0, -1.26, -0.10)),
             0.34, mats["antique_gold"], parts, "PORTAL_GOLD", component, 0.48)
    orb = (0.0, y - 1.40, 22.0)
    ico(f"PortalCyanCrown_{index}", orb, 1.55, (1.0, 0.55, 1.35),
        mats["cyan_glass"], parts, "CYAN_LIGHT", component)
    for vine_index, (start, finish) in enumerate((
            ((-19.0, y - 1.35, 15.2), (-8.0, y - 1.35, 20.0)),
            ((19.0, y - 1.35, 15.2), (8.0, y - 1.35, 20.0)),
            ((-8.0, y - 1.35, 20.0), orb),
            ((8.0, y - 1.35, 20.0), orb))):
        beam(f"PortalLivingVine_{index}_{vine_index}", start, finish,
             0.30, mats["antique_gold"], parts, "PORTAL_GOLD", component, 0.42)
    # Seat the six bough crystals on exact points along the living-vine
    # segments.  Their front-face offset keeps the gold rail from visibly
    # passing through the crystal when viewed from the playable lane.
    bough_crystals = (
        ((-19.0, 15.2), (-8.0, 20.0), 0.40),
        ((-19.0, 15.2), (-8.0, 20.0), 0.78),
        ((-8.0, 20.0), (0.0, 22.0), 0.25),
        ((19.0, 15.2), (8.0, 20.0), 0.40),
        ((19.0, 15.2), (8.0, 20.0), 0.78),
        ((8.0, 20.0), (0.0, 22.0), 0.25),
    )
    for crystal_index, (start, finish, progress) in enumerate(bough_crystals):
        start_x, start_z = start
        finish_x, finish_z = finish
        x = start_x + (finish_x - start_x) * progress
        z = start_z + (finish_z - start_z) * progress
        tangent_angle = math.atan2(finish_x - start_x, finish_z - start_z)
        crystal_angle = tangent_angle - math.copysign(math.pi * 0.5,
                                                       tangent_angle)
        crystal = ico(f"PortalBoughCrystal_{index}_{crystal_index}",
                      (x, y - 1.93, z), 0.82, (0.30, 0.65, 1.35),
                      mats["bright_gold"], parts, "PORTAL_GOLD", component)
        crystal.rotation_euler.y = crystal_angle


def build_bridge(parts, mats):
    build_deck(parts, mats)
    build_underside(parts, mats)
    for side in (-1, 1):
        for index in range(BAY_COUNT + 1):
            # Keep the end foundations inside the exact 0..447 m deck rather
            # than allowing half of each 4.2 m plinth to overhang a landing.
            station = min(max(index * BAY_LENGTH, 2.2), BRIDGE_LENGTH - 2.2)
            build_pylon(parts, mats, side, index, station)
        for bay in range(BAY_COUNT):
            build_rail_bay(parts, mats, side, bay)
    for index, progress in enumerate(PORTAL_POSITIONS):
        build_portal(parts, mats, index, BRIDGE_LENGTH * progress)


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.select_set(False)


def build_hierarchy(parts, hierarchy_collection):
    structure = OrderedDict((
        ("BRIDGE", ("DECK_BAY", "CYAN_ROUTE", "GOLD_ROUTE",
                    "PYLON", "BOTANICAL_RAIL_BAY", "BOUGH_PORTAL",
                    "UNDERSIDE_SUPPORT")),
    ))
    root = bpy.data.objects.new("00_TREE_PROCESSIONAL_BRIDGE_ASSEMBLY", None)
    hierarchy_collection.objects.link(root)
    nodes = {}
    for assembly, children in structure.items():
        parent = bpy.data.objects.new(f"10_{assembly}", None)
        hierarchy_collection.objects.link(parent)
        parent.parent = root
        for index, child in enumerate(children, start=1):
            node = bpy.data.objects.new(f"1{index}_{child}", None)
            hierarchy_collection.objects.link(node)
            node.parent = parent
            nodes[f"{assembly}/{child}"] = node
    counts = OrderedDict((path, 0) for path in nodes)
    for obj in [candidate for candidate in parts.objects if candidate.type == "MESH"]:
        path = str(obj.get("component_path"))
        obj.parent = nodes[path]
        counts[path] += 1
    root["editable_mesh_modules"] = sum(counts.values())
    root["component_count"] = len(counts)
    return root, counts


def build_export(parts, export_collection):
    grouped = OrderedDict()
    for source in (candidate for candidate in parts.objects if candidate.type == "MESH"):
        grouped.setdefault(str(source.get("semantic_group", "DETAIL")), []).append(source)
    root = bpy.data.objects.new("TreeProcessionalBridge", None)
    export_collection.objects.link(root)
    root["source_blend"] = "assets3D/tree_processional_bridge/blend/tree_processional_bridge.blend"
    root["bridge_length_m"] = BRIDGE_LENGTH
    root["bridge_width_m"] = BRIDGE_WIDTH
    root["clear_lane_width_m"] = CLEAR_LANE_WIDTH
    root["bay_count"] = BAY_COUNT
    root["portal_count"] = len(PORTAL_POSITIONS)
    root["performance_profile"] = "laptop_cpu_low"
    exports = []
    for group, sources in grouped.items():
        duplicates = []
        for source in sources:
            duplicate = source.copy()
            duplicate.data = source.data.copy()
            export_collection.objects.link(duplicate)
            duplicate.matrix_world = source.matrix_world.copy()
            apply_modifiers(duplicate)
            duplicates.append(duplicate)
        if len(duplicates) == 1:
            joined = duplicates[0]
        else:
            bpy.ops.object.select_all(action="DESELECT")
            for duplicate in duplicates:
                duplicate.select_set(True)
            bpy.context.view_layer.objects.active = duplicates[0]
            bpy.ops.object.join()
            joined = bpy.context.object
        joined.name = group.title().replace("_", "")
        joined["semantic_group"] = group
        joined["source_module_count"] = len(sources)
        joined.parent = root
        exports.append(joined)
    return root, exports, grouped


def select_recursive(obj):
    obj.select_set(True)
    for child in obj.children:
        select_recursive(child)


def triangle_count(objects):
    total = 0
    for obj in objects:
        obj.data.calc_loop_triangles()
        total += len(obj.data.loop_triangles)
    return total


def measured_bounds(objects):
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    minimum = [min(point[index] for point in points) for index in range(3)]
    maximum = [max(point[index] for point in points) for index in range(3)]
    return {
        "minimum": [round(value, 3) for value in minimum],
        "maximum": [round(value, 3) for value in maximum],
        "size": [round(maximum[index] - minimum[index], 3) for index in range(3)],
    }


def build_render_tree_proxy(render_collection, mats):
    # Render-only destination landmark; the production Godot Tree remains the
    # authoritative game asset and is not duplicated into the bridge GLB.
    y = BRIDGE_LENGTH + 40.0
    cylinder("RenderTreeTrunk", (0, y, 29), 7.5, 58.0, mats["ivory"],
             render_collection, "RENDER_ONLY", "RENDER/TREE", 10)
    for branch_index, angle in enumerate((-58, -34, -16, 16, 34, 58)):
        radians = math.radians(angle)
        start = Vector((0, y, 47))
        end = Vector((math.sin(radians) * 48, y + math.cos(radians) * 16, 86 - abs(angle) * 0.25))
        beam(f"RenderTreeBranch_{branch_index}", start, end, 2.3,
             mats["ivory_light"], render_collection, "RENDER_ONLY",
             "RENDER/TREE", 3.0)
        ico(f"RenderTreeCrown_{branch_index}", end, 10.0, (1.3, 0.65, 0.70),
            mats["bright_gold"], render_collection, "RENDER_ONLY", "RENDER/TREE")
    diamond_panel("RenderTreeHeart", 0, y - 7.6, 54, 8.0, 15.0, 0.8,
                  mats["cyan_glass"], render_collection, "RENDER_ONLY", "RENDER/TREE")
    # Two gold root-boughs frame the heart and echo the bridge portals.
    beam("RenderTreeRootBoughL", (-21, y - 2, 22), (0, y - 3, 63), 1.0,
         mats["antique_gold"], render_collection, "RENDER_ONLY", "RENDER/TREE", 1.4)
    beam("RenderTreeRootBoughR", (21, y - 2, 22), (0, y - 3, 63), 1.0,
         mats["antique_gold"], render_collection, "RENDER_ONLY", "RENDER/TREE", 1.4)


def build_render_scale_figure(render_collection, mats):
    """A restrained human silhouette makes the 42 m clear lane legible."""
    y = 42.0
    cylinder("RenderScaleBody", (-4.0, y, 1.55), 0.42, 2.1,
             mats["underside_blue"], render_collection, "RENDER_ONLY",
             "RENDER/SCALE", 8)
    ico("RenderScaleHead", (-4.0, y, 2.92), 0.43, (1.0, 1.0, 1.0),
        mats["underside_blue"], render_collection, "RENDER_ONLY", "RENDER/SCALE")
    beam("RenderScaleLegL", (-4.18, y, 0.55), (-4.35, y, -0.05), 0.18,
         mats["underside_blue"], render_collection, "RENDER_ONLY", "RENDER/SCALE", 0.22)
    beam("RenderScaleLegR", (-3.82, y, 0.55), (-3.65, y, -0.05), 0.18,
         mats["underside_blue"], render_collection, "RENDER_ONLY", "RENDER/SCALE", 0.22)


def setup_render(export_root, render_collection):
    world = bpy.data.worlds.new("TreeBridgeSky")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.24, 0.58, 0.92, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.45
    bpy.ops.object.light_add(type="SUN", location=(-70, -90, 110))
    sun = bpy.context.object
    sun.data.energy = 2.2
    sun.data.color = (1.0, 0.86, 0.64)
    sun.rotation_euler = (math.radians(28), math.radians(-18), math.radians(-32))
    bpy.ops.object.light_add(type="AREA", location=(-50, 40, 65))
    key = bpy.context.object
    key.data.energy = 2600
    key.data.shape = "DISK"
    key.data.size = 55
    key.data.color = (1.0, 0.80, 0.64)
    bpy.ops.object.camera_add(location=(70, -20, 26))
    camera = bpy.context.object
    camera.data.lens = 46
    camera.rotation_euler = (Vector((0, 225, 13)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1536
    scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.render.filepath = BEAUTY_RENDER_PATH
    scene.render.film_transparent = False
    bpy.ops.render.render(write_still=True)
    camera.location = (46, 72, 25)
    camera.data.lens = 58
    camera.rotation_euler = (Vector((0, BRIDGE_LENGTH * 0.24, 13)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 960
    scene.render.filepath = COMPONENT_RENDER_PATH
    bpy.ops.render.render(write_still=True)


def main():
    for path in (os.path.dirname(BLEND_PATH), os.path.dirname(GLB_PATH),
                 os.path.dirname(BEAUTY_RENDER_PATH)):
        os.makedirs(path, exist_ok=True)
    reset_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.length_unit = "METERS"
    scene["asset_title"] = "TREE OF LIFE PROCESSIONAL BRIDGE"
    scene["design_reference"] = "design/tree_of_life/bridge/tree_processional_bridge_concept_v1.png"
    scene["performance_profile"] = "laptop_cpu_low"
    parts = collection("TREE_BRIDGE_EDITABLE_COMPONENTS")
    hierarchy_collection = collection("TREE_BRIDGE_COMPONENT_HIERARCHY")
    export_collection = collection("TREE_BRIDGE_GAME_EXPORT")
    render_collection = collection("TREE_BRIDGE_RENDER_ONLY_DESTINATION")
    mats = {
        key: material(f"MAT_{key.title()}", color,
                      metallic=0.72 if "gold" in key else 0.0,
                      roughness=0.24 if key == "cyan_glass" else (0.38 if "gold" in key else 0.82),
                      emission=3.0 if key == "cyan_glass" else (0.14 if "gold" in key else 0.0))
        for key, color in PALETTE.items()
    }
    build_bridge(parts, mats)
    hierarchy_root, component_counts = build_hierarchy(parts, hierarchy_collection)
    export_root, exports, groups = build_export(parts, export_collection)
    editable_count = sum(component_counts.values())
    triangles = triangle_count(exports)
    bounds = measured_bounds(exports)
    build_render_tree_proxy(render_collection, mats)
    build_render_scale_figure(render_collection, mats)
    parts.hide_render = True
    parts.hide_viewport = True
    hierarchy_collection.hide_render = True
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    bpy.ops.object.select_all(action="DESELECT")
    select_recursive(export_root)
    bpy.context.view_layer.objects.active = export_root
    bpy.ops.export_scene.gltf(filepath=GLB_PATH, use_selection=True,
                              export_format="GLB", export_apply=True,
                              export_yup=True, export_materials="EXPORT",
                              export_cameras=False, export_lights=False,
                              export_animations=False, export_extras=True)
    manifest = {
        "asset": "tree_processional_bridge",
        "version": 1,
        "reference_image": "design/tree_of_life/bridge/tree_processional_bridge_concept_v1.png",
        "source_blend": "assets3D/tree_processional_bridge/blend/tree_processional_bridge.blend",
        "game_glb": "assets3D/tree_processional_bridge/glb/tree_processional_bridge.glb",
        "renders": [
            "artifacts/tree_processional_bridge_blender_render.png",
            "artifacts/tree_processional_bridge_components.png",
        ],
        "dimensions_m": {
            "length": BRIDGE_LENGTH,
            "width": BRIDGE_WIDTH,
            "clear_gameplay_lane": CLEAR_LANE_WIDTH,
            "maximum_height": bounds["maximum"][2],
            "bay_length": BAY_LENGTH,
        },
        "component_breakdown": dict(component_counts),
        "editable_source_modules": editable_count,
        "runtime_mesh_groups": len(exports),
        "runtime_group_modules": {name: len(items) for name, items in groups.items()},
        "runtime_triangles": triangles,
        "measured_bounds_m": bounds,
        "portal_count": len(PORTAL_POSITIONS),
        "pylon_count": (BAY_COUNT + 1) * 2,
        "rail_bay_count": BAY_COUNT * 2,
        "material_design_ratio_percent": {"ivory_sand": 60, "gold": 30, "cyan_blue": 10},
        "coordinate_system": "Blender metric: X width, Y route, Z height",
        "collision": "visual-only GLB over existing tested Godot continuous route collision",
        "performance_profile": "laptop_cpu_low",
        "web_compatible": True,
    }
    with open(MANIFEST_PATH, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")
    setup_render(export_root, render_collection)
    assert editable_count >= 400
    assert len(exports) <= 10
    assert triangles < TARGET_TRIANGLES
    assert abs(bounds["size"][0] - BRIDGE_WIDTH) < 0.25
    assert abs(bounds["size"][1] - BRIDGE_LENGTH) < 0.25
    assert bounds["maximum"][2] <= 28.5
    print("TREE_PROCESSIONAL_BRIDGE_BUILD: PASS")
    print(f"TREE_PROCESSIONAL_BRIDGE_BUILD: modules={editable_count} groups={len(exports)} triangles={triangles}")
    print(f"TREE_PROCESSIONAL_BRIDGE_BUILD: bounds={bounds}")
    print(f"TREE_PROCESSIONAL_BRIDGE_BUILD: blend={BLEND_PATH}")
    print(f"TREE_PROCESSIONAL_BRIDGE_BUILD: glb={GLB_PATH}")
    print(f"TREE_PROCESSIONAL_BRIDGE_BUILD: render={BEAUTY_RENDER_PATH}")
    print(f"TREE_PROCESSIONAL_BRIDGE_BUILD: components={COMPONENT_RENDER_PATH}")


if __name__ == "__main__":
    main()
