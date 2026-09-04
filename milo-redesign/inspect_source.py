"""Read-only Blender inventory; output is isolated from the game assets."""
import json
from pathlib import Path
import bpy

OUT = Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT.parent / 'artea/assets3D/characters/milo_exact_target_parts.blend'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
data = {
    'rig': rig.name,
    'rig_matrix': [list(row) for row in rig.matrix_world],
    'bones': {b.name: {'head': list(rig.matrix_world @ b.head_local),
                       'tail': list(rig.matrix_world @ b.tail_local),
                       'parent': b.parent.name if b.parent else None}
              for b in rig.data.bones},
    'meshes': [{'name': o.name, 'vertices': len(o.data.vertices),
                'materials': [m.name for m in o.data.materials if m],
                'groups': [g.name for g in o.vertex_groups],
                'location': list(o.location), 'dimensions': list(o.dimensions),
                'hidden': o.hide_render}
               for o in bpy.context.scene.objects if o.type == 'MESH'],
    'actions': [{'name': a.name, 'range': list(a.frame_range)} for a in bpy.data.actions],
}
(OUT / 'source_inventory.json').write_text(json.dumps(data, indent=2))
print(json.dumps(data))
