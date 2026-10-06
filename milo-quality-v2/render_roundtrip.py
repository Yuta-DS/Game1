from pathlib import Path
import sys,bpy
OUT=Path(__file__).resolve().parent;sys.path.insert(0,str(OUT))
from studio import setup
from review import aim
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'milo_quality_v2.glb'))
scene=setup();scene.render.engine='BLENDER_EEVEE'
for obj in list(scene.objects):
    for owner in [obj]+([obj.data.shape_keys] if obj.type=='MESH' and obj.data.shape_keys else []):
        ad=owner.animation_data
        if not ad:continue
        for tr in ad.nla_tracks:
            tr.mute=True
            if tr.name=='Idle':
                ad.action=tr.strips[0].action
                if hasattr(tr.strips[0],'action_slot'):ad.action_slot=tr.strips[0].action_slot
scene.frame_set(15)
scene.render.filepath=str(OUT/'runtime_roundtrip.png');bpy.ops.render.render(write_still=True)
print('ROUNDTRIP_RENDER_OK',flush=True)
