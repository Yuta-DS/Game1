"""Render the exact production Milo GLB as a face-review portrait."""

from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "artifacts" / "milo_blender_face.png"


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(
    filepath=str(ROOT / "assets3D/characters/milo_villager_lowpoly.glb")
)

# The exported character faces -Y, matching the existing Godot camera setup.
bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0.28, 0.0))
backdrop = bpy.context.object
backdrop.rotation_euler.x = 1.5708
backdrop_material = bpy.data.materials.new("Artea Navy Backdrop")
backdrop_material.diffuse_color = (0.008, 0.045, 0.080, 1.0)
backdrop_material.use_nodes = True
backdrop_material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (
    0.008, 0.045, 0.080, 1.0
)
backdrop_material.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
backdrop.data.materials.append(backdrop_material)

bpy.ops.object.camera_add(location=(0, -2.55, 1.53))
camera = bpy.context.object
camera.data.lens = 78
look_at(camera, (0, 0, 1.52))
bpy.context.scene.camera = camera

for location, energy, size, color in (
    ((-2.8, -3.0, 4.4), 440, 3.0, (1.0, 0.79, 0.62)),
    ((2.8, -2.4, 2.8), 220, 2.5, (0.42, 0.72, 1.0)),
    ((0.0, 1.0, 3.5), 130, 2.0, (0.85, 0.93, 1.0)),
):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.data.energy = energy
    light.data.size = size
    light.data.color = color
    look_at(light, (0, 0, 1.48))

world = bpy.data.worlds.new("World")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.006, 0.025, 0.05, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.35

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 900
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUTPUT)
scene.render.film_transparent = False
scene.view_settings.look = "AgX - Medium High Contrast"
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.render.render(write_still=True)
print(f"MILO_FACE_RENDER: wrote {OUTPUT}")
