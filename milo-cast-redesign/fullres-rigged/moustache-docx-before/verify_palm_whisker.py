"""Measure the actual exported palm change and connected cheek attachments."""
from pathlib import Path
import bpy,bmesh,json,hashlib,numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parent
def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(path))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    rig.animation_data.action=None
    for tr in rig.animation_data.nla_tracks:tr.mute=True
    for p in rig.pose.bones:p.matrix_basis.identity()
    bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
    return rig
def palms(rig):
    result={}
    for side in ('L','R'):
        inv=rig.data.bones['hand.'+side].matrix_local.inverted()
        obj=bpy.data.objects['Milo_Articulated_Paw.'+side]
        a=np.array([inv@v.co for v in obj.data.vertices])
        central=a[(np.abs(a[:,0])<.025)&(a[:,1]>.045)&(a[:,1]<.095)]
        inner=-1 if side=='L' else 1
        ulnar=a[(a[:,0]*inner<0)&(a[:,1]>.050)&(a[:,1]<.075)&(a[:,2]<0)]
        assert len(central)>100
        result[side]={'central_palm_depth_m':float(central[:,2].max()-central[:,2].min()),
                      'lower_palm_ulnar_halfwidth_m':float(np.abs(ulnar[:,0]).max()),
                      'knuckle_span_m':abs((inv@rig.data.bones['finger2.'+side].head_local).x-(inv@rig.data.bones['finger0.'+side].head_local).x),
                      'palm_length_m':(inv@rig.data.bones['finger1.'+side].head_local).y,
                      'triangles':len(obj.data.polygons)}
    return result
rig=load(OUT/'palm-whisker-before/milo_fullres.glb');before=palms(rig)
old_bones={b.name:np.array(b.matrix_local) for b in rig.data.bones}
rig=load(OUT/'milo_fullres.glb');after=palms(rig)
assert set(old_bones)=={b.name for b in rig.data.bones}
for b in rig.data.bones:assert np.allclose(old_bones[b.name],np.array(b.matrix_local),atol=1e-7,rtol=0),b.name
for side in ('L','R'):
    ratio=after[side]['central_palm_depth_m']/before[side]['central_palm_depth_m']
    assert .70<ratio<.92,(side,ratio)
    assert .60<after[side]['lower_palm_ulnar_halfwidth_m']/before[side]['lower_palm_ulnar_halfwidth_m']<.88
    for key in ('palm_length_m','knuckle_span_m'):assert abs(after[side][key]-before[side][key])<1e-7
    assert after[side]['triangles']==before[side]['triangles']
def tree(obj):return BVHTree.FromPolygons([v.co for v in obj.data.vertices],[p.vertices[:] for p in obj.data.polygons],all_triangles=True)
head=bpy.data.objects['Head_Cranium_AnyCreature'];headtree=tree(head)
whiskers={}
for side in (-1,1):
    obj=bpy.data.objects['Moustache_'+str(side)]
    bm=bmesh.new();bm.from_mesh(obj.data);bad=sum(not e.is_manifold for e in bm.edges)
    remaining=set(bm.verts);components=0
    while remaining:
        components+=1;stack=[remaining.pop()]
        while stack:
            for e in stack.pop().link_edges:
                for v in e.verts:
                    if v in remaining:remaining.remove(v);stack.append(v)
    bm.free();assert bad==0 and components==1,(obj.name,bad,components)
    contacts=len(headtree.overlap(tree(obj)));assert contacts>0,'Moustache root floats off the cheek'
    groups={obj.vertex_groups[g.group].name for v in obj.data.vertices for g in v.groups if g.weight>1e-6}
    assert groups=={'head'},groups
    assert all(p.use_smooth for p in obj.data.polygons)
    whiskers[obj.name]={'components':components,'nonmanifold_edges':bad,'head_attachment_intersections':contacts,
                       'note':'Intersections are intentional buried roots, not a collision-clearance claim.'}
report={'passed':True,'sha256':hashlib.sha256((OUT/'milo_fullres.glb').read_bytes()).hexdigest(),
        'before':before,'after':after,'all_61_bone_rest_matrices_unchanged':True,
        'depth_ratios':{s:after[s]['central_palm_depth_m']/before[s]['central_palm_depth_m'] for s in ('L','R')},
        'whiskers':whiskers}
(OUT/'palm_whisker_verification.json').write_text(json.dumps(report,indent=2));print('PALM_WHISKER_PASS',json.dumps(report),flush=True)
