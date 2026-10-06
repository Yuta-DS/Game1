"""Closed, connected, head-bound fur with clear eye and spectacle surfaces."""
from pathlib import Path
import bpy,bmesh,json,hashlib
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'milo_fullres.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig.animation_data.action=None
for tr in rig.animation_data.nla_tracks:tr.mute=True
for p in rig.pose.bones:p.matrix_basis.identity()
bpy.context.view_layer.update()
def tree(obj):
    return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[p.vertices[:] for p in obj.data.polygons],all_triangles=True)
head=tree(bpy.data.objects['Head_Cranium_AnyCreature'])
focals={o.name:tree(o) for o in bpy.data.objects if o.type=='MESH' and o.name.startswith(('Eye_','Glasses_'))}
result={}
for name in ('Moustache_1','Moustache_-1','Cheek_Ruff_1','Cheek_Ruff_-1'):
    obj=bpy.data.objects[name];bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
    bad=sum(not e.is_manifold for e in bm.edges)
    remaining=set(bm.verts);components=0
    while remaining:
        components+=1;stack=[remaining.pop()]
        while stack:
            for e in stack.pop().link_edges:
                for v in e.verts:
                    if v in remaining:remaining.remove(v);stack.append(v)
    bm.free();surface=tree(obj)
    attach=len(head.overlap(surface))
    collisions={n:len(t.overlap(surface)) for n,t in focals.items()}
    bindings={obj.vertex_groups[g.group].name for v in obj.data.vertices for g in v.groups if g.weight>1e-6}
    faces=[set(p.vertices) for p in obj.data.polygons]
    overlaps=[(i,j) for i,j in surface.overlap(surface) if i<j and not faces[i]&faces[j]]
    self_pairs=len(overlaps)
    result[name]={'components':components,'nonmanifold_edges':bad,'nonadjacent_self_intersections':self_pairs,
                  'skull_attachment_intersections':attach,'eye_spectacle_intersections':collisions,'bound_bones':sorted(bindings),
                  'triangles':len(obj.data.polygons)}
    assert components==1 and bad==0,(name,result[name])
    assert attach>0 and bindings=={'head'},(name,result[name])
    assert max(collisions.values())==0,(name,result[name])
    if self_pairs:
        print('FUR_OVERLAP_LOCATIONS',name,[(i,j,tuple(obj.data.polygons[i].center),tuple(obj.data.polygons[j].center)) for i,j in overlaps[:8]],flush=True)
    assert self_pairs==0,(name,result[name])
report={'passed':True,'sha256':hashlib.sha256((OUT/'milo_fullres.glb').read_bytes()).hexdigest(),'parts':result}
(OUT/'moustache_verification.json').write_text(json.dumps(report,indent=2))
print('MOUSTACHE_GEOMETRY_PASS',json.dumps(report),flush=True)
