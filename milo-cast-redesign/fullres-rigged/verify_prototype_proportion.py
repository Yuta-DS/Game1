"""Measure the immediate before/after prototype silhouette revision."""
from pathlib import Path
import bpy
import bmesh
import hashlib
import json
import numpy as np

OUT = Path(__file__).resolve().parent


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))


def bounds(names):
    points = np.array([tuple(vertex.co) for name in names for vertex in bpy.data.objects[name].data.vertices])
    return {
        'width_m': float(np.ptp(points[:, 0])),
        'depth_m': float(np.ptp(points[:, 1])),
        'height_m': float(np.ptp(points[:, 2])),
        'z_min_m': float(np.min(points[:, 2])),
        'z_max_m': float(np.max(points[:, 2])),
    }


def volume(names):
    total = 0.0
    for name in names:
        bm = bmesh.new()
        bm.from_mesh(bpy.data.objects[name].data)
        total += abs(bm.calc_volume())
        bm.free()
    return float(total)


def measure(path):
    load(path)
    result = {
        'head': bounds(['Head_Cranium_AnyCreature']),
        'central_moustache': bounds(['Moustache_1', 'Moustache_-1']),
        'side_moustache': bounds(['Cheek_Ruff_1', 'Cheek_Ruff_-1']),
        'neck': bounds(['Neck_Transition']),
    }
    result['central_moustache']['volume_m3'] = volume(['Moustache_1', 'Moustache_-1'])
    return result


before = measure(OUT / 'prototype-proportion-before/milo_fullres.glb')
after = measure(OUT / 'milo_fullres.glb')
ratios = {
    group: {key: after[group][key] / value for key, value in before[group].items() if value > 0}
    for group in ('head', 'central_moustache', 'side_moustache')
}
assert 1.02 <= ratios['central_moustache']['width_m'] <= 1.12, ratios['central_moustache']
assert ratios['central_moustache']['volume_m3'] > 1.08, ratios['central_moustache']
assert ratios['head']['width_m'] > 1.02, ratios['head']
assert after['neck']['height_m'] < before['neck']['height_m'], (before['neck'], after['neck'])

report = {
    'passed': True,
    'sha256': hashlib.sha256((OUT / 'milo_fullres.glb').read_bytes()).hexdigest(),
    'baseline_sha256': hashlib.sha256((OUT / 'prototype-proportion-before/milo_fullres.glb').read_bytes()).hexdigest(),
    'before': before,
    'after': after,
    'ratios': ratios,
    'interpretation': 'Immediate prior model comparison: modestly larger central moustache, fuller/wider cranium, redesigned two-lock side moustache, and shorter neck transition.'
}
(OUT / 'prototype_proportion_verification.json').write_text(json.dumps(report, indent=2))
print('PROTOTYPE_PROPORTION_PASS', json.dumps(report), flush=True)
