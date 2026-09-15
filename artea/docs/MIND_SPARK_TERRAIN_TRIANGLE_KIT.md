# Mind Spark World 1 — triangulated terrain construction kit

## Scope

Eight requested terrain families, broken into **50 reusable parts** and **eight
assembled examples**. Created in Blender, with every face explicitly triangulated
in both the editable source and exported GLBs. This is an isolated asset library,
not a replacement for the existing world or its six-island layout.

The modelling unit is a useful physical part, not one object per triangle. A bolt,
tile, coping segment, soil insert or rock sector can be replaced independently.
Their triangles remain editable inside each mesh. Assembly instances share mesh
data in the master Blender file.

## Files

- Master: `assets3D/mind_spark/terrain_triangle_kit/source/mind_spark_terrain_triangles.blend`
- One GLB per part: `assets3D/mind_spark/terrain_triangle_kit/parts/`
- One GLB per assembly: `assets3D/mind_spark/terrain_triangle_kit/assemblies/`
- Measurements, triangle counts, sockets and exact assembly quantities: `assets3D/mind_spark/terrain_triangle_kit/manifest.json`
- Assembled / exploded renders and topology views: `assets3D/mind_spark/terrain_triangle_kit/previews/`
- Individual part render: `previews/parts/<part_id>.png`
- Blender geometry checks: `validation_report.json`
- Isolated Godot import / surface checks: `godot_validation_report.json`

All paths above are relative to the Godot project, except the report basenames,
which are inside `assets3D/mind_spark/terrain_triangle_kit/`.

## Smallest reusable parts

### 1. P0 Floating-island rock base — 8 parts

1. `rock_cap_sector` — upper 30° sector, pinned boundary vertices, flat top datum.
2. `rock_shoulder_sector` — fractured shoulder slice with local triangular relief.
3. `rock_keel_sector` — five-level tapering underside slice.
4. `rock_fracture_plate` — thin, irregular surface slab for extra cliff relief.
5. `rock_tip_shard` — separate terminal rock mass.
6. `rock_boulder_large` — reusable large edge rock.
7. `rock_boulder_small` — smaller edge / planting rock.
8. `rock_scree_chip` — individual faceted rubble chip.

Reference assembly: twelve 30° sectors at each of the cap, shoulder and keel
levels, plus fracture plates, small surface rocks and a terminal shard. The
reference radius is **8 m**, not a new radius for any existing island. The cap
meets the shoulder at Z = -0.7 m; shoulder meets keel at Z = -3.2 m. Keel reaches
Z = -7 m; the separate tip extends farther down. Four stone tones reveal side
facets; the top stays visually quiet for a future civic deck.

### 2. P0 Ivory civic deck / floor shell — 6 parts

9. `deck_structural_half` — right-triangle substrate, 2 m legs, Z = -0.38 to -0.10 m.
10. `deck_paving_half` — warm ivory finish, top at Z = 0, fine beveled edges.
11. `deck_border_half` — cream alternate of the paving triangle.
12. `deck_edge_fascia` — 2 m replaceable edge face.
13. `deck_inlay_strip` — champagne-brass strip, recessed / flush with the deck.
14. `deck_joint_strip` — independent recessed expansion-joint strip for optional seams.

Reference assembly: **8 × 8 m**, made from sixteen 2 × 2 m cells. Every cell uses
two triangular structural halves and two paving halves. The second half rotates
180° and moves +2 m on X and Y. There is no raised triangular terrain on the
walking surface. Rendered diagonal details are geometry, not a wireframe effect.

### 3. P0 Island rim retaining band — 6 parts

15. `rim_wall_sector` — R8 m, 30° ivory retaining wall.
16. `rim_coping_sector` — separate overhanging coping stone.
17. `rim_brass_sector` — curved external brass belt.
18. `rim_buttress` — triangular support wedge.
19. `rim_drain_spout` — rose-copper scupper body; visual placeholder, not fluid plumbing.
20. `rim_seam_cover` — narrow vertical brass seam trim for optional joints.

Reference assembly: **90° quarter-rim**, using three compatible wall / coping /
belt sectors, support wedges, scupper bodies and individual fasteners. Origins
remain at the island centre so sectors rotate accurately. This is a retaining
edge, not a complete player safety barrier; use the earlier railing kit separately.

### 4. P0 Bridge landing foundation — 5 dedicated parts

21. `landing_footing` — beveled spread footing.
22. `landing_bearing` — dark replaceable bearing pad.
23. `landing_crossbeam` — 4 m support beam.
24. `landing_gusset` — triangular brass bracket plate.
25. `landing_pin_collar` — open-centre connection collar.

Reference assembly: **4 × 4 m**, with four corner footings and bearings,
crossbeams, shared anchor plates / bolts, triangular deck halves, two gussets and
two collars. Bridge and island connection sockets lie on opposite edges. The
bill of materials references existing deck and hardware parts rather than
duplicating those definitions.

### 5. P0 Accessible ramp and stair foundation — 7 parts

26. `access_ramp_wedge` — 2 m clear width, 3.6 m run, 0.3 m rise.
27. `access_slope_curb` — 0.09 m-wide sloping edge curb.
28. `access_landing_slab` — 2 × 1.5 m flat landing slab.
29. `access_step_block` — one 2 m-wide step, 0.30 m tread and 0.15 m rise.
30. `access_nosing` — thin brass tread-edge insert.
31. `access_side_stringer` — triangular foundation for the two-step example.
32. `access_tactile_stud` — independently reusable 3 mm-high brass stud.

Reference assembly: a smooth **1:12 geometric slope** alongside two steps, both
reaching the same +0.3 m shared landing. The outer curb is separate from the ramp.
These are game-design dimensions, not an accessibility certification or a
complete building-code design. Handrails, player movement tuning and full-world
route tests remain part of map integration.

### 6. P1 Cliff ledge and maintenance shelf — 4 parts

33. `ledge_shelf_slab` — 4 × 1.5 m shelf deck, 0.22 m thick.
34. `ledge_diagonal_brace` — shared strut stock, instanced to meet the underside.
35. `ledge_grate_frame` — 1 m replaceable frame member.
36. `ledge_grate_bar` — separate bar stock for a clipped diamond lattice.

Reference assembly: three decorative maintenance grate panels over a solid shelf,
two underside struts, shared anchor plates, washers and bolts. Bars are clipped
to the panel opening and remain linked to one bar mesh. The grate is an overlay,
not an open cut-through floor. No cliff placement or railing is added to the map.

### 7. P1 Planter soil bed — 5 parts

37. `soil_wall` — 2 m terracotta retaining wall.
38. `soil_corner_post` — ivory corner / intermediate joint post.
39. `soil_insert` — 1.78 m square soil cell with a 14 × 14 relief grid and triangular faces.
40. `soil_drainage_insert` — replaceable gravel-support layer.
41. `soil_separator_sheet` — separate thin separator membrane.

Reference assembly: **approximately 4 × 2 m** raised bed (trim extends beyond the
nominal grid), two removable layered soil cells, corner / middle posts and
small rubble pieces. Planting sockets identify the two soil cell centres. No
trees, shrubs or root simulations are added in this terrain-only pass.

### 8. P2 Water basin shell — 6 parts

42. `basin_liner` — 4 × 4 m teal base liner.
43. `basin_wall` — 2 m ivory side-wall module.
44. `basin_corner` — separate corner closure block.
45. `basin_coping` — 1 m cream coping stone.
46. `basin_drain_disc` — annular brass drain bezel.
47. `basin_grille` — individual dark drain bar.

Reference assembly: empty shallow basin with liner, eight wall segments, four
corners, sixteen coping pieces and a drain. The teal interior is solid liner,
not water. A named water-level socket is provided for a later water surface.
Overlapping construction pieces create the shell visually; it is not a
single boolean-unioned simulation vessel or an operating drainage system.

### Shared hardware — 3 parts

48. `hardware_anchor_plate` — 0.3 m square chamfered mounting plate.
49. `hardware_hex_bolt` — six-sided bolt head with real triangulated bevels.
50. `hardware_washer` — annular washer with an actual centre hole.

Use the same hardware meshes across the rim, landing, shelf and planter. These
are visible assembly parts; bolt threads and engineering load calculations are
outside this game-art scope.

## Simple assembly blueprint

```text
FLOATING ISLAND SECTION                    OPTIONAL SURFACE MODULES

  paving triangles + flush brass           raised planter        empty basin
  structural triangle slabs                soil                   coping
  ========================= Z = 0          separator              walls
  cap rock sectors  ← rim / coping         drainage               liner + drain
  shoulder sectors ← braced maintenance shelf
  tapered keel sectors
       terminal shard

LANDING LOAD STACK                         RAMP + STEP PLAN

  paving + flush inlay                     [shared +0.30 m landing]
  triangular structural halves             [ramp exit] [step 2]
  crossbeams + side gussets                 [1:12 ramp] [step 1]
  bearings                                 [low entry] [ground]
  footings / mounting hardware             2 m wide     2 m wide
```

The eight examples are separate review specimens. They demonstrate reusable
construction, not final assembled island extents. Existing island boundaries,
bridge endpoints, spawn anchors, quest IDs and world heights are unchanged.

## Reuse and editing contract

- Blender metres, Z-up; GLB exports Y-up. Root objects are `MST_<id>`.
- Every part and every assembly also has an asset-marked Blender collection.
- Parts are stored near the second showroom row, separate from the eight assemblies.
- Use `PART_<id>` / `ASSEMBLY_<id>` collections for appending complete hierarchies.
- Triangles remain inside a coherent part mesh; no object-per-triangle explosion.
- Most ground-based parts start at Z = 0. Floors use a top-surface datum; rock
  sectors use the deck datum. `manifest.json` records each exception and measured bounds.
- Sector edges are pinned. Rotate 30° around the shared origin to connect them.
- A 2 m deck grid is used where applicable; don't round individual decorative details.
- Changing a linked part mesh changes every instance in the master file. Make a
  single-user mesh copy only for an intentional variant.
- Exports contain shared simple materials; no external textures or shader dependency.
- Collision proxies use `-colonly` names; the isolated Godot importer converts them
  to collision shapes and removes their visible mesh. Deck, landing, access and
  shelf examples have simple proxies. Other families require placement-specific
  collision decisions during integration.
- The original luxury kit is untouched. Palette helpers are reused from its builder.
- Tiny parts remain separate for authoring. Before dense in-game placement, batch
  static pieces / repeated hardware and profile draw calls; low triangle counts
  alone do not prove Web performance.
- Reference R8 m sectors must be regenerated or tiled appropriately for an actual
  world island. Do not scale bolts, curbs and 2 m paving up to hundreds of metres.

## Reproducible build and validation

Run from `artea`:

```sh
rtk /opt/homebrew/bin/blender --background --python-exit-code 1 \
  --python tools/blender/build_mind_spark_terrain_triangles.py

rtk /opt/homebrew/bin/blender --background --python-exit-code 1 \
  --python tools/blender/validate_mind_spark_terrain_triangles.py
```

The Blender validator re-imports all 58 exports into clean scenes and checks
triangle-only geometry, nonzero face area, finite coordinates, positive solid
volume, closed topology after welding GLTF normal seams, materials, sockets,
origins, bounds, GLB hashes and connection seams. It also checks the actual
`.blend` meshes, not just the GLBs. Use `-- --no-render` for a geometry-only build;
the full build recreates presentation views and the arranged master library.

`tools/blender/test_mind_spark_terrain_import.gd` runs in a disposable Godot project
containing copies of `parts`, `assemblies` and `manifest.json`. It checks loaded
visual meshes, materials, collision conversion and 103 physics rays across the
ramp, its landing, the deck, bridge foundation and ledge. This is not a complete
player/controller test or a Web deployment test.

The live game was not integrated or deployed as part of this asset-production pass.
