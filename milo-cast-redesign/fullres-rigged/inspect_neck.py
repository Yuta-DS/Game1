from pathlib import Path
import bpy,json
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'milo_fullres.blend'))
for name in ('Head_Cranium_AnyCreature','Chin','Mouth','Milo_Medieval_High_Collar'):
    obj=bpy.data.objects[name]
    print('NECK_BOUNDS',name,[(min(v.co[i] for v in obj.data.vertices),max(v.co[i] for v in obj.data.vertices)) for i in range(3)],flush=True)
head=bpy.data.objects['Head_Cranium_AnyCreature']
for z in (.95,1,1.025,1.05,1.075,1.10,1.125,1.15):
    values=[]
    for x in (0,.07,.12,.17):
        hit,p,normal,index=head.ray_cast(Vector((x,-3,z)),Vector((0,1,0)))
        values.append((x,p.y if hit else None))
    print('HEAD_FRONT',z,values,flush=True)
