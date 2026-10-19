"""Independent geometry, preservation, inventory and split-keel clearance audit."""
import csv
import json
import math
import sys
from collections import Counter
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0,str(Path(__file__).resolve().parent))
import validate_celestial_islands_v09 as common
import validate_celestial_islands_v11 as reference

ROOT=common.ROOT
OUT=ROOT/"assets3D/mind_spark/celestial_verdant_v12"


def meshes():
    bpy.context.view_layer.update()
    return [o for o in bpy.context.scene.objects if o.type=="MESH"]


def gap_probes(objects):
    vertices=[];faces=[]
    for obj in objects:
        if obj.get("role")!="Rock" and not obj.name.startswith("Rock_"):
            continue
        offset=len(vertices)
        vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        faces.extend(tuple(offset+i for i in p.vertices) for p in obj.data.polygons)
    tree=BVHTree.FromPolygons(vertices,faces,all_triangles=True)
    return all(tree.ray_cast(Vector((x,-3,z)),Vector((0,1,0)),6)[0] is None
        for x in (-.06,0,.06) for z in (-1.05,-1.25,-1.45))


def main():
    manifest=json.loads((OUT/"manifest.json").read_text())
    record=manifest["variant"]
    checks={"preserved_baseline_files":all(common.sha(ROOT/p)==h for p,h in manifest["source_checksums"].items())}
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/"assets3D/mind_spark/celestial_islands_v11/source/island_02_3000.blend"))
    originals=meshes()
    preserved_reference=common.measurements([o for o in originals if o["category"]=="04_Reference_Enginehouses"])
    preserved_rails=common.measurements([o for o in originals if o["role"]=="Railing"])
    bpy.ops.wm.open_mainfile(filepath=str(OUT/record["source"]))
    objects=meshes()
    rows=list(csv.DictReader((OUT/record["bom"]).open()))
    ids=[o.get("part_id","") for o in objects]
    checks.update(exactly_3000_nonempty_parts=len(objects)==3000 and all(len(o.data.polygons)>0 for o in objects),
        unique_ids=len(set(ids))==3000 and all(p.startswith("MS12-I02-P") for p in ids),
        bom_matches=len(rows)==3000 and {r["part_id"] for r in rows}==set(ids),
        kind_counts_match=dict(Counter(o["component_kind"] for o in objects))==record["component_kinds"],
        bom_triangles_match=sum(int(r["triangles"]) for r in rows)==sum(len(o.data.polygons) for o in objects),
        original_enginehouse_geometry_retained=common.close(preserved_reference,common.measurements([o for o in objects if o["category"]=="04_Reference_Enginehouses"])),
        original_route_openings_retained=common.close(preserved_rails,common.measurements([o for o in objects if o["role"]=="Railing"])),
        four_planted_terraces=len({o["assembly"] for o in objects if o["category"]=="08_Hanging_Garden_Terraces" and o["assembly"].endswith("masonry")})==4,
        four_pressure_stays=len({o["assembly"] for o in objects if o["category"]=="10_Steam_Lift_Structure" and "suspension stay" in o["assembly"]})==4,
        source_split_keel_open_air=gap_probes(objects))
    checks.update(reference.check_geometry(objects,record,"source"))
    source=common.measurements([o for o in objects if o["role"]!="Paving"])
    paving=common.measurements([o for o in objects if o["role"]=="Paving"])
    checks["visibly_wider_asymmetric_silhouette"]=source["bounds"][1][0]-source["bounds"][0][0]>2.85 and source["bounds"][0][2]<-1.95
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT/record["file"]))
    runtime=meshes()
    measure=common.measurements(runtime)
    checks.update(reference.check_geometry(runtime,record,"runtime"))
    checks.update(five_batched_families=len(runtime)==5,source_export_coverage=common.close(source,measure),
        triangle_count_match=measure["triangles"]==record["runtime_triangles"],triangle_budget=measure["triangles"]<540000,
        runtime_split_keel_open_air=gap_probes(runtime))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/manifest["shared_paving"].removeprefix("res://")))
    shared=common.measurements(meshes())
    checks["paving_unchanged"]=common.close(paving,shared)
    report={"checks":checks,"passed":all(checks.values()),"runtime":measure,"visible_triangles":measure["triangles"]+shared["triangles"]}
    (OUT/"validation_report.json").write_text(json.dumps(report,indent=2)+"\n")
    print("VERDANT_V12_AUDIT",json.dumps(report),flush=True)
    assert report["passed"]


if __name__=="__main__":main()
