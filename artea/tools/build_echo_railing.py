"""Reuse original scrollwork and lantern posts as matched 15-degree arc modules."""
import bpy
import math
from pathlib import Path
from mathutils import Matrix

BASE = Path(__file__).resolve().parents[1] / 'assets3D/mind_spark'
OUT = BASE / 'echo_garden_benchmark'
bpy.ops.wm.open_mainfile(filepath=str(BASE/'celestial_islands_v11/source/reference_railings.blend'))
bpy.context.preferences.filepaths.save_version = 0
templates = list(bpy.context.scene.objects)
for kind, group in [('rail_bay','Panel_01'), ('rail_post','Post_01')]:
    parts = [o for o in templates if o.get('railing_group') == group]
    points = [v.co for o in parts for v in o.data.vertices]
    angles = [math.atan2(v.y,v.x) for v in points]
    middle = (min(angles)+max(angles))/2
    width = max(angles)-min(angles)
    copies = []
    for original in parts:
        ob = original.copy(); ob.data = original.data.copy()
        bpy.context.scene.collection.objects.link(ob)
        ob.matrix_world = Matrix.Identity(4)
        for v in ob.data.vertices:
            angle = math.atan2(v.co.y,v.co.x)-middle
            if kind == 'rail_bay':
                angle *= math.radians(15)/width
            radius = math.hypot(v.co.x,v.co.y) - .06
            v.co.x = math.sin(angle)*radius
            v.co.y = -math.cos(angle)*radius
        copies.append(ob)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in copies: ob.select_set(True)
    bpy.context.view_layer.objects.active = copies[0]
    bpy.ops.object.join()
    copies[0].name = kind
    # Keep original authored colours but remove mirror-like/emissive stone.
    for mat in copies[0].data.materials:
        if not mat or not mat.use_nodes: continue
        shader = mat.node_tree.nodes.get('Principled BSDF')
        if shader:
            shader.inputs['Roughness'].default_value = .55
            if 'glass' not in mat.name.lower():
                shader.inputs['Emission Strength'].default_value = 0
    bpy.ops.export_scene.gltf(filepath=str(OUT/'export'/f'{kind}.glb'), export_format='GLB',use_selection=True)
    bpy.data.objects.remove(copies[0],do_unlink=True)

