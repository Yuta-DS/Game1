from pathlib import Path
import bpy,json
from collections import Counter
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT.parent/'artea/assets3D/characters/Rogue.glb'))
report={}
for o in bpy.data.objects:
    if not o.name.startswith('Rogue_') or o.type!='MESH':continue
    points=[o.matrix_world@v.co for v in o.data.vertices]
    m=o.data.materials[0];img=next(n.image for n in m.node_tree.nodes if n.type=='TEX_IMAGE')
    w,h=img.size;pixels=list(img.pixels);uv=o.data.uv_layers.active.data;colors=Counter()
    for p in o.data.polygons:
        u=sum(uv[i].uv.x for i in p.loop_indices)/len(p.loop_indices);v=sum(uv[i].uv.y for i in p.loop_indices)/len(p.loop_indices)
        index=(min(h-1,int(v*h))*w+min(w-1,int(u*w)))*4
        col=tuple(round(c,3) for c in pixels[index:index+3]);colors[col]+=1
    report[o.name]={'matrix':[list(r) for r in o.matrix_world],'min':[min(v[i] for v in points) for i in range(3)],'max':[max(v[i] for v in points) for i in range(3)],'colors':[[list(c),n] for c,n in colors.most_common(20)]}
print(json.dumps(report,indent=2))
(OUT/'donor_geometry.json').write_text(json.dumps(report,indent=2))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
print('RIG_TRANSFORM',list(map(list,rig.matrix_world)))
print('ACTIONS',[(t.name, t.strips[0].action.name, list(t.strips[0].action.frame_range)) for t in rig.animation_data.nla_tracks])
