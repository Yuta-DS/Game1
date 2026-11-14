"""Build the pictured Mayor Milo as a separate, rig-compatible game asset.

This intentionally starts from the proven ``milo_exact_target_parts.blend``
rig workspace, then authors a distinct visual variant without overwriting the
fallback model.  The exported GLB retains the public MiloExactTargetRig bone
contract used by Godot's movement, cane IK, gaze and speech controllers.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
SOURCE_BLEND = ROOT / "assets3D/characters/milo_exact_target_parts.blend"
REFERENCE_IMAGE = ROOT / "artifacts/milo_2_reference_source.png"
OUTPUT_BLEND = ROOT / "assets3D/characters/milo_2_pictured.blend"
OUTPUT_GLB = ROOT / "assets3D/characters/milo_2_pictured.glb"
OUTPUT_RENDER = ROOT / "artifacts/milo_2_pictured_render.png"


def rgb(hex_color: str) -> tuple[float, float, float, float]:
    value = hex_color.lstrip("#")
    return tuple(int(value[index:index + 2], 16) / 255.0
                 for index in (0, 2, 4)) + (1.0,)


def tune_material(name: str, hex_color: str, roughness: float,
                  metallic: float = 0.0) -> bpy.types.Material:
    material = bpy.data.materials.get(name)
    if material is None:
        material = bpy.data.materials.new(name)
    color = rgb(hex_color)
    material.diffuse_color = color
    material.roughness = roughness
    material.metallic = metallic
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    if shader is not None:
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Roughness"].default_value = roughness
        shader.inputs["Metallic"].default_value = metallic
        ior_level = shader.inputs.get("IOR Level")
        if ior_level is not None:
            ior_level.default_value = 0.32 if metallic < 0.1 else 0.48
    return material


def assign_material(object_name: str, material: bpy.types.Material) -> None:
    obj = bpy.data.objects.get(object_name)
    if obj is None or obj.type != "MESH":
        raise RuntimeError(f"Missing Milo mesh: {object_name}")
    obj.data.materials.clear()
    obj.data.materials.append(material)


def scale_mesh_about_bounds(object_name: str, scale_xyz: tuple[float, float, float]) -> None:
    obj = bpy.data.objects.get(object_name)
    if obj is None or obj.type != "MESH":
        raise RuntimeError(f"Missing Milo mesh: {object_name}")
    center = sum((vertex.co for vertex in obj.data.vertices), obj.data.vertices[0].co * 0.0)
    center /= len(obj.data.vertices)
    sx, sy, sz = scale_xyz
    for vertex in obj.data.vertices:
        offset = vertex.co - center
        vertex.co = center + type(offset)((offset.x * sx, offset.y * sy, offset.z * sz))
    obj.data.update()


def shorten_mesh_from_top(object_name: str, z_scale: float) -> None:
    """Shorten tailored panels while keeping their shoulder/collar seam fixed."""
    obj = bpy.data.objects.get(object_name)
    if obj is None or obj.type != "MESH":
        return
    top = max(vertex.co.z for vertex in obj.data.vertices)
    for vertex in obj.data.vertices:
        vertex.co.z = top + (vertex.co.z - top) * z_scale
    obj.data.update()


def shorten_mesh_from_bottom(object_name: str, z_scale: float) -> None:
    obj = bpy.data.objects.get(object_name)
    if obj is None or obj.type != "MESH":
        return
    bottom = min(vertex.co.z for vertex in obj.data.vertices)
    for vertex in obj.data.vertices:
        vertex.co.z = bottom + (vertex.co.z - bottom) * z_scale
    obj.data.update()


def soften_mesh(object_name: str, subdivision_levels: int = 1) -> None:
    """Add restrained topology only where the prototype needs a soft read."""
    obj = bpy.data.objects.get(object_name)
    if obj is None or obj.type != "MESH":
        raise RuntimeError(f"Missing Milo mesh: {object_name}")
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    # The paws carry speech/gesture curl shape keys. Blender cannot destructively
    # apply subdivision to keyed topology, so retain their authored topology and
    # use smooth normals there.
    if subdivision_levels > 0 and obj.data.shape_keys is None:
        bpy.context.view_layer.objects.active = obj
        obj.hide_set(False)
        obj.select_set(True)
        modifier = obj.modifiers.new("PrototypeSurfacePolish", "SUBSURF")
        modifier.subdivision_type = "CATMULL_CLARK"
        modifier.levels = subdivision_levels
        modifier.render_levels = subdivision_levels
        bpy.context.object.modifiers.move(len(obj.modifiers) - 1, 0)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)


def bind_to_rig(obj: bpy.types.Object, armature: bpy.types.Object,
                bone_name: str) -> None:
    group = obj.vertex_groups.new(name=bone_name)
    group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    modifier = obj.modifiers.new("MiloPrototypeRig", "ARMATURE")
    modifier.object = armature
    obj.parent = armature
    obj["milo_part"] = obj.name
    obj["milo_variant"] = "pictured_prototype_reference"
    obj["prototype_reference"] = str(REFERENCE_IMAGE)


def add_belt(armature: bpy.types.Object, leather: bpy.types.Material,
             gold: bpy.types.Material) -> list[bpy.types.Object]:
    created: list[bpy.types.Object] = []
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.360,
        minor_radius=0.018,
        major_segments=24,
        minor_segments=8,
        location=(0.0, 0.0, 0.715),
    )
    belt = bpy.context.object
    belt.name = "PrototypeCoatBelt"
    belt.scale.y = 0.72
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    belt.data.materials.append(leather)
    bind_to_rig(belt, armature, "chest")
    created.append(belt)

    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.046,
        minor_radius=0.008,
        major_segments=16,
        minor_segments=6,
        location=(0.0, -0.278, 0.715),
        rotation=(math.pi / 2.0, 0.0, 0.0),
    )
    buckle = bpy.context.object
    buckle.name = "PrototypeBeltBuckle"
    buckle.scale = (1.18, 1.0, 0.72)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    buckle.data.materials.append(gold)
    bind_to_rig(buckle, armature, "chest")
    created.append(buckle)
    return created


def add_clean_eye_whites(armature: bpy.types.Object,
                         material: bpy.types.Material) -> list[bpy.types.Object]:
    """Replace the old triangle-fan eye caps with clean game-ready ellipsoids."""
    created: list[bpy.types.Object] = []
    for side, label in ((-1.0, "L"), (1.0, "R")):
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=24,
            ring_count=12,
            location=(0.160 * side, -0.340, 1.500),
        )
        eye = bpy.context.object
        eye.name = "PrototypeEyeWhite_" + label
        eye.scale = (0.112, 0.043, 0.132)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        for polygon in eye.data.polygons:
            polygon.use_smooth = True
        eye.data.materials.append(material)
        bind_to_rig(eye, armature, "head")
        created.append(eye)
    return created


def add_muzzle_bridge(armature: bpy.types.Object,
                      material: bpy.types.Material) -> bpy.types.Object:
    """Close the dark central gap so the two white moustache lobes read as one."""
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=24,
        ring_count=12,
        location=(0.0, -0.426, 1.365),
    )
    bridge = bpy.context.object
    bridge.name = "PrototypeMuzzleBridge"
    bridge.scale = (0.155, 0.038, 0.070)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for polygon in bridge.data.polygons:
        polygon.use_smooth = True
    bridge.data.materials.append(material)
    bind_to_rig(bridge, armature, "head")
    return bridge


def add_swept_moustache(armature: bpy.types.Object,
                        material: bpy.types.Material) -> list[bpy.types.Object]:
    """Create the prototype's bold, smooth two-sided swept moustache."""
    created: list[bpy.types.Object] = []
    for side, label in ((-1.0, "L"), (1.0, "R")):
        curve_data = bpy.data.curves.new("PrototypeMoustache_" + label, "CURVE")
        curve_data.dimensions = "3D"
        curve_data.resolution_u = 8
        curve_data.bevel_depth = 0.041
        curve_data.bevel_resolution = 4
        curve_data.resolution_u = 12
        spline = curve_data.splines.new("BEZIER")
        spline.bezier_points.add(3)
        points = (
            (0.018 * side, -0.444, 1.398, 0.72),
            (0.092 * side, -0.448, 1.365, 1.08),
            (0.205 * side, -0.438, 1.372, 0.92),
            (0.302 * side, -0.416, 1.425, 0.22),
        )
        for point, (x, y, z, radius) in zip(spline.bezier_points, points):
            point.co = (x, y, z)
            point.radius = radius
            point.handle_left_type = "AUTO"
            point.handle_right_type = "AUTO"
        obj = bpy.data.objects.new("PrototypeMoustache_" + label, curve_data)
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.append(material)
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.convert(target="MESH")
        obj = bpy.context.object
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
        bind_to_rig(obj, armature, "head")
        created.append(obj)
        obj.select_set(False)
    return created


def add_soft_brows(armature: bpy.types.Object,
                   material: bpy.types.Material) -> list[bpy.types.Object]:
    """Build the reference's small arched ivory brows, not blocky plates."""
    created: list[bpy.types.Object] = []
    for side, label in ((-1.0, "L"), (1.0, "R")):
        curve_data = bpy.data.curves.new("PrototypeBrow_" + label, "CURVE")
        curve_data.dimensions = "3D"
        curve_data.resolution_u = 10
        curve_data.bevel_depth = 0.014
        curve_data.bevel_resolution = 4
        spline = curve_data.splines.new("BEZIER")
        spline.bezier_points.add(2)
        points = (
            (0.082 * side, -0.405, 1.668, 0.62),
            (0.154 * side, -0.414, 1.687, 1.00),
            (0.222 * side, -0.402, 1.670, 0.52),
        )
        for point, (x, y, z, radius) in zip(spline.bezier_points, points):
            point.co = (x, y, z)
            point.radius = radius
            point.handle_left_type = "AUTO"
            point.handle_right_type = "AUTO"
        obj = bpy.data.objects.new("PrototypeBrow_" + label, curve_data)
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.append(material)
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.convert(target="MESH")
        obj = bpy.context.object
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
        bind_to_rig(obj, armature, "head")
        created.append(obj)
        obj.select_set(False)
    return created


def add_reference_tail(armature: bpy.types.Object,
                       material: bpy.types.Material) -> bpy.types.Object:
    """Add Milo 2's short, soft side-visible cat tail from the reference."""
    curve_data = bpy.data.curves.new("PrototypeTail", "CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = 10
    curve_data.bevel_depth = 0.064
    curve_data.bevel_resolution = 4
    spline = curve_data.splines.new("BEZIER")
    spline.bezier_points.add(3)
    points = (
        (0.255, 0.155, 0.505, 1.00),
        (0.425, 0.135, 0.405, 1.08),
        (0.565, 0.090, 0.360, 0.88),
        (0.635, 0.045, 0.445, 0.30),
    )
    for point, (x, y, z, radius) in zip(spline.bezier_points, points):
        point.co = (x, y, z)
        point.radius = radius
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    tail = bpy.data.objects.new("PrototypeTail", curve_data)
    bpy.context.scene.collection.objects.link(tail)
    tail.data.materials.append(material)
    bpy.context.view_layer.objects.active = tail
    tail.select_set(True)
    bpy.ops.object.convert(target="MESH")
    tail = bpy.context.object
    for polygon in tail.data.polygons:
        polygon.use_smooth = True
    bind_to_rig(tail, armature, "hips")
    tail.select_set(False)
    return tail


if not SOURCE_BLEND.exists():
    raise RuntimeError(f"Build the fallback Milo first: {SOURCE_BLEND}")

bpy.ops.wm.open_mainfile(filepath=str(SOURCE_BLEND))
armature = bpy.data.objects.get("MiloExactTargetRig")
if armature is None or armature.type != "ARMATURE":
    raise RuntimeError("The Milo 41-bone production rig is missing")

# Prototype palette: quiet warm fur, one burgundy focal mass, dark teal coat,
# and restrained polished gold.  These values deliberately avoid the previous
# bright-blue/purple toy finish while retaining readable value separation.
fur = tune_material("Prototype Warm Ivory Fur", "e4d7bd", 0.68)
fur_light = tune_material("Prototype Moustache Ivory", "f3eee2", 0.58)
inner_ear = tune_material("Prototype Inner Ear", "c89588", 0.62)
nose = tune_material("Prototype Rose Nose", "b87f73", 0.52)
eye_white = tune_material("Prototype Warm Eye White", "ded8c9", 0.48)
eye_black = tune_material("Prototype Soft Black Eye", "171b1c", 0.24)
coat = tune_material("Prototype Dark Teal Coat", "172d39", 0.76)
coat_panel = tune_material("Prototype Teal Tailoring", "203b47", 0.72)
coat_dark = tune_material("Prototype Deep Coat Seam", "10212a", 0.82)
burgundy = tune_material("Prototype Burgundy Waistcoat", "54243c", 0.68)
burgundy_light = tune_material("Prototype Burgundy Facet", "68314b", 0.64)
burgundy_dark = tune_material("Prototype Burgundy Seam", "432234", 0.74)
gold = tune_material("Prototype Luxury Gold", "c59a3b", 0.24, 0.62)
leather = tune_material("Prototype Belt Leather", "5a382b", 0.68)
trouser = tune_material("Prototype Charcoal Trousers", "17191d", 0.82)
shoe = tune_material("Prototype Brown Shoes", "55473f", 0.72)

for name in ("Head", "CheekUpper_L", "CheekUpper_R", "RearHairLower",
             "RearHairMiddle", "RearHairUpper", "EarOuter_L", "EarOuter_R",
             "EarInnerFold_L", "EarInnerFold_R"):
    assign_material(name, fur)
for name in ("CheekLower_L", "CheekLower_R", "Muzzle_L", "Muzzle_R",
             "MoustachePad_L", "MoustachePad_R", "MouthSocket",
             "BrowFrame_L", "BrowFrame_R"):
    assign_material(name, fur_light)
for name in ("EarInner_L", "EarInner_R"):
    assign_material(name, inner_ear)
for name in ("Nose", "Mouth"):
    assign_material(name, nose)
for name in ("EyeWhite_L", "EyeWhite_R"):
    assign_material(name, eye_white)
for name in ("Pupil_L", "Pupil_R", "Nostril_L", "Nostril_R"):
    assign_material(name, eye_black)

# Remove the purple concentric-eye look.  The pictured design uses one soft,
# vertical black oval per eye inside a warm off-white sclera.
excluded_from_export = {"IrisInner_L", "IrisInner_R", "EyeCatchlight_L",
                        "EyeCatchlight_R", "FaceMask_L", "FaceMask_R",
                        "EyeWhite_L", "EyeWhite_R", "EyelidRelaxed_L",
                        "EyelidRelaxed_R", "MoustachePad_L", "MoustachePad_R",
                        "BrowFrame_L", "BrowFrame_R", "ForeheadMark", "MouthSocket"}
for name in excluded_from_export:
    obj = bpy.data.objects.get(name)
    if obj is not None:
        obj.hide_render = True
        obj.hide_set(True)
for name in ("Pupil_L", "Pupil_R"):
    scale_mesh_about_bounds(name, (0.78, 0.82, 1.28))
for name in ("GlassesRing_L", "GlassesRing_R"):
    scale_mesh_about_bounds(name, (0.90, 0.90, 0.90))
for name in ("EarOuter_L", "EarOuter_R", "EarInner_L", "EarInner_R"):
    shorten_mesh_from_bottom(name, 0.86)
scale_mesh_about_bounds("Nose", (0.78, 0.78, 0.78))
scale_mesh_about_bounds("Mouth", (0.52, 0.72, 0.52))
for name in ("EyelidRelaxed_L", "EyelidRelaxed_R"):
    assign_material(name, fur)

# A slightly fuller lower face and broader moustache produce the calm, elderly
# chubby silhouette in the reference without introducing a visible neck gap.
for name in ("MoustachePad_L", "MoustachePad_R"):
    scale_mesh_about_bounds(name, (1.12, 1.06, 1.10))
for name in ("Muzzle_L", "Muzzle_R"):
    scale_mesh_about_bounds(name, (1.06, 1.04, 1.05))

# Concentrate added topology on the identity parts rather than globally
# inflating the asset.  One Catmull-Clark level removes the prototype's visible
# polygon stepping while retaining its authored chibi planes and web budget.
soften_mesh("Head", 2)
for name in ("GlassesRing_L", "GlassesRing_R"):
    soften_mesh(name, 1)
for name in ("MoustachePad_L", "MoustachePad_R", "Muzzle_L", "Muzzle_R",
             "Paw_L", "Paw_R"):
    soften_mesh(name, 0)

assign_material("ForeheadMark", tune_material(
    "Prototype Subtle Forehead Mark", "b8a98e", 0.72))

for name in ("CoatBody", "Sleeve_L", "Sleeve_R"):
    assign_material(name, coat)
for name in ("FrontCoatPanel_L", "FrontCoatPanel_R", "RearCoatTail_L",
             "RearCoatTail_R", "SideCoatTail_L", "SideCoatTail_R",
             "CoatLapel_L", "CoatLapel_R", "BackWaistBelt"):
    assign_material(name, coat_panel)
for name in ("CoatDart_L", "CoatDart_R", "CoatSideSeam_L",
             "CoatSideSeam_R", "FrontTailCenterSeam", "BackVentEdge_L",
             "BackVentEdge_R", "PocketFlap_L", "PocketFlap_R"):
    assign_material(name, coat_dark)
for name in ("Waistcoat", "Tie"):
    assign_material(name, burgundy)
scale_mesh_about_bounds("Waistcoat", (0.78, 1.0, 1.0))
for name in ("WaistcoatFacet_L", "WaistcoatFacet_R"):
    assign_material(name, burgundy_light)
    scale_mesh_about_bounds(name, (0.78, 1.0, 1.0))
assign_material("WaistcoatSeam", burgundy_dark)
for name in ("Collar_L", "Collar_R", "LapelPiping_L", "LapelPiping_R",
             "TealCoatLapelPiping_L", "TealCoatLapelPiping_R"):
    assign_material(name, coat_panel)

gold_names = [obj.name for obj in bpy.data.objects
              if obj.type == "MESH" and "Gold" in obj.name]
gold_names += ["Button_1_L", "Button_1_R", "Button_2_L", "Button_2_R",
               "BackBeltButton_L", "BackBeltButton_R", "Medallion",
               "GlassesBridge", "GlassesRing_L", "GlassesRing_R",
               "GlassesTemple_L", "GlassesTemple_R", "Cuff_L", "Cuff_R",
               "CuffAccent_L", "CuffAccent_R", "MayorCaneHook",
               "MayorCaneLowerCollar", "MayorCaneLowerFerrule",
               "MayorCaneUpperCollar", "MayorCaneGroundTip"]
for name in sorted(set(gold_names)):
    if bpy.data.objects.get(name) is not None:
        assign_material(name, gold)
for name in ("Paw_L", "Paw_R"):
    assign_material(name, fur)
    scale_mesh_about_bounds(name, (0.86, 0.88, 0.86))
for name in ("Sleeve_L", "Sleeve_R"):
    scale_mesh_about_bounds(name, (0.84, 0.90, 0.94))
for name in ("Trouser_L", "Trouser_R"):
    assign_material(name, trouser)
for name in ("Boot_L", "Boot_R", "Sole_L", "Sole_R"):
    assign_material(name, shoe)

for name in ("Button_1_L", "Button_1_R", "Button_2_L", "Button_2_R"):
    scale_mesh_about_bounds(name, (0.72, 0.72, 0.72))
scale_mesh_about_bounds("Medallion", (0.38, 0.38, 0.38))

# The reference has a compact chibi torso: the coat occupies roughly one third
# of the figure rather than almost half. Keep every shoulder/collar seam fixed
# and raise the hem so the trousers and boots read clearly below it.
compact_tailoring = [
    "CoatBody", "FrontCoatPanel_L", "FrontCoatPanel_R",
    "RearCoatTail_L", "RearCoatTail_R", "SideCoatTail_L", "SideCoatTail_R",
    "CoatLapel_L", "CoatLapel_R", "CoatDart_L", "CoatDart_R",
    "CoatSideSeam_L", "CoatSideSeam_R", "FrontTailCenterSeam",
    "BackVentEdge_L", "BackVentEdge_R", "PocketFlap_L", "PocketFlap_R",
    "GoldPocketTrim_L", "GoldPocketTrim_R", "GoldCoatHem360",
    "GoldCoatFrontEdge_L", "GoldCoatFrontEdge_R", "GoldLapelEdge_L",
    "GoldLapelEdge_R", "GoldSideCoatTailEdge_L", "GoldSideCoatTailEdge_R",
    "TealCoatLapelPiping_L", "TealCoatLapelPiping_R",
    "LapelPiping_L", "LapelPiping_R", "Waistcoat", "WaistcoatFacet_L",
    "WaistcoatFacet_R", "WaistcoatSeam", "GoldWaistcoatEdge_L",
    "GoldWaistcoatEdge_R",
]
for name in compact_tailoring:
    shorten_mesh_from_top(name, 0.80)

created = add_belt(armature, leather, gold)
created += add_clean_eye_whites(armature, eye_white)
created += add_swept_moustache(armature, fur_light)
created += add_soft_brows(armature, fur_light)
created.append(add_muzzle_bridge(armature, fur_light))
created.append(add_reference_tail(armature, fur))

# This ring is authored in a different local basis from the coat panels, so
# align it explicitly to the newly raised compact hem.
hem = bpy.data.objects.get("GoldCoatHem360")
if hem is not None:
    hem.location.z += 0.22

for obj in bpy.data.objects:
    if obj.type == "MESH" and obj.name != "RENDER_ONLY_StudioFloor":
        obj["milo_variant"] = "pictured_prototype_reference"
        obj["prototype_reference"] = str(REFERENCE_IMAGE)
armature["milo_variant"] = "pictured_prototype_reference"
armature["prototype_reference"] = str(REFERENCE_IMAGE)
armature["preserves_existing_rig_contract"] = True

# Dark neutral studio treatment matching the supplied prototype card.
world = bpy.context.scene.world
if world is not None and world.use_nodes:
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (
        0.006, 0.010, 0.013, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.18
floor = bpy.data.objects.get("RENDER_ONLY_StudioFloor")
if floor is not None:
    floor_mat = tune_material("Prototype Render Floor", "20272d", 0.90)
    floor.data.materials.clear()
    floor.data.materials.append(floor_mat)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 800
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUTPUT_RENDER)
scene.view_settings.look = "AgX - Medium High Contrast"
armature.data.pose_position = "REST"
scene.frame_set(0)
bpy.context.view_layer.update()
bpy.ops.render.render(write_still=True)

OUTPUT_BLEND.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))

bpy.ops.object.select_all(action="DESELECT")
armature.data.pose_position = "POSE"
armature.hide_set(False)
armature.select_set(True)
exported_meshes = []
for obj in bpy.data.objects:
    if obj.type != "MESH" or obj.name == "RENDER_ONLY_StudioFloor":
        continue
    if obj.name in excluded_from_export:
        continue
    if obj.parent == armature or obj in created:
        obj.hide_set(False)
        obj.select_set(True)
        exported_meshes.append(obj)
bpy.context.view_layer.objects.active = armature
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_GLB),
    export_format="GLB",
    use_selection=True,
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_nla_strips=False,
    export_force_sampling=True,
    export_materials="EXPORT",
)

if len(armature.data.bones) != 41:
    raise RuntimeError(f"Milo rig contract changed: {len(armature.data.bones)} bones")
if bpy.data.actions.get("Milo_Walking") is None:
    raise RuntimeError("Milo_Walking was not preserved")
if len(exported_meshes) < 90:
    raise RuntimeError(f"Prototype export lost parts: {len(exported_meshes)}")

print(f"MILO_PROTOTYPE_BUILD: {len(exported_meshes)} meshes, "
      f"{len(armature.data.bones)} bones -> {OUTPUT_GLB}")
print(f"MILO_PROTOTYPE_BLEND: {OUTPUT_BLEND}")
print(f"MILO_PROTOTYPE_RENDER: {OUTPUT_RENDER}")
