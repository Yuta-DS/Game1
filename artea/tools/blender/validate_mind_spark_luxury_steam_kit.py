"""Independently import and validate the Mind Spark luxury steam GLB kit."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
KIT_ROOT = ROOT / "assets3D" / "mind_spark" / "luxury_steam_kit"
MANIFEST_PATH = KIT_ROOT / "component_manifest.json"
REPORT_PATH = KIT_ROOT / "validation_report.json"


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def descendants(root):
    result=[]; stack=list(root.children)
    while stack:
        obj=stack.pop(); result.append(obj); stack.extend(obj.children)
    return result


def main():
    payload=json.loads(MANIFEST_PATH.read_text())
    errors=[]; warnings=[]; results=[]
    if payload.get("component_count") != 36:
        errors.append(f"expected 36 components, found {payload.get('component_count')}")
    ids=set()
    for spec in payload.get("components",[]):
        cid=spec["id"]
        if cid in ids: errors.append(f"duplicate id {cid}")
        ids.add(cid)
        path=ROOT/spec["glb"]
        if not path.exists(): errors.append(f"[{cid}] missing {path}"); continue
        reset_scene(); bpy.ops.import_scene.gltf(filepath=str(path))
        unexpected=[o.name for o in bpy.data.objects if o.type in ('CAMERA','LIGHT')]
        if unexpected: errors.append(f"[{cid}] exported camera/light: {unexpected}")
        roots=[o for o in bpy.data.objects if o.parent is None]
        if len(roots)!=1: errors.append(f"[{cid}] expected 1 root, got {[o.name for o in roots]}"); continue
        root=roots[0]
        if root.name != f"MSLS_{cid}": errors.append(f"[{cid}] wrong root {root.name}")
        children=descendants(root)
        meshes=[o for o in children if o.type=='MESH']
        sockets=[o for o in children if o.type=='EMPTY' and o.name.startswith('SOCKET_')]
        if not meshes: errors.append(f"[{cid}] no meshes")
        if not sockets and spec["category"] in ('mechanical','quest','traversal'):
            warnings.append(f"[{cid}] no sockets")
        material_names={mat.name for o in meshes for mat in o.data.materials if mat}
        bad=[name for name in material_names if not name.startswith('MSLS_')]
        if bad: errors.append(f"[{cid}] non-kit materials {bad}")
        verts=sum(len(o.data.vertices) for o in meshes)
        tris=sum(sum(max(0,len(p.vertices)-2) for p in o.data.polygons) for o in meshes)
        if tris > 60000: errors.append(f"[{cid}] exceeds 60k triangle component ceiling: {tris}")
        if tris < 20: errors.append(f"[{cid}] suspiciously empty: {tris} triangles")
        results.append({"id":cid,"root":root.name,"meshes":len(meshes),"vertices":verts,
                        "triangles":tris,"sockets":sorted(o.name for o in sockets),
                        "materials":sorted(material_names),"bytes":path.stat().st_size})
    total_bytes=sum(r["bytes"] for r in results)
    report={"passed":not errors,"component_count":len(results),"total_bytes":total_bytes,
            "errors":errors,"warnings":warnings,"components":results}
    REPORT_PATH.write_text(json.dumps(report,indent=2))
    for warning in warnings: print("[MSLS][WARN]",warning)
    for error in errors: print("[MSLS][FAIL]",error)
    print(f"[MSLS] validated={len(results)} bytes={total_bytes} passed={not errors}")
    if errors: sys.exit(1)


if __name__ == '__main__':
    main()

