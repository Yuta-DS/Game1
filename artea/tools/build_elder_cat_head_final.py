"""Build an isolated, production-quality Mayor Alder head turnaround asset.

This file does not alter the rigged Mayor Alder character.  The approved head
can be integrated only after its front, three-quarter, side and rear views have
been reviewed.  Every facial component remains independently named.
"""

import math
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
MOUSTACHE_SOURCE = ROOT / "assets3D/characters/elder_cat_moustache_final.glb"
GLB_OUTPUT = ROOT / "assets3D/characters/elder_cat_head_final.glb"
BLEND_OUTPUT = ROOT / "assets3D/characters/elder_cat_head_final.blend"

bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, roughness=0.72, metallic=0.0):
    rgb = tuple(int(color[index:index + 2], 16) / 255.0 for index in (0, 2, 4))
    value = bpy.data.materials.new(name)
    value.diffuse_color = (*rgb, 1)
    value.use_nodes = True
    shader = value.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return value


FUR = material("Alder Head Warm Beige", "b9a184", 0.78)
FUR_SIDE = material("Alder Head Shadow Fur", "93816e", 0.80)
CREAM = material("Alder Head Cream Fur", "dfd1ba", 0.78)
EAR_PINK = material("Alder Ear Rose", "bd7f70", 0.76)
EYE_WHITE = material("Alder Eye Ivory", "eee6d7", 0.48)
IRIS = material("Alder Amber Iris", "a86c2f", 0.34)
PUPIL = material("Alder Deep Pupil", "17130f", 0.26)
HIGHLIGHT = material("Alder Eye Highlight", "ffffff", 0.16)
NOSE = material("Alder Rose Nose", "c98c79", 0.52)
GOLD = material("Alder Glasses Gold", "d2a03b", 0.28, 0.50)
STRIPE = material("Alder Forehead Stripe", "756a60", 0.80)


def finish(obj, name, mat, smooth=True, bevel=0.0):
    obj.name = name
    if obj.type == "MESH":
        obj.data.name = name + "Mesh"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Rounded low-poly edge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    if smooth:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    obj.data.materials.append(mat)
    return obj


def sphere(name, location, scale, mat, segments=20, rings=13, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, radius=1,
        location=location, rotation=rotation,
    )
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat)


def prism(name, vertices, faces, mat, bevel=0.0, smooth=True):
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
        following = (index + 1) % count
        faces.append((index, following, count + following, count + index))
    return prism(name, vertices, faces, mat, bevel)


def tapered_ear(name, side, rows, front_y, depth, mat):
    """Create a curved three-column ear shell with a clean rear profile."""
    vertices = []
    for z, center, half_width in rows:
        center_x = center * side
        vertices.extend([
            (center_x - half_width, front_y + 0.012, z),
            (center_x, front_y - 0.024, z + 0.008),
            (center_x + half_width, front_y + 0.012, z),
        ])
    front_count = len(vertices)
    back_vertices = []
    row_count = len(rows)
    for row in range(row_count):
        # Broad ear base, progressively thin upper shell and nearly closed tip.
        row_depth = depth * (1.0 - 0.90 * row / max(1, row_count - 1))
        for column in range(3):
            x, _, z = vertices[row * 3 + column]
            back_vertices.append((x, front_y + row_depth, z))
    vertices += back_vertices
    faces = []
    for row in range(row_count - 1):
        for column in range(2):
            a = row * 3 + column
            b = a + 1
            c = (row + 1) * 3 + column + 1
            d = (row + 1) * 3 + column
            faces.extend([
                (a, b, c, d),
                (front_count + d, front_count + c,
                 front_count + b, front_count + a),
            ])
    for column in (0, 2):
        for row in range(row_count - 1):
            a = row * 3 + column
            b = (row + 1) * 3 + column
            faces.append((a, b, front_count + b, front_count + a))
    faces.append((0, 1, 2, front_count + 2, front_count + 1, front_count))
    top = (row_count - 1) * 3
    faces.append((top, front_count + top, front_count + top + 1,
                  front_count + top + 2, top + 2, top + 1))
    return prism(name, vertices, faces, mat, 0.004)


def tube(name, points, radius, mat, resolution=4, bevel_resolution=3):
    curve = bpy.data.curves.new(name + "Curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = resolution
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
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor,
        major_segments=36, minor_segments=10,
        location=location, rotation=(math.pi / 2, 0, 0),
    )
    return finish(bpy.context.object, name, mat)


# Skull and lower face establish the compact fox-family proportion.
sphere("Head_Skull", (0, 0, 0), (0.420, 0.340, 0.365), FUR, 24, 16)
sphere("Head_Cream_Chin", (0, -0.315, -0.145), (0.285, 0.145, 0.165), CREAM, 20, 13)

# Ears are readable from front, side and rear; inner ear planes are inset.
for side, label in ((-1, "L"), (1, "R")):
    tapered_ear(
        "Ear_Outer_" + label, side,
        [(0.265, 0.275, 0.145), (0.390, 0.288, 0.108),
         (0.515, 0.300, 0.058), (0.610, 0.305, 0.012)],
        -0.070, 0.145, FUR,
    )
    tapered_ear(
        "Ear_Inner_" + label, side,
        [(0.300, 0.275, 0.088), (0.392, 0.287, 0.067),
         (0.475, 0.296, 0.033), (0.535, 0.300, 0.008)],
        -0.110, 0.018, EAR_PINK,
    )
    sphere("Ear_Fold_" + label, ((0.225 * side), -0.125, 0.335),
           (0.038, 0.017, 0.064), FUR_SIDE, 12, 8,
           rotation=(0, 0, -0.32 * side))

# Cheek tufts are bevelled pointed leaves, layered into the skull so their
# roots disappear while their tapered ends remain readable from every angle.
for side, label in ((-1, "L"), (1, "R")):
    for index, (z, outer_x, height) in enumerate((
        (0.050, 0.452, 0.045),
        (-0.045, 0.462, 0.042),
        (-0.130, 0.448, 0.038),
    ), 1):
        extruded_panel(
            f"Cheek_Tuft_{label}_{index}",
            [(0.345 * side, z + height * 0.30),
             (0.400 * side, z + height),
             (outer_x * side, z),
             (0.400 * side, z - height),
             (0.345 * side, z - height * 0.30)],
            -0.100, 0.040, CREAM, 0.009,
        )

extruded_panel(
    "Forehead_Stripe", [(-0.078, 0.325), (0.078, 0.325), (0, 0.190)],
    -0.326, 0.016, STRIPE, 0.009,
)

# Large readable eyes with amber irises and double highlights.
for side, label in ((-1, "L"), (1, "R")):
    eye_x = 0.145 * side
    sphere("Eye_Sclera_" + label, (eye_x, -0.335, 0.045),
           (0.112, 0.038, 0.138), EYE_WHITE, 22, 14)
    sphere("Eye_Iris_" + label, (eye_x, -0.376, 0.040),
           (0.071, 0.023, 0.099), IRIS, 20, 13)
    sphere("Eye_Pupil_" + label, (eye_x, -0.401, 0.042),
           (0.037, 0.012, 0.070), PUPIL, 18, 12)
    sphere("Eye_Highlight_Main_" + label,
           (eye_x - 0.019 * side, -0.414, 0.090),
           (0.014, 0.007, 0.018), HIGHLIGHT, 8, 5)
    sphere("Eye_Highlight_Soft_" + label,
           (eye_x + 0.019 * side, -0.413, 0.005),
           (0.007, 0.005, 0.009), HIGHLIGHT, 7, 4)
    tube(
        "Eyebrow_" + label,
        [(0.050 * side, -0.373, 0.205),
         (0.130 * side, -0.380, 0.238),
         (0.225 * side, -0.355, 0.205)],
        0.027, CREAM,
    )

# Gold glasses include full rims, bridge and arms extending toward the ears.
for side, label in ((-1, "L"), (1, "R")):
    torus("Glasses_Rim_" + label, (0.145 * side, -0.425, 0.045), 0.126, 0.014, GOLD)
    tube(
        "Glasses_Arm_" + label,
        [(0.270 * side, -0.423, 0.055),
         (0.365 * side, -0.345, 0.058),
         (0.420 * side, -0.235, 0.055)],
        0.010, GOLD,
    )
tube("Glasses_Bridge", [(-0.020, -0.435, 0.058),
                         (0, -0.452, 0.072),
                         (0.020, -0.435, 0.058)], 0.012, GOLD)

# Muzzle pads and rounded rose nose remain visible above the moustache roots.
for side, label in ((-1, "L"), (1, "R")):
    sphere("Muzzle_Pad_" + label, (0.090 * side, -0.405, -0.115),
           (0.128, 0.052, 0.087), CREAM, 16, 10,
           rotation=(0, 0, 0.10 * side))
extruded_panel(
    "Nose", [(-0.050, -0.075), (0.050, -0.075),
             (0.036, -0.115), (0, -0.139), (-0.036, -0.115)],
    -0.475, 0.034, NOSE, 0.013,
)

# Import the approved two-object moustache and align it to the isolated head.
existing_objects = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(MOUSTACHE_SOURCE))
for obj in [value for value in bpy.data.objects
            if value not in existing_objects and value.type == "MESH"]:
    label = "L" if "_L" in obj.name else "R"
    obj.name = "Moustache_" + label
    obj.data.name = obj.name + "Mesh"
    obj.parent = None
    for vertex in obj.data.vertices:
        vertex.co.x *= 0.88
        vertex.co.y = vertex.co.y * 0.88 - 0.420
        vertex.co.z = vertex.co.z * 0.88 - 0.150

bpy.context.scene["asset_role"] = "Isolated Mayor Alder final head review"
bpy.context.scene["integration_status"] = "Not integrated into production character"

GLB_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUTPUT))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=str(GLB_OUTPUT), export_format="GLB", use_selection=True,
    export_animations=False, export_materials="EXPORT",
)
print(f"ELDER_CAT_HEAD_FINAL_BUILD: wrote {GLB_OUTPUT}")
print(f"ELDER_CAT_HEAD_FINAL_BUILD: wrote {BLEND_OUTPUT}")
