"""Only paw geometry, moustache geometry and digit/cane motion may change."""
from pathlib import Path
OUT=Path(__file__).resolve().parent
source=(OUT/'check_head_scope.py').read_text().split('before,old_motion,old_hash=')[0]
source=source.replace("if name in ('eye.L','eye.R'):continue",
                      "if name.startswith(('palm','finger','thumb')) or name=='cane':continue")
exec(compile(source,str(OUT/'check_head_scope.py'),'exec'))
def is_head(n):return n.startswith(('Milo_Articulated_Paw.','Moustache_'))
before,old_motion,old_hash=extract(OUT/'compact-paw-before/milo_fullres.glb')
after,new_motion,new_hash=extract(OUT/'milo_fullres.glb')
assert before==after,[n for n in before if before[n]!=after.get(n)]
assert old_motion==new_motion,'Body, wrist, face or other protected animation changed'
assert {'Head_Cranium_AnyCreature','Eye_1','Eye_-1','Nose','Chin','Mouth'}<=set(before)
report={'passed':True,'sha256':new_hash,'baseline_sha256':old_hash,
        'unchanged_meshes_and_materials':len(before),'geometry_tolerance_m':1e-7,
        'body_wrist_and_face_animation_channels_exactly_unchanged':True,
        'clips':len(old_motion),'protected_meshes':sorted(before),
        'scope':'Two paw meshes and two moustache meshes; digit rest proportions/presets and cane placement only. Body, face, eyes, glasses, outfit and prop geometry retained.'}
(OUT/'compact_scope_verification.json').write_text(json.dumps(report,indent=2))
print('COMPACT_SCOPE_PASS',json.dumps({k:v for k,v in report.items() if k!='protected_meshes'}))
