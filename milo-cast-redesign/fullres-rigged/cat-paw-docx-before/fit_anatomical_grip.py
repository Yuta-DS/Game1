"""Bounded angle-only grip fit on the exported skin, preserving joint mechanics.

Uses a shaft/collar distance objective, then reports exact surface intersections.
No bone translation/scaling, no detached fingertip IK, no geometry modification.
"""
from pathlib import Path
import bpy,math,json,copy,sys,numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'milo_fullres.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
for tr in rig.animation_data.nla_tracks:tr.mute=True
action=next(a for a in bpy.data.actions if a.name.startswith('Cane_Hold'))
rig.animation_data.action=action
if action.slots:rig.animation_data.action_slot=action.slots[0]
bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
rig.animation_data.action=None
exec(compile((OUT/'hand_motion.py').read_text(),str(OUT/'hand_motion.py'),'exec'))
settings=json.loads((OUT/'anatomical_grip_settings.json').read_text()) if (OUT/'anatomical_grip_settings.json').exists() else copy.deepcopy(HAND_POSES['grasp'])
previous_shift=settings.get('cane_shift',[0,0,0])
obj=bpy.data.objects['Milo_Articulated_Paw.R']
polygons=[p.vertices[:] for p in obj.data.polygons]
poly_sets=[set(p) for p in polygons]
groups={}
for stem in ('finger0','finger1','finger2','thumb'):
    name=stem+'_tip.R';inverse=rig.data.bones[name].matrix_local.inverted()
    groups[stem]=[v.index for v in obj.data.vertices if sum(g.weight for g in v.groups if obj.vertex_groups[g.group].name==name)>.8 and (inverse@v.co).z>0]
def points():
    ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
    data=np.empty(len(me.vertices)*3);me.vertices.foreach_get('co',data)
    data=data.reshape(-1,3);matrix=np.array(ev.matrix_world);data=data@matrix[:3,:3].T+matrix[:3,3]
    ev.to_mesh_clear();return data
before=points();apply_hand(rig,'R',settings);bpy.context.view_layer.update()
assert np.max(np.linalg.norm(points()-before,axis=1))<.00001,'Imported joint basis differs from authoring basis'
shaft=rig.pose.bones['cane'].head.copy();cane_matrix=rig.pose.bones['cane'].matrix.copy()
params=np.array(settings['mcp']+settings['pip']+settings['thumb']+[settings['cup'],0,0],dtype=float)
limits=[(0,85)]*3+[(0,90)]*3+[(5,60),(5,40),(0,60),(0,45),(0,55),(0,.8),(-.014,.014),(-.014,.014)]
steps=np.array([5]*11+[.10,.002,.002])
best_details={}
def evaluate(values,details=False):
    current={'mcp':values[:3].tolist(),'pip':values[3:6].tolist(),'spread':0,'cup':float(values[11]),'thumb':values[6:11].tolist()}
    apply_hand(rig,'R',current);bpy.context.view_layer.update();a=points()
    center=np.array([shaft.x+values[12],shaft.y+values[13]])
    radial=np.linalg.norm(a[:,:2]-center,axis=1)
    radius=.010+np.clip((a[:,2]-.018)/(.615-.018),0,1)*.004
    radius=np.where((a[:,2]>=.591)&(a[:,2]<=.626),.019,radius)
    valid=(a[:,2]>.018)&(a[:,2]<.626)
    distance=radial-radius
    penetration=np.maximum(0,.0008-distance[valid])
    gaps={name:float(distance[ids].min()) for name,ids in groups.items()}
    # Strong penetration penalty; contact is a small positive clearance.
    cost=30*float(np.sum(penetration**2))+sum((gap-.0012)**2 for gap in gaps.values())
    cost+=.000001*((values[12]/.014)**2+(values[13]/.014)**2)
    cmc_angle=math.degrees(rig.pose.bones['thumb_cmc.R'].rotation_quaternion.angle)
    cost+=.000001*max(0,cmc_angle-60)**2
    if '--self-contact' in sys.argv and cost<.002:
        hand_tree=BVHTree.FromPolygons(a.tolist(),polygons,all_triangles=True)
        crossings=sum(i<j and not poly_sets[i].intersection(poly_sets[j]) for i,j in hand_tree.overlap(hand_tree))
        cost+=crossings*.00002
    if details:return cost,current,a,gaps
    return cost
best=evaluate(params)
if '--finger-grid' in sys.argv:
    # Shorter digits need a fresh curl configuration, not merely a small
    # perturbation of the previous long-finger solution. Bounded angle grid;
    # no joint translations, scaling or relaxation of contact penalties.
    for digit in range(3):
        anchor=params.copy()
        for mcp in (8,18,28,38,48,58,68,78):
            for pip in (0,10,20,30,40,50,60,70,80):
                candidate=anchor.copy();candidate[digit]=mcp;candidate[3+digit]=pip
                cost=evaluate(candidate)
                if cost<best:params=candidate;best=cost
    print('BOUNDED_FINGER_SEARCH',best,params.tolist(),flush=True)
    # Move the shaft and all digit angles together to escape coordinate-wise
    # traps where approaching one pad would briefly penetrate another.
    rng=np.random.default_rng(20260829)
    scales=np.array([8]*6+[6]*5+[.06,.0025,.0025])
    for sample in range(384):
        candidate=params+rng.normal(size=len(params))*scales
        candidate=np.array([np.clip(v,lo,hi) for v,(lo,hi) in zip(candidate,limits)])
        cost=evaluate(candidate)
        if cost<best:params=candidate;best=cost
    print('BOUNDED_COMBINED_SEARCH',best,params.tolist(),flush=True)
    for pair_pass in range(2):
        for index in (0,3):
            for thumb in (6,7,8,9,10):
                anchor=params.copy()
                for a in (-10,-5,0,5,10):
                    for b in (-10,-5,0,5,10):
                        candidate=anchor.copy()
                        candidate[index]=np.clip(candidate[index]+a,*limits[index])
                        candidate[thumb]=np.clip(candidate[thumb]+b,*limits[thumb])
                        cost=evaluate(candidate)
                        if cost<best:params=candidate;best=cost
        print('PAIRED_INDEX_THUMB',pair_pass,best,params.tolist(),flush=True)
if '--global' in sys.argv:
    rng=np.random.default_rng(39)
    for sample in range(384):
        candidate=params.copy()
        candidate[6:11]=rng.uniform([0,5,0,0,0],[60,40,60,45,50])
        cost=evaluate(candidate)
        if cost<best:params=candidate;best=cost
    print('BOUNDED_THUMB_SEARCH',best,params.tolist(),flush=True)
for round_index,multiplier in enumerate((2,2,1,1,.5,.5)):
    changed=False
    for index,(low,high) in enumerate(limits):
        for sign in (-1,1):
            candidate=params.copy();candidate[index]=np.clip(candidate[index]+sign*steps[index]*multiplier,low,high)
            cost=evaluate(candidate)
            if cost<best:
                params=candidate;best=cost;changed=True
    print('GRIP_ROUND',round_index,'cost',best,'params',params.tolist(),flush=True)
    # Always reach the half-step pass; coarse-grid stagnation is not proof
    # that millimetre-scale contact placement has converged.
cost,current,a,gaps=evaluate(params,True)
current['cane_shift']=[previous_shift[0]+float(params[12]),previous_shift[1]+float(params[13]),0]
hand=BVHTree.FromPolygons(a.tolist(),[p.vertices[:] for p in obj.data.polygons],all_triangles=True)
overlaps={}
for prop in bpy.data.objects:
    if prop.type!='MESH' or not prop.name.startswith('Cane_'):continue
    ev=prop.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
    coords=[tuple(ev.matrix_world@v.co+Vector((params[12],params[13],0))) for v in me.vertices]
    tree=BVHTree.FromPolygons(coords,[p.vertices[:] for p in me.polygons],all_triangles=True)
    overlaps[prop.name]=len(hand.overlap(tree));ev.to_mesh_clear()
report={'settings':current,'cost':cost,'approximate_radial_gaps':gaps,'surface_intersections':overlaps,'note':'Angle-limited coordinate descent, DIP=0.65 PIP; exact all-frame check still required after rebuilding.'}
(OUT/'anatomical_grip_fit.json').write_text(json.dumps(report,indent=2))
(OUT/'anatomical_grip_settings.json').write_text(json.dumps(current,indent=2))
print('ANATOMICAL_GRIP_FIT',json.dumps(report),flush=True)
