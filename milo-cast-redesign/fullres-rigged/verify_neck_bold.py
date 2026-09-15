"""Measure moustache boldness and neck/jaw attachment in every authored frame."""
from pathlib import Path
import bpy,bmesh,json,hashlib,numpy as np
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parent
def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    rig.animation_data.action=None
    for tr in rig.animation_data.nla_tracks:tr.mute=True
    for p in rig.pose.bones:p.matrix_basis.identity()
    bpy.context.view_layer.update()
    return rig
def measure_fur():
    points=[];volume=0
    for name in ('Moustache_1','Moustache_-1'):
        o=bpy.data.objects[name];points.extend([tuple(v.co) for v in o.data.vertices])
        bm=bmesh.new();bm.from_mesh(o.data);volume+=abs(bm.calc_volume());bm.free()
    a=np.array(points)
    return {'width_m':float(np.ptp(a[:,0])),'height_m':float(np.ptp(a[:,2])),'volume_m3':volume}
load(OUT/'neck-bold-before/milo_fullres.glb');before=measure_fur()
rig=load(OUT/'milo_fullres.glb');after=measure_fur()
ratios={k:after[k]/before[k] for k in before}
assert ratios['width_m']>1.15 and ratios['volume_m3']>1.50,ratios
objects={n:bpy.data.objects[n] for n in ('Neck_Transition','Chin','Mouth','Head_Cranium_AnyCreature','Milo_Medieval_High_Collar')}
def points(o,evaluated=False):
    obj=o.evaluated_get(bpy.context.evaluated_depsgraph_get()) if evaluated else o
    m=obj.to_mesh() if evaluated else obj.data
    a=np.empty(len(m.vertices)*3);m.vertices.foreach_get('co',a);a=a.reshape(-1,3)
    matrix=np.array(obj.matrix_world);a=a@matrix[:3,:3].T+matrix[:3,3]
    if evaluated:obj.to_mesh_clear()
    return a
polys={n:[p.vertices[:] for p in o.data.polygons] for n,o in objects.items()}
def tree(n,a):return BVHTree.FromPolygons(a.tolist(),polys[n],all_triangles=True)
rest={n:points(o) for n,o in objects.items()}
topology={};edges={};lengths={}
for n in ('Neck_Transition','Chin','Mouth'):
    o=objects[n];bm=bmesh.new();bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
    bad=sum(not e.is_manifold for e in bm.edges)
    remaining=set(bm.verts);components=0
    while remaining:
        components+=1;stack=[remaining.pop()]
        while stack:
            for e in stack.pop().link_edges:
                for v in e.verts:
                    if v in remaining:remaining.remove(v);stack.append(v)
    bm.free();t=tree(n,rest[n]);face_sets=[set(p) for p in polys[n]]
    overlaps=sum(i<j and not face_sets[i]&face_sets[j] for i,j in t.overlap(t))
    topology[n]={'components':components,'nonmanifold_edges':bad,'nonadjacent_self_intersections':overlaps,
                 'bones':sorted({o.vertex_groups[g.group].name for v in o.data.vertices for g in v.groups if g.weight>1e-6})}
    assert components==1 and bad==0 and overlaps==0,(n,topology[n])
    edges[n]=np.array([e.vertices[:] for e in o.data.edges])
    lengths[n]=np.linalg.norm(rest[n][edges[n][:,0]]-rest[n][edges[n][:,1]],axis=1)
assert topology['Neck_Transition']['bones']==['chest','head','neck']
clips={};failures=[]
for track in rig.animation_data.nla_tracks:
    action=track.strips[0].action;rig.animation_data.action=action
    if action.slots:rig.animation_data.action_slot=action.slots[0]
    frames=range(round(action.frame_range[0]),round(action.frame_range[1])+1)
    max_stretch={n:1. for n in edges};minimum={n:10**9 for n in ('neck_head','neck_chin','chin_head','mouth_chin')};collar_max=0
    for f in frames:
        bpy.context.scene.frame_set(f);bpy.context.view_layer.update()
        p={n:points(o,True) for n,o in objects.items()}
        assert all(np.isfinite(a).all() for a in p.values())
        t={n:tree(n,a) for n,a in p.items()}
        for key,a,b in (('neck_head','Neck_Transition','Head_Cranium_AnyCreature'),('neck_chin','Neck_Transition','Chin'),('chin_head','Chin','Head_Cranium_AnyCreature'),('mouth_chin','Mouth','Chin')):
            count=len(t[a].overlap(t[b]));minimum[key]=min(minimum[key],count)
            if count==0:failures.append({'clip':track.name,'frame':f,'detached':key})
        collision=len(t['Neck_Transition'].overlap(t['Milo_Medieval_High_Collar']))
        collar_max=max(collar_max,collision)
        if collision:failures.append({'clip':track.name,'frame':f,'neck_collar_triangle_pairs':collision})
        for n,e in edges.items():
            lengths_now=np.linalg.norm(p[n][e[:,0]]-p[n][e[:,1]],axis=1);valid=lengths[n]>1e-5
            max_stretch[n]=max(max_stretch[n],float(np.max(lengths_now[valid]/lengths[n][valid])))
    clips[track.name]={'frames':len(frames),'minimum_attachment_pairs':minimum,'maximum_neck_collar_intersections':collar_max,'max_edge_stretch':max_stretch}
    if max(max_stretch.values())>1.5:failures.append({'clip':track.name,'excessive_neck_jaw_stretch':max_stretch})
report={'passed':not failures,'sha256':hashlib.sha256((OUT/'milo_fullres.glb').read_bytes()).hexdigest(),
        'moustache_before':before,'moustache_after':after,'moustache_ratios':ratios,'topology':topology,'animations':clips,'failures':failures}
(OUT/'neck_bold_verification.json').write_text(json.dumps(report,indent=2))
print('NECK_BOLD_RESULT',json.dumps({'passed':report['passed'],'sha256':report['sha256'],'moustache_ratios':ratios,'frames':sum(v['frames'] for v in clips.values()),'failures':len(failures),'first_failures':failures[:4]}),flush=True)
assert report['passed'],'See neck_bold_verification.json'
