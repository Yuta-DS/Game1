"""Measure the resized export against the preserved pre-resize hand."""
import bpy,json,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent
def measure(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    result={}
    for side in ('L','R'):
        hand=rig.data.bones['hand.'+side]
        inv=hand.matrix_local.inverted()
        palm_end=inv@rig.data.bones['finger1.'+side].head_local
        ends=[inv@rig.data.bones['finger%d.'%k+side].head_local for k in (0,2)]
        obj=bpy.data.objects['Milo_Articulated_Paw.'+side]
        points=[inv@v.co for v in obj.data.vertices]
        result[side]={'wrist_position':list(hand.head_local),'palm_length_m':palm_end.y,
                      'knuckle_span_m':abs(ends[1].x-ends[0].x),
                      'whole_hand_distal_extent_m':max(v.y for v in points),
                      'whole_hand_width_m':max(v.x for v in points)-min(v.x for v in points)}
    return result
old=measure(OUT/'palm-size-before/milo_fullres.glb')
new=measure(OUT/'milo_fullres.glb')
report={'sha256':hashlib.sha256((OUT/'milo_fullres.glb').read_bytes()).hexdigest(),'before':old,'after':new,'ratios':{}}
for side in ('L','R'):
    ratios={key:new[side][key]/old[side][key] for key in old[side] if key!='wrist_position'}
    assert .78<ratios['palm_length_m']<.83,ratios
    assert .87<ratios['knuckle_span_m']<.91,ratios
    assert max(abs(a-b) for a,b in zip(old[side]['wrist_position'],new[side]['wrist_position']))<1e-6
    report['ratios'][side]=ratios
report['passed']=True
(OUT/'palm_size_verification.json').write_text(json.dumps(report,indent=2))
print('PALM_SIZE_PASS',json.dumps(report),flush=True)
