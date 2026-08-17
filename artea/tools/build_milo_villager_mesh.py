import bpy
import math
from mathutils import Vector


SOURCE = "/Users/davidsovann/S2603/artea/assets3D/characters/Barbarian.glb"
OUTPUT = "/Users/davidsovann/S2603/artea/assets3D/characters/milo_villager_lowpoly.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SOURCE)
armature = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")

# The market rig's source warrior holds both arms horizontally. Milo's target
# references use the same compact animation language but a relaxed mayor pose.
# Re-angle only the deforming arm chains in rest space; all 41 bones and baked
# actions remain, while idle/walk/greeting now begin from hanging sleeves.
bpy.context.view_layer.objects.active = armature
armature.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for suffix, side in ((".l", 1.0), (".r", -1.0)):
    chain = {
        "upperarm": ((0.20 * side, 0.0, 1.11), (0.28 * side, 0.0, 0.94)),
        "lowerarm": ((0.28 * side, 0.0, 0.94), (0.31 * side, 0.0, 0.78)),
        "wrist": ((0.31 * side, 0.0, 0.78), (0.32 * side, 0.0, 0.71)),
        "hand": ((0.32 * side, 0.0, 0.71), (0.32 * side, 0.0, 0.60)),
        "handslot": ((0.32 * side, 0.0, 0.62), (0.32 * side, -0.10, 0.62)),
    }
    for bone_name, (head, tail) in chain.items():
        bone = armature.data.edit_bones.get(bone_name + suffix)
        bone.use_connect = False
        bone.head = head
        bone.tail = tail
bpy.ops.object.mode_set(mode="OBJECT")

# The market villager rig and all its actions remain untouched. Only its warrior
# geometry is replaced with Milo's connected low-poly mayor mesh.
for obj in list(bpy.context.scene.objects):
    if obj.type == "MESH":
        bpy.data.objects.remove(obj, do_unlink=True)


def material(name, hex_color, roughness=0.78, metallic=0.0):
    color = tuple(int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4))
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


CREAM = material("Milo Cream Fur", "b99d78", 0.72)
WHITE = material("Milo White Fur", "eee9df", 0.74)
MOUSTACHE = material("Milo Moustache", "fffaf0", 0.68)
NAVY = material("Milo Navy Mayor Coat", "071a2d", 0.76)
PURPLE = material("Milo Purple Waistcoat", "4d3159", 0.74)
PURPLE_DARK = material("Milo Waistcoat Seam", "2d1b36", 0.76)
GOLD = material("Milo Brushed Gold", "b8862f", 0.30, 0.42)
TEAL = material("Milo Teal Piping", "3c9aab")
PINK = material("Milo Pink Nose", "d69d91")
DARK = material("Milo Trousers", "252c32", 0.78)
IRIS = material("Milo Warm Brown Iris", "3a2417", 0.24)
PUPIL = material("Milo Black Pupil", "090807", 0.18)
HIGHLIGHT = material("Milo Eye Highlight", "ffffff", 0.12)
BROWN = material("Milo Brown Shoes", "28150f", 0.48)
SOLE = material("Milo Shoe Soles", "171719", 0.72)
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


def panel(name, outline, y_front, thickness, mat, bone):
    # outline is a list of (x, z) points in clockwise order.
    count = len(outline)
    verts = [(x, y_front, z) for x, z in outline]
    verts += [(x, y_front + thickness, z) for x, z in outline]
    faces = [tuple(range(count)), tuple(range(count, count * 2))[::-1]]
    for i in range(count):
        j = (i + 1) % count
        faces.append((i, j, count + j, count + i))
    return prism(name, verts, faces, mat, bone)


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


def curved_tube(name, points, radius, mat, bone):
    curve_data = bpy.data.curves.new(name + "Curve", "CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = 3
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = 2
    spline = curve_data.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, co in zip(spline.bezier_points, points):
        point.co = co
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve_data)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return finish(obj, name, mat, bone)


# Rounded compact coat body. It overlaps the shoulders and hips so Milo reads as
# one chibi villager silhouette rather than a head placed on a separate body.
sphere("MayorCoatBody", (0, 0.015, 0.83), (0.27, 0.23, 0.40), NAVY, "chest", 18, 11)
panel("PurpleWaistcoat", [(-0.15, 1.03), (0.15, 1.03), (0.15, 0.69),
                           (0.055, 0.61), (-0.055, 0.61), (-0.15, 0.69)],
      -0.258, 0.035, PURPLE, "chest")
panel("ShirtCollarL", [(-0.14, 1.10), (-0.01, 1.06), (-0.075, 0.98)],
      -0.308, 0.024, WHITE, "chest")
panel("ShirtCollarR", [(0.14, 1.10), (0.01, 1.06), (0.075, 0.98)],
      -0.308, 0.024, WHITE, "chest")
tube("WaistcoatSeam", [(0, -0.300, 0.66), (0, -0.300, 0.98)], 0.008, PURPLE_DARK, "chest")

# Lapels and coat edging follow the body curve instead of forming a box frame.
tube("TealLapelL", [(-0.03, -0.305, 1.10), (-0.13, -0.310, 1.00), (-0.19, -0.295, 0.88)], 0.012, TEAL, "chest")
tube("TealLapelR", [(0.03, -0.305, 1.10), (0.13, -0.310, 1.00), (0.19, -0.295, 0.88)], 0.012, TEAL, "chest")
tube("GoldCoatHem", [(-0.25, -0.245, 0.57), (0, -0.270, 0.54), (0.25, -0.245, 0.57)], 0.012, GOLD, "chest")
for side in (-1, 1):
    tube("GoldPocketTrim", [(0.12 * side, -0.278, 0.72), (0.23 * side, -0.265, 0.72)], 0.012, GOLD, "chest")

# Tie and four restrained mayor buttons.
prism("MayorTie", [(-0.045, -0.324, 1.06), (0.045, -0.324, 1.06),
                    (0.055, -0.324, 0.94), (0, -0.324, 0.88), (-0.055, -0.324, 0.94)],
      [(0, 1, 2, 3, 4)], PURPLE, "chest")
for x in (-0.105, 0.105):
    for z in (0.72, 0.87):
        sphere("CoatButton", (x, -0.30, z), (0.028, 0.016, 0.028), GOLD, "chest", 8, 5)

# Head and cheeks are deliberately broad and low, matching the market NPC head
# to body ratio and the approved cream-cat mayor reference.
sphere("CatHead", (0, -0.005, 1.45), (0.41, 0.32, 0.36), CREAM, "head", 20, 12)
sphere("LeftCheek", (-0.255, -0.255, 1.34), (0.125, 0.075, 0.11), CREAM, "head", 14, 8)
sphere("RightCheek", (0.255, -0.255, 1.34), (0.125, 0.075, 0.11), CREAM, "head", 14, 8)
sphere("MuzzleL", (-0.075, -0.315, 1.34), (0.125, 0.060, 0.085), WHITE, "head", 16, 9)
sphere("MuzzleR", (0.075, -0.315, 1.34), (0.125, 0.060, 0.085), WHITE, "head", 16, 9)

# Tapered ears with pink inset faces.
for side, label in ((-1, "L"), (1, "R")):
    x0 = 0.25 * side
    outer = [(x0 - 0.15, -0.10, 1.67), (x0 + 0.15, -0.10, 1.67),
             (x0 + 0.055 * side, -0.09, 1.94),
             (x0 - 0.13, 0.08, 1.66), (x0 + 0.13, 0.08, 1.66),
             (x0 + 0.045 * side, 0.06, 1.91)]
    faces = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    prism("CatEar" + label, outer, faces, CREAM, "head")
    inner = [(x0 - 0.080, -0.112, 1.70), (x0 + 0.080, -0.112, 1.70),
             (x0 + 0.035 * side, -0.108, 1.88)]
    prism("InnerEar" + label, inner, [(0, 1, 2)], PINK, "head")

# Face: soft white brows, large oval eyes, round gold glasses, nose and moustache.
for side, label in ((-1, "L"), (1, "R")):
    sphere("EyeWhite" + label, (0.125 * side, -0.300, 1.48), (0.095, 0.035, 0.125), WHITE, "head", 16, 10)
    sphere("Iris" + label, (0.125 * side, -0.337, 1.48), (0.057, 0.020, 0.087), IRIS, "head", 16, 10)
    sphere("Pupil" + label, (0.125 * side, -0.354, 1.48), (0.032, 0.012, 0.064), PUPIL, "head", 14, 9)
    sphere("EyeHighlight" + label, (0.105 * side, -0.370, 1.525), (0.014, 0.008, 0.020), HIGHLIGHT, "head", 10, 6)
    sphere("WhiteBrow" + label, (0.13 * side, -0.303, 1.635), (0.105, 0.032, 0.030), MOUSTACHE, "head", 12, 7, (0, 0.1 * side, 0.08 * side))
    torus("GlassesRing" + label, (0.125 * side, -0.372, 1.49), 0.125, 0.014, GOLD, "head")
tube("GlassesBridge", [(-0.012, -0.374, 1.50), (0.012, -0.374, 1.50)], 0.014, GOLD, "head")
sphere("PinkNose", (0, -0.410, 1.37), (0.065, 0.035, 0.050), PINK, "head", 14, 8)
sphere("SmallMouth", (0, -0.390, 1.255), (0.022, 0.012, 0.018), PINK, "head", 10, 6)
curved_tube("MoustacheL", [(-0.01, -0.423, 1.34), (-0.08, -0.426, 1.29),
                            (-0.17, -0.420, 1.30), (-0.245, -0.405, 1.345)],
            0.032, MOUSTACHE, "head")
curved_tube("MoustacheR", [(0.01, -0.423, 1.34), (0.08, -0.426, 1.29),
                            (0.17, -0.420, 1.30), (0.245, -0.405, 1.345)],
            0.032, MOUSTACHE, "head")

# Small central forehead marking.
prism("ForeheadMark", [(-0.07, -0.307, 1.70), (0.07, -0.307, 1.70), (0, -0.315, 1.58)],
      [(0, 1, 2)], MARKING, "head")

# Smooth fitted sleeves and hands use the same short bone lengths as villagers.
for side, suffix in ((-1, ".r"), (1, ".l")):
    label = "L" if side < 0 else "R"
    sphere("UpperSleeve" + label, (0.24 * side, 0, 1.02), (0.12, 0.115, 0.20), NAVY, "upperarm" + suffix, 16, 9)
    sphere("LowerSleeve" + label, (0.295 * side, 0, 0.85), (0.115, 0.11, 0.17), NAVY, "lowerarm" + suffix, 16, 9)
    torus("GoldCuff" + label, (0.315 * side, 0, 0.72), 0.086, 0.016, GOLD, "wrist" + suffix, rotation=(0, 0, 0))
    sphere("Paw" + label, (0.32 * side, 0, 0.64), (0.105, 0.10, 0.125), CREAM, "hand" + suffix, 16, 9)

# Short rounded trousers and broad shoes preserve the cast's compact stance.
for side, suffix in ((-1, ".r"), (1, ".l")):
    label = "L" if side < 0 else "R"
    sphere("Trouser" + label, (0.16 * side, 0, 0.39), (0.145, 0.14, 0.18), DARK, "upperleg" + suffix, 14, 8)
    sphere("LowerTrouser" + label, (0.16 * side, 0, 0.22), (0.12, 0.12, 0.14), DARK, "lowerleg" + suffix, 14, 8)
    sphere("Shoe" + label, (0.16 * side, -0.075, 0.10), (0.17, 0.22, 0.125), BROWN, "foot" + suffix, 14, 8)
    cube("Sole" + label, (0.16 * side, -0.08, 0.026), (0.15, 0.19, 0.018), SOLE, "foot" + suffix, bevel=0.014)

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
