"""Sample exported clips for finite skinning and cane/ground contact."""
from pathlib import Path
import bpy,json,math
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(OUT/'milo_cast.glb'))
scene=bpy.context.scene;rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');ad=rig.animation_data
meshes=[o for o in bpy.data.objects if o.type=='MESH' and len(o.data.materials)]
report={}
for tr in ad.nla_tracks:tr.mute=True
for tr in ad.nla_tracks:
    strip=tr.strips[0];ad.action=strip.action;ad.action_slot=strip.action_slot;end=strip.action.frame_range[1]
    lowest=1e9;stafflow=1e9;staffhigh=-1e9;bad=0;samples=[]
    for frame in [end*i/24 for i in range(25)]:
        scene.frame_set(int(frame),subframe=frame%1);dg=bpy.context.evaluated_depsgraph_get();cane=[];foot=[]
        for o in meshes:
            e=o.evaluated_get(dg);m=e.to_mesh()
            for v in m.vertices:
                p=e.matrix_world@v.co;bad+=not all(math.isfinite(x) for x in p);lowest=min(lowest,p.z)
                if 'Head' in o.name and any(o.vertex_groups[g.group].name=='hand.r' and g.weight>.9 for g in o.data.vertices[v.index].groups):cane.append(p)
                if 'Leg' in o.name:foot.append(p)
            e.to_mesh_clear()
        stafflow=min(stafflow,min(p.z for p in cane));staffhigh=max(staffhigh,min(p.z for p in cane));samples.append({'frame':round(frame,3),'cane_tip_z':round(min(p.z for p in cane),4),'feet_min_z':round(min(p.z for p in foot),4)})
    report[tr.name]={'duration':end/scene.render.fps,'non_finite_vertices':bad,'minimum_z':lowest,'cane_tip_z_range':[stafflow,staffhigh],'samples':samples}
(OUT/'motion_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:{kk:vv for kk,vv in v.items() if kk!='samples'} for k,v in report.items()},indent=2))
