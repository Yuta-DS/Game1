import bpy
import math
from pathlib import Path
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets3D/characters/Barbarian.glb"
OUTPUT = ROOT / "assets3D/characters/milo_villager_lowpoly.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
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
    # A restrained coat highlight gives the rounded forms the soft, premium
    # toy-render finish of the approved reference without making fur plastic.
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = 0.12 if metallic == 0.0 else 0.22
    if "Coat Roughness" in bsdf.inputs:
        bsdf.inputs["Coat Roughness"].default_value = 0.28
    return mat


CREAM = material("Milo Cream Fur", "c4b094", 0.58)
WHITE = material("Milo White Fur", "f0ece4", 0.56)
MOUSTACHE = material("Milo Moustache", "fffaf1", 0.52)
NAVY = material("Milo Navy Mayor Coat", "102c45", 0.58)
PURPLE = material("Milo Purple Waistcoat", "8876aa", 0.54)
PURPLE_LIGHT = material("Milo Waistcoat Highlight", "a99ac5", 0.52)
PURPLE_DARK = material("Milo Waistcoat Seam", "574876", 0.56)
GOLD = material("Milo Brushed Gold", "b9983c", 0.24, 0.48)
TEAL = material("Milo Teal Piping", "3c929f", 0.42)
PINK = material("Milo Pink Nose", "d8b1aa", 0.48)
DARK = material("Milo Trousers", "101318", 0.64)
EYE_WHITE = material("Milo Warm Eye White", "e2dfd3", 0.50)
BROW_SHADOW = material("Milo Brow Underside", "aec7cf", 0.58)
COLLAR = material("Milo Mint Collar", "a7d2cf", 0.54)
IRIS = material("Milo Warm Brown Iris", "2a2825", 0.16)
PUPIL = material("Milo Black Pupil", "0b1115", 0.10)
HIGHLIGHT = material("Milo Eye Highlight", "ffffff", 0.08)
MOUTH = material("Milo Mouth", "4a4542", 0.60)
BROWN = material("Milo Brown Shoes", "30261f", 0.48)
SOLE = material("Milo Shoe Soles", "090c0e", 0.58)
MARKING = material("Milo Fur Marking", "a18d74", 0.58)
GREEN = material("Milo Leaf Pin", "77af76", 0.38)
CYAN = material("Milo Diamond Pin", "75c7d2", 0.32)
VIOLET = material("Milo Star Pin", "a68bc2", 0.38)

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


def sphere(name, location, scale, mat, bone, segments=20, rings=12, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, radius=1.0,
        location=location, rotation=rotation)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat, bone)


def torus(name, location, major, minor, mat, bone, rotation=(math.pi / 2, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor,
        major_segments=32, minor_segments=10,
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
        mod.segments = 4
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
    # The card panels sit on Milo's negative-Y/front side. Reverse the front
    # winding so Godot does not back-face-cull the waistcoat and collar.
    faces = [tuple(range(count))[::-1], tuple(range(count, count * 2))]
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
    curve_data.resolution_u = 6
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = 4
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


# A bevelled rounded-rectangle body matches the target's compact coat: broad
# shoulders, nearly straight sides and a soft hem. The old sphere produced an
# egg torso and made every attached part read as a separate primitive.
cube("MayorCoatBody", (0, 0.015, 0.84), (0.42, 0.275, 0.40),
     NAVY, "chest", bevel=0.18)
panel("PurpleWaistcoat", [(-0.225, 1.07), (0.225, 1.07), (0.225, 0.68),
                           (0.078, 0.59), (-0.078, 0.59), (-0.225, 0.68)],
      -0.318, 0.025, PURPLE, "chest")
# Raised upper waistcoat facets and a central tie give the suit the folded,
# tailored depth visible in the close-up instead of one flat lavender card.
panel("WaistcoatFacetL", [(-0.215, 1.055), (-0.020, 1.055),
                           (-0.075, 0.965), (-0.185, 0.905)],
      -0.346, 0.014, PURPLE_LIGHT, "chest")
panel("WaistcoatFacetR", [(0.215, 1.055), (0.020, 1.055),
                           (0.075, 0.965), (0.185, 0.905)],
      -0.346, 0.014, PURPLE_LIGHT, "chest")
panel("ShirtCollarL", [(-0.17, 1.10), (-0.015, 1.065), (-0.095, 0.995)],
      -0.338, 0.018, COLLAR, "chest")
panel("ShirtCollarR", [(0.17, 1.10), (0.015, 1.065), (0.095, 0.995)],
      -0.338, 0.018, COLLAR, "chest")
tube("WaistcoatSeam", [(0, -0.347, 0.66), (0, -0.347, 0.98)], 0.008, PURPLE_DARK, "chest")

# Lapels and coat edging follow the body curve instead of forming a box frame.
tube("TealLapelL", [(-0.10, -0.353, 1.10), (-0.19, -0.353, 1.045), (-0.225, -0.348, 0.96)], 0.008, TEAL, "chest")
tube("TealLapelR", [(0.10, -0.353, 1.10), (0.19, -0.353, 1.045), (0.225, -0.348, 0.96)], 0.008, TEAL, "chest")
tube("GoldCoatHem", [(-0.29, -0.260, 0.57), (0, -0.286, 0.54), (0.29, -0.260, 0.57)], 0.012, GOLD, "chest")

# Tie and four restrained mayor buttons.
prism("MayorTie", [(-0.055, -0.372, 1.04), (0.055, -0.372, 1.04),
                    (0.065, -0.372, 0.93), (0, -0.372, 0.855), (-0.065, -0.372, 0.93)],
      [(0, 1, 2, 3, 4)], PURPLE_LIGHT, "chest")
for x in (-0.105, 0.105):
    for z in (0.72, 0.87):
        sphere("CoatButton", (x, -0.365, z), (0.038, 0.020, 0.038), GOLD, "chest", 16, 9)
sphere("MayorMedallion", (0, -0.386, 1.035), (0.043, 0.022, 0.050),
       GOLD, "chest", 18, 10)

# Head and cheeks are deliberately broad and low, matching the market NPC head
# to body ratio and the approved cream-cat mayor reference.
sphere("CatHead", (0, -0.005, 1.50), (0.50, 0.37, 0.47), CREAM, "head", 32, 20)
sphere("LeftCheek", (-0.335, -0.285, 1.38), (0.145, 0.090, 0.115), CREAM, "head", 24, 14)
sphere("RightCheek", (0.335, -0.285, 1.38), (0.145, 0.090, 0.115), CREAM, "head", 24, 14)
sphere("LeftLowerCheek", (-0.385, -0.270, 1.29), (0.100, 0.075, 0.085), CREAM, "head", 20, 12)
sphere("RightLowerCheek", (0.385, -0.270, 1.29), (0.100, 0.075, 0.085), CREAM, "head", 20, 12)
sphere("MuzzleL", (-0.090, -0.374, 1.35), (0.158, 0.072, 0.100), WHITE, "head", 26, 16)
sphere("MuzzleR", (0.090, -0.374, 1.35), (0.158, 0.072, 0.100), WHITE, "head", 26, 16)

# Tapered ears with pink inset faces.
for side, label in ((-1, "L"), (1, "R")):
    x0 = 0.31 * side
    outer = [(x0 - 0.18, -0.10, 1.72), (x0 + 0.18, -0.10, 1.72),
             (x0 + 0.045 * side, -0.09, 2.07),
             (x0 - 0.16, 0.08, 1.71), (x0 + 0.16, 0.08, 1.71),
             (x0 + 0.038 * side, 0.06, 2.04)]
    faces = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    prism("CatEar" + label, outer, faces, CREAM, "head")
    inner = [(x0 - 0.110, -0.112, 1.75), (x0 + 0.110, -0.112, 1.75),
             (x0 + 0.030 * side, -0.108, 1.99)]
    prism("InnerEar" + label, inner, [(0, 1, 2)], PINK, "head")

# Face: soft white brows, large oval eyes, round gold glasses, nose and moustache.
for side, label in ((-1, "L"), (1, "R")):
    sphere("EyeWhite" + label, (0.160 * side, -0.347, 1.50), (0.105, 0.035, 0.130), EYE_WHITE, "head", 24, 16)
    # The close-up target has plain black oval pupils, not a visible brown iris.
    sphere("Pupil" + label, (0.160 * side, -0.392, 1.50), (0.041, 0.017, 0.076), PUPIL, "head", 24, 16)
    sphere("EyeHighlight" + label, (0.143 * side, -0.411, 1.555), (0.012, 0.007, 0.018), HIGHLIGHT, "head", 14, 9)
    torus("GlassesRing" + label, (0.160 * side, -0.421, 1.51), 0.137, 0.012, GOLD, "head")
# Layered faceted brows reproduce the target's graphic white blocks and cool
# underside, instead of the previous floating pill-shaped eyebrows.
panel("BrowShadowL", [(-0.275, 1.665), (-0.175, 1.695), (-0.055, 1.675),
                       (-0.065, 1.630), (-0.170, 1.645), (-0.265, 1.625)],
      -0.392, 0.012, BROW_SHADOW, "head")
panel("BrowShadowR", [(0.275, 1.665), (0.175, 1.695), (0.055, 1.675),
                       (0.065, 1.630), (0.170, 1.645), (0.265, 1.625)],
      -0.392, 0.012, BROW_SHADOW, "head")
panel("WhiteBrowL", [(-0.275, 1.690), (-0.175, 1.720), (-0.055, 1.700),
                      (-0.065, 1.660), (-0.170, 1.675), (-0.265, 1.650)],
      -0.405, 0.012, MOUSTACHE, "head")
panel("WhiteBrowR", [(0.275, 1.690), (0.175, 1.720), (0.055, 1.700),
                      (0.065, 1.660), (0.170, 1.675), (0.265, 1.650)],
      -0.405, 0.012, MOUSTACHE, "head")
tube("GlassesBridge", [(-0.018, -0.423, 1.52), (0.018, -0.423, 1.52)], 0.012, GOLD, "head")
sphere("PinkNose", (0, -0.462, 1.372), (0.088, 0.044, 0.062), PINK, "head", 24, 15)
sphere("SmallMouth", (0, -0.420, 1.245), (0.030, 0.014, 0.018), MOUTH, "head", 14, 8)
# Broad moustache pads reproduce the full white sweep in the supplied close-up;
# the curved tubes below form only the lifted lower edges.
sphere("MoustachePadL", (-0.130, -0.448, 1.325), (0.215, 0.043, 0.102),
       MOUSTACHE, "head", 26, 16, (0, 0, -0.12))
sphere("MoustachePadR", (0.130, -0.448, 1.325), (0.215, 0.043, 0.102),
       MOUSTACHE, "head", 26, 16, (0, 0, 0.12))
curved_tube("MoustacheL", [(-0.01, -0.470, 1.34), (-0.10, -0.474, 1.275),
                            (-0.21, -0.466, 1.29), (-0.325, -0.448, 1.36)],
            0.048, MOUSTACHE, "head")
curved_tube("MoustacheR", [(0.01, -0.470, 1.34), (0.10, -0.474, 1.275),
                            (0.21, -0.466, 1.29), (0.325, -0.448, 1.36)],
            0.048, MOUSTACHE, "head")

# Small central forehead marking.
prism("ForeheadMark", [(-0.075, -0.392, 1.78), (0.075, -0.392, 1.78), (0, -0.402, 1.63)],
      [(0, 1, 2)], MARKING, "head")

# Smooth fitted sleeves and hands use the same short bone lengths as villagers.
for side, suffix in ((-1, ".r"), (1, ".l")):
    label = "L" if side < 0 else "R"
    # One continuous sleeve per side. The earlier two-lobe upper/lower sleeve
    # made each hand read as two stacked objects; the target has one clean arm
    # silhouette ending in one rounded paw.
    sphere("MayorSleeve" + label, (0.425 * side, 0, 0.91),
           (0.120, 0.125, 0.285), NAVY, "upperarm" + suffix, 24, 15)
    torus("GoldCuff" + label, (0.440 * side, 0, 0.69), 0.090, 0.014, GOLD, "wrist" + suffix, rotation=(0, 0, 0))
    sphere("Paw" + label, (0.440 * side, -0.015, 0.605), (0.110, 0.108, 0.132), CREAM, "hand" + suffix, 24, 15)
    for line_offset in (-0.022, 0.022):
        tube("PawLine" + label, [(0.440 * side + line_offset, -0.125, 0.59),
                                  (0.440 * side + line_offset, -0.127, 0.63)],
             0.004, MARKING, "hand" + suffix)

# One smooth trouser leg enters one rounded boot on each side. Keeping each
# silhouette continuous avoids both the old stacked cuffs and the later blocky
# two-column leg, while the taller shoe matches the target's soft boot profile.
for side, suffix in ((-1, ".r"), (1, ".l")):
    label = "L" if side < 0 else "R"
    sphere("TrouserLeg" + label, (0.14 * side, -0.002, 0.350),
           (0.120, 0.108, 0.150), DARK, "lowerleg" + suffix, 24, 16)
    sphere("Boot" + label, (0.14 * side, -0.095, 0.140),
           (0.200, 0.225, 0.120), BROWN, "foot" + suffix, 28, 17)
    sphere("Sole" + label, (0.14 * side, -0.090, 0.058),
           (0.195, 0.210, 0.014), SOLE, "foot" + suffix, 26, 8)

# One continuous curled tail. The earlier chain of round segments looked like
# stacked beads; this smooth tube matches the single-tail silhouette in both
# supplied references. Two fitted bands retain Milo's striped-cat identity.
curved_tube("MayorTail", [(0.27, 0.10, 0.64), (0.44, 0.12, 0.70),
                          (0.58, 0.10, 0.80), (0.58, 0.07, 0.91),
                          (0.52, 0.05, 0.98)],
            0.060, CREAM, "hips")
torus("TailStripeLower", (0.575, 0.105, 0.78), 0.061, 0.011,
      MARKING, "hips", rotation=(0, 0, 0))
torus("TailStripeUpper", (0.575, 0.075, 0.89), 0.059, 0.011,
      MARKING, "hips", rotation=(0, 0, 0))
sphere("TailTip", (0.52, 0.05, 0.98), (0.062, 0.062, 0.067),
       MARKING, "hips", 14, 8)

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
    filepath=str(OUTPUT),
    export_format="GLB",
    use_selection=True,
    export_animations=True,
    export_nla_strips=True,
    export_materials="EXPORT",
)
print(f"MILO_VILLAGER_BUILD: {len(milo.data.vertices)} vertices, {len(milo.data.polygons)} faces -> {OUTPUT}")
