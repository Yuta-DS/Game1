"""Render full, consecutive motion frames (30 fps), never pose montages."""
from pathlib import Path
import sys,json,subprocess,tempfile
import bpy
from mathutils import Vector
OUT=Path(__file__).resolve().parent;sys.path.insert(0,str(OUT))
from review import load,select_clip,aim
scene=load();scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=16
scene.render.resolution_x=640;scene.render.resolution_y=800
scene.render.image_settings.file_format='JPEG';scene.render.image_settings.quality=95;scene.render.fps=30
camera=scene.camera
jobs=[('walk','Walk_Forward',144),('welcome','Welcome',96),('speak','Speak',120),('listen','Listen',120),('idle','Idle',120)]
requested=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
if requested:jobs=[job for job in jobs if job[0] in requested]
for slug,clip,count in jobs:
    # Stream one small temporary image at a time; never accumulate frame folders.
    temp=tempfile.TemporaryDirectory(prefix='milo-render-',dir=str(OUT))
    scratch=Path(temp.name)/'frame.jpg'
    proc=subprocess.Popen(['/opt/homebrew/bin/ffmpeg','-hide_banner','-loglevel','error','-y','-f','image2pipe','-framerate','30','-i','pipe:0','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/(slug+'.mp4'))],stdin=subprocess.PIPE)
    select_clip(clip)
    if slug=='walk':
        camera.location=(3.3,-5.7,2.65);aim(camera,(0,-.63,1.02));camera.data.ortho_scale=2.85
    else:
        camera.location=(2.8,-6.4,2.5);aim(camera,(0,0,1.07));camera.data.ortho_scale=2.6
    for frame in range(count):
        scene.frame_set(frame);scene.render.filepath=str(scratch)
        bpy.ops.render.render(write_still=True)
        proc.stdin.write(scratch.read_bytes())
        if frame%30==0:print('MOTION_PROGRESS',slug,frame,count,flush=True)
    proc.stdin.close()
    if proc.wait()!=0:raise RuntimeError('Video encoding failed: '+slug)
    temp.cleanup()
print('MOTION_FRAMES_OK',flush=True)
