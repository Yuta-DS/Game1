# Art Castle entrance reconstruction — implementation notes

## Root cause

`hub_castle_entrance.gd` built the upper court and every doorway fixture
(gatehouse, arch, banners, lamps, threshold seal) at `CASTLE_DOOR.y +
UPPER_RISE`, where `UPPER_RISE = 2.2`. That put the finished floor 2.2 m
*above* the real castle threshold (`CASTLE_DOOR.y = 69.33`), so the deck
buried the doorway instead of meeting it — "the castle is lower than the
entrance gate."

Separately, `hub_castle_stairs.gd`'s `TERRACE_DECK_Y` (68.88, a
`CASTLE_DOOR.y - 0.45` offset) assumed only a 0.45 m gap between the terrace
and the door level, while the entrance's actual gap was 2.2 m. The two files
never agreed on one arrival level.

## New datum scheme

Both scripts now share two named constants instead of one ambiguous rise:

- `UPPER_DECK_Y = 69.33` — the entrance court and procedural gate datum.
- `CASTLE_THRESHOLD.y = 72.53` — the raised imported castle doorway.
- `CEREMONIAL_RISE = 1.6` (both files, must match) — how far the arrival
  terrace/causeway sit below the upper court, made up entirely by the
  ceremonial stair.
- `TERRACE_DECK_Y = UPPER_DECK_Y - CEREMONIAL_RISE` — computed the same way
  in both files so they can't drift apart silently. `test_castle_professional_pass.gd`
  cross-checks this at runtime.

`DOOR_LEVEL` in the entrance script is now the zero vector (door fixtures no
longer need an added rise) but is kept as a named constant so future height
tuning has one place to change.

## Straight architectural axis and raised castle

The spiral tower now shares the castle entrance's exact Z coordinate (`27.41`)
instead of sitting 14 m to one side. It was moved farther outward along X to
`(-1.4, 27.41)`, preserving foundation/plaza clearance while producing one
straight procession from crown to doorway.

The imported castle root is 3.2 m higher (`Y 65.49 -> 68.69`). A new central
twelve-tread flight crosses the upper court from the lower entrance datum at
69.33 to the real castle threshold at 72.53. Every tread and stepped cheek wall
has collision, and a threshold pad overlaps the final tread and live gallery
door trigger.

## Spiral crown landing

The old crown used a 4.6 m radius against an 8.4 m outer tread edge, so the
stair projected beyond its destination. The first reconstruction overcorrected
to 9.6 m; the supervisor render showed that this dominated the approach like a
floating plaza. The final `LANDING_RADIUS = 8.4` matches the actual outer tread
edge and is guarded by collision-backed octagonal parapets, with whole sides
omitted at the stair mouth and causeway gate.

The crown slab's finished surface is also flush with the last spiral tread.
The initial rebuild placed it 0.68 m higher—outside the controller's reliable
step-up range—so `CROWN_SURFACE_OFFSET = 0.17` now matches the half-height of
the 0.34 m final tread. The tower shaft stops beneath the slab instead of
projecting through the middle as a raised obstacle.

## Causeway/terrace handoff

Two problems, both in `_build_bridge`:

1. The continuous guard rails ran the *full* span from the tower launch all
   the way to the terrace target, butting straight into the terrace's own
   balustrade with no opening — the "diagonal barrier in the walking route."
   Rails now stop `gate_clearance = 2.4` short of the terrace end.
2. The end-cap (`CastleDoorLanding`) was a full 4 m-radius disc centred on
   the walking axis — a round obstruction sitting squarely in the route.
   It's now a rectangular pad aligned to the direction of travel, sized to
   the bridge width, so it covers the same seam without projecting sideways
   into the gate opening.
3. The causeway originally began at the tower axis, laying its deck and rails
   diagonally across the crown. It now begins at the crown gateway
   (`LANDING_RADIUS - 1.0`) and overlaps only the doorway edge. Its short guard
   span is centred correctly, preserving the full 2.4 m terrace opening.

## Front architecture rebalance

- Gatehouse towers scaled down ~30% (shaft radius 1.45→1.05, height
  7.4→5.4 m) and pulled from `OUT * 1.1` to `OUT * 0.7` from the door, so
  they read as an extension of the castle facade rather than a competing
  structure a few metres out.
- Colonnade reduced from 4 to 3 columns per side — with the gatehouse doing
  more framing close to the door, the fourth pair crowded the 8.4 m upper
  court into a picket fence.

## Tests

- `test_castle_entrance.gd`: asserts the entrance datum is 69.33, the castle
  threshold is at least 3 m higher, all twelve final-ascent treads have
  collision, and `TERRACE_DECK_Y == UPPER_DECK_Y - CEREMONIAL_RISE`.
- `test_castle_professional_pass.gd`: asserts the crown landing exists, has
  collision, stays inside the 8.0–8.8 m architectural envelope, and is flush
  with the final tread; asserts the causeway end-cap is not a `CylinderMesh`
  (i.e. not the old round obstruction); cross-checks `TERRACE_DECK_Y` agrees
  between the entrance and stair root nodes.
  It also asserts the stair tower and entrance share one Z axis and the live
  castle root is elevated.
- `test_approach_continuity.gd`: derives the live terrace datum, checks the
  final-tread/crown join directly, verifies the causeway reaches the terrace,
  and confirms the route carries collision.

## Capture utility

The capture is deterministic and no longer waits for unrelated island-state
tweens. Added angles: player-eye-height view of the gate from the terrace, the
spiral-to-crown handoff, the crown-to-causeway/causeway-to-terrace handoff
wide shot, and a wide shot of the full procession.
