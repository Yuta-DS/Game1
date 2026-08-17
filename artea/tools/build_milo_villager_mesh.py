import bpy
import math
from mathutils import Vector


SOURCE = "/Users/davidsovann/S2603/artea/assets3D/characters/Barbarian.glb"
OUTPUT = "/Users/davidsovann/S2603/artea/assets3D/characters/milo_villager_lowpoly.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SOURCE)
armature = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")

# The market villager rig and all its actions remain untouched. Only its warrior
# geometry is replaced with Milo's connected low-poly mayor mesh.
for obj in list(bpy.context.scene.objects):
    if obj.type == "MESH":
        bpy.data.objects.remove(obj, do_unlink=True)


def material(name, hex_color):
    color = tuple(int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4))
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.82
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


CREAM = material("Milo Cream Fur", "d8c4a8")
WHITE = material("Milo White Fur", "f2eee5")
NAVY = material("Milo Navy Mayor Coat", "244c6d")
PURPLE = material("Milo Purple Waistcoat", "76527f")
GOLD = material("Milo Brushed Gold", "c99b43")
TEAL = material("Milo Teal Piping", "3c9aab")
PINK = material("Milo Pink Nose", "d69d91")
DARK = material("Milo Eyes and Trousers", "252c32")
BROWN = material("Milo Brown Shoes", "604639")
MARKING = material("Milo Fur Marking", "a79279")
GREEN = material("Milo Leaf Pin", "70a959")
CYAN = material("Milo Diamond Pin", "63c7d7")
VIOLET = material("Milo Star Pin", "9a6ab1")

parts = []


def finish(obj, name, mat, bone):
    obj.name = name
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    obj.data.materials.append(mat)
    group = obj.vertex_groups.new(name=bone)
    group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    parts.append(obj)
    return obj


def sphere(name, location, scale, mat, bone, segments=12, rings=8, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, radius=1.0,
        location=location, rotation=rotation)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat, bone)


def torus(name, location, major, minor, mat, bone, rotation=(math.pi / 2, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor,
        major_segments=16, minor_segments=6,
        location=location, rotation=rotation)
    return finish(bpy.context.object, name, mat, bone)


def cube(name, location, scale, mat, bone, rotation=(0, 0, 0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.scale = scale
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("Soft low-poly bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, name, mat, bone)


def prism(name, verts, faces, mat, bone):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, bone)


def tube(name, points, radius, mat, bone):
    curve_data = bpy.data.curves.new(name + "Curve", "CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = 1
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = 1
    curve_data.resolution_u = 1
    spline = curve_data.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, co in zip(spline.points, points):
        point.co = (*co, 1.0)
    obj = bpy.data.objects.new(name, curve_data)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return finish(obj, name, mat, bone)


# Rounded compact coat body. It overlaps the shoulders and hips so Milo reads as
# one chibi villager silhouette rather than a head placed on a separate body.
sphere("MayorCoatBody", (0, 0.015, 0.84), (0.39, 0.27, 0.43), NAVY, "chest", 14, 9)
sphere("PurpleWaistcoat", (0, -0.258, 0.88), (0.235, 0.035, 0.29), PURPLE, "chest", 12, 7)
cube("WhiteShirtCollar", (0, -0.292, 1.075), (0.15, 0.022, 0.055), WHITE, "chest", bevel=0.025)

# Lapels and coat edging follow the body curve instead of forming a box frame.
tube("TealLapelL", [(-0.04, -0.296, 1.10), (-0.14, -0.298, 0.99), (-0.20, -0.285, 0.86)], 0.014, TEAL, "chest")
tube("TealLapelR", [(0.04, -0.296, 1.10), (0.14, -0.298, 0.99), (0.20, -0.285, 0.86)], 0.014, TEAL, "chest")
tube("GoldCoatHem", [(-0.27, -0.255, 0.57), (0, -0.285, 0.54), (0.27, -0.255, 0.57)], 0.014, GOLD, "chest")

# Tie and four restrained mayor buttons.
prism("MayorTie", [(-0.045, -0.324, 1.06), (0.045, -0.324, 1.06),
                    (0.055, -0.324, 0.94), (0, -0.324, 0.88), (-0.055, -0.324, 0.94)],
      [(0, 1, 2, 3, 4)], PURPLE, "chest")
for x in (-0.105, 0.105):
    for z in (0.72, 0.87):
        sphere("CoatButton", (x, -0.30, z), (0.028, 0.016, 0.028), GOLD, "chest", 8, 5)

# Head and cheeks are deliberately broad and low, matching the market NPC head
# to body ratio and the approved cream-cat mayor reference.
sphere("CatHead", (0, -0.005, 1.43), (0.39, 0.31, 0.34), CREAM, "head", 14, 9)
sphere("LeftCheek", (-0.25, -0.255, 1.34), (0.15, 0.085, 0.13), WHITE, "head", 10, 6)
sphere("RightCheek", (0.25, -0.255, 1.34), (0.15, 0.085, 0.13), WHITE, "head", 10, 6)

# Tapered ears with pink inset faces.
for side, label in ((-1, "L"), (1, "R")):
    x0 = 0.23 * side
    outer = [(x0 - 0.14, -0.10, 1.62), (x0 + 0.14, -0.10, 1.62),
             (x0 + 0.06 * side, -0.09, 1.98),
             (x0 - 0.12, 0.08, 1.61), (x0 + 0.12, 0.08, 1.61),
             (x0 + 0.05 * side, 0.06, 1.94)]
    faces = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    prism("CatEar" + label, outer, faces, CREAM, "head")
    inner = [(x0 - 0.075, -0.112, 1.66), (x0 + 0.075, -0.112, 1.66),
             (x0 + 0.04 * side, -0.108, 1.88)]
    prism("InnerEar" + label, inner, [(0, 1, 2)], PINK, "head")

# Face: soft white brows, large oval eyes, round gold glasses, nose and moustache.
for side, label in ((-1, "L"), (1, "R")):
    sphere("EyeWhite" + label, (0.135 * side, -0.301, 1.48), (0.105, 0.035, 0.135), WHITE, "head", 12, 7)
    sphere("Pupil" + label, (0.135 * side, -0.338, 1.48), (0.045, 0.02, 0.075), DARK, "head", 12, 7)
    sphere("WhiteBrow" + label, (0.14 * side, -0.303, 1.64), (0.11, 0.035, 0.035), WHITE, "head", 10, 6, (0, 0.1 * side, 0.08 * side))
    torus("GlassesRing" + label, (0.135 * side, -0.345, 1.49), 0.145, 0.018, GOLD, "head")
    sphere("Moustache" + label, (0.095 * side, -0.410, 1.30), (0.15, 0.040, 0.065), WHITE, "head", 12, 7, (0, 0, 0.16 * side))
tube("GlassesBridge", [(-0.015, -0.348, 1.50), (0.015, -0.348, 1.50)], 0.018, GOLD, "head")
sphere("PinkNose", (0, -0.383, 1.37), (0.07, 0.04, 0.055), PINK, "head", 10, 6)

# Small central forehead marking.
prism("ForeheadMark", [(-0.07, -0.307, 1.70), (0.07, -0.307, 1.70), (0, -0.315, 1.58)],
      [(0, 1, 2)], MARKING, "head")

# Smooth fitted sleeves and hands use the same short bone lengths as villagers.
for side, suffix in ((-1, ".r"), (1, ".l")):
    label = "L" if side < 0 else "R"
    sphere("UpperSleeve" + label, (0.34 * side, 0, 1.105), (0.18, 0.16, 0.18), NAVY, "upperarm" + suffix, 10, 6)
    sphere("LowerSleeve" + label, (0.58 * side, 0, 1.105), (0.18, 0.15, 0.17), NAVY, "lowerarm" + suffix, 10, 6)
    torus("GoldCuff" + label, (0.735 * side, 0, 1.105), 0.13, 0.025, GOLD, "wrist" + suffix, rotation=(0, math.pi / 2, 0))
    sphere("Paw" + label, (0.83 * side, 0, 1.105), (0.15, 0.14, 0.16), CREAM, "hand" + suffix, 10, 6)

# Short rounded trousers and broad shoes preserve the cast's compact stance.
for side, suffix in ((-1, ".r"), (1, ".l")):
    label = "L" if side < 0 else "R"
    sphere("Trouser" + label, (0.17 * side, 0, 0.39), (0.16, 0.15, 0.19), DARK, "upperleg" + suffix, 10, 6)
    sphere("LowerTrouser" + label, (0.17 * side, 0, 0.22), (0.135, 0.13, 0.15), DARK, "lowerleg" + suffix, 10, 6)
    sphere("Shoe" + label, (0.17 * side, -0.075, 0.10), (0.18, 0.23, 0.13), BROWN, "foot" + suffix, 10, 6)

# Curled striped tail, fully part of the hips silhouette.
tail_points = [(0.30, 0.13, 0.65), (0.43, 0.16, 0.73), (0.48, 0.14, 0.86),
               (0.44, 0.10, 0.98), (0.35, 0.08, 1.03)]
for i, point in enumerate(tail_points):
    sphere("TailSegment", point, (0.095 - i * 0.007,) * 3,
           CREAM if i % 2 == 0 else MARKING, "hips", 9, 6)

# Three small identity pins from the approved suit.
sphere("LeafPin", (-0.20, -0.302, 1.02), (0.035, 0.015, 0.06), GREEN, "chest", 8, 5, (0, 0, -0.5))
cube("DiamondPin", (-0.15, -0.314, 1.09), (0.035, 0.012, 0.035), CYAN, "chest", (0, math.pi / 4, math.pi / 4), 0.006)
sphere("StarPin", (-0.10, -0.31, 1.01), (0.035, 0.014, 0.035), VIOLET, "chest", 8, 5)

# Join into one material-rich mesh. Vertex groups keep each region attached to
# the matching villager bone, while the overlapping sculpt produces a single
# clean silhouette in idle, walking and greeting poses.
bpy.ops.object.select_all(action="DESELECT")
for obj in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
milo = bpy.context.object
milo.name = "MayorMilo"
modifier = milo.modifiers.new("VillagerRig", "ARMATURE")
modifier.object = armature
milo.parent = armature

bpy.ops.object.select_all(action="DESELECT")
milo.select_set(True)
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.export_scene.gltf(
    filepath=OUTPUT,
    export_format="GLB",
    use_selection=True,
    export_animations=True,
    export_nla_strips=True,
    export_materials="EXPORT",
)
print(f"MILO_VILLAGER_BUILD: {len(milo.data.vertices)} vertices, {len(milo.data.polygons)} faces -> {OUTPUT}")
