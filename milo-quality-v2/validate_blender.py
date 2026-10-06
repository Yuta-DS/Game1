"""Measured local rig checks; not a blanket claim of collision-free motion."""
from pathlib import Path
import sys,json,math
import bpy
from mathutils import Vector
OUT=Path(__file__).resolve().parent;sys.path.insert(0,str(OUT))
from review import load,select_clip
scene=load();rig=bpy.data.objects['MiloQualityRig']
meshes=[o for o in scene.objects if o.type=='MESH' and o.parent==rig]
report={'checks':[],'clips':{},'limitations':['No exhaustive self-collision or production-game integration test.','Optional IK-preview controls are not part of the exported baked rig.']}
def check(name,passed,**details):report['checks'].append(dict(name=name,passed=bool(passed),**details))
bad=[]
for o in meshes:
    for v in o.data.vertices:
        total=sum(g.weight for g in v.groups if o.vertex_groups[g.group].name in rig.data.bones)
        if abs(total-1)>.0001:bad.append((o.name,v.index,total))
check('normalized_skin_weights',not bad,bad_vertices=bad[:8])
rest={o.name:[(tuple(e.vertices),(o.data.vertices[e.vertices[0]].co-o.data.vertices[e.vertices[1]].co).length) for e in o.data.edges] for o in meshes if o.name.startswith(('Sleeve','Trouser','CoatBody'))}
manifest=json.loads((OUT/'animation_manifest.json').read_text())
records=json.loads((OUT/'contact_samples.json').read_text())
for clip,meta in manifest.items():
    select_clip(clip);stretch=1.;finite=True;min_sole=10.;grip_error=0.;loop_delta=0.;first=None
    for i in range(17):
        f=meta['duration']*30*i/16;scene.frame_set(int(f),subframe=f-int(f));dg=bpy.context.evaluated_depsgraph_get()
        mats={p.name:p.matrix.copy() for p in rig.pose.bones}
        if first is None:first=mats
        if i==16:loop_delta=max(abs(first[n][r][c]-mats[n][r][c]) for n in mats for r in range(4) for c in range(4))
        for o in meshes:
            eo=o.evaluated_get(dg);me=eo.to_mesh()
            finite &= all(math.isfinite(c) for v in me.vertices for c in v.co)
            if o.name.startswith('Sole.'):min_sole=min(min_sole,min((eo.matrix_world@v.co).z for v in me.vertices))
            if o.name in rest:
                for (a,b),length in rest[o.name]:
                    if length>.0001:stretch=max(stretch,(me.vertices[a].co-me.vertices[b].co).length/length)
            eo.to_mesh_clear()
        expected=rig.pose.bones['cane'].matrix@rig.data.bones['cane'].matrix_local.inverted()@Vector((.455,-.09,.760))
        grip_error=max(grip_error,(rig.pose.bones['hand.l'].head-expected).length)
    check(clip+'_finite_and_skin_stretch',finite and stretch<3,max_edge_stretch=stretch,samples=17)
    check(clip+'_ground_clearance',min_sole>=-.001,min_sole_z=min_sole)
    check(clip+'_cane_grip',grip_error<.0001,max_error_m=grip_error)
    check(clip+'_reachable_targets',meta['max_ik_reach_error']<.0001,max_error_m=meta['max_ik_reach_error'])
    if meta['loop']:check(clip+'_loop_closure',loop_delta<.0001,max_matrix_delta=loop_delta)
    report['clips'][clip]={'duration':meta['duration'],'samples':17,'max_skin_stretch':stretch,'min_sole_z':min_sole,'cane_grip_error':grip_error}
    print('CHECKED',clip,report['clips'][clip],flush=True)
# World-space planted points must stay fixed during each stance interval.
rows=records['Walk_Forward'];drift=0.
for side in ['l','r','cane']:
    anchor=None;last_phase=None
    for row in rows:
        contact=row['cane_contact'] if side=='cane' else row['feet'][side]['contact']
        point=Vector(row['cane_tip'] if side=='cane' else row['feet'][side]['actual'])
        phase=row['feet']['l' if side=='cane' else side]['phase']
        if not contact:anchor=None
        else:
            if anchor is None or (last_phase is not None and phase<last_phase):anchor=point
            drift=max(drift,(point-anchor).length)
        last_phase=phase
check('forward_walk_planted_contact',drift<.0001,max_drift_m=drift,samples=len(rows))
report['passed']=all(c['passed'] for c in report['checks'])
(OUT/'blender_validation.json').write_text(json.dumps(report,indent=2))
print('BLENDER_VALIDATION',report['passed'],flush=True)
if not report['passed']:raise RuntimeError('See blender_validation.json for actual failures')
