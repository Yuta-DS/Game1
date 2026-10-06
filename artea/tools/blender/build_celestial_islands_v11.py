"""Reference-style game islands: original v07 enginehouses, v08 footprints.

Run --prepare once; --island=1..6 in separate Blender processes; --finalize.
No earlier source is modified. Authoring meshes are honestly grouped/patched
to 3,000; runtime has five role batches plus the existing shared paving.
"""
import csv
import json
import math
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_celestial_islands_v09 as base
kit=base.kit
ROOT=base.ROOT
OUT=ROOT/"assets3D/mind_spark/celestial_islands_v11"
REFERENCE=ROOT/"assets3D/mind_spark/celestial_condenser_v07/source/celestial_condenser_v07.blend"
RUNTIME_REFERENCE=ROOT/"assets3D/mind_spark/celestial_land_runtime/celestial_land.glb"
ROLES=["Rock","Architecture","Machinery","Inlay","Railing"]
POSITIONS=[(-960,420),(-800,100),(-300,-220),(170,120),(620,20),(940,-420)]
RADII=[125,190,175,120,210,180]
DEPTH=[1.0,.88,.96,1.08,.82,1.12]
YAW=[0,.20,-.12,.10,math.pi/8,-.18]


def prepare():
    """Load only the 430 original railing/lantern components, not the whole scene."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    data=json.loads((REFERENCE.parent.parent/"parts_manifest.json").read_text())
    names=[p["name"] for p in data["parts"] if p["family"]=="04_Railings_Lamps"]
    with bpy.data.libraries.load(str(REFERENCE),link=False) as (_,dst):dst.objects=names
    objects=dst.objects
    for obj in objects:bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.update()
    for obj in objects:
        obj.data.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.dissolve_limit(bm,angle_limit=math.radians(2),verts=list(bm.verts),edges=list(bm.edges),delimit={"MATERIAL"})
        bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
        if len(obj.data.polygons)>360:
            bpy.context.view_layer.objects.active=obj
            modifier=obj.modifiers.new("ReferenceRailingRuntimeBudget","DECIMATE")
            modifier.ratio=max(.24,240/len(obj.data.polygons));modifier.use_collapse_triangulate=True
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.data.validate()
        obj.data.transform(Matrix.Diagonal((1.073/7.83,1.073/7.83,1/7.83,1)))
        obj["source_component"]=obj.name
    posts={};panels={}
    def center(obj):return sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)
    for obj in objects:
        name=obj.get("design_part",obj.name)
        post=re.fullmatch(r"Post(\d+)_plinth",name)
        panel=re.fullmatch(r"Balustrade(\d+)_stone_sill",name)
        if post:posts[int(post[1])]=center(obj)
        if panel:panels[int(panel[1])]=center(obj)
    assert len(posts)==12 and len(panels)>0
    for obj in objects:
        name=obj.get("design_part",obj.name)
        # All filigree in one bay is kept/omitted together. No orphaned scrolls.
        panel=re.match(r"Balustrade(\d+)_",name)
        post=re.match(r"(?:Post|Lantern)(\d+)_",name)
        if panel:key=f"Panel_{int(panel[1]):02d}"
        elif post:key=f"Post_{int(post[1]):02d}"
        elif "Balustrade" in name:
            key=f"Panel_{min(panels,key=lambda k:(panels[k]-center(obj)).length):02d}"
        else:key=f"Post_{min(posts,key=lambda k:(posts[k]-center(obj)).length):02d}"
        obj["railing_group"]=key
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"source/reference_railings.blend"),compress=True)
    print("V11_RAILINGS_PREPARED",len(objects),flush=True)


def directions(index):
    x,y=POSITIONS[index]
    result=[]
    for other in ((index-1)%6,(index+1)%6):
        xx,yy=POSITIONS[other]
        # Godot horizontal Z maps to Blender negative Y.
        d=Vector((xx-x,y-yy,0)).normalized();result.append(d)
    if index==4:result.append(Vector((0,-1,0)))  # Existing Godot +Z station spur.
    return result


def in_route(vertex,index):
    half_width=22/RADII[index]  # 28 m bridge plus 8 m clearance on each side.
    return any(vertex.dot(d)>.72 and abs(vertex.x*d.y-vertex.y*d.x)<half_width for d in directions(index))


def register(obj,role,category,assembly):
    base.GROUP=category;base.ASSEMBLY=assembly
    return base.register(obj,role)


def recess_rock_behind_enginehouses(index):
    """Move whole cliff stones behind the two machine bays, without cutting faces.

    The v08 rock profiles have different taper/bulge/depth. The reference's
    inset machine envelope must be reserved again after adapting that profile.
    Whole-piece translation preserves triangles, normals and part identities.
    """
    bpy.context.view_layer.update()
    inverse=Matrix.Rotation(-YAW[index],4,"Z")
    rotation=Matrix.Rotation(YAW[index],4,"Z")
    moved=0
    for obj in base.PARTS:
        if obj.get("role")!="Rock":continue
        points=[inverse@obj.matrix_world@v.co for v in obj.data.vertices]
        low=[min(v[k] for v in points) for k in range(3)]
        high=[max(v[k] for v in points) for k in range(3)]
        if high[0]<-.77 or low[0]>.77 or high[2]<-.85*DEPTH[index] or low[2]>-.12*DEPTH[index]:continue
        delta=0
        if low[1]<-.645 and high[1]<.2:delta=-.64-low[1]
        elif high[1]>.645 and low[1]>-.2:delta=.64-high[1]
        if delta:
            obj.location+=rotation@Vector((0,delta,0))
            obj["machine_bay_rock_recess"]=float(delta);moved+=1
    bpy.context.view_layer.update()
    return moved


def combine_to_budget(max_group_size=2):
    """Group related small fittings if necessary; never discard/pad geometry."""
    operations=0
    while len(base.PARTS)>3000:
        grouped=defaultdict(list)
        for obj in base.PARTS:
            if obj["role"] in ("Architecture","Machinery","Railing"):
                grouped[(obj["role"],obj["assembly"])].append(obj)
        candidates=[v for v in grouped.values() if len(v)>1]
        count=min(max_group_size,len(base.PARTS)-3000+1)
        members=min((sorted(v,key=lambda o:len(o.data.polygons))[:count] for v in candidates),
                    key=lambda pair:sum(len(o.data.polygons) for o in pair)/(len(pair)-1))
        keys=[o.get("source_component",o.name) for o in members]
        bpy.ops.object.select_all(action="DESELECT")
        for obj in members:obj.select_set(True);base.PARTS.remove(obj)
        bpy.context.view_layer.objects.active=members[0]
        bpy.ops.object.join()
        obj=bpy.context.object
        obj["component_kind"]="grouped_related_fittings"
        obj["source_component"]=" | ".join(keys)
        base.PARTS.append(obj);operations+=len(members)-1
        base.prune_unused_meshes()
    return operations


def batch(index, triangle_limit=540000):
    temporary=bpy.data.collections.new("_ExportOnly");bpy.context.scene.collection.children.link(temporary)
    output=[]
    for role in ROLES:
        members=[o for o in base.PARTS if o["role"]==role]
        assert members,role
        copies=[]
        for obj in members:
            copy=obj.copy();copy.data=obj.data.copy();temporary.objects.link(copy);copies.append(copy)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in copies:obj.select_set(True)
        bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join()
        merged=bpy.context.object
        merged.data.transform(merged.matrix_world);merged.matrix_world=Matrix.Identity(4)
        merged.name=f"{role}_v11_{index+1:02d}"
        for key in list(merged.keys()):del merged[key]
        merged["role"]=role
        bpy.ops.object.material_slot_remove_unused();output.append(merged)
    bpy.context.view_layer.update();base.prune_unused_meshes()
    triangles=sum(len(o.data.polygons) for o in output)
    assert triangles<triangle_limit,triangles
    pending=OUT/f"staging/island_{index+1:02d}.glb"
    kit.export_parts(output,pending);pending.replace(OUT/pending.name)
    for obj in output:base.discard_object(obj)
    bpy.data.collections.remove(temporary);base.prune_unused_meshes()
    return triangles


def build(index):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    collection_name=f"{index+1:02d}_"+kit.NAMES[index].replace(" ","_")
    with bpy.data.libraries.load(str(base.SOURCE),link=False) as (_,dst):dst.collections=[collection_name]
    original=dst.collections[0];bpy.context.scene.collection.children.link(original)
    originals=list(original.objects)
    base.SCENE_COLLECTION=bpy.data.collections.new(f"ISLAND_{index+1:02d}_REFERENCE_STYLE_3000")
    bpy.context.scene.collection.children.link(base.SCENE_COLLECTION)
    base.PARTS.clear();base.COLLECTIONS.clear()
    offset=Vector(((index%3-1)*3,(1-index//3)*3,0))
    bpy.context.view_layer.update()
    for obj in originals:
        role="Paving" if obj.name.startswith("CelestialIvoryDeck") else obj.get("role")
        if role not in ("Paving","Rock","Inlay"):
            base.discard_object(obj);continue
        obj.data=obj.data.copy();obj.location-=offset
        register(obj,role,{"Rock":"01_Rock_Profile","Paving":"02_Shared_Paving","Inlay":"03_Island_Identity"}[role],obj.name)
    bpy.data.collections.remove(original)
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(RUNTIME_REFERENCE))
    imported=[o for o in bpy.data.objects if o not in before]
    for obj in imported:
        if obj.type!="MESH" or obj.name.startswith(("CelestialRockAnchors","CelestialIvoryDeck")):
            if obj.type=="MESH":base.discard_object(obj)
            else:bpy.data.objects.remove(obj,do_unlink=True)
            continue
        template_matrix=obj.matrix_world.copy()
        # Two complete twin-arch enginehouses, seated on the opposite faces.
        # Keep their original fit, pipe joins, condenser and supported balcony.
        for side in range(2):
            copy=obj.copy();copy.data=obj.data.copy()
            bpy.context.scene.collection.objects.link(copy)
            copy.matrix_world=Matrix.Rotation(YAW[index]+side*math.pi,4,"Z") @ Matrix.Diagonal((1,1,DEPTH[index],1)) @ template_matrix
            copy.name=f"ReferenceEnginehouse_{side+1}_"+obj.name
            role="Machinery" if "Steam" in obj.name else "Architecture"
            register(copy,role,"04_Reference_Enginehouses",f"Enginehouse_{side+1}_"+obj.name)
        base.discard_object(obj)
    base.prune_unused_meshes()
    with bpy.data.libraries.load(str(OUT/"source/reference_railings.blend"),link=False) as (_,dst):
        dst.objects=[name for name in _.objects if name.startswith("CT3_")]
    rail_groups=defaultdict(list)
    for obj in dst.objects:
        bpy.context.scene.collection.objects.link(obj)
        rail_groups[obj["railing_group"]].append(obj)
    omitted=[];kept=[]
    for key,parts in rail_groups.items():
        if any(in_route(v.co,index) for o in parts for v in o.data.vertices):
            omitted.append(key)
            for obj in parts:base.discard_object(obj)
        else:
            kept.append(key)
            for obj in parts:register(obj,"Railing","05_Reference_Balustrades",key)
    kit.M={"ivory":bpy.data.materials.get("MSCT_ivory"),"gold":bpy.data.materials.get("MSCT_gold")}
    kit.register=base.register
    base.GROUP="06_Bearing_Cornice";base.ASSEMBLY="Continuous railing bearing cornice"
    kit.ring("IvoryRailingBearingCornice",1.025,.13,-.021,.038,"ivory",192)
    kit.ring("ChampagneCorniceReveal",1.092,.010,-.027,.014,"gold",192,role="Inlay")
    bpy.context.view_layer.update();base.separate_natural_components()
    natural=len(base.PARTS)
    merges=combine_to_budget();splits=base.subdivide_to_target()
    recessed=recess_rock_behind_enginehouses(index)
    parts=sorted(base.PARTS,key=lambda o:(o["category"],o["assembly"],o.name));rows=[]
    for j,obj in enumerate(parts):
        obj.data.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
        center=sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)
        obj.data.transform(Matrix.Translation(-center));obj.location=center
        identifier=f"MS11-I{index+1:02d}-P{j+1:04d}";previous=obj.name
        obj.name=identifier+"_"+previous[:32];obj["part_id"]=identifier;obj["island_id"]=index+1
        rows.append({"part_id":identifier,"name":previous,"role":obj["role"],"category":obj["category"],
            "assembly":obj["assembly"],"kind":obj["component_kind"],"triangles":len(obj.data.polygons),
            "source_component":obj.get("source_component",previous)})
    bpy.context.view_layer.update()
    triangles=batch(index)
    bpy.context.preferences.filepaths.save_version=0
    pending=OUT/f"staging/island_{index+1:02d}_3000.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(pending),compress=True);pending.replace(OUT/"source"/pending.name)
    with (OUT/f"bom/island_{index+1:02d}_parts.csv").open("w",newline="") as stream:
        writer=csv.DictWriter(stream,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    record={"id":index+1,"name":kit.NAMES[index],"file":f"island_{index+1:02d}.glb",
        "source":f"source/island_{index+1:02d}_3000.blend","bom":f"bom/island_{index+1:02d}_parts.csv",
        "editable_mesh_parts":3000,"runtime_meshes":5,"runtime_triangles":triangles,
        "natural_components":natural,"related_fitting_merges":merges,"surface_patch_splits":splits,
        "component_kinds":dict(Counter(o["component_kind"] for o in parts)),
        "enginehouse_count":2,"arch_bays":4,"retained_railing_groups":kept,"omitted_railing_groups":omitted,
        "route_directions_blender":[list(v) for v in directions(index)],"route_half_width":22/RADII[index],
        "radius":RADII[index],"facade_depth_factor":DEPTH[index],"recessed_rock_parts":recessed}
    (OUT/f"island_{index+1:02d}_record.json").write_text(json.dumps(record,indent=2)+"\n")
    print("V11_BUILT: "+json.dumps(record),flush=True)


def main():
    for sub in ("source","bom","staging"):
        (OUT/sub).mkdir(parents=True,exist_ok=True);(OUT/sub/".gdignore").touch()
    sources=[REFERENCE,base.SOURCE,RUNTIME_REFERENCE]
    hashes={str(p.relative_to(ROOT)):base.sha(p) for p in sources}
    if "--prepare" in sys.argv:prepare()
    elif "--finalize" in sys.argv:
        records=[json.loads((OUT/f"island_{i+1:02d}_record.json").read_text()) for i in range(6)]
        manifest={"revision":"v11","style_reference_revision":"v07","parts_per_island":3000,
            "total_editable_mesh_parts":18000,"shared_paving":"res://assets3D/mind_spark/celestial_islands_v08/shared_paving.glb",
            "source_checksums":hashes,"variants":records,
            "counting_policy":"3,000 nonempty editable mesh objects per island: connected pieces, transparently grouped related fittings and surface patches. No filler objects.",
            "adaptations":"Reference enginehouse repeated on two faces. Original ornate railings outside gameplay disc; whole bays omitted for bridge/station openings. Raised stairs, basin and planters not pasted over existing game content.",
            "collision_policy":"Existing game floors and route collisions retained; visual asset has no collision bodies.",
            "machinery_policy":"Static fictional steam machinery, not an operating lift simulation."}
        (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    elif any(s.startswith("--repair=") for s in sys.argv):
        index=int(next(s.split("=",1)[1] for s in sys.argv if s.startswith("--repair=")))-1
        assert 0<=index<6
        record_path=OUT/f"island_{index+1:02d}_record.json"
        record=json.loads(record_path.read_text())
        bpy.ops.wm.open_mainfile(filepath=str(OUT/record["source"]))
        base.PARTS[:]=[o for o in bpy.context.scene.objects if o.type=="MESH"]
        record["recessed_rock_parts"]=recess_rock_behind_enginehouses(index)
        record["runtime_triangles"]=batch(index)
        bpy.context.preferences.filepaths.save_version=0
        pending=OUT/f"staging/island_{index+1:02d}_3000.blend"
        bpy.ops.wm.save_as_mainfile(filepath=str(pending),compress=True)
        pending.replace(OUT/record["source"])
        record_path.write_text(json.dumps(record,indent=2)+"\n")
        print("V11_ROCK_RECESSED",index+1,record["recessed_rock_parts"],flush=True)
    else:
        index=int(next(s.split("=",1)[1] for s in sys.argv if s.startswith("--island=")))-1
        assert 0<=index<6;build(index)
    assert all(base.sha(ROOT/p)==h for p,h in hashes.items()),"Earlier source changed"


if __name__=="__main__":main()
