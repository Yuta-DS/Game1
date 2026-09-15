"""Measure compact proportions and guard protected skeleton/topology."""
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
def measure(rig):
    result={}
    for side in ('L','R'):
        inv=rig.data.bones['hand.'+side].matrix_local.inverted()
        obj=bpy.data.objects['Milo_Articulated_Paw.'+side]
        pts=np.array([inv@v.co for v in obj.data.vertices])
        middle=rig.data.bones['finger1.'+side]
        result[side]={'wrist_to_middle_tip_m':(inv@rig.data.bones['finger1_tip.'+side].tail_local).y,
                      'palm_length_m':(inv@middle.head_local).y,
                      'knuckle_span_m':abs((inv@rig.data.bones['finger2.'+side].head_local).x-(inv@rig.data.bones['finger0.'+side].head_local).x),
                      'skin_length_m':float(pts[:,1].max()-pts[:,1].min()),
                      'triangles':len(obj.data.polygons)}
    return result
rig=load(OUT/'compact-paw-before/milo_fullres.glb');before=measure(rig)
old={b.name:np.array(b.matrix_local) for b in rig.data.bones}
rig=load(OUT/'milo_fullres.glb');after=measure(rig)
assert set(old)=={b.name for b in rig.data.bones}
protected=0;max_rest_error=0
for b in rig.data.bones:
    if b.name.startswith(('palm','finger','thumb')):continue
    error=float(np.abs(old[b.name]-np.array(b.matrix_local)).max())
    max_rest_error=max(max_rest_error,error)
    # Blender reconstructs the wrist basis from changed child joints; the
    # observed float32 reconstruction difference is below one millionth.
    # Canonical exported body/wrist animation is separately compared exactly.
    assert error<1e-6,(b.name,error)
    protected+=1
ratios={}
for side in ('L','R'):
    ratios[side]={key:after[side][key]/before[side][key] for key in ('wrist_to_middle_tip_m','knuckle_span_m','skin_length_m')}
    assert .60<ratios[side]['wrist_to_middle_tip_m']<.80
    assert .75<ratios[side]['knuckle_span_m']<.90
    assert after[side]['triangles']==before[side]['triangles']
def tree(obj):return BVHTree.FromPolygons([v.co for v in obj.data.vertices],[p.vertices[:] for p in obj.data.polygons],all_triangles=True)
topology={};ht=tree(bpy.data.objects['Head_Cranium_AnyCreature'])
for name in ('Milo_Articulated_Paw.L','Milo_Articulated_Paw.R','Moustache_1','Moustache_-1'):
    obj=bpy.data.objects[name];bm=bmesh.new();bm.from_mesh(obj.data)
    bad=sum(not e.is_manifold for e in bm.edges);remaining=set(bm.verts);components=0
    while remaining:
        components+=1;stack=[remaining.pop()]
        while stack:
            for e in stack.pop().link_edges:
                for v in e.verts:
                    if v in remaining:remaining.remove(v);stack.append(v)
    bm.free();assert bad==0 and components==1,(name,bad,components)
    assert all(p.use_smooth for p in obj.data.polygons)
    topology[name]={'components':components,'nonmanifold_edges':bad}
    if name.startswith('Moustache'):
        assert len(ht.overlap(tree(obj)))>0,'Moustache root detached from cheek'
        assert {obj.vertex_groups[g.group].name for v in obj.data.vertices for g in v.groups if g.weight>1e-6}=={'head'}
report={'passed':True,'sha256':hashlib.sha256((OUT/'milo_fullres.glb').read_bytes()).hexdigest(),
        'before':before,'after':after,'ratios':ratios,'protected_rest_bones':protected,
        'total_bones':len(rig.data.bones),'topology':topology,
        'max_protected_rest_matrix_error':max_rest_error,'rest_matrix_tolerance':1e-6,
        'note':'Earlier 2x hand-size target superseded by compact-paw fit request. These checks do not judge visual appeal.'}
(OUT/'compact_paw_verification.json').write_text(json.dumps(report,indent=2))
print('COMPACT_PAW_PASS',json.dumps(report),flush=True)
