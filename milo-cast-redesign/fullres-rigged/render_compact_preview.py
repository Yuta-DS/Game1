"""Actual-model previews for the compact-paw and groomed-moustache pass."""
from pathlib import Path
import runpy,sys
OUT=Path(__file__).resolve().parent
for name in ('render.py','review_motion.py'):
    sys.argv=[str(OUT/name)]
    runpy.run_path(str(OUT/name),run_name='__main__')
