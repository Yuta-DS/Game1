"""Derived preview below anyCreature's 64 MiB cap; never changes the master."""
import bpy,bmesh,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets3D/mind_spark/celestial_terrace_3000'
source=OUT/'source/celestial_terrace_3000.blend'
full=OUT/'celestial_terrace_3000.glb'
dest=OUT/'anycreature';dest.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source))
parts=[o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('CT3_')]
assert len(parts)==3000
before=sum(len(o.data.polygons) for o in parts)
bpy.ops.object.select_all(action='DESELECT')
for o in parts:
    if len(o.data.polygons)>96:
        mod=o.modifiers.new('DERIVED_PREVIEW_ONLY','DECIMATE');mod.ratio=.48;mod.use_collapse_triangulate=True
print('[PREVIEW] Evaluating decimation in one dependency-graph update',flush=True)
bpy.context.view_layer.update()
depsgraph=bpy.context.evaluated_depsgraph_get()
evaluated=[]
for i,o in enumerate(parts):
    if o.modifiers:
        evaluated.append((o,bpy.data.meshes.new_from_object(o.evaluated_get(depsgraph))))
    if i%500==0:print('[PREVIEW] Evaluated',i,'parts',flush=True)
for o,data in evaluated:
    o.modifiers.clear();o.data=data
for o in parts:
    bm=bmesh.new();bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(o.data);bm.free();o.data.update()
    assert o.data.polygons and all(len(p.vertices)==3 and p.area>1e-13 for p in o.data.polygons),o.name
    o['lod']='derived_plugin_preview_only';o.select_set(True)
preview=dest/'celestial_terrace_3000_preview.glb'
bpy.ops.export_scene.gltf(filepath=str(preview),export_format='GLB',use_selection=True,
                         export_extras=True,export_cameras=False,export_lights=False)
size=preview.stat().st_size
assert size<64*1024*1024,('Preview still exceeds plugin limit',size)
result={'scope':'Derived preview only; master Blender and GLB are unchanged',
        'part_count':len(parts),'master_triangles':before,'preview_triangles':sum(len(o.data.polygons) for o in parts),
        'preview_bytes':size,'plugin_limit_bytes':64*1024*1024,
        'master_glb_sha256':hashlib.sha256(full.read_bytes()).hexdigest(),
        'preview_glb_sha256':hashlib.sha256(preview.read_bytes()).hexdigest(),
        'method':'Collapse decimation ratio 0.48 only for parts with more than 96 faces; preserve all 3000 objects',
        'not_verified':['Full-detail GLB in anyCreature','Game-ready LOD quality or collision integration']}
(dest/'preview_derivation.json').write_text(json.dumps(result,indent=2))
print('[PLUGIN PREVIEW]',json.dumps(result),flush=True)
