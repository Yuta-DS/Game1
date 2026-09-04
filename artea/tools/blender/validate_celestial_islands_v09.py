"""Independent source/BOM/GLB audit for six 3,000-part celestial islands."""
import csv
import hashlib
import json
import math
from collections import Counter
from pathlib import Path

import bpy

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"assets3D/mind_spark/celestial_islands_v09"


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream,"sha256").hexdigest()


def measurements(objects):
    coordinates=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
    area=0
    for obj in objects:
        for polygon in obj.data.polygons:
            vs=[obj.matrix_world@obj.data.vertices[i].co for i in polygon.vertices]
            area+=(vs[1]-vs[0]).cross(vs[2]-vs[0]).length*.5
    return {"triangles":sum(len(o.data.polygons) for o in objects),"area":area,
        "bounds":[[min(v[i] for v in coordinates) for i in range(3)],
                  [max(v[i] for v in coordinates) for i in range(3)]]}


def geometry_checks(objects):
    return {"finite_vertices":all(math.isfinite(c) for o in objects for v in o.data.vertices for c in v.co),
        "triangle_faces":all(len(p.vertices)==3 for o in objects for p in o.data.polygons),
        "positive_face_areas":all(p.area>1e-20 for o in objects for p in o.data.polygons),
        "no_mesh_repairs":not any(o.data.validate() for o in objects),
        "below_walkable_plane":max((o.matrix_world@v.co).z for o in objects for v in o.data.vertices)<.0004}


def close(a,b):
    return a["triangles"]==b["triangles"] and math.isclose(a["area"],b["area"],rel_tol=2e-5) and all(
        abs(x-y)<2e-5 for av,bv in zip(a["bounds"],b["bounds"]) for x,y in zip(av,bv))


def main():
    manifest=json.loads((OUT/"manifest.json").read_text())
    result={"checks":{"preserved_sources":all(sha(ROOT/p)==value for p,value in manifest["source_checksums"].items())},"islands":[]}
    ids=set();total=0
    for item in manifest["variants"]:
        bpy.ops.wm.open_mainfile(filepath=str(OUT/item["source"]))
        objects=[o for o in bpy.context.scene.objects if o.type=="MESH"]
        with (OUT/item["bom"]).open(newline="") as stream:rows=list(csv.DictReader(stream))
        part_ids=[o.get("part_id","") for o in objects]
        checks={"exactly_3000_mesh_objects":len(objects)==3000,
            "unique_named_part_ids":len(set(part_ids))==3000 and all(p.startswith(f"MS09-I{item['id']:02d}-P") for p in part_ids),
            "no_empty_meshes":all(len(o.data.vertices)>=3 and len(o.data.polygons)>0 for o in objects),
            "bom_matches_parts":len(rows)==3000 and {r["part_id"] for r in rows}==set(part_ids),
            "manifest_kind_counts":dict(Counter(o["component_kind"] for o in objects))==item["component_kinds"],
            "substantial_new_engine_components":sum(o["category"]=="04_Engine_Assemblies" for o in objects)>=200}
        checks.update({"source_"+k:v for k,v in geometry_checks(objects).items()})
        for obj in objects:
            assert obj["part_id"] not in ids
            ids.add(obj["part_id"])
        source=measurements([o for o in objects if o["role"]!="Paving"])
        paving=measurements([o for o in objects if o["role"]=="Paving"])
        source_triangles=sum(len(o.data.polygons) for o in objects)
        checks["bom_triangle_counts"]=source_triangles==sum(int(r["triangles"]) for r in rows)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(OUT/item["file"]))
        runtime=[o for o in bpy.context.scene.objects if o.type=="MESH"]
        runtime_measure=measurements(runtime)
        checks.update({"runtime_"+k:v for k,v in geometry_checks(runtime).items()})
        checks["four_batched_architecture_meshes"]=len(runtime)==4
        checks["source_runtime_coverage"]=close(source,runtime_measure)
        checks["manifest_runtime_triangle_count"]=runtime_measure["triangles"]==item["runtime_triangles"]
        checks["per_island_triangle_budget"]=runtime_measure["triangles"]<500000
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(ROOT/manifest["shared_paving"].removeprefix("res://")))
        paving_runtime=measurements([o for o in bpy.context.scene.objects if o.type=="MESH"])
        checks["source_paving_matches_shared_game_asset"]=close(paving,paving_runtime)
        total+=runtime_measure["triangles"]+paving_runtime["triangles"]
        result["islands"].append({"id":item["id"],"name":item["name"],"checks":checks,
            "editable_parts":len(part_ids),"runtime_triangles_including_paving":runtime_measure["triangles"]+paving_runtime["triangles"]})
        print("V09_AUDIT_ISLAND: "+json.dumps(result["islands"][-1]),flush=True)
    result["checks"]["exactly_18000_unique_parts"]=len(ids)==18000
    result["checks"]["whole_family_triangle_budget"]=total<2000000
    result["visible_family_triangles"]=total
    result["passed"]=all(result["checks"].values()) and all(all(i["checks"].values()) for i in result["islands"])
    (OUT/"validation_report.json").write_text(json.dumps(result,indent=2)+"\n")
    print("V09_AUDIT_RESULT: "+json.dumps({k:v for k,v in result.items() if k!="islands"}),flush=True)
    assert result["passed"]


if __name__=="__main__":main()
