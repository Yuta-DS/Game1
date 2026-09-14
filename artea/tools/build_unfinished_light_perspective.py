"""Three-view evidence carousel; full editable source, few runtime groups."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from research_asset_builder import *
from mathutils import Vector, Matrix
load_shell()
cyl('TurntableFoot',(0,0,1.46),1.00,.22,0)
cyl('TurntableBearing',(0,0,1.61),.82,.09,1)
cyl('CarouselTray',(0,0,1.73),.96,.14,2,'Carousel')
cyl('CarouselSpindle',(0,0,2.20),.12,1.1,1,'Carousel')
cyl('CarouselCrown',(0,0,2.83),.34,.16,1,'Carousel')
for index in range(3):
    angle=index*math.tau/3
    before=set(bpy.context.scene.objects)
    box('EvidenceFrame',(0,-.62,2.24),(1.03,.13,.94),1,'Carousel')
    box('EvidenceEnamel',(0,-.70,2.24),(.91,.035,.82),2,'Carousel')
    for x in [-.43,.43]:
        for z in [1.87,2.61]: cyl('FrameRivet',(x,-.735,z),.025,.028,0,'Carousel',True)
    if index==0:
        # Folded account sheet, ruled lines and an attached voice marker.
        box('AccountSheet',(0,-.77,2.23),(.51,.045,.58),0,'Carousel')
        for j in range(4): box('WrittenLine',(-.025,-.80,2.39-j*.10),(.34,.018,.022),1,'Carousel')
        cyl('AccountSeal',(.22,-.81,1.98),.09,.025,1,'Carousel',True)
    elif index==1:
        # Same test mechanism, expressed as a miniature flow pipe and shutter.
        box('FlowSymbol',(-.23,-.77,2.23),(.09,.055,.53),3,'Carousel')
        box('FlowConnection',(0,-.77,2.46),(.5,.05,.04),1,'Carousel')
        box('ProtectionSymbol',(.18,-.78,2.22),(.28,.06,.43),0,'Carousel')
        for j in range(3): box('ProtectionSlat',(.18,-.82,2.08+j*.13),(.24,.025,.025),1,'Carousel')
    else:
        # Two opposed supports hold one optic: collaboration, not a new fact.
        ring('SharedOptic',(0,-.79,2.25),.19,1,'Carousel')
        for side in [-1,1]:
            box('SupportHand',(side*.29,-.78,2.24),(.14,.08,.13),0,'Carousel')
            box('SupportArm',(side*.34,-.77,2.06),(.06,.07,.30),1,'Carousel')
    transform=Matrix.Rotation(angle,4,'Z')
    for ob in set(bpy.context.scene.objects)-before: ob.matrix_world=transform@ob.matrix_world
# Open eyepiece: avoids opaque glass hiding the evidence and excess overdraw.
for y in [-1.22,-1.35]: ring('ViewingAperture',(0,y,2.25),.45)
for x in [-.43,.43]: box('ViewingFrameStand',(x,-1.20,1.82),(.10,.13,.56),0)
box('ViewerFoot',(0,-1.14,1.43),(1.2,.50,.16),0)
for x in [-1.8,1.8]:
    box('PlateArchive',(x,.22,1.61),(.75,1.0,.45),2)
    for j in range(4): box('ArchiveDrawer',(x,-.30,1.44+j*.105),(.66,.035,.065),0)
cyl('SelectorBearing',(1.78,-.60,1.45),.25,.12)
cyl('ViewSelector',(1.78,-.60,1.56),.19,.12,2,'Selector')
box('SelectorIndex',(1.78,-.75,1.63),(.05,.15,.035),1,'Selector')
box('FrontNamePlate',(0,-.955,1.21),(3.8,.045,.20),2)
export('perspective_bay',{'Carousel':(0,0,1.73),'Selector':(1.78,-.60,1.56)})
