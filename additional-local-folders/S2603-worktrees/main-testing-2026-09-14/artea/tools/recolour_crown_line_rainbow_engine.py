"""Apply the approved gold-layout/rainbow-engine palette to the source Blend."""

import math
import os

import bpy
from mathutils import Vector


PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND_PATH = os.path.join(
    PROJECT_DIR, "assets3D", "crown_line_train", "crown_line_lego_train.blend"
)
RENDER_PATH = os.path.join(
    PROJECT_DIR, "artifacts", "blender_crown_train_rainbow_gold_engine.png"
)


def flat_material(name, colour, metallic=.10, roughness=.32, emission=None):
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.diffuse_color = (*colour, 1.0)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = .85
    return material


palette = {
    "red": flat_material("Engine_Rainbow_Red", (1.00, .12, .24)),
    "orange": flat_material("Engine_Rainbow_Orange", (1.00, .38, .06)),
    "yellow": flat_material("Engine_Rainbow_Yellow", (1.00, .82, .08), .08, .34),
    "green": flat_material("Engine_Rainbow_Green", (.12, .82, .34), .08),
    "blue": flat_material("Engine_Rainbow_Blue", (.06, .32, 1.00), .12, .27,
                          (.02, .18, 1.00)),
    "indigo": flat_material("Engine_Rainbow_Indigo", (.22, .12, .72)),
    "violet": flat_material("Engine_Rainbow_Violet", (.72, .20, 1.00), .08, .28,
                            (.48, .05, 1.00)),
    "white": flat_material("Engine_Tank_PearlWhite", (.985, .965, .900), .08, .24,
                           (.78, .74, .62)),
}
accent_gold = bpy.data.materials.get("Crown_AccentGold")


def assign(obj, material):
    if obj.type != "MESH":
        return
    obj.data.materials.clear()
    obj.data.materials.append(material)


exact_colours = {
    "TRAIN_Engine_UnderframeNavy": "indigo",
    "TRAIN_Engine_SideSillNavy_-1": "red",
    "TRAIN_Engine_SideSillNavy_+1": "violet",
    "TRAIN_Engine_CabRoofShell": "violet",
    "TRAIN_Engine_CabBeltArmour_-1": "green",
    "TRAIN_Engine_CabBeltArmour_+1": "blue",
    "TRAIN_Engine_SteamBoilerBarrel": "white",
    "TRAIN_Engine_SteamPressureOrb_0": "blue",
    "TRAIN_Engine_SteamPressureOrb_1": "violet",
}
for object_name, colour_name in exact_colours.items():
    obj = bpy.data.objects.get(object_name)
    if obj is not None:
        assign(obj, palette[colour_name])

rainbow_order = ("red", "orange", "yellow", "green", "blue", "indigo", "violet")
for obj in bpy.data.objects:
    if "TRAIN_Engine_ReactorCoolingFin_" in obj.name:
        assign(obj, palette[rainbow_order[int(obj.name.rsplit("_", 1)[-1]) % 7]])
    elif "TRAIN_Engine_SteamBoilerRainbowRivet_" in obj.name:
        assign(obj, palette[rainbow_order[int(obj.name.rsplit("_", 1)[-1]) % 7]])
    elif accent_gold is not None and any(token in obj.name for token in (
            "TRAIN_Engine_SteamBoilerGoldBand_", "TRAIN_Engine_SteamChimneyCrown_",
            "TRAIN_Engine_SteamGearHub_", "TRAIN_Engine_SteamConnectingRod_",
            "TRAIN_Engine_ChassisGold", "TRAIN_Engine_SideSillGold_",
            "TRAIN_Engine_CabRoofGoldBlade", "TRAIN_Engine_CabBeltGoldRail_")):
        assign(obj, accent_gold)

bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)

# Render a focused proof without altering the game camera or scene setup.
scene = bpy.context.scene
camera = scene.camera
camera.location = (17.0, -35.0, 13.0)
direction = Vector((0.0, -22.5, 3.8)) - camera.location
camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 62.0
scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.filepath = RENDER_PATH
bpy.ops.render.render(write_still=True)
print("CROWN_LINE_RAINBOW_ENGINE_RECOLOUR: PASS render=%s" % RENDER_PATH)
