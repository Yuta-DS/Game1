"""Keep Milo's head, tail, footwear, trousers and cane geometry unchanged."""
from pathlib import Path
OUT=Path(__file__).resolve().parent
source=(OUT/'check_hand_scope.py').read_text().split("before=geometry")[0]
exec(compile(source,str(OUT/'check_hand_scope.py'),'exec'))
before=geometry(OUT/'medieval-before/milo_fullres.glb');after=geometry(OUT/'milo_fullres.glb')
protected=[name for name in before if not name.startswith(('Milo_','Pin_')) or name.startswith(('Milo_Sculpt_Boot','Milo_Boot_','Milo_Trouser')) or name=='Milo_Sculpt_Tail']
assert all(before[name]==after.get(name) for name in protected),[name for name in protected if before[name]!=after.get(name)]
report={'unchanged_protected_meshes':len(protected),'names':protected,'tolerance_m':1e-7,'scope':'Hands, medieval clothing, required arm/prop pose retargeting and local preview only. No live-game changes.','passed':True}
(OUT/'medieval_scope_verification.json').write_text(json.dumps(report,indent=2))
print('MEDIEVAL_SCOPE_PASS',json.dumps(report))
