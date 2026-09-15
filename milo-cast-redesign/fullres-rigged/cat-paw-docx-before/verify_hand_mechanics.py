"""Check the actual exported bone motions, not just authored pose constants."""
import bpy,math,json
from pathlib import Path
OUT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(OUT/'milo_fullres.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
for tr in rig.animation_data.nla_tracks:tr.mute=True
report={'frames':0,'max_pip_dip_coupling_error_deg':0,'max_finger_sideways_hinge_rotation_deg':0,'max_digit_translation_m':0,'max_digit_scale_error':0,'thumb_cmc_rotation_max_deg':0,'outer_palm_flexion_max_deg':0}
for action in bpy.data.actions:
    rig.animation_data.action=action
    if action.slots:rig.animation_data.action_slot=action.slots[0]
    for frame in range(round(action.frame_range[0]),round(action.frame_range[1])+1):
        bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();report['frames']+=1
        for side in ('L','R'):
            cmc=rig.pose.bones['thumb_cmc.'+side]
            report['thumb_cmc_rotation_max_deg']=max(report['thumb_cmc_rotation_max_deg'],math.degrees(cmc.rotation_quaternion.angle))
            for k in range(3):
                pip=rig.pose.bones['finger%d_mid.'%k+side].rotation_quaternion.to_euler('XYZ')
                dip=rig.pose.bones['finger%d_tip.'%k+side].rotation_quaternion.to_euler('XYZ')
                mcp=rig.pose.bones['finger%d.'%k+side].rotation_quaternion.to_euler('XYZ')
                p,d,m=map(math.degrees,(pip.x,dip.x,mcp.x))
                assert -.01<=p<=100.01 and -.01<=d<=70.01 and -.01<=m<=85.01,(action.name,frame,side,k,p,d,m)
                coupling=abs(d-.65*p)
                sideways=max(abs(math.degrees(v)) for v in (pip.y,pip.z,dip.y,dip.z))
                assert coupling<.01 and sideways<.01,(action.name,frame,'Hinge/coupling failure',coupling,sideways)
                report['max_pip_dip_coupling_error_deg']=max(report['max_pip_dip_coupling_error_deg'],coupling)
                report['max_finger_sideways_hinge_rotation_deg']=max(report['max_finger_sideways_hinge_rotation_deg'],sideways)
            for pb in rig.pose.bones:
                if not pb.name.startswith(('palm','finger','thumb')):continue
                report['max_digit_translation_m']=max(report['max_digit_translation_m'],pb.location.length)
                report['max_digit_scale_error']=max(report['max_digit_scale_error'],max(abs(v-1) for v in pb.scale))
            for k in range(3):
                angle=math.degrees(rig.pose.bones['palm%d.'%k+side].rotation_quaternion.to_euler().x)
                assert -.01<=angle<=15.01
                report['outer_palm_flexion_max_deg']=max(report['outer_palm_flexion_max_deg'],angle)
assert report['frames']==631,report
assert report['max_digit_translation_m']<.00001 and report['max_digit_scale_error']<.0001,report
assert report['outer_palm_flexion_max_deg']>5 and report['thumb_cmc_rotation_max_deg']>25,report
report['passed']=True
report['limits']='Human-inspired kinematic structure and authored joint ranges only; not a medical simulation or proof of natural-looking motion, contact forces or collision-free hands.'
(OUT/'hand_mechanics_verification.json').write_text(json.dumps(report,indent=2))
print('HAND_MECHANICS_PASS',json.dumps(report),flush=True)
