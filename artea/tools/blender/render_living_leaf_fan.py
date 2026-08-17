"""Render a focused inspection image of the reference Living Leaf Fan."""

import os

import bpy
from mathutils import Vector


PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLEND_PATH = os.path.join(PROJECT_ROOT, "assets3D", "tree_of_life", "leaves",
                          "source", "artea_leaf_library.blend")
OUTPUT_PATH = os.path.join(PROJECT_ROOT, "artifacts", "tree_of_life_leaves",
                           "living_leaf_fan_blender.png")


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)
    living = bpy.data.objects.get("LivingLeafFan")
    if living is None:
        raise RuntimeError("LivingLeafFan root is missing")
    living.location = (-1.3, -0.4, 0)
    for root_name in ("MagicRuneLeaf", "SolarGlassScienceLeaf", "EmeraldSensorLeaf"):
        root = bpy.data.objects.get(root_name)
        if root:
            root.hide_render = True
            pending = list(root.children)
            while pending:
                child = pending.pop()
                child.hide_render = True
                pending.extend(child.children)

    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = OUTPUT_PATH
    scene.world = bpy.data.worlds.new("LivingFanPreviewWorld")
    scene.world.color = (0.002, 0.008, 0.025)

    material = bpy.data.materials.new("LivingFanPreviewBackground")
    material.use_nodes = True
    bsdf = material.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.002, 0.012, 0.035, 1)
    bsdf.inputs["Emission Color"].default_value = (0.002, 0.012, 0.035, 1)
    bsdf.inputs["Emission Strength"].default_value = 1.0
    bpy.ops.mesh.primitive_plane_add(size=20, location=(1.3, 1.3, -0.5))
    bpy.context.object.data.materials.append(material)

    camera_data = bpy.data.cameras.new("LivingFanPreviewCamera")
    camera = bpy.data.objects.new("LivingFanPreviewCamera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (1.2, 1.2, 14)
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 9.0
    look_at(camera, (1.2, 1.2, 0))
    scene.camera = camera

    light_data = bpy.data.lights.new("LivingFanPreviewKey", 'AREA')
    light_data.energy = 520
    light_data.size = 7.0
    light = bpy.data.objects.new("LivingFanPreviewKey", light_data)
    scene.collection.objects.link(light)
    light.location = (1.2, 1.2, 8)
    look_at(light, (1.2, 1.2, 0))

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print(f"LIVING_LEAF_FAN_RENDER: PASS — {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
