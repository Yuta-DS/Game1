"""Render the standalone Mayor Alder head prototype for approval."""

from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "assets3D/characters/elder_cat_head_lowpoly.glb"
OUTPUT = ROOT / "artifacts/elder_cat_head_lowpoly_preview.png"


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(MODEL))

bpy.ops.object.camera_add(location=(0, -4.25, 1.58))
camera = bpy.context.object
camera.data.lens = 73
look_at(camera, (0, 0, 1.56))
bpy.context.scene.camera = camera

for location, energy, size, color in (
    ((-3.0, -4.0, 5.0), 460, 3.2, (1.0, 0.84, 0.70)),
    ((3.5, -2.0, 3.0), 240, 2.8, (0.48, 0.72, 1.0)),
    ((0, 1.5, 3.5), 150, 2.5, (1.0, 0.95, 0.86)),
):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.data.energy = energy
    light.data.size = size
    light.data.color = color
    look_at(light, (0, 0, 1.52))

world = bpy.data.worlds.new("Alder Preview World")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.018, 0.075, 0.12, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.42

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 900
scene.render.resolution_y = 760
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUTPUT)
scene.render.film_transparent = False
scene.view_settings.look = "AgX - Medium High Contrast"
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.render.render(write_still=True)
print(f"ELDER_CAT_HEAD_RENDER: wrote {OUTPUT}")
