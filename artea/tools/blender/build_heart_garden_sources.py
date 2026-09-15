"""Import the deterministically exported game kit into editable Blender sources.

Run after tools/bake_heart_garden_kit.gd using Blender --background --python.
No downloads, modifiers, remeshing, or destructive source replacement.
"""
from pathlib import Path
import bpy

root = Path(__file__).resolve().parents[2] / "assets3D/heart_melody/island_one"
destination = root / "source"
destination.mkdir(parents=True, exist_ok=True)
for glb in sorted((root / "glb").glob("*.glb")):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    bpy.context.scene.unit_settings.system = "METRIC"
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            for polygon in obj.data.polygons:
                polygon.use_smooth = False
    bpy.ops.wm.save_as_mainfile(filepath=str(destination / (glb.stem + ".blend")))
    print("HEART_BLENDER_SOURCE", glb.stem)
