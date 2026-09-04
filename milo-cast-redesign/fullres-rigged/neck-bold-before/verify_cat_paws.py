"""Current cat-paw proportions, closed skin, pads and DOCX cheek attachment."""
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
rig=load(OUT/'cat-paw-docx-before/milo_fullres.glb')
old={b.name:np.array(b.matrix_local) for b in rig.data.bones}
rig=load(OUT/'milo_fullres.glb')
assert set(old)=={b.name for b in rig.data.bones}
errors={b.name:float(np.abs(old[b.name]-np.array(b.matrix_local)).max()) for b in rig.data.bones if not b.name.startswith(('palm','finger','thumb'))}
assert max(errors.values())<1e-6,errors
proportions={}
for side in ('L','R'):
    inv=rig.data.bones['hand.'+side].matrix_local.inverted()
    base=(inv@rig.data.bones['finger1.'+side].head_local).y
    tip=(inv@rig.data.bones['finger1_tip.'+side].tail_local).y
    ratio=(tip-base)/base
    assert .30<ratio<.55,ratio
    obj=bpy.data.objects['Milo_Articulated_Paw.'+side]
    colors=obj.data.color_attributes.active_color
    assert colors is not None,'Paw vertex colors missing from export'
    values=np.array([c.color[:] for c in colors.data])
    assert float(np.ptp(values[:,:3],axis=0).max())>.10,'Pad color contrast missing'
    proportions[side]={'palm_length_m':base,'middle_toe_length_m':tip-base,'toe_to_palm_ratio':ratio,'color_samples':len(values)}
def tree(obj):return BVHTree.FromPolygons([v.co for v in obj.data.vertices],[p.vertices[:] for p in obj.data.polygons],all_triangles=True)
head=tree(bpy.data.objects['Head_Cranium_AnyCreature'])
topology={}
names=['Milo_Articulated_Paw.L','Milo_Articulated_Paw.R','Moustache_1','Moustache_-1']
names += [f'Cheek_Tuft_{level}_{side}' for side in (-1,1) for level in ('Upper','Lower')]
for name in names:
    obj=bpy.data.objects[name];bm=bmesh.new();bm.from_mesh(obj.data)
    # glTF duplicates vertices at material boundaries. Weld only coincident
    # positions for geometric topology measurement, never the delivered mesh.
    before=len(bm.verts)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
    seams=before-len(bm.verts)
    bad=sum(not e.is_manifold for e in bm.edges)
    remaining=set(bm.verts);components=0
    while remaining:
        components+=1;stack=[remaining.pop()]
        while stack:
            for e in stack.pop().link_edges:
                for v in e.verts:
                    if v in remaining:remaining.remove(v);stack.append(v)
    bm.free()
    assert bad==0 and components==1,(name,bad,components)
    topology[name]={'components':components,'nonmanifold_edges':bad,'coincident_material_seam_vertices':seams}
    if name.startswith(('Moustache','Cheek_Tuft')):
        overlap=len(head.overlap(tree(obj)))
        topology[name]['skull_attachment_intersections']=overlap
        assert overlap>0,(name,'detached')
        assert {obj.vertex_groups[g.group].name for v in obj.data.vertices for g in v.groups if g.weight>1e-6}=={'head'}
result={'passed':True,'sha256':hashlib.sha256((OUT/'milo_fullres.glb').read_bytes()).hexdigest(),'proportions':proportions,'topology':topology,'protected_rest_bones':len(errors),'max_rest_error':max(errors.values()),'total_bones':len(rig.data.bones)}
(OUT/'cat_paw_verification.json').write_text(json.dumps(result,indent=2))
print('CAT_PAW_PASS',json.dumps(result),flush=True)
