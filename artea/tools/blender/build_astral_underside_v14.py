"""Complete the v13 lower plant without replacing its architecture or gameplay.

Two piston/flywheel engines, aft condensers and an attached service gallery.
New parts are deliberately economical; the existing 540k runtime ceiling stays.
"""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_astral_castle_v13 as astral

base, kit, reference = astral.base, astral.kit, astral.reference
ROOT = astral.ROOT
OUT = ROOT / "assets3D/mind_spark/celestial_astral_v14"
SOURCE = ROOT / "assets3D/mind_spark/celestial_astral_v13/source/island_03_3000.blend"
TAU = math.tau
group = astral.group


def block(name, at, size, mat="gold", bevel=0):
    # At this normalized scale, sub-.004 bevels on fittings are subpixel in play.
    # Keep the saddle chamfers; spend curvature on vessels, wheels and rails.
    return kit.box(name, at, size, mat, bevel if bevel >= .004 else 0, "Machinery")


def line(name, points, radius=.009, mat="gold", sides=6):
    return kit.tube(name, points, radius, mat, "Machinery", sides)


def pipe(name, points, radius, mat):
    points=[Vector(p) for p in points]
    rounded=[points[0]]
    for i in range(1,len(points)-1):
        a,b,c=points[i-1:i+2]
        trim=min((a-b).length,(c-b).length)*.23
        p=b+(a-b).normalized()*trim;q=b+(c-b).normalized()*trim
        rounded.extend((1-t)**2*p+2*(1-t)*t*b+t*t*q for t in (0,.25,.5,.75,1))
    rounded.append(points[-1])
    return line(name,rounded,radius,mat,8)


def ellipse(a, z, rx=.83, ry=.64):
    return (rx*math.cos(a), .04+ry*math.sin(a), z)


def gallery():
    group("11_Lower_Service_Gallery", "Continuous oval service deck")
    # Individually editable masonry sectors, seated on radial cross-bearers.
    for i in range(24):
        a0, a1 = i*TAU/24, (i+1)*TAU/24
        vs = [ellipse(a, z, rx, ry) for z in (-1.52, -1.4825)
              for rx, ry in ((.42,.29),(.86,.67)) for a in (a0,(a0+a1)/2,a1)]
        fs = [(0,3,4,1),(1,4,5,2),(6,7,10,9),(7,8,11,10),
              (0,1,7,6),(1,2,8,7),(3,9,10,4),(4,10,11,5),(0,6,9,3),(2,5,11,8)]
        kit.mesh(f"ServiceDeck_StoneSector_{i+1:02}", vs, fs, "ivory", "Machinery")
    # Rails belong to the machinery batch, not the gameplay perimeter rails.
    for z in (-1.47,-1.35):
        line("ServiceDeck_OvalBrassRail", [ellipse(j*TAU/48,z,.85,.66) for j in range(49)], .008)
    for j in range(24):
        a = j*TAU/24
        p = Vector(ellipse(a,-1.4825,.85,.66))
        block("ServiceDeck_BalusterFoot",p+Vector((0,0,.012)),(.025,.025,.024),"ivory")
        line("ServiceDeck_Baluster",[p,p+Vector((0,0,.132))],.006)
        # Crossed brass panels have the same open geometric language as v07.
        if j % 2 == 0:
            line("ServiceDeck_CrossedPanel",[ellipse(a,-1.45,.85,.66),ellipse(a+TAU/24,-1.37,.85,.66)],.0035)
            line("ServiceDeck_CrossedPanel",[ellipse(a,-1.37,.85,.66),ellipse(a+TAU/24,-1.45,.85,.66)],.0035)
    for j in range(8):
        a = j*TAU/8
        group("11_Lower_Service_Gallery", f"Keel-to-gallery bracket {j+1}")
        # Inner end overlaps the existing lower keel socket, outer end meets deck.
        inner = Vector((.045+.17*math.cos(a),.085+.17*math.sin(a),-1.57))
        outer = Vector(ellipse(a,-1.51,.78,.57))
        line("Gallery_RadialLoadBearer",[inner,outer],.027,"ivory",10)
        line("Gallery_BrassBrace",[inner+Vector((0,0,-.035)),outer],.010)
        block("Gallery_BearingShoe",outer,(.065,.065,.030),"gold",.002)
    # Rear ladder connects this maintenance level to the existing back facade.
    group("11_Lower_Service_Gallery", "Rear service ladder and head landing")
    for x in (-.37,-.27):
        line("RearService_LadderStringer",[(x,.51,-1.48),(x,.51,-.77)],.008)
    for i in range(12):
        z=-1.45+i*.059
        line("RearService_LadderRung",[(-.37,.51,z),(-.27,.51,z)],.005)
    block("RearService_HeadLanding",(-.32,.44,-.79),(.18,.29,.035),"ivory",.003)
    for x in (-.38,-.26):
        line("RearService_HeadBracket",[(x*.68,.12,-.92),(x,.52,-.806)],.012)


def flywheel(side):
    centre=Vector((side*.78,.04,-1.27))
    # Local XY wheel rotated into YZ; spokes, rim and teeth are real geometry.
    rotation=Matrix.Rotation(math.pi/2,4,"Y")
    for r,w,depth,mat in ((.158,.029,.028,"gold"),(.119,.010,.037,"copper")):
        obj=kit.ring("SideEngine_FlywheelRim",r,w,0,depth,mat,32,role="Machinery")
        obj.matrix_world=Matrix.Translation(centre)@rotation
    base.cylinder("SideEngine_Crankshaft",(side*.67,.04,-1.27),.024,.29,"gold",20,"X")
    base.cylinder("SideEngine_HubCap",(side*.809,.04,-1.27),.044,.026,"ivory",24,"X")
    for j in range(8):
        a=j*TAU/8
        p=centre+rotation@Vector((.088*math.cos(a),.088*math.sin(a),0))
        obj=block("SideEngine_FlywheelSpoke",(0,0,0),(.128,.014,.019),"ivory")
        obj.matrix_world=Matrix.Translation(p)@rotation@Matrix.Rotation(a,4,"Z")
    for j in range(24):
        a=j*TAU/24
        p=centre+rotation@Vector((.178*math.cos(a),.178*math.sin(a),0))
        obj=block("SideEngine_RimTooth",(0,0,0),(.018,.018,.028),"gold")
        obj.matrix_world=Matrix.Translation(p)@rotation@Matrix.Rotation(a,4,"Z")
    # Bearing pedestals meet both the drive shaft and the service deck.
    for x in (side*.56,side*.72):
        block("SideEngine_ShaftPedestal",(x,.04,-1.378),(.054,.095,.209),"ivory",.003)
        base.cylinder("SideEngine_Bearing",(x,.04,-1.27),.047,.059,"copper",20,"X")
    crank=Vector((side*.80,-.025,-1.235))
    base.cylinder("SideEngine_EccentricCrankPin",crank,.021,.056,"gold",16,"X")
    # Connecting rod and pin overlap, with a second pin at the crosshead.
    line("SideEngine_ConnectingRod",[(side*.80,.04,-1.073),crank],.013,"ivory")


def side_engine(side):
    label="West" if side<0 else "East"
    group("12_Lateral_Flywheel_Engines", label+" piston and flywheel engine")
    x,y=side*.61,.04
    block(label+"Engine_UpperSaddle",(x,y,-.745),(.21,.32,.035),"ivory",.004)
    # Four stays tie the cylinder saddle into the pedestal bed, not open air.
    block(label+"Engine_BaseSkid",(x,y,-1.468),(.27,.35,.029),"gold",.003)
    for yy in (y-.135,y+.135):
        line(label+"Engine_SaddleColumn",[(x,yy,-1.455),(x,yy,-.735)],.015,"ivory",12)
    astral.lathe(label+"Engine_PressureShell",(x,y),[(-1.035,.064),(-1.018,.082),(-.79,.082),(-.765,.064)],"blue",28,"Machinery")
    for z in (-1.03,-.90,-.77):
        base.cylinder(label+"Engine_BrassJacketBand",(x,y,z),.087,.017,"gold",24)
    for yy in (y-.095,y+.095):
        for z in (-1.03,-.77):
            base.cylinder(label+"Engine_HeadBolt",(x,yy,z),.006,.030,"gold",6)
    # Exposed piston rod, crosshead and crank show what drives the wheel.
    line(label+"Engine_PistonRod",[(x,y,-1.04),(x,y,-1.14)],.013,"gold",12)
    block(label+"Engine_Crosshead",(side*.70,y,-1.073),(.22,.048,.040),"gold",.002)
    # Pale-aqua sight glass on the outer-facing cylinder wall.
    block(label+"Engine_SightGlassCase",(x+side*.083,y,-.90),(.015,.040,.165),"gold")
    block(label+"Engine_SightGlass",(x+side*.093,y,-.90),(.006,.025,.140),"opal")
    flywheel(side)
    group("14_Steam_And_Return_Network", label+" engine closed supply and return")
    # These two risers terminate in visible fittings embedded in the upper rock.
    for name,zz,dy,mat in (("Supply",-.77,-.055,"gold"),("Return",-1.015,.055,"copper")):
        pipe(label+"Engine_"+name,[(x,y+dy,zz),(x-side*.16,y+dy,zz),(x-side*.16,y+dy,-.67)],.013,mat)
        base.cylinder(label+"Engine_"+name+"DeckSocket",(x-side*.16,y+dy,-.67),.029,.032,mat,16)
        base.cylinder(label+"Engine_"+name+"PortFlange",(x,y+dy,zz),.022,.034,mat,16)


def rear_condenser():
    group("13_Rear_Condenser_Bank", "Aft twin condensers and cooling matrix")
    block("AftCondenser_MachineSill",(0,.49,-1.464),(.54,.27,.037),"ivory",.003)
    for x in (-.18,.18):
        block("AftCondenser_MountingFoot",(x,.49,-1.405),(.13,.14,.082),"ivory",.003)
        astral.lathe("AftCondenser_DishedPressureVessel",(x,.49),
            [(-1.365,.061),(-1.345,.079),(-.945,.079),(-.914,.048)],"blue" if x<0 else "copper",28,"Machinery")
        for z in (-1.344,-1.145,-.945):
            base.cylinder("AftCondenser_BrassHoop",(x,.49,z),.083,.014,"gold",24)
        for j in range(6):
            a=j*TAU/6
            line("AftCondenser_JacketStave",[(x+.080*math.cos(a),.49+.080*math.sin(a),-1.32),
                 (x+.080*math.cos(a),.49+.080*math.sin(a),-.964)],.0035)
        block("AftCondenser_LevelFrame",(x,.574,-1.145),(.037,.015,.265),"gold")
        block("AftCondenser_LevelGlass",(x,.584,-1.145),(.023,.006,.24),"opal")
        for z in (-1.25,-1.20,-1.15,-1.10,-1.05):
            block("AftCondenser_LevelMark",(x+.014,.590,z),(.013,.004,.003),"ivory")
    for x in (-.087,.087):
        block("AftCondenser_MatrixFrame",(x,.58,-1.16),(.020,.05,.44),"ivory",.002)
    for i in range(16):
        block("AftCondenser_HeatFin",(0,.58,-1.36+i*.026),(.17,.075,.009),"copper")
    for z in (-1.38,-.936):
        block("AftCondenser_MatrixHeader",(0,.58,z),(.195,.08,.023),"gold",.002)
    group("14_Steam_And_Return_Network", "Aft condenser headers to crown plant")
    for name,z,mat in (("Steam",-.907,"gold"),("Return",-1.36,"copper")):
        # Separate hot/cold risers: never hide two circuits on a coincident path.
        xx,yy=(.30,.30) if name=="Steam" else (.35,.35)
        pipe("AftCondenser_"+name+"Header",[(-.18,.49,z),(.18,.49,z),(xx,.49,z),(xx,yy,z),(xx,yy,-.67)],.014,mat)
        line("AftCondenser_"+name+"MatrixBranch",[(0,.49,z),(0,.58,-.936 if name=="Steam" else -1.38)],.009,mat)
        for x in (-.18,.18):
            base.cylinder("AftCondenser_"+name+"VesselFlange",(x,.49,z),.026,.024,mat,16)
        base.cylinder("AftCondenser_"+name+"CrownSocket",(xx,yy,-.67),.03,.034,mat,16)
    # Dedicated planted corbels tie the condenser sill to the lower keel collar.
    group("13_Rear_Condenser_Bank", "Aft condenser cradle")
    for x in (-.18,.18):
        inner_x=.045+math.copysign(.17,x)
        line("AftCondenser_CradleStrut",[(inner_x,.085,-1.57),(x,.49,-1.482)],.024,"ivory",10)


def front_connections():
    group("14_Steam_And_Return_Network", "Existing front engine header termination")
    for name,y,z,r,mat in (("Steam",-.43,-1.012,.020,"gold"),("Return",-.49,-1.47,.017,"copper")):
        base.cylinder("FrontCore_"+name+"BlindFlange",(-.30,y,z),r,.024,mat,16,"X")
    # Front skid projects into the new ring deck; side steps bridge its slight level difference.
    for x in (-.395,.395):
        block("FrontCore_ServiceThreshold",(x,-.43,-1.474),(.09,.20,.017),"gold")


def main():
    for sub in ("source","bom","staging"):
        (OUT/sub).mkdir(parents=True,exist_ok=True)
        (OUT/sub/".gdignore").touch()
    paths=[SOURCE,SOURCE.parent.parent/"island_03.glb",
           ROOT/"assets3D/mind_spark/celestial_islands_v08/shared_paving.glb",
           ROOT/"assets3D/mind_spark/celestial_verdant_v12/island_02.glb"]
    hashes={str(p.relative_to(ROOT)):base.sha(p) for p in paths}
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    base.PARTS[:]=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    for obj in base.PARTS:
        obj["previous_revision_part_id"]=obj.get("part_id","")
    base.SCENE_COLLECTION=bpy.data.collections.new("ASTRAL_V14_UNDERSIDE_COMPLETION")
    bpy.context.scene.collection.children.link(base.SCENE_COLLECTION)
    base.COLLECTIONS.clear();kit.register=base.register
    kit.M={"ivory":bpy.data.materials["MSCT_ivory"],"gold":bpy.data.materials["MSCT_gold"],
           "copper":bpy.data.materials["MSCT_copper.002"],"opal":bpy.data.materials["MSCT_v6_energy"],
           "blue":bpy.data.materials["AstralV13_DeepTealEnamel"]}
    before=sum(len(o.data.polygons) for o in base.PARTS)
    gallery();side_engine(-1);side_engine(1);rear_condenser();front_connections()
    added_triangles=sum(len(o.data.polygons) for o in base.PARTS)-before
    added_parts=len(base.PARTS)-3000
    print("V14_ADDITIONS",added_parts,added_triangles,flush=True)
    astral.OUT=OUT;astral.SOURCE=SOURCE
    record=astral.finish("v14",{"new_underside_components":added_parts,"new_underside_triangles":added_triangles,
        "lateral_flywheel_engines":2,"rear_condenser_vessels":2,"lower_service_gallery":True,
        "source_preservation":"All v13 surface geometry retained. Related fittings grouped to keep 3000 editable objects.",
        "machinery_simulation":"Static fictional lift plant; no new machinery physics or playable lower deck."})
    assert all(base.sha(ROOT/p)==h for p,h in hashes.items()),"Previous assets changed"
    manifest={"revision":"v14","island_id":3,"name":"Astral Observatory","source_checksums":hashes,
              "shared_paving":"res://assets3D/mind_spark/celestial_islands_v08/shared_paving.glb","variant":record}
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("ASTRAL_V14_BUILT",json.dumps(record),flush=True)


if __name__=="__main__":
    main()
