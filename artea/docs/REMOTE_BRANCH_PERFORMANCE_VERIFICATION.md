# Remote-branch and rendering verification — 14 September 2026

Follow-up: the current game's minimap bottleneck has since been fixed and
measured at roughly 48% lower native frame time. See
`MINIMAP_RENDER_PERFORMANCE_FIX.md`. The historical branch results below are
unchanged; they do not certify the newer working-tree changes.

## Release decision: NOT READY FOR COMMIT / PUSH

No branches were merged, committed, pushed, or deployed during these checks.
The user's working branch remains `testing-fix-overall-system`; existing game
edits and AGENT/AGENTS files were preserved. Remote references were fetched and
pinned in `artifacts/branch_compatibility/remote-matrix.json`.

This is a partial verification report, not a completed all-branch integration
or smooth-Web-gameplay certification.

## Coverage

- [x] Inventory all 53 remote branch heads and available Godot tests.
- [x] Compare upstream path changes against local feature history and dirty files.
- [x] Dry-run the tracked uncommitted Artea patch against all 53 remote trees,
  using an isolated temporary Git index, without applying it to any branch.
- [x] Run focused native baselines on the eight priority branches below.
- [x] Run an exploratory native Compatibility-renderer culling comparison.
- [x] Reproduce a streaming rebuild defect and verify an isolated candidate fix.
- [ ] Reconcile complete current feature history plus untracked assets with remote changes.
- [ ] Runtime baselines for the remaining 45 branches.
- [ ] Test integrated three-island/five-quest progression, saves and player collisions.
- [ ] Verify phone/iPad controls, resize, landscape/portrait and UI safe areas.
- [ ] Export and exercise the integrated build in a real WebGL2 browser.
- [ ] Measure repeated player-input-driven frame times before/after optimization.
- [ ] Review results with the user before any commit or push.

## Native baseline results

Godot 4.7.1 standard executable, isolated detached checkout at
`/private/tmp/mindspark-branch-check.fpIrPm`. Godot generated import metadata
there; no gameplay source changes were made for the baseline runs. Imported
resources/cache were reused between the close branch snapshots. These are not
cold-cache export tests or full scene playthroughs.

| Branch | Pinned SHA | Focused baseline |
|---|---|---|
| main | d5154fb27e | 7 pass; 2 error-bearing runs; 1 unavailable |
| performance-tweak | c1565c9211 | 6 pass |
| Javid-fix-ipad-phone-scale | dd63991144 | 6 pass |
| splash-screen | cd664543e2 | 6 pass |
| stutter-fix | e601c7aa7f | 6 pass |
| spawn-cleanup-and-performance-optimisation | 6fff0f19c0 | 6 pass |
| spawn-and-train-cleanup-with-performance-optimisation | a74d935467 | 6 pass |
| general_optimisation | 034f9469b3 | 6 pass |

The common six checks cover Web environment *policy* (mocks/source assertions),
castle entrance, visible player-ground alignment, gallery flow, minimap and
Crown Line railway. A policy test is not an actual Web browser test. Tests vary
between source assertions and scene checks; none of these six certifies phone
input or the latest uncommitted island quests.

On main, `test_castle_ground_entry_route.gd` also passed.
`test_gallery_embedded_floating_world.gd` and
`test_train_station_jump_traversal.gd` printed their gameplay PASS markers but
reported `1 resources still in use at exit`. They are retained as error-bearing
runs rather than silently passed on exit code zero.
`test_story_crown_railway_web_performance.gd` does not exist on this main snapshot.

First import reported missing FBX texture references and transient pre-import
resource-loading errors. Later focused tests loaded successfully, but the import
was not certified clean. UID fallback and ObjectDB cleanup warnings remain.
Per-test commands/results/logs are recorded under
`artifacts/branch_compatibility/<branch>-<sha>/`.

## Integration finding

The tracked uncommitted patch did not apply directly to any of the 53 remote
snapshots. This does **not** mean all 53 branches are defective. The patch depends
on committed local feature history missing from several target branches, while
shared files such as the world builder, quest-object base, Milo animations and
Web export configuration have diverged.

`tracked-patch-check.json` contains exact Git diagnostics and a patch fingerprint.
The check deliberately excludes untracked assets and does not resolve or test
the complete integration. Copying a handful of scripts over remote branches
would not establish compatibility.

## Native render comparison

Snapshot: `performance-tweak` before the candidate fix. Apple M2 Pro;
Compatibility/OpenGL renderer; requested 1280×720 window. Shader warmup enabled
in both runs; existing caches retained. Runs performed sequentially without the
other Godot test batch running. The earlier concurrent diagnostic run is excluded.

| Culling | Idle mean / p95 | Traversal sample mean / p95 | Visible instances at end |
|---|---|---|---:|
| On | 36.94 / 41.33 ms | 38.30 / 41.12 ms | 529 |
| Off | 37.45 / 41.80 ms | 38.42 / 40.42 ms | 29,273 |

This short comparison shows substantially fewer visible-in-tree instances, but
no convincing frame-time improvement. End-of-route draw calls were similar
(268 versus 267), so visible-node count must not be presented as equivalent to
draw-call savings. Neither run establishes a smoothness target.

The branch's `bench_castle_cold.gd` teleports the player through 60 samples; it
does not walk using actual inputs or validate collision traversal. Its frame
sampling awaits both process and post-draw signals. These timings should not be
relabelled as browser FPS, GPU-only time, or cold-start measurements.
Full logs: `performance-tweak-render-on-isolated.log` and
`performance-tweak-render-off-isolated.log` in the artifact directory.

## Reproduced streaming defect and candidate fix

Calling `WorldStreamingDirector.rebuild()` after a distant cell was culled
discarded its tracking entry. The next scan skipped the hidden root as though
it were intentionally hidden by the author. Moving the player back to the cell
did not restore it: `restored_on_approach=false cells=0`.

A small candidate patch restores roots previously culled by the director before
rebuilding its list. The focused regression now passes, including preservation
of an authored-hidden mesh and collision configuration. Gallery-flow, minimap
and railway regressions also passed after the patch: four checks total.

The fix exists **only in the detached test checkout**, not in the user's game
or any remote branch. Reusable patch and test are saved under
`tools/branch_checks/`. It still needs integration tests for late-built islands
and gameplay-driven visibility changes; shared ownership of a root's visibility
cannot be inferred from a boolean alone.

## Safe next optimization order

1. Assemble a reviewable complete feature snapshot, preserving the user's
   uncommitted work, then reconcile upstream changes in the overlapping files.
2. Validate streaming registration after deferred island creation, returning
   to previously culled areas, and quest-controlled visibility. Keep physics and
   save/quest processing independent of decorative rendering.
3. Profile the actual player route in Web. Separate script, physics, draw-call,
   shader-compilation and download costs before changing art quality.
4. Prefer cached minimap data, batched static decorations and distant detail LOD.
   Preserve nearby silhouettes, legible puzzle indicators and all collision.
5. Compare fixed-resolution repeated runs and actual mobile layouts. Do not
   remove quest objects or arbitrarily lower all graphics to achieve a metric.

No production graphics reduction or Web smoothness improvement is claimed yet.
