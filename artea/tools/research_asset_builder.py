"""Small authoring library for derived laboratory assets in background Blender."""
import bpy, math, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MATS=[]
def load_shell():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets3D/mind_spark/unfinished_light/inspection_bay/inspection_bay.blend'))
    bpy.context.preferences.filepaths.save_version=0
    keep=('ContinuousBase','BaseReveal','StorageCase','Drawer','RecessedPull','CabinetFoot','WorkingTop','FrontBrassEdge','WorkSurface')
    for ob in list(bpy.context.scene.objects):
        if ob.get('assembly')!='Pavilion' and not ob.name.startswith(keep): bpy.data.objects.remove(ob,do_unlink=True)
    MATS[:]=[bpy.data.materials[n] for n in ['IvoryCeramic','BrushedBrass','DeepTealEnamel','OpalGlass']]
def finish(ob,name,mat,group,bevel=.02):
    ob.name=name; ob['assembly']=group; ob.data.materials.append(MATS[mat])
    bpy.context.view_layer.objects.active=ob
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('Crafted edges','BEVEL'); mod.width=bevel; mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for uv in ob.data.uv_layers.active.data:
        uv.uv.x=(mat+.04+uv.uv.x*.92)/4; uv.uv.y=.04+uv.uv.y*.92
    return ob
def box(name,at,size,mat=0,group='Cabinet'):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at); ob=bpy.context.object; ob.scale=size
    return finish(ob,name,mat,group)
def cyl(name,at,radius,depth,mat=1,group='Cabinet',front=False):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=radius,depth=depth,location=at,rotation=(math.pi/2,0,0) if front else (0,0,0))
    return finish(bpy.context.object,name,mat,group,.01)
def ring(name,at,radius,mat=1,group='Cabinet'):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius,minor_radius=.04,major_segments=32,minor_segments=8,location=at,rotation=(math.pi/2,0,0))
    return finish(bpy.context.object,name,mat,group,0)
def export(name,origins):
    out=ROOT/'assets3D/mind_spark/unfinished_light'/name; out.mkdir(parents=True,exist_ok=True)
    source_parts=len([o for o in bpy.context.scene.objects if o.type=='MESH'])
    bpy.ops.wm.save_as_mainfile(filepath=str(out/(name+'.blend')))
    groups={}
    for ob in list(bpy.context.scene.objects):
        if ob.type=='MESH': groups.setdefault(ob['assembly'],[]).append(ob)
    for group,parts in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for ob in parts: ob.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        if len(parts)>1: bpy.ops.object.join()
        ob=parts[0]; ob.name=group; bpy.context.scene.cursor.location=origins.get(group,(0,0,0))
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        mod=ob.modifiers.new('ExportTriangles','TRIANGULATE'); bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True)
    manifest={'source_parts':source_parts,'runtime_meshes':len(groups),'triangles':sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH'),'moving_parts':list(origins)}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)); print(name,manifest)
