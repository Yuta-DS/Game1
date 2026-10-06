"""Render only the reimported GLB, including its baked clips."""
from pathlib import Path
OUT=Path(__file__).resolve().parent
source=(OUT/'render.py').read_text().split('modes=')[0]
exec(compile(source,str(OUT/'render.py'),'exec'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
actions={clip:next(a for a in bpy.data.actions if a.name.startswith(clip)) for clip in ('Idle','Walking_A','Greet','Guide','Speak','Cane_Hold','Hand_Mechanics')}
def clip(name,frame):
    rig.animation_data.action=actions[name]
    if actions[name].slots:rig.animation_data.action_slot=actions[name].slots[0]
    for o in bpy.data.objects:
        if o.name.startswith('Cane_'):o.hide_render=name!='Cane_Hold'
    scene.frame_set(frame);bpy.context.view_layer.update()
cam.location=(2.1,-8,2.0);aim(cam,(0,0,.92));cam.data.ortho_scale=2.12
scene.render.resolution_x=720;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.eevee.taa_render_samples=48
mode=sys.argv[-1] if '--' in sys.argv else 'poses'
def begin_video(folder,filename):
    # A streaming option avoids hundreds of intermediate images on a nearly
    # full disk. Only our unique temporary frame and final video are written.
    global frames,encoder,temporary_frame
    encoder=None;temporary_frame=None
    if '--stream' in sys.argv:
        import subprocess,tempfile,os
        descriptor,name=tempfile.mkstemp(prefix='_milo_frame_',suffix='.jpg',dir=OUT)
        os.close(descriptor);temporary_frame=Path(name)
        encoder=subprocess.Popen(['/opt/homebrew/bin/ffmpeg','-y','-hide_banner','-loglevel','error','-f','image2pipe','-vcodec','mjpeg','-framerate','12','-i','pipe:0','-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/filename)],stdin=subprocess.PIPE)
    else:
        frames=OUT/folder;frames.mkdir(exist_ok=True)
def video_frame(n):
    scene.render.filepath=str(temporary_frame if encoder else frames/('%04d.jpg'%n))
    bpy.ops.render.render(write_still=True)
    if encoder:encoder.stdin.write(temporary_frame.read_bytes())
def finish_video():
    if encoder:
        encoder.stdin.close()
        assert encoder.wait(timeout=30)==0,'Video encoding failed'
        temporary_frame.unlink()
if mode=='poses':
    for name,f in [('Idle',1),('Walking_A',13),('Greet',37),('Guide',37),('Speak',31),('Cane_Hold',1)]:
        clip(name,f);scene.render.filepath=str(OUT/('pose_'+name+'.jpg'));bpy.ops.render.render(write_still=True)
    clip('Cane_Hold',1);cam.location=(-2.2,-6,1.3);aim(cam,(-.51,-.02,.555));cam.data.ortho_scale=.55
    scene.render.filepath=str(OUT/'cane_grip.jpg');bpy.ops.render.render(write_still=True)
    cam.location=(-3.5,5,1.0);aim(cam,(-.51,-.02,.555))
    scene.render.filepath=str(OUT/'cane_grip_inside.jpg');bpy.ops.render.render(write_still=True)
    clip('Greet',37);cam.location=(1,-6,1.3);aim(cam,(.66,-.13,1.05));cam.data.ortho_scale=.55
    scene.render.filepath=str(OUT/'greeting_hand.jpg');bpy.ops.render.render(write_still=True)
    clip('Idle',1);cam.location=(2,-6,1.15);aim(cam,(.50,-.02,.45));cam.data.ortho_scale=.55
    scene.render.filepath=str(OUT/'relaxed_paw.jpg');bpy.ops.render.render(write_still=True)
elif mode in ('mechanics','mechanics_video'):
    scene.render.resolution_x=720;scene.render.resolution_y=900
    cam.data.ortho_scale=.55
    viewpoints=[('palm',(1,-6,1.3)),('side',(6,-1,1.5)),('back',(1,6,1.3))]
    if mode=='mechanics':
        for view,location in viewpoints:
            cam.location=location;aim(cam,(.66,-.13,1.05))
            for name,frame in [('open',0),('relaxed',39),('hook',72),('opposition',110)]:
                clip('Hand_Mechanics',frame)
                scene.render.filepath=str(OUT/('mechanics_'+view+'_'+name+'.jpg'));bpy.ops.render.render(write_still=True)
    else:
        begin_video('mechanics_frames','milo_hand_mechanics.mp4')
        scene.render.resolution_x=480;scene.render.resolution_y=600;scene.eevee.taa_render_samples=16;scene.render.image_settings.quality=88
        n=1
        for view,location in viewpoints:
            cam.location=location;aim(cam,(.66,-.13,1.05))
            for frame in range(0,144,2):
                clip('Hand_Mechanics',frame);video_frame(n);n+=1
        finish_video()
elif mode=='isolated':
    clip('Greet',36)
    for obj in bpy.data.objects:
        if obj.type=='MESH':obj.hide_render=obj.name!='Milo_Articulated_Paw.L'
    hand=rig.pose.bones['hand.L'];frame=rig.matrix_world@hand.matrix
    center=frame@Vector((0,.068,0))
    cam.data.ortho_scale=.22
    for view,direction in [('front',(0,.08,2)),('side',(2,.08,0)),('top',(0,2,.10)),('hero',(1.1,.7,2))]:
        cam.location=center+frame.to_3x3()@Vector(direction)
        aim(cam,center)
        scene.render.resolution_x=scene.render.resolution_y=640
        scene.render.filepath=str(OUT/('isolated_hand_'+view+'.jpg'));bpy.ops.render.render(write_still=True)
        scene.render.resolution_x=scene.render.resolution_y=48
        scene.render.filepath=str(OUT/('isolated_hand_'+view+'_48.jpg'));bpy.ops.render.render(write_still=True)
elif mode=='video':
    begin_video('motion_frames','milo_motion.mp4')
    scene.render.resolution_x=480;scene.render.resolution_y=600;scene.render.image_settings.quality=88;scene.eevee.taa_render_samples=16
    n=1
    for name,length in [('Idle',96),('Walking_A',48),('Walking_A',48),('Greet',72),('Guide',72),('Speak',96),('Cane_Hold',72)]:
        for f in range(1,length+1,2):
            clip(name,f);video_frame(n);n+=1
    finish_video()
    print('MOTION_FRAMES',n-1,flush=True)
