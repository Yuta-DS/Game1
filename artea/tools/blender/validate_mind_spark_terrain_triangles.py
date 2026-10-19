"""Round-trip every terrain GLB; check geometry, metadata, bounds and source topology."""
import contextlib
import hashlib
import io
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets3D/mind_spark/terrain_triangle_kit'


def main():
    manifest=json.loads((OUT/'manifest.json').read_text())
    failures=[]; checked=[]
    def check(condition,message):
        if not condition: failures.append(message)
    check(manifest['part_count']==50,'Expected exactly 50 reusable parts')
    check(manifest['assembly_count']==8,'Expected exactly 8 assemblies')
    check(len({r['id'] for r in manifest['assets']})==58,'Asset IDs must be unique')
    check(all(t['passed'] for t in manifest['seam_tests']),'Sector connection seam failure')
    for record in manifest['assets']:
        cid=record['id']; path=OUT/record['glb']
        check(path.is_file(),f'{cid}: missing GLB')
        if not path.is_file(): continue
        check(hashlib.sha256(path.read_bytes()).hexdigest()==record['sha256'],f'{cid}: digest mismatch')
        bpy.ops.wm.read_factory_settings(use_empty=True)
        with contextlib.redirect_stdout(io.StringIO()): bpy.ops.import_scene.gltf(filepath=str(path))
        roots=[o for o in bpy.data.objects if o.parent is None]
        check(len(roots)==1,f'{cid}: root count {len(roots)}')
        if len(roots)!=1: continue
        root=roots[0]
        check(root.name=='MST_'+cid,f'{cid}: unexpected root {root.name}')
        check(root.location.length<1e-6,f'{cid}: misplaced export origin')
        check(all(abs(s-1)<1e-6 for s in root.scale),f'{cid}: scaled export root')
        objects=list(root.children_recursive)
        check(not any(o.type in ('CAMERA','LIGHT') for o in objects),f'{cid}: exported studio')
        meshes=[o for o in objects if o.type=='MESH']
        visuals=[o for o in meshes if not o.get('collision_proxy')]
        check(bool(visuals),f'{cid}: no visual mesh')
        check(sum(len(o.data.polygons) for o in visuals)==record['triangles'],f'{cid}: triangle count changed on round-trip')
        checked_meshes=set(); triangle_count=0
        for obj in meshes:
            data=obj.data
            check(all(math.isfinite(x) for row in obj.matrix_world for x in row),f'{cid}: invalid transform')
            check(all(s>0 for s in obj.scale),f'{cid}: negative scale')
            check(all(len(face.vertices)==3 for face in data.polygons),f'{cid}/{obj.name}: non-triangle face')
            check(all(face.area>1e-10 for face in data.polygons),f'{cid}/{obj.name}: zero-area triangle')
            check(all(math.isfinite(c) for v in data.vertices for c in v.co),f'{cid}: non-finite vertex')
            check(all(m is not None and m.name.startswith(('MSLS_','MST_')) for m in data.materials),f'{cid}: unexpected material')
            if data.name not in checked_meshes:
                # GLTF duplicates vertices at normal/material seams. Weld only a
                # temporary BMesh, never the user's authored source or export.
                bm=bmesh.new(); bm.from_mesh(data)
                bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
                check(all(edge.is_manifold for edge in bm.edges),f'{cid}/{obj.name}: non-manifold solid after seam weld')
                check(bm.calc_volume(signed=True)>0,f'{cid}/{obj.name}: non-positive solid volume')
                bm.free(); checked_meshes.add(data.name)
            triangle_count+=len(data.polygons)
        bpy.context.view_layer.update()
        points=[o.matrix_world@Vector(v) for o in visuals for v in o.bound_box]
        low=[min(p[i] for p in points) for i in range(3)]
        high=[max(p[i] for p in points) for i in range(3)]
        for i in range(3):
            check(abs(low[i]-record['bounds_min_m'][i])<.002,f'{cid}: minimum bound changed on axis {i}')
            check(abs(high[i]-record['bounds_max_m'][i])<.002,f'{cid}: maximum bound changed on axis {i}')
        sockets=[o for o in objects if o.type=='EMPTY' and o.name.startswith('SOCKET_')]
        check(len(sockets)==len(record['sockets']),f'{cid}: socket count changed')
        for expected in record['sockets']:
            obj=next((o for o in sockets if o.name==expected['name']),None)
            check(obj is not None,f'{cid}: missing socket {expected["name"]}')
            if obj:
                check((obj.location-Vector(expected['position_m'])).length<.001,f'{cid}: socket transform changed')
        check(sum(bool(o.get('collision_proxy')) for o in objects)==record['collisions'],f'{cid}: lost collision proxy')
        checked.append({'id':cid,'meshes':len(meshes),'visual_triangles':record['triangles'],'all_triangles':triangle_count,'closed_solids':True})
        print('[MST check]',cid,flush=True)
    # Blender source must also be triangles, not merely an implicit exporter conversion.
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'source/mind_spark_terrain_triangles.blend'))
    source_meshes=[o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith(('VIS_','COL_'))]
    check(all(len(f.vertices)==3 for o in source_meshes for f in o.data.polygons),'Source .blend contains non-triangle faces')
    check(all(len(o.modifiers)==0 for o in source_meshes),'Source has unapplied geometry modifiers')
    check(all(record['triangles']<25000 for record in manifest['assets']),'Per-asset review ceiling exceeded')
    report={'passed':not failures,'exported_assets_checked':len(checked),'source_mesh_objects_checked':len(source_meshes),
            'checks':['triangle-only source and GLBs','no degenerate faces','finite coordinates','positive volume',
                      'closed manifold geometry after GLTF seam weld','round-trip bounds and sockets',
                      'unique IDs and GLB digests','4 exact sector seam tests','per-asset <25000 triangles'],
            'errors':failures,'assets':checked}
    (OUT/'validation_report.json').write_text(json.dumps(report,indent=2))
    for failure in failures: print('[MST FAIL]',failure)
    print('[MST VALIDATION]',len(checked),'assets; passed=',not failures)
    if failures: raise RuntimeError(f'{len(failures)} terrain validation checks failed')


if __name__=='__main__': main()
