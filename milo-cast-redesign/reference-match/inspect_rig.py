import bpy,bmesh,json
from pathlib import Path
r=bpy.data.objects['Milo_Cast_Rig'];b=r.pose.bones['head']
print('RIG_MATRIX',r.matrix_world,flush=True)
print('HEAD_DEFORM',b.matrix@b.bone.matrix_local.inverted(),flush=True)
o=bpy.data.objects['Milo_Reference_Head']
print('HEAD_BOUNDS',[(min(v.co[i] for v in o.data.vertices),max(v.co[i] for v in o.data.vertices)) for i in range(3)],flush=True)
print('HEAD_MATERIALS',[m.name for m in o.data.materials],flush=True)
checks=[]
for o in bpy.data.objects:
    if o.name.startswith('Milo_Reference_Paw'):
        bm=bmesh.new();bm.from_mesh(o.data)
        bad=sum(not e.is_manifold for e in bm.edges)
        checks.append({'mesh':o.name,'vertices':len(o.data.vertices),'nonmanifold_edges':bad})
        print('PAW',o.name,len(o.data.vertices),bad,flush=True);bm.free()
(Path(__file__).resolve().parent/'paw_topology.json').write_text(json.dumps({'checks':checks,'passed':all(c['nonmanifold_edges']==0 for c in checks),'limits':'Paw topology only; not a full-model manifold audit'},indent=2))
