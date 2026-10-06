"""Protect all existing geometry except paws and the requested moustache."""
from pathlib import Path
OUT=Path(__file__).resolve().parent
source=(OUT/'check_head_scope.py').read_text().split('before,old_motion,old_hash=')[0]
source=source.replace("if name in ('eye.L','eye.R'):continue", "if name.startswith(('palm','finger','thumb')) or name=='cane':continue")
exec(compile(source,str(OUT/'check_head_scope.py'),'exec'))
def is_head(n):return n.startswith(('Milo_Articulated_Paw.','Moustache_','Cheek_Tuft_'))
before,old_motion,old_hash=extract(OUT/'cat-paw-docx-before/milo_fullres.glb')
after,new_motion,new_hash=extract(OUT/'milo_fullres.glb')
assert before==after,[n for n in before if before[n]!=after.get(n)]
assert old_motion==new_motion,'Protected body, wrist or face motion changed'
result={'passed':True,'sha256':new_hash,'baseline_sha256':old_hash,'unchanged_meshes_and_materials':len(before),'geometry_tolerance_m':1e-7,'protected_animation_exactly_unchanged':True,'scope':'Paw skin/pads, central moustache, four new cheek tufts; digit rig proportions and poses, optional cane placement. No live-game changes.'}
(OUT/'cat_paw_scope_verification.json').write_text(json.dumps(result,indent=2))
print('CAT_PAW_SCOPE_PASS',json.dumps(result))
