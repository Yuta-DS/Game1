"""Actual GLB neck close-up, followed by refreshed full delivery media."""
from pathlib import Path
import runpy,sys
OUT=Path(__file__).resolve().parent
source=(OUT/'render.py').read_text().split('modes=')[0]
exec(compile(source,str(OUT/'render.py'),'exec'))
cam.location=(3,-7,1.35);aim(cam,(0,-.07,1.13));cam.data.ortho_scale=.90
scene.render.resolution_x=1000;scene.render.resolution_y=760;scene.render.resolution_percentage=100
scene.render.filepath=str(OUT/'neck_detail.jpg');bpy.ops.render.render(write_still=True)
sys.argv=[str(OUT/'render_head_delivery.py')]
runpy.run_path(str(OUT/'render_head_delivery.py'),run_name='__main__')
