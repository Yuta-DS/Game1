"""Measure real perimeter coverage and side-bay closure, not just node counts."""
import csv
import json
import math
import sys
from collections import Counter
from pathlib import Path
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
import validate_astral_underside_v14 as prior
common,castle=prior.common,prior.castle
ROOT=prior.ROOT
OUT=ROOT/"assets3D/mind_spark/celestial_astral_v15"


def perimeter(objects):
    rails=[o for o in objects if o.get("role")=="Railing" or o.name.startswith("Railing_")]
    tree=prior.surface(rails)
    directions=[Vector((-.842271447,-.539053738,0)),Vector((.810224473,-.586119831,0))]
    gaps=[];checked=0
    # 0.5-degree samples at the continuous upper handrail elevation.
    for j in range(720):
        a=(j+.5)*math.tau/720
        d=Vector((math.cos(a),math.sin(a),0))
        if any(d.dot(v)>.72 and abs(d.x*v.y-d.y*v.x)<22/175/1.003+.008 for v in directions):continue
        checked+=1
        start=d*.99+Vector((0,0,.135))
        if tree.ray_cast(start,d,.16)[0] is None:gaps.append(round(math.degrees(a),3))
    return {"samples":checked,"missing_angles_degrees":gaps,"passed":not gaps}


def main():
    manifest=json.loads((OUT/"manifest.json").read_text());record=manifest["variant"]
    checks={"previous_assets_unchanged":all(common.sha(ROOT/p)==h for p,h in manifest["source_checksums"].items())}
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/"assets3D/mind_spark/celestial_astral_v14/source/island_03_3000.blend"))
    old=castle.meshes();categories=sorted({o["category"] for o in old})
    previous={c:common.measurements([o for o in old if o["category"]==c]) for c in categories}
    old_total=sum(len(o.data.polygons) for o in old)
    before_coverage=perimeter(old)
    bpy.ops.wm.open_mainfile(filepath=str(OUT/record["source"]));objects=castle.meshes()
    ids=[o.get("part_id","") for o in objects]
    rows=list(csv.DictReader((OUT/record["bom"]).open()))
    checks.update(exactly_3000_nonempty_parts=len(objects)==3000 and all(len(o.data.polygons)>0 for o in objects),
        unique_ids=len(set(ids))==3000 and all(p.startswith("MS15-I03-P") for p in ids),
        matching_inventory=len(rows)==3000 and {r["part_id"] for r in rows}==set(ids),
        matching_component_kinds=dict(Counter(o["component_kind"] for o in objects))==record["component_kinds"],
        matching_inventory_triangles=sum(int(r["triangles"]) for r in rows)==sum(len(o.data.polygons) for o in objects))
    for c in categories:checks["preserved_"+c]=common.close(previous[c],common.measurements([o for o in objects if o["category"]==c]))
    checks.update(castle.geometry(objects,record,"source"))
    added=[o for o in objects if o["category"] not in categories]
    checks["new_geometry_accounted"]=sum(len(o.data.polygons) for o in added)==record["new_enclosure_triangles"]==sum(len(o.data.polygons) for o in objects)-old_total
    bays=[o for o in added if o["category"]=="16_Carved_Side_Engine_Bays"]
    checks["new_bays_below_gameplay_plane"]=max((o.matrix_world@v.co).z for o in bays for v in o.data.vertices)<-.04
    checks["two_seated_arch_assemblies"]=len({o["assembly"] for o in bays if "seated arch" in o["assembly"]})==2
    chamber_surface=prior.surface(bays)
    bay_misses=[]
    for side in (-1,1):
        for u in (-.20,-.10,0,.10,.20):
            for z in (-1.35,-1.10,-.85,-.60,-.40):
                if chamber_surface.ray_cast(Vector((side*1.1,.04+u,z)),Vector((-side,0,0)),.7)[0] is None:bay_misses.append([side,u,z])
    checks["side_bays_visually_enclosed"]=not bay_misses
    collar=prior.surface([o for o in objects if o["assembly"]=="Keel crown bearing bands"])
    braces=prior.surface([o for o in bays if "tied bay footing" in o["assembly"]])
    roots=[(.045+side*.17,.085,-1.57) for side in (-1,1)]
    checks["side_bay_braces_seated_in_keel"]=prior.nearby(collar,roots,.03) and prior.nearby(braces,roots,.022)
    source_coverage=perimeter(objects)
    checks["source_perimeter_has_no_unintended_gaps"]=source_coverage["passed"]
    checks["baseline_gap_detected"]=not before_coverage["passed"]
    source=common.measurements([o for o in objects if o["role"]!="Paving"])
    paving=common.measurements([o for o in objects if o["role"]=="Paving"])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT/record["file"]));runtime=castle.meshes()
    measure=common.measurements(runtime);checks.update(castle.geometry(runtime,record,"runtime"))
    runtime_coverage=perimeter(runtime)
    checks.update(five_runtime_batches=len(runtime)==5,source_runtime_coverage=common.close(source,measure),
        revised_island_budget=measure["triangles"]<595000,recorded_triangles=measure["triangles"]==record["runtime_triangles"],
        runtime_perimeter_has_no_unintended_gaps=runtime_coverage["passed"])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/manifest["shared_paving"].removeprefix("res://")))
    shared=common.measurements(castle.meshes());checks["shared_paving_unchanged"]=common.close(paving,shared)
    result={"passed":all(checks.values()),"checks":checks,"runtime":measure,
        "before_perimeter":before_coverage,"source_perimeter":source_coverage,"runtime_perimeter":runtime_coverage,
        "bay_ray_misses":bay_misses,"visible_triangles":measure["triangles"]+shared["triangles"],
        "scope":"Visual barrier coverage, geometry and seating; no new collision/operational-machine simulation."}
    (OUT/"validation_report.json").write_text(json.dumps(result,indent=2)+"\n")
    print("ASTRAL_V15_AUDIT",json.dumps(result),flush=True)
    assert result["passed"],[k for k,v in checks.items() if not v]


if __name__=="__main__":main()
