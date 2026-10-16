# Weight Prism benchmark — implementation record

12 September 2026 · `weight_benchmark_01` · awaiting art-direction review

Follow-on: the user requested this style across the remaining quest objects.
See [heavenly kit audit](MIND_SPARK_HEAVENLY_QUEST_KIT_AUDIT.md) for the subsequent
fifteen replacements. This document remains the original benchmark record.

## Delivered locally

The former Weight Prism badge and procedural pedestal are replaced by a Blender
balance instrument. It has a bevelled plinth, ivory service housing, teal inset,
supported fulcrum, brass beam, two suspended chambers, bearing collars, selector
grip, counterweight, connected return pipes and output lens.

- Source: `assets3D/mind_spark/quest_kit/weight_prism/source/weight_prism.blend`
- Runtime: `assets3D/mind_spark/quest_kit/weight_prism/export/weight_prism.glb`
- Rebuild: `tools/build_weight_prism_benchmark.py` using Blender in a new background process.
- Atlas: 1024 × 1024, shared between four material regions.
- Measured export: 4,260 triangles, seven mesh nodes, four materials.
- Independently editable source components are retained before runtime consolidation.
- Original `AGENTS.md` is unchanged.

Blender MCP was unavailable at localhost:9876. The installed Blender binary was
used for generation, source save, export and studio renders.

## Runtime behaviour

The existing `weight_prism` control ID and saved seed choice remain authoritative.
Three choices map to -0.12, 0 and +0.12 radians of beam tilt. This is visual
composition feedback, not a new physical correctness rule. Chambers counter-rotate
to stay upright; selector and counterweight respond to the same interpolated pose.
New input cancels superseded movement. State restoration applies immediately.

The state lens is reparented into the existing feedback interface; the large
circular badge is no longer built. A simple plinth collider is independent of
the render mesh. The body faces the western approach.

## Verification evidence

- `test_weight_prism_benchmark.gd`: three choices, upright chambers, rapid repeated
  input and restored pose passed.
- `test_island_one_first_person_puzzle_v22.gd`: proximity quest journey passed.
- `test_island_one_quest_object_graphics_v40.gd`: identity and feedback passed.
- `test_island_one_production_asset_integration_v26.gd`: quest-to-gate flow passed.
- Native capture: `assets3D/mind_spark/quest_kit/weight_prism/previews/in_game.png`.
  This is an inspection camera using the actual containing scene's environment,
  sun and fill light. It is not a browser screenshot or a complete player recording.
- Blender studio captures: `previews/front.png`, `three_quarter.png`, `rear.png`.

## Web packaging repair

The following old scene wrappers reference missing model sources and had no
inbound path references in the inspected project. Their referenced models were
also absent from the inspected local Git history and import cache:

- `textures/common_tree_12.tscn`
- `textures/grass_common_short_2.tscn`
- `assets3D/worlds/popthought.tscn`

These exact wrappers are excluded from Web packaging, not deleted. Existing live
scenes and models remain included. Benchmark preview images are excluded too.
The subsequent non-Mono export completed without the missing-resource errors.

## Production delivery

Later release audit found the public alias still pointed at an older deployment.
The earlier browser check below proves the public game started, not that the
Weight Prism build was served. The subsequent heavenly-kit delivery corrects
the alias; see its audit record for the current verified deployment.

- Deployment: `dpl_B6Lidw4BTFrZH5VG2bmrfncNT1gk`, production READY.
- URL: https://artea-web.vercel.app/?build=dpl_B6Lidw4BTFrZH5VG2bmrfncNT1gk
- Browser verification: start screen rendered in colour, Offline Guest entered
  the playable outdoor hub, and the full map opened successfully.
- The changed Weight Prism puzzle was tested natively, not completed through
  the production browser. Browser end-to-end puzzle verification remains open.
- No commit or push was performed.

## Remaining review

This is the first reference object, not completion of the 16-object overhaul.
The environment remains visually busy and the containing scene's light is bright;
both require a separate environment pass before claiming final overall art quality.
Collision was introduced for the plinth; broader walk-route and full-scene frame
time profiling remain to be completed. No final art acceptance is inferred from
passing gameplay tests.
