"""Serial review renders to avoid overlapping Blender processes."""
from pathlib import Path
import sys,runpy
OUT=Path(__file__).resolve().parent
for mode in ('hero','face','face_side','paw_left','paw_right','lineup'):
    sys.argv=['review','--',mode];runpy.run_path(str(OUT/'render_review.py'))
