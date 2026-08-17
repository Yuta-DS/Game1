"""Render the live fox asset as a neutral visual style reference."""

from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets3D/characters/fox.glb"))

for obj in bpy.context.scene.objects:
    if obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = True

bpy.ops.object.camera_add(location=(2.4, -4.0, 2.0))
camera = bpy.context.object
camera.data.lens = 58
look_at(camera, (0, 0, 0.8))
bpy.context.scene.camera = camera

for location, energy, size, color in (
    ((-4, -4, 7), 700, 4.0, (1.0, 0.82, 0.66)),
    ((4, -2, 4), 380, 3.0, (0.45, 0.72, 1.0)),
    ((0, 4, 5), 450, 3.0, (0.60, 0.78, 1.0)),
):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.data.energy = energy
    light.data.size = size
    light.data.color = color
    look_at(light, (0, 0, 0.8))

world = bpy.context.scene.world or bpy.data.worlds.new("World")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.008, 0.02, 0.035, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.3

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 700
scene.render.resolution_y = 700
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(ROOT / "artifacts/fox_style_reference.png")
scene.view_settings.look = "AgX - Medium High Contrast"
bpy.ops.render.render(write_still=True)
