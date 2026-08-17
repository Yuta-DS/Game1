"""Refresh atlas images in the built Crown Line asset and rerender surfaces."""

import bpy
import math
import os
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSET = os.path.join(ROOT, "assets3D", "crown_line_train")
ARTIFACTS = os.path.join(ROOT, "artifacts")
BLEND = os.path.join(ASSET, "crown_line_lego_train.blend")
GLB = os.path.join(ASSET, "crown_line_lego_train.glb")

for image in bpy.data.images:
    if image.source == "FILE" and "crown_line_train/concept/maps" in image.filepath:
        image.reload()
for mat in bpy.data.materials:
    if not mat.get("authored_texture_set") or not mat.use_nodes:
        continue
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf and mat.name in {
        "Energy_Cyan", "Energy_Glass", "Crystal_Purple", "Flower_Pink",
        "Cab_Clear_Cyan_Glass",
    }:
        bsdf.inputs["Emission Strength"].default_value = .28

bpy.ops.wm.save_as_mainfile(filepath=BLEND)
bpy.ops.object.select_all(action="DESELECT")
construction = [obj for obj in bpy.data.objects if obj.name.startswith("TRAIN_")]
for obj in construction:
    obj.select_set(True)
root = bpy.data.objects.get("TRAIN_CrownLineConstructionRoot")
if root:
    bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", use_selection=True,
                          export_apply=True, export_extras=True)

camera = bpy.data.objects.get("RENDER_Camera")
scene = bpy.context.scene


def point(target):
    camera.rotation_euler = (Vector(target)-camera.location).to_track_quat("-Z", "Y").to_euler()


views = (
    ("blender_crown_train_three_quarter.png", (45,-59,34), (0,2,3.2), 50),
    ("blender_crown_train_side.png", (75,2,17), (0,2,3.0), 52),
    ("blender_crown_train_front.png", (0,-57,13), (0,-10,4.5), 55),
    ("blender_crown_train_top.png", (0,2,90), (0,2,1.5), 50),
    ("blender_crown_train_engine_exterior_detail.png", (17,-35,13), (0,-22.5,3.5), 62),
    ("blender_crown_train_bogie_rail_detail.png", (14,-18,3.4), (4.1,-17.0,-.10), 68),
)
for filename, location, target, lens in views:
    camera.location = location
    camera.data.lens = lens
    point(target)
    if filename == "blender_crown_train_top.png":
        camera.rotation_euler.rotate_axis("Z", math.pi/2)
    scene.render.filepath = os.path.join(ARTIFACTS, filename)
    bpy.ops.render.render(write_still=True)

print("CROWN_TRAIN_TEXTURE_REFRESH: PASS")
