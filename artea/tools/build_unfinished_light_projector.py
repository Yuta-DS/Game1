"""Living light-pattern projector: shared console, articulated botanical receiver."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from research_asset_builder import *
from mathutils import Vector
load_shell()
for ob in list(bpy.context.scene.objects):
    if ob.get('assembly')=='Pavilion': bpy.data.objects.remove(ob,do_unlink=True)
box('GardenPlinth',(0,3.3,.62),(6.4,3.0,1.24),0)
box('GardenInset',(0,3.3,1.26),(6.10,2.72,.07),2)
for i,x in enumerate([-2,0,2]):
    cyl('PlantingBasin',(x,3.3,1.50),.91,.46,0)
    cyl('SoilBed',(x,3.3,1.74),.81,.05,2)
    cyl('RootFeed',(x,3.3,2.19),.08,.87,1)
    for j in range(3):
        group='Leaf%d'%(i*3+j)
        start=Vector((x,3.3,2.50)); end=Vector((x+(j-1)*.35,3.3,2.62+j*.2))
        stem=cyl('ArticulatedLeafStem',(start+end)*.5,.035,(end-start).length,1)
        stem.rotation_euler=(end-start).to_track_quat('Z','Y').to_euler()
        # Closed, faceted leaf volume with a raised midrib, not a flat plane.
        verts=[(0,0,0),(.27,.32,.025),(0,.85,.07),(-.27,.32,.025),(0,.32,.12),(0,.32,-.03)]
        faces=[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(1,0,5),(2,1,5),(3,2,5),(0,3,5)]
        mesh=bpy.data.meshes.new(group); mesh.from_pydata(verts,[],faces); mesh.update(); mesh.uv_layers.new()
        ob=bpy.data.objects.new(group,mesh); bpy.context.collection.objects.link(ob)
        ob.location=(x+(j-1)*.35,3.3,2.62+j*.2); ob.rotation_euler.z=(j-1)*1.1
        finish(ob,group,3,group,.008)
        box('LeafMidrib',(x+(j-1)*.35,3.3,2.72+j*.2),(.04,.04,.24),1,group)
# Light head and optical carriage. The controls remain at hand height.
for side in [-1,1]:
    box('ProjectorPier',(side*2.4,1.25,1.5),(.33,.33,3.0),0)
box('ProjectorCrosshead',(0,1.25,3.03),(5.14,.42,.23),1)
box('LampHousing',(0,1.13,3.33),(1.35,.65,.57),2)
for x in [-.58,.58]: box('LampCap',(x,1.13,3.33),(.11,.74,.66),0)
cyl('LampAperture',(0,.76,3.33),.22,.13,3,front=True)
box('MirrorCradle',(-1.3,.4,1.78),(.92,.38,.12),1)
box('MirrorPlate',(-1.3,.4,2.04),(.73,.08,.50),3,'Mirror')
box('PatternSlide',(1.3,.4,1.93),(.90,.10,.55),0,'PatternPlate')
for i in range(3): box('PlateChannel',(1.3+(i-1)*.20,.33,1.93),(.06,.03,.40),1,'PatternPlate')
for x in [.56,2.04]: box('SlideRail',(x,.4,1.93),(.06,.18,.88),1)
box('AriReferenceBrace',(1.87,.17,1.94),(.08,.10,.60),1,'ReferenceBrace')
box('AriReferenceClamp',(1.71,.17,2.19),(.40,.13,.08),0,'ReferenceBrace')
box('ProtectionBlade',(0,.50,2.79),(.47,.08,.42),1,'Shutter')
for x in [-.30,.30]: box('ProtectionGuide',(x,.64,2.96),(.07,.12,.85),0)
cyl('CoolingChamber',(-2,.24,1.96),.24,.9,2)
for z in [1.5,2.4]: cyl('CoolingCap',(-2,.24,z),.28,.10)
box('CoolingSight',(-2,-.04,1.97),(.09,.04,.71),3,'CoolingLevel')
for i,x in enumerate([-1.25,0,1.25]):
    cyl('ControlBearing',(x,-.55,1.43),.24,.10)
    cyl('ControlDial',(x,-.55,1.54),.18,.10,2,'Control%d'%i)
    box('ControlIndex',(x,-.68,1.60),(.045,.13,.025),1,'Control%d'%i)
    box('ControlPlaque',(x,-.86,1.38),(1.03,.14,.04),0)
origins={'Mirror':(-1.3,.4,2.04),'PatternPlate':(1.3,.4,1.93),'ReferenceBrace':(1.87,.17,1.94),'Shutter':(0,.50,2.79),'CoolingLevel':(-2,-.04,1.615)}
for i,x in enumerate([-1.25,0,1.25]): origins['Control%d'%i]=(x,-.55,1.54)
for i,x in enumerate([-2,0,2]):
    for j in range(3): origins['Leaf%d'%(i*3+j)]=(x+(j-1)*.35,3.3,2.62+j*.2)
export('projector',origins)
