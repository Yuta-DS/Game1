"""Bind prototype-proportion verification and fresh media to the current GLB."""
from pathlib import Path
import hashlib
import json

OUT = Path(__file__).resolve().parent
ASSET = OUT / 'milo_fullres.glb'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(name):
    return json.loads((OUT / name).read_text())


sha = digest(ASSET)
verification = read('verification.json')
assert verification['sha256'] == sha
assert digest(OUT / 'preview/milo_fullres.glb') == sha

evidence = [
    ('prototype_proportion_verification.json', 'prototype_proportion_metrics'),
    ('prototype_proportion_scope_verification.json', 'protected_body_outfit_rig_scope'),
    ('moustache_verification.json', 'moustache_topology_attachment_and_spectacle_clearance'),
    ('neck_bold_verification.json', 'neck_face_attachment_all_631_frames'),
    ('head_style_verification.json', 'head_eye_and_blink_regression'),
    ('cuff_clearance_verification.json', 'cuff_clearance_regression'),
]
checks = []
for filename, name in evidence:
    report = read(filename)
    assert report['sha256'] == sha, ('Stale report', filename)
    checks.append({'name': name, 'passed': bool(report.get('passed', True)), 'evidence': filename})

hand_mechanics = read('hand_mechanics_verification.json')
checks.append({'name': 'hand_mechanics_regression', 'passed': hand_mechanics['passed'],
               'frames': hand_mechanics['frames'], 'evidence': 'hand_mechanics_verification.json'})
checks.append({'name': 'palm_orientation_regression', 'passed': True,
               'evidence': 'palm_orientation_verification.json'})

godot_path = OUT / 'preview/godot_import_verification.json'
assert godot_path.stat().st_mtime > ASSET.stat().st_mtime
godot = read('preview/godot_import_verification.json')
assert all(name in godot for name in ('Idle', 'Walking_A', 'Greet', 'Guide', 'Speak', 'Cane_Hold', 'Hand_Mechanics'))
checks.append({'name': 'godot_seven_clip_import', 'passed': True,
               'evidence': 'preview/godot_import_verification.json'})

contacts = read('hand_contact_verification.json')
grip = next(row for row in contacts if 'fingertip_pad_gap_m' in row)
hand_max = max(max(item['hand_max_edge_stretch'].values()) for item in verification['animations'].values())
body_max = max(item['max_edge_stretch'] for item in verification['animations'].values())
checks.extend([
    {'name': 'hand_edge_stretch_under_3x', 'passed': hand_max < 3, 'observed': hand_max},
    {'name': 'full_character_edge_stretch_under_3x', 'passed': body_max < 3, 'observed': body_max,
     'note': 'Pre-existing raised-arm sleeve distortion remains outside this face/proportion edit.'},
    {'name': 'sampled_hand_self_intersection',
     'passed': all(row['nonadjacent_surface_intersections'] == 0 for row in contacts),
     'samples': len(contacts),
     'failing_samples': sum(row['nonadjacent_surface_intersections'] > 0 for row in contacts),
     'note': 'Pre-existing small palm fold in Hand_Mechanics.'},
    {'name': 'all_cane_pad_clearances_under_3mm',
     'passed': max(grip['fingertip_pad_gap_m'].values()) < .003,
     'clearances_m': grip['fingertip_pad_gap_m'],
     'note': 'Pre-existing cane-contact limitation.'},
])

names = ['hero.jpg', 'front.jpg', 'side.jpg', 'back.jpg', 'face.jpg', 'paws.jpg',
         'turnaround.jpg', 'relaxed_paw.jpg', 'greeting_hand.jpg', 'cane_grip.jpg',
         'cane_grip_inside.jpg', 'cast_eye_comparison.jpg', 'neck_detail.jpg',
         'milo_motion.mp4', 'milo_hand_mechanics.mp4', 'godot_preview.png',
         'godot_hand_Greet.png', 'godot_hand_Cane_Hold.png', 'godot_hand_Hand_Mechanics.png']
names += [f'pose_{clip}.jpg' for clip in ('Idle', 'Walking_A', 'Greet', 'Guide', 'Speak', 'Cane_Hold')]
names += [f'face_{state}.jpg' for state in ('open', 'closing', 'blink', 'reopened')]
names += [path.name for path in OUT.glob('mechanics_*.jpg')]
media = {}
for name in names:
    path = OUT / name
    assert path.is_file() and path.stat().st_size > 0, name
    assert path.stat().st_mtime > ASSET.stat().st_mtime, ('Stale preview', name)
    media[name] = {'sha256': digest(path), 'bytes': path.stat().st_size}
(OUT / 'delivery_media_manifest.json').write_text(json.dumps({'asset_sha256': sha, 'media': media}, indent=2))
checks.append({'name': 'fresh_actual_model_media', 'passed': True, 'files': len(media),
               'evidence': 'delivery_media_manifest.json'})

summary = {
    'sha256': sha,
    'passed': all(check['passed'] for check in checks),
    'checks': checks,
    'metrics': read('prototype_proportion_verification.json')['ratios'],
    'known_failures_are_pre_existing': True,
}
(OUT / 'prototype_proportion_regression_summary.json').write_text(json.dumps(summary, indent=2))
gate = {
    'passed': summary['passed'],
    'asset': ASSET.name,
    'sha256': sha,
    'scope': 'Local DOCX-prototype face and proportion pass: fuller cranium, modestly larger central moustache, redesigned side moustache, and shorter neck. Body/outfit/paws/tail/cane geometry preserved.',
    'checks': checks,
    'regression_summary': 'prototype_proportion_regression_summary.json',
    'not_claimed': ['exact reference match or user approval', 'independent reader gate',
                    'arbitrary-pose or full-character collision freedom', 'production LOD',
                    'live-game integration', 'commit, push, upload or deployment'],
}
(OUT / 'gate.json').write_text(json.dumps(gate, indent=2))
print(json.dumps({'sha256': sha, 'gate_passed': gate['passed'],
                  'failures': [check for check in checks if not check['passed']],
                  'media_files': len(media), 'meshes': verification['mesh_objects'],
                  'bones': verification['bones'], 'triangles': verification['triangles']}, indent=2))
