"""Build Mayor Alder on the fox-like Rogue villager rig."""

import math
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets3D/characters/Rogue.glb"
OUTPUT = ROOT / "assets3D/characters/elder_cat_mayor.glb"
MOUSTACHE_SOURCE = ROOT / "assets3D/characters/elder_cat_moustache_final.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
armature = bpy.data.objects.get("Rig")

# Re-angle the source Rogue's weapon-holding rest pose into the relaxed mayor
# stance used by the reference.  Bone names and animations remain unchanged;
# only the deform chains' rest placement is corrected for the new fitted coat.
bpy.context.view_layer.objects.active = armature
armature.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for suffix, side in ((".l", 1.0), (".r", -1.0)):
    chain = {
        "upperarm": ((0.22 * side, 0.0, 1.11), (0.32 * side, 0.0, 0.94)),
        "lowerarm": ((0.32 * side, 0.0, 0.94), (0.39 * side, 0.0, 0.78)),
        "wrist": ((0.39 * side, 0.0, 0.78), (0.42 * side, 0.0, 0.71)),
        "hand": ((0.42 * side, 0.0, 0.71), (0.43 * side, 0.0, 0.60)),
        "handslot": ((0.43 * side, 0.0, 0.62), (0.43 * side, -0.10, 0.62)),
    }
    for bone_name, (head, tail) in chain.items():
        bone = armature.data.edit_bones.get(bone_name + suffix)
        if bone is not None:
            bone.use_connect = False
            bone.head = head
            bone.tail = tail
bpy.ops.object.mode_set(mode="OBJECT")

for name in (
    "Rogue_Head", "Rogue_ArmLeft", "Rogue_ArmRight", "Rogue_Body",
    "Rogue_LegLeft", "Rogue_LegRight", "Rogue_Cape",
    "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable",
    "Cube", "Light", "Camera", "Icosphere",
):
    obj = bpy.data.objects.get(name)
    if obj is not None:
        bpy.data.objects.remove(obj, do_unlink=True)


def material(name, color, roughness=0.75, metallic=0.0):
    rgb = tuple(int(color[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    value = bpy.data.materials.new(name)
    value.diffuse_color = (*rgb, 1.0)
    value.use_nodes = True
    shader = value.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return value


FUR = material("Alder Silver Fur", "777e82")
FUR_LIGHT = material("Alder White Fur", "d9d6cd")
EAR = material("Alder Ear Pink", "a86f68")
EYE = material("Alder Amber Eye", "bd7b2c", 0.32)
PUPIL = material("Alder Dark Eye", "17191b", 0.28)
NOSE = material("Alder Nose", "40343a", 0.55)
GOLD = material("Alder Mayor Gold", "c49435", 0.3, 0.42)
NAVY = material("Alder Navy Mayor Coat", "10243a", 0.78)
NAVY_DARK = material("Alder Coat Shadow", "091725", 0.82)
TEAL = material("Alder Teal Piping", "2d8c9b", 0.68)
PURPLE = material("Alder Purple Waistcoat", "51345f", 0.75)
PURPLE_DARK = material("Alder Waistcoat Seam", "302039", 0.78)
SHIRT = material("Alder Mayor Shirt", "e9e2d6", 0.78)
TROUSERS = material("Alder Mayor Trousers", "242a31", 0.82)
BOOT = material("Alder Brown Boots", "362119", 0.58)
SOLE = material("Alder Boot Soles", "17171a", 0.82)
PIN_GREEN = material("Alder Leaf Pin", "6b9b55", 0.68)
PIN_BLUE = material("Alder Diamond Pin", "58b6c7", 0.52)
PIN_VIOLET = material("Alder Star Pin", "8d66a5", 0.62)

new_parts = []


def finish(obj, name, mat, bone):
    obj.name = name
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for face in obj.data.polygons:
        face.use_smooth = True
    obj.data.materials.append(mat)
    group = obj.vertex_groups.new(name=bone)
    group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    new_parts.append(obj)
    return obj


def sphere(name, location, scale, mat, bone, segments=10, rings=7, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, radius=1.0,
        location=location, rotation=rotation,
    )
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat, bone)


def torus(name, location, major, minor, mat, bone, rotation=(math.pi / 2, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor,
        major_segments=12, minor_segments=4,
        location=location, rotation=rotation,
    )
    return finish(bpy.context.object, name, mat, bone)


def prism(name, vertices, faces, mat, bone, bevel=0.0):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if bevel > 0.0:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        modifier = obj.modifiers.new("Soft villager bevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return finish(obj, name, mat, bone)


def panel(name, outline, depth, mat, bone):
    vertices = [(x, depth, z) for x, z in outline]
    return prism(name, vertices, [tuple(range(len(vertices)))], mat, bone)


def tube(name, points, radius, mat, bone):
    curve = bpy.data.curves.new(name + "Curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    curve.bevel_depth = radius
    curve.bevel_resolution = 1
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, value in zip(spline.points, points):
        point.co = (*value, 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return finish(obj, name, mat, bone)


def cube(name, location, scale, mat, bone, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=location)
    obj = bpy.context.object
    obj.scale = scale
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        modifier = obj.modifiers.new("Rounded boot edge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return finish(obj, name, mat, bone)


# A compact anthropomorphic cat head at the same height and polygon language as
# the Rogue/fox family.  Simple oval eyes stay readable at normal town-camera
# distance instead of using Milo's portrait-like layered eyes and glasses.
sphere("AlderHead", (0, -0.01, 1.48), (0.37, 0.30, 0.34), FUR, "head", 12, 8)
sphere("AlderLowerFace", (0, -0.245, 1.36), (0.27, 0.10, 0.16), FUR_LIGHT, "head", 10, 7)
for side, label in ((-1, "L"), (1, "R")):
    x0 = 0.245 * side
    outer = [
        (x0 - 0.13, -0.07, 1.68), (x0 + 0.13, -0.07, 1.68),
        (x0 + 0.045 * side, -0.06, 1.91),
        (x0 - 0.11, 0.08, 1.67), (x0 + 0.11, 0.08, 1.67),
        (x0 + 0.035 * side, 0.06, 1.88),
    ]
    prism("AlderEar" + label, outer,
          [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)],
          FUR, "head", 0.012)
    prism("AlderInnerEar" + label,
          [(x0 - 0.06, -0.082, 1.70), (x0 + 0.06, -0.082, 1.70),
           (x0 + 0.025 * side, -0.080, 1.85)],
          [(0, 1, 2)], EAR, "head", 0.006)
    sphere("AlderEye" + label, (0.115 * side, -0.316, 1.51),
           (0.060, 0.025, 0.085), EYE, "head", 10, 7)
    sphere("AlderPupil" + label, (0.115 * side, -0.343, 1.51),
           (0.031, 0.012, 0.060), PUPIL, "head", 9, 6)
    sphere("AlderBrow" + label, (0.12 * side, -0.305, 1.625),
           (0.095, 0.028, 0.026), FUR_LIGHT, "head", 10, 7,
           (0, 0.10 * side, 0.14 * side))
    sphere("AlderCheek" + label, (0.20 * side, -0.315, 1.35),
           (0.13, 0.045, 0.080), FUR_LIGHT, "head", 10, 7)
sphere("AlderNose", (0, -0.373, 1.39), (0.052, 0.032, 0.042), NOSE, "head", 9, 6)

# Attach the approved standalone moustache without merging its two halves into
# the general character-detail mesh. Both objects deform rigidly with `head`.
existing_objects = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(MOUSTACHE_SOURCE))
imported_moustache = [
    obj for obj in bpy.data.objects
    if obj not in existing_objects and obj.type == "MESH"
]
for obj in imported_moustache:
    side_label = "L" if "_L" in obj.name else "R"
    obj.name = "AlderMoustache" + side_label
    obj.data.name = obj.name + "Mesh"
    obj.parent = None
    # The approved asset is authored around the origin. Fit it across Alder's
    # compact muzzle and bring it just in front of the existing cheek pads.
    for vertex in obj.data.vertices:
        vertex.co.x *= 0.88
        vertex.co.y = vertex.co.y * 0.88 - 0.414
        vertex.co.z = vertex.co.z * 0.88 + 1.350
    group = obj.vertex_groups.new(name="head")
    group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    modifier = obj.modifiers.new("VillagerRig", "ARMATURE")
    modifier.object = armature
    obj.parent = armature

# Outfit construction follows the supplied turnaround as separate bone-weighted
# pieces.  It has no cloth simulation: the long coat is a compact rounded shell
# with fitted lapels, hems and sleeves, so it remains stable in every animation.
sphere("AlderCoatBody", (0, 0.015, 0.83), (0.31, 0.245, 0.41), NAVY, "chest", 14, 9)
panel("AlderWaistcoat",
      [(-0.15, 1.04), (0.15, 1.04), (0.15, 0.69),
       (0.055, 0.61), (-0.055, 0.61), (-0.15, 0.69)],
      -0.258, PURPLE, "chest")
panel("AlderCoatFrontL",
      [(-0.30, 1.06), (-0.15, 1.00), (-0.14, 0.61), (-0.27, 0.55)],
      -0.292, NAVY, "chest")
panel("AlderCoatFrontR",
      [(0.30, 1.06), (0.15, 1.00), (0.14, 0.61), (0.27, 0.55)],
      -0.292, NAVY, "chest")
panel("AlderShirtBib", [(-0.13, 1.11), (0.13, 1.11), (0.09, 0.98), (-0.09, 0.98)],
      -0.270, SHIRT, "chest")
panel("AlderCollarL", [(-0.14, 1.11), (-0.01, 1.07), (-0.075, 0.98)],
      -0.306, SHIRT, "chest")
panel("AlderCollarR", [(0.14, 1.11), (0.01, 1.07), (0.075, 0.98)],
      -0.306, SHIRT, "chest")
panel("AlderTie",
      [(-0.040, 1.06), (0.040, 1.06), (0.052, 0.94), (0, 0.88), (-0.052, 0.94)],
      -0.326, PURPLE, "chest")
sphere("AlderTieKnot", (0, -0.337, 1.055), (0.045, 0.018, 0.040), GOLD, "chest", 9, 6)
tube("AlderWaistcoatSeam", [(0, -0.302, 0.66), (0, -0.302, 0.96)],
     0.007, PURPLE_DARK, "chest")

# Teal lapels and gold edging are geometric strips rather than painted lines,
# preserving their clarity at normal game-camera distance and from side views.
tube("AlderTealLapelL", [(-0.03, -0.310, 1.10), (-0.13, -0.315, 1.00),
                          (-0.20, -0.296, 0.87)], 0.012, TEAL, "chest")
tube("AlderTealLapelR", [(0.03, -0.310, 1.10), (0.13, -0.315, 1.00),
                          (0.20, -0.296, 0.87)], 0.012, TEAL, "chest")
tube("AlderGoldCoatHem", [(-0.26, -0.245, 0.57), (0, -0.274, 0.535),
                           (0.26, -0.245, 0.57)], 0.012, GOLD, "chest")
tube("AlderGoldFrontEdgeL", [(-0.15, -0.306, 0.62), (-0.15, -0.308, 0.98)],
     0.010, GOLD, "chest")
tube("AlderGoldFrontEdgeR", [(0.15, -0.306, 0.62), (0.15, -0.308, 0.98)],
     0.010, GOLD, "chest")
for side, label in ((-1, "L"), (1, "R")):
    tube("AlderPocketTrim" + label,
         [(0.12 * side, -0.282, 0.72), (0.235 * side, -0.267, 0.72)],
         0.010, GOLD, "chest")
    for height in (0.73, 0.88):
        sphere("AlderCoatButton" + label, (0.105 * side, -0.304, height),
               (0.026, 0.014, 0.026), GOLD, "chest", 9, 6)

# Layered sleeves, double cuff stripes and rounded paws follow the source NPC's
# compact arms while reproducing the reference mayor coat.
for side, suffix in ((-1, ".r"), (1, ".l")):
    label = "L" if side < 0 else "R"
    sphere("AlderUpperSleeve" + label, (0.285 * side, 0, 1.02),
           (0.125, 0.118, 0.205), NAVY, "upperarm" + suffix, 12, 8)
    sphere("AlderLowerSleeve" + label, (0.365 * side, 0, 0.84),
           (0.118, 0.112, 0.175), NAVY, "lowerarm" + suffix, 12, 8)
    torus("AlderCuffGoldOuter" + label, (0.410 * side, 0, 0.700),
          0.088, 0.014, GOLD, "wrist" + suffix, rotation=(0, 0, 0))
    torus("AlderCuffGoldInner" + label, (0.405 * side, 0, 0.740),
          0.086, 0.010, GOLD, "wrist" + suffix, rotation=(0, 0, 0))
    sphere("AlderPaw" + label, (0.46 * side, 0, 0.57),
           (0.105, 0.10, 0.125), FUR, "hand" + suffix, 12, 8)

# Dark trousers and broad brown boots finish the same short, grounded silhouette
# as the reference sheet and the playable fox.
for side, suffix in ((-1, ".r"), (1, ".l")):
    label = "L" if side < 0 else "R"
    sphere("AlderTrouser" + label, (0.16 * side, 0, 0.39),
           (0.145, 0.14, 0.18), TROUSERS, "upperleg" + suffix, 11, 7)
    sphere("AlderLowerTrouser" + label, (0.16 * side, 0, 0.22),
           (0.12, 0.12, 0.14), TROUSERS, "lowerleg" + suffix, 11, 7)
    sphere("AlderBoot" + label, (0.16 * side, -0.075, 0.10),
           (0.17, 0.22, 0.125), BOOT, "foot" + suffix, 12, 8)
    cube("AlderSole" + label, (0.16 * side, -0.08, 0.026),
         (0.15, 0.19, 0.018), SOLE, "foot" + suffix, 0.014)

# Three permanent civic pins echo the reference outfit while keeping Alder's
# own silver-cat face and identity.
sphere("AlderLeafPin", (-0.205, -0.306, 1.02), (0.032, 0.014, 0.055),
       PIN_GREEN, "chest", 9, 6, (0, 0, -0.45))
prism("AlderDiamondPin",
      [(-0.18, -0.320, 1.10), (-0.145, -0.320, 1.135),
       (-0.11, -0.320, 1.10), (-0.145, -0.320, 1.065)],
      [(0, 1, 2, 3)], PIN_BLUE, "chest", 0.005)
sphere("AlderStarPin", (-0.10, -0.314, 1.01), (0.032, 0.014, 0.032),
       PIN_VIOLET, "chest", 9, 6)

# Join only Alder's additions. Original Rogue body meshes keep their authored
# weights, animations, materials and compact proportions.
bpy.ops.object.select_all(action="DESELECT")
for obj in new_parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = new_parts[0]
bpy.ops.object.join()
alder_parts = bpy.context.object
alder_parts.name = "MayorAlderDetails"
modifier = alder_parts.modifiers.new("VillagerRig", "ARMATURE")
modifier.object = armature
alder_parts.parent = armature

bpy.ops.object.select_all(action="DESELECT")
armature.select_set(True)
for obj in bpy.context.scene.objects:
    if obj.type == "MESH" and obj.name not in {"Rogue_Head"}:
        obj.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT), export_format="GLB", use_selection=True,
    export_animations=True, export_nla_strips=True, export_materials="EXPORT",
)
print(f"ELDER_CAT_MAYOR_BUILD: wrote {OUTPUT}")
