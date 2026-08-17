"""Idempotent Blender pipeline: rebuilds the 12 Mind Spark quest object props.

Run headlessly:
    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/build_mind_spark_quest_objects.py

Outputs:
    assets3D/mind_spark/quest_objects/source/mind_spark_quest_objects.blend
    assets3D/mind_spark/quest_objects/glb/<object_id>.glb  (x12)
    tools/blender/mind_spark_quest_objects_report.json
"""

import json
import math
import os
import re
import sys

import bmesh
import bpy
import mathutils

Vector = mathutils.Vector
Matrix = mathutils.Matrix
Euler = mathutils.Euler

# ---------------------------------------------------------------------------
# Coordinate convention: every builder in this file authors positions and
# rotations in Godot's Y-up, right-handed convention (matching quest_object
# scene transforms in scenes/mind_spark/quest_objects/). Blender is Z-up, so
# every primitive helper below routes loc/rot/size through this single basis
# map instead of passing Godot vectors straight into Blender ops. The mapping
# (x, y, z) -> (x, -z, y) is an orthonormal, det=+1 rotation, so it is applied
# consistently to positions, box dimensions, and rotations (via conjugation)
# rather than being hand-tuned per builder.
# ---------------------------------------------------------------------------

GODOT_TO_BLENDER_MATRIX = Matrix((
    (1.0, 0.0, 0.0),
    (0.0, 0.0, -1.0),
    (0.0, 1.0, 0.0),
))


def godot_to_blender_loc(loc):
    return tuple(GODOT_TO_BLENDER_MATRIX @ Vector(loc))


def godot_to_blender_size(size):
    """Box half/full extents have no sign, so map each axis's magnitude
    through the same permutation the basis matrix applies to that axis."""
    x, y, z = size
    return (x, z, y)


def godot_to_blender_rot(rot):
    """Conjugates a Godot-authored XYZ Euler rotation through the basis
    matrix so it produces the equivalent orientation in Blender's Z-up
    space, rather than reinterpreting the same angle values on swapped axes."""
    r_godot = Euler(rot, 'XYZ').to_matrix().to_3x3()
    m = GODOT_TO_BLENDER_MATRIX
    r_blender = m @ r_godot @ m.transposed()
    return tuple(r_blender.to_euler('XYZ'))


REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCE_DIR = os.path.join(REPO_ROOT, "assets3D", "mind_spark", "quest_objects", "source")
GLB_DIR = os.path.join(REPO_ROOT, "assets3D", "mind_spark", "quest_objects", "glb")
TEXTURE_DIR = os.path.join(REPO_ROOT, "assets", "textures", "mind_spark", "quest_objects")
REPORT_PATH = os.path.join(os.path.dirname(__file__), "mind_spark_quest_objects_report.json")
BLEND_PATH = os.path.join(SOURCE_DIR, "mind_spark_quest_objects.blend")

os.makedirs(SOURCE_DIR, exist_ok=True)
os.makedirs(GLB_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Palette (matches reference art + existing Godot StandardMaterial3D colors)
# ---------------------------------------------------------------------------

NAVY_STONE = (0.086, 0.114, 0.176, 1.0)
GUNMETAL = (0.153, 0.2, 0.29, 1.0)
GUNMETAL_DARK = (0.067, 0.114, 0.204, 1.0)
CYAN = (0.42, 0.88, 1.0, 1.0)
CYAN_BRIGHT = (0.45, 0.91, 1.0, 1.0)
VIOLET = (0.458, 0.2745, 0.7412, 1.0)
VIOLET_BRIGHT = (0.6078, 0.3294, 0.9373, 1.0)
GOLD = (1.0, 0.86, 0.34, 1.0)
GREEN = (0.47, 1.0, 0.63, 1.0)
FEAR_RED = (1.0, 0.43, 0.55, 1.0)

# ---------------------------------------------------------------------------
# Object catalog: id, display name, texture file, accent color, kind index
# ---------------------------------------------------------------------------

OBJECTS = [
    dict(id="thought_spark_socket", index=0, texture="thought_spark_socket_albedo_v1.png",
         accent=CYAN_BRIGHT, hero_target="SparkReceiverBowl"),
    dict(id="evidence_scanner", index=1, texture="evidence_scanner_albedo_v1.png",
         accent=CYAN, hero_target="ScannerGlass"),
    dict(id="perspective_lens", index=2, texture="perspective_lens_albedo_v1.png",
         accent=GOLD, hero_target="LensBody/LensCrystal"),
    dict(id="memory_constellation_board", index=3, texture="memory_constellation_albedo_v1.png",
         accent=VIOLET, hero_target="ConstellationSlate"),
    dict(id="logic_gate_arch", index=4, texture="logic_gate_arch_albedo_v1.png",
         accent=GREEN, hero_target="Door"),
    dict(id="truth_bridge_tile", index=5, texture="truth_bridge_tile_albedo_v1.png",
         accent=CYAN, hero_target="BridgeTile/CircuitTile"),
    dict(id="focus_bell_beacon", index=6, texture="focus_bell_beacon_albedo_v1.png",
         accent=GOLD, hero_target="FocusBell"),
    dict(id="warden_anchor", index=7, texture="warden_anchor_albedo_v1.png",
         accent=FEAR_RED, hero_target="WardenShield"),
    dict(id="calm_rain_basin", index=8, texture="calm_rain_basin_albedo_v1.png",
         accent=(0.49, 0.76, 1.0, 1.0), hero_target="BasinWater"),
    dict(id="identity_reflection_mirror", index=9, texture="identity_reflection_mirror_albedo_v1.png",
         accent=(0.92, 0.72, 1.0, 1.0), hero_target="ReflectionSurface"),
    dict(id="checkpoint_server_root", index=10, texture="checkpoint_server_root_albedo_v1.png",
         accent=GREEN, hero_target="ServerRootTrunk"),
    dict(id="clear_path_projector", index=11, texture="clear_path_projector_albedo_v1.png",
         accent=GOLD, hero_target="RouteProjector"),
]

# ---------------------------------------------------------------------------
# Scene reset
# ---------------------------------------------------------------------------


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for coll in list(bpy.data.collections):
        bpy.data.collections.remove(coll)


def new_collection(name, parent=None):
    coll = bpy.data.collections.new(name)
    (parent or bpy.context.scene.collection).children.link(coll)
    return coll


# ---------------------------------------------------------------------------
# Material helpers
# ---------------------------------------------------------------------------

_material_cache = {}


def make_material(name, base_color, metallic=0.48, roughness=0.4, emission_color=None,
                   emission_strength=0.0, texture_path=None):
    key = (name, texture_path)
    if key in _material_cache:
        return _material_cache[key]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (300, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (0, 0)
    bsdf.inputs["Base Color"].default_value = base_color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission_color is not None:
        bsdf.inputs["Emission Color"].default_value = emission_color
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    if texture_path and os.path.exists(texture_path):
        tex_node = nt.nodes.new("ShaderNodeTexImage")
        tex_node.location = (-400, 200)
        img = bpy.data.images.load(texture_path, check_existing=True)
        tex_node.image = img
        nt.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat["artea_base_color"] = list(base_color)
    _material_cache[key] = mat
    return mat


def stone_material(name_suffix):
    return make_material(f"MAT_Stone_{name_suffix}", GUNMETAL, metallic=0.48, roughness=0.72,
                          emission_color=(*GUNMETAL_DARK[:3], 1.0), emission_strength=0.22)


def circuit_material(name_suffix, color=CYAN):
    return make_material(f"MAT_Circuit_{name_suffix}", color, metallic=0.5, roughness=0.28,
                          emission_color=color, emission_strength=1.6)


def crystal_material(name_suffix, color=VIOLET_BRIGHT):
    return make_material(f"MAT_Crystal_{name_suffix}", color, metallic=0.15, roughness=0.08,
                          emission_color=color, emission_strength=2.2)


def accent_material(name_suffix, color, strength=1.35):
    return make_material(f"MAT_Accent_{name_suffix}", color, metallic=0.48, roughness=0.2,
                          emission_color=color, emission_strength=strength)


def albedo_material(obj_id, texture_path):
    return make_material(f"MAT_Albedo_{obj_id}", (1, 1, 1, 1), metallic=0.3, roughness=0.42,
                          texture_path=texture_path)


# ---------------------------------------------------------------------------
# Primitive builders (return the created object, already at cursor origin)
# ---------------------------------------------------------------------------


def _link(obj, coll):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)
    return obj


def add_cylinder(coll, name, radius, height, loc=(0, 0, 0), segments=40, mat=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments, radius=radius, depth=height,
                                         location=godot_to_blender_loc(loc))
    obj = bpy.context.active_object
    obj.name = name
    _link(obj, coll)
    if mat:
        obj.data.materials.append(mat)
    return obj


def add_cone(coll, name, radius1, radius2, height, loc=(0, 0, 0), rot=(0, 0, 0), segments=16, mat=None):
    bpy.ops.mesh.primitive_cone_add(vertices=segments, radius1=radius1, radius2=radius2, depth=height,
                                     location=godot_to_blender_loc(loc), rotation=godot_to_blender_rot(rot))
    obj = bpy.context.active_object
    obj.name = name
    _link(obj, coll)
    if mat:
        obj.data.materials.append(mat)
    return obj


def add_torus(coll, name, major_r, minor_r, loc=(0, 0, 0), rot=(0, 0, 0), major_seg=36, minor_seg=16, mat=None):
    bpy.ops.mesh.primitive_torus_add(location=godot_to_blender_loc(loc), rotation=godot_to_blender_rot(rot),
                                      major_radius=major_r, minor_radius=minor_r,
                                      major_segments=major_seg, minor_segments=minor_seg)
    obj = bpy.context.active_object
    obj.name = name
    _link(obj, coll)
    if mat:
        obj.data.materials.append(mat)
    return obj


def add_hollow_frame(coll, name_prefix, outer_w, outer_h, bar_thickness, depth, loc=(0, 0, 0), rot=(0, 0, 0),
                      mat=None):
    """Reusable open four-piece beveled frame/arch: top, bottom, left, right
    bars around a rectangular opening, authored flat in the frame's own local
    XY plane (X=width, Y=height) then placed via the shared Godot->Blender
    loc/rot basis so callers can orient it like any other primitive. Returns
    the four bar Objects; the interior stays open so whatever sits behind
    (glass, slate, bell, lens) is visible through the opening."""
    half_w = outer_w / 2.0
    half_h = outer_h / 2.0

    def _place(local_pos, size):
        # local_pos/size are in the frame's own (x=width, y=height, z=depth)
        # space; rotate that offset by the authored Godot rotation, then add
        # to loc, so the whole frame orients as one rigid unit.
        r = Euler(rot, 'XYZ').to_matrix().to_3x3()
        world_pos = Vector(loc) + r @ Vector(local_pos)
        return tuple(world_pos), size

    bars = []
    top_pos, top_size = _place((0, half_h - bar_thickness / 2.0, 0), (outer_w, bar_thickness, depth))
    bars.append(add_box(coll, f"{name_prefix}Top", top_size, loc=top_pos, rot=rot, mat=mat))
    bot_pos, bot_size = _place((0, -(half_h - bar_thickness / 2.0), 0), (outer_w, bar_thickness, depth))
    bars.append(add_box(coll, f"{name_prefix}Bottom", bot_size, loc=bot_pos, rot=rot, mat=mat))
    side_h = outer_h - bar_thickness * 2.0
    left_pos, left_size = _place((-(half_w - bar_thickness / 2.0), 0, 0), (bar_thickness, side_h, depth))
    bars.append(add_box(coll, f"{name_prefix}Left", left_size, loc=left_pos, rot=rot, mat=mat))
    right_pos, right_size = _place((half_w - bar_thickness / 2.0, 0, 0), (bar_thickness, side_h, depth))
    bars.append(add_box(coll, f"{name_prefix}Right", right_size, loc=right_pos, rot=rot, mat=mat))
    return bars


def add_box(coll, name, size, loc=(0, 0, 0), rot=(0, 0, 0), mat=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=godot_to_blender_loc(loc))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = godot_to_blender_size(size)
    obj.rotation_euler = godot_to_blender_rot(rot)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    _link(obj, coll)
    if mat:
        obj.data.materials.append(mat)
    return obj


def add_sphere(coll, name, radius, loc=(0, 0, 0), segments=40, rings=24, mat=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=godot_to_blender_loc(loc), segments=segments,
                                          ring_count=rings)
    obj = bpy.context.active_object
    obj.name = name
    _link(obj, coll)
    if mat:
        obj.data.materials.append(mat)
    return obj


def add_icosphere(coll, name, radius, loc=(0, 0, 0), subdiv=3, mat=None):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=radius, location=godot_to_blender_loc(loc), subdivisions=subdiv)
    obj = bpy.context.active_object
    obj.name = name
    _link(obj, coll)
    if mat:
        obj.data.materials.append(mat)
    return obj


def add_crystal(coll, name, radius, height, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, sides=12):
    """Faceted double-cone crystal shard. The two half-cones are built tip-up
    in Blender's own local Z-up space (no Godot conversion at this stage,
    since this is purely local sub-geometry); the single Godot->Blender basis
    map is then applied once to the joined shard's final loc/rot, matching
    every other primitive helper's convention."""
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius, radius2=radius * 0.06,
                                     depth=height * 0.62, location=(0, 0, height * 0.31))
    top = bpy.context.active_object
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius * 0.85, radius2=0.0,
                                     depth=height * 0.38, location=(0, 0, -height * 0.19),
                                     rotation=(math.pi, 0, 0))
    bottom = bpy.context.active_object
    bpy.ops.object.select_all(action='DESELECT')
    top.select_set(True)
    bottom.select_set(True)
    bpy.context.view_layer.objects.active = top
    bpy.ops.object.join()
    crystal = bpy.context.active_object
    crystal.name = name
    crystal.location = godot_to_blender_loc(loc)
    crystal.rotation_euler = godot_to_blender_rot(rot)
    _link(crystal, coll)
    if mat:
        crystal.data.materials.append(mat)
    return crystal


def apply_uv_smart(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')


def add_bevel_and_apply(obj, width=0.012, segments=4):
    mod = obj.modifiers.new("Bevel", 'BEVEL')
    mod.width = width
    mod.segments = segments
    mod.limit_method = 'ANGLE'
    mod.angle_limit = math.radians(35)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def add_subsurf_and_apply(obj, levels=1):
    """Adds one level of Catmull-Clark subdivision for premium faceted density
    on hero geometry, keeping the flat-shaded faceted look via later autosmooth."""
    mod = obj.modifiers.new("Subsurf", 'SUBSURF')
    mod.levels = levels
    mod.render_levels = levels
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def shade_flat_with_autosmooth(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.object.shade_flat()
    if hasattr(obj.data, "use_auto_smooth"):
        obj.data.use_auto_smooth = True
        obj.data.auto_smooth_angle = math.radians(45)


# ---------------------------------------------------------------------------
# Shared pedestal builder — reproduces the existing Godot node naming so the
# GLB parts line up with quest_object_base.gd expectations.
# ---------------------------------------------------------------------------


def build_pedestal(coll, stone_mat, ring_mat, circuit_mat):
    parts = []
    parts.append(add_cylinder(coll, "PedestalStoneBase", 0.86, 0.2, loc=(0, -0.02, 0), segments=24, mat=stone_mat))
    parts.append(add_cylinder(coll, "PedestalStoneCrown", 0.7, 0.16, loc=(0, 0.12, 0), segments=24, mat=stone_mat))
    parts.append(add_torus(coll, "PedestalEnergyRing", 0.715, 0.035, loc=(0, 0.05, 0), major_seg=32, minor_seg=12,
                            mat=ring_mat))
    parts.append(add_torus(coll, "PedestalInnerRing", 0.515, 0.035, loc=(0, 0.12, 0), major_seg=32, minor_seg=12,
                            mat=ring_mat))

    # 12 armor plates ringed around the base, alternating with circuit studs,
    # matching PedestalArmorNN / PedestalCircuitStudNN naming used in-engine.
    plate_count = 12
    for i in range(plate_count):
        angle = (2 * math.pi / plate_count) * i
        x = math.sin(angle) * 0.79
        z = math.cos(angle) * 0.79
        plate = add_box(coll, f"PedestalArmor{i:02d}", (0.16, 0.12, 0.03),
                         loc=(x, 0.02, z), rot=(0, -angle, 0), mat=stone_mat)
        parts.append(plate)
        if i % 2 == 0:
            sx = math.sin(angle) * 0.88
            sz = math.cos(angle) * 0.88
            stud = add_icosphere(coll, f"PedestalCircuitStud{i:02d}", 0.045, loc=(sx, 0.12, sz),
                                  subdiv=2, mat=circuit_mat)
            parts.append(stud)

    for strut_i, ang in enumerate((0.0, math.radians(120), math.radians(240))):
        x = math.sin(ang) * 0.4
        z = math.cos(ang) * 0.4
        strut = add_box(coll, "PedestalStrut" if strut_i == 0 else f"PedestalStrut{strut_i}",
                         (0.08, 0.06, 0.31), loc=(x, 0.08, z), rot=(0, -ang, 0), mat=stone_mat)
        parts.append(strut)

    return parts


UCX_LOC = (0, 0.42, 0)


def build_collision(coll, name_prefix):
    box = add_box(coll, f"UCX_{name_prefix}", (0.86, 0.86, 0.86), loc=(0, 0.5, 0))
    box.display_type = 'WIRE'
    return box


# ---------------------------------------------------------------------------
# Per-object hero geometry builders.
# Each returns (hero_parts:list[Object], state_groups: dict[str, list[Object]])
# state_groups keys are a subset of {"inactive", "active", "completed"}.
# ---------------------------------------------------------------------------


def build_thought_spark_socket(coll, accent_mat, crystal_mat_bright, circuit_mat):
    hero = []
    hero.append(add_cylinder(coll, "SparkReceiverBowl", 0.42, 0.14, loc=(0, 0.26, 0), segments=14, mat=accent_mat))
    hero.append(add_torus(coll, "SocketCrown", 0.38, 0.045, loc=(0, 0.34, 0), mat=circuit_mat))
    for i, ang in enumerate((0, math.radians(120), math.radians(240))):
        x = math.sin(ang) * 0.5
        z = math.cos(ang) * 0.5
        hero.append(add_icosphere(coll, f"Pip{i+1}", 0.07, loc=(x, 0.3, z), subdiv=1, mat=circuit_mat))

    inactive = [add_crystal(coll, "CentralSpark_Inactive", 0.1, 0.34, loc=(0, 0.42, 0), mat=circuit_mat)]
    active = [add_crystal(coll, "CentralSpark_Active", 0.14, 0.46, loc=(0, 0.46, 0), mat=crystal_mat_bright)]
    completed = [add_crystal(coll, "CentralSpark", 0.18, 0.6, loc=(0, 0.52, 0), mat=crystal_mat_bright),
                 add_cone(coll, "SparkBeam", 0.02, 0.16, 0.9, loc=(0, 0.95, 0), segments=8, mat=crystal_mat_bright)]
    return hero, {"inactive": inactive, "active": active, "completed": completed}


def build_evidence_scanner(coll, accent_mat, crystal_mat, circuit_mat):
    hero = []
    hero.extend(add_hollow_frame(coll, "ScannerFrame", 0.62, 0.5, 0.07, 0.08, loc=(0, 0.5, 0), mat=accent_mat))
    hero.append(add_box(coll, "ScannerGlass", (0.48, 0.36, 0.02), loc=(0, 0.5, 0.03), mat=crystal_mat))
    hero.append(add_icosphere(coll, "ScannerCrystal", 0.09, loc=(0, 0.86, 0), subdiv=1, mat=crystal_mat))
    for i, x in enumerate((-0.2, 0.2)):
        name = "FactButton" if i == 0 else "FearButton"
        col = GREEN if i == 0 else FEAR_RED
        mat = accent_material(f"Scanner_{name}", col)
        hero.append(add_cylinder(coll, name, 0.09, 0.03, loc=(x, 0.2, 0.1), segments=12, mat=mat))

    inactive = [add_box(coll, "ScannerGlass_State_Inactive", (0.46, 0.34, 0.015), loc=(0, 0.5, 0.07),
                         mat=circuit_mat)]
    active = [add_box(coll, "ScannerGlass_State_Active", (0.46, 0.34, 0.015), loc=(0, 0.5, 0.07),
                       mat=accent_material("Scanner_Active", GOLD))]
    completed = [add_box(coll, "ScannerGlass_State_Completed", (0.46, 0.34, 0.015), loc=(0, 0.5, 0.07),
                          mat=accent_material("Scanner_Completed", GREEN))]
    return hero, {"inactive": inactive, "active": active, "completed": completed}


def build_perspective_lens(coll, accent_mat, crystal_mat, circuit_mat):
    hero = []
    ring = add_torus(coll, "LensBody", 0.38, 0.05, loc=(0, 0.5, 0), rot=(math.radians(90), 0, 0), mat=accent_mat)
    hero.append(ring)
    lens_face = add_cylinder(coll, "LensCrystal", 0.32, 0.05, loc=(0, 0.5, 0), segments=12, mat=crystal_mat)
    lens_face.rotation_euler = godot_to_blender_rot((math.radians(90), 0, 0))
    hero.append(lens_face)
    for side, x in (("L", -0.5), ("R", 0.5)):
        hero.append(add_box(coll, f"LensSupport{side}", (0.06, 0.06, 0.5), loc=(x, 0.5, -0.1),
                             rot=(math.radians(20) if side == "L" else -math.radians(20), 0, 0), mat=accent_mat))
    hero.append(add_cone(coll, "PathBeam", 0.03, 0.22, 1.1, loc=(0.7, 0.5, 0), rot=(0, 0, math.radians(90)),
                          segments=8, mat=circuit_mat))

    inactive = [add_cylinder(coll, "LensGlass_Inactive", 0.28, 0.03, loc=(0, 0.5, 0.02), segments=16,
                              mat=circuit_mat)]
    active = [add_cylinder(coll, "LensGlass_Active", 0.28, 0.03, loc=(0, 0.5, 0.02), segments=16,
                            mat=accent_material("Lens_Active", GOLD))]
    completed = [add_cylinder(coll, "LensGlass_Completed", 0.28, 0.03, loc=(0, 0.5, 0.02), segments=16,
                               mat=accent_material("Lens_Completed", GOLD, strength=2.0))]
    return hero, {"inactive": inactive, "active": active, "completed": completed}


def build_memory_constellation(coll, accent_mat, crystal_mat, circuit_mat):
    hero = []
    hero.extend(add_hollow_frame(coll, "ConstellationFrame", 0.66, 0.56, 0.07, 0.06, loc=(0, 0.5, 0), mat=accent_mat))
    hero.append(add_box(coll, "ConstellationSlate", (0.52, 0.42, 0.02), loc=(0, 0.5, 0.02), mat=crystal_mat))
    for i, ang in enumerate((0, math.radians(90), math.radians(180), math.radians(270))):
        x = math.sin(ang) * 0.33
        y = 0.5 + math.cos(ang) * 0.28
        hero.append(add_icosphere(coll, f"FrameJewel{i+1}", 0.035, loc=(x, y, 0.045), subdiv=1, mat=crystal_mat))
    sockets = [(-0.18, 0.62), (0.18, 0.62), (0.0, 0.34)]
    for i, (x, y) in enumerate(sockets):
        hero.append(add_icosphere(coll, f"Socket{i+1}", 0.055, loc=(x, y, 0.05), subdiv=1, mat=circuit_mat))
    for i in range(2):
        x0, y0 = sockets[i]
        x1, y1 = sockets[i + 1]
        mid = ((x0 + x1) / 2, (y0 + y1) / 2, 0.05)
        length = math.hypot(x1 - x0, y1 - y0)
        ang = math.atan2(x1 - x0, y1 - y0)
        link = add_box(coll, f"MemoryLink{i+1}", (0.015, length * 0.5, 0.015), loc=mid,
                        rot=(math.radians(90), 0, ang), mat=circuit_mat)
        hero.append(link)

    inactive = [add_material_swap_plane(coll, "ConstellationGlyph_Inactive", loc=(0, 0.5, 0.09), mat=circuit_mat)]
    active = [add_material_swap_plane(coll, "ConstellationGlyph_Active", loc=(0, 0.5, 0.09),
                                       mat=accent_material("Constellation_Active", VIOLET_BRIGHT))]
    completed = [add_icosphere(coll, "ConstellationStar", 0.09, loc=(0, 0.9, 0.05), subdiv=1,
                                mat=accent_material("Constellation_Completed", GOLD, strength=2.0))]
    return hero, {"inactive": inactive, "active": active, "completed": completed}


def add_material_swap_plane(coll, name, loc, mat):
    """A vertical plane facing forward (-Z in Godot), tipped up from its
    default flat/ground-facing orientation by a Godot-space X rotation so it
    routes through the same basis map as every other primitive helper."""
    bpy.ops.mesh.primitive_plane_add(size=0.4, location=godot_to_blender_loc(loc),
                                      rotation=godot_to_blender_rot((math.radians(90), 0, 0)))
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    _link(obj, coll)
    obj.data.materials.append(mat)
    return obj


def build_logic_gate_arch(coll, accent_mat, crystal_mat, circuit_mat):
    hero = []
    for side, x in (("L", -0.42), ("R", 0.42)):
        hero.append(add_box(coll, f"LogicPillar{side}" if side == "L" else "LogicPillar",
                             (0.14, 0.9, 0.14), loc=(x, 0.65, 0), mat=accent_mat))
    hero.append(add_box(coll, "LogicLintel", (1.0, 0.16, 0.16), loc=(0, 1.12, 0), mat=accent_mat))
    hero.append(add_crystal(coll, "GateCrownCrystal", 0.13, 0.34, loc=(0, 1.3, 0), mat=crystal_mat))
    for i, x in enumerate((-0.42, 0.42)):
        hero.append(add_icosphere(coll, f"EvidenceSocket{i+1}", 0.08, loc=(x, 0.34, 0.16), subdiv=1,
                                   mat=circuit_mat))

    inactive = [add_box(coll, "Door", (0.7, 0.9, 0.05), loc=(0, 0.55, 0), mat=stone_material("GateDoor"))]
    active = [add_box(coll, "Door_Active", (0.7, 0.9, 0.05), loc=(0, 0.55, 0),
                       mat=accent_material("Gate_Active", GOLD))]
    completed = [add_box(coll, "Door_Completed", (0.7, 0.04, 0.05), loc=(0, 1.4, 0),
                          mat=accent_material("Gate_Completed", GREEN)),
                 add_cone(coll, "PathBeam", 0.03, 0.2, 0.6, loc=(0, 0.3, 0.4), segments=8, mat=circuit_mat)]
    return hero, {"inactive": inactive, "active": active, "completed": completed}


def build_truth_bridge_tile(coll, accent_mat, crystal_mat, circuit_mat):
    hero = []
    hero.append(add_box(coll, "BridgeTile", (0.9, 0.06, 0.9), loc=(0, 0.24, 0), mat=accent_mat))
    hero.append(add_box(coll, "CircuitTile", (0.78, 0.02, 0.78), loc=(0, 0.28, 0), mat=circuit_mat))
    hero.append(add_torus(coll, "TileCircuitRing", 0.3, 0.02, loc=(0, 0.3, 0), mat=circuit_mat))
    for i in range(3):
        ang = (2 * math.pi / 3) * i
        x = math.sin(ang) * 0.34
        z = math.cos(ang) * 0.34
        hero.append(add_box(coll, f"TileCircuitSpoke{i:02d}", (0.28, 0.01, 0.03), loc=(x * 0.5, 0.3, z * 0.5),
                             rot=(0, -ang, 0), mat=circuit_mat))
    corners = [(-0.4, -0.4), (0.4, -0.4), (-0.4, 0.4), (0.4, 0.4)]
    for i, (x, z) in enumerate(corners):
        hero.append(add_icosphere(coll, f"TileCorner{i:02d}", 0.05, loc=(x, 0.3, z), subdiv=1, mat=crystal_mat))

    inactive = [add_material_swap_plane(coll, "CircuitTileState_Inactive", loc=(0, 0.32, 0), mat=circuit_mat)]
    active = [add_material_swap_plane(coll, "CircuitTileState_Active", loc=(0, 0.32, 0),
                                       mat=accent_material("Bridge_Active", GOLD))]
    completed = [add_crystal(coll, "CompletionCrystal", 0.1, 0.3, loc=(0, 0.5, 0),
                              mat=accent_material("Bridge_Completed", GREEN, strength=2.0))]
    return hero, {"inactive": inactive, "active": active, "completed": completed}


def build_focus_bell_beacon(coll, accent_mat, crystal_mat, circuit_mat):
    hero = []
    shrine_stone = stone_material("BellShrine")
    for side, x in (("L", -0.34), ("R", 0.34)):
        hero.append(add_box(coll, f"ShrinePillar{side}", (0.16, 1.0, 0.16), loc=(x, 0.55, 0), mat=shrine_stone))
    hero.append(add_box(coll, "ShrineLintel", (0.84, 0.14, 0.18), loc=(0, 1.08, 0), mat=shrine_stone))
    hero.append(add_cone(coll, "FocusBell", 0.2, 0.27, 0.34, loc=(0, 0.82, 0), segments=14, mat=accent_mat))
    hero.append(add_torus(coll, "BellRim", 0.2, 0.025, loc=(0, 0.66, 0), mat=circuit_mat))
    hero.append(add_cylinder(coll, "BellHanger", 0.015, 0.24, loc=(0, 0.99, 0), segments=8, mat=circuit_mat))
    for side, x in (("L", -0.2), ("R", 0.2)):
        hero.append(add_torus(coll, f"BellWave{side}", 0.16, 0.012, loc=(x, 0.55, 0), major_seg=16, minor_seg=6,
                               mat=circuit_mat))

    inactive = [add_crystal(coll, "HintArrowMarker_Inactive", 0.05, 0.2, loc=(0, 1.25, 0), mat=circuit_mat)]
    active = [add_crystal(coll, "HintArrowMarker_Active", 0.07, 0.26, loc=(0, 1.28, 0),
                           mat=accent_material("Bell_Active", GOLD))]
    completed = [add_icosphere(coll, "HintArrowMarker_Completed", 0.09, loc=(0, 1.3, 0), subdiv=1,
                                mat=accent_material("Bell_Completed", GOLD, strength=2.2))]
    return hero, {"inactive": inactive, "active": active, "completed": completed}


def build_warden_anchor(coll, accent_mat, crystal_mat, circuit_mat):
    hero = []
    hero.append(add_icosphere(coll, "AnchorBody", 0.42, loc=(0, 0.62, 0), subdiv=2,
                               mat=stone_material("AnchorBody")))
    hero.append(add_crystal(coll, "CrystalSpine", 0.22, 0.5, loc=(0, 1.0, 0), mat=crystal_mat))
    for i in range(8):
        ang = (2 * math.pi / 8) * i
        x = math.sin(ang) * 0.5
        z = math.cos(ang) * 0.5
        hero.append(add_crystal(coll, f"WardenOuterShard{i:02d}", 0.09, 0.28, loc=(x, 0.62, z),
                                 rot=(math.radians(20), -ang, 0), mat=crystal_mat))
    hero.append(add_torus(coll, "Hurtbox_Ring", 0.36, 0.02, loc=(0, 0.5, 0), mat=circuit_mat))

    inactive = [add_icosphere(coll, "WardenShield_Inactive", 0.32, loc=(0, 0.55, 0), subdiv=2,
                               mat=stone_material("Warden_Inactive"))]
    active = [add_icosphere(coll, "WardenShield_Active", 0.32, loc=(0, 0.55, 0), subdiv=2,
                             mat=accent_material("Warden_Active", FEAR_RED))]
    completed = [add_icosphere(coll, "BrokenCore", 0.18, loc=(0, 0.5, 0), subdiv=1,
                                mat=accent_material("Warden_Broken", (0.545, 0.58, 0.663, 1.0)))]
    return hero, {"inactive": inactive, "active": active, "completed": completed}


def build_calm_rain_basin(coll, accent_mat, crystal_mat, circuit_mat):
    hero = []
    hero.append(add_cylinder(coll, "RainBasin", 0.5, 0.14, loc=(0, 0.3, 0), segments=18, mat=accent_mat))
    hero.append(add_torus(coll, "RainBasinRim", 0.5, 0.035, loc=(0, 0.37, 0), mat=circuit_mat))
    for i in range(3):
        ang = (2 * math.pi / 3) * i + math.radians(30)
        x = math.sin(ang) * 0.6
        z = math.cos(ang) * 0.6
        hero.append(add_cylinder(coll, f"BasinPost{i:02d}", 0.03, 0.5, loc=(x, 0.5, z), segments=8,
                                  mat=stone_material("BasinPost")))

    inactive = [add_cone(coll, "StormCloud_Inactive", 0.34, 0.0, 0.24, loc=(0, 1.1, 0), segments=10,
                          mat=stone_material("StormCloud"))]
    active = [add_cone(coll, "StormCloud_Active", 0.36, 0.0, 0.26, loc=(0, 1.1, 0), segments=10,
                        mat=accent_material("Rain_Active", (0.7, 0.75, 0.9, 1.0)))]
    completed = [add_material_swap_plane(coll, "BasinWater", loc=(0, 0.38, 0),
                                          mat=accent_material("Rain_Completed", (0.49, 0.76, 1.0, 1.0),
                                                               strength=1.8))]
    return hero, {"inactive": inactive, "active": active, "completed": completed}


def build_identity_reflection_mirror(coll, accent_mat, crystal_mat, circuit_mat):
    hero = []
    hero.append(add_torus(coll, "MirrorFrame", 0.42, 0.06, loc=(0, 0.62, 0), rot=(math.radians(90), 0, 0),
                           major_seg=32, minor_seg=14, mat=accent_mat))
    hero.append(add_torus(coll, "MirrorJewelRing", 0.34, 0.025, loc=(0, 0.62, 0.05), rot=(math.radians(90), 0, 0),
                           major_seg=24, minor_seg=10, mat=crystal_mat))
    for i in range(6):
        ang = (2 * math.pi / 6) * i
        x = math.sin(ang) * 0.44
        y = 0.62 + math.cos(ang) * 0.44
        hero.append(add_icosphere(coll, f"MirrorGem{i:02d}", 0.045, loc=(x, y, 0.06), subdiv=1, mat=crystal_mat))

    inactive = [add_cylinder(coll, "ReflectionSurface_Inactive", 0.3, 0.03, loc=(0, 0.62, 0.02), segments=24,
                              mat=stone_material("Reflect_Inactive"))]
    active = [add_cylinder(coll, "ReflectionSurface_Active", 0.3, 0.03, loc=(0, 0.62, 0.02), segments=24,
                            mat=crystal_mat)]
    completed = [add_cylinder(coll, "ReflectionSurface", 0.3, 0.03, loc=(0, 0.62, 0.02), segments=24,
                               mat=accent_material("Reflect_Completed", (0.96, 1.0, 1.0, 1.0), strength=1.8))]
    for grp in (inactive, active, completed):
        grp[0].rotation_euler = godot_to_blender_rot((math.radians(90), 0, 0))
    return hero, {"inactive": inactive, "active": active, "completed": completed}


def build_checkpoint_server_root(coll, accent_mat, crystal_mat, circuit_mat):
    hero = []
    hero.extend(add_hollow_frame(coll, "ServerConsole", 0.5, 0.6, 0.06, 0.28, loc=(0, 0.35, 0),
                                  mat=stone_material("ServerConsole")))
    hero.append(add_box(coll, "ServerConsolePanel", (0.38, 0.48, 0.02), loc=(0, 0.35, 0.11), mat=circuit_mat))
    hero.append(add_cylinder(coll, "ServerRootTrunk", 0.1, 0.9, loc=(0, 0.9, 0), segments=10, mat=accent_mat))
    hero.append(add_box(coll, "LivingRootBranch", (0.5, 0.05, 0.05), loc=(0, 1.15, 0), rot=(0, 0, math.radians(20)),
                         mat=circuit_mat))
    for i, ang in enumerate((math.radians(200), math.radians(250), math.radians(290))):
        x = math.sin(ang) * 0.32
        z = math.cos(ang) * 0.18
        hero.append(add_box(coll, f"RootBranchLower{i:02d}", (0.28, 0.04, 0.04), loc=(x * 0.5, 0.5, z),
                             rot=(0, ang, 0), mat=circuit_mat))
    hero.append(add_crystal(coll, "RootCanopyCrystal", 0.14, 0.32, loc=(0, 1.42, 0), mat=crystal_mat))
    for i, x in enumerate((-0.16, 0.0, 0.16)):
        names = ("MenuButtonSave", "MenuButtonHeal", "MenuButtonTask")
        cols = (CYAN, GREEN, VIOLET_BRIGHT)
        mat = accent_material(f"Server_{names[i]}", cols[i])
        hero.append(add_cylinder(coll, names[i], 0.06, 0.02, loc=(x, 0.85, 0.16), segments=12, mat=mat))

    inactive = [add_material_swap_plane(coll, "ServerConsoleGlow_Inactive", loc=(0, 0.6, 0.16), mat=circuit_mat)]
    active = [add_material_swap_plane(coll, "ServerConsoleGlow_Active", loc=(0, 0.6, 0.16),
                                       mat=accent_material("Server_Active", GOLD))]
    completed = [add_material_swap_plane(coll, "ServerConsoleGlow_Completed", loc=(0, 0.6, 0.16),
                                          mat=accent_material("Server_Completed", GREEN, strength=1.8))]
    return hero, {"inactive": inactive, "active": active, "completed": completed}


def build_clear_path_projector(coll, accent_mat, crystal_mat, circuit_mat):
    hero = []
    hero.append(add_cylinder(coll, "RouteProjector", 0.16, 0.5, loc=(0, 0.55, 0), segments=12, mat=accent_mat))
    hero.append(add_crystal(coll, "ProjectorTip", 0.09, 0.3, loc=(0, 0.9, 0), mat=crystal_mat))
    for i in range(9):
        t = i / 8.0
        x = t * 2.1
        y = 0.06 + math.sin(t * math.pi) * 0.14
        hero.append(add_icosphere(coll, f"RouteDot{i:02d}", 0.03, loc=(x, y, 0), subdiv=1, mat=circuit_mat))

    inactive = [add_icosphere(coll, "ProjectorBeam_Inactive", 0.04, loc=(0.2, 0.1, 0), subdiv=1, mat=circuit_mat)]
    active = [add_cone(coll, "ProjectorBeam_Active", 0.05, 0.14, 1.9, loc=(1.05, 0.08, 0),
                        rot=(0, 0, math.radians(90)), segments=8, mat=accent_material("Projector_Active", GOLD))]
    completed = [add_icosphere(coll, "ProjectorGoalStar", 0.1, loc=(2.1, 0.14, 0), subdiv=1,
                                mat=accent_material("Projector_Completed", GOLD, strength=2.2))]
    return hero, {"inactive": inactive, "active": active, "completed": completed}


BUILDERS = {
    "thought_spark_socket": build_thought_spark_socket,
    "evidence_scanner": build_evidence_scanner,
    "perspective_lens": build_perspective_lens,
    "memory_constellation_board": build_memory_constellation,
    "logic_gate_arch": build_logic_gate_arch,
    "truth_bridge_tile": build_truth_bridge_tile,
    "focus_bell_beacon": build_focus_bell_beacon,
    "warden_anchor": build_warden_anchor,
    "calm_rain_basin": build_calm_rain_basin,
    "identity_reflection_mirror": build_identity_reflection_mirror,
    "checkpoint_server_root": build_checkpoint_server_root,
    "clear_path_projector": build_clear_path_projector,
}

# ---------------------------------------------------------------------------
# LOD generation
# ---------------------------------------------------------------------------


def make_decimated_copy(obj, ratio, name):
    dup = obj.copy()
    dup.data = obj.data.copy()
    dup.name = name
    bpy.context.scene.collection.objects.link(dup)
    if len(dup.data.polygons) > 8:
        mod = dup.modifiers.new("Decimate", 'DECIMATE')
        mod.ratio = ratio
        bpy.context.view_layer.objects.active = dup
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.scene.collection.objects.unlink(dup)
    return dup


def join_all(objs, name):
    if not objs:
        return None
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    return joined


def count_tris(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(depsgraph)
    mesh = eval_obj.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    tri_count = len(bm.faces)
    bm.free()
    eval_obj.to_mesh_clear()
    return tri_count


# ---------------------------------------------------------------------------
# Build one object end-to-end
# ---------------------------------------------------------------------------


def build_object(spec):
    obj_id = spec["id"]
    root_coll = new_collection(obj_id)
    lod0_coll = new_collection(f"{obj_id}_LOD0", root_coll)

    stone_mat = stone_material(obj_id)
    ring_mat = accent_material(f"{obj_id}_ring", spec["accent"], strength=1.35)
    circuit_mat = circuit_material(obj_id, CYAN)
    crystal_mat_bright = crystal_material(obj_id, VIOLET_BRIGHT)
    hero_accent_mat = accent_material(f"{obj_id}_hero", spec["accent"], strength=1.35)

    texture_path = os.path.join(TEXTURE_DIR, spec["texture"])
    tex_mat = albedo_material(obj_id, texture_path)

    pedestal_parts = build_pedestal(lod0_coll, stone_mat, ring_mat, circuit_mat)
    hero_parts, state_groups = BUILDERS[obj_id](lod0_coll, hero_accent_mat, crystal_mat_bright, circuit_mat)
    ucx = build_collision(lod0_coll, obj_id)

    # Root empty carrying the same top-level name convention as the Godot
    # model scenes (e.g. "WardenAnchorModel").
    pascal = "".join(part.capitalize() for part in obj_id.split("_"))
    root_name = f"{pascal}Model"

    all_mesh_objs = pedestal_parts + hero_parts
    for grp in state_groups.values():
        all_mesh_objs += grp

    # Only the large hero silhouette parts get a subsurf pass on top of the
    # bevel; pedestal studs/pips/state markers are already dense enough from
    # their own primitive resolution and would blow the triangle budget if
    # subdivided too.
    subsurf_objs = set(id(o) for o in hero_parts)
    if obj_id == "identity_reflection_mirror":
        # MirrorJewelRing is already a smoothly tessellated torus (24 x 10)
        # with a bevel pass. Subdividing it again adds 7,200 triangles without
        # a visible silhouette improvement and pushes this prop over the 40k
        # hard budget. Keep the outer frame and six faceted jewels subdivided;
        # only this redundant inner-ring subdivision is omitted.
        subsurf_objs.discard(id(next(o for o in hero_parts if o.name == "MirrorJewelRing")))

    for o in all_mesh_objs:
        add_bevel_and_apply(o)
        if id(o) in subsurf_objs:
            # The bevel's extra edge loops act as support loops so this
            # Catmull-Clark pass adds premium faceted density without
            # rounding hard edges into a blob.
            add_subsurf_and_apply(o, levels=1)
        shade_flat_with_autosmooth(o)
        apply_uv_smart(o)
        # Assign the shared albedo texture material as an alternate slot for
        # the named hero target part, then repoint every polygon at that slot
        # so the texture actually renders on the hero surface instead of
        # sitting in an unused material slot.
        if o.name.split("_")[0] == spec["hero_target"].split("/")[-1]:
            o.data.materials.append(tex_mat)
            albedo_slot = len(o.data.materials) - 1
            for poly in o.data.polygons:
                poly.material_index = albedo_slot

    tri_total = sum(count_tris(o) for o in all_mesh_objs)

    lod1_coll = new_collection(f"{obj_id}_LOD1", root_coll)
    lod2_coll = new_collection(f"{obj_id}_LOD2", root_coll)
    lod1_objs = []
    lod2_objs = []
    for o in all_mesh_objs:
        d1 = make_decimated_copy(o, 0.5, f"{o.name}_LOD1")
        d2 = make_decimated_copy(o, 0.22, f"{o.name}_LOD2")
        lod1_coll.objects.link(d1)
        lod2_coll.objects.link(d2)
        lod1_objs.append(d1)
        lod2_objs.append(d2)

    tri_lod1 = sum(count_tris(o) for o in lod1_objs)
    tri_lod2 = sum(count_tris(o) for o in lod2_objs)

    # Parent everything under a root empty so glTF export nests correctly and
    # matches the Model root-node naming used in scenes/.../models/*.tscn.
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
    root_empty = bpy.context.active_object
    root_empty.name = root_name
    root_coll.objects.link(root_empty)
    bpy.context.scene.collection.objects.unlink(root_empty)

    lod_empties = {}
    for lod_name, coll, objs in (("LOD0", lod0_coll, all_mesh_objs),
                                  ("LOD1", lod1_coll, lod1_objs),
                                  ("LOD2", lod2_coll, lod2_objs)):
        bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
        lod_root = bpy.context.active_object
        lod_root.name = lod_name
        coll.objects.link(lod_root)
        bpy.context.scene.collection.objects.unlink(lod_root)
        lod_root.parent = root_empty
        for o in objs:
            o.parent = lod_root
        lod_empties[lod_name] = lod_root

    ucx.parent = lod_empties["LOD0"]

    bounds_min = Vector((math.inf, math.inf, math.inf))
    bounds_max = Vector((-math.inf, -math.inf, -math.inf))
    for o in all_mesh_objs:
        for corner in o.bound_box:
            world_corner = o.matrix_world @ Vector(corner)
            bounds_min.x = min(bounds_min.x, world_corner.x)
            bounds_min.y = min(bounds_min.y, world_corner.y)
            bounds_min.z = min(bounds_min.z, world_corner.z)
            bounds_max.x = max(bounds_max.x, world_corner.x)
            bounds_max.y = max(bounds_max.y, world_corner.y)
            bounds_max.z = max(bounds_max.z, world_corner.z)

    manifest_parts = {}
    for o in all_mesh_objs:
        manifest_parts[o.name] = {
            "triangles": count_tris(o),
            "materials": [m.name for m in o.data.materials if m],
        }

    state_part_names = {state: [o.name for o in objs] for state, objs in state_groups.items()}

    return dict(
        object_id=obj_id,
        root_node=root_name,
        hero_target=spec["hero_target"],
        collision_node=ucx.name,
        triangles_lod0=tri_total,
        triangles_lod1=tri_lod1,
        triangles_lod2=tri_lod2,
        bounds_min=[bounds_min.x, bounds_min.y, bounds_min.z],
        bounds_max=[bounds_max.x, bounds_max.y, bounds_max.z],
        state_parts=state_part_names,
        parts=manifest_parts,
        materials=sorted({m.name for o in all_mesh_objs for m in o.data.materials if m}),
        texture=spec["texture"],
    ), root_empty


_NAME_SUFFIX_RE = re.compile(r"\.\d{3}$")


def _clean_name(name):
    """Strips Blender's auto-disambiguation suffix (e.g. "LOD0.001" -> "LOD0")
    so multiple objects sharing a semantic name across the combined .blend
    file (12 x "LOD0", "PedestalArmor00", ...) still export with clean,
    semantic node names into each object's own standalone GLB."""
    return _NAME_SUFFIX_RE.sub("", name)


def export_glb(root_empty, obj_id):
    bpy.ops.object.select_all(action='DESELECT')

    def select_recursive(obj):
        obj.select_set(True)
        for child in obj.children:
            select_recursive(child)

    select_recursive(root_empty)
    selected = [o for o in bpy.context.selected_objects]
    mesh_data = {o.data for o in selected if o.type == 'MESH' and o.data is not None}

    # Rename to strip ".001"-style suffixes so this object's own GLB gets
    # clean, semantic node names. Afterwards, rename to an obj_id-namespaced
    # name (rather than restoring the original) so the plain semantic name is
    # freed up for the next object's export pass instead of staying claimed
    # by this object for the rest of the Blender session.
    for o in selected:
        o.name = _clean_name(o.name)
    for mesh in mesh_data:
        mesh.name = _clean_name(mesh.name)

    out_path = os.path.join(GLB_DIR, f"{obj_id}.glb")
    try:
        bpy.ops.export_scene.gltf(
            filepath=out_path,
            use_selection=True,
            export_format='GLB',
            export_apply=True,
            export_yup=True,
            export_materials='EXPORT',
            export_cameras=False,
            export_lights=False,
            export_animations=False,
        )
    finally:
        for o in selected:
            o.name = f"{obj_id}::{o.name}"
        for mesh in mesh_data:
            mesh.name = f"{obj_id}::{mesh.name}"

    return out_path


def main():
    reset_scene()
    report = {"objects": []}

    for spec in OBJECTS:
        manifest, root_empty = build_object(spec)
        out_path = export_glb(root_empty, spec["id"])
        manifest["glb_path"] = os.path.relpath(out_path, REPO_ROOT)
        manifest["glb_exists"] = os.path.exists(out_path)
        manifest["glb_size_bytes"] = os.path.getsize(out_path) if manifest["glb_exists"] else 0
        report["objects"].append(manifest)
        print(f"[build] {spec['id']}: LOD0={manifest['triangles_lod0']} tris "
              f"LOD1={manifest['triangles_lod1']} LOD2={manifest['triangles_lod2']} -> {out_path}")

    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    report["blend_path"] = os.path.relpath(BLEND_PATH, REPO_ROOT)

    with open(REPORT_PATH, "w") as f:
        json.dump(report, f, indent=2)

    print(f"[build] wrote report to {REPORT_PATH}")
    print(f"[build] wrote blend to {BLEND_PATH}")


if __name__ == "__main__":
    main()
