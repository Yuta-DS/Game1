"""Editable Echo Garden hero tree and contained planting, replacing Nature overlay."""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parents[1] / 'assets3D/mind_spark/echo_garden_benchmark'
bpy.ops.wm.read_factory_settings(use_empty=True)
materials = []
for name, color, metal, rough in [
    ('WarmBark', (.30,.17,.09,1),0,.85),
    ('IvoryStone', (.86,.79,.64,1),0,.7),
    ('ChampagneBrass', (.58,.40,.18,1),.65,.48),
    ('PearlFoliage', (.92,.84,.62,1),0,.72),
    ('SageFoliage', (.31,.46,.32,1),0,.8),
    ('GardenSoil', (.12,.09,.065,1),0,1),
]:
    m=bpy.data.materials.new(name); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=color
    p.inputs['Metallic'].default_value=metal
    p.inputs['Roughness'].default_value=rough
    materials.append(m)

def finish(ob,name,mat):
    ob.name=name; ob.data.materials.append(materials[mat])
    bpy.context.view_layer.objects.active=ob
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return ob

def branch(name,a,b,r1,r2,mat=0):
    d=Vector(b)-Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=10,radius1=r1,radius2=r2,depth=d.length,location=(Vector(a)+Vector(b))/2)
    ob=bpy.context.object; ob.rotation_mode='QUATERNION'; ob.rotation_quaternion=d.to_track_quat('Z','Y')
    return finish(ob,name,mat)

def crown(name,at,size,mat=3):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=at)
    ob=bpy.context.object; ob.scale=size
    return finish(ob,name,mat)

def rim(name,radius,wire,z,mat):
    bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=6,major_radius=radius,minor_radius=wire,location=(0,0,z))
    return finish(bpy.context.object,name,mat)

# Roots stay inside the basin; the previous long spokes crossed the terrace.
branch('RootBasin',(0,0,0),(0,0,1.8),25,25,1)
branch('ContainedSoil',(0,0,1.8),(0,0,2),23,23,5)
rim('MouldedBasinRim',24,1.25,2,1)
rim('BrassBasinReveal',24.5,.25,2.6,2)
points=[(0,0,1.8),(1,-.7,11),(-1.2,.8,22),(1,1.4,33),(-.8,0,43),(0,0,51)]
for i in range(len(points)-1):
    branch('Trunk_%02d'%i,points[i],points[i+1],5.2-i*.78,4.6-i*.78)
for i in range(8):
    a=i*math.tau/8
    mid=(math.cos(a)*10,math.sin(a)*10,3.5)
    tip=(math.cos(a)*21,math.sin(a)*21,2.1)
    branch('RootShoulder',points[0],mid,3,1.4)
    branch('RootTaper',mid,tip,1.4,.25)

for i in range(9):
    a=i*2.39996323
    start=points[2+i%3]
    radius=23 if i<6 else 14
    middle=(math.cos(a)*radius*.55,math.sin(a)*radius*.55,36+i*1.8)
    end=(math.cos(a)*radius,math.sin(a)*radius,44+i*1.8)
    branch('MainBough_%02d'%i,start,middle,2.3,1.35)
    branch('CrownFork_%02d'%i,middle,end,1.35,.35)
    crown('CanopyCluster_%02d'%i,end,(13,10,7.5))
    # Secondary cluster overlaps its branch-end crown: no disconnected cubes.
    at=Vector(end)+Vector((math.cos(a+.8)*6,math.sin(a+.8)*6,4))
    crown('CanopyCrest_%02d'%i,at,(8,7,5),1 if i%3==0 else 3)
crown('CrownTop',(0,0,61),(14,12,9))

# Eight deliberate pockets replace the 60 alternating soil/stone blocks.
for i in range(8):
    a=(i+.5)*math.tau/8
    x,y=math.cos(a)*74,math.sin(a)*74
    branch('PlanterShell',(x,y,0),(x,y,2.2),6.8,7.3,1)
    branch('PlanterSoil',(x,y,2.2),(x,y,2.4),6.5,6.5,5)
    for j in range(3):
        b=a+j*math.tau/3
        crown('PlantingCluster',(x+math.cos(b)*2.5,y+math.sin(b)*2.5,3.6),(3.5,3.2,2.2),4)

for folder in ('source','export','previews'): (OUT/folder).mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/echo_garden.blend'))
source_count=len(bpy.context.scene.objects)
# Separate material batches preserve clear finish boundaries, not arbitrary part counts.
for mat in materials:
    parts=[ob for ob in bpy.context.scene.objects if ob.type=='MESH' and ob.data.materials[0]==mat]
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts: ob.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join(); parts[0].name=mat.name
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'export/echo_garden.glb'),export_format='GLB',use_selection=True)
triangles=0
for ob in bpy.context.scene.objects:
    ob.data.calc_loop_triangles(); triangles+=len(ob.data.loop_triangles)
(OUT/'manifest.json').write_text(json.dumps({'revision':'echo_garden_01','source_meshes':source_count,
    'runtime_meshes':len(bpy.context.scene.objects),'triangles':triangles,'materials':len(materials),
    'root_radius':21,'basin_radius':25,'planter_pockets':8,'canopy_clusters':19},indent=2))
