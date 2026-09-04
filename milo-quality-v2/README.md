# Milo — fuller-cheek quality rebuild

Local review asset, not a production replacement. No commit, push, upload, deployment, or live-game asset replacement was performed. Existing unrelated work was preserved.

## Open first

- `face_closeup.png`: the slightly chubbier cheeks, rounded muzzle and recessed eyes.
- `hero.png`, `front.png`: native Blender studio renders.
- `milo_quality_v2.blend`: editable sculpt, materials, rig and actions.
- `milo_quality_v2.glb`: simplified, material-grouped, skinned export with six clips and facial morph animation.
- `runtime_roundtrip.png`: actual re-imported GLB render, not the richer native material setup.
- `walk.mp4`, `welcome.mp4`, `speak.mp4`, `listen.mp4`, `idle.mp4`: consecutive 30 fps animation previews, no audio.

The native Blender material setup has procedural micro-bump and subsurface shading. The GLB carries geometry, vertex color and PBR factors; it does not reproduce all procedural material nodes. See `runtime_optimization.json` for measured mesh/triangle counts.

## Design and tools

AnyCreature supplied the authored body/sleeve/trouser geometry from `body_spec.json`. Blender 5.2 LTS was used for the fused face sculpt, eye sockets, dimensional moustache, rounded paws and shoes, fitted clothing layers, new rig, animation, export and rendering. No connected Blender MCP/plugin tool was available, so the installed Blender application was driven through its Python interface.

The design keeps Milo as a warm elder cat: softly fuller cheeks, ivory moustache, gold spectacles, lavender eyes, navy coat, plum waistcoat, and wooden cane. The face is modeled geometry, not a painted replacement image.

## Rig and movement

31 deform bones plus 8 optional Blender IK controls. The six baked actions are authoritative for export. `IK_preview = 0` plays those actions; `IK_preview = 1` enables the optional posing controls. These manual IK controls are not exported and have not received a complete animator workflow test.

| Clip | Duration | Movement |
| --- | ---: | --- |
| Idle | 4.0 s | Gentle breathing/sway, eye contact, ear reaction and two blinks; closed loop. |
| Walk_InPlace | 1.6 s | Short cane-assisted steps, alternating feet, restrained upper-body motion; closed loop. |
| Walk_Forward | 4.8 s | Three walking cycles with actual root travel and planted world-space foot/cane targets. |
| Welcome | 3.2 s | Free-hand greeting, small head acknowledgement and brow response. |
| Listen | 4.0 s | Head tilt, nod and small ear response. |
| Speak | 4.0 s | Jaw/moustache motion, eye blinks and a restrained free-hand gesture; not phoneme-based lip sync. |

Walking uses a 0.42 m cycle stride over 1.6 seconds (0.2625 m/s in model space). Each foot spends 62% of its cycle in stance; the other foot is offset by half a cycle. Foot recovery lift peaks near 7.8 cm and cane recovery near 3.6 cm. Two-bone solving keeps feet on their targets and the left hand on the independent cane grip. Do not combine the forward-root clip with an additional character translation without extracting or compensating for root motion.

Face controls: `UpperLid.l/r` have `Blink`; `Paw.l/r` have `FingerCurl`. Head, eyes, ears, brows, jaw, moustache and coat tails have individual deform bones. Matching rig and shape-key NLA tracks merge into the same six exported glTF clips.

## Live code trace and integration boundary

The current live route is:

`artea/project.godot` autoload `MiloCompanionManager` → `scripts/MiloCompanionManager.gd` → `scenes/milo_animations.tscn` → `scenes/characters/milo_scholar.tscn` → `scenes/characters/milo_villager_skin.tscn` → `assets3D/characters/milo_exact_target_parts.glb`.

`scripts/milo_animations.gd` supplies the companion behavior, following, cane-chain handling, terrain reactions, speech and procedural animation. `scripts/milo_villager_skin.gd` supplies visual setup. The separate `scripts/npc/milo_guide.gd` is not the companion scene entry point.

This rebuild is **not a drop-in replacement for that live setup**: its rest pose, mesh grouping, independent cane and action names differ. Integration still requires mapping the new clips and reviewing the old procedural bone/material overrides. No production-game render, terrain-following test, performance benchmark or exhaustive collision QA is claimed for v2.

## Evidence, not certification

- `blender_validation.json`: normalized weights; sampled finite deformation/stretch; sole clearance; cane grip; target reachability; loop closure; full-frame planted-contact path checks.
- `glb_validation.json`: self-contained GLB, finite geometry, indices and normalized weights, bone count, six clip durations, morph channels and loop endpoint checks.
- `visual_review.json`: independent image-only findings, including problems and remaining limitations.
- `gate.json`: only actual checks, with incomplete/full-toolkit certification explicitly distinguished.

AnyCreature's combat-oriented full style/attack/triangle gate was not certified. Milo is a non-combat companion, and no attack was added just to satisfy that fixture. The offline HTML/browser viewer was not re-verified after the app blocked that local-file route; no workaround browser or server was used.

The final independent reader judged the fuller face recognizable and the neck/chest repairs visibly improved, but **did not pass high-polish presentation**. Remaining issues are eye integration, lumpy shoulder/elbow transitions and a runtime shading difference from the native hero render. These are preserved in `visual_review.json`; a green mechanical test result does not override them.

## Rebuild locally

Run from any directory using absolute paths:

```sh
rtk proxy python3 /Users/davidsovann/.codex/plugins/cache/personal/anycreature/1.2.0+codex.local.20260828/scripts/anycreature.py compile /Users/davidsovann/S2603/milo-quality-v2/body_spec.json /Users/davidsovann/S2603/milo-quality-v2/body_seed.glb
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python /Users/davidsovann/S2603/milo-quality-v2/build_model.py --python /Users/davidsovann/S2603/milo-quality-v2/studio.py --python /Users/davidsovann/S2603/milo-quality-v2/animate.py
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python /Users/davidsovann/S2603/milo-quality-v2/review.py -- export
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python /Users/davidsovann/S2603/milo-quality-v2/validate_blender.py
rtk proxy python3 /Users/davidsovann/S2603/milo-quality-v2/validate_glb.py
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python /Users/davidsovann/S2603/milo-quality-v2/review.py -- final
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python /Users/davidsovann/S2603/milo-quality-v2/render_roundtrip.py
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python /Users/davidsovann/S2603/milo-quality-v2/render_motion.py
```

The disk approached capacity during rendering. Only newly generated intermediate frame PNGs were removed (55 MB, reproducible). Video export now streams through one small temporary image and keeps compact MP4 files.
