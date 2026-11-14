"""One-time normal-only refresh of the derived GLB; master geometry unchanged.
The full bake script applies the same rule on subsequent rebuilds.
"""
import json
from pathlib import Path
import bpy

root = Path(__file__).resolve().parents[2]
out = root / "assets3D/mind_spark/celestial_land_runtime"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(out / "celestial_land.glb"))
objects = [o for o in bpy.data.objects if o.type == "MESH"]
deck = next(o for o in objects if o.name == "CelestialIvoryDeck")
# Clear imported split normals so flat flags are actually exported.
if deck.data.has_custom_normals:
    bpy.context.view_layer.objects.active = deck
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
for face in deck.data.polygons:
    if face.normal.z > 0.9:
        face.use_smooth = False
deck.data.update()
bpy.ops.object.select_all(action="DESELECT")
for obj in objects:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(out / "celestial_land.glb"), export_format="GLB",
    use_selection=True, export_extras=True, export_cameras=False, export_lights=False)
manifest = json.loads((out / "build_manifest.json").read_text())
manifest["glb_bytes"] = (out / "celestial_land.glb").stat().st_size
(out / "build_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
