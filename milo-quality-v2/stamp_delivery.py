"""Preserve real results and hashes. Never label a partial gate a full pass."""
from pathlib import Path
import json,hashlib,subprocess
OUT=Path(__file__).resolve().parent
blender=json.loads((OUT/'blender_validation.json').read_text())
glb=json.loads((OUT/'glb_validation.json').read_text())
visual=json.loads((OUT/'visual_review.json').read_text())
checks=[dict(c,source=source) for source,report in [('Blender',blender),('glTF',glb)] for c in report['checks']]
videos={}
for slug,expected in [('walk',144),('welcome',96),('speak',120),('listen',120),('idle',120)]:
    path=OUT/(slug+'.mp4')
    probe=subprocess.run(['/opt/homebrew/bin/ffprobe','-v','error','-show_entries','format=duration:stream=width,height,r_frame_rate,nb_frames','-of','json',str(path)],capture_output=True,text=True,check=True)
    meta=json.loads(probe.stdout);stream=meta['streams'][0]
    decoded=subprocess.run(['/opt/homebrew/bin/ffmpeg','-v','error','-i',str(path),'-f','null','-'],capture_output=True,text=True)
    ok=stream['nb_frames']==str(expected) and stream['r_frame_rate']=='30/1' and decoded.returncode==0
    checks.append({'name':slug+'_continuous_video','passed':ok,'source':'ffprobe and ffmpeg decode','frames':int(stream['nb_frames']),'fps':30})
    videos[slug]=meta
checks.append({'name':'independent_high_polish_review','passed':visual['rounds'][-1]['high_polish_passed'],'source':'Independent image-only reader','unresolved':visual['rounds'][-1]['unresolved']})
hashes={name:hashlib.sha256((OUT/name).read_bytes()).hexdigest() for name in ['milo_quality_v2.blend','milo_quality_v2.glb','hero.png','face_closeup.png','walk.mp4','welcome.mp4','speak.mp4','listen.mp4','idle.mp4']}
report={'passed':all(c['passed'] for c in checks),'local_mechanical_checks_passed':blender['passed'] and glb['passed'],'status':'local_review_prototype','full_anycreature_gate':'not_certified','live_game_integration':'not_performed','checks':checks,'sha256':hashes}
(OUT/'video_validation.json').write_text(json.dumps(videos,indent=2))
(OUT/'gate.json').write_text(json.dumps(report,indent=2))
print(json.dumps({'mechanical_checks_passed':report['local_mechanical_checks_passed'],'high_polish_gate_passed':report['passed'],'video_files':len(videos),'unresolved':visual['rounds'][-1]['unresolved']},indent=2))
