"""Dedicated FK deform rig, analytical two-link posing, fully baked clips.

No runtime constraints or donor-warrior animation are required by the GLB.
All distances are metres and the walk is in-place (caller supplies locomotion).
"""
from mathutils import Matrix, Quaternion
ad=bpy.data.armatures.new('Milo_Reference_Deform_Rig')
rig=bpy.data.objects.new('MiloReferenceRig',ad);scene.collection.objects.link(rig)
select(rig);bpy.ops.object.mode_set(mode='EDIT')
def bone(name,h,t,parent=None,deform=True):
    b=ad.edit_bones.new(name);b.head=h;b.tail=t;b.use_deform=deform
    if parent:b.parent=ad.edit_bones[parent]
    return b
bone('root',(0,0,0),(0,0,.12))
bone('hips',(0,0,.43),(0,0,.64),'root')
bone('spine',(0,0,.64),(0,0,.82),'hips')
bone('chest',(0,0,.82),(0,0,.965),'spine')
bone('neck',(0,0,.965),(0,0,1.04+HEAD_SEAT_Z),'chest')
bone('head',(0,0,1.04+HEAD_SEAT_Z),(0,0,1.61+HEAD_SEAT_Z),'neck')
bone('jaw',(0,-.19,1.077+HEAD_SEAT_Z),(0,-.26,1.005+HEAD_SEAT_Z),'head')
for s,label in ((-1,'R'),(1,'L')):
    eye_center=Vector(EYE_CENTERS[label])
    bone('eye.'+label,eye_center,eye_center+Vector((0,0,.068)),'head')
    bone('brow.'+label,(s*.18,-.20,1.45+HEAD_SEAT_Z),(s*.18,-.20,1.51+HEAD_SEAT_Z),'head')
    bone('ear.'+label,(s*.33,.01,1.56+HEAD_SEAT_Z),(s*.38,.02,1.74+HEAD_SEAT_Z),'head')
    bone('upperarm.'+label,(s*.263,0,.855),(s*.372,-.008,.714),'chest')
    bone('forearm.'+label,(s*.372,-.008,.714),(s*.443,-.018,.553),'upperarm.'+label)
    bone('hand.'+label,(s*.443,-.018,.553),(s*.470,-.023,.445),'forearm.'+label).align_roll(HAND_FRAMES[label][1].col[2])
    for name,(h,t,parent) in HAND_CHAINS[label].items():
        bone(name,h,t,parent).align_roll(HAND_FRAMES[label][1].col[2])
    bone('thigh.'+label,(s*.225,.025,.43),(s*.225,-.015,.273),'hips')
    bone('shin.'+label,(s*.225,-.015,.273),(s*.225,.005,.135),'thigh.'+label)
    bone('foot.'+label,(s*.225,.005,.135),(s*.225,-.135,.05),'shin.'+label)
    bone('coat.'+label,(s*.22,0,.61),(s*.27,0,.30),'hips')
tailpoints=[(0,.21,.39),(.07,.34,.28),(.18,.46,.21),(.27,.57,.29)]
for i in range(3):bone('tail.%02d'%i,tailpoints[i],tailpoints[i+1],'hips' if i==0 else 'tail.%02d'%(i-1))
bone('cane',(-.56,-.16,.03),(-.56,-.16,.63),'root')
bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True;ad.display_type='OCTAHEDRAL'
rest={b.name:b.matrix_local.copy() for b in ad.bones}
heads={b.name:b.head_local.copy() for b in ad.bones};tails={b.name:b.tail_local.copy() for b in ad.bones}
for pb in rig.pose.bones:pb.rotation_mode='QUATERNION'
def clamp(v):return max(0,min(1,v))
def smooth(v):v=clamp(v);return v*v*(3-2*v)
def torso_weights(v):
    if v.z<.72:
        side=smooth((v.x+.13)/.26);skirt=1-smooth((v.z-.48)/.20);spine=smooth((v.z-.61)/.11)
        return {'coat.L':(1-spine)*skirt*side,'coat.R':(1-spine)*skirt*(1-side),'hips':(1-spine)*(1-skirt),'spine':spine}
    if v.z<.85:
        t=smooth((v.z-.72)/.13);return {'spine':1-t,'chest':t}
    return {'chest':1}
def arm_weights(v,label):
    axis=(heads['hand.'+label]-heads['upperarm.'+label]);u=(v-heads['upperarm.'+label]).dot(axis)/axis.length_squared
    shoulder=smooth((u+.23)/.32)
    elbow=smooth((u-.35)/.32)
    # Distribute wrist rotation through the forearm fabric instead of
    # concentrating it in a short strip immediately above the cuff.
    wrist=smooth((u-.30)/.65)
    return {'chest':1-shoulder,'upperarm.'+label:shoulder*(1-elbow),'forearm.'+label:shoulder*elbow*(1-wrist),'hand.'+label:shoulder*elbow*wrist}
def assign(o,fn):
    o.vertex_groups.clear()
    for v in o.data.vertices:
        weights={n:w for n,w in fn(v.co).items() if w>1e-6};total=sum(weights.values())
        for n,w in weights.items():
            g=o.vertex_groups.get(n) or o.vertex_groups.new(name=n);g.add([v.index],w/total,'REPLACE')
    mod=o.modifiers.new('Milo weighted deformation','ARMATURE');mod.object=rig
    o.parent=rig
for o in meshes:
    name=o.name
    if name.startswith('Milo_Articulated_Paw.'):
        mod=o.modifiers.new('Milo weighted deformation','ARMATURE');mod.object=rig;o.parent=rig
        continue # Keep authored per-loop skin weights from hands.py.
    center=sum((v.co for v in o.data.vertices),Vector())/max(1,len(o.data.vertices));label='L' if center.x>=0 else 'R'
    fn=lambda v:{'head':1}
    if name.startswith(('Eye_','EyeGlint')):fn=lambda v,l=label:{'eye.'+l:1}
    elif name.startswith('Brow_'):fn=lambda v,l=label:{'brow.'+l:1}
    elif name.startswith('Ear'):fn=lambda v,l=label:{'ear.'+l:1}
    elif name=='Mouth':fn=lambda v:{'jaw':1}
    elif name=='Chin':
        def fn(v):
            jaw=smooth((-.10-v.y)/.10)*smooth((v.z-(1.015+HEAD_SEAT_Z))/.045)
            return {'jaw':jaw,'head':1-jaw}
    elif name=='Neck_Transition':
        def fn(v):
            upper=smooth((v.z-.987)/.090)
            lower=smooth((v.z-.938)/.048)
            return {'chest':(1-lower)*(1-upper),'neck':lower*(1-upper),'head':upper}
    elif name.startswith('Milo_Paw_'):fn=lambda v,l=label:{'hand.'+l:1}
    elif name.startswith(('Milo_Broad_Cuff','Milo_Cuff_','Milo_Linen_Cuff')):fn=lambda v,l=label:{'hand.'+l:1}
    elif name.startswith('Milo_Sleeve'):fn=lambda v,l=label:arm_weights(v,l)
    elif name.startswith(('Milo_Sculpt_Boot','Milo_Boot_')):fn=lambda v,l=label:{'foot.'+l:1}
    elif name.startswith('Milo_Trouser'):
        def fn(v,l=label):
            t=smooth((.315-v.z)/.09);return {'thigh.'+l:1-t,'shin.'+l:t}
    elif name=='Milo_Sculpt_Tail':
        def fn(v):
            t=clamp((v.y-.25)/.27)*2;i=min(1,int(t));u=t-i
            return {'tail.%02d'%i:1-u,'tail.%02d'%(i+1):u}
    elif name.startswith(('Milo_','Pin_')):
        fn=torso_weights
        if o.get('rigid_accessory') or 'Button' in name or name.startswith(('Pin_','Milo_Coat_Welt','Milo_Pocket_','Milo_Cravat','Milo_Gold_Tie')):
            weights=torso_weights(center);fn=lambda v,w=weights:w
    assign(o,fn)

# Cane is an optional separate skinned accessory. Runtime preview toggles it.
cane_parts=[]
cane_parts.append(tube('Cane_Shaft',[(-.56,-.16,.018),(-.56,-.16,.615)],[.010,.014],leather,12))
cane_parts.append(tube('Cane_Gold_Ferrule',[(-.56,-.16,.008),(-.56,-.16,.049)],[.011,.0105],gold,12))
cane_parts.append(tube('Cane_Gold_Collar',[(-.56,-.16,.591),(-.56,-.16,.626)],[.019,.019],gold,12))
curvepts=path([(-.56,-.16,.619),(-.568,-.208,.684),(-.548,-.235,.701),(-.514,-.237,.686),(-.514,-.232,.667)],7)
cane_parts.append(tube('Cane_Gold_Crook',curvepts,[.016]*len(curvepts),gold,12))
for o in cane_parts:assign(o,lambda v:{'cane':1});o['optional_accessory']='Hide except Cane_Hold preview'
meshes+=cane_parts

def set_segment(name,h,t):
    h=Vector(h);t=Vector(t)
    q=(tails[name]-heads[name]).rotation_difference(t-h)
    m=(q.to_matrix()@rest[name].to_3x3()).to_4x4();m.translation=h
    rig.pose.bones[name].matrix=m;bpy.context.view_layer.update()
def transformed_point(parent,p):return rig.pose.bones[parent].matrix@rest[parent].inverted()@Vector(p)
def solve_limb(root,target,length1,length2,bend):
    d=target-root;dist=d.length;axis=d.normalized();dist=min(length1+length2-.00001,max(abs(length1-length2)+.00001,dist))
    along=(length1*length1-length2*length2+dist*dist)/(2*dist)
    side=Vector(bend)-axis*Vector(bend).dot(axis);side.normalize()
    mid=root+axis*along+side*math.sqrt(max(0,length1*length1-along*along))
    return mid,root+axis*dist
def rot(name,axis,angle):rig.pose.bones[name].rotation_quaternion=Quaternion(axis,math.radians(angle))
exec(compile((OUT/'hand_motion.py').read_text(),str(OUT/'hand_motion.py'),'exec'))
grip_settings=HAND_POSES['grasp']
if (OUT/'anatomical_grip_settings.json').exists():grip_settings=json.loads((OUT/'anatomical_grip_settings.json').read_text())
def pose(clip,t,duration):
    for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
    u=t/duration;phase=math.tau*u
    walk=clip=='Walking_A';gesture=math.sin(math.pi*u)**2
    bob=.004*(1-math.cos(phase*2)) if walk else .0025*math.sin(phase)
    rig.pose.bones['hips'].location.y=bob
    rot('spine',(0,1,0),.8*math.sin(phase))
    rot('chest',(1,0,0),.5*math.sin(phase))
    rot('head',(0,1,0),(-3*gesture if clip=='Guide' else .8*math.sin(phase)))
    if clip=='Speak':rot('jaw',(1,0,0),4*abs(math.sin(phase*4))*gesture)
    blink=max(0,1-abs(u-.64)/.025)
    for label in ('L','R'):
        rig.pose.bones['eye.'+label].scale.y=1-.94*blink
        rot('brow.'+label,(0,0,1),(-3 if label=='L' else 3)*gesture if clip in ('Greet','Speak') else 0)
    for i in range(3):rot('tail.%02d'%i,(0,1,0),4*math.sin(phase-i*.6))
    bpy.context.view_layer.update()
    if clip=='Cane_Hold':
        # Place the accessory within a comfortable reach of this short arm.
        # The back of the paw faces forward; fingers wrap toward the palm
        # behind it. Keep the cane inside this short arm's comfortable reach.
        offset=Vector((.098,.094,0))+Vector(grip_settings.get('cane_shift',(0,0,0)))
        set_segment('cane',heads['cane']+offset,tails['cane']+offset)
        # Turn the crook away from the sleeve; preserve the original prop
        # geometry and floor contact while opening room for the thumb.
        pb=rig.pose.bones['cane'];m=pb.matrix.copy()
        q=Quaternion((0,0,1),math.pi)@m.to_quaternion()
        turned=q.to_matrix().to_4x4();turned.translation=m.translation
        pb.matrix=turned;bpy.context.view_layer.update()
    for s,label in ((-1,'R'),(1,'L')):
        # In-place walk: constant-speed stance, eased lifted swing.
        p=(u+(0 if label=='L' else .5))%1
        y=.005;lift=0
        if walk:
            if p<.5:y=-.06+.24*p
            else:
                q=(p-.5)*2;y=.06-.12*smooth(q);lift=.043*math.sin(math.pi*q)**2
        ankle=Vector((s*.225,y,.135+lift))
        root=transformed_point('hips',heads['thigh.'+label])
        l1=(tails['thigh.'+label]-heads['thigh.'+label]).length;l2=(tails['shin.'+label]-heads['shin.'+label]).length
        mid,end=solve_limb(root,ankle,l1,l2,(0,-1,0))
        set_segment('thigh.'+label,root,mid);set_segment('shin.'+label,mid,end)
        set_segment('foot.'+label,end,end+(tails['foot.'+label]-heads['foot.'+label]))
        rot('coat.'+label,(1,0,0),(2.4*math.sin(phase+s*.4) if walk else .35*math.sin(phase)))
        # Hand target arcs are solved with fixed bone lengths, not stretched limbs.
        root=transformed_point('chest',heads['upperarm.'+label])
        target=transformed_point('chest',heads['hand.'+label])
        handdir=tails['hand.'+label]-heads['hand.'+label]
        if walk:target.y+=.030*math.sin(phase+(0 if label=='L' else math.pi));target.z+=.005
        if clip in ('Greet','Hand_Mechanics') and label=='L':
            raised=1 if clip=='Hand_Mechanics' else gesture
            # Lift the forearm too: an upright palm above a horizontal
            # forearm hyperextends the wrist and drives the cuff into skin.
            target=target.lerp(Vector((.57,-.10,.95)),raised)
            # Let the forearm rise before opening the wrist. Linear hand
            # direction interpolation turned the palm upward too early.
            handdir=handdir.lerp(Vector((.085,-.005,.080)),raised*raised)
        if clip=='Guide' and label=='L':
            target=target.lerp(Vector((.54,-.19,.89)),gesture)
            handdir=handdir.lerp(Vector((.09,-.018,.015)),gesture)
        if clip=='Speak':
            target=target.lerp(Vector((s*.46,-.15,.72)),gesture*(.65+.15*math.sin(phase*2+s)))
            handdir=handdir.lerp(Vector((s*.06,-.04,.04)),gesture*.7)
        if clip=='Cane_Hold' and label=='R':
            # Reachable wrist target: the shaft lies inside the fingers' curl
            # arc, not outside their tips. Grip sits below the gold crook.
            target=Vector((-.395,-.110,.535));handdir=Vector((-.110,0,0))
        l1=(tails['upperarm.'+label]-heads['upperarm.'+label]).length;l2=(tails['forearm.'+label]-heads['forearm.'+label]).length
        bend=(0,-1,.15) if clip=='Cane_Hold' and label=='R' else (s,-.16,.03)
        mid,end=solve_limb(root,target,l1,l2,bend)
        set_segment('upperarm.'+label,root,mid);set_segment('forearm.'+label,mid,end);set_segment('hand.'+label,end,end+handdir)
        # Explicit palm plane prevents arbitrary shortest-arc wrist twist.
        if (clip in ('Greet','Hand_Mechanics') and label=='L') or (clip=='Cane_Hold' and label=='R'):
            yy=handdir.normalized()
            # Local +Z is the PALM, not the back. Show palm for the wave;
            # show dorsal knuckles for the cane grip.
            zz=Vector((0,-1 if clip in ('Greet','Hand_Mechanics') else 1,0));zz=(zz-yy*zz.dot(yy)).normalized();xx=yy.cross(zz).normalized()
            orient=Matrix((xx,yy,zz)).transposed().to_quaternion()
            pb=rig.pose.bones['hand.'+label];q=pb.matrix.to_quaternion().slerp(orient,gesture if clip=='Greet' else 1)
            m=q.to_matrix().to_4x4();m.translation=end;pb.matrix=m;bpy.context.view_layer.update()
        settings=HAND_POSES['relaxed']
        if clip=='Greet' and label=='L':settings=blend_hand(settings,HAND_POSES['open'],gesture)
        if clip=='Guide' and label=='L':settings=blend_hand(settings,HAND_POSES['point'],gesture)
        if clip=='Speak':settings=blend_hand(settings,HAND_POSES['open'],.38*gesture)
        if clip=='Cane_Hold' and label=='R':settings=grip_settings
        if clip=='Hand_Mechanics' and label=='L':settings=mechanics_demo(u)
        apply_hand(rig,label,settings)
    bpy.context.view_layer.update()

scene.render.fps=24
clips={'Idle':4.0,'Walking_A':2.0,'Greet':3.0,'Guide':3.0,'Speak':4.0,'Cane_Hold':4.0,'Hand_Mechanics':6.0}
rig.animation_data_create()
for clip,duration in clips.items():
    action=bpy.data.actions.new(clip);rig.animation_data.action=action
    count=round(duration*24)
    for f in range(count+1):
        scene.frame_set(f);pose(clip,f/24,duration)
        for pb in rig.pose.bones:
            pb.keyframe_insert('location',frame=f,group=pb.name)
            pb.keyframe_insert('rotation_quaternion',frame=f,group=pb.name)
            pb.keyframe_insert('scale',frame=f,group=pb.name)
    track=rig.animation_data.nla_tracks.new();track.name=clip
    strip=track.strips.new(clip,0,action);strip.action_frame_start=0;strip.action_frame_end=count
    track.mute=True
    action['loop']=clip in ('Idle','Walking_A','Speak','Cane_Hold')
rig.animation_data.action=None
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
scene.frame_start=0;scene.frame_end=96;scene.frame_set(0)
rig['motion_note']='Walking_A in-place, 0.12 m stance travel per second; apply matching forward locomotion. Optional cane accessory only for Cane_Hold.'
rig['controls']='Editable FK: three palm rays per hand; MCP/PIP/DIP finger joints; CMC/MCP/IP thumb joints; existing body/face controls. hand_motion.py provides limited anatomical pose presets.'
(OUT/'hand_anatomy.json').write_text(json.dumps(HAND_ANATOMY,indent=2))
(OUT/'animation_manifest.json').write_text(json.dumps({'fps':24,'clips':clips,'bones':len(ad.bones),'walk_speed_m_s':.12,'walk_root_motion':False,'plugin':'Blender CLI fallback; MCP disconnected'},indent=2))
