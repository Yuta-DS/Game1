"""Full local regression sequence for the palm and side-moustache revision."""
from pathlib import Path
import runpy
OUT=Path(__file__).resolve().parent
for name in ('verify_palm_whisker.py','verify.py','verify_hand_contacts.py',
             'verify_hand_mechanics.py','verify_palm_orientation.py',
             'verify_cuff_clearance.py','verify_medieval_update.py','verify_head_style.py'):
    print('PALM_WHISKER_CHECK',name,flush=True)
    runpy.run_path(str(OUT/name),run_name='__main__')
