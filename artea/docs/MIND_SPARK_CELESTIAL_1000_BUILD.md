# Celestial Terrace — 1,000 editable parts

Production scope: one detailed 3D interpretation of the approved heavenly
concept. This is an isolated Blender asset, not a changed World One map.

## Part allocation, defined before modeling

| Collection | Mesh objects | Construction |
| --- | ---: | --- |
| 01 Rock and anchors | 120 | Stratified masses, core, shards, anchor bands |
| 02 Civic deck | 160 | Stone sectors, radial inlay, rings, layered cornice |
| 03 Civic façade | 220 | Arch blocks, keystones, piers, cornices, ribs, relief, fasteners |
| 04 Railings and lamps | 160 | Posts, plaques, pearl lamps, curved rails, fanwork |
| 05 Access | 70 | Stair cores, treads, nosings, landings, ramp, cheeks and trim |
| 06 Steam machinery | 100 | Cylinder, boiler, flywheel, bearings, rods, pipes, valves, gauges |
| 07 Maintenance balcony | 50 | Deck, grates, brackets, mounts, posts and infill |
| 08 Basin | 40 | Base, liner, water, walls, coping, drain and connections |
| 09 Gardens | 80 | Layered planter shells, soil, foliage and blossom clusters |
| Total | 1,000 | Named visible mesh objects; no count-padding empties |

Repeated construction pieces are individual editable parts, not 1,000 unique
product designs. Each object has its own mesh datablock so vertex changes do not
unexpectedly change another instance. Materials are shared for reuse.

## Editing and surface contract

3D meshes are edited through vertices, edges and faces, not pixels. Every surface
is triangulated. Curved geometry is sampled densely, machined edges are beveled,
and smooth shading preserves intentional sharp architectural joints. Triangle
count alone is not a smoothness guarantee.

Select a CT_ object and press Tab in Blender. Collections organize the nine
families. Some components, such as a grate cassette or flower cluster, contain
smaller mesh islands that can be selected or separated in Edit Mode. UVs are
preliminary projected UVs, not a finished packed texture atlas.

## Tool boundaries

Blender performs modeling, rendering and GLB export. The installed anyCreature
plugin's local renderer assists with a separate GLB preview. Its creature
identity, skinning, attack and saturation gates do not apply to this static
environment and are not reported as passed. Publishing stays disabled.
No callable Blender MCP plugin is exposed in this task; the installed Blender
application is used through its Python API.

The concept image is a visual target, not enough information to recover exact
hidden geometry or dimensions. No pixel-exact reconstruction, in-game performance,
physical accessibility, working steam simulation or Web deployment is implied.

## Deliverables

Inside assets3D/mind_spark/celestial_terrace_1000/:

- source/celestial_terrace_1000.blend — editable source with packed reference.
- celestial_terrace_1000.glb — all 1,000 separated meshes.
- parts_manifest.json — numbered mesh inventory, materials, counts and dimensions.
- parts_catalogue.csv — spreadsheet-readable inventory.
- previews/ — real Blender beauty, detail, rear and exploded renders.
- validation_report.json — actual source/export checks.
- anycreature/ — plugin-assisted independent GLB preview.

Builder: tools/blender/build_mind_spark_celestial_1000.py.
No existing map scene or earlier Blender kit is replaced.

## Verification and current limits

The corrected model passes 32 source/export checks: exactly 1,000 separate mesh
objects, independent mesh datablocks, triangle-only faces, nonzero face area,
closed mesh islands, positive volume, no loose vertices, UV presence, materials,
normals, and preservation through a clean GLB re-import. Total: 945,880 triangles.
Check validation_report.json for the precise scope and file hashes.

anyCreature's installed hero command successfully loaded and rendered the GLB,
reporting an 8.5% framing margin. Its full delivery command initially failed when
the Mac ran out of disk space. The partial zero-byte copy was removed; the lighter
hero command succeeded. The delivered anycreature folder contains real preview
images and renderer_report.json, not a completed offline-viewer package.

The asset directory is ignored by Godot until deliberate integration. This
high-detail authoring version is not optimized or collision-tested for live play.
Small procedural plant clusters are included to establish the heavenly palette;
they are not a complete vegetation system. The water is a static surface and the
engine is a static modeled assembly. The reference image remains the art target;
the result is a 3D interpretation rather than an exact reconstruction.
