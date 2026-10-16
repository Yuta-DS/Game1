# Island One lighting and surroundings — warm_scenery_01

13 September 2026. Implemented locally; production delivery is blocked.

## Scope

- Keep three islands, five quests, all sixteen Island One controls, saved state,
  movement and gate logic unchanged.
- Before static batching, duplicate scenery material overrides only under the
  first two district roots. Shared materials used by later islands are untouched.
  Imported quest instruments and their state-driven material adapters are excluded.
- Brass scenery uses a quieter champagne finish; scenery emission is capped at
  0.24. Large gold architectural parts reflect light instead of emitting it.
- Keep the high arrival, composition and tree lights at their original heights;
  reduce energy to 0.95 / 0.85 / 1.15 and ranges to 82 / 52 / 54.
- Limit instrument purpose titles to 24 units. Actual thought and question panels
  remain intact. This is not a claim that all background labels are cleaned up.
- A camera-local profile warms ambient light and desaturates the procedural sky
  close to the puzzle controls. Influence fades between 30 and 90 local units,
  with a time-smoothed transition. Restore the previous camera environment on
  departure, camera replacement or removal. Do not mutate the global environment.
  Sky resources stop updating once the transition settles.

## Evidence

Native 1280×720 captures, using the containing world environment and directional
lights, are under `artifacts/island_one_warm_surroundings/`:

- `weight_prism.png`
- `echo_question.png`
- `middle_ring.png`

These are player-height instrument viewpoints, not a continuous walking recording.
Earlier comparison captures remain under `artifacts/heavenly_quest_video/`.
The earlier video shows completed states; new captures show dormant states, so
mechanical poses are not a controlled before/after comparison.

Passed in this pass:

- `test_island_one_warm_surroundings.gd -- --capture`: local palette, elevated
  lights, sixteen title ranges, locked beacon, camera profile and restoration.
- `test_heavenly_quest_kit.gd`: proximity inputs, poses, choices, persistence,
  complete Quest 1 and Quest 2, then gate unlock.
- `test_island_one_science_art_harmony_v31.gd`: garden structure and three
  creative puzzle solutions.
- `test_island_one_first_person_puzzle_v22.gd`: proximity quest journey.

## Delivery limitation and remaining art review

The maintained non-Mono export generated 142 pack parts and included the new
lighting-profile script, but the latest export and its retry both reported
`TLS handshake error: -27648` after pack serialization. Exit status was zero;
that does not make the error a clean export. Existing duplicate UID warnings,
music UID path fallback and two leaked ObjectDB instances also remain.

No production deployment was made for this pass; no updated WebGL verification
or production deployment ID is claimed. The existing public release is unchanged.

The native captures show reduced cyan tint and more neutral ivory/brass. Bright
floor highlights, some overlapping background service labels and crowded views
still need further art review. No foliage, collisions or playable paths were
deleted or relocated. Full garden rearrangement and Web performance measurement
are not complete. Original AGENTS.md was not changed. No Git commit or push.
