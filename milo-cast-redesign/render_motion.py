"""Render consecutive exported-GLB frames; stream without accumulating frames."""
from pathlib import Path
import sys,runpy,subprocess,tempfile
import bpy
OUT=Path(__file__).resolve().parent
sys.argv=['review','--','hero'];runpy.run_path(str(OUT/'render_review.py'))
scene=bpy.context.scene;scene.render.resolution_x=560;scene.render.resolution_y=700;scene.eevee.taa_render_samples=16;scene.render.fps=24;scene.render.image_settings.file_format='JPEG';scene.render.image_settings.quality=95
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');ad=rig.animation_data
tracks={tr.name:tr for tr in ad.nla_tracks}
for tr in ad.nla_tracks:tr.mute=True
temp=tempfile.TemporaryDirectory(prefix='motion-frame-',dir=str(OUT));scratch=Path(temp.name)/'frame.jpg'
proc=subprocess.Popen(['/opt/homebrew/bin/ffmpeg','-hide_banner','-loglevel','error','-y','-f','image2pipe','-framerate','24','-i','pipe:0','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/'motion.mp4')],stdin=subprocess.PIPE)
for name,count,period in [('Idle',72,72),('Walking_A',64,32),('Guide',72,72),('Speak',72,72)]:
    strip=tracks[name].strips[0];ad.action=strip.action;ad.action_slot=strip.action_slot
    for frame in range(count):
        scene.frame_set(frame%period);scene.render.filepath=str(scratch);bpy.ops.render.render(write_still=True);content=scratch.read_bytes();proc.stdin.write(content)
        if frame in (0,period//4,period//2,period*3//4):(OUT/(name+'_'+str(frame)+'.jpg')).write_bytes(content)
        if frame%24==0:print('MOTION_PROGRESS',name,frame,count,flush=True)
proc.stdin.close()
if proc.wait()!=0:raise RuntimeError('Video encoding failed')
temp.cleanup();print('MOTION_RENDER_DONE',flush=True)
