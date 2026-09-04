"""Verify anatomical handedness/orientation from the exported GLB."""
import bpy,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(OUT/'milo_fullres.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:track.mute=True
def pose(clip,frame):
    action=next(a for a in bpy.data.actions if a.name.startswith(clip));rig.animation_data.action=action
    if action.slots:rig.animation_data.action_slot=action.slots[0]
    bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
def axes(label):
    hand=rig.pose.bones['hand.'+label]
    palm=(hand.matrix.to_3x3()@Vector((0,0,1))).normalized()
    thumb=rig.pose.bones['thumb.'+label].head-hand.head
    return palm,thumb
report={}
pose('Idle',0)
for s,label in ((-1,'R'),(1,'L')):
    palm,thumb=axes(label)
    inward=palm.dot(Vector((-s,0,0)));forward_thumb=thumb.dot(Vector((0,-1,0)))
    assert inward>.65 and forward_thumb>.015,(label,palm[:],thumb[:])
    report['idle_'+label]={'palm_inward_dot':inward,'thumb_forward_m':forward_thumb,'palm_world':list(palm)}
pose('Greet',36);palm,thumb=axes('L')
assert palm.dot(Vector((0,-1,0)))>.95,('Greeting palm backward',palm[:])
assert thumb.x<0,('Greeting thumb on wrong side',thumb[:])
report['greeting']={'palm_forward_dot':palm.dot(Vector((0,-1,0))),'thumb_toward_body':thumb.x<0}
pose('Cane_Hold',0);palm,thumb=axes('R')
assert (-palm).dot(Vector((0,-1,0)))>.95,('Grip dorsal side backward',palm[:])
report['cane']={'back_of_hand_forward_dot':(-palm).dot(Vector((0,-1,0)))}
(OUT/'palm_orientation_verification.json').write_text(json.dumps(report,indent=2))
print('PALM_ORIENTATION_PASS',json.dumps(report),flush=True)
