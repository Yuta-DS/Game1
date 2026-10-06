"""Detailed, 3,000-mesh-part-per-island revision. Preserves v07/v08 sources.

Natural connected components are separated first. Remaining authoring granularity
is provided by non-overlapping surface patches, never empty objects or filler bolts.
Run in Blender with --background --python-exit-code 1 --python this_file.py.
"""
import csv
import hashlib
import json
import math
import sys
from collections import Counter, defaultdict
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_celestial_island_variants as kit

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets3D/mind_spark/celestial_islands_v08/source/celestial_island_family_v08.blend"
OUT = ROOT / "assets3D/mind_spark/celestial_islands_v09"
TARGET = 3000
REVISION = "v09"
TAU = math.tau
GROUP = ""
ASSEMBLY = ""
PARTS = []
SCENE_COLLECTION = None
COLLECTIONS = {}


def keep_original(obj, index):
    return not (index == 3 and obj.name.startswith("DawnSmallEngine"))


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def discard_object(obj):
    data=obj.data
    bpy.data.objects.remove(obj,do_unlink=True)
    if data.users==0:
        bpy.data.meshes.remove(data)


def prune_unused_meshes():
    for data in list(bpy.data.meshes):
        if data.users==0:
            bpy.data.meshes.remove(data)


def register(obj, role):
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    key = GROUP or role
    if key not in COLLECTIONS:
        collection = bpy.data.collections.new(key)
        SCENE_COLLECTION.children.link(collection)
        COLLECTIONS[key] = collection
    COLLECTIONS[key].objects.link(obj)
    obj["role"] = role
    obj["assembly"] = ASSEMBLY or obj.name
    obj["category"] = key
    obj["component_kind"] = "constructed_component"
    PARTS.append(obj)
    return obj


kit.register = register


def cylinder(name, center, radius, depth, mat="gold", segments=20, axis="Z"):
    verts = []
    for z in (-depth/2, depth/2):
        for j in range(segments):
            verts.append((radius*math.cos(j*TAU/segments), radius*math.sin(j*TAU/segments), z))
    faces = [(j, (j+1)%segments, (j+1)%segments+segments, j+segments) for j in range(segments)]
    faces += [tuple(reversed(range(segments))), tuple(range(segments, 2*segments))]
    obj = kit.mesh(name, verts, faces, mat, "Machinery", smooth=True)
    for face in obj.data.polygons:
        if abs(face.normal.z) > .9:
            face.use_smooth = False
    obj.location = center
    if axis == "X":
        obj.rotation_euler.y = math.pi/2
    elif axis == "Y":
        obj.rotation_euler.x = math.pi/2
    return obj


def pipe(name, points, radius=.008, mat="copper"):
    # Quadratic corner fillets keep adjacent straight sections tangent.
    points = [Vector(p) for p in points]
    rounded = [points[0]]
    for i in range(1, len(points)-1):
        a,b,c = points[i-1:i+2]
        trim = min((a-b).length, (c-b).length)*.23
        p = b+(a-b).normalized()*trim
        q = b+(c-b).normalized()*trim
        rounded.append(p)
        for k in range(1,7):
            t=k/6
            rounded.append((1-t)**2*p+2*(1-t)*t*b+t*t*q)
    rounded.append(points[-1])
    return kit.tube(name, rounded, radius, mat, "Machinery", sides=10)


def pressure_column(label, x, y, z, h=.36, r=.066, enamel="sage"):
    cylinder(label+"_PressureShell", (x,y,z+h*.5), r, h, enamel, 32)
    for end,zz in enumerate((z,z+h)):
        cylinder(label+f"_EndFlange_{end}", (x,y,zz), r*1.16, .017, "gold",32)
        cylinder(label+f"_DishedCover_{end}", (x,y,zz+(-.011 if end==0 else .011)),r*.91,.022,"ivory",32)
        for j in range(10):
            a=j*TAU/10
            cylinder(label+f"_FlangeFastener_{end}_{j:02d}", (x+r*1.055*math.cos(a),y+r*1.055*math.sin(a),zz+.01),.004,.007,"copper",6)
    for k in range(3):
        cylinder(label+f"_Hoop_{k}",(x,y,z+h*(k+1)/4),r*1.055,.012,"gold",32)
    for j in range(8):
        a=j*TAU/8
        kit.tube(label+f"_JacketStave_{j}",[(x+r*1.015*math.cos(a),y+r*1.015*math.sin(a),z+.02),
            (x+r*1.015*math.cos(a),y+r*1.015*math.sin(a),z+h-.02)],.003,"gold","Machinery",8)
    # A visible level-glass inset with brass casing, not a clock face.
    kit.box(label+"_LevelGlassCasing",(x,y-r-.006,z+h*.51),(.026,.013,h*.59),"gold",.002,"Machinery")
    kit.box(label+"_LevelGlass",(x,y-r-.014,z+h*.51),(.015,.006,h*.51),"opal",.001,"Machinery")
    for j in range(5):
        kit.box(label+f"_LevelGraduation_{j}",(x+.011,y-r-.018,z+h*(.30+.10*j)),(.008,.005,.003),"ivory",0,"Machinery")
    for sx in (-1,1):
        kit.box(label+f"_MountingFoot_{sx}",(x+sx*r*.75,y,z-.035),(.026,.10,.058),"ivory",.002,"Machinery")
    pipe(label+"_SteamRiser",[(x,y,z+h+.019),(x+.04,y,z+h+.055),(x+.10,y,z+h+.055)],.011,"gold")
    pipe(label+"_Drain",[(x,y,z-.012),(x,y-.06,z-.04),(x+.10,y-.06,z-.04)],.008)
    cylinder(label+"_IsolationBody",(x+.055,y,z+h+.055),.017,.035,"gold",16,"X")
    kit.box(label+"_ValveLever",(x+.055,y,z+h+.078),(.054,.014,.012),"copper",.003,"Machinery")


def exchanger(label, x, y, z, width=.14, height=.30):
    for side in (-1,1):
        cylinder(label+f"_WaterHeader_{side}",(x+side*width*.5,y,z),.012,height,"copper",16)
        kit.box(label+f"_FrameUpright_{side}",(x+side*(width*.5+.015),y,z),(.014,.046,height+.035),"gold",.002,"Machinery")
    for k in range(18):
        zz=z-height*.46+k*height*.92/17
        kit.box(label+f"_HeatFin_{k:02d}",(x,y-.012,zz),(width+.01,.052,.008),"copper",.001,"Machinery")
    for side in (-1,1):
        kit.box(label+f"_FrameCap_{side}",(x,y,z+side*(height*.5+.012)),(width+.045,.055,.018),"ivory",.002,"Machinery")


def move_new(start, origin, yaw, scale=1):
    transform=Matrix.Translation(Vector(origin))@Matrix.Rotation(yaw,4,"Z")@Matrix.Scale(scale,4)
    for obj in PARTS[start:]:
        obj.matrix_world=transform@obj.matrix_world


def machinery_bay(label, origin, yaw, scale=1, enamel="sage", vessels=2):
    global GROUP, ASSEMBLY
    GROUP="04_Engine_Assemblies";ASSEMBLY=label
    start=len(PARTS)
    width=.40 if vessels==2 else .69
    header_end=width*.5+.04
    kit.box(label+"_StoneSkid",(0,0,-.052),(width+.10,.31,.055),"ivory",.009,"Machinery")
    kit.box(label+"_BronzeBedplate",(0,0,-.017),(width+.058,.26,.017),"gold",.003,"Machinery")
    xs=[-.115,.115] if vessels==2 else [-.265,0,.265]
    for j,x in enumerate(xs):
        pressure_column(label+f"_Vessel_{j+1}",x,0,.043,.37,.066,enamel)
    exchanger(label+"_Radiator",0,-.10,.21,.13 if vessels==2 else .23,.28)
    pipe(label+"_CommonSteamHeader",[(-header_end,0,.47),(header_end,0,.47),(header_end,.07,.47),(header_end,.07,.57)],.014,"gold")
    pipe(label+"_CommonCondensateHeader",[(-header_end,-.06,.003),(header_end,-.06,.003),(header_end,.07,.003)],.012)
    for j,x in enumerate(xs):
        pipe(label+f"_SteamBranch_{j}",[(x+.10,0,.468),(x+.10,0,.47)],.012,"gold")
        pipe(label+f"_ReturnBranch_{j}",[(x+.10,-.06,.003),(x+.10,-.06,.020)],.011)
    # Front inset framed in ivory; visibly reads as an engineered cabinet.
    for x in (-width*.5,width*.5):
        kit.box(label+"_Jamb",(x,-.015,.23),(.025,.10,.46),"ivory",.003,"Machinery")
        kit.box(label+"_JambInlay",(x,-.070,.24),(.008,.006,.31),"gold",.001,"Machinery")
    kit.box(label+"_Lintel",(0,-.015,.476),(width+.068,.11,.035),"ivory",.004,"Machinery")
    for x in (-width*.39,width*.39):
        kit.box(label+"_WarmInspectionLight",(x,-.082,.416),(.027,.012,.041),"opal",.003,"Machinery")
    bpy.context.view_layer.update()
    move_new(start,origin,yaw,scale)
    # Tie the skid to the island's internal foundation and feed into the deck.
    p=Vector(origin)
    outward=Vector((math.sin(yaw),-math.cos(yaw),0))
    tangent=Vector((math.cos(yaw),math.sin(yaw),0))
    for side in (-1,1):
        at=p+tangent*side*(width*.34*scale)
        anchor=Vector((at.x*.35,at.y*.35,p.z-.19))
        pipe(label+f"_StructuralCorbel_{side}",[anchor,at+Vector((0,0,-.071*scale))],.027*scale,"ivory")
    # Existing port and header termination points are transformed identically.
    tr=Matrix.Translation(p)@Matrix.Rotation(yaw,4,"Z")@Matrix.Scale(scale,4)
    supply=tr@Vector((header_end,.07,.57))
    pipe(label+"_DeckSupply",[supply,Vector((supply.x,supply.y,-.046))],.014*scale,"gold")
    ret=tr@Vector((header_end,.07,.003))
    pipe(label+"_RockReturn",[ret,ret-outward*.18,Vector((ret.x*.50,ret.y*.50,ret.z-.06))],.012*scale)


def rim_cassettes(index):
    global GROUP,ASSEMBLY
    GROUP="03_Civic_Frieze"
    for j in range(36):
        a=j*TAU/36
        ASSEMBLY=f"Rim_Service_Cassette_{j+1:02d}"
        start=len(PARTS)
        kit.box("IvoryFriezeFrame",(0,0,0),(.143,.047,.057),"ivory",.004)
        kit.box("RecessedEnamel",(0,-.027,0),(.115,.009,.035),"blue" if index==2 else "sage",.002)
        for side in (-1,1):
            kit.box("BrassFrameEnd",(side*.059,-.032,0),(.008,.007,.034),"gold",.001)
        for k in range(5):
            kit.box("RecessedVentFin",(-.043+k*.0215,-.034,0),(.006,.007,.023),"gold",.001)
        bpy.context.view_layer.update()
        move_new(start,kit.radial_point(1.012,a,-.078),a+math.pi/2)


def service_gallery(index, radius, z, start, end, spans):
    global GROUP,ASSEMBLY
    GROUP="05_Service_Galleries";ASSEMBLY="Supported lower maintenance gallery"
    kit.ring("MaintenanceStoneWalk",radius,.105,z,.027,"ivory",max(24,spans*4),start,end)
    for h in (.07,.145):
        kit.ring("GalleryBrassHandrail",radius+.055,.009,z+h,.009,"gold",max(24,spans*4),start,end)
    for j in range(spans+1):
        a=start+(end-start)*j/spans
        pipe("HandrailBaluster",[kit.radial_point(radius+.055,a,z),kit.radial_point(radius+.055,a,z+.149)],.006,"gold")
        kit.box("BalusterShoe",kit.radial_point(radius+.055,a,z+.006),(.028,.028,.018),"ivory",.002,yaw=a)
        # Gallery's consoles bury inside the existing rock, not unsupported air.
        pipe("GalleryBearingConsole",[kit.radial_point(.30,a,z-.22),kit.radial_point(radius,a,z-.025)],.022,"ivory")
        if j<spans:
            a2=a+(end-start)/spans
            for k in range(3):
                b=a+(a2-a)*(k+.5)/3
                pipe("FineGalleryPicket",[kit.radial_point(radius+.055,b,z+.008),kit.radial_point(radius+.055,b,z+.142)],.0035,"gold")
            # The panel's curved lower brace is seated on its two balusters.
            pts=[kit.radial_point(radius+.055,a+(a2-a)*t,z+.11-.055*math.sin(t*math.pi)) for t in [k/12 for k in range(13)]]
            pipe("GallerySwanNeckBrace",pts,.004,"gold")


def additions(index):
    rim_cassettes(index)
    if index==0:
        for j,a in enumerate((.28,2.28)):
            machinery_bay(f"Gate_Auxiliary_Pump_{j+1}",kit.radial_point(1.00,a,-.74),a+math.pi/2,.88,"blue")
        service_gallery(index,1.045,-.83,-.05,2.65,14)
    elif index==1:
        for j,a in enumerate((-.15,1.95,4.05)):
            machinery_bay(f"Garden_Irrigation_Exchanger_{j+1}",kit.radial_point(.99,a,-.76),a+math.pi/2,.88,"sage")
        service_gallery(index,1.035,-.85,-math.pi,math.pi,24)
    elif index==2:
        for j in range(5):
            a=-math.pi/2+j*TAU/5
            machinery_bay(f"Astral_Circulation_Station_{j+1}",kit.radial_point(.775,a,-.70),a+math.pi/2,.75,"blue")
        service_gallery(index,.86,-.815,-math.pi,math.pi,20)
    elif index==3:
        # Two broad three-cylinder pressure engines occupy the viaduct bays.
        for j,y in enumerate((-.64,.64)):
            machinery_bay(f"Dawn_Three_Cylinder_Lift_Engine_{j+1}",(0,y,-.87),0 if j==0 else math.pi,1.10,"blue",3)
        service_gallery(index,.80,-1.085,-2.72,-.42,12)
    elif index==4:
        for j in range(4):
            a=-3*math.pi/8+j*math.pi/2
            machinery_bay(f"Storm_Accumulator_Station_{j+1}",kit.radial_point(1.015,a,-.83),a+math.pi/2,.84,"copper")
        service_gallery(index,1.075,-.93,-math.pi,math.pi,24)
    else:
        for j in range(8):
            a=math.pi/8+j*math.pi/4
            machinery_bay(f"Sanctuary_Root_Nutrient_Pump_{j+1}",kit.radial_point(.73,a,-.83),a+math.pi/2,.60,"sage")
        service_gallery(index,.77,-.91,-math.pi,math.pi,24)


def natural_groups(data):
    # Weld only in the connectivity graph. Original vertex positions and split
    # normals are retained; no mesh welding/simplification changes the artwork.
    parent=list(range(len(data.vertices))); seen={}
    def root(i):
        while parent[i]!=i:
            parent[i]=parent[parent[i]];i=parent[i]
        return i
    def union(a,b):
        parent[root(a)]=root(b)
    for vertex in data.vertices:
        key=tuple(round(c,6) for c in vertex.co)
        if key in seen:union(vertex.index,seen[key])
        else:seen[key]=vertex.index
    for edge in data.edges:union(*edge.vertices)
    groups=defaultdict(list)
    for face in data.polygons:groups[root(face.vertices[0])].append(face.index)
    return list(groups.values())


def patch_object(source, faces, name, kind):
    data=source.data
    used=sorted({v for fi in faces for v in data.polygons[fi].vertices})
    remap={v:i for i,v in enumerate(used)}
    verts=[data.vertices[v].co.copy() for v in used]
    polygons=[tuple(remap[v] for v in data.polygons[fi].vertices) for fi in faces]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],polygons)
    for material in data.materials:mesh.materials.append(material)
    normals=[]
    for target,fi in zip(mesh.polygons,faces):
        original=data.polygons[fi]
        target.material_index=original.material_index
        target.use_smooth=original.use_smooth
        if data.has_custom_normals:
            normals.extend(tuple(data.corner_normals[li].vector) for li in original.loop_indices)
    mesh.update()
    if normals:mesh.normals_split_custom_set(normals)
    obj=bpy.data.objects.new(name,mesh)
    source.users_collection[0].objects.link(obj)
    obj.matrix_world=source.matrix_world.copy()
    for key in source.keys():obj[key]=source[key]
    obj["source_component"]=source.get("source_component",source.name)
    obj["component_kind"]=kind
    return obj


def separate_natural_components():
    result=[]
    for obj in list(PARTS):
        groups=natural_groups(obj.data)
        if len(groups)==1:
            result.append(obj);continue
        for j,faces in enumerate(groups):
            result.append(patch_object(obj,faces,obj.name+f"_Block_{j+1:03d}","connected_component"))
        discard_object(obj)
    PARTS[:]=result


def subdivide_to_target():
    # Surface patching is explicit in metadata and BOM. Prefer broad masonry
    # and rock, leaving the mechanical fittings intact as useful whole objects.
    count=0
    while len(PARTS)<TARGET:
        candidates=[o for o in PARTS if o["role"] in ("Rock","Architecture","Paving") and len(o.data.polygons)>=16]
        source=max(candidates,key=lambda o:len(o.data.polygons))
        faces=list(source.data.polygons)
        centers=[p.center for p in faces]
        axis=max(range(3),key=lambda k:max(c[k] for c in centers)-min(c[k] for c in centers))
        order=sorted(range(len(faces)),key=lambda i:(centers[i][axis],i))
        groups=(order[:len(order)//2],order[len(order)//2:])
        replacements=[patch_object(source,group,source.name[:42]+f"_Panel_{count:04d}_{i}","editable_surface_patch") for i,group in enumerate(groups)]
        PARTS.remove(source);PARTS.extend(replacements)
        discard_object(source)
        count+=1
    assert len(PARTS)==TARGET, f"Functional component count exceeds budget: {len(PARTS)}"
    return count


def batch_runtime(index):
    output=[]
    temporary=bpy.data.collections.new("_ExportOnly")
    bpy.context.scene.collection.children.link(temporary)
    for role in kit.ROLES:
        members=[o for o in PARTS if o["role"]==role]
        copies=[]
        for obj in members:
            copy=obj.copy();copy.data=obj.data.copy();temporary.objects.link(copy);copies.append(copy)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in copies:obj.select_set(True)
        bpy.context.view_layer.objects.active=copies[0]
        bpy.ops.object.join()
        merged=bpy.context.object
        merged.data.transform(merged.matrix_world);merged.matrix_world=Matrix.Identity(4)
        merged.name=f"{role}_v09_{index+1:02d}"
        for key in list(merged.keys()):del merged[key]
        merged["role"]=role
        bpy.ops.object.material_slot_remove_unused()
        output.append(merged)
    prune_unused_meshes()
    path=OUT/f"island_{index+1:02d}.glb"
    pending=OUT/"staging"/path.name
    kit.export_parts(output,pending)
    triangles=sum(len(o.data.polygons) for o in output)
    top=max(v.co.z for o in output for v in o.data.vertices)
    assert triangles<500000 and top<.0004,(triangles,top)
    pending.replace(path)
    for obj in output:bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.collections.remove(temporary)
    return triangles,path.stat().st_size


def build(index):
    global GROUP,ASSEMBLY,SCENE_COLLECTION
    # Load just one collection, not the entire six-island scene. This avoids
    # unnecessary peak memory and swap use on a storage-constrained workstation.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    collection_name=f"{index+1:02d}_"+kit.NAMES[index].replace(" ","_")
    with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):
        dst.collections=[collection_name]
    source_collection=dst.collections[0]
    bpy.context.scene.collection.children.link(source_collection)
    originals=list(source_collection.objects)
    keep={o.name for o in originals}
    for obj in list(bpy.data.objects):
        if obj.name not in keep:bpy.data.objects.remove(obj,do_unlink=True)
    SCENE_COLLECTION=bpy.data.collections.new(f"ISLAND_{index+1:02d}_{kit.NAMES[index].replace(' ','_')}_3000")
    bpy.context.scene.collection.children.link(SCENE_COLLECTION)
    COLLECTIONS.clear();PARTS.clear()
    offset=Vector(((index%3-1)*3.0,(1-index//3)*3.0,0))
    bpy.context.view_layer.update()
    for obj in originals:
        obj.data=obj.data.copy()
        obj.location-=offset
        # Replace only the tiny viaduct centre engine; keep its original cross-bearer.
        if not keep_original(obj,index):
            bpy.data.objects.remove(obj,do_unlink=True);continue
        paving=obj.name.startswith("CelestialIvoryDeck")
        role="Paving" if paving else obj["role"]
        GROUP={"Paving":"01_Civic_Paving","Rock":"02_Cliff_Masonry"}.get(role,"00_Preserved_Architecture")
        ASSEMBLY="Shared civic paving" if paving else obj.name
        register(obj,role)
    for collection in list(bpy.data.collections):
        if collection!=SCENE_COLLECTION and collection not in COLLECTIONS.values():
            bpy.data.collections.remove(collection)
    prune_unused_meshes()
    kit.M={"ivory":bpy.data.materials.get("MSCT_ivory"),"gold":bpy.data.materials.get("MSCT_gold"),
           "copper":bpy.data.materials.get("MSCT_copper"),"sage":bpy.data.materials.get("CelestialSageEnamel"),
           "blue":bpy.data.materials.get("CelestialAstralBlueEnamel")}
    if kit.M["sage"] is None:
        kit.M["sage"]=kit.newmat("CelestialSageEnamel",(.24,.43,.33),.20)
    if kit.M["blue"] is None:
        kit.M["blue"]=kit.newmat("CelestialAstralBlueEnamel",(.12,.26,.34),.22)
    assert all(kit.M.values())
    kit.M["opal"]=kit.newmat("V09_WarmOpalInspectionGlass",(.75,.86,.69),.10)
    shader=kit.M["opal"].node_tree.nodes.get("Principled BSDF")
    shader.inputs["Emission Color"].default_value=(.5,.72,.46,1)
    shader.inputs["Emission Strength"].default_value=.25
    additions(index)
    bpy.context.view_layer.update()
    separate_natural_components()
    natural_count=len(PARTS)
    print(f"V09_NATURAL {index+1}: {natural_count}",flush=True)
    splits=subdivide_to_target()
    # Baking local transforms and centring pivots makes every selection editable.
    bpy.context.view_layer.update()
    parts=sorted(PARTS,key=lambda o:(o["category"],o["assembly"],o.name))
    rows=[]
    for j,obj in enumerate(parts):
        obj.data.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
        center=sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)
        obj.data.transform(Matrix.Translation(-center));obj.location=center
        identifier=f"MS{REVISION[1:]}-I{index+1:02d}-P{j+1:04d}"
        previous_name=obj.name
        obj.name=identifier+"_"+previous_name[:35]
        obj["part_id"]=identifier;obj["island_id"]=index+1
        rows.append({"part_id":identifier,"name":previous_name,"category":obj["category"],
            "assembly":obj["assembly"],"role":obj["role"],"kind":obj["component_kind"],
            "triangles":len(obj.data.polygons),"source_component":obj.get("source_component",previous_name),
            "motion_id":obj.get("motion_id", "")})
    bpy.context.view_layer.update()
    triangles,size=batch_runtime(index)
    # Discard unreferenced imported mesh data before saving. Live geometry stays.
    prune_unused_meshes()
    bpy.context.preferences.filepaths.save_version=0
    pending=OUT/f"staging/island_{index+1:02d}_3000.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(pending),compress=True)
    pending.replace(OUT/f"source/island_{index+1:02d}_3000.blend")
    with (OUT/f"bom/island_{index+1:02d}_parts.csv").open("w",newline="") as stream:
        writer=csv.DictWriter(stream,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    record={"id":index+1,"name":kit.NAMES[index],"file":f"island_{index+1:02d}.glb",
        "source":f"source/island_{index+1:02d}_3000.blend","bom":f"bom/island_{index+1:02d}_parts.csv",
        "editable_mesh_parts":len(parts),"natural_components_before_patching":natural_count,
        "surface_split_operations":splits,"component_kinds":dict(Counter(row["kind"] for row in rows)),
        "categories":dict(Counter(row["category"] for row in rows)),"runtime_triangles":triangles,"glb_bytes":size}
    print("V09_ISLAND: "+json.dumps(record),flush=True)
    (OUT/f"island_{index+1:02d}_record.json").write_text(json.dumps(record,indent=2)+"\n")
    return record


def main():
    OUT.mkdir(exist_ok=True)
    (OUT/"source").mkdir(exist_ok=True);(OUT/"source/.gdignore").touch()
    (OUT/"bom").mkdir(exist_ok=True);(OUT/"bom/.gdignore").touch()
    (OUT/"staging").mkdir(exist_ok=True);(OUT/"staging/.gdignore").touch()
    sources=[SOURCE,ROOT/"assets3D/mind_spark/celestial_condenser_v07/source/celestial_condenser_v07.blend"]
    before={str(p.relative_to(ROOT)):sha(p) for p in sources}
    selected=next((int(s.split("=",1)[1])-1 for s in sys.argv if s.startswith("--island=")),None)
    if selected is not None:
        build(selected)
        assert all(sha(ROOT/p)==value for p,value in before.items())
        return
    if "--finalize" in sys.argv:
        records=[json.loads((OUT/f"island_{i+1:02d}_record.json").read_text()) for i in range(6)]
    else:
        records=[build(i) for i in range(6)]
    assert all(sha(ROOT/p)==value for p,value in before.items())
    manifest={"revision":"v09","parts_per_island":3000,"total_editable_mesh_parts":18000,
        "source_checksums":before,"sources_unchanged":True,
        "shared_paving":"res://assets3D/mind_spark/celestial_islands_v08/shared_paving.glb",
        "counting_policy":"Real nonempty mesh objects: constructed fittings, connected stone/component pieces and explicitly labelled surface patches. Not 3000 closed solids or machines.",
        "variants":records}
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("V09_COMPLETE: 18000 editable mesh parts",flush=True)


if __name__=="__main__":main()
