"""Current compact-paw regression set; old 2x-dimension test is historical."""
from pathlib import Path
import runpy,json,hashlib,traceback
OUT=Path(__file__).resolve().parent
checks=[]
for name in ('verify_compact_paws.py','verify.py','verify_hand_contacts.py',
             'verify_hand_mechanics.py','verify_palm_orientation.py',
             'verify_cuff_clearance.py','verify_head_style.py'):
    print('COMPACT_CHECK',name,flush=True)
    try:
        runpy.run_path(str(OUT/name),run_name='__main__')
        checks.append({'script':name,'passed':True})
    except Exception as error:
        traceback.print_exc()
        checks.append({'script':name,'passed':False,'error':str(error)})
result={'sha256':hashlib.sha256((OUT/'milo_fullres.glb').read_bytes()).hexdigest(),
        'passed':all(c['passed'] for c in checks),'checks':checks}
(OUT/'compact_regression_summary.json').write_text(json.dumps(result,indent=2))
print('COMPACT_REGRESSION',json.dumps(result),flush=True)
assert result['passed'],'See compact_regression_summary.json for failing checks'
