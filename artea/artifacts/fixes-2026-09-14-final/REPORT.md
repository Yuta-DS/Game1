# Artéa failed-test repair report — 14 September 2026

## Outcome

All 59 automated checks pass, including the 58-test validation matrix and the
new inventory-startup regression. The final non-Mono Godot 4.7.1 Web export
completed successfully and the deployed production build is playable.

Production deployment: `dpl_AQNtFfMHJ68KyQpkk1yUgtTFoEy1`

Public URL: <https://artea-web.vercel.app/>

## Fixed behavior

- Checkpoint saves are recorded after the Observatory task advances, allowing
  the two-root requirement to complete and open the Island Two path.
- The restored third Spark remains placeable before the Logic Gate unlocks.
- Island Two story regression coverage now exercises the current observation,
  memory replay, causal experiment, perspective, and projection controls.
- Seated players no longer run ordinary floor movement against the train.
- The train camera ignores the train's own collision while retaining world-wall
  collision; smoothness now measures cruising separately from docking.
- Deferred spatial-audio setup resolves nodes by instance ID, so scene changes
  cannot pass freed audio nodes to a typed deferred call.
- Milo's map, tablet, and heart hands retain their measured prop endpoints and
  inward grip while his torso animation continues.
- Urgent support messages no longer retain private input for later player echo.
- Hub inventory data binds before the first physics frame, so immediate
  collectible overlap cannot refresh an uninitialized inventory UI.
- All three fused islands receive replacement barriers on exposed edges. Hidden
  legacy rail families no longer affect current layout validation.
- Asset tests now distinguish the measured Milo, prototype Milo, current
  catalog socket model, and intentionally reduced Island 1 overlay.
- Browser smoke verification now focuses the tab, verifies pointer lock, treats
  runtime exceptions as failures, and allows the documented large production
  download to finish.

## Verification

- Automated checks: **59/59 passed**.
- Quest 1 cleanup check: **3 additional consecutive clean passes**.
- Train smoothness: train turn jump **0.323°**, camera turn **0.0001°**, camera
  step variation **0.364 m** against the **0.60 m** limit.
- Web export: **145 pack parts**, standard non-Mono Godot.
- Loader patch tests: **4/4 passed**.
- Local browser: start screen, Offline Guest, hub, pointer lock, and movement;
  **0 runtime exceptions**, **0 fatal resource errors**.
- Production browser: engine started after the uncached 1.16 GB first load,
  Offline Guest entered, hub built, pointer lock acquired, movement rendered;
  **0 runtime exceptions**, **0 fatal resource errors**.

## Evidence

- [Structured results](results.json)
- [Web export log](web-export.log)
- [Deployment log](vercel-deploy.log)
- [Production console](production-browser-retry/console.log)
- [Production hub screenshot](production-browser-retry/04-after-move.png)

The working tree already contained railway and world edits before this repair.
They remain uncommitted together with these fixes; no unrelated file was reset.
