"""Render the former sign-side Milo so its rig and finish can be evaluated."""

from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "meshy ai/Milo_Animations.glb"))
for obj in bpy.context.scene.objects:
    obj.hide_render = obj.name != "char1" and obj.type in {"MESH", "LIGHT", "CAMERA"}
bpy.ops.object.camera_add(location=(1.15, -2.15, 0.92))
camera = bpy.context.object
camera.data.lens = 62
look_at(camera, (0.0, 0.0, 0.34))
bpy.context.scene.camera = camera
for location, energy, size, color in (
    ((-2, -2, 3), 500, 3.0, (1.0, 0.82, 0.68)),
    ((2, -1, 2), 250, 2.0, (0.4, 0.7, 1.0)),
):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.data.energy = energy
    light.data.size = size
    light.data.color = color
    look_at(light, (0, 0, 0.34))
world = bpy.context.scene.world or bpy.data.worlds.new("World")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.006, 0.018, 0.03, 1)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 700
scene.render.resolution_y = 700
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(ROOT / "artifacts/old_milo_reference.png")
scene.view_settings.look = "AgX - Medium High Contrast"
bpy.ops.render.render(write_still=True)
