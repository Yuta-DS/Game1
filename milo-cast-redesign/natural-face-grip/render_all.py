from pathlib import Path
import sys,runpy
OUT=Path(__file__).resolve().parent
for mode in ('hero','face','face_side','paw_left','paw_right','grip_side','lineup'):
    sys.argv=['review','--',mode];runpy.run_path(str(OUT/'render_review.py'))
