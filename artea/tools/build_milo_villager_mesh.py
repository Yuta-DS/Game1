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
    # The arm chain must terminate where the sleeve and paw geometry actually
    # sits.  The bones previously stopped at x=0.32 while the sleeves and hands
    # were authored out at x=0.50..0.56, so the skin was driven from well inside
    # the visible arm - which is what made the sleeves appear folded across the
    # chest instead of hanging at Milo's sides.  The chain now runs out to the
    # shoulder line and straight down, matching the built geometry.
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
# geometry is replaced with Milo's connected low-poly mayor mesh.  The donor file
# also ships an unparented 42-vertex "Icosphere" helper whose +/-1.0 extents
# would otherwise dominate the exported bounding box, so every mesh goes,
# parented to the rig or not.
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
MAYOR_GOLD = material("Milo Antique Suit Gold", "8f6b32", 0.50, 0.22)
TEAL = material("Milo Teal Piping", "3c929f", 0.42)
PINK = material("Milo Pink Nose", "d8b1aa", 0.48)
DARK = material("Milo Trousers", "101318", 0.64)
EYE_WHITE = material("Milo Warm Eye White", "e2dfd3", 0.50)
BROW_SHADOW = material("Milo Brow Underside", "aec7cf", 0.58)
COLLAR = material("Milo Mint Collar", "a7d2cf", 0.54)
TIE_PURPLE = material("Milo Mayor Tie", "4a315e", 0.56)
CANE_BROWN = material("Milo Cane Wood", "402b1a", 0.60)
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


def distance_to_segment(px, pz, ax, az, bx, bz):
    abx, abz = bx - ax, bz - az
    length_sq = abx * abx + abz * abz
    if length_sq == 0:
        return math.hypot(px - ax, pz - az)
    t = max(0.0, min(1.0, ((px - ax) * abx + (pz - az) * abz) / length_sq))
    return math.hypot(px - (ax + t * abx), pz - (az + t * abz))


def make_tailcoat_fabric_material():
    """Bake teal and gold tailoring into the coat's actual colour texture."""
    width = height = 256
    x_min, x_max = -0.40, 0.40
    z_min, z_max = 0.47, 1.18
    # Texture colours are slightly lifted to compensate for sRGB conversion
    # and the mobile renderer's shaded front-facing fabric.
    navy = tuple(int("1b304a"[i:i + 2], 16) / 255 for i in (0, 2, 4))
    teal = tuple(int("69b6b2"[i:i + 2], 16) / 255 for i in (0, 2, 4))
    gold = tuple(int("b58a3d"[i:i + 2], 16) / 255 for i in (0, 2, 4))
    teal_paths = [
        [(-0.310, 1.145), (-0.140, 1.107), (-0.208, 1.018), (-0.160, 0.925)],
        [(0.310, 1.145), (0.140, 1.107), (0.208, 1.018), (0.160, 0.925)],
    ]
    gold_paths = [
        [(-0.160, 0.890), (-0.178, 0.555), (-0.310, 0.515)],
        [(0.160, 0.890), (0.178, 0.555), (0.310, 0.515)],
        [(-0.325, 0.690), (-0.235, 0.670)],
        [(0.325, 0.690), (0.235, 0.670)],
    ]

    pixels = [0.0] * (width * height * 4)
    for iy in range(height):
        z = z_min + (z_max - z_min) * iy / (height - 1)
        for ix in range(width):
            x = x_min + (x_max - x_min) * ix / (width - 1)
            colour = navy
            for paths, ink, radius in ((teal_paths, teal, 0.014),
                                       (gold_paths, gold, 0.015)):
                distance = min(
                    distance_to_segment(x, z, *path[i], *path[i + 1])
                    for path in paths for i in range(len(path) - 1)
                )
                if distance <= radius:
                    # One-pixel feather keeps the painted edge smooth without
                    # creating any physical ridge or highlight.
                    feather = 0.0035
                    mix = min(1.0, (radius - distance) / feather)
                    colour = tuple(colour[c] * (1.0 - mix) + ink[c] * mix
                                   for c in range(3))
            offset = (iy * width + ix) * 4
            pixels[offset:offset + 4] = (*colour, 1.0)

    image = bpy.data.images.new("MiloTailcoatFabricColour", width, height)
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(ROOT / "assets3D/characters/milo_tailcoat_fabric_colour.png")
    image.file_format = "PNG"
    image.save()

    mat = material("Milo Tailcoat Fabric With Inlaid Colour", "08101f", 0.72)
    nodes = mat.node_tree.nodes
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Linear"
    # Explicitly bind the fabric's own UV channel.  Milo's joined rig mesh also
    # contains the source character's generic UVMap; relying on the active map
    # would sample that unrelated channel and hide the painted tailoring.
    uv_map = nodes.new("ShaderNodeUVMap")
    uv_map.uv_map = "TailcoatFabricUV"
    mat.node_tree.links.new(uv_map.outputs["UV"], texture.inputs["Vector"])
    mat.node_tree.links.new(texture.outputs["Color"],
                            nodes.get("Principled BSDF").inputs["Base Color"])
    return mat


TAILCOAT_FABRIC = make_tailcoat_fabric_material()


def make_tabby_fur_material():
    """Paint banded tabby markings into the cream fur's colour texture.

    The reference sheet's cat is tabby: darker bands break up the head, ears and
    limbs.  Flat cream fur is what makes the current model read as an untextured
    prototype, so the banding is baked into an image rather than approximated
    with extra geometry, which would cost vertices and still shade flat.
    """
    width = height = 256
    base = tuple(int("c4b094"[i:i + 2], 16) / 255 for i in (0, 2, 4))
    band = tuple(int("8a6f4a"[i:i + 2], 16) / 255 for i in (0, 2, 4))
    pixels = [0.0] * (width * height * 4)
    for iy in range(height):
        v = iy / (height - 1)
        for ix in range(width):
            u = ix / (width - 1)
            # Sine bands along v, warped by u so the stripes curve around the
            # form instead of reading as straight printed lines.
            wave = math.sin(v * math.pi * 14.0 + math.sin(u * math.pi * 2.0) * 1.1)
            strength = max(0.0, (wave - 0.05) / 0.95)
            # Belly and inner surfaces stay pale, as on a real tabby.
            strength *= min(1.0, 0.35 + abs(u - 0.5) * 1.9)
            colour = tuple(base[c] * (1.0 - strength) + band[c] * strength
                           for c in range(3))
            offset = (iy * width + ix) * 4
            pixels[offset:offset + 4] = (*colour, 1.0)

    image = bpy.data.images.new("MiloTabbyFurColour", width, height)
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(ROOT / "assets3D/characters/milo_tabby_fur_colour.png")
    image.file_format = "PNG"
    image.save()

    mat = material("Milo Tabby Fur", "c4b094", 0.58)
    nodes = mat.node_tree.nodes
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Linear"
    # Generated coordinates wrap the banding around each rounded form without
    # needing a hand-authored UV layout for every primitive.
    coords = nodes.new("ShaderNodeTexCoord")
    mat.node_tree.links.new(coords.outputs["Generated"], texture.inputs["Vector"])
    mat.node_tree.links.new(texture.outputs["Color"],
                            nodes.get("Principled BSDF").inputs["Base Color"])
    return mat


# The approved target is a clean warm-cream cat.  Its only darker markings are
# the small forehead triangle and the two tail bands; full-body tabby stripes
# change the character identity and make the face read much busier than the
# supplied reference.
TABBY_FUR = CREAM

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


# Global subdivision multiplier.  The silhouette and proportions are already
# approved, so higher detail comes from resolving the existing forms more finely
# rather than from re-authoring them.
DETAIL = 1.75


def _dense(value, minimum):
    return max(minimum, int(round(value * DETAIL)))


def sphere(name, location, scale, mat, bone, segments=20, rings=12, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=_dense(segments, 8), ring_count=_dense(rings, 6), radius=1.0,
        location=location, rotation=rotation)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat, bone)


def torus(name, location, major, minor, mat, bone, rotation=(math.pi / 2, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor,
        # 24x8 is visually round at Milo's NPC scale and avoids spending more
        # vertices on tiny trim rings than on the expressive face.
        major_segments=_dense(24, 12), minor_segments=_dense(8, 6),
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
        mod.segments = _dense(4, 4)
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


def rounded_panel(name, outline, y_front, thickness, mat, bone,
                  bevel=0.018, segments=3):
    """Extrude a shaped panel and softly round its silhouette and rim."""
    obj = panel(name, outline, y_front, thickness, mat, bone)
    modifier = obj.modifiers.new("Soft curved rim", "BEVEL")
    modifier.width = bevel
    modifier.segments = _dense(segments, 2)
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def textured_panel(name, outline, y_front, thickness, mat, bone,
                   x_bounds=(-0.40, 0.40), z_bounds=(0.47, 1.18)):
    """Create one coat surface whose coloured tailoring is UV-embedded."""
    obj = panel(name, outline, y_front, thickness, mat, bone)
    uv_layer = obj.data.uv_layers.new(name="TailcoatFabricUV")
    x_min, x_max = x_bounds
    z_min, z_max = z_bounds
    for polygon in obj.data.polygons:
        for loop_index in polygon.loop_indices:
            vertex = obj.data.vertices[obj.data.loops[loop_index].vertex_index].co
            uv_layer.data[loop_index].uv = (
                (vertex.x - x_min) / (x_max - x_min),
                (vertex.z - z_min) / (z_max - z_min),
            )
    return obj


def tube(name, points, radius, mat, bone):
    curve_data = bpy.data.curves.new(name + "Curve", "CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = 1
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = _dense(1, 2)
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
    # Three longitudinal subdivisions and a two-step round bevel are sufficient
    # for the soft low-poly language while keeping the web GLB lightweight.
    curve_data.resolution_u = _dense(3, 3)
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = _dense(2, 2)
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


# Measured from the 594x942 target card: the visible waistcoat occupies about
# 56% of the coat-front width and 87% of its chest-to-hem height; button centres
# sit near 15%/85% across the vest, with rows at roughly 41%/78% down. Materials
# below compensate for the Godot preview lighting to reproduce the sampled
# target render colours (navy ~#405b7c, lavender ~#a09dba, gold ~#aa986a).
# A bevelled rounded-rectangle body matches the target's compact coat: broad
# shoulders, nearly straight sides and a soft hem. The old sphere produced an
# egg torso and made every attached part read as a separate primitive.
cube("MayorCoatBody", (0, 0.015, 0.84), (0.38, 0.275, 0.405),
     NAVY, "chest", bevel=0.16)
# The approved formal outfit is constructed in the same layer order as a real
# open tailcoat: shirt, waistcoat, lapels, piping, then opening trim.  The vest
# is deliberately narrow and ends in two points so the navy coat remains
# visible around it instead of reading as a lavender bib.
#
# Each garment layer keeps its authored FRONT face but is extruded back far
# enough to bury its rear inside the coat body (front face y=-0.260).  Thin
# panels previously stopped short of the torso, so in profile the chest read as
# a stack of parallel cards floating in mid air with daylight between them.
# Only the hidden rear depth changes here; the visible surfaces and their
# layering order are untouched.
rounded_panel("PurpleWaistcoat", [(-0.155, 1.080), (0.155, 1.080),
                                   (0.150, 0.700), (0.065, 0.610),
                                   (0, 0.670), (-0.065, 0.610),
                                   (-0.150, 0.700)],
              -0.318, 0.098, PURPLE, "chest", bevel=0.014, segments=3)
rounded_panel("WaistcoatFacetL", [(-0.148, 1.055), (-0.012, 1.055),
                                   (-0.048, 0.955), (-0.142, 0.905)],
              -0.344, 0.108, PURPLE_LIGHT, "chest", bevel=0.007, segments=2)
rounded_panel("WaistcoatFacetR", [(0.148, 1.055), (0.012, 1.055),
                                   (0.048, 0.955), (0.142, 0.905)],
              -0.344, 0.108, PURPLE_LIGHT, "chest", bevel=0.007, segments=2)
rounded_panel("ShirtCollarL", [(-0.185, 1.135), (-0.008, 1.090),
                                (-0.082, 0.990), (-0.165, 1.050)],
              -0.350, 0.114, COLLAR, "chest", bevel=0.007, segments=2)
rounded_panel("ShirtCollarR", [(0.185, 1.135), (0.008, 1.090),
                                (0.082, 0.990), (0.165, 1.050)],
              -0.350, 0.114, COLLAR, "chest", bevel=0.007, segments=2)
tube("WaistcoatSeam", [(0, -0.330, 0.675), (0, -0.330, 0.955)],
     0.005, PURPLE_DARK, "chest")

# Each side is now one continuous UV-mapped coat panel.  Navy fabric, teal
# lapel piping and antique-gold opening edge are colour pixels in the same
# material, never separate meshes.  The panel overlaps the rounded shoulder
# and follows the open-tail geometry down to the hem.
textured_panel("InlaidTailcoatFrontL",
               [(-0.345, 1.175), (-0.105, 1.115), (-0.195, 1.005),
                (-0.145, 0.915), (-0.165, 0.535), (-0.330, 0.490),
                (-0.375, 0.575), (-0.375, 1.075)],
               -0.350, 0.114, TAILCOAT_FABRIC, "chest")
textured_panel("InlaidTailcoatFrontR",
               [(0.345, 1.175), (0.105, 1.115), (0.195, 1.005),
                (0.145, 0.915), (0.165, 0.535), (0.330, 0.490),
                (0.375, 0.575), (0.375, 1.075)],
               -0.350, 0.114, TAILCOAT_FABRIC, "chest")

# The dark opening beneath the vest and two separate gold edges make the coat
# read as open and tailored; there is no artificial gold bar across the belly.
# The trousers themselves are built below as complete 360-degree volumes.
# There are no flat front cards here: the pointed waistcoat and open coat reveal
# the upper surfaces of the same full leg meshes used around the sides and back.

# Compact tie, antique-gold medallion, paired vest buttons, coat buttons and
# pocket tabs reproduce the hierarchy and spacing measured from the target.
rounded_panel("MayorTieKnot", [(-0.052, 1.095), (0.052, 1.095),
                                (0.040, 1.025), (0, 1.000),
                                (-0.040, 1.025)],
              -0.374, 0.070, TIE_PURPLE, "chest", bevel=0.007, segments=2)
rounded_panel("MayorTieBlade", [(-0.036, 1.010), (0.036, 1.010),
                                 (0.052, 0.945), (0, 0.900),
                                 (-0.052, 0.945)],
              -0.371, 0.065, TIE_PURPLE, "chest", bevel=0.006, segments=2)
sphere("MayorMedallion", (0, -0.381, 0.970), (0.038, 0.030, 0.047),
       MAYOR_GOLD, "chest", 16, 9)
# Four large paired buttons are one of the target's clearest costume cues.
for z in (0.855, 0.735):
    for side in (-1, 1):
        sphere("WaistcoatButton", (0.105 * side, -0.376, z),
               (0.031, 0.027, 0.031), MAYOR_GOLD, "chest", 14, 8)

# Head and cheeks are deliberately broad and low, matching the market NPC head
# to body ratio and the approved cream-cat mayor reference.
cat_head = sphere("CatHead", (0, -0.005, 1.50),
                  (0.50, 0.37, 0.47), TABBY_FUR, "head", 28, 18)
# A cat's head is broad through the temples and upper cheeks, then narrows into
# the muzzle and jaw.  Deforming the existing smooth rigged sphere preserves
# its animation and low-poly topology while removing the human-like roundness.
for vertex in cat_head.data.vertices:
    normalized_z = max(-1.0, min(1.0, vertex.co.z / 0.47))
    if normalized_z < 0.0:
        vertex.co.x *= 1.0 + normalized_z * 0.18
    elif normalized_z < 0.55:
        vertex.co.x *= 1.04
    else:
        vertex.co.x *= 1.04 - (normalized_z - 0.55) * 0.10
sphere("MuzzleL", (-0.082, -0.374, 1.35), (0.125, 0.060, 0.078), WHITE, "head", 26, 16)
sphere("MuzzleR", (0.082, -0.374, 1.35), (0.125, 0.060, 0.078), WHITE, "head", 26, 16)

# Face features were previously placed on a single flat plane of fixed y.  The
# skull is an ellipsoid, so in profile the whole face read as a detached card
# hovering in front of the head with a visible gap.  Conforming each feature to
# the actual head surface seats eyes, glasses, brows, nose and moustache into
# the face instead, which is what makes the character read as one solid object
# from every angle rather than only head-on.
HEAD_CENTRE = Vector((0.0, -0.005, 1.50))
HEAD_RADII = Vector((0.50 * 1.04, 0.37, 0.47))


def head_surface_y(x, z, inset=0.0):
    """Front-side y of the skull ellipsoid at (x, z), pushed in by `inset`.

    Returns None when (x, z) falls outside the head silhouette, so callers can
    leave outlying geometry (whisker tips, ear edges) exactly where it was.
    """
    nx = (x - HEAD_CENTRE.x) / HEAD_RADII.x
    nz = (z - HEAD_CENTRE.z) / HEAD_RADII.z
    radial = nx * nx + nz * nz
    if radial >= 1.0:
        return None
    return HEAD_CENTRE.y - HEAD_RADII.y * math.sqrt(1.0 - radial) + inset


def conform_to_head(obj, inset=0.0, blend=1.0):
    """Slide a face part back onto the skull along y, keeping its own shape.

    Only y moves, so the silhouette, bevels and UVs authored in the x/z plane
    are all preserved; the part simply stops floating.  `blend` lets rounded
    features keep part of their original depth so they still protrude.
    """
    offsets = []
    for vertex in obj.data.vertices:
        world = obj.matrix_world @ vertex.co
        surface = head_surface_y(world.x, world.z, inset)
        offsets.append(None if surface is None else (surface - world.y) * blend)
    valid = [o for o in offsets if o is not None]
    if not valid:
        return obj
    # Shift the part rigidly by its median offset.  A per-vertex shift would
    # shear thin panels such as the brows into curved shells; moving the whole
    # feature keeps each one a clean, readable shape against the skull.
    valid.sort()
    shift = valid[len(valid) // 2]
    obj.location.y += shift
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    return obj


conform_to_head(bpy.data.objects["MuzzleL"], inset=-0.062)
conform_to_head(bpy.data.objects["MuzzleR"], inset=-0.062)

# Rounded, gently curved ears. The extra outline points and bevel replace the
# old sharp triangular prisms, matching the soft carved silhouette in the
# supplied close-up while retaining a restrained low-poly surface density.
for side, label in ((-1, "L"), (1, "R")):
    # Define the right ear once in front view, then mirror it for the left.
    # Both base corners terminate well inside the head silhouette. Because the
    # ear also sits behind the head, the head naturally masks this join and the
    # visible edge rises as one continuous curve instead of a separate shelf.
    outer_right = [(0.145, 1.665), (0.170, 1.800), (0.220, 1.900),
                   (0.285, 2.005), (0.340, 2.070), (0.375, 2.075),
                   (0.415, 2.025), (0.455, 1.925), (0.485, 1.815),
                   (0.425, 1.665)]
    inner_right = [(0.220, 1.690), (0.240, 1.835), (0.285, 1.920),
                   (0.340, 1.990), (0.370, 1.995), (0.400, 1.940),
                   (0.430, 1.845), (0.405, 1.690)]
    outer = [(x * side, z) for x, z in outer_right]
    inner = [(x * side, z) for x, z in inner_right]
    rounded_panel("CatEar" + label, outer, -0.015, 0.125,
                  TABBY_FUR, "head", bevel=0.018, segments=4)
    rounded_panel("InnerEar" + label, inner, -0.038, 0.014,
                  PINK, "head", bevel=0.010, segments=3)

# Face: soft white brows, large oval eyes, round gold glasses, nose and moustache.
# Each feature is seated against the skull at its own depth, so the eye sits in
# a socket, the pupil sits inside the eye, and the glasses ride just clear of
# both.  The inset values keep that stacking order while removing the gap.
for side, label in ((-1, "L"), (1, "R")):
    conform_to_head(
        sphere("EyeWhite" + label, (0.160 * side, -0.347, 1.50),
               (0.088, 0.030, 0.105), EYE_WHITE, "head", 24, 16),
        inset=0.020)
    # Compact, smoothly rounded brown-black pupils match the target's softer
    # glossy ovals instead of the previous tall blue-black faceted shapes.
    conform_to_head(
        sphere("Pupil" + label, (0.160 * side, -0.392, 1.50),
               (0.033, 0.014, 0.061), PUPIL, "head", 24, 16),
        inset=0.004)
    conform_to_head(
        sphere("EyeHighlight" + label, (0.145 * side, -0.410, 1.548),
               (0.010, 0.005, 0.015), HIGHLIGHT, "head", 16, 10),
        inset=-0.004)
    conform_to_head(
        torus("GlassesRing" + label, (0.160 * side, -0.421, 1.51),
              0.135, 0.009, GOLD, "head"),
        inset=-0.055)
# Two-layer arched brows follow the glasses rather than reading as horizontal
# blocks. Tapered ends, a lifted centre, and an exposed cool underside reproduce
# the gentle carved expression of the supplied close-up.
brow_right = [(0.052, 1.710), (0.105, 1.735), (0.170, 1.748),
              (0.230, 1.738), (0.286, 1.708), (0.278, 1.665),
              (0.226, 1.688), (0.168, 1.697), (0.108, 1.687),
              (0.060, 1.670)]
shadow_right = [(x, z - 0.026) for x, z in brow_right]
for side, label in ((-1, "L"), (1, "R")):
    brow = [(x * side, z) for x, z in brow_right]
    shadow = [(x * side, z) for x, z in shadow_right]
    conform_to_head(
        rounded_panel("BrowShadow" + label, shadow, -0.398, 0.010,
                      BROW_SHADOW, "head", bevel=0.007, segments=2),
        inset=0.004)
    conform_to_head(
        rounded_panel("WhiteBrow" + label, brow, -0.414, 0.010,
                      MOUSTACHE, "head", bevel=0.008, segments=3),
        inset=-0.004)
conform_to_head(
    tube("GlassesBridge", [(-0.020, -0.423, 1.52), (0.020, -0.423, 1.52)],
         0.009, GOLD, "head"),
    inset=-0.055)
# Nose and muzzle deliberately protrude: a blend keeps part of their authored
# depth so the snout still reads in profile instead of flattening into the face.
conform_to_head(
    sphere("PinkNose", (0, -0.462, 1.372), (0.088, 0.044, 0.062),
           PINK, "head", 24, 15),
    inset=-0.086)
conform_to_head(
    sphere("SmallMouth", (0, -0.420, 1.245), (0.030, 0.014, 0.018),
           MOUTH, "head", 14, 8),
    inset=-0.040)
# Broad moustache pads reproduce the full white sweep in the supplied close-up.
# Their top edge stays below the glasses rims so the two accessories remain
# visually and geometrically separate while still meeting beneath the nose.
conform_to_head(
    sphere("MoustachePadL", (-0.115, -0.448, 1.285), (0.170, 0.038, 0.070),
           MOUSTACHE, "head", 26, 16, (0, 0, -0.12)),
    inset=-0.074)
conform_to_head(
    sphere("MoustachePadR", (0.115, -0.448, 1.285), (0.170, 0.038, 0.070),
           MOUSTACHE, "head", 26, 16, (0, 0, 0.12)),
    inset=-0.074)
conform_to_head(
    curved_tube("MoustacheL", [(-0.01, -0.470, 1.305), (-0.09, -0.474, 1.250),
                               (-0.18, -0.466, 1.260), (-0.270, -0.448, 1.315)],
                0.036, MOUSTACHE, "head"),
    inset=-0.082)
conform_to_head(
    curved_tube("MoustacheR", [(0.01, -0.470, 1.305), (0.09, -0.474, 1.250),
                               (0.18, -0.466, 1.260), (0.270, -0.448, 1.315)],
                0.036, MOUSTACHE, "head"),
    inset=-0.082)

# Small central forehead marking.
prism("ForeheadMark", [(-0.075, -0.392, 1.78), (0.075, -0.392, 1.78), (0, -0.402, 1.63)],
      [(0, 1, 2)], MARKING, "head")

# Smooth fitted sleeves and hands use the same short bone lengths as villagers.
for side, suffix in ((-1, ".r"), (1, ".l")):
    label = "L" if side < 0 else "R"
    # One continuous sleeve per side. The earlier two-lobe upper/lower sleeve
    # made each hand read as two stacked objects; the target has one clean arm
    # silhouette ending in one rounded paw.
    # A rounded rectangular sleeve has a controlled lower edge, allowing the
    # sleeve, cuff and paw to meet at clean boundaries rather than intersecting
    # three ellipsoids.  The slight outward tilt preserves shoulder connection.
    sleeve = cube("MayorSleeve" + label, (0.475 * side, -0.055, 0.890),
                  (0.115, 0.140, 0.275), NAVY, "upperarm" + suffix,
                  rotation=(0, -side * 0.02, 0), bevel=0.095)
    # The formal gold sleeve band is material painted onto the sleeve's own
    # polygon rows.  It therefore bends and shades with the navy cloth without
    # creating a separate torus, ridge, gap or stacked-object silhouette.
    sleeve.data.materials.append(MAYOR_GOLD)
    for polygon in sleeve.data.polygons:
        centre = sum((sleeve.data.vertices[index].co
                      for index in polygon.vertices), Vector()) / len(polygon.vertices)
        local_z = centre.z
        if -0.245 <= local_z <= -0.185:
            polygon.material_index = 1
    # A softly bevelled box matches the sleeve's lower footprint.  The paw is
    # slightly narrower than the coat opening and shares its z=0.63 boundary,
    # producing a deliberate covered wrist instead of a ball under a rectangle.
    sphere("Paw" + label, (0.505 * side, -0.090, 0.565),
           (0.090, 0.080, 0.105), TABBY_FUR, "hand" + suffix, 20, 12)

# A small left thumb folds across the front of the hidden cane section.  The
# visible shaft stops at the hand boundaries, so no wood passes through skin.
# The cane-grip thumb blob is gone: the right paw now models a real opposed
# thumb, and keeping both produced two thumbs on one hand.

# Full-height tailored trousers wrap every leg through 360 degrees.  Their
# rounded rectangular volume runs from beneath the waistcoat to the boot top,
# while blended upper/lower-leg weights preserve walking animation.
for side, suffix in ((-1, ".r"), (1, ".l")):
    label = "L" if side < 0 else "R"
    trouser = cube("TrouserLeg" + label, (0.145 * side, -0.002, 0.445),
                   (0.105, 0.130, 0.200), DARK, "lowerleg" + suffix,
                   bevel=0.035)
    lower_group = trouser.vertex_groups.get("lowerleg" + suffix)
    upper_group = trouser.vertex_groups.new(name="upperleg" + suffix)
    for vertex in trouser.data.vertices:
        # Mesh-local z runs roughly -0.20..0.20 after scale application.
        upper_weight = max(0.0, min(1.0, (vertex.co.z + 0.05) / 0.25))
        lower_group.add([vertex.index], 1.0 - upper_weight, "REPLACE")
        upper_group.add([vertex.index], upper_weight, "REPLACE")
    sphere("Boot" + label, (0.160 * side, -0.082, 0.135),
           (0.150, 0.185, 0.105), BROWN, "foot" + suffix, 26, 16)
    sphere("Sole" + label, (0.160 * side, -0.078, 0.064),
           (0.148, 0.178, 0.013), SOLE, "foot" + suffix, 24, 8)

# One continuous curled tail. The earlier chain of round segments looked like
# stacked beads; this smooth tube matches the single-tail silhouette in both
# supplied references. Two fitted bands retain Milo's striped-cat identity.
#
# The tail was previously authored at y=0.05..0.12, but the coat body spans
# y=-0.26..0.29 and reaches x=+/-0.38, so the whole base sat *inside* the torso
# and only the far curl emerged - beside the sleeve, where it read as a second
# floating arm rather than a tail.  Anchoring it behind the coat's back face and
# starting it below the hem lets it leave the body cleanly and curl upward in
# open air, which is what makes it legible from the side and back.
# The root starts well inside the hips (y below the coat's 0.29 back face) and
# thickens there, so the tail grows out of the body instead of beginning in mid
# air beside it.  Only once it clears the hem does it sweep back and curl up.
TAIL_BACK = 0.34
curved_tube("MayorTail", [(0.00, 0.10, 0.50),
                          (0.14, 0.22, 0.47),
                          (0.32, TAIL_BACK + 0.04, 0.50),
                          (0.44, TAIL_BACK + 0.15, 0.62),
                          (0.47, TAIL_BACK + 0.17, 0.78),
                          (0.40, TAIL_BACK + 0.12, 0.92)],
            0.060, TABBY_FUR, "hips")
# The bands ride the curl's outer arc, matching the tube's own path so they read
# as fitted stripes instead of loose rings floating beside the tail.
torus("TailStripeLower", (0.455, TAIL_BACK + 0.175, 0.63), 0.061, 0.011,
      MARKING, "hips", rotation=(math.pi / 2, 0, 0))
torus("TailStripeUpper", (0.468, TAIL_BACK + 0.172, 0.78), 0.059, 0.011,
      MARKING, "hips", rotation=(math.pi / 2, 0, 0))
sphere("TailTip", (0.40, TAIL_BACK + 0.12, 0.92), (0.062, 0.062, 0.067),
       MARKING, "hips", 14, 8)

# Restore the compact approved body from the target capture.  Later concept
# experiments made the vest narrow, squared the sleeves, reduced the boots and
# pushed the hands outward; those changes are intentionally discarded here.
target_body_prefixes = (
    "MayorCoatBody", "PurpleWaistcoat", "WaistcoatFacet", "ShirtCollar",
    "WaistcoatSeam", "InlaidTailcoatFront", "MayorTie", "MayorMedallion",
    "WaistcoatButton", "MayorSleeve", "Paw", "TrouserLeg", "Boot", "Sole",
    "MayorTail", "TailStripe", "TailTip",
)
for obj in list(parts):
    if obj.name.startswith(target_body_prefixes):
        parts.remove(obj)
        bpy.data.objects.remove(obj, do_unlink=True)

cube("MayorCoatBody", (0, 0.015, 0.84), (0.42, 0.275, 0.40),
     NAVY, "chest", bevel=0.18)
panel("PurpleWaistcoat", [(-0.225, 1.07), (0.225, 1.07), (0.225, 0.68),
                           (0.078, 0.59), (-0.078, 0.59), (-0.225, 0.68)],
      -0.318, 0.025, PURPLE, "chest")
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
tube("WaistcoatSeam", [(0, -0.347, 0.66), (0, -0.347, 0.98)],
     0.008, PURPLE_DARK, "chest")
tube("TealLapelL", [(-0.10, -0.353, 1.10), (-0.19, -0.353, 1.045),
                     (-0.225, -0.348, 0.96)], 0.008, TEAL, "chest")
tube("TealLapelR", [(0.10, -0.353, 1.10), (0.19, -0.353, 1.045),
                     (0.225, -0.348, 0.96)], 0.008, TEAL, "chest")
tube("GoldCoatHem", [(-0.29, -0.260, 0.57), (0, -0.286, 0.54),
                     (0.29, -0.260, 0.57)], 0.012, GOLD, "chest")
prism("MayorTie", [(-0.055, -0.372, 1.04), (0.055, -0.372, 1.04),
                    (0.065, -0.372, 0.93), (0, -0.372, 0.855),
                    (-0.065, -0.372, 0.93)],
      [(0, 1, 2, 3, 4)], PURPLE_LIGHT, "chest")
for x in (-0.105, 0.105):
    for z in (0.72, 0.87):
        sphere("CoatButton", (x, -0.365, z), (0.038, 0.020, 0.038),
               GOLD, "chest", 16, 9)
sphere("MayorMedallion", (0, -0.386, 1.035), (0.043, 0.022, 0.050),
       GOLD, "chest", 18, 10)

for side, suffix in ((-1, ".r"), (1, ".l")):
    label = "L" if side < 0 else "R"
    sphere("MayorSleeve" + label, (0.425 * side, 0, 0.91),
           (0.120, 0.125, 0.285), NAVY, "upperarm" + suffix, 24, 15)
    torus("GoldCuff" + label, (0.440 * side, 0, 0.69), 0.090, 0.014,
          GOLD, "wrist" + suffix, rotation=(0, 0, 0))
    sphere("Paw" + label, (0.440 * side, -0.015, 0.605),
           (0.110, 0.108, 0.132), CREAM, "hand" + suffix, 24, 15)
    for line_offset in (-0.022, 0.022):
        tube("PawLine" + label,
             [(0.440 * side + line_offset, -0.125, 0.59),
              (0.440 * side + line_offset, -0.127, 0.63)],
             0.004, MARKING, "hand" + suffix)
    sphere("TrouserLeg" + label, (0.14 * side, -0.002, 0.350),
           (0.120, 0.108, 0.150), DARK, "lowerleg" + suffix, 24, 16)
    sphere("Boot" + label, (0.14 * side, -0.095, 0.140),
           (0.200, 0.225, 0.120), BROWN, "foot" + suffix, 28, 17)
    sphere("Sole" + label, (0.14 * side, -0.090, 0.058),
           (0.195, 0.210, 0.014), SOLE, "foot" + suffix, 26, 8)

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

# Faceted shading on the fur.
#
# The approved concept sheet's "realistic" quality comes from visible flat
# planes across the head, ears and tail - a deliberate low-poly crystalline
# look - not from smooth, denser surfaces.  Smooth-shading a higher-density
# mesh produces a rounder blob that moves *away* from the reference, so the fur
# is given a sharp auto-smooth angle: broad faces read flat and catch distinct
# highlights, while tight curvature still shades smoothly.
FUR_MATERIALS = {"Milo Tabby Fur", "Milo Cream Fur", "Milo White Fur"}
fur_indices = {index for index, slot in enumerate(milo.data.materials)
               if slot and slot.name in FUR_MATERIALS}
for polygon in milo.data.polygons:
    if polygon.material_index in fur_indices:
        polygon.use_smooth = False

modifier = milo.modifiers.new("VillagerRig", "ARMATURE")
modifier.object = armature
milo.parent = armature

bpy.ops.object.select_all(action="DESELECT")
milo.select_set(True)
armature.select_set(True)
bpy.context.view_layer.objects.active = armature

# Guard the export against any stray helper geometry surviving from the donor
# file.  Only Milo and his rig may ship; a loose mesh would silently reappear in
# the GLB's bounds and throw off anything that scales or grounds by bounding box.
stray = [obj.name for obj in bpy.context.scene.objects
         if obj.type == "MESH" and obj is not milo]
if stray:
    raise SystemExit(f"Refusing to export: stray meshes present {stray}")
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT),
    export_format="GLB",
    use_selection=True,
    export_animations=True,
    export_nla_strips=True,
    export_materials="EXPORT",
)
print(f"MILO_VILLAGER_BUILD: {len(milo.data.vertices)} vertices, {len(milo.data.polygons)} faces -> {OUTPUT}")
