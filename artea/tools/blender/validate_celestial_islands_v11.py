"""Independent source/export geometry, part inventory and route-clearance audit."""
import csv
import json
import math
import sys
from collections import Counter
from pathlib import Path
import bpy
from mathutils import Vector, Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
import validate_celestial_islands_v09 as common

ROOT=common.ROOT
OUT=ROOT/"assets3D/mind_spark/celestial_islands_v11"


def check_geometry(objects,record,source):
    checks=common.geometry_checks(objects)
    del checks["below_walkable_plane"]
    rails=[o for o in objects if o.get("role")=="Railing" or o.name.startswith("Railing_v11_")]
    ground=[o for o in objects if o not in rails]
    points=[o.matrix_world@v.co for o in rails for v in o.data.vertices]
    directions=[Vector(d) for d in record["route_directions_blender"]]
    checks.update(nonrail_below_walkable_plane=max((o.matrix_world@v.co).z for o in ground for v in o.data.vertices)<.0004,
        railing_outside_gameplay_disc=bool(points) and min(math.hypot(v.x,v.y) for v in points)>1.003,
        bridge_and_station_openings=not any(v.dot(d)>.72 and abs(v.x*d.y-v.y*d.x)<record["route_half_width"]-1e-5 for v in points for d in directions))
    return {source+"_"+k:v for k,v in checks.items()}


def audit(record):
    bpy.ops.wm.open_mainfile(filepath=str(OUT/record["source"]))
    objects=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    rows=list(csv.DictReader((OUT/record["bom"]).open()))
    ids=[o.get("part_id","") for o in objects]
    checks={"exactly_3000_nonempty_parts":len(objects)==3000 and all(len(o.data.polygons)>0 for o in objects),
        "unique_ids":len(set(ids))==3000 and all(p.startswith(f"MS11-I{record['id']:02d}-P") for p in ids),
        "bom_matches":len(rows)==3000 and {r["part_id"] for r in rows}==set(ids),
        "kind_counts_match":dict(Counter(o["component_kind"] for o in objects))==record["component_kinds"],
        "two_reference_enginehouses":all(any(o["assembly"].startswith(f"Enginehouse_{side}_") for o in objects) for side in (1,2))}
    checks.update(check_geometry(objects,record,"source"))
    yaw=[0,.20,-.12,.10,math.pi/8,-.18][record["id"]-1]
    rotation=Matrix.Rotation(-yaw,4,"Z")
    depth=record["facade_depth_factor"]
    intersects=False
    for obj in objects:
        if obj.get("role")!="Rock":continue
        points=[rotation@obj.matrix_world@v.co for v in obj.data.vertices]
        low=[min(v[k] for v in points) for k in range(3)]
        high=[max(v[k] for v in points) for k in range(3)]
        if high[0]<-.77 or low[0]>.77 or high[2]<-.85*depth or low[2]>-.12*depth:continue
        if (low[1]<-.645 and high[1]<.2) or (high[1]>.645 and low[1]>-.2):intersects=True
    checks["rock_clear_of_recessed_machinery"]=not intersects
    source=common.measurements([o for o in objects if o["role"]!="Paving"])
    paving=common.measurements([o for o in objects if o["role"]=="Paving"])
    checks["bom_triangles_match"]=sum(int(r["triangles"]) for r in rows)==sum(len(o.data.polygons) for o in objects)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT/record["file"]));bpy.context.view_layer.update()
    runtime=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    measure=common.measurements(runtime)
    checks.update(check_geometry(runtime,record,"runtime"))
    checks["five_batched_families"]=len(runtime)==5
    checks["source_export_coverage"]=common.close(source,measure)
    checks["triangle_count_match"]=measure["triangles"]==record["runtime_triangles"]
    checks["triangle_budget"]=measure["triangles"]<540000
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/"assets3D/mind_spark/celestial_islands_v08/shared_paving.glb"))
    shared=common.measurements([o for o in bpy.context.scene.objects if o.type=="MESH"])
    checks["paving_unchanged"]=common.close(paving,shared)
    report={"id":record["id"],"checks":checks,"passed":all(checks.values()),"visible_triangles":measure["triangles"]+shared["triangles"]}
    (OUT/f"island_{record['id']:02d}_audit.json").write_text(json.dumps(report,indent=2)+"\n")
    print("V11_AUDIT: "+json.dumps(report),flush=True)
    assert report["passed"]


def main():
    if "--finalize" in sys.argv:
        manifest=json.loads((OUT/"manifest.json").read_text())
        reports=[json.loads((OUT/f"island_{i+1:02d}_audit.json").read_text()) for i in range(6)]
        total=sum(r["visible_triangles"] for r in reports)
        checks={"all_islands_pass":all(r["passed"] for r in reports),"whole_family_budget":total<3500000,
            "preserved_sources":all(common.sha(ROOT/p)==h for p,h in manifest["source_checksums"].items())}
        report={"checks":checks,"passed":all(checks.values()),"visible_triangles":total,"islands":reports}
        (OUT/"validation_report.json").write_text(json.dumps(report,indent=2)+"\n")
        print("V11_AUDIT_FINAL",json.dumps({k:v for k,v in report.items() if k!="islands"}),flush=True)
        assert report["passed"]
    else:
        index=int(next(s.split("=",1)[1] for s in sys.argv if s.startswith("--island=")))
        audit(json.loads((OUT/f"island_{index:02d}_record.json").read_text()))


if __name__=="__main__":main()
