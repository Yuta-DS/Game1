"""Build the reference-faithful Castle-to-Galaxy bridge and gate.

Run with:
    blender --background --python tools/blender/build_castle_galaxy_bridge_gate.py

The .blend retains every masonry, metalwork, lantern, and trim module as an
independent object.  The GLB joins those modules into semantic systems so the
same detailed asset remains practical in the Godot Web build.
"""

from __future__ import annotations

import json
import math
import os
import sys
from collections import OrderedDict

import bpy
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSET_DIR = os.path.join(ROOT, "assets3D", "castle_galaxy_bridge")
BLEND_PATH = os.path.join(ASSET_DIR, "blend", "castle_galaxy_bridge_gate.blend")
GLB_PATH = os.path.join(ASSET_DIR, "glb", "castle_galaxy_bridge_gate.glb")
MANIFEST_PATH = os.path.join(ASSET_DIR, "castle_galaxy_bridge_gate_manifest.json")
RENDER_PATH = os.path.join(ROOT, "artifacts", "castle_galaxy_bridge_gate.png")
GATE_CLOSEUP_RENDER_PATH = os.path.join(
    ROOT, "artifacts", "castle_galaxy_front_gate_closeup.png")

BRIDGE_LENGTH = 170.0
BRIDGE_WIDTH = 16.0
GATE_Y = 163.0
GATE_WIDTH = 42.0
GATE_HEIGHT = 52.0
PORTAL_WIDTH = 14.8
PORTAL_SHOULDER = 19.0
PORTAL_APEX = 34.0
PERFORMANCE_PROFILE = "laptop_cpu_low"
TARGET_TRIANGLE_BUDGET = 130000

PALETTE = OrderedDict(
    # Reference hierarchy: warm skin/sand ivory mass, refined gold framework,
    # then concentrated midnight/cyan magical accents.
    limestone=(0.78, 0.65, 0.46, 1.0),
    limestone_light=(0.96, 0.86, 0.66, 1.0),
    limestone_shadow=(0.55, 0.42, 0.26, 1.0),
    charcoal_iron=(0.075, 0.095, 0.12, 1.0),
    aged_bronze=(1.00, 0.76, 0.20, 1.0),
    gold_structure=(0.95, 0.62, 0.08, 1.0),
    slate_blue=(0.035, 0.12, 0.23, 1.0),
    blue_structure=(0.025, 0.17, 0.31, 1.0),
    cyan_glass=(0.01, 0.42, 0.82, 1.0),
)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def collection(name):
    result = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result


def material(name, color, metallic=0.0, roughness=0.8, emission=0.0):
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


def tag(obj, group, module):
    obj["semantic_group"] = group
    obj["module"] = module
    return obj


def assign_component(obj, component_path):
    """Expose a stable, two-level assembly path on every editable module."""
    obj["component_path"] = component_path
    return obj


def box(name, center, size, mat, target, group, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=center)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("EdgeChamfer", "BEVEL")
        modifier.width = bevel
        # A single chamfer catches light without doubling every repeated edge.
        modifier.segments = 1
    obj.data.materials.append(mat)
    move_to_collection(obj, target)
    return tag(obj, group, name)


def extruded_profile(name, profile_xz, center_y, depth, mat, target, group):
    """Create a clean front/back architectural silhouette from an X/Z profile."""
    front_y = center_y - depth * 0.5
    back_y = center_y + depth * 0.5
    vertices = [(x, front_y, z) for x, z in profile_xz]
    vertices += [(x, back_y, z) for x, z in profile_xz]
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
    return tag(obj, group, name)


def tube_polyline(name, points, radius, mat, target, group, cyclic=False):
    """Build one continuous low-poly trim tube so corners share real geometry."""
    curve_data = bpy.data.curves.new(f"{name}Curve", "CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = 1
    curve_data.resolution_v = 0
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = 0
    curve_data.use_fill_caps = True
    spline = curve_data.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, coordinate in zip(spline.points, points):
        point.co = (*coordinate, 1.0)
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve_data)
    curve_data.materials.append(mat)
    target.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.object
    obj.name = name
    return tag(obj, group, name)


def leaf_plate(name, start_xz, end_xz, width, center_y, depth, mat, target, group):
    """Create a pointed botanical plate with a broad middle and narrow ends."""
    start = Vector(start_xz)
    end = Vector(end_xz)
    direction = (end - start).normalized()
    perpendicular = Vector((-direction.y, direction.x))
    quarter = start.lerp(end, 0.28)
    shoulder = start.lerp(end, 0.62)
    profile = (
        tuple(start),
        tuple(quarter + perpendicular * width * 0.34),
        tuple(shoulder + perpendicular * width * 0.5),
        tuple(end),
        tuple(shoulder - perpendicular * width * 0.5),
        tuple(quarter - perpendicular * width * 0.34),
    )
    return extruded_profile(name, profile, center_y, depth, mat, target, group)


def cylinder(name, center, radius, depth, mat, target, group, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    move_to_collection(obj, target)
    return tag(obj, group, name)


def cone(name, center, radius, depth, mat, target, group, vertices=8):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=0.0,
                                   depth=depth, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    move_to_collection(obj, target)
    return tag(obj, group, name)


def frustum(name, center, lower_radius, upper_radius, depth, mat, target, group,
            vertices=8):
    """Create a faceted roof stage with a deliberate shoulder, not a raw cone."""
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=lower_radius,
                                   radius2=upper_radius, depth=depth,
                                   location=center)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    move_to_collection(obj, target)
    return tag(obj, group, name)


def sphere(name, center, radius, mat, target, group):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    move_to_collection(obj, target)
    return tag(obj, group, name)


def beam(name, start, end, thickness, mat, target, group, depth=None):
    start, end = Vector(start), Vector(end)
    delta = end - start
    obj = box(name, (start + end) * 0.5,
              (thickness, depth or thickness, delta.length), mat, target, group, min(thickness * 0.12, 0.04))
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    return obj


def build_deck(parts, mats):
    # Three lanes and twenty-six bays retain readable paving at player height
    # while removing tiny long-distance seams on CPU-limited laptops.
    deck_rows = 26
    deck_lanes = 3
    bay = BRIDGE_LENGTH / deck_rows
    lane = 15.2 / deck_lanes
    for row in range(deck_rows):
        for col in range(deck_lanes):
            x = -7.6 + lane * (col + 0.5)
            y = bay * (row + 0.5)
            stagger = 0.20 if (row + col) % 2 else 0.0
            box(f"Paver_{row:02d}_{col}", (x, y + stagger, 0.12),
                (lane - 0.10, bay - 0.12, 0.24),
                mats["limestone_light"] if (row + col) % 5 else mats["limestone"],
                parts, "PAVING", 0.035)
    box("DeckStoneSubstrate", (0, BRIDGE_LENGTH / 2, -0.45),
        (16.0, BRIDGE_LENGTH, 0.9), mats["gold_structure"], parts, "DECK_STRUCTURE")
    box("CyanRouteInlay", (0, BRIDGE_LENGTH / 2, 0.265),
        (0.16, BRIDGE_LENGTH - 2.0, 0.035), mats["cyan_glass"], parts, "CYAN_LIGHT")
    for side in (-1, 1):
        box(f"BronzeEdgeInlay_{side:+d}", (side * 6.9, BRIDGE_LENGTH / 2, 0.27),
            (0.10, BRIDGE_LENGTH - 1.0, 0.04), mats["aged_bronze"], parts, "BRONZE_TRIM")


def build_fascia(parts, mats):
    course_h = 0.72
    fascia_modules = 48
    brick_len = BRIDGE_LENGTH / fascia_modules
    for side in (-1, 1):
        x = side * 7.82
        for course in range(4):
            count = fascia_modules
            for index in range(count):
                y = (index + 0.5) * BRIDGE_LENGTH / count
                y += (BRIDGE_LENGTH / count * 0.5) if course % 2 else 0.0
                if y >= BRIDGE_LENGTH:
                    continue
                box(f"Fascia_{side:+d}_{course}_{index:02d}",
                    (x, y, -0.78 - course * course_h),
                    (0.55, brick_len - 0.08, course_h - 0.08),
                    mats["limestone"] if (course + index) % 4 else mats["gold_structure"],
                    parts, "FASCIA_MASONRY", 0.035)
        box(f"FasciaCornice_{side:+d}", (x, BRIDGE_LENGTH / 2, 0.03),
            (0.82, BRIDGE_LENGTH, 0.34), mats["limestone_light"], parts, "DECK_STRUCTURE", 0.05)
        box(f"FasciaLowerBand_{side:+d}", (x, BRIDGE_LENGTH / 2, -3.75),
            (0.72, BRIDGE_LENGTH, 0.42), mats["aged_bronze"], parts, "BRONZE_TRIM", 0.04)

        # Three structural arch bays. Each concentric rib is independently
        # blocked so close player views retain real voussoir-like joints.
        span = BRIDGE_LENGTH / 3.0
        for arch in range(3):
            y0 = arch * span
            for layer, thickness in enumerate((0.62, 0.30)):
                previous = Vector((x + side * layer * 0.38, y0, -8.7 - layer * 0.1))
                for segment in range(12):
                    t = (segment + 1) / 12.0
                    current = Vector((x + side * layer * 0.38, y0 + span * t,
                                      -8.7 + math.sin(math.pi * t) * 7.0 - layer * 0.1))
                    beam(f"ArchRib_{side:+d}_{arch}_{layer}_{segment:02d}", previous, current,
                         thickness, mats["blue_structure"] if layer == 0 else mats["cyan_glass"],
                         parts, "UNDERSIDE_ARCH" if layer == 0 else "CYAN_LIGHT")
                    previous = current
            for brace in range(1, 5):
                y = y0 + span * brace / 5.0
                box(f"ArchSpandrel_{side:+d}_{arch}_{brace}", (x, y, -5.0),
                    (0.46, 0.34, 4.8), mats["blue_structure"], parts, "UNDERSIDE_ARCH", 0.04)


def build_lantern(parts, mats, side, index, y):
    x = side * 7.55
    box(f"NewelFoot_{side:+d}_{index:02d}", (x, y, 0.62), (1.45, 1.45, 1.0),
        mats["limestone_shadow"], parts, "NEWELS", 0.08)
    box(f"NewelPlinth_{side:+d}_{index:02d}", (x, y, 1.35), (1.12, 1.12, 0.48),
        mats["limestone_light"], parts, "NEWELS", 0.06)
    box(f"NewelShaft_{side:+d}_{index:02d}", (x, y, 2.65), (0.62, 0.62, 2.2),
        mats["limestone"], parts, "NEWELS", 0.05)
    box(f"LanternBase_{side:+d}_{index:02d}", (x, y, 4.05), (0.92, 0.92, 0.42),
        mats["aged_bronze"], parts, "LANTERN_FRAMES", 0.04)
    box(f"LanternCore_{side:+d}_{index:02d}", (x, y, 5.05), (0.66, 0.66, 1.55),
        mats["cyan_glass"], parts, "CYAN_LIGHT", 0.04)
    for corner in (-1, 1):
        for other in (-1, 1):
            beam(f"LanternFrame_{side:+d}_{index:02d}_{corner:+d}_{other:+d}",
                 (x + corner * 0.39, y + other * 0.39, 4.18),
                 (x + corner * 0.28, y + other * 0.28, 5.88), 0.075,
                 mats["aged_bronze"], parts, "LANTERN_FRAMES")
    cone(f"LanternCap_{side:+d}_{index:02d}", (x, y, 6.22), 0.72, 0.78,
         mats["slate_blue"], parts, "ROOFS")
    sphere(f"LanternFinial_{side:+d}_{index:02d}", (x, y, 6.75), 0.14,
           mats["aged_bronze"], parts, "BRONZE_TRIM")


def build_balustrades(parts, mats):
    bridge_bays = 8
    spacing = BRIDGE_LENGTH / bridge_bays
    for side in (-1, 1):
        for index in range(bridge_bays + 1):
            build_lantern(parts, mats, side, index, index * spacing)
        x = side * 7.55
        for bay in range(bridge_bays):
            y0, y1 = bay * spacing + 0.8, (bay + 1) * spacing - 0.8
            beam(f"RailTop_{side:+d}_{bay:02d}", (x, y0, 3.55), (x, y1, 3.55), 0.20,
                 mats["aged_bronze"], parts, "BALUSTRADE")
            beam(f"RailBottom_{side:+d}_{bay:02d}", (x, y0, 1.45), (x, y1, 1.45), 0.16,
                 mats["gold_structure"], parts, "BALUSTRADE")
            subdivisions = 3
            step = (y1 - y0) / subdivisions
            for cell in range(subdivisions):
                a, b = y0 + cell * step, y0 + (cell + 1) * step
                beam(f"LatticeA_{side:+d}_{bay:02d}_{cell}", (x, a, 1.50), (x, b, 3.48), 0.10,
                     mats["gold_structure"], parts, "BALUSTRADE")
                beam(f"LatticeB_{side:+d}_{bay:02d}_{cell}", (x, a, 3.48), (x, b, 1.50), 0.10,
                     mats["gold_structure"], parts, "BALUSTRADE")


def tower(parts, mats, side):
    x = side * 16.0
    tower_name = "LEFT_GATE_TOWER" if side < 0 else "RIGHT_GATE_TOWER"
    foundation = f"{tower_name}/FOUNDATION"
    assign_component(box(f"TowerFoundation_{side:+d}", (x, GATE_Y, 1.2), (10.0, 11.0, 2.4),
                         mats["limestone_shadow"], parts, "GATE_MASONRY", 0.12), foundation)
    assign_component(box(f"TowerPlinth_{side:+d}", (x, GATE_Y, 3.0), (8.7, 9.7, 1.2),
                         mats["limestone_light"], parts, "GATE_MASONRY", 0.10), foundation)

    # The body is structural masonry, not one hidden core with a brick texture.
    # Fourteen full-depth courses are split into alternating two- and three-stone
    # bonds. This makes lower/mid/upper body chunks independently editable while
    # retaining the reference silhouette and exact 7.6 m tower width.
    body_chunk_count = 0
    for course in range(14):
        section = "LOWER_BODY" if course < 5 else ("MID_BODY" if course < 10 else "UPPER_BODY")
        component_path = f"{tower_name}/{section}"
        count = 2 if course % 2 == 0 else 3
        course_width = 7.6 / count
        z = 4.44 + course * 1.90
        for index in range(count):
            bx = x - 3.8 + course_width * (index + 0.5)
            module = box(f"TowerBodyChunk_{side:+d}_{section}_{course:02d}_{index}",
                         (bx, GATE_Y, z), (course_width - 0.055, 8.4, 1.84),
                         mats["limestone"] if (course + index) % 5 else mats["limestone_light"],
                         parts, "GATE_MASONRY", 0.055)
            module["masonry_course"] = course
            module["body_section"] = section
            module["bond_index"] = index
            module["bond_count"] = count
            assign_component(module, component_path)
            body_chunk_count += 1
    # Visible front and outer return brickwork: real separated courses, not a texture.
    for course in range(14):
        z = 5.0 + course * 1.75
        count = 3 if course % 2 == 0 else 4
        brick_w = 7.05 / count
        for index in range(count):
            bx = x - 3.525 + brick_w * (index + 0.5)
            section = "LOWER_BODY" if course < 5 else ("MID_BODY" if course < 10 else "UPPER_BODY")
            assign_component(box(f"TowerFrontBrick_{side:+d}_{course:02d}_{index}",
                                 (bx, GATE_Y - 4.31, z), (brick_w - 0.10, 0.20, 1.56),
                                 mats["limestone_light"] if (course + index) % 4 else mats["limestone"],
                                 parts, "GATE_BRICK_DETAIL", 0.025),
                             f"{tower_name}/{section}")
        for index in range(3):
            by = GATE_Y - 3.0 + index * 2.8
            assign_component(box(f"TowerReturnBrick_{side:+d}_{course:02d}_{index}",
                                 (x + side * 3.91, by, z), (0.20, 1.95, 1.56),
                                 mats["limestone"], parts, "GATE_BRICK_DETAIL", 0.025),
                             f"{tower_name}/{section}")

    # Projecting front buttresses are divided at the same visual storeys seen in
    # the close reference: foot, lower shaft, waist, mid shaft, neck and cap.
    for rib in (-1, 1):
        bx = x + rib * 3.30
        for section, z, height in (("LOWER_BODY", 8.1, 8.2),
                                   ("MID_BODY", 17.0, 8.6),
                                   ("UPPER_BODY", 26.0, 8.4)):
            assign_component(box(f"TowerButtress_{side:+d}_{rib:+d}_{section}",
                                 (bx, GATE_Y - 4.47, z), (0.92, 0.62, height),
                                 mats["limestone_shadow"], parts, "GATE_MASONRY", 0.06),
                             f"{tower_name}/{section}")
        for band_index, band_z in enumerate((4.25, 12.35, 21.35, 30.35)):
            section = "FOUNDATION" if band_index == 0 else (
                "LOWER_BODY" if band_index == 1 else ("MID_BODY" if band_index == 2 else "UPPER_BODY"))
            assign_component(box(f"TowerButtressBand_{side:+d}_{rib:+d}_{band_index}",
                                 (bx, GATE_Y - 4.51, band_z), (1.28, 0.74, 0.58),
                                 mats["limestone_light"], parts, "GATE_MASONRY", 0.045),
                             f"{tower_name}/{section}")

    for band_index, (band_z, width, depth) in enumerate(((12.35, 8.20, 8.95),
                                                          (21.35, 8.05, 8.80),
                                                          (30.35, 8.65, 9.35))):
        section = "LOWER_BODY" if band_index == 0 else ("MID_BODY" if band_index == 1 else "UPPER_BODY")
        assign_component(box(f"TowerStoreyBand_{side:+d}_{band_index}",
                             (x, GATE_Y, band_z), (width, depth, 0.46),
                             mats["aged_bronze"], parts, "BRONZE_TRIM", 0.045),
                         f"{tower_name}/{section}")
    for rib in (-1, 1):
        bx = x + rib * 3.35
        # Keep the gold edge line in front of the projecting buttress so it is
        # visible and visually bonded to every storey band.
        box(f"TowerBronzeRib_{side:+d}_{rib:+d}", (bx, GATE_Y - 4.90, 18.0),
            (0.32, 0.12, 25.0), mats["aged_bronze"], parts, "BRONZE_TRIM", 0.025)
    for band_index, band_z in enumerate((12.35, 21.35, 30.35)):
        box(f"TowerGoldStoreyLine_{side:+d}_{band_index}",
            (x, GATE_Y - 4.90, band_z), (8.35, 0.12, 0.18),
            mats["aged_bronze"], parts, "BRONZE_TRIM", 0.018)
    # Large inset ashlar panels calm the editable masonry bond and establish
    # the long vertical proportions visible in the supplied final reference.
    for panel_index, (panel_z, panel_h) in enumerate(((8.25, 6.8),
                                                       (16.85, 7.6),
                                                       (25.75, 7.2))):
        section = "LOWER_BODY" if panel_index == 0 else (
            "MID_BODY" if panel_index == 1 else "UPPER_BODY")
        panel_left, panel_right = x - 2.575, x + 2.575
        panel_bottom, panel_top = panel_z - panel_h * 0.5, panel_z + panel_h * 0.5
        corner = 0.28
        panel_profile = (
            (panel_left + corner, panel_bottom), (panel_right - corner, panel_bottom),
            (panel_right, panel_bottom + corner), (panel_right, panel_top - corner),
            (panel_right - corner, panel_top), (panel_left + corner, panel_top),
            (panel_left, panel_top - corner), (panel_left, panel_bottom + corner),
        )
        assign_component(extruded_profile(
            f"TowerInsetPanel_{side:+d}_{panel_index}", panel_profile,
            GATE_Y - 4.48, 0.22, mats["limestone_light"], parts,
            "GATE_MASONRY"),
            f"{tower_name}/{section}")
        assign_component(tube_polyline(
            f"TowerInsetPanelOutline_{side:+d}_{panel_index}",
            tuple((px, GATE_Y - 4.64, pz) for px, pz in panel_profile),
            0.075, mats["aged_bronze"], parts, "BRONZE_TRIM", cyclic=True),
            f"{tower_name}/{section}")
    lancet_frame_profile = ((x - 0.82, 15.1), (x - 0.82, 20.45),
                            (x, 23.05), (x + 0.82, 20.45), (x + 0.82, 15.1))
    assign_component(extruded_profile(
        f"TowerWindowFrame_{side:+d}", lancet_frame_profile, GATE_Y - 4.55,
        0.22, mats["aged_bronze"], parts, "BRONZE_TRIM"),
        f"{tower_name}/ORNAMENT")
    lancet_light_profile = ((x - 0.44, 15.48), (x - 0.44, 20.28),
                            (x, 22.34), (x + 0.44, 20.28), (x + 0.44, 15.48))
    assign_component(extruded_profile(
        f"TowerWindowLight_{side:+d}", lancet_light_profile, GATE_Y - 4.70,
        0.10, mats["cyan_glass"], parts, "CYAN_LIGHT"),
        f"{tower_name}/ORNAMENT")
    diamond_frame = box(f"TowerUpperDiamondFrame_{side:+d}",
                        (x, GATE_Y - 4.61, 29.0), (1.55, 0.24, 1.55),
                        mats["aged_bronze"], parts, "BRONZE_TRIM", 0.04)
    diamond_frame.rotation_euler.y = math.radians(45)
    assign_component(diamond_frame, f"{tower_name}/ORNAMENT")
    diamond_light = box(f"TowerUpperDiamondLight_{side:+d}",
                        (x, GATE_Y - 4.75, 29.0), (0.92, 0.12, 0.92),
                        mats["cyan_glass"], parts, "CYAN_LIGHT", 0.025)
    diamond_light.rotation_euler.y = math.radians(45)
    assign_component(diamond_light, f"{tower_name}/ORNAMENT")
    assign_component(tube_polyline(
        f"TowerDiamondHood_{side:+d}",
        ((x - 0.92, GATE_Y - 4.93, 29.65),
         (x, GATE_Y - 4.93, 30.72),
         (x + 0.92, GATE_Y - 4.93, 29.65)),
        0.13, mats["aged_bronze"], parts, "BRONZE_TRIM"),
        f"{tower_name}/ORNAMENT")
    box(f"TowerCrown_{side:+d}", (x, GATE_Y, 31.4), (8.8, 9.6, 2.0),
        mats["limestone_light"], parts, "GATE_MASONRY", 0.09)
    assign_component(box(f"TowerRoofBaseGoldBand_{side:+d}",
                         (x, GATE_Y - 4.90, 32.42), (8.65, 0.14, 0.38),
                         mats["aged_bronze"], parts, "BRONZE_TRIM", 0.025),
                     f"{tower_name}/ROOF")
    for corner_x in (-1, 1):
        for corner_y in (-1, 1):
            cylinder(f"TowerPinnacle_{side:+d}_{corner_x:+d}_{corner_y:+d}",
                     (x + corner_x * 3.7, GATE_Y + corner_y * 4.0, 34.1), 0.35, 3.5,
                     mats["aged_bronze"], parts, "BRONZE_TRIM", 8)
            cone(f"TowerPinnacleCap_{side:+d}_{corner_x:+d}_{corner_y:+d}",
                 (x + corner_x * 3.7, GATE_Y + corner_y * 4.0, 36.1), 0.48, 1.2,
                 mats["slate_blue"], parts, "ROOFS", 8)
    # A two-stage octagonal mansard has the broad lower skirt and crisp upper
    # shoulder of the reference while preserving the approved finial height.
    roof_base_z = 32.50
    lower_roof_top_z = 43.80
    roof_peak_z = 48.50
    lower_radius = 4.25
    shoulder_radius = 2.35
    assign_component(frustum(
        f"TowerMansardLower_{side:+d}", (x, GATE_Y, 38.15),
        lower_radius, shoulder_radius, 11.3, mats["slate_blue"], parts,
        "ROOFS", 8), f"{tower_name}/ROOF")
    assign_component(cone(
        f"TowerMansardUpper_{side:+d}", (x, GATE_Y, 46.15),
        shoulder_radius, 4.7, mats["slate_blue"], parts, "ROOFS", 8),
        f"{tower_name}/ROOF")
    roof_outline_y = GATE_Y - 2.12
    assign_component(tube_polyline(
        f"TowerSpireGoldOutline_{side:+d}",
        ((x - lower_radius, roof_outline_y, roof_base_z),
         (x - shoulder_radius, roof_outline_y, lower_roof_top_z),
         (x, roof_outline_y, roof_peak_z),
         (x + shoulder_radius, roof_outline_y, lower_roof_top_z),
         (x + lower_radius, roof_outline_y, roof_base_z)),
        0.11, mats["aged_bronze"], parts, "BRONZE_TRIM"),
        f"{tower_name}/ROOF")
    assign_component(tube_polyline(
        f"TowerSpireCenterRib_{side:+d}",
        ((x, roof_outline_y - 0.02, roof_base_z),
         (x, roof_outline_y - 0.02, lower_roof_top_z),
         (x, roof_outline_y - 0.02, roof_peak_z)),
        0.075, mats["gold_structure"], parts, "BRONZE_TRIM"),
        f"{tower_name}/ROOF")
    assign_component(cylinder(
        f"TowerFinialMast_{side:+d}", (x, GATE_Y, 49.8), 0.11, 2.6,
        mats["aged_bronze"], parts, "BRONZE_TRIM", 6), f"{tower_name}/ROOF")
    sphere(f"TowerFinial_{side:+d}", (x, GATE_Y, 51.1), 0.42,
           mats["aged_bronze"], parts, "BRONZE_TRIM")
    cone(f"TowerNeedle_{side:+d}", (x, GATE_Y, 51.8), 0.14, 1.4,
         mats["aged_bronze"], parts, "BRONZE_TRIM", 8)
    return body_chunk_count


def build_gate(parts, mats):
    body_chunk_count = tower(parts, mats, -1) + tower(parts, mats, 1)
    half = PORTAL_WIDTH / 2.0
    # This six-metre-deep wall is the load-bearing span between the towers.
    # Its two concave halves follow the opening, so masonry surrounds the portal
    # all the way to the foundations rather than beginning above it and floating.
    wall_center_y = GATE_Y
    wall_depth = 6.0
    wall_front_y = wall_center_y - wall_depth * 0.5
    arch_halves = {}
    for side in (-1, 1):
        shoulder_x = side * half
        shoulder = Vector((shoulder_x, wall_front_y - 0.58, PORTAL_SHOULDER))
        apex = Vector((0, wall_front_y - 0.58, PORTAL_APEX))
        control = Vector((shoulder_x, wall_front_y - 0.58, 29.5))
        points = [shoulder]
        for segment in range(1, 13):
            t = segment / 12.0
            points.append(shoulder * ((1.0 - t) ** 2)
                          + control * (2.0 * (1.0 - t) * t) + apex * (t ** 2))
        arch_halves[side] = points

        outer_x = side * 12.35
        if side < 0:
            wall_profile = [(outer_x, 3.6), (outer_x, 38.15), (0.0, 44.55),
                            (0.0, PORTAL_APEX)]
            wall_profile += [(point.x, point.z) for point in reversed(points[:-1])]
            wall_profile += [(-half, 3.6)]
        else:
            wall_profile = [(half, 3.6)]
            wall_profile += [(point.x, point.z) for point in points[:-1]]
            wall_profile += [(0.0, PORTAL_APEX), (0.0, 44.55),
                             (outer_x, 38.15), (outer_x, 3.6)]
        assign_component(extruded_profile(
            f"GateStructuralWall_{side:+d}", wall_profile, wall_center_y,
            wall_depth, mats["limestone_light"], parts, "GATE_MASONRY"),
            "CENTRAL_FACADE/GABLE_BODY")

    # The stepped parapet is recessed behind the pointed face. Its outer tiers
    # overlap the inner tower shoulders, visibly locking all three masses.
    rear_parapet = (
        (-12.35, 36.7), (-12.35, 39.3), (-10.6, 39.3), (-10.6, 40.4),
        (-7.4, 40.4), (-7.4, 41.35), (-3.2, 41.35), (-3.2, 42.0),
        (3.2, 42.0), (3.2, 41.35), (7.4, 41.35), (7.4, 40.4),
        (10.6, 40.4), (10.6, 39.3), (12.35, 39.3), (12.35, 36.7),
    )
    assign_component(extruded_profile(
        "FacadeSteppedRearParapet", rear_parapet, GATE_Y + 1.05, 4.4,
        mats["limestone"], parts, "GATE_MASONRY"),
        "CENTRAL_FACADE/STEPPED_CROWN")

    facade_y = GATE_Y - 0.6
    for side in (-1, 1):
        x = side * (half + 1.5)
        assign_component(box(
            f"PortalPier_{side:+d}", (x, facade_y, 10.0), (3.0, 2.0, 20.0),
            mats["limestone_light"], parts, "GATE_MASONRY", 0.09),
            "CENTRAL_FACADE/POINTED_PORTAL")
        assign_component(box(
            f"PortalPierShadow_{side:+d}", (x + side * 1.2, facade_y - 1.08, 11.0),
            (0.42, 0.22, 17.0), mats["limestone_shadow"], parts,
            "GATE_BRICK_DETAIL", 0.025), "CENTRAL_FACADE/POINTED_PORTAL")
        # Continue every curved molding down to the plinth. The arch and jambs
        # now form one readable portal order instead of an arc suspended in air.
        jamb_center_z = (3.7 + PORTAL_SHOULDER) * 0.5
        jamb_height = PORTAL_SHOULDER - 3.7
        assign_component(box(
            f"PortalOuterJamb_{side:+d}",
            (side * half, wall_front_y - 0.58, jamb_center_z),
            (1.55, 1.05, jamb_height), mats["limestone_shadow"], parts,
            "PORTAL_ARCH", 0.05), "CENTRAL_FACADE/POINTED_PORTAL")
        assign_component(box(
            f"PortalInnerJamb_{side:+d}",
            (side * (half - 0.42), wall_front_y - 1.18, jamb_center_z),
            (0.82, 0.42, jamb_height), mats["limestone_light"], parts,
            "PORTAL_ARCH", 0.04), "CENTRAL_FACADE/POINTED_PORTAL")
        assign_component(box(
            f"PortalGoldJamb_{side:+d}",
            (side * (half - 0.42), wall_front_y - 1.46, jamb_center_z),
            (0.16, 0.10, jamb_height), mats["aged_bronze"], parts,
            "BRONZE_TRIM", 0.018), "CENTRAL_FACADE/POINTED_PORTAL")
        shoulder = arch_halves[side][0]
        apex = arch_halves[side][-1]
        previous = shoulder
        for segment in range(12):
            current = arch_halves[side][segment + 1]
            assign_component(beam(
                f"PortalOuterMolding_{side:+d}_{segment:02d}", previous, current,
                1.55, mats["limestone_shadow"], parts, "PORTAL_ARCH", depth=1.05),
                "CENTRAL_FACADE/POINTED_PORTAL")
            inward = Vector((-side * 0.42, -0.60, -0.18))
            assign_component(beam(
                f"PortalInnerMolding_{side:+d}_{segment:02d}", previous + inward,
                current + inward, 0.82, mats["limestone_light"], parts,
                "PORTAL_ARCH", depth=0.42), "CENTRAL_FACADE/POINTED_PORTAL")
            assign_component(beam(
                f"PortalGoldTrim_{side:+d}_{segment:02d}",
                previous + inward + Vector((0, -0.28, 0)),
                current + inward + Vector((0, -0.28, 0)), 0.16,
                mats["aged_bronze"], parts, "BRONZE_TRIM", depth=0.10),
                "CENTRAL_FACADE/POINTED_PORTAL")
            previous = current

    # A shallow face plate produces the uninterrupted pale field in the crop.
    # Its lower V overlaps the arch apex, eliminating the former floating gap.
    gable_profile = ((-11.35, 37.95), (0.0, 44.55), (11.35, 37.95),
                     (0.0, 34.15))
    assign_component(extruded_profile(
        "GatePointedGableFace", gable_profile, GATE_Y - 3.18, 0.38,
        mats["limestone_light"], parts, "GATE_MASONRY"),
        "CENTRAL_FACADE/GABLE_BODY")

    # Pale stone coping gives the roofline its stepped mass while following the
    # peak instead of increasing the height with stacked crown slabs.
    assign_component(beam("FacadeStoneCopingLeft", (-11.35, GATE_Y, 38.05),
                          (0.0, GATE_Y, 44.75), 0.72, mats["limestone_light"],
                          parts, "GATE_MASONRY", depth=0.72),
                     "CENTRAL_FACADE/STEPPED_CROWN")
    assign_component(beam("FacadeStoneCopingRight", (11.35, GATE_Y, 38.05),
                          (0.0, GATE_Y, 44.75), 0.72, mats["limestone_light"],
                          parts, "GATE_MASONRY", depth=0.72),
                     "CENTRAL_FACADE/STEPPED_CROWN")

    # Fine stone joints reproduce the large, quiet panels visible in the crop.
    # All face details sit millimetres in front of the 5.6 m-deep gable face.
    # The earlier offset inherited the portal's front plane and left the trim
    # floating several metres forward; this plane keeps every line glued down.
    facade_front = GATE_Y - 3.39
    panel_joints = (
        ((-10.7, 33.35), (-4.0, 32.15)), ((10.7, 33.35), (4.0, 32.15)),
        ((-9.35, 35.55), (-4.15, 39.65)), ((9.35, 35.55), (4.15, 39.65)),
    )
    for index, ((x0, z0), (x1, z1)) in enumerate(panel_joints):
        assign_component(beam(f"FacadePanelJoint_{index}",
                              (x0, facade_front, z0), (x1, facade_front, z1),
                              0.035, mats["limestone"], parts,
                              "GATE_BRICK_DETAIL", depth=0.08),
                         "CENTRAL_FACADE/GABLE_BODY")
    # Both perimeter layers consume the exact same profile as the core face.
    # Their corners and slopes therefore cannot drift from the masonry angle.
    stone_outline_y = GATE_Y - 3.45
    assign_component(tube_polyline(
        "FacadeShapeDrivenStonePerimeter",
        tuple((x, stone_outline_y, z) for x, z in gable_profile),
        0.34, mats["limestone_shadow"], parts, "GATE_MASONRY", cyclic=True),
        "CENTRAL_FACADE/GABLE_BODY")
    gold_surface_y = GATE_Y - 3.62
    assign_component(tube_polyline(
        "FacadeContinuousGoldOutline",
        tuple((x, gold_surface_y, z) for x, z in gable_profile),
        0.17, mats["aged_bronze"], parts, "BRONZE_TRIM", cyclic=True),
        "CENTRAL_FACADE/GABLE_BODY")
    for index, (x, z) in enumerate(gable_profile):
        assign_component(sphere(
            f"FacadePerimeterBoss_{index}", (x, gold_surface_y - 0.06, z),
            0.23, mats["gold_structure"], parts, "BRONZE_TRIM"),
            "CENTRAL_FACADE/GABLE_BODY")

    crest = [(0.0, 40.9), (-3.9, 36.9), (3.9, 36.9)]
    for index, (x, z) in enumerate(crest):
        halo_radius = 1.25 if index == 0 else 1.20
        light_radius = 0.88 if index == 0 else 0.84
        cylinder(f"CrestHalo_{index}", (x, GATE_Y - 3.55, z), halo_radius, 0.28,
                 mats["aged_bronze"], parts, "BRONZE_TRIM", 16).rotation_euler.x = math.pi / 2
        cylinder(f"CrestLight_{index}", (x, GATE_Y - 3.72, z), light_radius, 0.18,
                 mats["cyan_glass"], parts, "CYAN_LIGHT", 16).rotation_euler.x = math.pi / 2
    crest_line_y = GATE_Y - 3.78
    assign_component(tube_polyline(
        "CrestContinuousStem", ((0, crest_line_y, 40.45), (0, crest_line_y, 35.45)),
        0.16, mats["aged_bronze"], parts, "BRONZE_TRIM"),
        "CENTRAL_FACADE/THREE_LIGHT_CREST")
    assign_component(tube_polyline(
        "CrestContinuousLeftBranch",
        ((0, crest_line_y, 39.65), (-3.9, crest_line_y, 36.9),
         (0, crest_line_y, 35.45)),
        0.16, mats["aged_bronze"], parts, "BRONZE_TRIM"),
        "CENTRAL_FACADE/THREE_LIGHT_CREST")
    assign_component(tube_polyline(
        "CrestContinuousRightBranch",
        ((0, crest_line_y, 39.65), (3.9, crest_line_y, 36.9),
         (0, crest_line_y, 35.45)),
        0.16, mats["aged_bronze"], parts, "BRONZE_TRIM"),
        "CENTRAL_FACADE/THREE_LIGHT_CREST")
    sphere("CrestUpperJunction", (0, crest_line_y, 39.65), 0.24,
           mats["aged_bronze"], parts, "BRONZE_TRIM")
    sphere("CrestLowerJunction", (0, crest_line_y, 35.45), 0.30,
           mats["aged_bronze"], parts, "BRONZE_TRIM")

    leaf_tips = ((-1.80, 38.35, 0.76), (-0.78, 37.65, 0.56),
                 (0.78, 37.65, 0.56), (1.80, 38.35, 0.76))
    for index, (leaf_x, leaf_z, leaf_width) in enumerate(leaf_tips):
        assign_component(leaf_plate(
            f"CrestBotanicalLeafPlate_{index}", (0.0, 35.55), (leaf_x, leaf_z),
            leaf_width, crest_line_y - 0.02, 0.12, mats["aged_bronze"], parts,
            "BRONZE_TRIM"), "CENTRAL_FACADE/THREE_LIGHT_CREST")
        beam(f"CrestLeafVein_{index}",
             (0.0, crest_line_y - 0.10, 35.58),
             (leaf_x, crest_line_y - 0.10, leaf_z), 0.075,
             mats["gold_structure"], parts, "BRONZE_TRIM", depth=0.05)
    # Small crown dormer visible above the stepped parapet in the close crop.
    dormer_profile = ((-1.55, 44.20), (-1.55, 45.25), (0.0, 46.35),
                      (1.55, 45.25), (1.55, 44.20))
    assign_component(extruded_profile("FacadeCrownDormer", dormer_profile,
                                      GATE_Y - 0.2, 2.0, mats["limestone_light"],
                                      parts, "GATE_MASONRY"),
                     "CENTRAL_FACADE/STEPPED_CROWN")
    assign_component(tube_polyline(
        "FacadeCrownDormerGoldHood",
        ((-1.45, GATE_Y - 1.36, 45.25), (0.0, GATE_Y - 1.36, 46.35),
         (1.45, GATE_Y - 1.36, 45.25)),
        0.13, mats["aged_bronze"], parts, "BRONZE_TRIM"),
        "CENTRAL_FACADE/STEPPED_CROWN")
    dormer_frame = box("FacadeCrownDormerFrame", (0, GATE_Y - 1.27, 45.25),
                       (1.42, 0.16, 1.42), mats["aged_bronze"], parts, "BRONZE_TRIM", 0.03)
    dormer_frame.rotation_euler.y = math.radians(45)
    assign_component(dormer_frame, "CENTRAL_FACADE/STEPPED_CROWN")
    dormer_light = box("FacadeCrownDormerLight", (0, GATE_Y - 1.38, 45.25),
                       (0.82, 0.10, 0.82), mats["cyan_glass"], parts, "CYAN_LIGHT", 0.02)
    dormer_light.rotation_euler.y = math.radians(45)
    assign_component(dormer_light, "CENTRAL_FACADE/STEPPED_CROWN")
    return body_chunk_count


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    # Bake each module in world space before semantic joining. Without this,
    # Blender retains the first selected arch rib's quaternion on the joined
    # object and rotates the remaining arch spans around that local frame.
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.select_set(False)


def component_path_for(obj):
    """Classify legacy and new modules into a navigable modeling hierarchy."""
    explicit = obj.get("component_path")
    if explicit:
        return explicit
    name = obj.name
    if name.startswith("Tower"):
        tower_name = "LEFT_GATE_TOWER" if "_-1" in name else "RIGHT_GATE_TOWER"
        if "Foundation" in name or "Plinth" in name:
            section = "FOUNDATION"
        elif any(token in name for token in ("Spire", "Crown")):
            section = "ROOF"
        elif any(token in name for token in ("Pinnacle", "Finial", "Needle", "Window", "BronzeRib")):
            section = "ORNAMENT"
        else:
            section = "MID_BODY"
        return f"{tower_name}/{section}"
    if name.startswith("Portal"):
        return "CENTRAL_FACADE/POINTED_PORTAL"
    if name.startswith("FacadeCrown"):
        return "CENTRAL_FACADE/STEPPED_CROWN"
    if name.startswith("FacadeGold"):
        return "CENTRAL_FACADE/GABLE_BODY"
    if name.startswith("Crest"):
        return "CENTRAL_FACADE/THREE_LIGHT_CREST"
    if name.startswith("Gate"):
        return "CENTRAL_FACADE/GABLE_BODY"
    if name.startswith(("Paver", "CyanRouteInlay", "BronzeEdgeInlay")):
        return "BRIDGE/PAVING"
    if name.startswith(("Deck", "FasciaCornice")):
        return "BRIDGE/DECK_STRUCTURE"
    if name.startswith(("Fascia", "Arch")):
        return "BRIDGE/FASCIA_AND_ARCHES"
    if name.startswith(("Rail", "Lattice")):
        return "BRIDGE/BALUSTRADE"
    return "BRIDGE/LANTERNS_AND_NEWELS"


def build_component_hierarchy(parts, hierarchy_collection):
    """Parent editable meshes into gate > assembly > subcomponent empties."""
    structure = OrderedDict((
        ("LEFT_GATE_TOWER", ("FOUNDATION", "LOWER_BODY", "MID_BODY", "UPPER_BODY", "ROOF", "ORNAMENT")),
        ("RIGHT_GATE_TOWER", ("FOUNDATION", "LOWER_BODY", "MID_BODY", "UPPER_BODY", "ROOF", "ORNAMENT")),
        ("CENTRAL_FACADE", ("POINTED_PORTAL", "GABLE_BODY", "STEPPED_CROWN", "THREE_LIGHT_CREST")),
        ("BRIDGE", ("PAVING", "DECK_STRUCTURE", "FASCIA_AND_ARCHES", "BALUSTRADE", "LANTERNS_AND_NEWELS")),
    ))
    root = bpy.data.objects.new("00_CASTLE_GALAXY_ASSEMBLY", None)
    hierarchy_collection.objects.link(root)
    root["assembly_role"] = "asset_root"
    nodes = {}
    top_index = 1
    for assembly, children in structure.items():
        parent = bpy.data.objects.new(f"{top_index}0_{assembly}", None)
        hierarchy_collection.objects.link(parent)
        parent.parent = root
        parent["assembly_role"] = "major_component"
        nodes[assembly] = parent
        for child_index, child in enumerate(children, start=1):
            node = bpy.data.objects.new(f"{top_index}{child_index}_{child}", None)
            hierarchy_collection.objects.link(node)
            node.parent = parent
            node["assembly_role"] = "editable_subcomponent"
            node["component_path"] = f"{assembly}/{child}"
            nodes[f"{assembly}/{child}"] = node
        top_index += 1
    # Newly linked parent chains need one dependency update before mesh
    # parenting. All hierarchy empties intentionally use identity transforms,
    # so retaining each mesh's local transform also retains its authored world
    # transform without a stale matrix_world round-trip.
    bpy.context.view_layer.update()
    counts = OrderedDict((path, 0) for path in nodes if "/" in path)
    for obj in [candidate for candidate in parts.objects if candidate.type == "MESH"]:
        path = component_path_for(obj)
        obj["component_path"] = path
        obj.parent = nodes[path]
        counts[path] += 1
    bpy.context.view_layer.update()
    root["editable_mesh_modules"] = sum(counts.values())
    root["subcomponent_count"] = len(counts)
    return root, counts, 1 + len(structure) + len(counts)


def build_export(parts, export_collection):
    grouped = OrderedDict()
    for source in (candidate for candidate in parts.objects if candidate.type == "MESH"):
        grouped.setdefault(source.get("semantic_group", "DETAIL"), []).append(source)
    root = bpy.data.objects.new("CastleGalaxyBridgeGate", None)
    export_collection.objects.link(root)
    root["source_blend"] = "assets3D/castle_galaxy_bridge/blend/castle_galaxy_bridge_gate.blend"
    root["bridge_length_m"] = BRIDGE_LENGTH
    root["bridge_width_m"] = BRIDGE_WIDTH
    root["gate_width_m"] = GATE_WIDTH
    root["gate_height_m"] = GATE_HEIGHT
    root["clear_portal_width_m"] = PORTAL_WIDTH
    root["reference"] = "user_supplied_bridge_gate_screenshot"
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
    return root, exports, sum(len(items) for items in grouped.values()), grouped


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
        "size": [round(maximum[index] - minimum[index], 4) for index in range(3)],
        "minimum": [round(value, 4) for value in minimum],
        "maximum": [round(value, 4) for value in maximum],
    }


def component_max_z(objects, component_prefix):
    points = [obj.matrix_world @ Vector(corner)
              for obj in objects
              if str(obj.get("component_path", "")).startswith(component_prefix)
              for corner in obj.bound_box]
    if not points:
        raise AssertionError(f"No editable modules found for {component_prefix}")
    return round(max(point.z for point in points), 4)


def material_category(name):
    name = name.lower()
    if "limestone" in name:
        return "sand_ivory"
    if "bronze" in name or "gold" in name or "charcoal" in name:
        return "gold"
    if "blue" in name or "cyan" in name:
        return "blue"
    raise AssertionError(f"Unclassified bridge material: {name}")


def measured_color_mix(objects, editable_sources=None):
    """Area-weighted exposed palette, excluding buried masonry bond faces."""
    areas = {"sand_ivory": 0.0, "gold": 0.0, "blue": 0.0}
    for obj in objects:
        for polygon in obj.data.polygons:
            category = material_category(obj.data.materials[polygon.material_index].name)
            areas[category] += polygon.area
    # Joining real course blocks preserves coincident top/bottom and internal
    # bond faces in the GLB. They are useful for independent editing but never
    # visible, so remove their analytical area from the graphic color ratio.
    if editable_sources is not None:
        for obj in editable_sources:
            if not obj.name.startswith("TowerBodyChunk_"):
                continue
            width, depth, height = obj.dimensions
            hidden = 2.0 * width * depth
            index = int(obj.get("bond_index", 0))
            count = int(obj.get("bond_count", 1))
            if index > 0:
                hidden += depth * height
            if index < count - 1:
                hidden += depth * height
            category = material_category(obj.data.materials[0].name)
            areas[category] = max(0.0, areas[category] - hidden)
    total = sum(areas.values())
    return {key: round(value / total * 100.0, 2) for key, value in areas.items()}


def setup_render(export_root):
    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.28, 0.60, 0.88, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.34
    bpy.ops.object.light_add(type="AREA", location=(-35, -30, 70))
    key = bpy.context.object
    key.data.energy = 3400
    key.data.color = (1.0, 0.78, 0.58)
    key.data.shape = "DISK"
    key.data.size = 45
    key.rotation_euler = (math.radians(25), 0, math.radians(-28))
    bpy.ops.object.light_add(type="SUN", location=(0, 0, 70))
    bpy.context.object.rotation_euler = (math.radians(25), math.radians(-20), math.radians(-25))
    bpy.context.object.data.energy = 2.5
    bpy.context.object.data.color = (1.0, 0.88, 0.68)
    bpy.ops.object.camera_add(location=(52, -48, 29))
    camera = bpy.context.object
    target = Vector((0, 128, 17))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 48
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = RENDER_PATH
    scene.render.film_transparent = False
    bpy.ops.render.render(write_still=True)
    # The square close-up matches the latest reference framing and includes the
    # full tower-to-wall junction, spire silhouette, portal, and bridge landing.
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    camera.location = (18.0, 74.0, 29.0)
    target = Vector((0.0, GATE_Y, 27.5))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 55
    scene.render.filepath = GATE_CLOSEUP_RENDER_PATH
    bpy.ops.render.render(write_still=True)


def main():
    for path in (os.path.dirname(BLEND_PATH), os.path.dirname(GLB_PATH), os.path.dirname(RENDER_PATH)):
        os.makedirs(path, exist_ok=True)
    reset_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.length_unit = "METERS"
    scene["asset_title"] = "CASTLE TO GALAXY BRIDGE AND FRONT GATE"
    scene["reference_dimensions_px"] = "1090x1028"
    scene["design_basis"] = "human-scaled proportional reconstruction from supplied screenshot"
    parts = collection("CASTLE_GALAXY_EDITABLE_PARTS")
    hierarchy_collection = collection("CASTLE_GALAXY_COMPONENT_HIERARCHY")
    export_collection = collection("CASTLE_GALAXY_GAME_EXPORT")
    mats = {
        key: material(f"MAT_{key.title()}", color,
                      metallic=0.72 if key in ("charcoal_iron", "aged_bronze", "gold_structure") else 0.0,
                      roughness=0.24 if key == "cyan_glass" else (0.44 if key in ("charcoal_iron", "aged_bronze", "gold_structure", "slate_blue", "blue_structure") else 0.86),
                      emission=3.0 if key == "cyan_glass" else (
                          0.22 if key in ("aged_bronze", "gold_structure") else 0.0))
        for key, color in PALETTE.items()
    }
    build_deck(parts, mats)
    build_fascia(parts, mats)
    build_balustrades(parts, mats)
    body_chunk_count = build_gate(parts, mats)
    hierarchy_root, component_counts, hierarchy_node_count = build_component_hierarchy(
        parts, hierarchy_collection)
    central_facade_max_z = component_max_z(
        [candidate for candidate in parts.objects if candidate.type == "MESH"],
        "CENTRAL_FACADE/")
    export_root, exports, source_count, groups = build_export(parts, export_collection)
    parts.hide_render = True
    parts.hide_viewport = True
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)

    bpy.ops.object.select_all(action="DESELECT")
    select_recursive(export_root)
    bpy.context.view_layer.objects.active = export_root
    bpy.ops.export_scene.gltf(filepath=GLB_PATH, use_selection=True, export_format="GLB",
                              export_apply=True, export_yup=True, export_materials="EXPORT",
                              export_cameras=False, export_lights=False, export_animations=False,
                              export_extras=True)
    triangles = triangle_count(exports)
    bounds = measured_bounds(exports)
    color_mix = measured_color_mix(
        exports, [candidate for candidate in parts.objects if candidate.type == "MESH"])
    manifest = {
        "asset": "castle_galaxy_bridge_gate",
        "version": 1,
        "performance_profile": PERFORMANCE_PROFILE,
        "target_triangle_budget": TARGET_TRIANGLE_BUDGET,
        "previous_triangle_count": 200108,
        "source_blend": "assets3D/castle_galaxy_bridge/blend/castle_galaxy_bridge_gate.blend",
        "game_glb": "assets3D/castle_galaxy_bridge/glb/castle_galaxy_bridge_gate.glb",
        "reference_image_pixels": [1090, 1028],
        "front_gate_reference_measurements": {
            "tower_center_separation_px": 538,
            "central_facade_width_px": 350,
            "outline_thickness_px": 5,
            "crest_top_orb_diameter_px": 49,
            "crest_side_orb_diameter_px": 51,
            "crest_side_offset_m": 3.9,
            "outline_lower_v_height_m": 34.15,
            "continuous_facade_outline_modules": 1,
            "structural_wall_halves": 2,
            "portal_molding_layers": 3,
            "tower_roof_stages": 2,
            "shape_driven_outline_systems": 4,
            "tower_panel_outline_count": 6,
            "facade_outline_profile_vertices": 4,
        },
        "dimensions_m": {
            "bridge_length": BRIDGE_LENGTH,
            "bridge_width": BRIDGE_WIDTH,
            "gate_outer_width": GATE_WIDTH,
            "gate_finial_height": GATE_HEIGHT,
            "clear_portal_width": PORTAL_WIDTH,
            "portal_shoulder_height": PORTAL_SHOULDER,
            "portal_apex_height": PORTAL_APEX,
            "central_facade_max_height": central_facade_max_z,
            "rear_wall_setback_in_game": 157.0,
        },
        "editable_source_modules": source_count,
        "editable_component_hierarchy": {
            "root": hierarchy_root.name,
            "major_components": 4,
            "subcomponents": dict(component_counts),
        },
        "hierarchy_node_count": hierarchy_node_count,
        "tower_body_course_count_per_tower": 14,
        "tower_body_chunk_count": body_chunk_count,
        "game_mesh_groups": len(exports),
        "group_module_counts": {name: len(items) for name, items in groups.items()},
        "game_triangles": triangles,
        "triangle_reduction_percent": round((1.0 - triangles / 200108.0) * 100.0, 2),
        "measured_blender_bounds_m": bounds,
        "measured_surface_color_mix_percent": color_mix,
        "coordinate_system": "Blender metric, X width, Y route, Z height",
        "collision": "existing tested Godot bridge collision retained",
        "web_compatible": True,
        "laptop_cpu_optimized": True,
    }
    with open(MANIFEST_PATH, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")
    setup_render(export_root)
    assert source_count >= 1000
    assert body_chunk_count == 70
    assert hierarchy_node_count == 26
    assert central_facade_max_z <= 46.6
    assert len(exports) <= 16
    # The 13 joined runtime meshes remain inexpensive draw-call-wise. The
    # triangle budget intentionally retains the small chamfers that make the
    # masonry readable in grazing light at player height.
    assert triangles < TARGET_TRIANGLE_BUDGET
    assert 58.0 <= color_mix["sand_ivory"] <= 63.5
    assert 28.0 <= color_mix["gold"] <= 33.0
    assert 8.0 <= color_mix["blue"] <= 11.0
    print("CASTLE_GALAXY_BRIDGE_BUILD: PASS")
    print(f"CASTLE_GALAXY_BRIDGE_BUILD: modules={source_count} groups={len(exports)} triangles={triangles}")
    print(f"CASTLE_GALAXY_BRIDGE_BUILD: central_facade_max_z={central_facade_max_z}")
    print(f"CASTLE_GALAXY_BRIDGE_BUILD: color_mix={color_mix}")
    print(f"CASTLE_GALAXY_BRIDGE_BUILD: blend={BLEND_PATH}")
    print(f"CASTLE_GALAXY_BRIDGE_BUILD: glb={GLB_PATH}")
    print(f"CASTLE_GALAXY_BRIDGE_BUILD: render={RENDER_PATH}")
    print(f"CASTLE_GALAXY_BRIDGE_BUILD: closeup={GATE_CLOSEUP_RENDER_PATH}")


def refresh_materials_only():
    """Fast deterministic palette iteration against the already-built source."""
    for key, color in PALETTE.items():
        mat = bpy.data.materials.get(f"MAT_{key.title()}")
        if mat is None:
            # Blender prunes palette entries that are no longer assigned to any
            # module (the former charcoal system is intentionally superseded by
            # structural gold and blue).
            continue
        mat.diffuse_color = color
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Metallic"].default_value = 0.72 \
            if key in ("charcoal_iron", "aged_bronze", "gold_structure") else 0.0
        bsdf.inputs["Roughness"].default_value = 0.24 if key == "cyan_glass" else (
            0.44 if key in ("charcoal_iron", "aged_bronze", "gold_structure",
                            "slate_blue", "blue_structure") else 0.86)
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = 3.0 if key == "cyan_glass" else (
            0.22 if key in ("aged_bronze", "gold_structure") else 0.0)
    export_root = bpy.data.objects.get("CastleGalaxyBridgeGate")
    if export_root is None:
        raise AssertionError("CastleGalaxyBridgeGate export root is missing")
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    bpy.ops.object.select_all(action="DESELECT")
    select_recursive(export_root)
    bpy.context.view_layer.objects.active = export_root
    bpy.ops.export_scene.gltf(filepath=GLB_PATH, use_selection=True, export_format="GLB",
                              export_apply=True, export_yup=True, export_materials="EXPORT",
                              export_cameras=False, export_lights=False, export_animations=False,
                              export_extras=True)
    setup_render(export_root)
    print("CASTLE_GALAXY_BRIDGE_MATERIAL_REFRESH: PASS")


def refresh_metadata_only():
    """Refresh exposed-surface measurements on an already generated source."""
    parts = bpy.data.collections.get("CASTLE_GALAXY_EDITABLE_PARTS")
    export_root = bpy.data.objects.get("CastleGalaxyBridgeGate")
    if parts is None or export_root is None:
        raise AssertionError("Generated bridge source and export root are required")
    sources = [candidate for candidate in parts.objects if candidate.type == "MESH"]
    for obj in sources:
        if not obj.name.startswith("TowerBodyChunk_"):
            continue
        tokens = obj.name.split("_")
        course = int(tokens[-2])
        obj["masonry_course"] = course
        obj["bond_index"] = int(tokens[-1])
        obj["bond_count"] = 2 if course % 2 == 0 else 3
    exports = [child for child in export_root.children if child.type == "MESH"]
    color_mix = measured_color_mix(exports, sources)
    with open(MANIFEST_PATH, "r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    manifest["measured_surface_color_mix_percent"] = color_mix
    with open(MANIFEST_PATH, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    assert 58.0 <= color_mix["sand_ivory"] <= 62.1
    assert 29.0 <= color_mix["gold"] <= 33.0
    assert 8.0 <= color_mix["blue"] <= 11.0
    print(f"CASTLE_GALAXY_BRIDGE_METADATA_REFRESH: PASS color_mix={color_mix}")


if __name__ == "__main__":
    if "--metadata-only" in sys.argv:
        refresh_metadata_only()
    elif "--materials-only" in sys.argv:
        refresh_materials_only()
    else:
        main()
