"""Build Mayor Alder's standalone sculpted professor moustache.

The asset contains exactly two smooth meshes: a left half and a right half.
Each uses a rounded Bezier silhouette matching the supplied reference.
"""

import math
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
GLB_OUTPUT = ROOT / "assets3D/characters/elder_cat_moustache_final.glb"
BLEND_OUTPUT = ROOT / "assets3D/characters/elder_cat_moustache_final.blend"

bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, roughness=0.72):
    rgb = tuple(int(color[index:index + 2], 16) / 255.0 for index in (0, 2, 4))
    value = bpy.data.materials.new(name)
    value.diffuse_color = (*rgb, 1)
    value.use_nodes = True
    shader = value.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Roughness"].default_value = roughness
    return value


IVORY = material("Alder Moustache Warm Cream", "d9c5a7", 0.76)


def sculpted_half(name, side):
    """Make a rounded leaf-shaped half from a cyclic Bezier silhouette."""
    # Ordered clockwise: centre crown -> upper sweep -> lifted point -> lower
    # belly -> centre root. Auto handles turn these landmarks into one clean
    # flowing contour while retaining the exact reference proportions.
    outline = [
        (0.006, 0.018), (0.030, 0.070), (0.075, 0.086),
        (0.125, 0.068), (0.180, 0.030), (0.235, 0.010),
        (0.285, 0.024), (0.325, 0.047), (0.350, 0.060),
        (0.338, 0.018), (0.310, -0.014), (0.270, -0.047),
        (0.215, -0.074), (0.155, -0.084), (0.095, -0.070),
        (0.045, -0.038),
    ]
    curve = bpy.data.curves.new(name + "Curve", "CURVE")
    curve.dimensions = "2D"
    # Moderate resolution keeps broad low-poly planes in the actual shape,
    # while smooth normals prevent jagged silhouette edges.
    curve.resolution_u = 5
    curve.resolution_v = 2
    curve.fill_mode = "BOTH"
    curve.extrude = 0.026
    curve.bevel_depth = 0.010
    curve.bevel_resolution = 3
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(outline) - 1)
    for point, (x, z) in zip(spline.bezier_points, outline):
        point.co = (x * side, z, 0)
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    spline.use_cyclic_u = True
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(IVORY)
    # Rotate the filled XY silhouette into the character's X/Z face plane;
    # curve extrusion becomes a shallow front/back sculpted depth.
    obj.rotation_euler.x = math.pi / 2
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.name = name + "Mesh"
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


for side, label in ((-1, "L"), (1, "R")):
    sculpted_half("Moustache_" + label, side)

bpy.context.scene["asset_role"] = "Mayor Alder final sculpted moustache"
bpy.context.scene["attachment_note"] = "Parent the two moustache halves to the head bone"

GLB_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUTPUT))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=str(GLB_OUTPUT), export_format="GLB", use_selection=True,
    export_animations=False, export_materials="EXPORT",
)
print(f"ELDER_CAT_MOUSTACHE_BUILD: wrote {GLB_OUTPUT}")
print(f"ELDER_CAT_MOUSTACHE_BUILD: wrote {BLEND_OUTPUT}")
