"""Exported outfit animation test; only one temporary frame on disk."""
from pathlib import Path
import bpy,sys,runpy,tempfile,subprocess,json,math
OUT=Path(__file__).resolve().parent
sys.argv=['render','--','hero'];runpy.run_path(str(OUT/'render_outfit.py'))
scene=bpy.context.scene;scene.render.resolution_x=480;scene.render.resolution_y=600;scene.eevee.taa_render_samples=16;scene.render.image_settings.file_format='JPEG';scene.render.image_settings.quality=94;scene.render.fps=24
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');ad=rig.animation_data;tracks={tr.name:tr for tr in ad.nla_tracks}
for tr in ad.nla_tracks:tr.mute=True
temp=tempfile.TemporaryDirectory(prefix='outfit-frame-',dir=str(OUT));scratch=Path(temp.name)/'frame.jpg'
proc=subprocess.Popen(['/opt/homebrew/bin/ffmpeg','-hide_banner','-loglevel','error','-y','-f','image2pipe','-framerate','24','-i','pipe:0','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/'outfit_motion.mp4')],stdin=subprocess.PIPE)
bad=0;min_z=1e9
for name,count,period in [('Idle',24,72),('Walking_A',64,32),('Guide',72,72),('Speak',72,72)]:
    strip=tracks[name].strips[0];ad.action=strip.action;ad.action_slot=strip.action_slot
    for frame in range(count):
        scene.frame_set(frame%period);dg=bpy.context.evaluated_depsgraph_get()
        outfit=next(o for o in bpy.data.objects if o.name.startswith('Milo_Luxury_Coat_and_Suit'));e=outfit.evaluated_get(dg);m=e.to_mesh()
        for v in m.vertices:
            p=e.matrix_world@v.co;bad+=not all(math.isfinite(x) for x in p);min_z=min(min_z,p.z)
        e.to_mesh_clear();scene.render.filepath=str(scratch);bpy.ops.render.render(write_still=True);content=scratch.read_bytes();proc.stdin.write(content)
        if (name=='Walking_A' and frame in (0,8,16,24)) or (name=='Guide' and frame==36):(OUT/(name+'_'+str(frame)+'.jpg')).write_bytes(content)
        if frame%24==0:print('OUTFIT_MOTION',name,frame,count,flush=True)
proc.stdin.close()
if proc.wait()!=0:raise RuntimeError('Video encoder failed')
temp.cleanup();(OUT/'motion_check.json').write_text(json.dumps({'rendered_frames':232,'fps':24,'non_finite_costume_vertices':bad,'minimum_costume_z':min_z,'terrain_contact':'not tested in Godot'},indent=2));print('OUTFIT_MOTION_DONE',flush=True)
