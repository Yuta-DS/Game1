"""Render Rowan's exact production villager model for visual review."""

from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "artifacts" / "town_villager_preview.png"


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(
    filepath=str(ROOT / "assets3D/characters/Rogue.glb")
)
for prop_name in ("Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"):
    prop = bpy.data.objects.get(prop_name)
    if prop is not None:
        prop.hide_render = True

bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.015))
ground = bpy.context.object
ground_material = bpy.data.materials.new("Artea Ground")
ground_material.diffuse_color = (0.12, 0.34, 0.28, 1)
ground.data.materials.append(ground_material)

bpy.ops.object.camera_add(location=(0, -7.4, 2.25))
camera = bpy.context.object
camera.data.lens = 64
look_at(camera, (0, 0, 1.05))
bpy.context.scene.camera = camera

for location, energy, size, color in (
    ((-3.5, -4.0, 6.0), 650, 4.0, (1.0, 0.83, 0.68)),
    ((4.0, -2.5, 3.6), 300, 3.0, (0.45, 0.72, 1.0)),
):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.data.energy = energy
    light.data.size = size
    light.data.color = color
    look_at(light, (0, 0, 1.0))

world = bpy.data.worlds.new("World")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.12, 0.34, 0.48, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.55

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 900
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUTPUT)
scene.view_settings.look = "AgX - Medium High Contrast"
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.render.render(write_still=True)
print(f"TOWN_VILLAGER_RENDER: wrote {OUTPUT}")
