"""Refresh all current media after the final head export; no concept images."""
from pathlib import Path
import runpy,sys
OUT=Path(__file__).resolve().parent
sys.argv=['render_cast_faces.py'];runpy.run_path(str(OUT/'render_cast_faces.py'),run_name='__main__')
sys.argv=['render_delivery.py'];runpy.run_path(str(OUT/'render_delivery.py'),run_name='__main__')
