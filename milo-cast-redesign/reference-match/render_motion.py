"""All four existing actions, evaluated from the exported reference-model GLB."""
from pathlib import Path
import bpy,runpy,sys,subprocess,tempfile,json,math
OUT=Path(__file__).resolve().parent
sys.argv=['review','--','hero'];runpy.run_path(str(OUT/'render_review.py'))
scene=bpy.context.scene;scene.render.resolution_x=480;scene.render.resolution_y=600;scene.eevee.taa_render_samples=16;scene.render.image_settings.quality=93;scene.render.fps=24
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');ad=rig.animation_data;tracks={tr.name:tr for tr in ad.nla_tracks}
targets=[o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('Milo_Reference')];assert len(targets)==11
for tr in ad.nla_tracks:tr.mute=True
bad=0;bounds={};temp=tempfile.TemporaryDirectory(prefix='milo-review-frame-',dir=str(OUT));scratch=Path(temp.name)/'frame.jpg'
proc=subprocess.Popen(['/opt/homebrew/bin/ffmpeg','-hide_banner','-loglevel','error','-y','-f','image2pipe','-framerate','24','-i','pipe:0','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/'milo_reference_motion.mp4')],stdin=subprocess.PIPE)
try:
    for name,count,period in [('Idle',24,72),('Walking_A',64,32),('Guide',72,72),('Speak',72,72)]:
        strip=tracks[name].strips[0];ad.action=strip.action;ad.action_slot=strip.action_slot
        for frame in range(count):
            scene.frame_set(frame%period);dg=bpy.context.evaluated_depsgraph_get()
            for obj in targets:
                e=obj.evaluated_get(dg);m=e.to_mesh();bound=bounds.setdefault(obj.name,{'min_z':1e9,'max_z':-1e9})
                for v in m.vertices:
                    p=e.matrix_world@v.co;bad+=not all(math.isfinite(x) for x in p);bound['min_z']=min(bound['min_z'],p.z);bound['max_z']=max(bound['max_z'],p.z)
                e.to_mesh_clear()
            scene.render.filepath=str(scratch);bpy.ops.render.render(write_still=True);content=scratch.read_bytes();proc.stdin.write(content)
            if (name=='Walking_A' and frame in (0,8,16,24)) or (name=='Guide' and frame in (18,36)):(OUT/(name+'_'+str(frame)+'.jpg')).write_bytes(content)
            if frame%24==0:print('REFERENCE_MOTION',name,frame,flush=True)
    proc.stdin.close()
    if proc.wait()!=0:raise RuntimeError('Encoder failed')
finally:
    if proc.poll() is None:proc.terminate();proc.wait()
    temp.cleanup()
(OUT/'motion_check.json').write_text(json.dumps({'rendered_frames':232,'fps':24,'non_finite_vertices':bad,'bounds':bounds,'limits':'No Godot collision or facial/finger articulation validation'},indent=2))
if bad:raise RuntimeError('Non-finite evaluated vertices')
print('REFERENCE_MOTION_DONE',flush=True)
