"""Protect everything except palm skin, moustache fans and local cheek skin."""
from pathlib import Path
OUT=Path(__file__).resolve().parent
# Reuse only the canonical GLB reader, without executing its old comparison.
source=(OUT/'check_head_scope.py').read_text().split('before,old_motion,old_hash=')[0]
source=source.replace("if name in ('eye.L','eye.R'):continue",'if False:continue')
exec(compile(source,str(OUT/'check_head_scope.py'),'exec'))
def is_head(n):
    return n.startswith(('Milo_Articulated_Paw.','Moustache_')) or n=='Head_Cranium_AnyCreature'
before,old_motion,old_hash=extract(OUT/'palm-whisker-before/milo_fullres.glb')
after,new_motion,new_hash=extract(OUT/'milo_fullres.glb')
assert before==after,[n for n in before if before[n]!=after.get(n)]
assert old_motion==new_motion,'Baked animation samples changed'
assert {'Eye_1','Eye_-1','Glasses_Bridge','Nose','Chin','Mouth'}<=set(before)
report={'passed':True,'sha256':new_hash,'baseline_sha256':old_hash,
        'unchanged_meshes_and_materials':len(before),'geometry_tolerance_m':1e-7,
        'all_animation_channels_exactly_unchanged':True,'clips':len(old_motion),
        'protected_meshes':sorted(before),
        'scope':'Palm skin contour, thumb root thickness, moustache/side-whisker fans, local cheek skin only. Existing bones, clips, eyes, glasses, clothing and props retained.'}
(OUT/'palm_whisker_scope_verification.json').write_text(json.dumps(report,indent=2))
print('PALM_WHISKER_SCOPE_PASS',json.dumps({k:v for k,v in report.items() if k!='protected_meshes'}))
