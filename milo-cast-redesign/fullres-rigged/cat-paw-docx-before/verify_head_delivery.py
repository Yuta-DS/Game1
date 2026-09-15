"""Local head revision regression sequence. Fail immediately on any check."""
from pathlib import Path
import runpy
OUT=Path(__file__).resolve().parent
for name in ('verify_head_style.py','verify.py','verify_hand_mechanics.py','verify_palm_orientation.py','verify_cuff_clearance.py','verify_medieval_update.py'):
    print('HEAD_DELIVERY_CHECK',name,flush=True)
    runpy.run_path(str(OUT/name),run_name='__main__')
