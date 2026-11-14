# Bottom castle staircase audit — 29 August 2026

Inspection only. No product code, scene, collision or material changed. Fresh local-game renders and real-input movement probes were used.

## Confirmed collision bug

Both straight entrance side walls have zero collision shapes. The two ground-entry stone posts and red caps also have zero collision shapes. They differ from the solid piers added farther up the spiral.

Real packed-player input crossed both visible walls from the ramp midpoint without jumping:

- Start: approximately (5.090, 27.178, 24.410).
- Inner wall centre x=3.190; player crossed to (2.632, 26.963, 24.402).
- Outer wall centre x=6.990; player crossed to (7.548, 26.966, 24.403).

Source: `scripts/hub_castle_stairs.gd`, `_build_grounded_castle_entry` and `_build_ground_entry_balustrades`. The walls/posts are constructed as visual objects without `_add_box_body`. The walking slab is solid; this is not evidence that its central floor is missing.

## Unfinished visual design

1. The straight ramp does not meet the low walls: approximately 0.18 m of visible separation on the inner side and 0.47 m on the outer side, derived from the unchanged ramp and wall widths/positions. The curve-specific tread setback has been reused for the straight approach, leaving visible slots.
2. The entrance posts/caps finish about 0.73 m apart in height because each uses its terrain height instead of the shared ramp-edge height. They also retain the earlier slender, uncapped pier treatment rather than the newer heavier stone capitals.
3. The bottom foundation still reads as exposed construction: abrupt wedge-shaped endings, blunt projecting supports and an uneven transition from the first-turn underside to the hillside. The close-up images show this despite the upper stair's improved finish. This is a visual finding, not a claim that the whole foundation lacks collision.

## What passed

- `test_castle_ground_entry_route.gd`: three approach lanes through the first twelve treads passed.
- `test_castle_stair_dynamics.gd`: terrain-to-crown ascent/descent, jump transitions and lower/middle/upper loose-prop support passed.

These route checks do not cover walking sideways through the straight entrance walls. The new audit explicitly reproduced that missing case. No browser/deployment or other-OS conclusion is made from these native checks.

## Evidence

- `01_bottom_entrance.png`: overall ramp/post alignment.
- `02_outer_ground_join.png`: outer wall and foundation detailing.
- `04_first_turn_underside.png`: unfinished wedge/support termination.
- `05_first_flight.png`: first-turn overview.
- `06_walk_through_inner.png` and `06_walk_through_outer.png`: character beyond each non-solid wall.

The temporary inspection script is `/tmp/castle_bottom_audit_20260829.gd`; diagnostic output is `/tmp/castle-bottom-audit.log`. No fixes, commits, pushes or deployments were performed.
