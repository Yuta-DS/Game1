"""Build Mayor Alder's head as a standalone, modular low-poly asset.

This is intentionally separate from build_elder_cat_mayor.py.  Every visible
feature remains its own named mesh so proportions and expression can be tuned
before the approved head is attached to the production character rig.
"""

import math
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
GLB_OUTPUT = ROOT / "assets3D/characters/elder_cat_head_lowpoly.glb"
BLEND_OUTPUT = ROOT / "assets3D/characters/elder_cat_head_lowpoly.blend"

bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, roughness=0.72, metallic=0.0):
    rgb = tuple(int(color[index:index + 2], 16) / 255.0 for index in (0, 2, 4))
    value = bpy.data.materials.new(name)
    value.diffuse_color = (*rgb, 1.0)
    value.use_nodes = True
    shader = value.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return value


FUR = material("Alder Warm Silver Fur", "b09d87")
FUR_SHADOW = material("Alder Side Fur", "82766b")
FUR_LIGHT = material("Alder Cream Face Fur", "eee8dc")
EAR_PINK = material("Alder Inner Ear", "c98e80")
EYE_WHITE = material("Alder Eye White", "eee9dc", 0.48)
IRIS = material("Alder Amber Iris", "9b622b", 0.36)
PUPIL = material("Alder Pupil", "17130f", 0.28)
HIGHLIGHT = material("Alder Eye Highlight", "ffffff", 0.18)
NOSE = material("Alder Rose Nose", "c98a78", 0.52)
MOUTH = material("Alder Mouth Shadow", "4c3d38", 0.72)
GOLD = material("Alder Glasses Gold", "d5a139", 0.28, 0.55)
STRIPE = material("Alder Forehead Marking", "716a64", 0.78)


def finish(obj, name, mat, smooth=True, bevel=0.0):
    obj.name = name
    if obj.type == "MESH":
        obj.data.name = name + "Mesh"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Soft low-poly edge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    if smooth and obj.type == "MESH":
        for face in obj.data.polygons:
            face.use_smooth = True
    obj.data.materials.append(mat)
    return obj


def sphere(name, location, scale, mat, segments=16, rings=10, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, radius=1,
        location=location, rotation=rotation,
    )
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat)


def prism(name, vertices, faces, mat, bevel=0.0, smooth=False):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, smooth, bevel)


def extruded_panel(name, outline, front_y, depth, mat, bevel=0.0):
    count = len(outline)
    vertices = [(x, front_y, z) for x, z in outline]
    vertices += [(x, front_y + depth, z) for x, z in outline]
    faces = [tuple(range(count)), tuple(reversed(range(count, count * 2)))]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
    return prism(name, vertices, faces, mat, bevel)


def tapered_ear(name, side, rows, front_y, depth, mat):
    """Create a softly convex three-column cat-ear shell."""
    vertices = []
    for z, center, half_width in rows:
        center_x = center * side
        vertices.extend([
            (center_x - half_width, front_y + 0.012, z),
            (center_x, front_y - 0.020, z + 0.006),
            (center_x + half_width, front_y + 0.012, z),
        ])
    front_count = len(vertices)
    vertices.extend([(x, front_y + depth, z) for x, _, z in vertices])
    faces = []
    row_count = len(rows)
    for row in range(row_count - 1):
        for column in range(2):
            a = row * 3 + column
            b = a + 1
            c = (row + 1) * 3 + column + 1
            d = (row + 1) * 3 + column
            faces.append((a, b, c, d))
            faces.append((front_count + d, front_count + c,
                          front_count + b, front_count + a))
    # Close left/right edges, base and narrow tip.
    for column in (0, 2):
        for row in range(row_count - 1):
            a = row * 3 + column
            b = (row + 1) * 3 + column
            faces.append((a, b, front_count + b, front_count + a))
    faces.append((0, 1, 2, front_count + 2, front_count + 1, front_count))
    top = (row_count - 1) * 3
    faces.append((top, front_count + top, front_count + top + 1,
                  front_count + top + 2, top + 2, top + 1))
    return prism(name, vertices, faces, mat, 0.003, True)


def tube(name, points, radius, mat, bevel_resolution=2):
    curve = bpy.data.curves.new(name + "Curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 4
    curve.bevel_depth = radius
    curve.bevel_resolution = bevel_resolution
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, location in zip(spline.bezier_points, points):
        point.co = location
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return finish(obj, name, mat)


def torus(name, location, major, minor, mat):
    # Front of Alder faces -Y, hence the ring lies in the X/Z plane.
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor,
        major_segments=36, minor_segments=10,
        location=location, rotation=(math.pi / 2, 0, 0),
    )
    return finish(bpy.context.object, name, mat)


# 01 — Skull: broad, child-friendly fox-family proportions with a short muzzle.
sphere("Head_Skull", (0, 0.01, 1.50), (0.420, 0.325, 0.360), FUR, 24, 16)
sphere("Head_Lower_Jaw", (0, -0.315, 1.335), (0.285, 0.145, 0.165),
       FUR_LIGHT, 20, 13)

# 02 — Ears: outer wedge, inset pink plane and small inner fold.
for side, label in ((-1, "L"), (1, "R")):
    center = 0.275 * side
    tapered_ear(
        "Ear_Outer_" + label, side,
        [(1.675, 0.275, 0.145), (1.790, 0.288, 0.108),
         (1.900, 0.300, 0.058), (1.975, 0.305, 0.012)],
        -0.080, 0.130, FUR,
    )
    tapered_ear(
        "Ear_Inner_" + label, side,
        [(1.710, 0.275, 0.088), (1.790, 0.287, 0.067),
         (1.865, 0.296, 0.033), (1.910, 0.300, 0.008)],
        -0.116, 0.018, EAR_PINK,
    )
    sphere("Ear_Fold_" + label, (center - 0.050 * side, -0.126, 1.755),
           (0.036, 0.016, 0.060), FUR_SHADOW, 12, 8,
           rotation=(0, 0, -0.35 * side))

# 03 — Side tufts: three overlapping rounded leaves per cheek.  Their staggered
# height preserves the elderly cat silhouette with no saw-tooth edges.
for side, label in ((-1, "L"), (1, "R")):
    for index, (x, z, angle, scale) in enumerate((
        (0.382, 1.470, 0.22, (0.092, 0.048, 0.050)),
        (0.392, 1.385, 0.08, (0.095, 0.048, 0.047)),
        (0.378, 1.310, -0.18, (0.082, 0.046, 0.041)),
    ), 1):
        # Set behind the skull so only the softly rounded tips enter the
        # silhouette; the joins are hidden inside the head volume.
        sphere(f"Cheek_Tuft_{label}_{index}", (x * side, -0.055, z),
               scale, FUR_LIGHT, 14, 9, rotation=(0, 0, angle * side))

# 04 — Forehead marking, shaped as the reference's centered downward triangle.
extruded_panel(
    "Forehead_Marking",
    [(-0.075, 1.820), (0.075, 1.820), (0.0, 1.690)],
    -0.300, 0.014, STRIPE, 0.008,
)

# 05 — Eyes: white sclera, amber iris, dark pupil and two highlights per eye.
for side, label in ((-1, "L"), (1, "R")):
    eye_x = 0.145 * side
    sphere("Eye_Sclera_" + label, (eye_x, -0.304, 1.545),
           (0.112, 0.037, 0.138), EYE_WHITE, 22, 14)
    sphere("Eye_Iris_" + label, (eye_x, -0.343, 1.540),
           (0.071, 0.022, 0.099), IRIS, 20, 13)
    sphere("Eye_Pupil_" + label, (eye_x, -0.367, 1.542),
           (0.037, 0.012, 0.070), PUPIL, 18, 12)
    sphere("Eye_Highlight_Main_" + label,
           (eye_x - 0.019 * side, -0.380, 1.590),
           (0.014, 0.007, 0.018), HIGHLIGHT, 8, 5)
    sphere("Eye_Highlight_Soft_" + label,
           (eye_x + 0.019 * side, -0.379, 1.505),
           (0.007, 0.005, 0.009), HIGHLIGHT, 7, 4)

# 06 — Elder brows: asymmetric soft arches, raised toward the center.
for side, label in ((-1, "L"), (1, "R")):
    tube(
        "Eyebrow_" + label,
        [(0.055 * side, -0.359, 1.704),
         (0.130 * side, -0.365, 1.740),
         (0.220 * side, -0.345, 1.707)],
        0.027, FUR_LIGHT, 3,
    )

# 07 — Glasses: independent rims, bridge and side arms.
for side, label in ((-1, "L"), (1, "R")):
    torus("Glasses_Rim_" + label, (0.145 * side, -0.392, 1.545), 0.126, 0.014, GOLD)
    tube(
        "Glasses_Arm_" + label,
        [(0.270 * side, -0.390, 1.557), (0.365 * side, -0.330, 1.558),
         (0.415 * side, -0.235, 1.555)],
        0.010, GOLD,
    )
tube("Glasses_Bridge", [(-0.020, -0.402, 1.558), (0, -0.420, 1.572),
                         (0.020, -0.402, 1.558)], 0.012, GOLD)

# 08 — Muzzle and nose: two cream pads, triangular rose nose and mouth seam.
for side, label in ((-1, "L"), (1, "R")):
    sphere("Muzzle_Pad_" + label, (0.092 * side, -0.370, 1.385),
           (0.128, 0.052, 0.087), FUR_LIGHT, 14, 9,
           rotation=(0, 0, 0.12 * side))
extruded_panel(
    "Nose",
    [(-0.052, 1.425), (0.052, 1.425), (0.037, 1.385),
     (0.0, 1.362), (-0.037, 1.385)],
    -0.482, 0.035, NOSE, 0.013,
)
tube("Mouth_Center", [(0, -0.414, 1.355), (0, -0.414, 1.318)], 0.008, MOUTH)

# 09 — White moustache: one continuous curved mesh per side.  The four control
# points create the soft dip and lifted professor curl without visible seams.
for side, label in ((-1, "L"), (1, "R")):
    moustache = tube(
        "Moustache_" + label,
        [(0.018 * side, -0.459, 1.355),
         (0.105 * side, -0.459, 1.323),
         (0.205 * side, -0.457, 1.318),
         (0.300 * side, -0.452, 1.370)],
        0.055, FUR_LIGHT, 4,
    )
    # Flatten only the front/back axis for the broad carved-fur profile.
    for vertex in moustache.data.vertices:
        vertex.co.y = -0.456 + (vertex.co.y + 0.456) * 0.72

# Store component groups as custom metadata for Godot/Blender inspection.
bpy.context.scene["asset_role"] = "Mayor Alder modular head study"
bpy.context.scene["component_order"] = (
    "skull, ears, cheek tufts, forehead marking, eyes, brows, glasses, "
    "muzzle, nose, moustache, neck"
)

GLB_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUTPUT))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=str(GLB_OUTPUT), export_format="GLB", use_selection=True,
    export_animations=False, export_materials="EXPORT",
)
print(f"ELDER_CAT_HEAD_BUILD: wrote {GLB_OUTPUT}")
print(f"ELDER_CAT_HEAD_BUILD: wrote {BLEND_OUTPUT}")
