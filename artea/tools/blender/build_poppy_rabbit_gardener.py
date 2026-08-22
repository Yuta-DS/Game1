"""Build Poppy, a friendly rabbit gardener in the established villager style."""

from pathlib import Path
import math

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets3D/characters/milo_exact_target_parts.glb"
OUTPUT_GLB = ROOT / "assets3D/characters/poppy_rabbit_gardener.glb"
OUTPUT_BLEND = ROOT / "assets3D/characters/poppy_rabbit_gardener.blend"
OUTPUT_RENDER = ROOT / "artifacts/poppy_rabbit_gardener.png"
OUTPUT_VIEWS = {
    "front": ROOT / "artifacts/poppy_360_front.png",
    "right": ROOT / "artifacts/poppy_360_right.png",
    "back": ROOT / "artifacts/poppy_360_back.png",
    "left": ROOT / "artifacts/poppy_360_left.png",
}


def material(name, color, roughness=0.68):
    value = bpy.data.materials.new(name)
    rgb = tuple(int(color[index:index + 2], 16) / 255.0 for index in (0, 2, 4))
    value.diffuse_color = (*rgb, 1.0)
    value.use_nodes = True
    shader = value.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    return value


def apply_material(obj, mat):
    if obj.type == "MESH":
        obj.data.materials.clear()
        obj.data.materials.append(mat)


def finish(obj, name, mat, bone, armature, parts, smooth=False):
    obj.name = name
    if obj.type == "MESH":
        for face in obj.data.polygons:
            face.use_smooth = smooth
        apply_material(obj, mat)
        group = obj.vertex_groups.new(name=bone)
        group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
        modifier = obj.modifiers.new("PoppyVillagerRig", "ARMATURE")
        modifier.object = armature
    obj.parent = armature
    obj["villager_part"] = name
    obj["character"] = "Poppy Rabbit Gardener"
    parts.append(obj)
    return obj


def sphere(name, location, scale, mat, bone, armature, parts, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=12, ring_count=7, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, bone, armature, parts, smooth=True)


def panel(name, outline, y, thickness, mat, bone, armature, parts, bevel=0.008):
    count = len(outline)
    verts = [(x, y, z) for x, z in outline]
    verts += [(x, y + thickness, z) for x, z in outline]
    faces = [tuple(range(count))[::-1], tuple(range(count, count * 2))]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if bevel:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        modifier = obj.modifiers.new("Soft sewn edge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return finish(obj, name, mat, bone, armature, parts)


def tube(name, points, radius, mat, bone, armature, parts):
    curve = bpy.data.curves.new(name + "Curve", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 1
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, coordinate in zip(spline.points, points):
        point.co = (*coordinate, 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return finish(obj, name, mat, bone, armature, parts, smooth=True)


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
armature = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
armature.name = "PoppyRabbitGardenerRig"

# Remove Milo-specific anatomy and ceremonial tailoring while retaining the
# proven villager body, eyes, paws, legs and animation-ready topology.
remove_prefixes = (
    "EarOuter_", "EarInner_", "ForeheadMark", "Glasses", "Brow_",
    "Moustache", "CoatLapel_", "GoldLapel", "GoldWaistcoat", "Waistcoat",
    "LapelPiping", "Collar_", "Tie", "Medallion", "Button_", "GoldTieClip",
    "Mayoral", "PocketFlap_", "GoldPocket", "BackYoke", "GoldBackYoke",
    "Tail", "CoatDart_", "BackVent", "BackCenterSeam",
)
for obj in list(bpy.context.scene.objects):
    if obj.type == "MESH" and obj.name.startswith(remove_prefixes):
        bpy.data.objects.remove(obj, do_unlink=True)

parts = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]

# Milo's moustache previously bridged these face layers. Seat them directly on
# Poppy's cream rabbit muzzle so the nose and mouth do not float in side view.
for face_name, depth_shift in (("Nose", 0.060), ("Mouth", 0.055)):
    face_part = bpy.data.objects.get(face_name)
    if face_part is not None:
        face_part.location.y += depth_shift

FUR = material("Poppy warm rabbit fur", "b8916f")
FUR_LIGHT = material("Poppy cream muzzle", "e7d8bd")
INNER_EAR = material("Poppy inner ear", "d9a69f")
GREEN = material("Poppy moss gardening coat", "4f6f52")
GREEN_DARK = material("Poppy coat seams", "304a38")
APRON = material("Poppy linen apron", "c7ad78")
APRON_LIGHT = material("Poppy apron pocket", "d7c391")
KERCHIEF = material("Poppy berry kerchief", "a84e46")
BOOT = material("Poppy garden boots", "514337")
SOIL = material("Poppy trouser brown", "403a34")
BLACK = material("Poppy eye", "17191a", 0.35)
WHITE = material("Poppy eye highlight", "f4eee4")

for obj in parts:
    if obj.name == "Head" or obj.name.startswith(("CheekUpper_", "CheekLower_")):
        apply_material(obj, FUR)
    elif obj.name.startswith("Muzzle_"):
        apply_material(obj, FUR_LIGHT)
    elif obj.name == "CoatBody" or obj.name.startswith("Sleeve_"):
        apply_material(obj, GREEN)
    elif obj.name.startswith("Paw_"):
        apply_material(obj, FUR)
    elif obj.name.startswith("Trouser_"):
        apply_material(obj, SOIL)
    elif obj.name.startswith(("Boot_", "Sole_")):
        apply_material(obj, BOOT)
    elif obj.name.startswith("Pupil_"):
        apply_material(obj, BLACK)
    elif obj.name.startswith("EyeHighlight_"):
        apply_material(obj, WHITE)
    elif obj.name.startswith("CoatHem_") or obj.name.startswith("GoldSideHem_") \
            or obj.name.startswith("BackCoatHem_"):
        apply_material(obj, GREEN_DARK)

# Tall rabbit ears overlap the head so they read as connected from all sides.
for side, label in ((-1, "L"), (1, "R")):
    panel("RabbitEarOuter_" + label,
          [(0.31 * side, 1.66), (0.34 * side, 2.12),
           (0.28 * side, 2.28), (0.19 * side, 2.30),
           (0.12 * side, 2.15), (0.13 * side, 1.68)],
          -0.075, 0.17, FUR, "head", armature, parts, bevel=0.018)
    panel("RabbitEarInner_" + label,
          [(0.285 * side, 1.75), (0.300 * side, 2.08),
           (0.255 * side, 2.21), (0.205 * side, 2.22),
           (0.160 * side, 2.10), (0.165 * side, 1.77)],
          -0.095, 0.012, INNER_EAR, "head", armature, parts, bevel=0.012)
    tube("ApronStrap_" + label,
         [(0.245 * side, -0.287, 1.085), (0.180 * side, -0.300, 0.930)],
         0.014, APRON, "chest", armature, parts)

# Gardener outfit details are shallow and sewn directly to the coat-body.
panel("GardenerApron",
      [(-0.205, 0.960), (0.205, 0.960), (0.235, 0.365),
       (0.0, 0.315), (-0.235, 0.365)],
      -0.295, 0.018, APRON, "chest", armature, parts, bevel=0.012)
panel("ApronPocket",
      [(-0.155, 0.670), (0.155, 0.670), (0.135, 0.500),
       (0.0, 0.465), (-0.135, 0.500)],
      -0.318, 0.012, APRON_LIGHT, "chest", armature, parts, bevel=0.009)
panel("Kerchief",
      [(-0.145, 1.105), (0.145, 1.105), (0.0, 0.915)],
      -0.305, 0.020, KERCHIEF, "chest", armature, parts, bevel=0.009)
tube("ApronPocketSeam",
     [(-0.130, -0.335, 0.655), (0.0, -0.338, 0.620),
      (0.130, -0.335, 0.655)],
     0.006, GREEN_DARK, "chest", armature, parts)
sphere("ApronButton_L", (-0.18, -0.330, 0.945), (0.028, 0.014, 0.028),
       GREEN_DARK, "chest", armature, parts)
sphere("ApronButton_R", (0.18, -0.330, 0.945), (0.028, 0.014, 0.028),
       GREEN_DARK, "chest", armature, parts)
sphere("RabbitTail", (0.0, 0.335, 0.610), (0.105, 0.090, 0.105),
       FUR_LIGHT, "hips", armature, parts)

for part in parts:
    part["villager_style"] = "artea_soft_chibi_lowpoly"
armature.data.pose_position = "REST"

# Four-cardinal proof renders.
bpy.ops.object.camera_add(location=(0, -5.15, 1.15))
camera = bpy.context.object
camera.data.lens = 72
bpy.context.scene.camera = camera
for location, energy in (((-3, -4, 5), 300), ((3, -2, 3), 100),
                         ((3, 4, 4), 250), ((-3, 2, 3), 90)):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.data.energy = energy
    light.data.size = 3.0
    look_at(light, (0, 0, 1.15))
world = bpy.data.worlds.new("PoppyWorld")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.16, 0.34, 0.38, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.42
bpy.context.scene.world = world
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 720
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.view_settings.look = "AgX - Medium High Contrast"
views = {"front": (0, -5.15, 1.15), "right": (5.15, 0, 1.15),
         "back": (0, 5.15, 1.15), "left": (-5.15, 0, 1.15)}
for name, location in views.items():
    camera.location = location
    look_at(camera, (0, 0, 1.15))
    scene.render.filepath = str(OUTPUT_VIEWS[name])
    bpy.ops.render.render(write_still=True)
scene.render.filepath = str(OUTPUT_RENDER)
camera.location = views["front"]
look_at(camera, (0, 0, 1.15))
bpy.ops.render.render(write_still=True)

OUTPUT_BLEND.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
bpy.ops.object.select_all(action="DESELECT")
armature.select_set(True)
for part in parts:
    part.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_GLB), export_format="GLB", use_selection=True,
    export_animations=True, export_nla_strips=True, export_materials="EXPORT")
print(f"POPPY_BUILD: {len(parts)} parts -> {OUTPUT_GLB}")
