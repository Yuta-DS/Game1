"""Sample self-intersection and fingertip-pad contact on the exported asset."""
import bpy,json
from pathlib import Path
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(OUT/'milo_fullres.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
for track in rig.animation_data.nla_tracks:track.mute=True
report=[]
samples=[(action.name,frame,side) for action in bpy.data.actions
         for frame in range(round(action.frame_range[0]),round(action.frame_range[1])+1)
         for side in ('L','R')]
for clip,frame,side in samples:
    action=next(a for a in bpy.data.actions if a.name.startswith(clip));rig.animation_data.action=action
    if action.slots:rig.animation_data.action_slot=action.slots[0]
    bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
    obj=bpy.data.objects['Milo_Articulated_Paw.'+side];ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
    coords=[tuple(ev.matrix_world@v.co) for v in me.vertices];polys=[p.vertices[:] for p in me.polygons]
    tree=BVHTree.FromPolygons(coords,polys,all_triangles=True)
    pairs=[(a,b) for a,b in tree.overlap(tree) if a<b and not set(polys[a]).intersection(polys[b])]
    sample={'clip':clip,'frame':frame,'hand':side,'nonadjacent_surface_intersections':len(pairs)}
    if pairs:
        sample['examples']=[{'faces':[a,b],'dominant_groups':[[obj.vertex_groups[max(obj.data.vertices[i].groups,key=lambda g:g.weight).group].name for i in polys[face]] for face in (a,b)]} for a,b in pairs[:4]]
    ev.to_mesh_clear()
    if clip=='Cane_Hold' and frame==0 and side=='R':
        props=[]
        for prop in bpy.data.objects:
            if prop.type!='MESH' or prop.name not in ('Cane_Shaft','Cane_Gold_Collar'):continue
            ep=prop.evaluated_get(bpy.context.evaluated_depsgraph_get());pm=ep.to_mesh()
            props.append(BVHTree.FromPolygons([tuple(ep.matrix_world@v.co) for v in pm.vertices],[p.vertices[:] for p in pm.polygons],all_triangles=True));ep.to_mesh_clear()
        gaps={}
        for stem in ('finger0','finger1','finger2','thumb'):
            name=stem+'_tip.R';inverse=rig.data.bones[name].matrix_local.inverted()
            ids=[v.index for v in obj.data.vertices if sum(g.weight for g in v.groups if obj.vertex_groups[g.group].name==name)>.8 and (inverse@v.co).z>0]
            gaps[stem]=min(prop.find_nearest(coords[i])[3] for prop in props for i in ids)
        sample['fingertip_pad_gap_m']=gaps
    report.append(sample)
(OUT/'hand_contact_verification.json').write_text(json.dumps(report,indent=2))
failures=[r for r in report if r['nonadjacent_surface_intersections']]
grip=next(r for r in report if 'fingertip_pad_gap_m' in r)
print('HAND_CONTACT_SAMPLES',json.dumps({'frames_checked':len(report),'failing_frames':len(failures),'first_failures':failures[:3],'grip':grip}),flush=True)
assert all(row['nonadjacent_surface_intersections']==0 for row in report),'Hand self-intersection in sampled pose'
assert max(grip['fingertip_pad_gap_m'].values())<.003,'A fingertip pad is not close to the cane'
