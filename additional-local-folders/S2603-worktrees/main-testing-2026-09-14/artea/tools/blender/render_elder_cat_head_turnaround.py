"""Render the isolated Mayor Alder head from four review angles."""

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "assets3D/characters/elder_cat_head_final.glb"
OUTPUT = ROOT / "artifacts/elder_cat_head_final_turnaround.png"


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


bpy.ops.wm.read_factory_settings(use_empty=True)

# Import four independent copies, each rotated around the head origin.
for index, (offset, angle) in enumerate((
    (-1.80, 0.0), (-0.60, -math.radians(38)),
    (0.60, -math.radians(90)), (1.80, math.radians(180)),
), 1):
    previous = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(MODEL))
    imported = [obj for obj in bpy.data.objects if obj not in previous]
    root = bpy.data.objects.new(f"HeadView{index:02d}", None)
    bpy.context.collection.objects.link(root)
    root.location.x = offset
    root.rotation_euler.z = angle
    for obj in imported:
        if obj.parent is None:
            obj.parent = root

bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0.20, -0.39))
ground = bpy.context.object
ground_material = bpy.data.materials.new("Turnaround Ground")
ground_material.use_nodes = True
ground_shader = ground_material.node_tree.nodes.get("Principled BSDF")
ground_shader.inputs["Base Color"].default_value = (0.012, 0.055, 0.090, 1)
ground_shader.inputs["Roughness"].default_value = 0.90
ground.data.materials.append(ground_material)

bpy.ops.object.camera_add(location=(0, -10.0, 0.10))
camera = bpy.context.object
camera.data.type = "ORTHO"
camera.data.ortho_scale = 5.25
look_at(camera, (0, 0, 0.08))
bpy.context.scene.camera = camera

for location, energy, size, color in (
    ((-4.0, -5.0, 5.5), 720, 4.0, (1.0, 0.84, 0.68)),
    ((4.5, -2.5, 3.0), 360, 3.0, (0.48, 0.72, 1.0)),
):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.data.energy = energy
    light.data.size = size
    light.data.color = color
    look_at(light, (0, 0, 0.05))

world = bpy.data.worlds.new("Alder Head Turnaround World")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.010, 0.045, 0.075, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.40

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1500
scene.render.resolution_y = 520
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUTPUT)
scene.view_settings.look = "AgX - Medium High Contrast"
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.render.render(write_still=True)
print(f"ELDER_CAT_HEAD_TURNAROUND: wrote {OUTPUT}")
