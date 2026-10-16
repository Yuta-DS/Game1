"""Build the Blender-authored look reference for Artéa's hub ocean.

The .blend is intentionally kept as an editable art source.  Its Ocean
modifier, small-scale bump and low-angle sun are mirrored by the lightweight
Godot shaders used at runtime.
"""

from pathlib import Path
import math

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "assets3D" / "environment" / "ocean" / "source"
ARTIFACT_DIR = ROOT / "artifacts" / "hub_ocean_blender"


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            datablocks.remove(datablock)


def make_ocean_material() -> bpy.types.Material:
    material = bpy.data.materials.new("Artea_Ocean_Sunlit")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    principled.inputs["Base Color"].default_value = (0.015, 0.18, 0.30, 1.0)
    principled.inputs["Metallic"].default_value = 0.08
    principled.inputs["Roughness"].default_value = 0.14
    principled.inputs["IOR"].default_value = 1.333

    texcoord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 3.8
    noise.inputs["Detail"].default_value = 5.0
    noise.inputs["Roughness"].default_value = 0.62
    noise.inputs["Distortion"].default_value = 0.18
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.28
    bump.inputs["Distance"].default_value = 0.22

    layer_weight = nodes.new("ShaderNodeLayerWeight")
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.12
    ramp.color_ramp.elements[0].color = (0.008, 0.09, 0.18, 1.0)
    ramp.color_ramp.elements[1].position = 0.88
    ramp.color_ramp.elements[1].color = (0.035, 0.34, 0.50, 1.0)

    links.new(texcoord.outputs["Generated"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], principled.inputs["Normal"])
    links.new(layer_weight.outputs["Facing"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], principled.inputs["Base Color"])
    links.new(principled.outputs["BSDF"], output.inputs["Surface"])
    return material


def add_ocean() -> bpy.types.Object:
    bpy.ops.mesh.primitive_plane_add(size=2.0, location=(0.0, 0.0, 0.0))
    ocean = bpy.context.object
    ocean.name = "Hub_Ocean_Reference"
    modifier = ocean.modifiers.new("Layered_Sea_Waves", "OCEAN")
    modifier.geometry_mode = "GENERATE"
    modifier.repeat_x = 4
    modifier.repeat_y = 4
    modifier.viewport_resolution = 10
    modifier.resolution = 14
    modifier.spatial_size = 42
    modifier.wave_scale = 0.62
    modifier.wave_scale_min = 0.18
    modifier.wind_velocity = 11.0
    modifier.choppiness = 0.75
    modifier.wave_alignment = 0.36
    modifier.wave_direction = math.radians(28.0)
    modifier.damping = 0.35
    modifier.time = 1.35
    ocean.data.materials.append(make_ocean_material())
    return ocean


def add_lighting() -> None:
    world = bpy.data.worlds.new("Artea_Clear_Coastal_Sky")
    bpy.context.scene.world = world
    world.use_nodes = True
    nodes = world.node_tree.nodes
    links = world.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputWorld")
    background = nodes.new("ShaderNodeBackground")
    background.inputs["Color"].default_value = (0.055, 0.26, 0.52, 1.0)
    background.inputs["Strength"].default_value = 0.22
    links.new(background.outputs["Background"], output.inputs["Surface"])

    sun_data = bpy.data.lights.new("Warm_Low_Sun", "SUN")
    sun_data.energy = 1.7
    sun_data.color = (1.0, 0.72, 0.42)
    sun_data.angle = math.radians(1.4)
    sun = bpy.data.objects.new("Warm_Low_Sun", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.location = (-8.0, 42.0, 25.0)
    sun.rotation_euler = ((Vector((0.0, 0.0, 0.0)) - sun.location)
                          .to_track_quat("-Z", "Y").to_euler())

    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=3.2,
                                         location=(-8.0, 68.0, 24.0))
    sun_disc = bpy.context.object
    sun_disc.name = "Visible_Sun_Disc"
    disc_material = bpy.data.materials.new("Visible_Sun_Glow")
    disc_material.use_nodes = True
    disc_nodes = disc_material.node_tree.nodes
    disc_links = disc_material.node_tree.links
    disc_nodes.clear()
    disc_output = disc_nodes.new("ShaderNodeOutputMaterial")
    emission = disc_nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (1.0, 0.38, 0.08, 1.0)
    emission.inputs["Strength"].default_value = 4.0
    disc_links.new(emission.outputs["Emission"], disc_output.inputs["Surface"])
    sun_disc.data.materials.append(disc_material)


def add_camera() -> None:
    camera_data = bpy.data.cameras.new("Ocean_Lookdev_Camera")
    camera = bpy.data.objects.new("Ocean_Lookdev_Camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (18.0, -31.0, 8.5)
    camera.data.lens = 46.0
    camera.data.sensor_width = 36.0
    target = bpy.data.objects.new("Ocean_Camera_Target", None)
    target.location = (1.0, 8.0, 0.0)
    bpy.context.collection.objects.link(target)
    constraint = camera.constraints.new(type="TRACK_TO")
    constraint.target = target
    constraint.track_axis = "TRACK_NEGATIVE_Z"
    constraint.up_axis = "UP_Y"
    bpy.context.scene.camera = camera


def configure_render() -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 540
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.filepath = str(ARTIFACT_DIR / "hub_ocean_sun_reflection.png")
    scene.render.image_settings.color_mode = "RGBA"


def main() -> None:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    reset_scene()
    add_ocean()
    add_lighting()
    add_camera()
    configure_render()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_DIR / "hub_ocean_reference.blend"))
    bpy.ops.render.render(write_still=True)
    print(f"Saved Blender ocean and preview to {SOURCE_DIR} and {ARTIFACT_DIR}")


if __name__ == "__main__":
    main()
