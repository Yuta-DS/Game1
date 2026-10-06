"""Build the reusable Mind Spark luxury aether-steam component library.

Run:
    blender --background --python tools/blender/build_mind_spark_luxury_steam_kit.py

Outputs:
    assets3D/mind_spark/luxury_steam_kit/source/mind_spark_luxury_steam_kit.blend
    assets3D/mind_spark/luxury_steam_kit/glb/<component_id>.glb
    assets3D/mind_spark/luxury_steam_kit/previews/*.png
    assets3D/mind_spark/luxury_steam_kit/component_manifest.json

The individual GLBs contain only one root hierarchy and no camera/light. The
master Blend arranges all roots as an editable component showroom.
"""

from __future__ import annotations

import json
import math
import os
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
KIT_ROOT = ROOT / "assets3D" / "mind_spark" / "luxury_steam_kit"
SOURCE_DIR = KIT_ROOT / "source"
GLB_DIR = KIT_ROOT / "glb"
PREVIEW_DIR = KIT_ROOT / "previews"
COMPONENT_PREVIEW_DIR = PREVIEW_DIR / "components"
BLEND_PATH = SOURCE_DIR / "mind_spark_luxury_steam_kit.blend"
MANIFEST_PATH = KIT_ROOT / "component_manifest.json"
for path in (SOURCE_DIR, GLB_DIR, PREVIEW_DIR, COMPONENT_PREVIEW_DIR):
    path.mkdir(parents=True, exist_ok=True)


PALETTE = {
    "ivory": (0.80, 0.71, 0.57, 1.0),
    "cream": (0.68, 0.55, 0.39, 1.0),
    "brass": (0.58, 0.34, 0.10, 1.0),
    "copper": (0.55, 0.20, 0.12, 1.0),
    "gunmetal": (0.055, 0.075, 0.09, 1.0),
    "walnut": (0.30, 0.12, 0.06, 1.0),
    "terracotta": (0.52, 0.20, 0.11, 1.0),
    "sage": (0.20, 0.36, 0.19, 1.0),
    "teal": (0.045, 0.21, 0.23, 1.0),
    "sapphire": (0.035, 0.15, 0.31, 1.0),
    "cyan": (0.12, 0.72, 0.80, 1.0),
    "amber": (0.93, 0.43, 0.10, 1.0),
    "violet": (0.28, 0.07, 0.43, 1.0),
    "glass": (0.34, 0.58, 0.60, 0.30),
    "water": (0.04, 0.30, 0.42, 0.54),
}


CATALOG = [
    ("arch_01_ivory_column", "architecture", (0.85, 0.85, 5.2), "Fluted ivory and brass structural column"),
    ("arch_02_brass_railing_straight", "architecture", (4.0, 0.18, 1.15), "Straight brass safety railing"),
    ("arch_03_brass_railing_curve", "architecture", (4.2, 1.15, 1.15), "Curved island-rim safety railing"),
    ("arch_04_glass_canopy_bay", "architecture", (6.0, 4.0, 4.2), "Repeatable iron-and-glass canopy bay"),
    ("arch_05_luxury_floor_square", "architecture", (4.0, 4.0, 0.22), "Square civic floor bay"),
    ("arch_06_luxury_floor_diamond", "architecture", (4.0, 4.0, 0.22), "Diamond navigation floor bay"),
    ("arch_07_rotunda_arch", "architecture", (6.0, 1.0, 5.5), "Grand circular-focus civic arch"),
    ("arch_08_glass_balustrade", "architecture", (4.0, 0.14, 1.2), "Warm-glass safety balustrade"),
    ("route_01_bridge_truss_segment", "traversal", (8.0, 5.0, 1.4), "Walkable bridge and structural truss"),
    ("route_02_bridge_landing", "traversal", (7.0, 7.0, 0.7), "Island-rim bridge transition"),
    ("route_03_wayfinding_pylon", "traversal", (1.1, 1.1, 3.6), "Diamond objective direction pylon"),
    ("route_04_station_platform_bay", "traversal", (10.0, 5.0, 0.55), "Boutique railway platform bay"),
    ("mech_01_boiler_vertical", "mechanical", (2.6, 2.6, 5.4), "Vertical steam boiler"),
    ("mech_02_piston_engine", "mechanical", (5.0, 2.4, 3.2), "Double-acting piston engine"),
    ("mech_03_flywheel", "mechanical", (0.7, 3.8, 3.8), "Spoked kinetic flywheel"),
    ("mech_04_centrifugal_governor", "mechanical", (1.8, 1.8, 3.4), "Centrifugal speed governor"),
    ("mech_05_pressure_gauge", "mechanical", (0.35, 0.75, 0.75), "Circular enamel pressure gauge"),
    ("mech_06_relief_valve", "mechanical", (0.8, 0.8, 1.7), "Handwheel pressure relief valve"),
    ("mech_07_pipe_straight", "mechanical", (4.0, 0.48, 0.48), "Four-metre flanged copper pipe"),
    ("mech_08_pipe_elbow", "mechanical", (2.2, 2.2, 0.48), "Quarter-turn flanged copper pipe"),
    ("mech_09_pipe_t_junction", "mechanical", (3.2, 2.2, 0.48), "Three-way copper pipe fitting"),
    ("mech_10_condenser_tank", "mechanical", (4.0, 3.0, 2.4), "Glass-and-brass condenser reservoir"),
    ("mech_11_aether_dynamo", "mechanical", (3.0, 3.0, 3.2), "Shaft-to-aether circular generator"),
    ("mech_12_energy_conduit", "mechanical", (4.0, 0.55, 0.55), "Glass-and-brass cyan energy conduit"),
    ("civic_01_lantern", "civic", (0.65, 0.65, 3.2), "Warm civic lamp"),
    ("civic_02_bench", "civic", (2.4, 0.75, 1.0), "Walnut-and-brass garden bench"),
    ("civic_03_planter", "civic", (2.0, 2.0, 1.65), "Terracotta planter and sage planting"),
    ("civic_04_reflecting_basin", "civic", (4.0, 4.0, 0.45), "Shallow reflecting pool"),
    ("civic_05_mechanical_flower", "civic", (1.4, 1.4, 1.8), "Kinetic brass and sage flower"),
    ("civic_06_clock_kiosk", "civic", (1.8, 1.2, 3.8), "Arrival and station clock kiosk"),
    ("quest_01_compass_ring", "quest", (4.8, 4.8, 3.2), "Direction relic mechanism"),
    ("quest_02_balance_valve", "quest", (4.8, 3.0, 3.2), "Steam-water-light balance mechanism"),
    ("quest_03_clarity_lens", "quest", (4.4, 3.0, 3.4), "Observation and prediction optical comparator"),
    ("quest_04_perspective_prism", "quest", (4.6, 4.6, 4.0), "Three-arm perspective alignment mechanism"),
    ("quest_05_courage_flywheel", "quest", (4.8, 3.2, 4.2), "Calmed-storm flywheel relic"),
    ("quest_06_wisdom_engine", "quest", (7.0, 7.0, 6.2), "Final six-socket Wisdom Engine"),
]


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_material(name, color, metallic=0.0, roughness=0.5, emission=None,
                  emission_strength=0.0, transmission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = color
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Alpha"].default_value = color[3]
    if "Transmission Weight" in bsdf.inputs:
        bsdf.inputs["Transmission Weight"].default_value = transmission
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    if color[3] < 1.0:
        mat.surface_render_method = 'DITHERED'
        mat.use_transparency_overlap = False
    mat["mind_spark_luxury_material"] = True
    return mat


def create_materials():
    return {
        "ivory": make_material("MSLS_IvoryStone", PALETTE["ivory"], roughness=0.67),
        "cream": make_material("MSLS_CreamStone", PALETTE["cream"], roughness=0.62),
        "brass": make_material("MSLS_ChampagneBrass", PALETTE["brass"], metallic=0.82, roughness=0.24),
        "copper": make_material("MSLS_RoseCopper", PALETTE["copper"], metallic=0.76, roughness=0.31),
        "gunmetal": make_material("MSLS_Gunmetal", PALETTE["gunmetal"], metallic=0.72, roughness=0.29),
        "walnut": make_material("MSLS_Walnut", PALETTE["walnut"], roughness=0.49),
        "terracotta": make_material("MSLS_Terracotta", PALETTE["terracotta"], roughness=0.72),
        "sage": make_material("MSLS_Sage", PALETTE["sage"], roughness=0.77),
        "teal": make_material("MSLS_DeepTeal", PALETTE["teal"], metallic=0.42, roughness=0.31),
        "sapphire": make_material("MSLS_Sapphire", PALETTE["sapphire"], metallic=0.36, roughness=0.27),
        "cyan": make_material("MSLS_AetherCyan", PALETTE["cyan"], metallic=0.16, roughness=0.17,
                              emission=PALETTE["cyan"], emission_strength=2.2),
        "amber": make_material("MSLS_HoneyAmber", PALETTE["amber"], metallic=0.10, roughness=0.24,
                               emission=PALETTE["amber"], emission_strength=1.6),
        "violet": make_material("MSLS_StormViolet", PALETTE["violet"], metallic=0.12, roughness=0.22,
                                emission=PALETTE["violet"], emission_strength=1.7),
        "glass": make_material("MSLS_WarmGlass", PALETTE["glass"], roughness=0.12, transmission=0.65),
        "water": make_material("MSLS_Water", PALETTE["water"], roughness=0.08, transmission=0.45),
    }


def new_collection(name):
    coll = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(coll)
    return coll


def move_to(obj, coll):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    coll.objects.link(obj)
    return obj


def make_root(component_id, category, dimensions, description, coll):
    root = bpy.data.objects.new(f"MSLS_{component_id}", None)
    coll.objects.link(root)
    root.empty_display_type = 'CUBE'
    root.empty_display_size = 0.35
    root["component_id"] = component_id
    root["category"] = category
    root["dimensions_m"] = list(dimensions)
    root["description"] = description
    root["reusable"] = True
    try:
        root.asset_mark()
        root.asset_data.description = description
    except Exception:
        pass
    return root


def tag(obj, root, component_id, role="visual"):
    obj.parent = root
    obj["component_id"] = component_id
    obj["role"] = role
    return obj


def add_box(coll, root, cid, name, loc, scale, mat, bevel=0.06, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = move_to(bpy.context.object, coll)
    obj.name = f"VIS_{name}"
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("EdgeSoftening", 'BEVEL')
        mod.width = bevel
        mod.segments = 2
    obj.data.materials.append(mat)
    return tag(obj, root, cid)


def add_cylinder(coll, root, cid, name, loc, radius, depth, mat, vertices=32,
                 rot=(0, 0, 0), role="visual"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                       location=loc, rotation=rot)
    obj = move_to(bpy.context.object, coll)
    obj.name = ("UCX_" if role == "collision" else "VIS_") + name
    obj.data.materials.append(mat)
    return tag(obj, root, cid, role)


def add_torus(coll, root, cid, name, loc, major, minor, mat, rot=(0, 0, 0),
              major_segments=40, minor_segments=10):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                    major_segments=major_segments, minor_segments=minor_segments,
                                    location=loc, rotation=rot)
    obj = move_to(bpy.context.object, coll)
    obj.name = f"VIS_{name}"
    obj.data.materials.append(mat)
    return tag(obj, root, cid)


def add_sphere(coll, root, cid, name, loc, scale, mat, segments=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0, location=loc)
    obj = move_to(bpy.context.object, coll)
    obj.name = f"VIS_{name}"
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return tag(obj, root, cid)


def add_cone(coll, root, cid, name, loc, r1, r2, depth, mat, vertices=24,
             rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2,
                                  depth=depth, location=loc, rotation=rot)
    obj = move_to(bpy.context.object, coll)
    obj.name = f"VIS_{name}"
    obj.data.materials.append(mat)
    return tag(obj, root, cid)


def add_beam(coll, root, cid, name, start, end, radius, mat, vertices=16):
    start, end = Vector(start), Vector(end)
    vec = end - start
    obj = add_cylinder(coll, root, cid, name, (start + end) * 0.5, radius,
                       vec.length, mat, vertices)
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(vec.normalized())
    return obj


def add_socket(coll, root, cid, name, loc, socket_type, direction=(1, 0, 0)):
    socket = bpy.data.objects.new(f"SOCKET_{name}", None)
    coll.objects.link(socket)
    socket.parent = root
    socket.location = loc
    socket.empty_display_type = 'ARROWS'
    socket.empty_display_size = 0.26
    socket["component_id"] = cid
    socket["socket_type"] = socket_type
    socket["direction"] = list(direction)
    return socket


def add_collision_box(coll, root, cid, name, loc, scale):
    obj = add_box(coll, root, cid, name, loc, scale, bpy.data.materials["MSLS_Gunmetal"], bevel=0)
    obj.name = f"UCX_{name}"
    obj["role"] = "collision"
    obj.display_type = 'WIRE'
    obj.hide_render = True
    return obj


def add_handwheel(coll, root, cid, name, loc, radius, mats, rot=(math.pi / 2, 0, 0)):
    add_torus(coll, root, cid, name + "_Rim", loc, radius, 0.07, mats["brass"], rot)
    for i in range(6):
        a = math.tau * i / 6
        p = (loc[0] + math.cos(a) * radius, loc[1], loc[2] + math.sin(a) * radius)
        add_beam(coll, root, cid, name + f"_Spoke{i+1:02d}", loc, p, 0.035, mats["brass"])
    add_cylinder(coll, root, cid, name + "_Hub", loc, 0.13, 0.22, mats["gunmetal"], 20, rot=rot)


def add_gauge(coll, root, cid, name, loc, radius, mats, rot=(math.pi / 2, 0, 0)):
    add_cylinder(coll, root, cid, name + "_Case", loc, radius, 0.22, mats["brass"], 40, rot=rot)
    face = (loc[0], loc[1] - 0.13, loc[2])
    add_cylinder(coll, root, cid, name + "_Face", face, radius * 0.82, 0.035, mats["sapphire"], 40, rot=rot)
    tip = (loc[0] + radius * 0.55, loc[1] - 0.17, loc[2] + radius * 0.16)
    add_beam(coll, root, cid, name + "_Needle", face, tip, 0.025, mats["amber"], 10)


def build_architecture(cid, coll, root, mats):
    if cid == "arch_01_ivory_column":
        add_cylinder(coll, root, cid, "Base", (0, 0, 0.18), 0.42, 0.36, mats["cream"], 32)
        add_cylinder(coll, root, cid, "Shaft", (0, 0, 2.55), 0.30, 4.55, mats["ivory"], 20)
        for i in range(8):
            a = math.tau * i / 8
            add_cylinder(coll, root, cid, f"Flute{i+1:02d}", (math.cos(a)*0.29, math.sin(a)*0.29, 2.55),
                         0.027, 4.2, mats["brass"], 10)
        add_cylinder(coll, root, cid, "Capital", (0, 0, 4.94), 0.43, 0.28, mats["brass"], 32)
        add_box(coll, root, cid, "TopPlate", (0, 0, 5.13), (0.82, 0.82, 0.14), mats["ivory"])
        add_socket(coll, root, cid, "TOP", (0, 0, 5.2), "structure")
    elif cid == "arch_02_brass_railing_straight":
        for x in (-2, -1, 0, 1, 2):
            add_box(coll, root, cid, f"Post{x+2}", (x, 0, 0.57), (0.09, 0.09, 1.14), mats["brass"], 0.025)
        add_box(coll, root, cid, "TopRail", (0, 0, 1.1), (4.1, 0.11, 0.11), mats["brass"], 0.035)
        for x in (-1.5, -0.5, 0.5, 1.5):
            add_box(coll, root, cid, "DiamondA", (x, 0, 0.58), (0.72, 0.07, 0.07), mats["brass"], 0.015, (0, math.radians(45), 0))
            add_box(coll, root, cid, "DiamondB", (x, 0, 0.58), (0.72, 0.07, 0.07), mats["brass"], 0.015, (0, math.radians(-45), 0))
        add_socket(coll, root, cid, "START", (-2.05, 0, 0), "railing", (-1, 0, 0))
        add_socket(coll, root, cid, "END", (2.05, 0, 0), "railing")
    elif cid == "arch_03_brass_railing_curve":
        radius = 4.0
        for i in range(7):
            a = math.radians(-15 + i * 5)
            x, y = math.sin(a)*radius, radius-math.cos(a)*radius
            add_cylinder(coll, root, cid, f"Post{i+1:02d}", (x, y, 0.57), 0.045, 1.14, mats["brass"], 12)
        for i in range(12):
            a0, a1 = math.radians(-15+i*2.5), math.radians(-15+(i+1)*2.5)
            p0 = (math.sin(a0)*radius, radius-math.cos(a0)*radius, 1.1)
            p1 = (math.sin(a1)*radius, radius-math.cos(a1)*radius, 1.1)
            add_beam(coll, root, cid, f"CurveRail{i+1:02d}", p0, p1, 0.055, mats["brass"], 12)
        add_socket(coll, root, cid, "START", (-1.035, 0.136, 0), "railing")
        add_socket(coll, root, cid, "END", (1.035, 0.136, 0), "railing")
    elif cid == "arch_04_glass_canopy_bay":
        for x in (-3, 3):
            for y in (-2, 2):
                add_cylinder(coll, root, cid, f"Column_{x}_{y}", (x, y, 1.9), 0.10, 3.8, mats["brass"], 16)
        for i in range(9):
            y = -2 + i * 0.5
            for j in range(8):
                a0, a1 = math.pi*j/8, math.pi*(j+1)/8
                p0 = (-3+6*j/8, y, 3.35 + math.sin(a0)*0.8)
                p1 = (-3+6*(j+1)/8, y, 3.35 + math.sin(a1)*0.8)
                add_beam(coll, root, cid, f"RoofRib_{i}_{j}", p0, p1, 0.055, mats["brass"], 10)
            if i < 8:
                add_box(coll, root, cid, f"GlassBay{i+1:02d}", (0, y+0.25, 3.7), (5.82, 0.46, 0.055), mats["glass"], 0.02)
        add_socket(coll, root, cid, "START", (0, -2, 0), "canopy", (0, -1, 0))
        add_socket(coll, root, cid, "END", (0, 2, 0), "canopy", (0, 1, 0))
    elif cid in ("arch_05_luxury_floor_square", "arch_06_luxury_floor_diamond"):
        add_box(coll, root, cid, "StoneSlab", (0, 0, 0.11), (4, 4, 0.22), mats["ivory"], 0.035)
        add_box(coll, root, cid, "BorderX1", (0, -1.75, 0.24), (3.65, 0.07, 0.035), mats["brass"], 0.01)
        add_box(coll, root, cid, "BorderX2", (0, 1.75, 0.24), (3.65, 0.07, 0.035), mats["brass"], 0.01)
        add_box(coll, root, cid, "BorderY1", (-1.75, 0, 0.24), (0.07, 3.65, 0.035), mats["brass"], 0.01)
        add_box(coll, root, cid, "BorderY2", (1.75, 0, 0.24), (0.07, 3.65, 0.035), mats["brass"], 0.01)
        if "diamond" in cid:
            for angle in (math.radians(45), math.radians(-45)):
                add_box(coll, root, cid, "DiamondInlay", (0, 0, 0.245), (2.3, 0.07, 0.028), mats["brass"], 0.008, (0, 0, angle))
            add_cylinder(coll, root, cid, "FocusStud", (0, 0, 0.27), 0.16, 0.055, mats["cyan"], 20)
        add_collision_box(coll, root, cid, "Floor", (0, 0, 0.1), (4, 4, 0.2))
    elif cid == "arch_07_rotunda_arch":
        for x in (-2.75, 2.75):
            add_box(coll, root, cid, f"Pier_{x}", (x, 0, 2.0), (0.5, 0.8, 4), mats["ivory"], 0.12)
            add_box(coll, root, cid, f"PierBand_{x}", (x, -0.43, 2.0), (0.58, 0.08, 2.9), mats["brass"], 0.04)
        for i in range(17):
            a0, a1 = math.pi*i/16, math.pi*(i+1)/16
            p0 = (math.cos(a0)*2.75, 0, 3.85+math.sin(a0)*1.35)
            p1 = (math.cos(a1)*2.75, 0, 3.85+math.sin(a1)*1.35)
            add_beam(coll, root, cid, f"ArchSegment{i+1:02d}", p0, p1, 0.18, mats["brass"], 14)
        add_torus(coll, root, cid, "FocusCrown", (0, 0, 4.4), 0.47, 0.09, mats["cyan"], (math.pi/2, 0, 0))
        add_socket(coll, root, cid, "LEFT", (-3, 0, 0), "architecture", (-1, 0, 0))
        add_socket(coll, root, cid, "RIGHT", (3, 0, 0), "architecture")
    elif cid == "arch_08_glass_balustrade":
        add_box(coll, root, cid, "GlassPanel", (0, 0, 0.64), (3.65, 0.055, 1.05), mats["glass"], 0.025)
        for x in (-2, 0, 2):
            add_box(coll, root, cid, f"Post{x+2}", (x, 0, 0.6), (0.08, 0.1, 1.2), mats["brass"], 0.025)
        add_box(coll, root, cid, "TopRail", (0, 0, 1.17), (4.1, 0.11, 0.11), mats["brass"], 0.035)
        add_socket(coll, root, cid, "START", (-2.05, 0, 0), "balustrade", (-1, 0, 0))
        add_socket(coll, root, cid, "END", (2.05, 0, 0), "balustrade")


def build_route(cid, coll, root, mats):
    if cid == "route_01_bridge_truss_segment":
        add_box(coll, root, cid, "Deck", (0, 0, 0.75), (8, 5, 0.32), mats["ivory"], 0.08)
        for y in (-2.35, 2.35):
            add_box(coll, root, cid, f"EdgeRail_{y}", (0, y, 1.35), (8, 0.12, 0.12), mats["brass"], 0.04)
            for x in (-4, -2, 0, 2, 4):
                add_box(coll, root, cid, f"Post_{x}_{y}", (x, y, 1.0), (0.10, 0.10, 0.72), mats["brass"], 0.03)
            for i in range(4):
                x0, x1 = -4+i*2, -2+i*2
                add_beam(coll, root, cid, f"TrussA_{y}_{i}", (x0,y,0.18), (x1,y,0.72), 0.09, mats["gunmetal"])
                add_beam(coll, root, cid, f"TrussB_{y}_{i}", (x0,y,0.72), (x1,y,0.18), 0.09, mats["gunmetal"])
        add_box(coll, root, cid, "CenterInlay", (0, 0, 0.93), (7.5, 0.08, 0.035), mats["cyan"], 0.01)
        add_collision_box(coll, root, cid, "Deck", (0, 0, 0.75), (8, 5, 0.30))
        add_socket(coll, root, cid, "START", (-4, 0, 0.9), "bridge", (-1, 0, 0))
        add_socket(coll, root, cid, "END", (4, 0, 0.9), "bridge")
    elif cid == "route_02_bridge_landing":
        add_cylinder(coll, root, cid, "Landing", (0, 0, 0.32), 3.5, 0.64, mats["ivory"], 48)
        add_torus(coll, root, cid, "BrassEdge", (0, 0, 0.66), 3.22, 0.08, mats["brass"])
        for i in range(8):
            a=math.tau*i/8
            add_box(coll, root, cid, f"RadialInlay{i+1:02d}", (math.cos(a)*1.6, math.sin(a)*1.6, 0.66), (2.8,0.06,0.03), mats["brass"],0.008,(0,0,a))
        add_collision_box(coll, root, cid, "Landing", (0, 0, 0.32), (6.8,6.8,0.62))
        add_socket(coll, root, cid, "BRIDGE_A", (-3.5,0,0.7), "bridge", (-1,0,0))
        add_socket(coll, root, cid, "BRIDGE_B", (3.5,0,0.7), "bridge")
    elif cid == "route_03_wayfinding_pylon":
        add_box(coll, root, cid, "Plinth", (0,0,0.25),(1.1,1.1,0.5),mats["ivory"],0.12)
        add_cylinder(coll, root, cid, "Shaft", (0,0,1.8),0.16,2.8,mats["brass"],20)
        add_torus(coll, root, cid, "Compass",(0,0,3.0),0.46,0.07,mats["brass"],(math.pi/2,0,0))
        add_box(coll, root, cid, "Pointer", (0.20,-0.04,3.0),(0.72,0.08,0.18),mats["cyan"],0.03,(0,math.radians(45),0))
        add_sphere(coll, root, cid, "Focus",(0,-0.05,3.0),(0.13,0.08,0.13),mats["cyan"])
        add_socket(coll, root, cid, "POWER",(0,0,0.05),"aether",(0,0,-1))
    elif cid == "route_04_station_platform_bay":
        add_box(coll, root, cid, "Platform",(0,0,0.25),(10,5,0.5),mats["ivory"],0.09)
        add_box(coll, root, cid, "TactileEdge",(0,-2.2,0.53),(9.6,0.22,0.05),mats["brass"],0.02)
        for x in range(-4,5):
            add_box(coll, root, cid, f"EdgeStud{x+5:02d}",(x,-2.2,0.58),(0.08,0.10,0.06),mats["cyan"],0.01)
        add_collision_box(coll, root, cid, "Platform",(0,0,0.24),(10,5,0.48))
        add_socket(coll, root, cid, "START",(-5,0,0.5),"platform",(-1,0,0))
        add_socket(coll, root, cid, "END",(5,0,0.5),"platform")
        for x in (-3,3): add_socket(coll, root, cid, f"CANOPY_{x}",(x,0,0.5),"canopy")


def build_mechanical(cid, coll, root, mats):
    if cid == "mech_01_boiler_vertical":
        add_cylinder(coll, root, cid, "BoilerBody",(0,0,2.7),1.1,4.6,mats["teal"],40)
        for z in (0.65,1.5,2.4,3.3,4.25,4.95): add_torus(coll,root,cid,f"RivetBand{z}",(0,0,z),1.12,0.07,mats["brass"])
        add_box(coll,root,cid,"Firebox",(0,-1.0,0.75),(1.25,0.42,1.0),mats["gunmetal"],0.10)
        add_cylinder(coll,root,cid,"Chimney",(0,0,5.1),0.34,0.6,mats["copper"],28)
        add_gauge(coll,root,cid,"PressureGauge",(0,-1.2,3.65),0.33,mats)
        add_socket(coll,root,cid,"STEAM_OUT",(1.1,0,4.2),"steam")
        add_socket(coll,root,cid,"WATER_IN",(-1.1,0,1.0),"water",(-1,0,0))
    elif cid == "mech_02_piston_engine":
        add_box(coll,root,cid,"Bed",(0,0,0.22),(5,2.4,0.44),mats["ivory"],0.10)
        add_cylinder(coll,root,cid,"Cylinder",(-1.3,0,1.55),0.75,1.65,mats["teal"],36,rot=(0,math.pi/2,0))
        for x in (-2.1,-0.5): add_torus(coll,root,cid,f"CylinderBand{x}",(x,0,1.55),0.76,0.07,mats["brass"],(0,math.pi/2,0))
        add_box(coll,root,cid,"Crosshead",(0.15,0,1.55),(0.42,1.1,0.7),mats["brass"],0.08)
        add_beam(coll,root,cid,"PistonRod",(-0.5,0,1.55),(0.8,0,1.55),0.10,mats["copper"])
        add_beam(coll,root,cid,"ConnectingRod",(0.8,0,1.55),(2.0,0,0.88),0.12,mats["brass"])
        add_cylinder(coll,root,cid,"Crank",(2.0,0,0.88),0.28,1.5,mats["gunmetal"],24,rot=(math.pi/2,0,0))
        add_socket(coll,root,cid,"STEAM_IN",(-1.3,0,2.3),"steam",(0,0,1))
        add_socket(coll,root,cid,"SHAFT_OUT",(2.0,0,0.88),"shaft")
    elif cid == "mech_03_flywheel":
        add_torus(coll,root,cid,"Rim",(0,0,1.9),1.72,0.16,mats["brass"],(0,math.pi/2,0),48,12)
        add_cylinder(coll,root,cid,"Hub",(0,0,1.9),0.28,0.72,mats["gunmetal"],24,rot=(0,math.pi/2,0))
        for i in range(10):
            a=math.tau*i/10
            add_beam(coll,root,cid,f"Spoke{i+1:02d}",(0,0,1.9),(0,math.cos(a)*1.6,1.9+math.sin(a)*1.6),0.075,mats["brass"],12)
        for y in (-0.48,0.48): add_box(coll,root,cid,f"Guard{y}",(0,y,1.9),(0.12,0.08,3.65),mats["gunmetal"],0.04)
        add_socket(coll,root,cid,"SHAFT_IN",(-0.36,0,1.9),"shaft",(-1,0,0))
        add_socket(coll,root,cid,"SHAFT_OUT",(0.36,0,1.9),"shaft")
    elif cid == "mech_04_centrifugal_governor":
        add_cylinder(coll,root,cid,"Base",(0,0,0.18),0.72,0.36,mats["ivory"],32)
        add_cylinder(coll,root,cid,"Shaft",(0,0,1.75),0.10,2.9,mats["brass"],16)
        add_cylinder(coll,root,cid,"Sleeve",(0,0,1.1),0.22,0.55,mats["teal"],24)
        for i,a in enumerate((0,math.pi)):
            top=(0,0,2.65); weight=(math.cos(a)*0.72,math.sin(a)*0.72,1.72); sleeve=(0,0,1.1)
            add_beam(coll,root,cid,f"UpperArm{i}",top,weight,0.045,mats["brass"])
            add_beam(coll,root,cid,f"LowerArm{i}",weight,sleeve,0.045,mats["brass"])
            add_sphere(coll,root,cid,f"Weight{i}",weight,(0.22,0.22,0.22),mats["brass"])
        add_torus(coll,root,cid,"ControlHalo",(0,0,2.8),0.36,0.055,mats["cyan"])
        add_socket(coll,root,cid,"SHAFT_IN",(0,0,0),"shaft",(0,0,-1))
        add_socket(coll,root,cid,"CONTROL_OUT",(0,0,3.2),"control",(0,0,1))
    elif cid == "mech_05_pressure_gauge":
        add_gauge(coll,root,cid,"Gauge",(0,0,0.38),0.36,mats,rot=(math.pi/2,0,0))
        add_cylinder(coll,root,cid,"Stem",(0,0,0.08),0.07,0.16,mats["copper"],14)
        add_socket(coll,root,cid,"PRESSURE_IN",(0,0,0),"steam",(0,0,-1))
    elif cid == "mech_06_relief_valve":
        add_cylinder(coll,root,cid,"ValveBody",(0,0,0.48),0.30,0.72,mats["copper"],24)
        add_cylinder(coll,root,cid,"Stem",(0,0,1.05),0.07,0.62,mats["brass"],14)
        add_handwheel(coll,root,cid,"Handwheel",(0,-0.02,1.42),0.34,mats)
        add_socket(coll,root,cid,"IN",(-0.42,0,0.38),"steam",(-1,0,0))
        add_socket(coll,root,cid,"OUT",(0.42,0,0.38),"steam")
    elif cid == "mech_07_pipe_straight":
        add_cylinder(coll,root,cid,"Pipe",(0,0,0),0.18,4,mats["copper"],24,rot=(0,math.pi/2,0))
        for x in (-2,2): add_torus(coll,root,cid,f"Flange{x}",(x,0,0),0.27,0.06,mats["brass"],(0,math.pi/2,0))
        add_socket(coll,root,cid,"IN",(-2,0,0),"pipe",(-1,0,0)); add_socket(coll,root,cid,"OUT",(2,0,0),"pipe")
    elif cid == "mech_08_pipe_elbow":
        points=[]
        for i in range(13):
            a=math.pi/2*i/12
            points.append((1.1-math.cos(a)*1.1,0,1.1-math.sin(a)*1.1))
        for i in range(len(points)-1): add_beam(coll,root,cid,f"Elbow{i+1:02d}",points[i],points[i+1],0.18,mats["copper"],16)
        add_torus(coll,root,cid,"FlangeIn",points[0],0.27,0.06,mats["brass"],(0,math.pi/2,0))
        add_torus(coll,root,cid,"FlangeOut",points[-1],0.27,0.06,mats["brass"],(0,0,0))
        add_socket(coll,root,cid,"IN",points[0],"pipe",(-1,0,0)); add_socket(coll,root,cid,"OUT",points[-1],"pipe",(0,0,-1))
    elif cid == "mech_09_pipe_t_junction":
        add_cylinder(coll,root,cid,"Main",(0,0,0),0.18,3.2,mats["copper"],24,rot=(0,math.pi/2,0))
        add_cylinder(coll,root,cid,"Branch",(0,0,0.9),0.18,1.8,mats["copper"],24)
        for name,loc,rot in (("Left",(-1.6,0,0),(0,math.pi/2,0)),("Right",(1.6,0,0),(0,math.pi/2,0)),("Top",(0,0,1.8),(0,0,0))):
            add_torus(coll,root,cid,"Flange"+name,loc,0.27,0.06,mats["brass"],rot)
        add_socket(coll,root,cid,"IN",(-1.6,0,0),"pipe",(-1,0,0)); add_socket(coll,root,cid,"OUT_A",(1.6,0,0),"pipe"); add_socket(coll,root,cid,"OUT_B",(0,0,1.8),"pipe",(0,0,1))
    elif cid == "mech_10_condenser_tank":
        add_box(coll,root,cid,"StoneBase",(0,0,0.2),(4,3,0.4),mats["ivory"],0.10)
        add_cylinder(coll,root,cid,"Tank",(0,0,1.32),1.15,2.1,mats["glass"],40,rot=(0,math.pi/2,0))
        add_cylinder(coll,root,cid,"Water",(0,0,0.98),1.05,1.22,mats["water"],40,rot=(0,math.pi/2,0))
        for x in (-1.55,1.55): add_torus(coll,root,cid,f"Band{x}",(x,0,1.32),1.17,0.07,mats["brass"],(0,math.pi/2,0))
        add_socket(coll,root,cid,"STEAM_IN",(-2,0,1.8),"steam",(-1,0,0)); add_socket(coll,root,cid,"WATER_OUT",(2,0,0.8),"water")
    elif cid == "mech_11_aether_dynamo":
        add_cylinder(coll,root,cid,"Base",(0,0,0.2),1.45,0.4,mats["ivory"],40)
        add_torus(coll,root,cid,"OuterRing",(0,0,1.65),1.22,0.16,mats["brass"],(math.pi/2,0,0),48,12)
        add_torus(coll,root,cid,"EnergyRing",(0,-0.04,1.65),0.82,0.12,mats["cyan"],(math.pi/2,0,0))
        add_sphere(coll,root,cid,"Core",(0,-0.08,1.65),(0.48,0.22,0.48),mats["cyan"])
        for i in range(8):
            a=math.tau*i/8
            add_beam(coll,root,cid,f"Conductor{i+1:02d}",(math.cos(a)*0.55,0,1.65+math.sin(a)*0.55),(math.cos(a)*1.08,0,1.65+math.sin(a)*1.08),0.045,mats["brass"])
        add_socket(coll,root,cid,"SHAFT_IN",(0,0,1.65),"shaft",(0,-1,0)); add_socket(coll,root,cid,"AETHER_OUT",(0,0,3.1),"aether",(0,0,1))
    elif cid == "mech_12_energy_conduit":
        add_cylinder(coll,root,cid,"GlassTube",(0,0,0),0.24,4,mats["glass"],24,rot=(0,math.pi/2,0))
        add_cylinder(coll,root,cid,"EnergyCore",(0,0,0),0.075,3.9,mats["cyan"],16,rot=(0,math.pi/2,0))
        for x in (-2,-1,0,1,2): add_torus(coll,root,cid,f"Collar{x+2}",(x,0,0),0.27,0.05,mats["brass"],(0,math.pi/2,0))
        add_socket(coll,root,cid,"IN",(-2,0,0),"aether",(-1,0,0)); add_socket(coll,root,cid,"OUT",(2,0,0),"aether")


def build_civic(cid, coll, root, mats):
    if cid == "civic_01_lantern":
        add_cylinder(coll,root,cid,"Base",(0,0,0.15),0.30,0.30,mats["ivory"],28)
        add_cylinder(coll,root,cid,"Post",(0,0,1.45),0.075,2.6,mats["brass"],16)
        add_box(coll,root,cid,"LanternFrame",(0,0,2.78),(0.58,0.58,0.72),mats["brass"],0.08)
        add_sphere(coll,root,cid,"WarmLight",(0,0,2.78),(0.22,0.22,0.30),mats["amber"])
        add_cone(coll,root,cid,"Cap",(0,0,3.18),0.36,0.06,0.22,mats["brass"],20)
        add_socket(coll,root,cid,"POWER",(0,0,0),"aether",(0,0,-1))
    elif cid == "civic_02_bench":
        for z in (0.48,0.73):
            for y in (-0.28,0,0.28): add_box(coll,root,cid,f"Slat_{z}_{y}",(0,y,z),(2.2,0.16,0.12),mats["walnut"],0.05)
        for x in (-0.95,0.95):
            add_box(coll,root,cid,f"Leg{x}",(x,0,0.28),(0.12,0.55,0.56),mats["brass"],0.04)
            add_beam(coll,root,cid,f"Arm{x}",(x,-0.32,0.48),(x,-0.32,0.88),0.055,mats["brass"])
        add_collision_box(coll,root,cid,"Seat",(0,0,0.50),(2.3,0.72,0.18))
    elif cid == "civic_03_planter":
        add_cylinder(coll,root,cid,"Pot",(0,0,0.42),0.92,0.84,mats["terracotta"],36)
        add_torus(coll,root,cid,"BrassRim",(0,0,0.84),0.86,0.07,mats["brass"])
        for i in range(9):
            a=math.tau*i/9; r=0.24+0.20*(i%3)
            add_sphere(coll,root,cid,f"Plant{i+1:02d}",(math.cos(a)*r,math.sin(a)*r,0.98+0.12*(i%2)),(0.22,0.12,0.38),mats["sage"],16,8)
    elif cid == "civic_04_reflecting_basin":
        add_box(coll,root,cid,"StoneBasin",(0,0,0.18),(4,4,0.36),mats["ivory"],0.18)
        add_box(coll,root,cid,"Water",(0,0,0.39),(3.55,3.55,0.04),mats["water"],0.06)
        for a in range(0,360,45):
            rad=math.radians(a); add_sphere(coll,root,cid,f"BrassStud{a}",(math.cos(rad)*1.82,math.sin(rad)*1.82,0.42),(0.08,0.08,0.08),mats["brass"],12,6)
    elif cid == "civic_05_mechanical_flower":
        add_cylinder(coll,root,cid,"Stem",(0,0,0.72),0.07,1.44,mats["brass"],14)
        for i in range(8):
            a=math.tau*i/8
            petal=add_sphere(coll,root,cid,f"Petal{i+1:02d}",(math.cos(a)*0.38,math.sin(a)*0.38,1.42),(0.38,0.16,0.12),mats["brass"],16,8)
            petal.rotation_euler[2]=a
        add_sphere(coll,root,cid,"AetherCentre",(0,0,1.43),(0.22,0.22,0.18),mats["cyan"])
        for i in range(3):
            a=math.tau*i/3
            leaf=add_sphere(coll,root,cid,f"Leaf{i+1:02d}",(math.cos(a)*0.28,math.sin(a)*0.28,0.72),(0.30,0.10,0.14),mats["sage"],16,8)
            leaf.rotation_euler[2]=a
        add_socket(coll,root,cid,"POWER",(0,0,0),"aether",(0,0,-1))
    elif cid == "civic_06_clock_kiosk":
        add_box(coll,root,cid,"Plinth",(0,0,0.22),(1.8,1.2,0.44),mats["ivory"],0.12)
        add_box(coll,root,cid,"Cabinet",(0,0,1.65),(1.35,0.75,2.4),mats["walnut"],0.13)
        add_cylinder(coll,root,cid,"ClockBezel",(0,-0.40,2.65),0.48,0.12,mats["brass"],40,rot=(math.pi/2,0,0))
        add_cylinder(coll,root,cid,"ClockFace",(0,-0.47,2.65),0.40,0.035,mats["sapphire"],40,rot=(math.pi/2,0,0))
        for a in range(0,360,30):
            rad=math.radians(a); add_sphere(coll,root,cid,f"Hour{a}",(math.cos(rad)*0.31,-0.50,2.65+math.sin(rad)*0.31),(0.025,0.015,0.025),mats["amber"],8,4)
        add_box(coll,root,cid,"MapPanel",(0,-0.42,1.35),(0.95,0.055,1.0),mats["glass"],0.04)
        add_socket(coll,root,cid,"POWER",(0,0,0),"aether",(0,0,-1))


def quest_plinth(cid, coll, root, mats, radius=2.1):
    add_cylinder(coll,root,cid,"QuestPlinth",(0,0,0.25),radius,0.5,mats["ivory"],48)
    add_torus(coll,root,cid,"QuestEdge",(0,0,0.52),radius*0.90,0.08,mats["brass"])
    add_socket(coll,root,cid,"POWER_IN",(0,0,0),"aether",(0,0,-1))


def build_quest(cid, coll, root, mats):
    if cid == "quest_01_compass_ring":
        quest_plinth(cid,coll,root,mats,2.3)
        for i,(r,z) in enumerate(((1.65,1.0),(1.22,1.35),(0.78,1.70))):
            add_torus(coll,root,cid,f"CompassRing{i+1}",(0,0,z),r,0.10,mats["brass"])
            for k in range(4):
                a=math.tau*k/4+i*0.3
                add_sphere(coll,root,cid,f"Landmark{i}_{k}",(math.cos(a)*r,math.sin(a)*r,z),(0.09,0.09,0.09),mats["cyan"],12,6)
        pointer=add_box(coll,root,cid,"DiamondPointer",(0,0,2.25),(0.52,0.52,0.14),mats["cyan"],0.06,(0,0,math.radians(45)))
        pointer["animation_role"]="rotating_pointer"
        add_socket(coll,root,cid,"RELIC_OUT",(0,0,2.7),"relic_compass",(0,0,1))
    elif cid == "quest_02_balance_valve":
        quest_plinth(cid,coll,root,mats,2.3)
        for i,(x,color) in enumerate(((-1.25,"copper"),(0,"cyan"),(1.25,"amber"))):
            add_cylinder(coll,root,cid,f"MeterColumn{i+1}",(x,0,1.55),0.42,2.05,mats["glass"],28)
            add_cylinder(coll,root,cid,f"MeterLevel{i+1}",(x,0,1.05),0.29,0.92,mats[color],24)
            add_handwheel(coll,root,cid,f"Valve{i+1}",(x,-0.55,0.75),0.32,mats)
        add_torus(coll,root,cid,"EquilibriumRing",(0,0,2.75),0.52,0.09,mats["cyan"],(math.pi/2,0,0))
        add_socket(coll,root,cid,"RELIC_OUT",(0,0,3.1),"relic_balance",(0,0,1))
    elif cid == "quest_03_clarity_lens":
        quest_plinth(cid,coll,root,mats,2.1)
        for i,x in enumerate((-0.9,0.9)):
            add_torus(coll,root,cid,f"LensFrame{i+1}",(x,0,2.0),0.62,0.10,mats["brass"],(math.pi/2,0,0))
            add_sphere(coll,root,cid,f"LensGlass{i+1}",(x,-0.05,2.0),(0.49,0.12,0.49),mats["glass"])
            add_beam(coll,root,cid,f"LensStand{i+1}",(x,0,0.5),(x,0,1.4),0.09,mats["brass"])
        add_sphere(coll,root,cid,"Convergence",(0,-0.18,2.0),(0.22,0.12,0.22),mats["cyan"])
        add_box(coll,root,cid,"EvidenceTable",(0,0,0.92),(2.8,1.1,0.18),mats["walnut"],0.08)
        add_socket(coll,root,cid,"RELIC_OUT",(0,0,3.2),"relic_clarity",(0,0,1))
    elif cid == "quest_04_perspective_prism":
        quest_plinth(cid,coll,root,mats,2.2)
        add_cone(coll,root,cid,"CentralPrism",(0,0,2.1),0.72,0.12,1.8,mats["glass"],6)
        for i in range(3):
            a=math.tau*i/3
            pivot=(math.cos(a)*1.5,math.sin(a)*1.5,1.35)
            add_cylinder(coll,root,cid,f"ArmPivot{i+1}",pivot,0.22,1.2,mats["brass"],20)
            add_beam(coll,root,cid,f"OpticalArm{i+1}",pivot,(math.cos(a)*0.55,math.sin(a)*0.55,2.15),0.09,mats["brass"])
            add_torus(coll,root,cid,f"Lens{i+1}",pivot,0.34,0.06,mats["cyan"],(math.pi/2,0,a))
        add_socket(coll,root,cid,"RELIC_OUT",(0,0,3.6),"relic_perspective",(0,0,1))
    elif cid == "quest_05_courage_flywheel":
        quest_plinth(cid,coll,root,mats,2.3)
        add_torus(coll,root,cid,"CourageRim",(0,0,2.25),1.45,0.16,mats["brass"],(math.pi/2,0,0),48,12)
        add_cylinder(coll,root,cid,"CourageHub",(0,0,2.25),0.32,0.55,mats["cyan"],24,rot=(math.pi/2,0,0))
        for i in range(8):
            a=math.tau*i/8
            add_beam(coll,root,cid,f"Spoke{i+1:02d}",(0,0,2.25),(math.cos(a)*1.25,0,2.25+math.sin(a)*1.25),0.075,mats["brass"])
        for i,a in enumerate((-0.9,0,0.9)):
            add_torus(coll,root,cid,f"ReliefRing{i+1}",(a,-0.1,0.95),0.26,0.06,mats["cyan"],(math.pi/2,0,0))
        add_socket(coll,root,cid,"RELIC_OUT",(0,0,4.0),"relic_courage",(0,0,1))
    elif cid == "quest_06_wisdom_engine":
        quest_plinth(cid,coll,root,mats,3.35)
        for i,(r,z,mat) in enumerate(((2.5,0.85,"brass"),(2.0,1.2,"cyan"),(1.5,1.55,"brass"),(1.0,1.9,"cyan"))):
            add_torus(coll,root,cid,f"WisdomRing{i+1}",(0,0,z),r,0.13,mats[mat])
        add_sphere(coll,root,cid,"WisdomCore",(0,0,2.4),(0.72,0.72,0.72),mats["amber"],32,16)
        for i in range(12):
            a=math.tau*i/12
            add_beam(coll,root,cid,f"CrownRay{i+1:02d}",(math.cos(a)*0.78,math.sin(a)*0.78,2.4),(math.cos(a)*2.5,math.sin(a)*2.5,3.6),0.055,mats["brass"])
        relics=("COMPASS","BALANCE","CLARITY","PERSPECTIVE","COURAGE")
        for i,name in enumerate(relics):
            a=math.tau*i/5-math.pi/2
            loc=(math.cos(a)*2.5,math.sin(a)*2.5,1.1)
            add_torus(coll,root,cid,f"SocketRing{name}",loc,0.31,0.06,mats["cyan"],(math.pi/2,0,a))
            add_socket(coll,root,cid,f"RELIC_{name}",loc,"relic_"+name.lower(),(math.cos(a),math.sin(a),0))
        add_socket(coll,root,cid,"PLAYER_CORE",(0,0,2.4),"player_core",(0,0,1))
        add_socket(coll,root,cid,"TREE_POWER",(0,0,5.5),"aether",(0,0,1))


def build_component(spec, mats):
    cid, category, dimensions, description = spec
    coll = new_collection(f"COL_{cid}")
    root = make_root(cid, category, dimensions, description, coll)
    if category == "architecture": build_architecture(cid,coll,root,mats)
    elif category == "traversal": build_route(cid,coll,root,mats)
    elif category == "mechanical": build_mechanical(cid,coll,root,mats)
    elif category == "civic": build_civic(cid,coll,root,mats)
    elif category == "quest": build_quest(cid,coll,root,mats)
    return root, coll


def descendants(root):
    result=[root]
    stack=list(root.children)
    while stack:
        obj=stack.pop()
        result.append(obj); stack.extend(obj.children)
    return result


def mesh_stats(root):
    verts=tris=meshes=0
    sockets=[]
    for obj in descendants(root):
        if obj.type == 'MESH':
            meshes += 1; verts += len(obj.data.vertices)
            tris += sum(max(0,len(p.vertices)-2) for p in obj.data.polygons)
        elif obj.type == 'EMPTY' and obj.name.startswith("SOCKET_"):
            sockets.append(obj.name)
    return meshes,verts,tris,sorted(sockets)


def export_component(root, cid):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in descendants(root): obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    out=GLB_DIR/f"{cid}.glb"
    bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,
                              export_materials='EXPORT',export_cameras=False,
                              export_lights=False,export_extras=True)
    return out


def add_preview_rig():
    world=bpy.context.scene.world or bpy.data.worlds.new("MSLS_PreviewWorld")
    bpy.context.scene.world=world
    world.use_nodes=True
    world.node_tree.nodes["Background"].inputs["Color"].default_value=(0.018,0.032,0.055,1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value=0.62
    bpy.ops.object.light_add(type='AREA',location=(4,-6,10)); key=bpy.context.object; key.name="PREVIEW_Key"; key.data.energy=2500; key.data.shape='DISK'; key.data.size=8; key.data.color=(1.0,0.68,0.42)
    bpy.ops.object.light_add(type='AREA',location=(-6,2,7)); fill=bpy.context.object; fill.name="PREVIEW_Fill"; fill.data.energy=1600; fill.data.size=10; fill.data.color=(0.35,0.65,1.0)
    bpy.ops.object.light_add(type='AREA',location=(0,8,4)); rim=bpy.context.object; rim.name="PREVIEW_Rim"; rim.data.energy=900; rim.data.size=7; rim.data.color=(0.45,0.9,1.0)
    bpy.ops.object.camera_add(location=(38,-52,43)); cam=bpy.context.object; cam.name="PREVIEW_Camera"; bpy.context.scene.camera=cam
    target=Vector((0,0,2.1)); cam.rotation_euler=(target-Vector(cam.location)).to_track_quat('-Z','Y').to_euler(); cam.data.lens=54
    cam.data.type='ORTHO'; cam.data.ortho_scale=30
    preview_floor=bpy.data.materials.get("MSLS_PreviewFloor") or make_material("MSLS_PreviewFloor",(0.025,0.045,0.075,1),metallic=0.05,roughness=0.66)
    bpy.ops.mesh.primitive_plane_add(size=120,location=(0,0,-0.06)); floor=bpy.context.object; floor.name="PREVIEW_Floor"; floor.data.materials.append(preview_floor)
    # Blender 5.x exposes Eevee through BLENDER_EEVEE. Older releases used
    # BLENDER_EEVEE_NEXT, so select the first supported identifier.
    render_engines={item.identifier for item in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items}
    bpy.context.scene.render.engine=('BLENDER_EEVEE' if 'BLENDER_EEVEE' in render_engines
                                     else 'BLENDER_EEVEE_NEXT')
    bpy.context.scene.render.resolution_x=1800; bpy.context.scene.render.resolution_y=1100; bpy.context.scene.render.resolution_percentage=100
    bpy.context.scene.render.image_settings.file_format='PNG'
    bpy.context.scene.view_settings.look='AgX - Medium High Contrast'
    return [key,fill,rim,cam,floor]


def render_groups(roots):
    rig=add_preview_rig()
    camera=bpy.context.scene.camera
    original_locations={root:root.location.copy() for root in roots}
    groups=(
        ("01_architecture_traversal",{"architecture","traversal"},38),
        ("02_mechanical",{"mechanical"},36),
        ("03_civic",{"civic"},28),
        ("04_quest_relics",{"quest"},31),
        ("05_complete_library",{"architecture","traversal","mechanical","civic","quest"},65),
    )
    for filename,categories,ortho_scale in groups:
        visible=[root for root in roots if root.get("category") in categories]
        columns=3 if len(visible) <= 6 else (4 if len(visible) <= 12 else 6)
        rows=math.ceil(len(visible)/columns)
        spacing=8.5
        for index,root in enumerate(visible):
            column=index%columns; row=index//columns
            root.location=((column-(columns-1)*0.5)*spacing,
                           ((rows-1)*0.5-row)*spacing,0)
        camera.data.ortho_scale=ortho_scale
        for root in roots:
            hidden=root.get("category") not in categories
            for obj in descendants(root):
                obj.hide_render=hidden or obj.name.startswith("UCX_")
        bpy.context.scene.render.filepath=str(PREVIEW_DIR/f"{filename}.png")
        bpy.ops.render.render(write_still=True)
    bpy.context.scene.render.resolution_x=900
    bpy.context.scene.render.resolution_y=900
    for root in roots:
        root.location=(0,0,0)
        dimensions=root.get("dimensions_m",[1,1,1])
        camera.data.ortho_scale=max(4.5,max(dimensions)*1.75+1.0)
        for candidate in roots:
            hidden=candidate != root
            for obj in descendants(candidate):
                obj.hide_render=hidden or obj.name.startswith("UCX_")
        bpy.context.scene.render.filepath=str(COMPONENT_PREVIEW_DIR/f"{root.get('component_id')}.png")
        bpy.ops.render.render(write_still=True)
    bpy.context.scene.render.resolution_x=1800
    bpy.context.scene.render.resolution_y=1100
    for root in roots:
        root.location=original_locations[root]
        for obj in descendants(root):
            obj.hide_render=obj.name.startswith("UCX_")
    for obj in rig: bpy.data.objects.remove(obj,do_unlink=True)


def main():
    reset_scene(); mats=create_materials(); roots=[]; manifest=[]
    for index,spec in enumerate(CATALOG):
        cid,category,dimensions,description=spec
        root,_=build_component(spec,mats)
        out=export_component(root,cid)
        meshes,verts,tris,sockets=mesh_stats(root)
        manifest.append({"id":cid,"category":category,"description":description,
                         "dimensions_m":list(dimensions),"glb":str(out.relative_to(ROOT)),
                         "bytes":out.stat().st_size,"mesh_count":meshes,
                         "vertices":verts,"triangles":tris,"sockets":sockets})
        col=index%6; row=index//6
        root.location=(col*9.0-22.5,row*9.0-22.5,0)
        roots.append(root)
        print(f"[MSLS] {cid}: meshes={meshes} verts={verts} tris={tris} sockets={len(sockets)}")
    # Centre the showroom layout around the origin for previews.
    xs=[r.location.x for r in roots]; ys=[r.location.y for r in roots]
    cx=(min(xs)+max(xs))*0.5; cy=(min(ys)+max(ys))*0.5
    for root in roots: root.location.x-=cx; root.location.y-=cy
    render_groups(roots)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    payload={"schema_version":1,"kit":"mind_spark_luxury_steam","component_count":len(manifest),
             "blend":str(BLEND_PATH.relative_to(ROOT)),"components":manifest}
    MANIFEST_PATH.write_text(json.dumps(payload,indent=2))
    print(f"[MSLS] wrote {len(manifest)} components, master {BLEND_PATH}, manifest {MANIFEST_PATH}")


if __name__ == '__main__':
    main()
