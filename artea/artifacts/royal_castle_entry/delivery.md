# Royal castle staircase, door and frame

Implemented in the local Godot game on 28 August 2026.

## Design and implementation

- One 18-tread masonry flight from the existing lower court (69.18 m) to the
  castle threshold (78.33 m), retaining the established 4.8 m clear width.
- Each visible tread owns its matching solid collision box. The old hidden
  ramp, separate overlay stair and redundant door-frame builders are removed.
- Continuous solid stone parapets, fitted coping, red-capped newels and small
  crown shields match the courtyard. A closed soffit encloses every tread end.
- Pointed, individually cut stone arch with jamb mouldings, capitals, a crown
  keystone, paired red banners and warm lanterns.
- Twelve fitted oak boards form the double door, with forged straps, brass
  rivets and ring knockers. The existing gallery entry destination and automatic
  handoff are preserved; the closed door is solid in explicit-interaction mode.
- Supported side balconies provide room for the commander outside the stair
  lane. Conflicting old banners are removed; decorative leaves intersecting the
  stair clearance are repositioned without removing the tree or its roots.
- Dressed tread tops use material colour, not coplanar overlay meshes. Shared
  coping now joins the wall instead of shimmering over an identical face.

The lean-build skill guided reuse of the courtyard's stone/material helpers and
replacement of duplicate geometry owners instead of adding another overlay.

## Verification

Final focused test passed without script/runtime errors:

- 54 tread-height/collider probes.
- 18 upward-facing underside probes.
- Three player ascent/descent lanes.
- Four sprint wall impacts with escape checks.
- Jump landing and actual automatic entry into the existing gallery scene.

Also passed: castle entrance, castle redesign, full crown/bridge/courtyard/door
player route, royal courtyard, Art Castle gallery flow, world minimap, embedded
gallery world, station jump traversal, Crown Line railway and Web environment
compatibility policy. Scoped `git diff --check` passed.

Native Forward Mobile captures, not generated concept images:

- `01_royal_entrance.png` — complete entrance.
- `02_door_frame.png` — oak door and fitted royal frame.
- `03_stair_detail.png` — treads, side guards and newels.
- `04_stair_underside.png` — continuous enclosed lower surface.

## Web delivery limitation

Not exported/deployed in this delivery cycle. The prior Web export blockers
remain: unused `textures/grass_common_short_2.tscn` and
`textures/common_tree_12.tscn` reference absent `Grass_Common_Short.gltf` and
`CommonTree_1.gltf` models. The earlier request for approval to exclude only
those previews from the Web export has not been answered. No export preset,
gameplay assets or production deployment were changed to bypass that issue.

A separate Mind Spark model was temporarily unavailable during an early test;
it appeared during other workspace activity. The final live-entry test no
longer reports that error. No changes were made here to Mind Spark assets.

Production URL is not claimed to contain these changes. No deployment ID or
production-browser verification exists for this delivery. No commit or push.
