# Island One quest-object style audit and replacement

Revision heavenly_kit_02 · 12 September 2026

## Scope and method

The user requested the new benchmark style across the objects. This pass covers
all sixteen Island One quest instruments: fifteen replacements and the retained
Weight Prism benchmark. Island geometry, the three-island layout, five-quest
progression, characters and gate architecture were not redesigned.

The lean-build skill kept this pass on the existing presentation seam, preserving
saved control IDs and valid solutions rather than adding new puzzle rules.
Blender ran in an isolated background process; no open user scene was overwritten.
Original AGENTS.md is unchanged. No commit or push.

## Audit findings

- Old controls often stacked a common pedestal, oversized circular identity badge
  and another free-standing dial. This obscured the instrument's specific purpose.
- Colour/Rhythm used dense generic gimbals rather than a clear optical/musical form.
- Echo question and beacon overlays duplicated the station body. They are replaced
  by the card desk and cradled crystal, not merely hidden behind new models.
- Classifier titles exposed semantic hints before classification. Titles now use
  neutral echo numbers; all desks expose the same three category choices.
- Original light-route origins referred to retired emitter positions. Routes now
  derive their start from the current instrument's output port.
- The collector's transfer socket occupied the same centre as the instrument.
  It is now adjacent to it, preserving the installed-prism reward display.

## Object review inventory

All rows are **implemented / needs final art review**, not user-accepted final art.
Each has editable Blender source, a GLB, manifest and a native in-world capture.
Triangle counts below describe exported instrument art, not whole-scene geometry
or added runtime labels, ports and collision.

| Control | Rebuilt form and feedback | Triangles | Runtime meshes |
|---|---|---:|---:|
| colour_prism | Three-lens optical instrument; selected seed rotates the lens carrier | 2700 | 3 |
| rhythm_prism | Graduated resonator bars and mallet; selected seed changes the operating pose | 2076 | 3 |
| analysis_console | Evidence desk with three labelled, individually moving specimen cards | 2028 | 5 |
| west_regulator | Intake vessel, sight scale, supported valve spindle and flow arrow | 2584 | 4 |
| east_regulator | Release vessel with opposite flow arrow; level and valve reflect saved pressure | 2584 | 4 |
| outer_ring | Large eight-detent wheel with a moving index | 2792 | 3 |
| middle_ring | Medium wheel with coupled position feedback | 2792 | 3 |
| inner_ring | Compact wheel with coupled position feedback | 2792 | 3 |
| confirm | Guarded send lever and prism cradle | 1296 | 3 |
| echo_collector | Three supported receiving horns and three persistent charge windows | 2404 | 5 |
| echo_signal_1 | Reusable Fact/Possibility/Unsure classifier; selected card projects | 1352 | 6 |
| echo_signal_2 | Same classifier family, independent second echo state | 1352 | 6 |
| echo_signal_3 | Same classifier family, independent third echo state | 1352 | 6 |
| echo_question | Four-card question desk with physical selector and actual question in nearby UI | 1660 | 7 |
| echo_beacon | Cradled wisdom crystal, mast and completion lift | 1456 | 3 |
| weight_prism | Retained balance benchmark with upright suspended chambers | 4260 | 7 |

New exports total 31220 triangles and 64 mesh nodes. They use the benchmark's
1024px ivory/brass/teal/aqua atlas and four material definitions. Imported material
resources are shared across new instances at runtime. Mesh count is not a draw-call
measurement: meshes can contain several material surfaces.

## Runtime and preservation

- Authoritative puzzle state drives wheels, pressure levels, card selection,
  collected charges, lever and crystal lift. No animation awards progress.
- Superseded tweens are cancelled. Non-moving collector updates create no empty tween.
- Cards retain their category labels while moving. Classifiers never encode the
  correct answer in their material or fixed identity.
- Simple plinth colliders are independent of visible geometry.
- Existing player proximity, prompt/status text, alternative compositions,
  revision attempts, rewards and gate dependencies remain in place.
- The musical object currently presents a seed-selected mallet pose; it does not
  introduce timed tapping or a new rhythm rule.

## Verification

Passed native checks during this pass:

- Heavenly kit: real proximity inputs, all fifteen adapters, coupled wheel poses,
  selected cards, collected charges, restoration and quest-to-gate completion.
- Quest-object graphics v40 and textured asset integration v41.
- First-person proximity journey v22 and production-to-gate regression v26.
- Quest 1 and Quest 2 completion/persistence, including revision of an incorrect interpretation.
- Science/art harmony v31: all three creative compositions and replay.

New model source: assets3D/mind_spark/quest_kit/<id>/source/<id>.blend
Runtime export: assets3D/mind_spark/quest_kit/<id>/export/<id>.glb
Capture: assets3D/mind_spark/quest_kit/<id>/previews/in_game_kit.png
Contact sheet: assets3D/mind_spark/quest_kit/heavenly_kit_contact_sheet.png
Build: tools/build_heavenly_quest_kit.py

## Visual review and remaining boundaries

All sixteen native inspection views were reviewed. The major mechanisms are visible;
new forms are much quieter than the previous badge stacks. Existing background
foliage, decorative rings, floating labels and the very bright cyan-tinted lighting
still compete with the new kit. This pass does not claim final environment grading,
full walk-route clearance, GPU profiling or complete moving-mesh collision analysis.
The contact sheet is a Blender studio render. Native captures use the actual
containing scene's environment, sun and fill, from an inspection camera; they are
not a production-browser player recording. Art approval remains with the user.

## Delivery

Non-Mono Web export completed (142 pack parts); all new runtime models and the
visual adapter were confirmed in the packing log. An editor TLS handshake error
was logged after pack serialization. No missing-resource or script-parse errors
were found; the TLS message is not being presented as a clean export log.

Deployment `dpl_J8ecLrmF1gqwVAKS8XzYjaEYqrYm` reached production READY at
https://artea-peqy2jc6c-dsovann80-2407s-projects.vercel.app.
Public browser verification completed for start screen and Offline Guest hub
entry in the corrected deployment. The canvas renders in colour and the game
enters its playable hub. Browser console reports the missing Firebase
`res://addons/godot-firebase/.env` configuration; no credentials were added or
published to work around it. Authentication was not tested. Full Island One
puzzle completion remains native-verified, not production-browser-verified.

Release audit found the public alias still serving deployment
`dpl_BhwKZBCjLPz1ns3R7K9f3NkMpga2` (10 September), despite successful production
uploads. The existing `artea-web.vercel.app` alias was explicitly reassigned to
`dpl_J8ecLrmF1gqwVAKS8XzYjaEYqrYm`. Browser reload then showed the new 1137 MB
pack rather than the old 1120 MB pack. No domain was renamed or new project created.
