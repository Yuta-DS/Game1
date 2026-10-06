"""Sample distal palm/cuff intersections, excluding only the buried wrist."""
import bpy,json,hashlib
from pathlib import Path
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'milo_fullres.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
for track in rig.animation_data.nla_tracks:track.mute=True
hands={};cuffs={}
for side in ('L','R'):
    obj=bpy.data.objects['Milo_Articulated_Paw.'+side]
    inv=rig.data.bones['hand.'+side].matrix_local.inverted()
    ids={v.index for v in obj.data.vertices if (inv@v.co).y>.025}
    hands[side]=(obj,[p.vertices[:] for p in obj.data.polygons if all(i in ids for i in p.vertices)])
    sign=1 if side=='L' else -1
    cuffs[side]=[o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith(('Milo_Broad_Cuff','Milo_Cuff_','Milo_Linen_Cuff')) and sum(v.co.x for v in o.data.vertices)*sign>0]
report=[]
for action in list(bpy.data.actions):
    rig.animation_data.action=action
    if action.slots:rig.animation_data.action_slot=action.slots[0]
    for fraction in (0,.25,.5,.75,1):
        frame=round(action.frame_range[0]+(action.frame_range[1]-action.frame_range[0])*fraction)
        bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
        dg=bpy.context.evaluated_depsgraph_get()
        for side,(obj,polys) in hands.items():
            ev=obj.evaluated_get(dg);me=ev.to_mesh()
            tree=BVHTree.FromPolygons([tuple(ev.matrix_world@v.co) for v in me.vertices],polys,all_triangles=True)
            ev.to_mesh_clear();count=0;names=[]
            for cuff in cuffs[side]:
                ce=cuff.evaluated_get(dg);cm=ce.to_mesh()
                ct=BVHTree.FromPolygons([tuple(ce.matrix_world@v.co) for v in cm.vertices],[p.vertices[:] for p in cm.polygons],all_triangles=True)
                pairs=tree.overlap(ct)
                if pairs:names.append(cuff.name);count+=len(pairs)
                ce.to_mesh_clear()
            report.append({'clip':action.name,'frame':frame,'side':side,'intersections':count,'cuffs':names})
result={'sha256':hashlib.sha256((OUT/'milo_fullres.glb').read_bytes()).hexdigest(),'samples':report,'scope':'Five frames per clip per hand; palm/finger region beyond 25mm from wrist joint only. Buried wrist attachment is intentionally excluded.','passed':not any(r['intersections'] for r in report)}
(OUT/'cuff_clearance_verification.json').write_text(json.dumps(result,indent=2))
print('CUFF_CLEARANCE',json.dumps({'passed':result['passed'],'samples':len(report),'failures':[r for r in report if r['intersections']]}),flush=True)
assert result['passed'],'Cuff cuts into distal palm/fingers'
