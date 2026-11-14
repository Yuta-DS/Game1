# Rooftop inner-edge barrier — 28 August 2026

## Result

The curved roof edge above the final stair flight now has a solid blue-grey
masonry barrier with a crisp stone cap and restrained staggered brick faces.
The wall joins the existing end walls while the stair landing stays open.

The surgical-patch approach kept the implementation focused on this edge. Its
previous world-space vertices inherited the castle parent's translation a
second time, moving the guard away from the roof. The wall, coping and brick
faces now share the correct rooftop origin. Closed convex collision cells
protect the edge without making individual brick details snag the player.

## Verification

- `test_castle_inner_roof_guard.gd`: PASS — 50 knee/chest-height edge probes;
  seven sprint/oblique impacts, unchanged standing height, and clean escapes.
  Before the fix, this test failed because the guard was anchored at the wrong
  world position.
- `test_castle_spiral_route.gd`: PASS — all three stair lanes and crown circuit.
- `test_castle_stair_dynamics.gd`: PASS — terrain-to-roof ascent/descent, jump
  landings and supported loose props.
- `test_castle_rooftop_barrier_safety.gd`: PASS — six walkable perimeter sections
  resisted sprint impacts and allowed the player to move away.
- `test_castle_professional_pass.gd`: PASS.
- `test_web_environment_compat.gd`: PASS.
- In-game screenshots reviewed from the roof and stair approach.
- Non-Mono Web export: PASS — 102 pack parts, 853,131,484 bytes.
- `git diff --check`: PASS. No commit or push performed.

Traversal tests follow the open landing beyond the new guard before turning
inward; they no longer request a shortcut directly through the protected edge.
The floor probe also recognizes the existing flush stair-handoff collider.

## Deployment

- Target: existing `artea-web` production project.
- Status: READY.
- Deployment ID: `dpl_69PGnWPQKXqsV34SJuMnrCnXczwn`.
- Deployment URL: https://artea-6fbovmhep-dsovann80-2407s-projects.vercel.app
- Public URL: https://artea-web.vercel.app/?build=dpl_69PGnWPQKXqsV34SJuMnrCnXczwn
- The existing public alias was pointed to this deployment; its pack manifest
  matches the exported build.
- Browser verification: public URL reached the rendered start screen, entered
  Offline Guest, rendered the 3D hub and responded to a movement key. The
  detailed rooftop route was tested natively, not manually traversed in-browser.

## Scope and limitations

This fixes the inner edge highlighted in the supplied screenshot, not every
remaining outer-perimeter design issue. Physics tests are native Godot tests;
they do not establish identical behavior on every browser/OS or prevent a
player deliberately jumping over a wall. Existing native asset-UID fallback,
Firebase configuration and shutdown warnings remain outside this patch. The
browser also reported the pre-existing missing Firebase `.env` configuration
and an `inventory_data is null` inventory initialization error; neither prevented
Offline Guest gameplay, and neither comes from the barrier code. No barrier
script error was observed.
