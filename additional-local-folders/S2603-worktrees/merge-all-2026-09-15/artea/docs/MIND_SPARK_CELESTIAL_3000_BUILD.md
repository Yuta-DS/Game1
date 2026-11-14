# MineSpark — Celestial Terrace / 3,000-part revision

This revision develops the approved `mind_spark_terrain_heavenly_v3.png`
reference into a more detailed, editable Blender asset. The original 1,000-part
asset is preserved. No live map, route, quest, branch, commit or deployment is
changed by this work.

## Reference-led changes

- Ivory stone: finer staggered paving courses, small cornice dentils, pier-edge
  relief, carved keystone ornament and individually editable stair treads.
- Heavenly engineering: a second tier of iron arch webs, fine rivets, lantern
  cages, balustrade scrolls, balcony volutes and restrained champagne-gold trim.
- Architecture repair: 80 fitted curved ashlar blocks, 12 intrados liners,
  12 pier-to-core bearing stones, four cornice returns and 12 sparse lower-arch
  anchors replace 120 repetitive rivets. Forty lower arch segments gain depth
  behind their original front plane. See `MIND_SPARK_ARCHITECTURE_AUDIT.md`.
- Steam equipment: flywheel rim fasteners, bearing bolts, fluted cylinder jacket,
  boiler-band rivets, gauge ticks, valve fasteners and service unions.
- Terrain: irregular fracture shelves, longer hanging limestone fins and two
  segmented retaining belts. The upper deck footprint is retained; only the
  underside is elongated to better approach the reference silhouette.
- Gardens and water: smaller blossoms, fine sage sprays and stems, recessed
  planter details, a layered fountain crown, submerged mosaic and static ripples.
- Presentation: a front-left view and a one-large/three-detail board echo the
  reference's composition. All model views are actual Blender renders.

## Exact allocation

| Family | Mesh parts | Scope |
| --- | ---: | --- |
| Rock and anchors | 360 | Core, fractures, hanging fins, belts, mounts, bolts |
| Civic deck | 460 | 420 cut paving stones, medallion, rays, inlays, cornices |
| Civic façade | 470 | Arches, curved ashlar, pier bearings, cornice returns, relief |
| Railings and lamps | 430 | Posts, lantern assemblies, rails, pickets, scrollwork |
| Access | 160 | Stairs, treads, nosings, landings, ramp and newels |
| Steam machinery | 290 | Boiler, piston, flywheel, bearings, fittings, gauges |
| Maintenance balcony | 140 | Slab, grates, paving, brackets, railings and volutes |
| Basin | 140 | Shell, coping, mosaic, fountain, water and plumbing |
| Gardens | 550 | Planters, soil, shrubs, 200 individual flowers, sprays, stems |
| Total | **3,000** | Independent mesh objects and independent mesh datablocks |

The count represents editable construction parts, including repeated details;
it does not mean 3,000 unique product designs. Structural cores and substrates
are legitimate assembly parts, not invisible count-padding objects.

## Editing and reuse

Objects are named `CT3_0001_…` through `CT3_3000_…`, grouped in nine named,
asset-marked collections. Select an object and press **Tab** to edit vertices,
edges and triangular faces. A flower's petals, for example, are smaller closed
mesh islands inside that flower component. Use linked selection in Edit Mode to
select a petal, and Separate Selection if a separate object is needed.

Every object owns its mesh data; changing one part's vertices does not change
another part. Materials are shared deliberately. The manifest and CSV contain
IDs, family, material, dimensions, location, vertex count and triangle count.
The presentation board includes family totals and a searchable inventory.

Triangles alone do not make a smooth object. Curves are sampled, edges are
beveled, and smooth shading is used on manufactured curves. The limestone keeps
intentional fracture planes. All geometry is triangulated for the saved source
and export. UVs are preliminary projections, not a production-packed atlas.

## Files and repeatable build

Output directory: `assets3D/mind_spark/celestial_terrace_3000/`.

- `source/celestial_terrace_3000.blend`: editable source with the reference packed.
- `celestial_terrace_3000.glb`: self-contained static export, 3,000 mesh objects.
- `asset_board.html`: actual renders, file links and searchable component data.
- `previews/00_presentation_board.png`: rendered presentation sheet.
- `previews/01_hero.png` through `05_rear_view.png`: model views.
- `previews/06_pier_support.png` and `07_curved_masonry.png`: repair close-ups.
- `source/before_architecture_audit.blend`: preserved pre-repair 3,000-part source.
- `architecture_audit.json`: component and connection checks, bound to source hash.
- `parts_catalogue.csv` and `parts_manifest.json`: measured component inventory.
- `validation_report.json`: source/export geometry checks and file hashes.
- `board_validation.json`: image loading, inventory interaction and layout checks.
- `anycreature/`: plugin-assisted independent preview and its actual result.

Builder: `tools/blender/build_mind_spark_celestial_3000.py`. It reuses the original
geometry helpers without changing the original builder or outputs. Build with
Blender's `--python-exit-code 1` and `-- --no-render`; use `-- --render-only` for
the full-resolution previews, or add `--quick` for draft renders. Validate with
`tools/blender/validate_mind_spark_celestial_3000.py`.

## Quality boundaries

The current saved revision contains 3,000 mesh objects and 2,237,308 triangles.
Its 32 source/export geometry checks passed. This is a geometry result, not an
image-similarity or gameplay certification.

The validation report, not this document, is the source of truth for pass/fail
and final mesh counts. Checks include triangle-only faces, nonzero areas,
finite vertices, closed mesh topology, positive aggregate volume per part,
independent meshes, materials, UV presence, no external GLB resources, and a
fresh export re-import preserving all part names and triangle counts.

Visual comparison is a manual art review, not a numerical similarity score.
The reference still contains finer painterly wear, denser botanical detail and
subtleties that this procedural 3D interpretation does not reproduce exactly.
No claim of pixel-exact matching or recovered hidden geometry is made.

Blender performs construction through its Python API; no Blender MCP tool is
exposed in this task. The full-detail GLB exceeds anyCreature's 64 MiB input cap.
Its local hero renderer therefore uses a separately labelled, decimated preview
that keeps all 3,000 object names; the master source and GLB remain unchanged.
`anycreature/preview_derivation.json` records its exact counts and hashes, and
`renderer_report.json` records the actual plugin outcome. This does not certify
the full-detail GLB in that renderer. Creature identity, animation and saturation
gates do not apply to this environment and are not claimed. Publishing remains
disabled. The surgical-patch workflow keeps this repair focused on the highlighted
architecture and isolated from gameplay.

This is a high-detail static authoring asset, not an optimized live-game level.
Water and machinery are not animated. Collision, navigation, Web performance
and gameplay integration are not tested. Procedural stone/metal micro-bump is
visible in Blender but is not baked into the GLB; exported material response is
simpler. The output directory is ignored by Godot until deliberate integration.
