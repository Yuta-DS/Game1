"""Author slow, contact-aware motion and face animation on the bespoke Milo rig."""
from pathlib import Path
import math,json
import bpy
from mathutils import Vector,Matrix,Quaternion
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'milo_quality_studio.blend'))
scene=bpy.context.scene;scene.render.fps=30
rig=bpy.data.objects['MiloQualityRig']
rig.animation_data_create()
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
deform_names=list(rest)
shapes=[o for o in scene.objects if o.type=='MESH' and o.data.shape_keys]

def update():bpy.context.view_layer.update()
def reset():
    for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4);p.rotation_mode='QUATERNION'
    for o in shapes:
        for k in o.data.shape_keys.key_blocks[1:]:k.value=0
    update()

def rotate(name,axis,angle):
    pb=rig.pose.bones[name];basis=rest[name].to_quaternion()
    pb.rotation_quaternion=pb.rotation_quaternion@(basis.inverted()@Quaternion(Vector(axis),math.radians(angle))@basis)

def bone_segment(name,head,tail):
    b=rig.data.bones[name];direction=b.tail_local-b.head_local
    q=direction.rotation_difference(Vector(tail)-Vector(head))@rest[name].to_quaternion()
    rig.pose.bones[name].matrix=Matrix.LocRotScale(Vector(head),q,Vector((1,1,1)))
    update()

def solve_two(upper,lower,target,pole):
    start=rig.pose.bones[upper].head.copy();target=Vector(target)
    l1=rig.data.bones[upper].length;l2=rig.data.bones[lower].length
    delta=target-start;actual=delta.length;d=min(actual,(l1+l2)*.998);d=max(d,abs(l1-l2)+.001)
    axis=delta.normalized();bend=Vector(pole)-axis*Vector(pole).dot(axis);bend.normalize()
    a=(l1*l1-l2*l2+d*d)/(2*d);h=math.sqrt(max(0,l1*l1-a*a))
    joint=start+axis*a+bend*h;end=start+axis*d
    bone_segment(upper,start,joint);bone_segment(lower,joint,end)
    return end,abs(actual-d)

def set_world(name,position,rotation=None):
    q=rotation or rest[name].to_quaternion()
    rig.pose.bones[name].matrix=Matrix.LocRotScale(Vector(position),q,Vector((1,1,1)));update()

def pulse(t,center,width):
    a=abs(t-center)/width
    return .5+.5*math.cos(math.pi*a) if a<1 else 0

# Animator-editable optional IK controls. The baked FK actions remain authoritative
# for game export; set IK_preview to 1 in Blender to pose via the named controls.
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
for sign,side in [(1,'l'),(-1,'r')]:
    for label,head in [('foot',(sign*.15,0,.14)),('knee',(sign*.15,-.5,.36)),('hand',(sign*.43,-.08,.74)),('elbow',(sign*.7,.24,.95))]:
        b=rig.data.edit_bones.new('CTRL_'+label+'.'+side);b.head=head;b.tail=Vector(head)+Vector((0,0,.09));b.use_deform=False;b.parent=rig.data.edit_bones['root']
bpy.ops.object.mode_set(mode='OBJECT')
collection=rig.data.collections.new('IK controls — enable IK_preview')
for b in rig.data.bones:
    if b.name.startswith('CTRL_'):collection.assign(b)
rig['IK_preview']=0.0;rig.id_properties_ui('IK_preview').update(min=0,max=1,description='0: baked FK animation; 1: animator IK controls')
for side in ['l','r']:
    for limb,control,pole in [('lowerleg','foot','knee'),('lowerarm','hand','elbow')]:
        c=rig.pose.bones[limb+'.'+side].constraints.new('IK');c.name='Editable '+control+' IK'
        c.target=rig;c.subtarget='CTRL_'+control+'.'+side;c.pole_target=rig;c.pole_subtarget='CTRL_'+pole+'.'+side;c.chain_count=2;c.use_stretch=False;c.influence=0
        driver=c.driver_add('influence').driver;driver.expression='amount'
        variable=driver.variables.new();variable.name='amount';variable.type='SINGLE_PROP';variable.targets[0].id=rig;variable.targets[0].data_path='["IK_preview"]'
for name in rig.data.bones.keys():
    if name not in rest:rest[name]=rig.data.bones[name].matrix_local.copy()

clips={'Idle':4.0,'Walk_InPlace':1.6,'Walk_Forward':4.8,'Welcome':3.2,'Listen':4.0,'Speak':4.0}
manifest={};records={};all_actions={};face_actions={}
STRIDE=.42;CYCLE=1.6;STANCE=.62

def sample(name,time,duration):
    reset();walking=name.startswith('Walk');phase=(time/CYCLE)%1 if walking else 0
    travel=STRIDE*time/CYCLE if name=='Walk_Forward' else 0
    root_offset=Vector((0,-travel,0))
    set_world('root',root_offset)
    sway=.017*math.cos(math.tau*phase) if walking else .006*math.sin(math.tau*time/4)
    bob=.005*math.cos(math.tau*2*phase) if walking else .0025*math.sin(math.tau*time/4)
    body=Vector((sway,0,-.043+bob))
    set_world('hips',root_offset+Vector((0,0,.64))+body)
    rotate('spine',(1,0,0),2.2+(.7*math.sin(math.tau*phase) if walking else .35*math.sin(math.tau*time/4)))
    rotate('chest',(0,0,1),1.1*math.sin(math.tau*phase) if walking else .4*math.sin(math.tau*time/4))
    rotate('head',(1,0,0),-1.6+(.4*math.sin(math.tau*2*phase) if walking else .6*math.sin(math.tau*time/4)))
    rotate('head',(0,0,1),-.7*math.sin(math.tau*phase) if walking else .8*math.sin(math.tau*time/4))
    update();err=0;feet={}
    for sign,side in [(1,'l'),(-1,'r')]:
        p=(phase+(0 if side=='l' else .5))%1
        forward=0;lift=0;pitch=0
        if walking:
            if p<=STANCE:forward=.16-STRIDE*p
            else:
                t=(p-STANCE)/(1-STANCE);smooth=t*t*(3-2*t)
                forward=(.16-STRIDE*STANCE)*(1-smooth)+.16*smooth
                lift=.078*math.sin(math.pi*t)**1.3;pitch=7*math.sin(math.pi*t)
        target=root_offset+Vector((sign*.15,-forward,.14+lift))
        end,error=solve_two('upperleg.'+side,'lowerleg.'+side,target,(0,-1,0));err=max(err,error)
        q=Quaternion(Vector((1,0,0)),math.radians(-pitch))@rest['foot.'+side].to_quaternion()
        set_world('foot.'+side,end,q)
        set_world('CTRL_foot.'+side,target)
        feet[side]={'phase':p,'contact':not walking or p<=STANCE,'target':list(target),'actual':list(end)}
        rotate('coat_tail.'+side,(1,0,0),1.2*math.sin(math.tau*phase+(0 if side=='l' else math.pi)) if walking else .3*math.sin(math.tau*time/4))
    # Cane tip follows a planted world-space path, then recovers with a low arc.
    cp=phase;cf=0;cl=0
    if walking:
        if cp<=STANCE:cf=.10-STRIDE*cp
        else:
            t=(cp-STANCE)/(1-STANCE);s=t*t*(3-2*t);cf=(.10-STRIDE*STANCE)*(1-s)+.10*s;cl=.036*math.sin(math.pi*t)
    cane_pos=root_offset+Vector((.515,-.09-cf,.018+cl))
    set_world('cane',cane_pos)
    grip=rig.pose.bones['cane'].matrix@rest['cane'].inverted()@Vector((.455,-.09,.760))
    wrist_target=grip+Vector((0,.01,.05))
    end,error=solve_two('upperarm.l','lowerarm.l',wrist_target,(.15,1,0));err=max(err,error)
    set_world('wrist.l',end);set_world('hand.l',grip);set_world('CTRL_hand.l',wrist_target)
    free=root_offset+body+Vector((-.43,-.08+(.07*math.sin(math.tau*phase) if walking else 0),.765))
    envelope=math.sin(math.pi*time/duration)**2
    if name=='Welcome':
        free+=Vector((-.03,-.21,.16))*envelope
        rotate('head',(0,0,1),-3*envelope);rotate('head',(1,0,0),2*envelope)
        rotate('brow.r',(0,1,0),-5*envelope)
    elif name=='Listen':
        rotate('head',(0,1,0),-6*envelope)
        rotate('head',(1,0,0),3.5*envelope*math.sin(math.tau*time/duration))
        rotate('ear.r',(0,1,0),-3*envelope)
    elif name=='Speak':
        free+=Vector((-.025,-.13,.06))*envelope*(.7+.3*math.sin(math.tau*time/1.3))
        rotate('head',(0,0,1),2*envelope*math.sin(math.tau*time/2.3))
        rotate('jaw',(1,0,0),-9*envelope*(.3+.7*abs(math.sin(time*8))))
        for side in ['l','r']:rotate('moustache.'+side,(1,0,0),.8*math.sin(time*8)*envelope)
    update();end,error=solve_two('upperarm.r','lowerarm.r',free,(-.15,1,0));err=max(err,error)
    set_world('wrist.r',end)
    hand=end+Vector((0,-.01,-.05));set_world('hand.r',hand)
    if name in ['Welcome','Speak']:rotate('hand.r',(0,1,0),-25*envelope)
    set_world('CTRL_hand.r',free)
    # Full blink and very small eye contact shifts, independently skinned.
    blink=max(pulse(time,1.45,.12),pulse(time,3.55,.11))
    if name=='Walk_InPlace':blink=0
    for side in ['l','r']:
        bpy.data.objects['UpperLid.'+side].data.shape_keys.key_blocks['Blink'].value=blink
        bpy.data.objects['Paw.'+side].data.shape_keys.key_blocks['FingerCurl'].value=.5 if side=='l' else .15+.08*math.sin(math.tau*time/duration)
        rotate('eye.'+side,(0,0,1),.8*math.sin(math.tau*time/duration))
        rotate('ear.'+side,(0,1,0),1.3*pulse(time,2.1,.35)*(1 if side=='l' else -.6))
    update()
    return {'feet':feet,'cane_tip':list(cane_pos),'cane_contact':not walking or cp<=STANCE,'max_ik_reach_error':err}

for name,duration in clips.items():
    n=round(duration*30);action=bpy.data.actions.new(name);action.use_fake_user=True
    rig.animation_data.action=action
    actions={}
    for obj in shapes:
        key=obj.data.shape_keys;key.animation_data_create()
        fa=bpy.data.actions.new(name+'__'+obj.name);fa.use_fake_user=True;key.animation_data.action=fa;actions[obj.name]=fa
    rows=[]
    for frame in range(n+1):
        scene.frame_set(frame);rows.append(sample(name,frame/30,duration))
        for pb in rig.pose.bones:
            pb.keyframe_insert(data_path='location',frame=frame,group=pb.name)
            pb.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=pb.name)
            pb.keyframe_insert(data_path='scale',frame=frame,group=pb.name)
        for obj in shapes:
            for key in obj.data.shape_keys.key_blocks[1:]:key.keyframe_insert(data_path='value',frame=frame)
    all_actions[name]=action;face_actions[name]=actions
    manifest[name]={'duration':duration,'frames':n+1,'root_motion':name=='Walk_Forward','loop':name in ['Idle','Walk_InPlace'],'max_ik_reach_error':max(r['max_ik_reach_error'] for r in rows)}
    records[name]=rows
    print('ANIM_AUTHORED',name,manifest[name],flush=True)

# Named NLA tracks merge matching rig and shape-key animation into one glTF clip.
rig.animation_data.action=None
for name,action in all_actions.items():
    tr=rig.animation_data.nla_tracks.new();tr.name=name;st=tr.strips.new(name,0,action);tr.mute=True
for obj in shapes:
    data=obj.data.shape_keys;data.animation_data.action=None
    for name,actions in face_actions.items():
        tr=data.animation_data.nla_tracks.new();tr.name=name;tr.strips.new(name,0,actions[obj.name]);tr.mute=True

def choose(name):
    rig.animation_data.action=all_actions[name]
    if all_actions[name].slots:rig.animation_data.action_slot=all_actions[name].slots[0]
    for obj in shapes:
        a=face_actions[name][obj.name];obj.data.shape_keys.animation_data.action=a
        if a.slots:obj.data.shape_keys.animation_data.action_slot=a.slots[0]
    scene.frame_start=0;scene.frame_end=round(clips[name]*30);scene.frame_set(0);update()

choose('Idle')
scene['milo_clips']=json.dumps(manifest)
(OUT/'animation_manifest.json').write_text(json.dumps(manifest,indent=2))
(OUT/'contact_samples.json').write_text(json.dumps(records))
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'milo_quality_v2.blend'))
print('ANIMATION_BUILD_OK',flush=True)
