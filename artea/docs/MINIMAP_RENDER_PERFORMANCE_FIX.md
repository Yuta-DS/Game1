# Rendering performance fix — 14 September 2026

## Implemented in the current game

`scripts/art_castle_minimap.gd` now caches world transforms, island coordinates,
kingdom coordinates and constant palettes per redraw instead of reconstructing
them for roughly 530 tiles every frame. Idle redraws use a bounded cadence;
significant movement and turning request an immediate refresh. Existing camera
heading, map projection, UI styling and quest logic are preserved.

The implementation adapts the reviewed minimap optimization from the pinned
`performance-tweak` source, without merging branches. No meshes, textures,
lighting, collision shapes or puzzle objects were removed or downgraded.

Web movement testing additionally exposed repeated missing `Cane_Walk` lookups.
The skin alias installer now reaches its existing donor fallback when the
authored `Milo_Walking` clip is absent. The controller checks availability before
seeking a clip, avoiding repeated errors during incomplete animation setup.

## Measured results

Actual current gallery scene, Apple M2 Pro, Godot 4.7.1 native Compatibility,
1280×720, uncapped/VSync disabled, fixed camera, 180 warmup frames plus 30 settle
frames, then 600 consecutive rendered-frame intervals per run. Runs were
sequential, without parallel Godot tests or exports. Warm resource/shader caches
were retained. This measures steady-state native rendering, not cold load time,
browser/mobile FPS, or a full player traversal.

| Run | Mean ms | Median ms | p95 ms | p99 ms | Draw calls |
|---|---:|---:|---:|---:|---:|
| Original map updates | 23.508 | 23.908 | 25.969 | 26.831 | 279 |
| Diagnostic: map updates paused | 11.965 | 11.686 | 14.467 | 15.510 | 279 |
| Optimized, run 1 | 12.390 | 11.917 | 15.740 | 17.185 | 279 |
| Optimized, run 2 | 12.289 | 11.814 | 15.675 | 16.872 | 279 |

Mean frame time improved about 48%. Both optimized runs met a p95 ≤16.7 ms
target for this scene. Occasional frames exceeded 16.7 ms, so this is not a
guarantee of locked 60 FPS everywhere. The map remained enabled in both optimized
runs. The paused-map ablation is diagnostic only, not a shipped change.

The new benchmark timestamps consecutive `frame_post_draw` events. It does not
reuse the earlier remote benchmark's process-plus-post-draw sampling or its
teleport sequence; those older timings must not be directly compared with this
table.

Evidence is in `artifacts/branch_compatibility/current-render-*.log`.
Benchmark: `scripts/benchmark_render_pacing.gd`.

## Verification

- PASS: new minimap render-budget regression (1,000 tile samples reuse one
  world snapshot; transforms refresh; idle cadence stays bounded; movement and
  turning bypass the cadence limit).
- PASS: existing full-map toggle, player tracking, projection and camera-heading checks.
- PASS: gallery flow, train station/jump traversal, Crown Line railway and
  unfinished-light puzzle/story checks.
- The headless embedded-gallery test printed its gameplay PASS but reported a
  DummyShader cleanup leak. Repeating it with the actual Compatibility renderer
  passed without that error; an ObjectDB cleanup warning remained.
- PASS: missing-walk regression verifies a real donor fallback and 120 safe
  playback updates without a clip, preserving unrelated playback speed.
- Two broader Milo suites still fail. Both were rerun with these two animation
  edits removed and reproduced the same failures: GREETING versus expected idle,
  cane-arm smoothness, legacy prototype facial nodes and finger curls. These
  pre-existing failures remain unresolved; no assertions were relaxed.
- Initial optimized Web export completed and the browser reached the colored
  start screen, Offline Guest hub, full atlas, closed atlas and player movement.
  That check exposed the missing-walk issue addressed above.
- Final Web export including the animation fix completed successfully (145 PCK
  parts); its retained log contains no `SCRIPT ERROR` or `ERROR:` lines. UID
  fallback/duplicate and ObjectDB warnings remain. The fresh final browser load
  reached the colored start screen and Offline Guest hub; 35 walking inputs
  changed the player position and minimap. No new console errors were recorded
  during that final test interval. This is a smoke test, not Web FPS certification.

Final export log: `artifacts/branch_compatibility/minimap-final-web-export.log`.
Local verification URL: `http://127.0.0.1:18080/?build=minimap-render-optimization-final`.

No commit, push, merge or production deployment has been performed. This is not
an all-remote-branch compatibility certification. Mobile frame-time measurements
and a complete three-island Web quest playthrough remain outstanding.

## Reproduce

```sh
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --path artea --rendering-method gl_compatibility --resolution 1280x720 --windowed --script res://scripts/benchmark_render_pacing.gd
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --path artea --script res://scripts/test_minimap_render_budget.gd
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --path artea --script res://scripts/test_milo_missing_walk_fallback.gd
```
