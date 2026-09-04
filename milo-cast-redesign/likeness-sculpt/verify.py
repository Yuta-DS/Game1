"""Structural check only: explicitly not a likeness, rig or production-quality pass."""
import bpy,bmesh,json,math,struct,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent
data=(OUT/'milo_likeness.glb').read_bytes();n=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+n])
assert data[:4]==b'glTF' and struct.unpack_from('<I',data,8)[0]==len(data)
external=[r.get('uri') for k in ('buffers','images') for r in doc.get(k,[]) if r.get('uri')]
assert not external,'External model resource'
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(OUT/'milo_likeness.glb'))
meshes=[o for o in bpy.data.objects if o.type=='MESH'];nonfinite=0;checks=[];triangles=0
for o in meshes:
    nonfinite+=sum(not all(math.isfinite(x) for x in v.co) for v in o.data.vertices)
    triangles+=sum(len(p.vertices)-2 for p in o.data.polygons)
    if o.name.startswith(('Milo_Sculpt_Head','Milo_Sculpt_Connected_Muzzle','Milo_Sculpt_Paw')):
        bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
        checks.append({'name':o.name,'vertices':len(bm.verts),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges)});bm.free()
result={'self_contained':not external,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'meshes':len(meshes),'triangles':triangles,'non_finite_vertices':nonfinite,'rigged':bool(doc.get('skins')),'animations':len(doc.get('animations',[])),'sculpt_shells':checks,'limits':'Static local study only. Likeness requires image review and user approval. No rig, animation, gameplay or complete manifold certification.'}
(OUT/'verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2),flush=True)
assert nonfinite==0
