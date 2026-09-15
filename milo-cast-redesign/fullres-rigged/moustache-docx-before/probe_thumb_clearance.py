"""Bounded local pose probe; never changes the model or accepts a failed pose."""
import bpy,sys,json,copy
from pathlib import Path
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(OUT))
from hand_motion import HAND_POSES,apply_hand
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'milo_fullres.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig.animation_data_clear()
obj=bpy.data.objects['Milo_Articulated_Paw.L']
for pb in rig.pose.bones:pb.matrix_basis.identity()
report=[]
for thumb in ([20,10,30,12,15],[20,18,30,12,15],[20,24,30,12,15],[16,18,26,10,12],[14,20,26,10,12],[12,22,26,10,12]):
    settings=copy.deepcopy(HAND_POSES['opposition']);settings['thumb']=thumb
    apply_hand(rig,'L',settings);bpy.context.view_layer.update()
    ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
    polys=[p.vertices[:] for p in me.polygons]
    tree=BVHTree.FromPolygons([v.co[:] for v in me.vertices],polys,all_triangles=True)
    pairs=[(a,b) for a,b in tree.overlap(tree) if a<b and not set(polys[a]).intersection(polys[b])]
    row={'thumb':thumb,'nonadjacent_intersections':len(pairs)}
    report.append(row);print('THUMB_PROBE',json.dumps(row),flush=True)
    ev.to_mesh_clear()
(OUT/'thumb_clearance_probe.json').write_text(json.dumps(report,indent=2))
