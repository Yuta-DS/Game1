"""Measured deformation checks, not a claim of complete collision QA."""
import json
import math
from pathlib import Path
import bpy
from mathutils import Vector

OUT = Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'milo_redesign.blend'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.name.startswith('RENDER_ONLY')]
report = {'mesh_count': len(meshes), 'bone_count': len(rig.data.bones), 'checks': [], 'clips': {}}
bad_weights = []
for obj in meshes:
    for v in obj.data.vertices:
        total = sum(g.weight for g in v.groups if obj.vertex_groups[g.group].name in rig.data.bones)
        if abs(total-1) > .001:
            bad_weights.append([obj.name, v.index, total])
report['checks'].append({'name':'normalized_deform_weights', 'passed':not bad_weights, 'bad_vertices':bad_weights[:12]})
rig.data.pose_position = 'REST'
bpy.context.view_layer.update()
rest = {}
for obj in meshes:
    if not obj.name.startswith('Sleeve_'):
        continue
    rest[obj.name] = [(tuple(e.vertices), (obj.data.vertices[e.vertices[0]].co-obj.data.vertices[e.vertices[1]].co).length) for e in obj.data.edges]
rig.data.pose_position = 'POSE'
for clip in ['Milo_Redesign_Idle','Milo_Redesign_Welcome','Milo_Redesign_Listen','Milo_Walking']:
    action = bpy.data.actions[clip]
    rig.animation_data.action = action
    if action.slots:
        rig.animation_data.action_slot = action.slots[0]
    start, end = action.frame_range
    ratio, finite, frames = 1.0, True, 0
    hand_positions, cane_positions = [], []
    for i in range(33):
        frame = start + (end-start)*i/32
        bpy.context.scene.frame_set(int(frame), subframe=frame-int(frame))
        graph = bpy.context.evaluated_depsgraph_get()
        hand_positions.append(list(rig.matrix_world @ rig.pose.bones['hand.r'].head))
        cane_positions.append(list(rig.matrix_world @ rig.pose.bones['hand.l'].head))
        for obj in meshes:
            evaluated = obj.evaluated_get(graph)
            mesh = evaluated.to_mesh()
            finite &= all(math.isfinite(c) for v in mesh.vertices for c in v.co)
            if obj.name in rest:
                for (a,b), length in rest[obj.name]:
                    if length > .0001:
                        ratio = max(ratio, (mesh.vertices[a].co-mesh.vertices[b].co).length/length)
            evaluated.to_mesh_clear()
        frames += 1
    cane_drift = max((Vector(p)-Vector(cane_positions[0])).length for p in cane_positions)
    hand_travel = max((Vector(p)-Vector(hand_positions[0])).length for p in hand_positions)
    report['clips'][clip] = {'samples':frames, 'finite_vertices':finite, 'max_sleeve_edge_stretch':ratio,
                             'cane_hand_displacement_m':cane_drift, 'free_hand_displacement_m':hand_travel,
                             'duration_seconds':float(end-start)/bpy.context.scene.render.fps}
    report['checks'].append({'name':clip+'_finite_and_stretch', 'passed':finite and ratio < 3})
    if clip != 'Milo_Walking':
        report['checks'].append({'name':clip+'_stationary_cane_hand', 'passed':cane_drift < .001})
report['passed'] = all(check['passed'] for check in report['checks'])
(OUT/'blender_validation.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
if not report['passed']:
    raise RuntimeError('Measured deformation validation failed')
