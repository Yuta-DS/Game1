"""Render Mayor Alder's standalone finished moustache."""

from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "assets3D/characters/elder_cat_moustache_final.glb"
OUTPUT = ROOT / "artifacts/elder_cat_moustache_final_preview.png"


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(MODEL))

bpy.ops.mesh.primitive_plane_add(size=4, location=(0, 0.12, -0.125))
ground = bpy.context.object
ground_material = bpy.data.materials.new("Preview Ground")
ground_material.diffuse_color = (0.015, 0.055, 0.085, 1)
ground_material.use_nodes = True
ground_shader = ground_material.node_tree.nodes.get("Principled BSDF")
ground_shader.inputs["Base Color"].default_value = (0.015, 0.055, 0.085, 1)
ground_shader.inputs["Roughness"].default_value = 0.88
ground.data.materials.append(ground_material)

bpy.ops.object.camera_add(location=(0, -2.65, 0.025))
camera = bpy.context.object
camera.data.lens = 78
look_at(camera, (0, 0, 0.005))
bpy.context.scene.camera = camera

for location, energy, size, color in (
    ((-2.2, -2.5, 2.8), 430, 2.2, (1.0, 0.86, 0.72)),
    ((2.4, -1.2, 1.7), 230, 1.8, (0.55, 0.75, 1.0)),
):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.data.energy = energy
    light.data.size = size
    light.data.color = color
    look_at(light, (0, 0, 0))

world = bpy.data.worlds.new("Moustache Preview World")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.012, 0.050, 0.080, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.38

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1100
scene.render.resolution_y = 480
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUTPUT)
scene.view_settings.look = "AgX - Medium High Contrast"
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.render.render(write_still=True)
print(f"ELDER_CAT_MOUSTACHE_RENDER: wrote {OUTPUT}")
