"""Small grip-only diagnostic on the actual exported asset."""
import bpy,numpy as np,json,sys
from mathutils.bvhtree import BVHTree
from pathlib import Path
OUT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(OUT/'milo_fullres.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.animation_data.action=None
for tr in rig.animation_data.nla_tracks:tr.mute=True
o=bpy.data.objects['Milo_Articulated_Paw.R']
def points(evaluated=False):
    obj=o.evaluated_get(bpy.context.evaluated_depsgraph_get()) if evaluated else o
    me=obj.to_mesh() if evaluated else obj.data
    a=np.array([tuple(obj.matrix_world@v.co) for v in me.vertices])
    if evaluated:obj.to_mesh_clear()
    return a
original=points();edges=np.array([e.vertices[:] for e in o.data.edges])
act=next(a for a in bpy.data.actions if a.name.startswith('Cane_Hold'));rig.animation_data.action=act
if act.slots:rig.animation_data.action_slot=act.slots[0]
bpy.context.scene.frame_set(1);bpy.context.view_layer.update();posed=points(True)
if '--fit-grip-yaw' in sys.argv:
    hand=BVHTree.FromPolygons(posed.tolist(),[p.vertices[:] for p in o.data.polygons],all_triangles=True)
    pivot=np.array(tuple(rig.pose.bones['cane'].head))
    rotation=np.diag([-1.,-1.,1.])
    accessories=[]
    for obj in bpy.data.objects:
        if not obj.name.startswith('Cane_') or obj.type!='MESH':continue
        ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
        coords=np.array([tuple(ev.matrix_world@v.co) for v in me.vertices])
        accessories.append((obj.name,(coords-pivot)@rotation.T+pivot,[p.vertices[:] for p in me.polygons]));ev.to_mesh_clear()
    digit_points={}
    for stem in ('finger0','finger1','finger2','thumb'):
        names={stem+'.R',stem+'_tip.R'}
        ids=[v.index for v in o.data.vertices if sum(g.weight for g in v.groups if o.vertex_groups[g.group].name in names)>.80]
        digit_points[stem]=posed[ids]
    candidates=[]
    for dx in np.arange(-.024,.0141,.002):
        for dy in np.arange(-.060,.0081,.002):
            shift=np.array([dx,dy,0]);overlaps={}
            for name,coords,polys in accessories:
                tree=BVHTree.FromPolygons((coords+shift).tolist(),polys,all_triangles=True)
                overlaps[name]=len(hand.overlap(tree))
            gaps={name:float(np.linalg.norm(a[:,:2]-(pivot+shift)[:2],axis=1).min()-.014) for name,a in digit_points.items()}
            candidates.append({'dx':round(float(dx),5),'dy':round(float(dy),5),'pairs':sum(overlaps.values()),'parts':overlaps,'approx_shaft_gaps':gaps,'contact_cost':sum(abs(v-.001) for v in gaps.values())})
    candidates.sort(key=lambda c:(c['pairs'],c['contact_cost']))
    print('NATURAL_GRIP_FIT',json.dumps(candidates[:12]),flush=True)
    (OUT/'natural_grip_fit.json').write_text(json.dumps(candidates[:12],indent=2))
if '--fit-cane' in sys.argv:
    hand=BVHTree.FromPolygons(posed.tolist(),[p.vertices[:] for p in o.data.polygons],all_triangles=True)
    accessories=[]
    for obj in bpy.data.objects:
        if not obj.name.startswith('Cane_') or obj.type!='MESH':continue
        ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
        coords=np.array([tuple(ev.matrix_world@v.co) for v in me.vertices]);polys=[p.vertices[:] for p in me.polygons]
        accessories.append((obj.name,coords,polys));ev.to_mesh_clear()
    candidates=[]
    for dx in np.arange(-.020,.0201,.002):
        for dy in np.arange(-.030,.0301,.002):
            overlaps={}
            for name,coords,polys in accessories:
                tree=BVHTree.FromPolygons((coords+np.array([dx,dy,0])).tolist(),polys,all_triangles=True)
                overlaps[name]=len(hand.overlap(tree))
            candidates.append({'dx':round(float(dx),5),'dy':round(float(dy),5),'pairs':sum(overlaps.values()),'parts':overlaps})
    candidates.sort(key=lambda c:(c['pairs'],c['dx']**2+c['dy']**2))
    print('CANE_FIT',json.dumps(candidates[:12]),flush=True)
    (OUT/'cane_contact_fit.json').write_text(json.dumps(candidates[:12],indent=2))
lengths=np.linalg.norm(original[edges[:,0]]-original[edges[:,1]],axis=1)
ratio=np.linalg.norm(posed[edges[:,0]]-posed[edges[:,1]],axis=1)/np.maximum(lengths,1e-10)
for i in np.argsort(ratio)[-6:]:
    pair=edges[i]
    print('EDGE',float(ratio[i]),'length',float(lengths[i]),'rest',original[pair].tolist(),'posed',posed[pair].tolist(),'weights',[[[o.vertex_groups[g.group].name,round(g.weight,3)] for g in o.data.vertices[j].groups] for j in pair])
for name in ('hand.R','finger0.R','finger0_tip.R','finger1.R','finger1_tip.R','finger2.R','finger2_tip.R','thumb.R','thumb_tip.R'):
    pb=rig.pose.bones[name];print('BONE',name,'head',tuple(pb.head),'tail',tuple(pb.tail))
for k in range(3):
    names={f'finger{k}.R',f'finger{k}_tip.R'}
    indices=[v.index for v in o.data.vertices if sum(g.weight for g in v.groups if o.vertex_groups[g.group].name in names)>.8]
    shaft=rig.pose.bones['cane'].head
    a=posed[indices];radial=np.linalg.norm(a[:,:2]-np.array([shaft.x,shaft.y]),axis=1)
    print('DIGIT',k,'cane radial min',float(radial.min()),'bounds',a.min(0).tolist(),a.max(0).tolist())
