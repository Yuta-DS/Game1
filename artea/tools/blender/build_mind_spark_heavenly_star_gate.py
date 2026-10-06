"""Build the production-quality Mind Spark Heavenly Star Gate.

The .blend preserves the architectural assembly as individually named modules.
The GLB joins those modules into semantic runtime groups. Every delivered mesh
is bevelled where appropriate, smooth shaded, and explicitly triangulated.

Run:
    blender --background --python tools/blender/build_mind_spark_heavenly_star_gate.py
"""

from __future__ import annotations

import json
import math
from collections import Counter, OrderedDict
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
ASSET_ROOT = ROOT / "assets3D" / "mind_spark" / "heavenly_star_gate"
BLEND_PATH = ASSET_ROOT / "blend" / "mind_spark_heavenly_star_gate.blend"
GLB_PATH = ASSET_ROOT / "glb" / "mind_spark_heavenly_star_gate.glb"
MANIFEST_PATH = ASSET_ROOT / "mind_spark_heavenly_star_gate_manifest.json"
ARTIFACT_ROOT = ROOT / "artifacts" / "mind_spark_heavenly_star_gate_object"
HERO_PATH = ARTIFACT_ROOT / "heavenly_star_gate_hero.png"
DETAIL_PATH = ARTIFACT_ROOT / "heavenly_star_gate_hinge_detail.png"

PALETTE = OrderedDict(
    ivory=(0.965, 0.90, 0.77, 1.0),
    ivory_light=(1.0, 0.985, 0.93, 1.0),
    ivory_shadow=(0.72, 0.64, 0.52, 1.0),
    warm_gold=(0.94, 0.64, 0.20, 1.0),
    pale_gold=(1.0, 0.84, 0.42, 1.0),
    bronze=(0.42, 0.25, 0.13, 1.0),
    teal=(0.035, 0.42, 0.44, 1.0),
    aether=(0.25, 0.92, 0.96, 1.0),
    lavender=(0.66, 0.48, 0.84, 1.0),
)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def new_collection(name, parent=None):
    value = bpy.data.collections.new(name)
    (parent.children if parent else bpy.context.scene.collection.children).link(value)
    return value


def material(name, color, metallic=0.0, roughness=0.55, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = color
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if bsdf.inputs.get("Coat Weight"):
        bsdf.inputs["Coat Weight"].default_value = 0.22 if metallic else 0.10
        bsdf.inputs["Coat Roughness"].default_value = 0.18
    if emission:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission
    # Subtle object-space microstructure prevents large stone and metal fields
    # from reading as perfectly smooth plastic without requiring image textures.
    texcoord = mat.node_tree.nodes.new("ShaderNodeTexCoord")
    noise = mat.node_tree.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 5.0 if metallic == 0.0 else 22.0
    noise.inputs["Detail"].default_value = 3.0
    noise.inputs["Roughness"].default_value = 0.68
    bump = mat.node_tree.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.11 if metallic == 0.0 else 0.035
    bump.inputs["Distance"].default_value = 0.055 if metallic == 0.0 else 0.018
    mat.node_tree.links.new(texcoord.outputs["Generated"], noise.inputs["Vector"])
    mat.node_tree.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    mat.node_tree.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    if "AETHER" in name.upper() or "LAVENDER" in name.upper():
        if bsdf.inputs.get("Transmission Weight"):
            bsdf.inputs["Transmission Weight"].default_value = 0.22
        if bsdf.inputs.get("Coat Weight"):
            bsdf.inputs["Coat Weight"].default_value = 0.48
    return mat


def move(obj, target):
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    target.objects.link(obj)


def mark(obj, group, path):
    obj["semantic_group"] = group
    obj["component_path"] = path
    return obj


def finalize(obj, bevel=0.0, smooth=True):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if bevel:
        mod = obj.modifiers.new("Production edge radius", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    tri = obj.modifiers.new("Explicit triangle topology", "TRIANGULATE")
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    obj.select_set(False)
    return obj


def box(name, center, size, mat, target, group, path, bevel=0.08, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=center, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    move(obj, target)
    return mark(finalize(obj, bevel), group, path)


def cylinder(name, center, radius, depth, mat, target, group, path, vertices=24,
             rotation=(0, 0, 0), bevel=0.04):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                       location=center, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    move(obj, target)
    return mark(finalize(obj, bevel), group, path)


def sphere(name, center, radius, mat, target, group, path, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius,
                                         location=center)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    move(obj, target)
    return mark(finalize(obj, 0.025), group, path)


def torus(name, center, major, minor, mat, target, group, path,
          rotation=(math.pi / 2, 0, 0), major_segments=32, minor_segments=8):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                    major_segments=major_segments,
                                    minor_segments=minor_segments,
                                    location=center, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    move(obj, target)
    return mark(finalize(obj, 0.0), group, path)


def beam(name, start, end, thickness, depth, mat, target, group, path, bevel=0.04):
    start, end = Vector(start), Vector(end)
    delta = end - start
    obj = box(name, (start + end) * 0.5, (thickness, depth, delta.length), mat,
              target, group, path, bevel)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    bpy.context.view_layer.update()
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.select_set(False)
    return obj


def triangular_prism(name, points_xz, y, depth, mat, target, group, path):
    front, back = y - depth * 0.5, y + depth * 0.5
    verts = [(x, front, z) for x, z in points_xz] + [(x, back, z) for x, z in points_xz]
    faces = [(0, 2, 1), (3, 4, 5), (0, 1, 4), (0, 4, 3),
             (1, 2, 5), (1, 5, 4), (2, 0, 3), (2, 3, 5)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.data.materials.append(mat)
    target.objects.link(obj)
    return mark(finalize(obj, 0.035), group, path)


def arch_point(side, t, inner=False):
    # A slightly pointed heavenly arch: quadratic shoulders meet at a high apex.
    shoulder_x = side * (6.35 if inner else 7.25)
    shoulder_z = 12.6 if inner else 11.8
    apex_z = 24.3 if inner else 25.7
    control_x = side * (6.5 if inner else 7.6)
    control_z = 20.8 if inner else 21.9
    return Vector((
        shoulder_x * (1 - t) ** 2 + control_x * 2 * (1 - t) * t,
        -0.10,
        shoulder_z * (1 - t) ** 2 + control_z * 2 * (1 - t) * t + apex_z * t ** 2,
    ))


def build_foundation(parts, mats):
    path = "00_FOUNDATION"
    box("Foundation_Threshold_Core", (0, 0.4, 0.5), (25.5, 6.4, 1.0),
        mats["ivory_shadow"], parts, "FOUNDATION", path, 0.16)
    for tier, (w, d, h, z) in enumerate(((27.0, 7.0, 0.45, 0.18),
                                          (25.8, 6.5, 0.50, 0.60),
                                          (24.6, 5.8, 0.48, 1.05))):
        box(f"Foundation_SteppedCourse_{tier:02d}", (0, 0.2, z), (w, d, h),
            mats["ivory_light" if tier == 2 else "ivory"], parts,
            "FOUNDATION", path + "/STEPPED_PLINTH", 0.10)
    for side in (-1, 1):
        box(f"Foundation_LoadPad_{side:+d}", (side * 10.4, 0.15, 1.45),
            (6.6, 6.1, 0.72), mats["ivory_light"], parts, "FOUNDATION",
            path + "/LOAD_PADS", 0.14)
        for row in range(2):
            for col in range(5):
                cylinder(f"Foundation_AnchorBolt_{side:+d}_{row}_{col}",
                         (side * (8.45 + col * 0.95), -2.45 + row * 5.2, 1.91),
                         0.13, 0.18, mats["warm_gold"], parts, "MICRO_DETAIL",
                         path + "/ANCHOR_BOLTS", 12, bevel=0.02)
    for i in range(14):
        x = -11.7 + i * 1.8
        box(f"Threshold_Inlay_{i:02d}", (x, -2.87, 1.36), (1.25, 0.12, 0.16),
            mats["pale_gold"], parts, "TRIM", path + "/THRESHOLD_INLAY", 0.025)
    box("Foundation_MaintenanceHatch", (0, 2.92, 1.68), (4.8, 0.14, 2.1),
        mats["bronze"], parts, "MECHANISM", path + "/MAINTENANCE_HATCH", 0.10)
    for i in range(8):
        cylinder(f"Foundation_HatchRivet_{i:02d}",
                 (-2.0 + (i % 4) * 1.35, 2.81, 1.0 + (i // 4) * 1.35),
                 0.11, 0.12, mats["pale_gold"], parts, "MICRO_DETAIL",
                 path + "/MAINTENANCE_HATCH", 12, rotation=(math.pi / 2, 0, 0), bevel=0.015)


def build_pylon(parts, mats, side):
    sx = side * 10.4
    path = f"01_PYLONS/{'LEFT' if side < 0 else 'RIGHT'}"
    # Individually coursed, load-bearing stone shaft.
    for course in range(11):
        z = 2.45 + course * 1.52
        shift = (0.16 if course % 2 else -0.16) * side
        box(f"Pylon_{side:+d}_Course_{course:02d}_Core", (sx + shift, 0.35, z),
            (5.3 - course * 0.045, 5.0, 1.38), mats["ivory"], parts,
            "PYLON_STONE", path + "/MASONRY_COURSES", 0.095)
        # Face blocks make the bond and scale legible from player height.
        for block in range(3):
            box(f"Pylon_{side:+d}_Course_{course:02d}_FaceBlock_{block}",
                (sx - 1.62 + block * 1.62, -2.24, z), (1.43, 0.17, 1.08),
                mats["ivory_light" if (course + block) % 2 else "ivory"], parts,
                "PYLON_STONE", path + "/FACE_BLOCKS", 0.055)
    for tier, (w, d, h, z) in enumerate(((6.3, 5.8, 0.46, 18.95),
                                          (5.65, 5.3, 0.42, 19.40),
                                          (4.95, 4.8, 0.55, 19.88))):
        box(f"Pylon_{side:+d}_Capital_{tier}", (sx, 0.3, z), (w, d, h),
            mats["ivory_light"], parts, "PYLON_STONE", path + "/CAPITAL", 0.09)
    # Deep teal service panel, gold frame and triangular celestial reliefs.
    box(f"Pylon_{side:+d}_ServiceRecess", (sx, -2.39, 10.4), (3.3, 0.20, 8.5),
        mats["teal"], parts, "AETHER_GLASS", path + "/SERVICE_RECESS", 0.14)
    for xoff in (-1.72, 1.72):
        box(f"Pylon_{side:+d}_RecessJamb_{xoff:+.2f}", (sx + xoff, -2.56, 10.4),
            (0.23, 0.18, 9.0), mats["warm_gold"], parts, "TRIM",
            path + "/SERVICE_RECESS", 0.035)
    for z in (6.2, 10.4, 14.6):
        triangular_prism(f"Pylon_{side:+d}_CelestialRelief_{z:.1f}",
                         ((sx - 1.15, z - 0.95), (sx + 1.15, z - 0.95), (sx, z + 1.05)),
                         -2.62, 0.14, mats["pale_gold"], parts, "TRIM",
                         path + "/CELESTIAL_RELIEFS")
        sphere(f"Pylon_{side:+d}_ReliefPearl_{z:.1f}", (sx, -2.76, z - 0.15),
               0.24, mats["aether"], parts, "AETHER_GLASS", path + "/CELESTIAL_RELIEFS")
    # Lantern crown reads as heavenly civic architecture, not a generic tower.
    cylinder(f"Pylon_{side:+d}_LanternDrum", (sx, 0.3, 20.75), 2.0, 1.15,
             mats["warm_gold"], parts, "TRIM", path + "/LANTERN_CROWN", 32, bevel=0.08)
    cylinder(f"Pylon_{side:+d}_LanternGlass", (sx, 0.3, 22.35), 1.55, 2.25,
             mats["aether"], parts, "AETHER_GLASS", path + "/LANTERN_CROWN", 24, bevel=0.06)
    for rib in range(8):
        angle = math.tau * rib / 8
        x = sx + math.cos(angle) * 1.58
        y = 0.3 + math.sin(angle) * 1.58
        beam(f"Pylon_{side:+d}_LanternRib_{rib:02d}", (x, y, 21.2), (x, y, 23.5),
             0.13, 0.13, mats["pale_gold"], parts, "TRIM", path + "/LANTERN_CROWN", 0.02)
    cylinder(f"Pylon_{side:+d}_LanternCap", (sx, 0.3, 23.72), 1.88, 0.48,
             mats["ivory_light"], parts, "PYLON_STONE", path + "/LANTERN_CROWN", 24, bevel=0.07)
    sphere(f"Pylon_{side:+d}_CrownOrb", (sx, 0.3, 24.55), 0.55,
           mats["pale_gold"], parts, "TRIM", path + "/LANTERN_CROWN")
    beam(f"Pylon_{side:+d}_Finial", (sx, 0.3, 24.95), (sx, 0.3, 26.2), 0.18, 0.18,
         mats["pale_gold"], parts, "TRIM", path + "/LANTERN_CROWN", 0.02)


def build_gear(parts, mats, side):
    cx, cy, cz = side * 8.0, -3.05, 7.0
    path = f"02_HINGE_ENGINES/{'LEFT' if side < 0 else 'RIGHT'}"
    box(f"Hinge_{side:+d}_Backplate", (cx, cy + 0.28, cz), (5.3, 0.48, 8.2),
        mats["bronze"], parts, "MECHANISM", path + "/BACKPLATE", 0.16)
    # Ivory segmented engine hood embeds the wheel in the pylon instead of
    # making it appear glued onto a flat plate.
    for hood_index in range(9):
        hood_angle = math.radians(20 + hood_index * 17.5)
        hood_x = cx + math.cos(hood_angle) * 3.05
        hood_z = cz + 0.65 + math.sin(hood_angle) * 3.05
        box(f"Hinge_{side:+d}_IvoryHood_{hood_index:02d}",
            (hood_x, cy - 0.02, hood_z), (0.78, 0.78, 0.46),
            mats["ivory_light"], parts, "PYLON_STONE", path + "/ENGINE_HOOD",
            0.08, rotation=(0, hood_angle, 0))
        sphere(f"Hinge_{side:+d}_HoodFastener_{hood_index:02d}",
               (hood_x, cy - 0.48, hood_z), 0.09, mats["pale_gold"], parts,
               "MICRO_DETAIL", path + "/ENGINE_HOOD", 1)
    box(f"Hinge_{side:+d}_EngineSill", (cx, cy + 0.05, cz - 2.55),
        (5.8, 1.10, 0.72), mats["ivory_light"], parts, "PYLON_STONE",
        path + "/ENGINE_HOOD", 0.12)
    torus(f"Hinge_{side:+d}_FlywheelOuter", (cx, cy - 0.16, cz + 0.65), 2.38, 0.27,
          mats["pale_gold"], parts, "MECHANISM", path + "/FLYWHEEL")
    torus(f"Hinge_{side:+d}_FlywheelInner", (cx, cy - 0.25, cz + 0.65), 1.72, 0.16,
          mats["warm_gold"], parts, "MECHANISM", path + "/FLYWHEEL")
    cylinder(f"Hinge_{side:+d}_Hub", (cx, cy - 0.44, cz + 0.65), 0.65, 0.68,
             mats["ivory_light"], parts, "MECHANISM", path + "/FLYWHEEL", 24,
             rotation=(math.pi / 2, 0, 0), bevel=0.08)
    for spoke in range(10):
        a = math.tau * spoke / 10
        beam(f"Hinge_{side:+d}_Spoke_{spoke:02d}", (cx, cy - 0.48, cz + 0.65),
             (cx + math.cos(a) * 2.15, cy - 0.48, cz + 0.65 + math.sin(a) * 2.15),
             0.16, 0.16, mats["warm_gold"], parts, "MECHANISM", path + "/FLYWHEEL", 0.025)
    for tooth in range(12):
        a = math.tau * tooth / 12
        x, z = cx + math.cos(a) * 2.78, cz + 0.65 + math.sin(a) * 2.78
        box(f"Hinge_{side:+d}_Tooth_{tooth:02d}", (x, cy - 0.15, z),
            (0.62, 0.62, 0.34), mats["pale_gold"], parts, "MECHANISM",
            path + "/GEAR_TEETH", 0.06, rotation=(0, a, 0))
    # Pressure chamber and readable maintenance fittings.
    cylinder(f"Hinge_{side:+d}_PressureChamber", (cx, cy - 0.30, 3.35), 1.12, 2.7,
             mats["teal"], parts, "MECHANISM", path + "/PRESSURE_CHAMBER", 24, bevel=0.10)
    for z in (2.25, 3.35, 4.45):
        torus(f"Hinge_{side:+d}_ChamberBand_{z:.2f}", (cx, cy - 0.30, z), 1.12, 0.11,
              mats["pale_gold"], parts, "MECHANISM", path + "/PRESSURE_CHAMBER",
              rotation=(0, 0, 0), major_segments=24)
    for bolt in range(8):
        a = math.tau * bolt / 8
        sphere(f"Hinge_{side:+d}_HubBolt_{bolt:02d}",
               (cx + math.cos(a) * 0.42, cy - 0.82, cz + 0.65 + math.sin(a) * 0.42),
               0.105, mats["bronze"], parts, "MICRO_DETAIL", path + "/FASTENERS", 1)
    # Brake pawl and power pipe give the flywheel mechanical purpose.
    beam(f"Hinge_{side:+d}_BrakePawl", (cx + side * 1.55, cy - 0.62, cz + 3.1),
         (cx + side * 2.35, cy - 0.62, cz + 1.8), 0.28, 0.32, mats["bronze"],
         parts, "MECHANISM", path + "/BRAKE", 0.05)
    for segment, (z0, z1) in enumerate(((4.6, 7.0), (7.0, 10.1))):
        beam(f"Hinge_{side:+d}_PowerPipe_{segment}",
             (cx + side * 2.15, -3.35, z0), (cx + side * 2.15, -3.35, z1),
             0.34, 0.34, mats["warm_gold"], parts, "MECHANISM", path + "/POWER_PIPE", 0.06)
        torus(f"Hinge_{side:+d}_PipeCollar_{segment}",
              (cx + side * 2.15, -3.35, z1), 0.34, 0.09, mats["pale_gold"], parts,
              "MICRO_DETAIL", path + "/POWER_PIPE", rotation=(0, 0, 0), major_segments=16)


def build_gate_leaf(parts, mats, side):
    path = f"03_GATE_LEAVES/{'LEFT' if side < 0 else 'RIGHT'}"
    leaf_group = "GATE_LEAF_LEFT" if side < 0 else "GATE_LEAF_RIGHT"
    inner, outer = 0.18 * side, 6.15 * side
    # Structural silhouette narrows toward the center, avoiding a plain rectangle.
    outline = [(outer, 2.0), (outer, 12.6), (side * 4.8, 17.1),
               (side * 1.2, 21.8), (inner, 20.3), (inner, 2.0)]
    for index in range(len(outline)):
        x0, z0 = outline[index]
        x1, z1 = outline[(index + 1) % len(outline)]
        beam(f"Leaf_{side:+d}_Perimeter_{index:02d}", (x0, -2.55, z0), (x1, -2.55, z1),
             0.42, 0.55, mats["warm_gold"], parts, leaf_group, path + "/PERIMETER", 0.07)
    box(f"Leaf_{side:+d}_LoadSpine", (side * 5.78, -2.52, 8.3), (0.70, 0.62, 12.4),
        mats["bronze"], parts, leaf_group, path + "/LOAD_SPINE", 0.10)
    # Six ribs subdivide the leaf into gameplay-readable facets.
    for rib in range(6):
        t = (rib + 1) / 7
        x = outer * (1 - t) + inner * t
        top = 12.6 * (1 - t) + (20.3 + 1.5 * math.sin(t * math.pi)) * t
        beam(f"Leaf_{side:+d}_RadialRib_{rib:02d}", (outer, -2.62, 2.15),
             (x, -2.62, top), 0.20, 0.26, mats["pale_gold"], parts,
             leaf_group, path + "/RADIAL_RIBS", 0.035)
    # Triangular aether panes make the surface detailed without becoming opaque.
    for row in range(5):
        z0 = 3.0 + row * 2.72
        for col in range(3):
            xa = side * (0.62 + col * 1.65)
            xb = side * (1.32 + col * 1.65)
            xc = side * (0.97 + col * 1.65)
            triangular_prism(f"Leaf_{side:+d}_AetherFacet_{row:02d}_{col:02d}",
                             ((xa, z0), (xb, z0 + 0.45), (xc, z0 + 2.0)),
                             -2.36, 0.11, mats["teal" if (row + col) % 2 else "aether"],
                             parts, leaf_group, path + "/TRIANGULAR_FACETS")
    # Mirrored half-medallions become one Star of Wisdom when the leaves close.
    center = (0, -2.78, 10.8)
    torus(f"Leaf_{side:+d}_MedallionHalo", center, 3.0, 0.18, mats["pale_gold"],
          parts, leaf_group, path + "/STAR_MEDALLION", major_segments=40)
    for ray in range(8):
        a = math.tau * ray / 8 + math.pi / 8
        end = (math.cos(a) * 2.7, -2.82, 10.8 + math.sin(a) * 2.7)
        if (end[0] <= 0 and side < 0) or (end[0] >= 0 and side > 0):
            beam(f"Leaf_{side:+d}_MedallionRay_{ray:02d}", center, end, 0.20, 0.16,
                 mats["pale_gold"], parts, leaf_group, path + "/STAR_MEDALLION", 0.025)
    for z in (3.0, 6.8, 14.8, 18.2):
        cylinder(f"Leaf_{side:+d}_HingeKnuckle_{z:.1f}", (side * 6.08, -2.30, z),
                 0.42, 1.35, mats["pale_gold"], parts, leaf_group,
                 path + "/HINGE_KNUCKLES", 20, bevel=0.055)


def build_crown(parts, mats):
    path = "04_CROWN_ARCH"
    # 18 independent wedge-like spans per side reveal real construction logic.
    for side in (-1, 1):
        previous_outer = arch_point(side, 0.0, False)
        previous_inner = arch_point(side, 0.0, True)
        for segment in range(18):
            t = (segment + 1) / 18
            outer = arch_point(side, t, False)
            inner = arch_point(side, t, True)
            beam(f"Crown_{side:+d}_OuterVoussoir_{segment:02d}", previous_outer,
                 outer, 0.78, 1.10, mats["ivory_light" if segment % 2 else "ivory"],
                 parts, "CROWN_STONE", path + "/OUTER_VOUSSOIRS", 0.08)
            beam(f"Crown_{side:+d}_InnerGoldOrder_{segment:02d}", previous_inner,
                 inner, 0.25, 0.30, mats["pale_gold"], parts, "TRIM",
                 path + "/GOLD_ORDER", 0.035)
            # Radial joint/boss at each construction seam.
            sphere(f"Crown_{side:+d}_JointBoss_{segment:02d}",
                   tuple(outer + Vector((0, -0.72, 0))), 0.12, mats["warm_gold"],
                   parts, "MICRO_DETAIL", path + "/JOINT_BOSSES", 1)
            previous_outer, previous_inner = outer, inner
    for side in (-1, 1):
        box(f"Crown_SpringBlock_{side:+d}", (side * 7.15, 0.0, 11.65),
            (2.05, 2.3, 1.4), mats["ivory_light"], parts, "CROWN_STONE",
            path + "/SPRING_BLOCKS", 0.14)
    triangular_prism("Crown_Keystone", ((-1.15, 23.45), (1.15, 23.45), (0, 26.7)),
                     -0.72, 1.45, mats["ivory_light"], parts, "CROWN_STONE",
                     path + "/KEYSTONE")
    triangular_prism("Crown_KeystoneGoldInlay", ((-0.48, 24.0), (0.48, 24.0), (0, 26.0)),
                     -1.52, 0.16, mats["pale_gold"], parts, "TRIM", path + "/KEYSTONE")


def build_power_star(parts, mats):
    path = "05_POWER_STAR"
    center = Vector((0, -1.70, 27.65))
    # Twelve translucent crystalline petals turn the star into a celestial
    # wisdom flower rather than a conventional clock/astrolabe dial.
    for petal in range(12):
        angle = math.tau * petal / 12
        perpendicular = Vector((-math.sin(angle), 0, math.cos(angle)))
        radial = Vector((math.cos(angle), 0, math.sin(angle)))
        base = center + radial * 0.92
        tip = center + radial * (3.15 if petal % 2 == 0 else 2.72)
        points = (
            (base.x + perpendicular.x * 0.48, base.z + perpendicular.z * 0.48),
            (base.x - perpendicular.x * 0.48, base.z - perpendicular.z * 0.48),
            (tip.x, tip.z),
        )
        triangular_prism(f"PowerStar_CrystalPetal_{petal:02d}", points,
                         center.y - 0.34, 0.18,
                         mats["aether" if petal % 2 == 0 else "lavender"],
                         parts, "POWER_STAR", path + "/CRYSTAL_FLOWER")
    for index, (radius, minor, mat) in enumerate(((3.7, 0.20, mats["pale_gold"]),
                                                   (2.85, 0.12, mats["warm_gold"]),
                                                   (1.62, 0.13, mats["pale_gold"]))):
        torus(f"PowerStar_Halo_{index}", center, radius, minor, mat, parts,
              "POWER_STAR", path + "/HALOS", major_segments=48)
    for ray in range(16):
        angle = math.tau * ray / 16
        length = 4.65 if ray % 2 == 0 else 4.08
        start = center + Vector((math.cos(angle) * 1.0, 0, math.sin(angle) * 1.0))
        end = center + Vector((math.cos(angle) * length, 0, math.sin(angle) * length))
        beam(f"PowerStar_Ray_{ray:02d}", start, end,
             0.30 if ray % 2 == 0 else 0.18, 0.22, mats["pale_gold"], parts,
             "POWER_STAR", path + "/RAYS", 0.035)
        sphere(f"PowerStar_RayPearl_{ray:02d}", tuple(end), 0.18 if ray % 2 == 0 else 0.12,
               mats["aether"], parts, "POWER_STAR", path + "/RAYS", 1)
    sphere("PowerStar_AetherCore", center, 1.18, mats["aether"], parts,
           "POWER_STAR", path + "/CORE", 3)
    sphere("PowerStar_WisdomSeed", (0, -2.75, 27.65), 0.48, mats["ivory_light"],
           parts, "POWER_STAR", path + "/CORE", 2)
    # Three orbit sockets communicate the three coupled player choices.
    for orbit, radius in enumerate((2.05, 2.78, 3.52)):
        angle = math.radians((orbit * 113) + 25)
        point = center + Vector((math.cos(angle) * radius, -0.55, math.sin(angle) * radius))
        torus(f"PowerStar_OrbitSocket_{orbit}", point, 0.34, 0.09,
              mats["lavender" if orbit == 0 else "aether"], parts,
              "POWER_STAR", path + "/ORBIT_SOCKETS", major_segments=20)


def build_conduits(parts, mats):
    path = "06_POWER_CONDUITS"
    for side in (-1, 1):
        points = [
            (side * 8.0, -3.50, 1.9),
            (side * 8.0, -3.50, 4.2),
            (side * 6.8, -3.50, 10.8),
            (side * 6.2, -3.50, 17.0),
            (side * 3.4, -3.50, 23.9),
            (side * 1.0, -3.50, 27.0),
        ]
        for i in range(len(points) - 1):
            beam(f"Conduit_{side:+d}_Run_{i:02d}", points[i], points[i + 1], 0.24, 0.24,
                 mats["warm_gold"], parts, "MECHANISM", path + "/MAIN_RUN", 0.05)
            torus(f"Conduit_{side:+d}_Collar_{i:02d}", points[i], 0.25, 0.075,
                  mats["pale_gold"], parts, "MICRO_DETAIL", path + "/COLLARS",
                  rotation=(0, 0, 0), major_segments=16)
        for index in range(9):
            z = 3.0 + index * 1.7
            sphere(f"Conduit_{side:+d}_EnergyNode_{index:02d}",
                   (side * 6.45, -3.72, z), 0.12, mats["aether"], parts,
                   "AETHER_GLASS", path + "/ENERGY_NODES", 1)


def build_v2_foundation(parts, mats):
    path = "00_FOUNDATION"
    courses = (
        (30.0, 8.4, 0.38, 0.18, "ivory_shadow"),
        (29.2, 7.8, 0.34, 0.54, "ivory"),
        (28.4, 7.2, 0.30, 0.86, "ivory_light"),
        (27.3, 6.6, 0.26, 1.14, "warm_gold"),
        (26.7, 6.2, 0.30, 1.42, "ivory_light"),
    )
    for index, (width, depth, height, z, material_name) in enumerate(courses):
        box(f"V2_ThresholdCourse_{index:02d}", (0, 0.25, z),
            (width, depth, height), mats[material_name], parts, "FOUNDATION",
            path + "/PROCESSIONAL_PLINTH", 0.09)
    for side in (-1, 0, 1):
        box(f"V2_ThresholdInlay_{side:+d}", (side * 7.9, -2.94, 1.63),
            (6.2, 0.10, 0.16), mats["pale_gold"], parts, "TRIM",
            path + "/THRESHOLD_INLAYS", 0.025)
        for boss in range(5):
            sphere(f"V2_ThresholdBoss_{side:+d}_{boss:02d}",
                   (side * 7.9 - 2.45 + boss * 1.22, -3.08, 1.64), 0.09,
                   mats["aether"], parts, "MICRO_DETAIL",
                   path + "/THRESHOLD_INLAYS", 1)
    for side in (-1, 1):
        for tier, (width, depth, height, z) in enumerate(((7.7, 7.0, 0.54, 1.68),
                                                          (7.0, 6.4, 0.46, 2.16),
                                                          (6.3, 5.8, 0.42, 2.58))):
            box(f"V2_BearingPad_{side:+d}_{tier}", (side * 11.1, 0.3, z),
                (width, depth, height), mats["ivory_light" if tier == 2 else "ivory"],
                parts, "FOUNDATION", path + "/BEARING_PADS", 0.12)
        for bolt in range(8):
            angle = math.tau * bolt / 8
            sphere(f"V2_BearingBolt_{side:+d}_{bolt:02d}",
                   (side * 11.1 + math.cos(angle) * 2.45,
                    0.3 + math.sin(angle) * 2.05, 2.84), 0.11,
                   mats["bronze"], parts, "MICRO_DETAIL",
                   path + "/BEARING_PADS", 1)


def build_v2_pylon(parts, mats, side):
    sx = side * 11.1
    path = f"01_PYLONS/{'LEFT' if side < 0 else 'RIGHT'}"
    for course in range(9):
        z = 3.3 + course * 1.72
        width = 5.85 - course * 0.075
        box(f"V2_Pylon_{side:+d}_Course_{course:02d}", (sx, 0.35, z),
            (width, 5.15, 1.52), mats["ivory_light" if course % 3 == 2 else "ivory"],
            parts, "PYLON_STONE", path + "/ASHLAR_SHAFT", 0.10)
        for block in range(3):
            block_x = sx + (block - 1) * 1.72 + (0.24 * side if course % 2 else 0)
            box(f"V2_Pylon_{side:+d}_FaceStone_{course:02d}_{block}",
                (block_x, -2.30, z), (1.45, 0.16, 1.18), mats["ivory_light"],
                parts, "PYLON_STONE", path + "/FACE_STONES", 0.055)
    box(f"V2_Pylon_{side:+d}_MachineRecess", (sx, -2.44, 10.15),
        (3.55, 0.24, 9.7), mats["teal"], parts, "AETHER_GLASS",
        path + "/MACHINE_RECESS", 0.15)
    for xoff in (-1.92, 1.92):
        box(f"V2_Pylon_{side:+d}_RecessJamb_{xoff:+.2f}",
            (sx + xoff, -2.58, 10.15), (0.30, 0.22, 10.15), mats["pale_gold"],
            parts, "TRIM", path + "/MACHINE_RECESS", 0.04)
    for tier, (width, depth, height, z) in enumerate(((6.45, 5.70, 0.48, 18.95),
                                                      (5.85, 5.25, 0.44, 19.42),
                                                      (5.25, 4.80, 0.56, 19.92))):
        box(f"V2_Pylon_{side:+d}_Capital_{tier}", (sx, 0.3, z),
            (width, depth, height), mats["ivory_light"], parts,
            "PYLON_STONE", path + "/CAPITAL", 0.10)
    cylinder(f"V2_Pylon_{side:+d}_LanternBase", (sx, 0.3, 20.65), 1.72, 0.78,
             mats["warm_gold"], parts, "TRIM", path + "/LANTERN", 24, bevel=0.07)
    cylinder(f"V2_Pylon_{side:+d}_LanternLens", (sx, 0.3, 22.05), 1.36, 2.15,
             mats["aether"], parts, "AETHER_GLASS", path + "/LANTERN", 12, bevel=0.05)
    for rib in range(6):
        angle = math.tau * rib / 6
        x, y = sx + math.cos(angle) * 1.39, 0.3 + math.sin(angle) * 1.39
        beam(f"V2_Pylon_{side:+d}_LanternRib_{rib:02d}", (x, y, 20.95),
             (x, y, 23.18), 0.13, 0.13, mats["pale_gold"], parts, "TRIM",
             path + "/LANTERN", 0.02)
    cylinder(f"V2_Pylon_{side:+d}_LanternCap", (sx, 0.3, 23.36), 1.64, 0.42,
             mats["ivory_light"], parts, "PYLON_STONE", path + "/LANTERN", 24,
             bevel=0.06)
    sphere(f"V2_Pylon_{side:+d}_FinialOrb", (sx, 0.3, 24.05), 0.40,
           mats["pale_gold"], parts, "TRIM", path + "/LANTERN", 2)
    beam(f"V2_Pylon_{side:+d}_FinialNeedle", (sx, 0.3, 24.35),
         (sx, 0.3, 25.25), 0.12, 0.12, mats["pale_gold"], parts, "TRIM",
         path + "/LANTERN", 0.015)


def build_v2_engine(parts, mats, side):
    cx, cy = side * 11.1, -2.86
    path = f"02_HINGE_ENGINES/{'LEFT' if side < 0 else 'RIGHT'}"
    cylinder(f"V2_Engine_{side:+d}_PressureVessel", (cx, cy, 5.3), 1.08, 4.4,
             mats["bronze"], parts, "MECHANISM", path + "/PRESSURE_VESSEL", 24,
             bevel=0.09)
    for z in (3.2, 4.25, 5.30, 6.35, 7.4):
        torus(f"V2_Engine_{side:+d}_VesselBand_{z:.2f}", (cx, cy, z), 1.08,
              0.10, mats["pale_gold"], parts, "MECHANISM",
              path + "/PRESSURE_VESSEL", rotation=(0, 0, 0), major_segments=24)
    sphere(f"V2_Engine_{side:+d}_VesselLens", (cx, cy - 1.13, 5.3), 0.38,
           mats["aether"], parts, "AETHER_GLASS", path + "/PRESSURE_VESSEL", 2)
    wheel_z = 10.9
    torus(f"V2_Engine_{side:+d}_FlywheelOuter", (cx, cy - 0.08, wheel_z),
          2.05, 0.25, mats["pale_gold"], parts, "MECHANISM", path + "/FLYWHEEL")
    torus(f"V2_Engine_{side:+d}_FlywheelInner", (cx, cy - 0.14, wheel_z),
          1.40, 0.13, mats["warm_gold"], parts, "MECHANISM", path + "/FLYWHEEL")
    cylinder(f"V2_Engine_{side:+d}_FlywheelHub", (cx, cy - 0.30, wheel_z),
             0.48, 0.54, mats["ivory_light"], parts, "MECHANISM", path + "/FLYWHEEL",
             20, rotation=(math.pi / 2, 0, 0), bevel=0.06)
    for spoke in range(8):
        angle = math.tau * spoke / 8
        beam(f"V2_Engine_{side:+d}_Spoke_{spoke:02d}", (cx, cy - 0.34, wheel_z),
             (cx + math.cos(angle) * 1.78, cy - 0.34,
              wheel_z + math.sin(angle) * 1.78), 0.14, 0.14,
             mats["warm_gold"], parts, "MECHANISM", path + "/FLYWHEEL", 0.02)
    beam(f"V2_Engine_{side:+d}_ConnectingRod", (cx, cy - 0.48, 7.45),
         (cx + side * 1.25, cy - 0.48, 9.45), 0.25, 0.22,
         mats["pale_gold"], parts, "MECHANISM", path + "/DRIVE_TRAIN", 0.04)
    beam(f"V2_Engine_{side:+d}_LockBar", (cx + side * 1.25, cy - 0.45, 9.45),
         (side * 6.55, cy - 0.45, 9.45), 0.30, 0.24,
         mats["pale_gold"], parts, "MECHANISM", path + "/DRIVE_TRAIN", 0.045)
    for bolt in range(8):
        angle = math.tau * bolt / 8
        sphere(f"V2_Engine_{side:+d}_HubBolt_{bolt:02d}",
               (cx + math.cos(angle) * 0.32, cy - 0.65,
                wheel_z + math.sin(angle) * 0.32), 0.075, mats["bronze"],
               parts, "MICRO_DETAIL", path + "/FASTENERS", 1)


def build_v2_leaf(parts, mats, side):
    path = f"03_GATE_LEAVES/{'LEFT' if side < 0 else 'RIGHT'}"
    group = "GATE_LEAF_LEFT" if side < 0 else "GATE_LEAF_RIGHT"
    outer_x, seam_x = side * 6.45, side * 0.18
    outline = [(outer_x, 2.0), (outer_x, 13.0), (side * 4.8, 17.0),
               (side * 1.15, 21.15), (seam_x, 20.0), (seam_x, 2.0)]
    for index in range(len(outline)):
        start, finish = outline[index], outline[(index + 1) % len(outline)]
        beam(f"V2_Leaf_{side:+d}_Frame_{index:02d}",
             (start[0], -2.50, start[1]), (finish[0], -2.50, finish[1]),
             0.46, 0.52, mats["pale_gold"], parts, group,
             path + "/PERIMETER_FRAME", 0.07)
    box(f"V2_Leaf_{side:+d}_HingeSpine", (side * 6.12, -2.45, 9.15),
        (0.82, 0.66, 14.2), mats["ivory_light"], parts, group,
        path + "/HINGE_SPINE", 0.11)
    cells = ((3.0, 7.0, 4.6), (7.6, 12.0, 3.8), (12.7, 17.3, 2.9))
    for index, (z0, z1, width) in enumerate(cells):
        cx = side * (3.25 if index < 2 else 2.45)
        box(f"V2_Leaf_{side:+d}_AetherPanel_{index}", (cx, -2.41, (z0 + z1) * 0.5),
            (width, 0.13, z1 - z0), mats["teal"],
            parts, group, path + "/AETHER_PANELS", 0.16)
        for edge in (-1, 1):
            beam(f"V2_Leaf_{side:+d}_PanelRail_{index}_{edge:+d}",
                 (cx + side * edge * width * 0.43, -2.61, z0 + 0.25),
                 (cx + side * edge * width * 0.43, -2.61, z1 - 0.25),
                 0.16, 0.18, mats["warm_gold"], parts, group,
                 path + "/PANEL_FRAMES", 0.025)
        beam(f"V2_Leaf_{side:+d}_PanelBrace_{index}",
             (cx - side * width * 0.38, -2.64, z0 + 0.35),
             (cx + side * width * 0.38, -2.64, z1 - 0.35),
             0.14, 0.16, mats["pale_gold"], parts, group,
             path + "/PANEL_FRAMES", 0.02)
        sphere(f"V2_Leaf_{side:+d}_PanelPearl_{index}",
               (cx, -2.73, (z0 + z1) * 0.5), 0.20, mats["aether"],
               parts, group, path + "/PANEL_FRAMES", 2)
    center = Vector((0, -2.76, 10.6))
    for ray in range(6):
        angle = math.tau * ray / 6 + math.pi / 6
        end = center + Vector((math.cos(angle) * 2.3, 0, math.sin(angle) * 2.3))
        if (end.x <= 0 and side < 0) or (end.x >= 0 and side > 0):
            beam(f"V2_Leaf_{side:+d}_WisdomRay_{ray}", center, end,
                 0.24, 0.18, mats["pale_gold"], parts, group,
                 path + "/WISDOM_SEAL", 0.03)
    for z in (3.2, 7.2, 11.2, 15.2):
        cylinder(f"V2_Leaf_{side:+d}_Hinge_{z:.1f}", (side * 6.25, -2.25, z),
                 0.38, 1.2, mats["warm_gold"], parts, group,
                 path + "/HINGES", 18, bevel=0.05)


def build_v2_crown(parts, mats):
    path = "04_CROWN_ARCH"
    for side in (-1, 1):
        previous_outer = arch_point(side, 0.0, False)
        previous_inner = arch_point(side, 0.0, True)
        for segment in range(12):
            t = (segment + 1) / 12
            outer, inner = arch_point(side, t, False), arch_point(side, t, True)
            beam(f"V2_Crown_{side:+d}_Voussoir_{segment:02d}", previous_outer,
                 outer, 0.92, 1.30, mats["ivory_light" if segment % 2 else "ivory"],
                 parts, "CROWN_STONE", path + "/VOUSSOIRS", 0.10)
            beam(f"V2_Crown_{side:+d}_GoldOrder_{segment:02d}", previous_inner,
                 inner, 0.22, 0.24, mats["pale_gold"], parts, "TRIM",
                 path + "/INNER_ORDER", 0.03)
            if segment % 2 == 0:
                sphere(f"V2_Crown_{side:+d}_Joint_{segment:02d}",
                       tuple(outer + Vector((0, -0.78, 0))), 0.105,
                       mats["bronze"], parts, "MICRO_DETAIL",
                       path + "/CONSTRUCTION_JOINTS", 1)
            previous_outer, previous_inner = outer, inner
        box(f"V2_Crown_{side:+d}_SpringBlock", (side * 7.1, 0.0, 11.9),
            (2.15, 2.55, 1.55), mats["ivory_light"], parts, "CROWN_STONE",
            path + "/SPRING_BLOCKS", 0.14)
    triangular_prism("V2_CrownKeystone", ((-1.35, 23.1), (1.35, 23.1), (0, 26.15)),
                     -0.75, 1.55, mats["ivory_light"], parts, "CROWN_STONE",
                     path + "/KEYSTONE")
    triangular_prism("V2_CrownKeystoneInlay", ((-0.52, 23.65), (0.52, 23.65), (0, 25.45)),
                     -1.58, 0.16, mats["pale_gold"], parts, "TRIM",
                     path + "/KEYSTONE")


def build_v2_power_crown(parts, mats):
    path = "05_POWER_STAR"
    center = Vector((0, -1.78, 27.35))
    # Eight faceted petals form an unmistakable heavenly flower/crest. There is
    # deliberately no circular dial or evenly-spoked clock face.
    for petal in range(8):
        angle = math.tau * petal / 8 + math.pi / 8
        radial = Vector((math.cos(angle), 0, math.sin(angle)))
        tangent = Vector((-math.sin(angle), 0, math.cos(angle)))
        base = center + radial * 0.52
        tip = center + radial * (3.25 if petal in (1, 2, 5, 6) else 2.65)
        points = ((base.x + tangent.x * 0.58, base.z + tangent.z * 0.58),
                  (base.x - tangent.x * 0.58, base.z - tangent.z * 0.58),
                  (tip.x, tip.z))
        triangular_prism(f"V2_WisdomCrownPetal_{petal:02d}", points,
                         center.y - 0.22, 0.22,
                         mats["ivory_light" if petal % 2 == 0 else "lavender"],
                         parts, "POWER_STAR", path + "/WISDOM_FLOWER")
        beam(f"V2_WisdomCrownPetalSpine_{petal:02d}", tuple(center), tuple(tip),
             0.13, 0.14, mats["pale_gold"], parts, "POWER_STAR",
             path + "/WISDOM_FLOWER", 0.02)
        sphere(f"V2_WisdomCrownPearl_{petal:02d}", tuple(tip), 0.13,
               mats["aether"], parts, "POWER_STAR", path + "/WISDOM_FLOWER", 1)
    sphere("V2_WisdomCrownCore", center, 0.82, mats["aether"], parts,
           "POWER_STAR", path + "/CORE", 3)
    for socket in range(3):
        angle = math.radians(210 + socket * 60)
        point = center + Vector((math.cos(angle) * 1.55, -0.38, math.sin(angle) * 1.55))
        torus(f"V2_WisdomCrownSocket_{socket}", point, 0.26, 0.07,
              mats["lavender" if socket == 1 else "aether"], parts,
              "POWER_STAR", path + "/PUZZLE_SOCKETS", major_segments=18)


def build_v2_conduits(parts, mats):
    path = "06_POWER_CONDUITS"
    for side in (-1, 1):
        # Power is routed behind the stone order; only the luminous junctions
        # peek through dedicated reveals instead of drawing lines over the facade.
        start = (side * 11.1, 1.85, 3.0)
        finish = (side * 11.1, 1.85, 18.1)
        beam(f"V2_Conduit_{side:+d}_VerticalBus", start, finish,
             0.25, 0.23, mats["warm_gold"], parts, "MECHANISM",
             path + "/POWER_SPINE", 0.045)
        for node_index, z in enumerate((4.0, 10.5, 17.0)):
            sphere(f"V2_ConduitNode_{side:+d}_{node_index}",
                   (side * 11.1, 1.70, z), 0.13, mats["aether"], parts,
                   "AETHER_GLASS", path + "/POWER_SPINE", 1)


def hierarchy(parts):
    coll = new_collection("MSHG_COMPONENT_HIERARCHY")
    root = bpy.data.objects.new("00_MIND_SPARK_HEAVENLY_STAR_GATE", None)
    coll.objects.link(root)
    nodes = {}
    for index, name in enumerate(("00_FOUNDATION", "01_PYLONS", "02_HINGE_ENGINES",
                                  "03_GATE_LEAVES", "04_CROWN_ARCH", "05_POWER_STAR",
                                  "06_POWER_CONDUITS")):
        node = bpy.data.objects.new(name, None)
        coll.objects.link(node)
        node.parent = root
        nodes[name] = node
    for obj in parts.objects:
        if obj.type != "MESH":
            continue
        prefix = str(obj.get("component_path", "00_FOUNDATION")).split("/")[0]
        obj.parent = nodes[prefix]
    root["asset_role"] = "island_one_puzzle_sanctum_gate"
    root["interaction_state"] = "locked_closed"
    root["assembly_count"] = len(nodes)
    return root


def duplicate_runtime(parts):
    export = new_collection("MSHG_GAME_EXPORT")
    root = bpy.data.objects.new("MindSparkHeavenlyStarGate", None)
    export.objects.link(root)
    grouped = OrderedDict()
    for source in parts.objects:
        if source.type == "MESH":
            grouped.setdefault(source["semantic_group"], []).append(source)
    exports = []
    for group, sources in grouped.items():
        copies = []
        for source in sources:
            dup = source.copy()
            dup.data = source.data.copy()
            export.objects.link(dup)
            dup.matrix_world = source.matrix_world.copy()
            dup.parent = None
            copies.append(dup)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in copies:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = copies[0]
        bpy.ops.object.join()
        joined = bpy.context.object
        joined.name = "MSHG_" + group.title().replace("_", "")
        joined.parent = root
        joined["semantic_group"] = group
        joined["source_module_count"] = len(sources)
        exports.append(joined)
    root["gameplay_role"] = "island_one_puzzle_sanctum_gate"
    root["puzzle_contract"] = "three coupled orbit regulators power the Star of Wisdom"
    root["animation_contract"] = "hinges_charge > star_awakens > leaves_retract > passage_unlocked"
    return export, root, exports, grouped


def select_tree(root):
    root.select_set(True)
    for child in root.children:
        select_tree(child)


def triangles(objects):
    count = 0
    for obj in objects:
        obj.data.calc_loop_triangles()
        count += len(obj.data.loop_triangles)
    return count


def setup_render(export, root):
    for child in bpy.context.scene.collection.children:
        child.hide_render = child != export
    export.hide_render = False
    world = bpy.data.worlds.new("Mind Spark Midnight")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.10, 0.18, 0.29, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.38
    bpy.ops.object.light_add(type="AREA", location=(-16, -20, 34))
    key = bpy.context.object
    key.data.energy, key.data.shape, key.data.size = 4600, "DISK", 14
    key.data.color = (1.0, 0.72, 0.42)
    key.rotation_euler = (math.radians(24), 0, math.radians(-26))
    bpy.ops.object.light_add(type="AREA", location=(17, 2, 24))
    rim = bpy.context.object
    rim.data.energy, rim.data.size = 2400, 12
    rim.data.color = (0.10, 0.48, 0.72)
    rim.rotation_euler = (math.radians(-70), 0, math.radians(150))
    bpy.ops.object.light_add(type="AREA", location=(0, -8, 9))
    fill = bpy.context.object
    fill.data.energy, fill.data.size = 900, 10
    fill.data.color = (1.0, 0.48, 0.22)
    bpy.ops.object.camera_add(location=(39, -64, 25))
    camera = bpy.context.object
    camera.data.lens = 55
    camera.rotation_euler = (Vector((0, 0, 14.4)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1400, 1050
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    scene.render.filepath = str(HERO_PATH)
    bpy.ops.render.render(write_still=True)
    camera.location = (-15.0, -27.0, 9.5)
    camera.data.lens = 68
    camera.rotation_euler = (Vector((-8.0, -2.5, 7.0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x, scene.render.resolution_y = 1200, 1200
    scene.render.filepath = str(DETAIL_PATH)
    bpy.ops.render.render(write_still=True)


def main():
    for path in (BLEND_PATH.parent, GLB_PATH.parent, ARTIFACT_ROOT):
        path.mkdir(parents=True, exist_ok=True)
    reset_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene["asset_title"] = "MIND SPARK HEAVENLY STAR GATE"
    scene["design_language"] = "warm heavenly civic luxury + Piltover-inspired precision + industrial load logic"
    scene["topology_contract"] = "independent editable modules, bevelled silhouettes, smooth shading, all polygon faces triangulated"
    parts = new_collection("MSHG_EDITABLE_SOURCE_PARTS")
    mats = {
        key: material("MSHG_MAT_" + key.upper(), color,
                      metallic=0.78 if key in ("warm_gold", "pale_gold", "bronze") else 0.0,
                      roughness=0.24 if key in ("warm_gold", "pale_gold") else
                                (0.34 if key == "bronze" else 0.62),
                      emission=3.8 if key == "aether" else (0.35 if key == "lavender" else 0.0))
        for key, color in PALETTE.items()
    }
    build_v2_foundation(parts, mats)
    for side in (-1, 1):
        build_v2_pylon(parts, mats, side)
        build_v2_engine(parts, mats, side)
        build_v2_leaf(parts, mats, side)
    build_v2_crown(parts, mats)
    build_v2_power_crown(parts, mats)
    build_v2_conduits(parts, mats)
    source_root = hierarchy(parts)
    export_collection, export_root, exports, groups = duplicate_runtime(parts)
    parts.hide_viewport = True
    parts.hide_render = True
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.object.select_all(action="DESELECT")
    select_tree(export_root)
    bpy.context.view_layer.objects.active = export_root
    bpy.ops.export_scene.gltf(filepath=str(GLB_PATH), use_selection=True,
                              export_format="GLB", export_apply=True, export_yup=True,
                              export_materials="EXPORT", export_cameras=False,
                              export_lights=False, export_animations=False, export_extras=True)
    source_meshes = [o for o in parts.objects if o.type == "MESH"]
    polygon_sizes = Counter(len(p.vertices) for o in source_meshes for p in o.data.polygons)
    total_tris = triangles(exports)
    manifest = {
        "asset": "mind_spark_heavenly_star_gate",
        "version": 2,
        "purpose": "Island One Thought Constellation sanctum gate; not an inter-island world portal",
        "editable_source_modules": len(source_meshes),
        "major_assemblies": 7,
        "component_groups": dict(Counter(str(o["component_path"]).split("/")[0] for o in source_meshes)),
        "runtime_mesh_groups": len(exports),
        "runtime_group_modules": {k: len(v) for k, v in groups.items()},
        "triangles": total_tris,
        "polygon_vertex_counts": dict(polygon_sizes),
        "all_faces_triangulated": set(polygon_sizes) == {3},
        "materials": sorted(mat.name for mat in mats.values()),
        "dimensions_m": {"width": 30.0, "depth": 8.4, "height": 30.5, "clear_portal_width": 12.0},
        "animation_contract": ["LOCKED", "HINGES_CHARGING", "STAR_AWAKENING", "LEAVES_RETRACTING", "OPEN"],
        "reuse_contract": {
            "pylon": "mirrorable civic support module",
            "hinge_engine": "mirrorable powered rotation module",
            "voussoir": "repeatable curved crown construction unit",
            "aether_facet": "repeatable triangular magical-glass panel",
            "fastener": "shared bolt, pearl, pipe-collar micro-kit",
        },
        "blend": str(BLEND_PATH.relative_to(ROOT)),
        "glb": str(GLB_PATH.relative_to(ROOT)),
        "hero_render": str(HERO_PATH.relative_to(ROOT)),
        "detail_render": str(DETAIL_PATH.relative_to(ROOT)),
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n")
    setup_render(export_collection, export_root)
    assert len(source_meshes) >= 250
    assert set(polygon_sizes) == {3}
    assert len(exports) <= 12
    assert total_tris < 180000
    print("MIND_SPARK_HEAVENLY_STAR_GATE_BUILD: PASS")
    print(f"modules={len(source_meshes)} runtime_groups={len(exports)} triangles={total_tris}")
    print(f"blend={BLEND_PATH}")
    print(f"glb={GLB_PATH}")
    print(f"hero={HERO_PATH}")
    print(f"detail={DETAIL_PATH}")


if __name__ == "__main__":
    main()
