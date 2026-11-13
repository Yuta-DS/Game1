"""Derive reusable small trees from the approved-direction hero tree source."""
import bpy
import json
from pathlib import Path
from mathutils import Matrix
BASE=Path(__file__).resolve().parents[1]/'assets3D/mind_spark/echo_garden_benchmark'
bpy.ops.wm.open_mainfile(filepath=str(BASE/'source/echo_garden.blend'))
prefixes=('Trunk_','MainBough_','CrownFork_','CanopyCluster_','CanopyCrest_','CrownTop','RootShoulder','RootTaper','RootBasin','ContainedSoil','MouldedBasinRim','BrassBasinReveal')
for ob in list(bpy.context.scene.objects):
    if not ob.name.startswith(prefixes): bpy.data.objects.remove(ob,do_unlink=True)
for ob in bpy.context.scene.objects:
    ob.location *= .45
    ob.scale *= .45
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'source/echo_sapling.blend'))
for material in list(bpy.data.materials):
    parts=[ob for ob in bpy.context.scene.objects if ob.type=='MESH' and ob.data.materials[0]==material]
    if not parts: continue
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts: ob.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    if len(parts)>1: bpy.ops.object.join()
    parts[0].name='Sapling_'+material.name
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(BASE/'export/echo_sapling.glb'),export_format='GLB',use_selection=True)
# Two quieter secondary silhouettes keep the family resemblance without
# repeating the complete landmark canopy on every background tree.
for variant in (1,2):
    bpy.ops.wm.open_mainfile(filepath=str(BASE/'source/echo_sapling.blend'))
    for ob in list(bpy.context.scene.objects):
        if ob.name.startswith('CanopyCrest_'):
            bpy.data.objects.remove(ob,do_unlink=True)
        elif ob.name.startswith(('Canopy','CrownTop','MainBough','CrownFork','Trunk')):
            ob.matrix_world = Matrix.Diagonal((1,1,.90 if variant == 1 else 1.08,1)) @ ob.matrix_world
    bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'source'/f'echo_sapling_{variant}.blend'))
    for material in list(bpy.data.materials):
        parts=[ob for ob in bpy.context.scene.objects if ob.type=='MESH' and ob.data.materials[0]==material]
        if not parts: continue
        bpy.ops.object.select_all(action='DESELECT')
        for ob in parts: ob.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        if len(parts)>1: bpy.ops.object.join()
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(BASE/'export'/f'echo_sapling_{variant}.glb'),export_format='GLB',use_selection=True)
