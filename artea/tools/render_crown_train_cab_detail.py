import bpy
import os
from mathutils import Vector


ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ARTIFACT_DIR = os.path.join(ROOT_DIR, "artifacts")
camera = bpy.data.objects["RENDER_Camera"]
scene = bpy.context.scene
scene.camera = camera
scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100


def point_camera(target):
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()


def render_cutaway(filename, location, target, lens, hide_tokens):
    hidden = []
    for obj in bpy.data.objects:
        if any(token in obj.name for token in hide_tokens):
            obj.hide_render = True
            hidden.append(obj)
    camera.location = location
    camera.data.lens = lens
    point_camera(target)
    scene.render.filepath = os.path.join(ARTIFACT_DIR, filename)
    bpy.ops.render.render(write_still=True)
    for obj in hidden:
        obj.hide_render = False


def render_isolated(filename, location, target, lens, keep_tokens):
    hidden = []
    for obj in bpy.data.objects:
        if obj.type == "MESH" and not any(token in obj.name for token in keep_tokens):
            obj.hide_render = True
            hidden.append(obj)
    camera.location = location
    camera.data.lens = lens
    point_camera(target)
    scene.render.filepath = os.path.join(ARTIFACT_DIR, filename)
    bpy.ops.render.render(write_still=True)
    for obj in hidden:
        obj.hide_render = False


common = ("Engine_CrownCanopy", "Engine_CrownHalo", "Engine_HaloRay",
          "Engine_WindscreenGlass", "Engine_WindowGlass_R")
render_isolated(
    "blender_crown_train_etcs_dmi_frontal.png",
    (0, -12.00, 4.70), (0, -16.40, 4.26), 62,
    ("Engine_ETCS", "Engine_BrakeGauge", "Engine_SpeedMechanism"),
)
render_cutaway(
    "blender_crown_train_driver_control_wide.png",
    (6.8, -13.7, 6.4), (0, -16.65, 4.15), 58,
    common + ("Engine_CabPillar", "Engine_WindowFrame_R", "Finish_CabTactileLegend"),
)
render_isolated(
    "blender_crown_train_bogie_engineering_isolated.png",
    (10.5, -26.5, 3.4), (4.35, -21.25, -.05), 58,
    ("Engine_Bogie_Wheel", "Engine_Bogie_Tyre", "Engine_Bogie_RailFlange",
     "Engine_Bogie_Brake", "Engine_Bogie_Axle", "Engine_Bogie_EnergyHub",
     "Engine_Bogie_Suspension", "Engine_Bogie_RailGuide",
     "Engine_Bogie_TractionLink", "RENDER_Rail"),
)

print("CROWN_TRAIN_CAB_DETAIL_RENDER: PASS")
