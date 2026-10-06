"""Keep cast gait, stabilize the cane arm, bake exact loops and mentor gestures."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector,Matrix,Quaternion
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'milo_cast.blend'));scene=bpy.context.scene;rig=bpy.data.objects['Milo_Cast_Rig'];ad=rig.animation_data
sources={tr.name:(tr.strips[0].action,tr.strips[0].action_slot) for tr in ad.nla_tracks}
for tr in ad.nla_tracks:tr.mute=True
def source(name,phase):
    act,slot=sources[name];ad.action=act;ad.action_slot=slot
    frame=act.frame_range[1]*phase;scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
source('Idle',0)
idle={b.name:b.matrix.copy() for b in rig.pose.bones}
idle_basis={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
def orient(bone,head,tail):
    rest=bone.bone.matrix_local.to_quaternion();d=(bone.bone.tail_local-bone.bone.head_local).normalized();q=d.rotation_difference((tail-head).normalized())@rest
    bone.matrix=Matrix.LocRotScale(head,q,Vector((1,1,1)));bpy.context.view_layer.update()
def cane_arm(phase,walking):
    # Analytic two-link IK. Keep joint lengths, never stretch the arm to the staff.
    upper=rig.pose.bones['upperarm.r'];lower=rig.pose.bones['lowerarm.r'];wrist=rig.pose.bones['wrist.r']
    a=upper.head.copy();target=idle['wrist.r'].translation.copy()
    if walking:
        target.y+=.038*math.sin(phase*math.tau);target.z+=.018+.045*(1-math.cos(phase*math.tau))*.5
    delta=target-a;dist=delta.length;l1=upper.bone.length;l2=lower.bone.length;dist=min(l1+l2-.0001,max(abs(l1-l2)+.0001,dist));d=delta.normalized();target=a+d*dist
    # Preferred elbow plane from relaxed idle. Cross-axis fallback for a straight arm.
    pole=idle['lowerarm.r'].translation-a;pole-=d*pole.dot(d)
    if pole.length<1e-5:pole=Vector((-.5,.6,0));pole-=d*pole.dot(d)
    pole.normalize();along=(l1*l1-l2*l2+dist*dist)/(2*dist);height=math.sqrt(max(0,l1*l1-along*along));elbow=a+d*along+pole*height
    orient(upper,a,elbow);orient(lower,elbow,target)
    wrist.matrix=Matrix.LocRotScale(target,idle['wrist.r'].to_quaternion(),Vector((1,1,1)))
    rig.pose.bones['hand.r'].matrix_basis=idle_basis['hand.r'];bpy.context.view_layer.update()

jobs=[('Idle',72,True),('Walking_A',32,True),('Guide',72,False),('Speak',72,True)]
baked={};manifest={}
for name,count,loop in jobs:
    records=[]
    for f in range(count+1):
        phase=f/count;p=0 if f==count and loop else phase
        source('Walking_A' if name=='Walking_A' else 'Idle',p)
        if name=='Guide':
            gesture=math.sin(math.pi*p)**2
            b=rig.pose.bones['upperarm.l'];b.rotation_quaternion=b.rotation_quaternion@Quaternion((0,0,1),-.40*gesture)
            b=rig.pose.bones['lowerarm.l'];b.rotation_quaternion=b.rotation_quaternion@Quaternion((1,0,0),-.30*gesture)
            b=rig.pose.bones['head'];b.rotation_quaternion=b.rotation_quaternion@Quaternion((0,1,0),-.11*gesture)
        if name=='Speak':
            b=rig.pose.bones['head'];b.rotation_quaternion=b.rotation_quaternion@Quaternion((1,0,0),.035*math.sin(p*math.tau*2))
            b=rig.pose.bones['chest'];b.rotation_quaternion=b.rotation_quaternion@Quaternion((0,1,0),.018*math.sin(p*math.tau))
        bpy.context.view_layer.update();cane_arm(p,name=='Walking_A')
        # Keep the lowest boot at ground level (original cast walk dips ~2.6 cm).
        dg=bpy.context.evaluated_depsgraph_get();lowest=0
        for o in bpy.data.objects:
            if o.type=='MESH' and o.name.startswith('Milo_Leg'):
                e=o.evaluated_get(dg);m=e.to_mesh();lowest=min(lowest,min((e.matrix_world@v.co).z for v in m.vertices));e.to_mesh_clear()
        root=rig.pose.bones['root'];root_matrix=root.matrix.copy();root_matrix.translation.z+=-lowest;root.matrix=root_matrix
        bpy.context.view_layer.update()
        records.append({b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in rig.pose.bones})
    baked[name]=records;manifest[name]={'frames':count,'duration':count/24,'loop':loop,'source':'Rogue Walking_A, cane-arm IK' if name=='Walking_A' else 'Rogue Idle with restrained mentor gestures'}

for tr in list(ad.nla_tracks):ad.nla_tracks.remove(tr)
ad.action=None;newactions={}
for name,records in baked.items():
    for a in bpy.data.actions:
        if a.name==name:a.name='Source_'+name
    act=bpy.data.actions.new(name);ad.action=act
    for f,record in enumerate(records):
        scene.frame_set(f)
        for b in rig.pose.bones:
            b.rotation_mode='QUATERNION';b.location,b.rotation_quaternion,b.scale=record[b.name]
            for path in ('location','rotation_quaternion','scale'):b.keyframe_insert(data_path=path,frame=f,group=b.name)
    slot=ad.action_slot
    for layer in act.layers:
        for strip in layer.strips:
            bag=strip.channelbag(slot)
            for curve in bag.fcurves:
                for key in curve.keyframe_points:key.interpolation='LINEAR'
    newactions[name]=(act,slot);tr=ad.nla_tracks.new();tr.name=name;strip=tr.strips.new(name,0,act);strip.action_slot=slot;tr.mute=True
ad.action=None
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    if o==rig or o.type=='MESH':o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'milo_cast.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_materials='EXPORT',export_skins=True,export_def_bones=False,export_yup=True)
ad.action,ad.action_slot=newactions['Idle'];scene.frame_set(0);scene.frame_start=0;scene.frame_end=72
# Save without creating an accumulating backup on a nearly full user disk.
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'milo_cast.blend'))
(OUT/'animation_manifest.json').write_text(json.dumps(manifest,indent=2))
print('CAST_ANIMATION_POLISH_DONE',flush=True)
