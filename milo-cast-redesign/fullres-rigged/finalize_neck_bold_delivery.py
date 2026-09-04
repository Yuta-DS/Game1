"""Bind actual verification and freshly rendered media to the current GLB."""
from pathlib import Path
import json,hashlib
OUT=Path(__file__).resolve().parent
asset=OUT/'milo_fullres.glb'
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
sha=digest(asset)
def read(name):return json.loads((OUT/name).read_text())
summary=read('neck_bold_regression_summary.json');v=read('verification.json')
assert summary['sha256']==v['sha256']==sha
assert digest(OUT/'preview/milo_fullres.glb')==sha
contacts=read('hand_contact_verification.json')
grip=next(r for r in contacts if 'fingertip_pad_gap_m' in r)
checks=[{'name':row['script'],'passed':row['passed'],**({'error':row['error']} if 'error' in row else {})} for row in summary['checks']]
hand_max=max(max(a['hand_max_edge_stretch'].values()) for a in v['animations'].values())
body_max=max(a['max_edge_stretch'] for a in v['animations'].values())
checks.extend([
    {'name':'hand_edge_stretch_under_3x','passed':hand_max<3,'observed':hand_max},
    {'name':'full_character_edge_stretch_under_3x','passed':body_max<3,'observed':body_max,'note':'Pre-existing raised-arm sleeve distortion remains outside this edit.'},
    {'name':'sampled_hand_self_intersection','passed':all(r['nonadjacent_surface_intersections']==0 for r in contacts),'samples':len(contacts),'failing_samples':sum(r['nonadjacent_surface_intersections']>0 for r in contacts)},
    {'name':'all_cane_pad_clearances_under_3mm','passed':max(grip['fingertip_pad_gap_m'].values())<.003,'clearances_m':grip['fingertip_pad_gap_m']},
])
godot=OUT/'preview/godot_import_verification.json'
assert godot.stat().st_mtime>asset.stat().st_mtime,'Stale Godot test report'
assert all(c in read('preview/godot_import_verification.json') for c in ('Idle','Walking_A','Greet','Guide','Speak','Cane_Hold','Hand_Mechanics'))
checks.append({'name':'godot_seven_clip_import','passed':True,'evidence':'preview/godot_import_verification.json'})
names=['hero.jpg','front.jpg','side.jpg','back.jpg','face.jpg','paws.jpg','turnaround.jpg','relaxed_paw.jpg','greeting_hand.jpg','cane_grip.jpg','cane_grip_inside.jpg','cast_eye_comparison.jpg','milo_motion.mp4','milo_hand_mechanics.mp4','godot_preview.png','godot_hand_Greet.png','godot_hand_Cane_Hold.png','godot_hand_Hand_Mechanics.png']
names += ['neck_detail.jpg']
names += [f'pose_{clip}.jpg' for clip in ('Idle','Walking_A','Greet','Guide','Speak','Cane_Hold')]
names += [f'face_{state}.jpg' for state in ('open','closing','blink','reopened')]
names += [p.name for p in OUT.glob('mechanics_*.jpg')]
media={}
for name in names:
    path=OUT/name
    assert path.is_file() and path.stat().st_size>0,name
    assert path.stat().st_mtime>asset.stat().st_mtime,('Stale preview',name)
    media[name]={'sha256':digest(path),'bytes':path.stat().st_size}
(OUT/'delivery_media_manifest.json').write_text(json.dumps({'asset_sha256':sha,'media':media},indent=2))
checks.append({'name':'fresh_actual_model_media','passed':True,'files':len(media),'evidence':'delivery_media_manifest.json'})
gate={'passed':all(c['passed'] for c in checks),'asset':asset.name,'sha256':sha,'scope':'Local neck/jaw transition and bold central moustache revision; all other geometry and all animation channels preserved. Not a live-game replacement or exact-match approval.','checks':checks,'visual_review':'NECK_BOLD_REVIEW.md','regression_summary':'neck_bold_regression_summary.json','not_claimed':['full AnyCreature quality-gate pass','exact reference match or user approval','force-solved grasp','arbitrary-pose or full-character collision freedom','production LOD or live-game integration','Blender MCP execution','commit, push, upload or deployment']}
(OUT/'gate.json').write_text(json.dumps(gate,indent=2))
print(json.dumps({'sha256':sha,'gate_passed':gate['passed'],'failures':[c for c in checks if not c['passed']],'media_files':len(media),'meshes':v['mesh_objects'],'bones':v['bones'],'triangles':v['triangles']},indent=2))
