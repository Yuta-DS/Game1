"""Numerical validation of the exported GLB, not the authoring scene."""
import bpy, bmesh, numpy as np, json, struct, hashlib
from mathutils.bvhtree import BVHTree
from pathlib import Path
OUT=Path(__file__).resolve().parent
p=OUT/'milo_fullres.glb';blob=p.read_bytes();doc=json.loads(blob[20:20+struct.unpack_from('<I',blob,12)[0]])
assert not any('uri' in b for b in doc.get('buffers',[])), 'external buffers'
assert not any('uri' in b for b in doc.get('images',[])), 'external images'
expected={'Idle','Walking_A','Greet','Guide','Speak','Cane_Hold','Hand_Mechanics'}
assert {a['name'] for a in doc['animations']}==expected
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(p));scene=bpy.context.scene
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig.animation_data.action=None
for tr in rig.animation_data.nla_tracks:tr.mute=True
source_mesh_names={n['name'] for n in doc['nodes'] if 'mesh' in n}
meshes=[o for o in bpy.data.objects if o.type=='MESH' and o.name in source_mesh_names]
def points(o,eval=False):
    obj=o.evaluated_get(bpy.context.evaluated_depsgraph_get()) if eval else o
    m=obj.to_mesh() if eval else obj.data
    a=np.zeros(len(m.vertices)*3,dtype=np.float64);m.vertices.foreach_get('co',a);a=a.reshape(-1,3)
    mat=np.array(obj.matrix_world);a=a@mat[:3,:3].T+mat[:3,3]
    if eval:obj.to_mesh_clear()
    return a
rest={o.name:points(o) for o in meshes}
edges={o.name:np.array([e.vertices[:] for e in o.data.edges],dtype=np.int32) for o in meshes}
weights_bad=[]
hand_topology={}
for o in meshes:
    if not any(m.type=='ARMATURE' for m in o.modifiers):weights_bad.append(o.name+': unskinned')
    for v in o.data.vertices:
        if abs(sum(g.weight for g in v.groups)-1)>.001:weights_bad.append(o.name+': weight sum');break
    if o.name.startswith('Milo_Articulated_Paw.'):
        bm=bmesh.new();bm.from_mesh(o.data)
        nonmanifold=sum(not e.is_manifold for e in bm.edges)
        unseen=set(bm.verts);components=0
        while unseen:
            components+=1;todo=[unseen.pop()]
            while todo:
                v=todo.pop()
                for e in v.link_edges:
                    other=e.other_vert(v)
                    if other in unseen:unseen.remove(other);todo.append(other)
        hand_topology[o.name]={'nonmanifold_edges':nonmanifold,'connected_components':components}
        bm.free()
        assert nonmanifold==0 and components==1,(o.name,hand_topology[o.name])
assert not weights_bad,weights_bad
assert set(hand_topology)=={'Milo_Articulated_Paw.L','Milo_Articulated_Paw.R'},'Missing revised hands'
assert len(rig.data.bones)==61,'Anatomical hand rig bone count regression'
for side in ('L','R'):
    assert rig.data.bones['thumb.'+side].parent.name=='thumb_cmc.'+side
    for k in range(3):
        assert rig.data.bones['finger%d.'%k+side].parent.name=='palm%d.'%k+side
        assert rig.data.bones['finger%d_mid.'%k+side].parent.name=='finger%d.'%k+side
        assert rig.data.bones['finger%d_tip.'%k+side].parent.name=='finger%d_mid.'%k+side
results={}
grip_contacts=[]
for name in sorted(expected):
    act=next(a for a in bpy.data.actions if a.name.startswith(name));rig.animation_data.action=act
    if act.slots:rig.animation_data.action_slot=act.slots[0]
    start=round(act.frame_range[0]);end=round(act.frame_range[1]);frames=list(range(start,end+1))
    minfoot=10.;maxstretch=0.;worst='';bounds=[];centers=[];bootheights=[];first=None;loop_error=0.;hand_stretch={n:1. for n in hand_topology}
    for f in frames:
        scene.frame_set(f);bpy.context.view_layer.update();allpts=[];heights=[]
        contact_frame=name=='Cane_Hold'
        contact_meshes={}
        hand_coords=None
        for o in meshes:
            a=points(o,True);assert np.isfinite(a).all(),(name,f,o.name)
            if contact_frame and (o.name.startswith('Cane_') or o.name=='Milo_Articulated_Paw.R'):
                contact_meshes[o.name]=BVHTree.FromPolygons(a.tolist(),[p.vertices[:] for p in o.data.polygons],all_triangles=True)
                if o.name=='Milo_Articulated_Paw.R':hand_coords=a
            if o.name.startswith('Cane_'):continue
            allpts.append(a)
            if o.name.startswith('Milo_Sculpt_Boot'):
                minfoot=min(minfoot,float(a[:,2].min()));heights.append(float(a[:,2].min()))
            e=edges[o.name]
            if len(e):
                original=np.linalg.norm(rest[o.name][e[:,0]]-rest[o.name][e[:,1]],axis=1)
                length=np.linalg.norm(a[e[:,0]]-a[e[:,1]],axis=1);valid=original>1e-5
                ratio=float(np.max(length[valid]/original[valid])) if valid.any() else 1
                if ratio>maxstretch:maxstretch=ratio;worst=o.name
                if o.name in hand_stretch:hand_stretch[o.name]=max(hand_stretch[o.name],ratio)
        full=np.concatenate(allpts);bounds.append((full.min(0).tolist(),full.max(0).tolist()));centers.append(full.mean(0).tolist());bootheights.append(heights)
        if first is None:first=full.copy()
        if f==end:loop_error=float(np.linalg.norm(full-first,axis=1).max())
        if contact_frame:
            hand=contact_meshes.pop('Milo_Articulated_Paw.R')
            overlaps={n:len(hand.overlap(tree)) for n,tree in contact_meshes.items()}
            sample={'frame':f,'hand_cane_intersecting_triangle_pairs':overlaps}
            if f in (start,(start+end)//2,end):
                obj=bpy.data.objects['Milo_Articulated_Paw.R'];gaps={}
                for stem in ('finger0','finger1','finger2','thumb'):
                    names={stem+'.R',stem+'_mid.R',stem+'_tip.R'}
                    ids=[v.index for v in obj.data.vertices if sum(g.weight for g in v.groups if obj.vertex_groups[g.group].name in names)>.80]
                    gaps[stem]=min(tree.find_nearest(tuple(hand_coords[i]))[3] for i in ids for name,tree in contact_meshes.items() if name in ('Cane_Shaft','Cane_Gold_Collar'))
                sample['digit_minimum_surface_gaps_m']=gaps
            grip_contacts.append(sample)
    results[name]={'sampled_frames':len(frames),'all_authored_frames_checked':True,'loop_endpoint_max_vertex_error':loop_error,'min_boot_z':minfoot,'max_edge_stretch':maxstretch,'worst_stretch_mesh':worst,'hand_max_edge_stretch':hand_stretch,'boot_heights':bootheights,'bounds':bounds}
report={'file':str(p),'sha256':hashlib.sha256(blob).hexdigest(),'bytes':len(blob),'mesh_objects':len(meshes),'bones':len(rig.data.bones),'triangles':sum(len(o.data.polygons) for o in meshes),'self_contained':True,'skin_weights_normalized':True,'animations':results,'visual_likeness':'See PALM_WHISKER_REVIEW.md for the current part review; numeric checks do not judge appearance. Earlier head and exact-reference reviews remain historical, not full-asset approval.','limits':'All authored frames checked for finite vertices, edge stretch and ground penetration. This does not prove no intersections or faithful likeness.'}
report['hand_topology']=hand_topology
report['hand_deformation_gate_pass']=all(v<3 for clip in results.values() for v in clip['hand_max_edge_stretch'].values())
report['grip_surface_intersections']=grip_contacts
report['grip_sampled_surface_intersection_gate_pass']=all(count==0 for sample in grip_contacts for count in sample['hand_cane_intersecting_triangle_pairs'].values())
(OUT/'verification.json').write_text(json.dumps(report,indent=2))
assert report['hand_deformation_gate_pass'],'Hand deformation exceeds 3x stretch limit'
assert report['grip_sampled_surface_intersection_gate_pass'],'Sampled hand/cane surfaces intersect'
print('VERIFICATION',json.dumps({k:{kk:v for kk,v in val.items() if kk not in ('bounds','boot_heights')} for k,val in results.items()}),flush=True)
