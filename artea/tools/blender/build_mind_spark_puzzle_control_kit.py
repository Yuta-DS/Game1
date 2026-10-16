"""Build the heavenly production controls used by the Island One puzzle.

Creates three reusable assets: pressure regulator, coupled-orbit selector and
confirmation altar. Source parts remain independent; runtime exports are joined
by semantic system. All mesh faces are explicitly triangulated.
"""

from __future__ import annotations

import json
import math
from collections import Counter, OrderedDict
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
ASSET_ROOT = ROOT / "assets3D" / "mind_spark" / "puzzle_control_kit"
BLEND_PATH = ASSET_ROOT / "blend" / "mind_spark_puzzle_control_kit.blend"
MANIFEST_PATH = ASSET_ROOT / "puzzle_control_kit_manifest.json"
RENDER_PATH = ROOT / "artifacts" / "mind_spark_puzzle_control_kit" / "heavenly_puzzle_controls.png"
KINDS = ("regulator", "selector", "confirmation")

COLORS = OrderedDict(
    pearl=(1.0, 0.97, 0.89, 1.0),
    ivory=(0.91, 0.82, 0.67, 1.0),
    champagne=(1.0, 0.78, 0.34, 1.0),
    gold=(0.88, 0.51, 0.13, 1.0),
    bronze=(0.37, 0.20, 0.10, 1.0),
    teal=(0.03, 0.37, 0.40, 1.0),
    aether=(0.24, 0.92, 0.96, 1.0),
    lavender=(0.65, 0.46, 0.84, 1.0),
)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def collection(name):
    coll = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(coll)
    return coll


def material(name, color, metallic=0.0, roughness=0.5, emission=0.0):
    mat = bpy.data.materials.new("MSPC_" + name.upper())
    mat.use_nodes = True
    mat.diffuse_color = color
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if bsdf.inputs.get("Coat Weight"):
        bsdf.inputs["Coat Weight"].default_value = 0.25 if metallic else 0.12
        bsdf.inputs["Coat Roughness"].default_value = 0.16
    if emission:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission
    texcoord = mat.node_tree.nodes.new("ShaderNodeTexCoord")
    noise = mat.node_tree.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 5.5 if metallic == 0 else 24.0
    noise.inputs["Detail"].default_value = 3.0
    bump = mat.node_tree.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.10 if metallic == 0 else 0.03
    bump.inputs["Distance"].default_value = 0.045 if metallic == 0 else 0.014
    mat.node_tree.links.new(texcoord.outputs["Generated"], noise.inputs["Vector"])
    mat.node_tree.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    mat.node_tree.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    if name in ("aether", "lavender"):
        if bsdf.inputs.get("Transmission Weight"):
            bsdf.inputs["Transmission Weight"].default_value = 0.24
        if bsdf.inputs.get("Coat Weight"):
            bsdf.inputs["Coat Weight"].default_value = 0.50
    return mat


def move(obj, coll):
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    coll.objects.link(obj)


def finish(obj, bevel=0.05):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if bevel:
        mod = obj.modifiers.new("Soft production edge", "BEVEL")
        mod.width, mod.segments = bevel, 2
    obj.modifiers.new("Triangle delivery topology", "TRIANGULATE")
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for face in obj.data.polygons:
        face.use_smooth = True
    obj.select_set(False)
    return obj


def tag(obj, group, path, root):
    obj["semantic_group"] = group
    obj["component_path"] = path
    obj.parent = root
    return obj


def box(name, center, size, mat, coll, group, path, root, bevel=0.06, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=center, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    move(obj, coll)
    return tag(finish(obj, bevel), group, path, root)


def cyl(name, center, radius, depth, mat, coll, group, path, root, vertices=24,
         rotation=(0, 0, 0), bevel=0.05):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                       location=center, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    move(obj, coll)
    return tag(finish(obj, bevel), group, path, root)


def torus(name, center, major, minor, mat, coll, group, path, root,
          rotation=(math.pi / 2, 0, 0), major_segments=32, minor_segments=8):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                    major_segments=major_segments, minor_segments=minor_segments,
                                    location=center, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    move(obj, coll)
    return tag(finish(obj, 0), group, path, root)


def sphere(name, center, radius, mat, coll, group, path, root, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    move(obj, coll)
    return tag(finish(obj, 0.025), group, path, root)


def beam(name, start, end, thickness, depth, mat, coll, group, path, root):
    start, end = Vector(start), Vector(end)
    delta = end - start
    obj = box(name, (start + end) * 0.5, (thickness, depth, delta.length), mat,
              coll, group, path, root, min(0.04, thickness * 0.18))
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    return obj


def star(name, center, radius, mat, coll, group, path, root, rays=8):
    for index in range(rays):
        angle = math.tau * index / rays
        end = Vector(center) + Vector((math.cos(angle) * radius, 0, math.sin(angle) * radius))
        beam(f"{name}_Ray_{index:02d}", center, end, 0.16 if index % 2 else 0.22,
             0.15, mat, coll, group, path, root)
        sphere(f"{name}_Pearl_{index:02d}", end, 0.10, mat, coll, group, path, root, 1)


def build_common(kind, coll, mats):
    root = bpy.data.objects.new(f"MSPC_{kind.title()}_Editable", None)
    coll.objects.link(root)
    root["control_kind"] = kind
    path = f"{kind.upper()}/BODY"
    # Four-layer lotus-like civic base.
    for tier, (radius, depth, z) in enumerate(((3.65, 0.34, 0.18), (3.28, 0.42, 0.52),
                                               (2.94, 0.46, 0.94), (2.62, 0.50, 1.38))):
        cyl(f"{kind}_PlinthCourse_{tier:02d}", (0, 0, z), radius, depth,
             mats["pearl" if tier % 2 else "ivory"], coll, "STONE", path, root, 32, bevel=0.09)
    torus(f"{kind}_PlinthGoldKerb", (0, 0, 1.65), 2.40, 0.16, mats["champagne"],
          coll, "GOLD", path + "/KERB", root, rotation=(0, 0, 0), major_segments=32)
    # Twelve small petal brackets give the base a heavenly rather than factory silhouette.
    for index in range(12):
        angle = math.tau * index / 12
        x, y = math.cos(angle) * 2.88, math.sin(angle) * 2.88
        box(f"{kind}_LotusPetal_{index:02d}", (x, y, 1.36), (0.58, 0.34, 1.0),
            mats["champagne"], coll, "GOLD", path + "/LOTUS_PETALS", root, 0.08,
            rotation=(0, 0, angle))
    # Coursed tapered pedestal assembled from editable drums and ribs.
    for course in range(5):
        radius = 2.12 - course * 0.10
        z = 2.00 + course * 0.72
        cyl(f"{kind}_PedestalCourse_{course:02d}", (0, 0, z), radius, 0.62,
             mats["pearl" if course % 2 else "ivory"], coll, "STONE",
             path + "/PEDESTAL", root, 24, bevel=0.075)
    for rib in range(8):
        angle = math.tau * rib / 8
        x, y = math.cos(angle) * 2.05, math.sin(angle) * 2.05
        box(f"{kind}_PedestalGoldRib_{rib:02d}", (x, y, 3.45), (0.18, 0.22, 3.25),
            mats["gold"], coll, "GOLD", path + "/PEDESTAL_RIBS", root, 0.03,
            rotation=(0, 0, angle))
    # Deep inset face and layered celestial bezel.
    box(f"{kind}_FaceRecess", (0, -2.02, 4.15), (3.25, 0.24, 2.65), mats["teal"],
        coll, "GLASS", path + "/FACE", root, 0.14)
    for side in (-1, 1):
        box(f"{kind}_FaceGoldJamb_{side:+d}", (side * 1.72, -2.18, 4.15),
            (0.22, 0.16, 3.05), mats["champagne"], coll, "GOLD", path + "/FACE", root, 0.035)
    box(f"{kind}_FaceLintel", (0, -2.18, 5.61), (3.65, 0.18, 0.25),
        mats["champagne"], coll, "GOLD", path + "/FACE", root, 0.04)
    # Crown canopy, floating pearl and star crest.
    for tier, (radius, depth, z) in enumerate(((2.40, 0.34, 5.85), (2.05, 0.32, 6.16))):
        cyl(f"{kind}_CanopyCourse_{tier}", (0, 0, z), radius, depth, mats["pearl"],
             coll, "STONE", path + "/CANOPY", root, 28, bevel=0.07)
    torus(f"{kind}_CrownHalo", (0, -0.05, 7.28), 0.82, 0.10, mats["champagne"],
          coll, "GOLD", path + "/CROWN", root, major_segments=28)
    sphere(f"{kind}_CrownPearl", (0, -0.18, 7.28), 0.43, mats["aether"],
           coll, "GLASS", path + "/CROWN", root, 2)
    star(f"{kind}_CrownStar", (0, -0.12, 7.28), 1.18, mats["champagne"],
         coll, "GOLD", path + "/CROWN", root, 8)
    # Real fasteners at structural seams.
    for level, z in enumerate((0.72, 1.68, 5.72)):
        for index in range(12):
            angle = math.tau * index / 12
            radius = 2.95 if level == 0 else (2.42 if level == 1 else 2.10)
            sphere(f"{kind}_SeamBolt_{level}_{index:02d}",
                   (math.cos(angle) * radius, math.sin(angle) * radius, z), 0.085,
                   mats["gold"], coll, "MICRO", path + "/FASTENERS", root, 1)
    return root


def build_regulator(coll, mats):
    root = build_common("regulator", coll, mats)
    path = "REGULATOR/MECHANISM"
    center = Vector((0, -2.43, 4.18))
    # Twin pressure reservoirs and a crowned feed pipe make this silhouette
    # unmistakably an aether-pressure engine rather than another dial pedestal.
    for side in (-1, 1):
        tank_x = side * 2.72
        cyl(f"regulator_SideReservoir_{side:+d}", (tank_x, 0.15, 3.25), 0.62, 3.45,
             mats["teal"], coll, "GLASS", path + "/RESERVOIRS", root, 24, bevel=0.09)
        for band, z in enumerate((1.72, 3.25, 4.78)):
            torus(f"regulator_ReservoirBand_{side:+d}_{band}", (tank_x, 0.15, z),
                  0.63, 0.10, mats["champagne"], coll, "GOLD",
                  path + "/RESERVOIRS", root, rotation=(0, 0, 0), major_segments=24)
        sphere(f"regulator_ReservoirCrown_{side:+d}", (tank_x, 0.15, 5.15), 0.36,
               mats["aether"], coll, "GLASS", path + "/RESERVOIRS", root, 2)
        beam(f"regulator_CrownedFeedPipe_{side:+d}", (tank_x, 0.15, 5.05),
             (side * 1.25, -0.15, 6.25), 0.20, 0.20, mats["champagne"], coll,
             "GOLD", path + "/FEED_PIPES", root)
    torus("regulator_PressureCrown", (0, -0.10, 6.28), 1.35, 0.15,
          mats["champagne"], coll, "GOLD", path + "/FEED_PIPES", root,
          major_segments=32)
    torus("regulator_HandwheelOuter", center, 1.50, 0.19, mats["champagne"], coll,
          "MOVING", path, root, major_segments=36)
    torus("regulator_HandwheelInner", center + Vector((0, -0.04, 0)), 0.97, 0.10,
          mats["gold"], coll, "MOVING", path, root, major_segments=28)
    cyl("regulator_Hub", center + Vector((0, -0.22, 0)), 0.43, 0.46, mats["pearl"],
         coll, "MOVING", path, root, 20, rotation=(math.pi / 2, 0, 0), bevel=0.06)
    for index in range(8):
        angle = math.tau * index / 8
        beam(f"regulator_Spoke_{index:02d}", center,
             center + Vector((math.cos(angle) * 1.34, -0.24, math.sin(angle) * 1.34)),
             0.13, 0.13, mats["champagne"], coll, "MOVING", path, root)
    for index in range(12):
        angle = math.tau * index / 12
        box(f"regulator_GearTooth_{index:02d}",
            center + Vector((math.cos(angle) * 1.78, 0.02, math.sin(angle) * 1.78)),
            (0.32, 0.28, 0.18), mats["gold"], coll, "MOVING", path + "/TEETH", root,
            0.04, rotation=(0, angle, 0))
    # Pressure gauge and three-state luminous scale.
    torus("regulator_GaugeBezel", (0, -2.37, 2.42), 0.70, 0.11, mats["champagne"],
          coll, "GOLD", path + "/GAUGE", root, major_segments=28)
    sphere("regulator_GaugeGlass", (0, -2.44, 2.42), 0.57, mats["aether"],
           coll, "GLASS", path + "/GAUGE", root, 2)
    for index in range(3):
        angle = math.radians(220 + index * 50)
        sphere(f"regulator_StateLamp_{index}",
               (math.cos(angle) * 0.46, -3.0, 2.42 + math.sin(angle) * 0.46),
               0.09, mats["lavender" if index == 0 else "aether"], coll, "GLASS",
               path + "/GAUGE", root, 1)
    return root


def build_selector(coll, mats):
    root = build_common("selector", coll, mats)
    path = "SELECTOR/COUPLED_ORBITS"
    center = Vector((0, -2.42, 4.18))
    # An elevated armillary crown separates the selector from the pressure
    # engines and makes its linked-orbit purpose readable in silhouette.
    for side in (-1, 1):
        box(f"selector_ArmillaryPillar_{side:+d}", (side * 2.42, 0.10, 5.65),
            (0.42, 0.62, 4.20), mats["pearl"], coll, "STONE",
            path + "/ARMILLARY_FRAME", root, 0.08)
        sphere(f"selector_PillarPearl_{side:+d}", (side * 2.42, 0.10, 7.92), 0.30,
               mats["aether"], coll, "GLASS", path + "/ARMILLARY_FRAME", root, 2)
    armillary_center = (0, -0.10, 8.0)
    torus("selector_ArmillaryOrbitA", armillary_center, 2.48, 0.14,
          mats["champagne"], coll, "GOLD", path + "/ARMILLARY_CROWN", root,
          major_segments=40)
    torus("selector_ArmillaryOrbitB", armillary_center, 1.85, 0.10,
          mats["aether"], coll, "GLASS", path + "/ARMILLARY_CROWN", root,
          rotation=(math.pi / 2, math.pi / 3, 0), major_segments=36)
    torus("selector_ArmillaryOrbitC", armillary_center, 1.36, 0.09,
          mats["lavender"], coll, "GLASS", path + "/ARMILLARY_CROWN", root,
          rotation=(math.pi / 2, -math.pi / 3, 0), major_segments=32)
    sphere("selector_ArmillaryCore", (0, -0.28, 8.0), 0.58, mats["aether"], coll,
           "GLASS", path + "/ARMILLARY_CROWN", root, 3)
    for orbit, (radius, mat) in enumerate(((1.48, mats["champagne"]), (0.98, mats["aether"]))):
        torus(f"selector_Orbit_{orbit}", center + Vector((0, -orbit * 0.08, 0)), radius,
              0.14 if orbit == 0 else 0.10, mat, coll,
              "MOVING" if orbit == 0 else "GLASS", path, root, major_segments=36)
    for index in range(12):
        angle = math.tau * index / 12
        at = center + Vector((math.cos(angle) * 1.78, -0.18, math.sin(angle) * 1.78))
        box(f"selector_BearingTick_{index:02d}", at, (0.16, 0.16, 0.50 if index % 3 == 0 else 0.28),
            mats["champagne"], coll, "GOLD", path + "/TICKS", root, 0.025,
            rotation=(0, angle, 0))
    beam("selector_NoticeNeedle", center, center + Vector((0, -0.30, 1.32)),
         0.22, 0.15, mats["lavender"], coll, "MOVING", path + "/NEEDLES", root)
    beam("selector_CompanionNeedle", center, center + Vector((1.12, -0.34, -0.62)),
         0.16, 0.13, mats["aether"], coll, "MOVING", path + "/NEEDLES", root)
    sphere("selector_CenterJewel", center + Vector((0, -0.40, 0)), 0.32, mats["aether"],
           coll, "GLASS", path + "/CENTER", root, 2)
    for index, angle in enumerate((0, math.pi / 2, math.pi, math.pi * 1.5)):
        sphere(f"selector_DirectionJewel_{index}",
               center + Vector((math.cos(angle) * 1.77, -0.34, math.sin(angle) * 1.77)),
               0.15, mats["aether" if index % 2 else "lavender"], coll, "GLASS",
               path + "/DIRECTION_JEWELS", root, 1)
    # Physical lower coupling display: the action always moves two orbits.
    for side in (-1, 1):
        torus(f"selector_CouplingSocket_{side:+d}", (side * 0.78, -2.39, 2.35), 0.38,
              0.09, mats["aether" if side < 0 else "champagne"], coll, "GLASS",
              path + "/COUPLING_DISPLAY", root, major_segments=20)
    beam("selector_CouplingLink", (-0.40, -2.45, 2.35), (0.40, -2.45, 2.35),
         0.12, 0.10, mats["champagne"], coll, "GOLD", path + "/COUPLING_DISPLAY", root)
    return root


def build_confirmation(coll, mats):
    root = build_common("confirmation", coll, mats)
    path = "CONFIRMATION/STAR_LEVER"
    # Twin luminous pylons and a pointed crown make this a ceremonial threshold
    # in miniature, visually distinct from both regulator and selector.
    for side in (-1, 1):
        box(f"confirmation_CeremonyPylon_{side:+d}", (side * 2.58, 0.18, 4.55),
            (0.82, 1.05, 5.35), mats["pearl"], coll, "STONE",
            path + "/CEREMONY_PYLONS", root, 0.12)
        box(f"confirmation_PylonGlassVein_{side:+d}", (side * 2.58, -0.42, 4.55),
            (0.30, 0.16, 3.70), mats["aether"], coll, "GLASS",
            path + "/CEREMONY_PYLONS", root, 0.04)
        sphere(f"confirmation_PylonCrown_{side:+d}", (side * 2.58, 0.18, 7.48),
               0.38, mats["champagne"], coll, "GOLD",
               path + "/CEREMONY_PYLONS", root, 2)
        beam(f"confirmation_CrownSlope_{side:+d}", (side * 2.58, -0.08, 7.22),
             (0, -0.08, 9.10), 0.30, 0.30, mats["champagne"], coll,
             "GOLD", path + "/POINTED_CROWN", root)
    sphere("confirmation_CrownWisdomLight", (0, -0.25, 9.10), 0.52,
           mats["aether"], coll, "GLASS", path + "/POINTED_CROWN", root, 3)
    # A ceremonial two-hand lever makes confirmation feel consequential.
    for side in (-1, 1):
        torus(f"confirmation_PivotBezel_{side:+d}", (side * 0.92, -2.40, 3.45),
              0.48, 0.11, mats["champagne"], coll, "GOLD", path + "/PIVOTS", root,
              major_segments=24)
        beam(f"confirmation_LeverArm_{side:+d}", (side * 0.92, -2.58, 3.45),
             (side * 0.92, -2.95, 6.15), 0.24, 0.20, mats["gold"], coll,
             "MOVING", path + "/ARMS", root)
        sphere(f"confirmation_LeverPearl_{side:+d}", (side * 0.92, -3.00, 6.35),
               0.46, mats["aether"], coll, "MOVING", path + "/GRIPS", root, 2)
    beam("confirmation_CrossGrip", (-0.92, -3.0, 6.35), (0.92, -3.0, 6.35),
         0.24, 0.22, mats["champagne"], coll, "MOVING", path + "/GRIPS", root)
    torus("confirmation_WisdomSocket", (0, -2.44, 4.20), 1.24, 0.15,
          mats["champagne"], coll, "GOLD", path + "/SOCKET", root, major_segments=36)
    sphere("confirmation_WisdomCore", (0, -2.60, 4.20), 0.82, mats["lavender"],
           coll, "GLASS", path + "/SOCKET", root, 3)
    star("confirmation_WisdomStar", (0, -2.86, 4.20), 1.06, mats["aether"],
         coll, "GLASS", path + "/SOCKET", root, 8)
    return root


def select_tree(root):
    root.select_set(True)
    for child in root.children:
        select_tree(child)


def runtime_export(kind, source_root, source_coll):
    export_coll = collection(f"MSPC_{kind.upper()}_GAME_EXPORT")
    export_root = bpy.data.objects.new(f"MindSparkPuzzle{kind.title()}", None)
    export_coll.objects.link(export_root)
    grouped = OrderedDict()
    for child in source_root.children:
        if child.type == "MESH":
            grouped.setdefault(child["semantic_group"], []).append(child)
    meshes = []
    for group, sources in grouped.items():
        copies = []
        for source in sources:
            dup = source.copy()
            dup.data = source.data.copy()
            export_coll.objects.link(dup)
            dup.matrix_world = source.matrix_world.copy()
            dup.parent = None
            copies.append(dup)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in copies:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = copies[0]
        bpy.ops.object.join()
        joined = bpy.context.object
        joined.name = f"MSPC_{kind.title()}_{group.title()}"
        joined.parent = export_root
        joined["semantic_group"] = group
        joined["source_module_count"] = len(sources)
        meshes.append(joined)
    out = ASSET_ROOT / "glb" / f"mind_spark_puzzle_{kind}.glb"
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    select_tree(export_root)
    bpy.context.view_layer.objects.active = export_root
    bpy.ops.export_scene.gltf(filepath=str(out), use_selection=True, export_format="GLB",
                              export_apply=True, export_yup=True, export_materials="EXPORT",
                              export_cameras=False, export_lights=False, export_animations=False,
                              export_extras=True)
    export_coll.hide_viewport = True
    export_coll.hide_render = True
    return out, meshes, grouped


def render_lineup(roots, source_collections):
    for offset, root in zip((-9.0, 0.0, 9.0), roots):
        root.location.x = offset
    world = bpy.data.worlds.new("Heavenly Puzzle Court")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.10, 0.18, 0.29, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.40
    bpy.ops.object.light_add(type="AREA", location=(-14, -18, 20))
    key = bpy.context.object
    key.data.energy, key.data.size, key.data.color = 4300, 12, (1.0, 0.76, 0.48)
    bpy.ops.object.light_add(type="AREA", location=(15, 1, 15))
    rim = bpy.context.object
    rim.data.energy, rim.data.size, rim.data.color = 2300, 10, (0.18, 0.68, 0.86)
    bpy.ops.object.camera_add(location=(20, -33, 14))
    camera = bpy.context.object
    camera.data.lens = 56
    camera.rotation_euler = (Vector((0, 0, 3.5)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1600, 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(RENDER_PATH)
    bpy.ops.render.render(write_still=True)


def main():
    for path in (BLEND_PATH.parent, RENDER_PATH.parent):
        path.mkdir(parents=True, exist_ok=True)
    reset()
    bpy.context.scene.unit_settings.system = "METRIC"
    mats = {
        key: material(key, color,
                      metallic=0.75 if key in ("champagne", "gold", "bronze") else 0.0,
                      roughness=0.22 if key in ("champagne", "gold") else 0.55,
                      emission=3.2 if key == "aether" else (0.85 if key == "lavender" else 0.0))
        for key, color in COLORS.items()
    }
    builders = {"regulator": build_regulator, "selector": build_selector,
                "confirmation": build_confirmation}
    roots, source_collections, assets = [], [], {}
    total_modules = 0
    for kind in KINDS:
        coll = collection(f"MSPC_{kind.upper()}_EDITABLE_PARTS")
        root = builders[kind](coll, mats)
        roots.append(root)
        source_collections.append(coll)
        modules = [obj for obj in root.children if obj.type == "MESH"]
        glb, runtime_meshes, groups = runtime_export(kind, root, coll)
        polygon_sizes = Counter(len(face.vertices) for obj in modules for face in obj.data.polygons)
        assert set(polygon_sizes) == {3}
        total_modules += len(modules)
        assets[kind] = {
            "editable_modules": len(modules),
            "runtime_groups": len(runtime_meshes),
            "runtime_group_modules": {name: len(items) for name, items in groups.items()},
            "triangles": sum(len(obj.data.polygons) for obj in runtime_meshes),
            "glb": str(glb.relative_to(ROOT)),
        }
    render_lineup(roots, source_collections)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    manifest = {
        "asset": "mind_spark_puzzle_control_kit",
        "version": 1,
        "design_language": "pearl ivory, champagne gold, celestial aqua, lavender wisdom light",
        "all_faces_triangulated": True,
        "total_editable_modules": total_modules,
        "assets": assets,
        "reuse": {"regulator": 2, "selector": 3, "confirmation": 1},
        "blend": str(BLEND_PATH.relative_to(ROOT)),
        "render": str(RENDER_PATH.relative_to(ROOT)),
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n")
    assert total_modules >= 300
    print("MIND_SPARK_PUZZLE_CONTROL_KIT_BUILD: PASS")
    print(f"editable_modules={total_modules} assets={assets}")
    print(f"render={RENDER_PATH}")


if __name__ == "__main__":
    main()
