"""Verify that Milo has no visible neck mesh and stays seated on the collar."""
from pathlib import Path
import bpy
import hashlib
import json
import numpy as np
from mathutils.bvhtree import BVHTree

OUT = Path(__file__).resolve().parent
ASSET = OUT / 'milo_fullres.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ASSET))

assert 'Neck_Transition' not in bpy.data.objects, 'Visible neck mesh still exported'
rig = next(obj for obj in bpy.data.objects if obj.type == 'ARMATURE')
assert {'neck', 'head'} <= {bone.name for bone in rig.data.bones}, 'Hidden articulation bones must remain'

objects = {name: bpy.data.objects[name] for name in (
    'Head_Cranium_AnyCreature', 'Chin', 'Milo_Medieval_High_Collar',
    'Milo_Medieval_Linen_Throat', 'Milo_Medieval_Linen_Throat.001')}


def evaluated_points(obj):
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    values = np.empty(len(mesh.vertices) * 3)
    mesh.vertices.foreach_get('co', values)
    points = values.reshape(-1, 3)
    matrix = np.array(evaluated.matrix_world)
    points = points @ matrix[:3, :3].T + matrix[:3, 3]
    faces = [poly.vertices[:] for poly in mesh.polygons]
    evaluated.to_mesh_clear()
    return points, faces


def tree(obj):
    points, faces = evaluated_points(obj)
    return BVHTree.FromPolygons(points.tolist(), faces, all_triangles=True)


rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = True
clips = {}
failures = []
for track in rig.animation_data.nla_tracks:
    action = track.strips[0].action
    rig.animation_data.action = action
    if action.slots:
        rig.animation_data.action_slot = action.slots[0]
    frames = range(round(action.frame_range[0]), round(action.frame_range[1]) + 1)
    minimum_contact = 10 ** 9
    maximum_contact = 0
    for frame in frames:
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        head = tree(objects['Head_Cranium_AnyCreature'])
        chin = tree(objects['Chin'])
        contact = 0
        for name in ('Milo_Medieval_High_Collar', 'Milo_Medieval_Linen_Throat', 'Milo_Medieval_Linen_Throat.001'):
            upper_body = tree(objects[name])
            contact += len(head.overlap(upper_body)) + len(chin.overlap(upper_body))
        minimum_contact = min(minimum_contact, contact)
        maximum_contact = max(maximum_contact, contact)
        if contact == 0:
            failures.append({'clip': track.name, 'frame': frame, 'detached_head_from_collar': True})
    clips[track.name] = {
        'frames': len(frames),
        'minimum_head_collar_triangle_pairs': minimum_contact,
        'maximum_head_collar_triangle_pairs': maximum_contact,
    }

report = {
    'passed': not failures,
    'sha256': hashlib.sha256(ASSET.read_bytes()).hexdigest(),
    'visible_neck_mesh_removed': True,
    'hidden_neck_and_head_articulation_bones_retained': True,
    'frames_checked': sum(item['frames'] for item in clips.values()),
    'clips': clips,
    'failures': failures,
}
(OUT / 'no_visible_neck_verification.json').write_text(json.dumps(report, indent=2))
print('NO_VISIBLE_NECK_RESULT', json.dumps({
    'passed': report['passed'], 'sha256': report['sha256'],
    'frames_checked': report['frames_checked'], 'failures': failures[:8],
    'minimum_contacts': {name: item['minimum_head_collar_triangle_pairs'] for name, item in clips.items()},
}), flush=True)
assert report['passed'], 'Head separates from collar in authored motion'
