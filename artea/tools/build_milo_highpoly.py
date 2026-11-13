"""Build the high-detail, editable Mayor Milo for rendering and art work.

This is deliberately NOT the shipping game asset.  ``build_milo_villager_mesh``
produces the ~38k mesh Godot loads; this script reuses that same build, then
subdivides every component to reach roughly 100k editable polygons and saves the
result as a .blend whose parts stay separate, plus a GLB for external renderers.

Two properties matter and pull against each other:

* **Editable components.** The shipping asset joins everything into one mesh,
  which makes selecting "the collar" or "the left ear" a manual face-picking
  chore.  Here each primitive stays its own named object, so a part can be
  selected, moved or resculpted directly.
* **The approved faceted look.** The concept sheet's style comes from large flat
  planes.  Naive subdivision shrinks those planes into invisible slivers and the
  character silently turns into a smooth blob.  Subdivision here is therefore
  ``SIMPLE`` rather than ``CATMULL_CLARK``: it adds editable topology *within*
  each existing plane without rounding the silhouette, and the flat-shading
  applied to fur is re-asserted afterwards so the facets still read.

Run:
    blender --background --python artea/tools/build_milo_highpoly.py
"""

import runpy
import shutil
import tempfile
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
BUILD_SCRIPT = Path(__file__).resolve().parent / "build_milo_villager_mesh.py"
OUT_BLEND = ROOT / "assets3D/characters/milo_villager_highpoly.blend"
OUT_GLB = ROOT / "assets3D/characters/milo_villager_highpoly.glb"

TARGET_FACES = 100_000

# Fur keeps its flat shading; these are the materials treated as fur.
FUR_MATERIALS = {"Milo Tabby Fur", "Milo Cream Fur", "Milo White Fur"}


def build_source_parts():
    """Run the production build and recover its component list pre-join.

    The build script joins its ``parts`` into one mesh at the end.  Executing it
    through ``runpy`` gives access to that module namespace, but the join has
    already happened by then, so the objects are re-read from the scene instead:
    the joined mesh is discarded and the build re-run with the join disabled.
    """
    namespace = runpy.run_path(str(BUILD_SCRIPT), run_name="__milo_build__")
    return namespace


def main():
    # The production script exports the shipping GLB as a side effect of running.
    # Snapshot it first and restore it at the end, so producing this render-only
    # asset can never silently modify what the game loads.
    shipping = ROOT / "assets3D/characters/milo_villager_lowpoly.glb"
    backup = None
    if shipping.exists():
        backup = Path(tempfile.gettempdir()) / "milo_shipping_snapshot.glb"
        shutil.copy2(shipping, backup)

    # The production script is written as a top-level program, so running it
    # rebuilds the whole character in this Blender session.
    namespace = build_source_parts()

    armature = namespace["armature"]
    milo = namespace["milo"]

    faces_before = len(milo.data.polygons)

    # Split the joined mesh back into its authored components.  Every primitive
    # was built as a separate island, so separating by loose parts recovers them
    # as individually selectable objects for editing.
    bpy.ops.object.select_all(action="DESELECT")
    milo.select_set(True)
    bpy.context.view_layer.objects.active = milo
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")

    components = [o for o in bpy.context.scene.objects
                  if o.type == "MESH" and o.name.startswith("MayorMilo")]
    print("HIGHPOLY components=%d faces_before=%d" % (len(components), faces_before))

    # Work out how many simple-subdivision levels reach the target.  Each level
    # multiplies face count by four, so this is a log4 problem; the level is
    # capped so a runaway target cannot explode memory.
    # Pick the level landing NEAREST the target rather than the last one that
    # stays under it.  Requiring a full 4x step to fit beneath 100k would leave
    # 38,983 faces unsubdivided, since 38,983*4 overshoots - so the mesh would
    # silently come back unchanged.
    level, projected = 0, faces_before
    while level < 3:
        nxt = projected * 4
        if abs(nxt - TARGET_FACES) >= abs(projected - TARGET_FACES):
            break
        projected, level = nxt, level + 1
    print("HIGHPOLY subdivision level=%d projected=%d" % (level, projected))

    if level:
        for obj in components:
            bpy.context.view_layer.objects.active = obj
            mod = obj.modifiers.new("EditableDensity", "SUBSURF")
            # SIMPLE preserves the faceted silhouette; CATMULL_CLARK would round
            # it off and destroy the approved low-poly look.
            mod.subdivision_type = "SIMPLE"
            mod.levels = level
            mod.render_levels = level
            bpy.ops.object.modifier_apply(modifier=mod.name)

    # Subdivision multiplies faces by 4 per level, so it overshoots the target
    # (39k -> 156k).  A planar-preserving decimate brings the total back to the
    # requested budget without collapsing the flat planes the style depends on.
    subdivided = sum(len(o.data.polygons) for o in components)
    if subdivided > TARGET_FACES:
        ratio = TARGET_FACES / subdivided
        for obj in components:
            if len(obj.data.polygons) < 24:
                # Tiny parts (buttons, pins, whisker tubes) are already minimal;
                # decimating them further destroys their shape for no real gain.
                continue
            bpy.context.view_layer.objects.active = obj
            mod = obj.modifiers.new("BudgetTrim", "DECIMATE")
            mod.decimate_type = "COLLAPSE"
            mod.ratio = ratio
            bpy.ops.object.modifier_apply(modifier=mod.name)
        print("HIGHPOLY decimate ratio=%.3f from=%d" % (ratio, subdivided))

    # Re-assert flat shading on fur after subdivision so the large planes of the
    # concept sheet still read instead of averaging into a smooth surface.
    for obj in components:
        fur_slots = {i for i, m in enumerate(obj.data.materials)
                     if m and m.name in FUR_MATERIALS}
        for polygon in obj.data.polygons:
            if polygon.material_index in fur_slots:
                polygon.use_smooth = False

    # Give the components readable names.  Loose-part separation numbers them
    # arbitrarily, so they are labelled by height and size to make the outliner
    # navigable rather than a wall of "MayorMilo.183".
    for index, obj in enumerate(sorted(components,
                                       key=lambda o: -o.matrix_world.translation.z)):
        obj.name = "MiloPart_%03d" % index

    total_faces = sum(len(o.data.polygons) for o in components)
    total_verts = sum(len(o.data.vertices) for o in components)

    # Keep every component bound to the rig so the high-detail version can still
    # be posed and animation-checked, not just rendered in rest pose.
    for obj in components:
        if not any(m.type == "ARMATURE" for m in obj.modifiers):
            mod = obj.modifiers.new("VillagerRig", "ARMATURE")
            mod.object = armature
        obj.parent = armature

    bpy.ops.wm.save_as_mainfile(filepath=str(OUT_BLEND))

    bpy.ops.object.select_all(action="DESELECT")
    for obj in components:
        obj.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=str(OUT_GLB),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_nla_strips=True,
        export_materials="EXPORT",
    )

    print("MILO_HIGHPOLY_BUILD: %d components, %d vertices, %d faces"
          % (len(components), total_verts, total_faces))
    print("MILO_HIGHPOLY_BLEND: %s" % OUT_BLEND)
    if backup is not None:
        shutil.copy2(backup, shipping)
        print("MILO_SHIPPING_RESTORED: %s" % shipping)

    print("MILO_HIGHPOLY_GLB: %s" % OUT_GLB)


main()
