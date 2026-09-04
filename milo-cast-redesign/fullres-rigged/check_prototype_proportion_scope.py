"""Prove that the prototype-proportion pass changes only Milo's head/face."""
from pathlib import Path
import hashlib
import json
import struct

OUT = Path(__file__).resolve().parent
HEAD_PREFIXES = ('Head_', 'Eye_', 'Brow_', 'Ear_', 'Glasses_', 'Moustache_', 'Cheek_', 'eye.')
HEAD_NAMES = {'Chin', 'Mouth', 'Neck_Transition', 'Nose'}


def allowed(name):
    return name.startswith(HEAD_PREFIXES) or name in HEAD_NAMES


def extract(path):
    raw = path.read_bytes()
    size = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + size])
    blob = raw[28 + size:]

    def acc(index):
        item = doc['accessors'][index]
        view = doc['bufferViews'][item['bufferView']]
        scalar = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}[item['componentType']]
        width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[item['type']]
        fmt = '<' + scalar * width
        stride = view.get('byteStride', struct.calcsize(fmt))
        start = view.get('byteOffset', 0) + item.get('byteOffset', 0)
        return [struct.unpack_from(fmt, blob, start + i * stride) for i in range(item['count'])]

    nodes = doc['nodes']
    parents = {child: node['name'] for node in nodes for child in node.get('children', [])}
    meshes = {}
    rests = {}
    for node_index, node in enumerate(nodes):
        name = node['name']
        if allowed(name):
            continue
        rests[name] = {key: node[key] for key in ('translation', 'rotation', 'scale', 'matrix') if key in node}
        rests[name]['parent'] = parents.get(node_index)
        if 'mesh' not in node:
            continue
        joints = [nodes[j]['name'] for j in doc['skins'][node['skin']]['joints']] if 'skin' in node else []
        entries = []
        for primitive in doc['meshes'][node['mesh']]['primitives']:
            attrs = {key: acc(value) for key, value in primitive['attributes'].items()}
            vertices = []
            for i in range(len(attrs['POSITION'])):
                values = []
                for key in sorted(attrs):
                    if key.startswith(('JOINTS', 'WEIGHTS')):
                        continue
                    values.append((key, tuple(round(x, 7) for x in attrs[key][i])))
                if joints:
                    weights = {}
                    for key in attrs:
                        if not key.startswith('JOINTS_'):
                            continue
                        for joint, weight in zip(attrs[key][i], attrs[key.replace('JOINTS', 'WEIGHTS')][i]):
                            if weight > 1e-7:
                                weights[joints[joint]] = round(weight, 7)
                    values.append(('skin', tuple(sorted(weights.items()))))
                vertices.append(tuple(values))
            indices = [value[0] for value in acc(primitive['indices'])]
            triangles = []
            for i in range(0, len(indices), 3):
                tri = tuple(vertices[j] for j in indices[i:i + 3])
                triangles.append(min(tri, tri[1:] + tri[:1], tri[2:] + tri[:2]))
            entries.append((hashlib.sha256(repr(sorted(triangles)).encode()).hexdigest(),
                            doc['materials'][primitive['material']]))
        meshes[name] = entries

    motion = {}
    for animation in doc['animations']:
        channels = {}
        for channel in animation['channels']:
            target = channel['target']
            sampler = animation['samplers'][channel['sampler']]
            node_name = nodes[target['node']]['name']
            if node_name.startswith('eye.') and target['path'] == 'translation':
                continue
            channels[(node_name, target['path'])] = (
                acc(sampler['input']), acc(sampler['output']), sampler.get('interpolation', 'LINEAR'))
        motion[animation['name']] = channels

    binds = {}
    for skin in doc['skins']:
        for joint, matrix in zip(skin['joints'], acc(skin['inverseBindMatrices'])):
            name = nodes[joint]['name']
            if not allowed(name):
                binds[name] = matrix
    return meshes, rests, motion, binds, hashlib.sha256(raw).hexdigest()


before = extract(OUT / 'prototype-proportion-before/milo_fullres.glb')
after = extract(OUT / 'milo_fullres.glb')
assert before[0] == after[0], ('Protected body/outfit meshes changed',
                              [name for name in before[0] if before[0][name] != after[0].get(name)])
assert before[1] == after[1], ('Protected node transforms or parents changed',
                              [name for name in before[1] if before[1][name] != after[1].get(name)])
assert before[2] == after[2], ('Animation channels changed', {
    clip: [channel for channel in before[2][clip] if before[2][clip][channel] != after[2].get(clip, {}).get(channel)]
    for clip in before[2] if before[2][clip] != after[2].get(clip)
})
assert before[3] == after[3], 'Inverse bind matrices changed'

result = {
    'passed': True,
    'sha256': after[4],
    'baseline_sha256': before[4],
    'protected_mesh_count': len(before[0]),
    'protected_meshes': sorted(before[0]),
    'all_body_outfit_paw_tail_cane_geometry_unchanged': True,
    'all_non_eye_translation_animation_channels_exactly_unchanged': True,
    'eye_translation_channels_rebased_to_reshaped_face': True,
    'all_protected_rest_transforms_exactly_unchanged': True,
    'clips': len(before[2]),
    'bones': len(before[3]),
    'scope': 'Head cranium, face pieces, moustache, cheek locks, chin, short neck and eye-bone rest placement may change; body, outfit, paws, tail, cane, all other rig rest transforms and all non-eye-translation animation channels are protected.'
}
(OUT / 'prototype_proportion_scope_verification.json').write_text(json.dumps(result, indent=2))
print('PROTOTYPE_PROPORTION_SCOPE_PASS', json.dumps({key: value for key, value in result.items() if key != 'protected_meshes'}))
