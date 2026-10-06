"""Refresh every delivery render from one final GLB in one Blender process."""
import runpy,sys
from pathlib import Path
OUT=Path(__file__).resolve().parent
for script,args in [('render.py',[]),('review_motion.py',[]),('review_motion.py',['--','mechanics']),('review_motion.py',['--','--stream','mechanics_video']),('review_motion.py',['--','--stream','video'])]:
    print('DELIVERY_RENDER',script,args,flush=True)
    sys.argv=[str(OUT/script)]+args
    runpy.run_path(str(OUT/script),run_name='__main__')
