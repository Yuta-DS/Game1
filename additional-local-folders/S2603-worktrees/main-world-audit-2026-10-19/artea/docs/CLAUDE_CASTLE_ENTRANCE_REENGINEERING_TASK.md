# Claude implementation task: Art Castle entrance reconstruction

## Canonical user request

> CAN YOU FIX THIS AREA TO MAKE IT BETTER LIKE THE STAIR I CAME UP AND THE
> FRONT OF THE CASTLE IS NOT MUCH IT TOGATHER DESIGN AND RE ENGINERRING
> CONTRUC THE ARCHITECTURE FOR ME BETTER AND ALSO THE CASTLE IS LOWER THE
> ENTRANCE GATE CAN YOU FIX IT

Reference screenshots:

- `/Users/davidsovann/Documents/Screenshot 2026-08-10 at 1.55.11 am.png`
- `/Users/davidsovann/Documents/Screenshot 2026-08-10 at 1.55.45 am.png`

## Supervisor diagnosis

This is an architectural circulation and datum problem, not a request for
more decorative props.

1. The imported castle's measured doorway threshold is
   `CASTLE_DOOR.y = 69.33`.
2. `hub_castle_entrance.gd` currently builds the upper court and all doorway
   furniture at `CASTLE_DOOR + UPPER_RISE`, where `UPPER_RISE = 2.2`. The
   platform therefore hides the real doorway and makes it look too low.
3. The spiral crown, launch landing, causeway, arrival terrace, ceremonial
   stair and door court use several ambiguous centre/surface heights. They
   must share explicit finished-floor datums.
4. At the spiral top, the player sees crossing rails/beam-like pieces and a
   narrow handoff instead of a generous landing with an obvious path.
5. The approach uses too many oversized columns and disconnected decorative
   elements. It competes with the imported castle instead of extending its
   massing, roof rhythm, colour, and central doorway axis.

## Design intent

Build one legible procession:

`spiral stair -> crown landing -> straight causeway -> arrival terrace -> ceremonial stair -> castle threshold`

- The real castle threshold is the authoritative upper finished-floor level.
- The arrival terrace and causeway sit below it by one deliberate ceremonial
  rise; the wide stair makes up that rise.
- The causeway must be centred on its destination and enter through genuine
  openings in both guard systems.
- The spiral crown must be a room-sized landing, not a beam crossing.
- The centreline from causeway through stair to castle gate stays clear for a
  player capsule at least 1.2 m wide and 2.2 m high.
- Use the existing slate-blue stone, darker foundations, brass, cyan inlay,
  red roofs and faceted low-poly language. Prefer coherent structural masses
  over many small decorations.
- Scale the added gatehouse down and attach it visually to the existing castle
  facade. The real door and arch must be visible from the terrace at player
  height.
- Keep railings continuous along fall edges but terminate them cleanly before
  circulation openings. No rail, lintel, lamp, planter, fountain or banner may
  cross the walking axis.

## Required implementation

1. Refactor the height constants in `hub_castle_entrance.gd` and
   `hub_castle_stairs.gd` into unambiguous finished-surface datums. The upper
   court surface must align to the measured castle threshold.
2. Rebuild the spiral-top landing and its causeway launch so the last tread
   opens onto a broad, collision-backed landing and then an unobstructed gate.
3. Rebuild the causeway/terrace handoff with deliberate rail openings and no
   overlapping round end-cap or diagonal barrier in the walking route.
4. Rebalance the front architecture: reduce visual clutter and oversized
   columns, strengthen the central gate composition, and visually join the
   new work to the castle.
5. Preserve ordinary walking/jumping traversal and all existing gameplay,
   gallery return, lens, train and world-cutting behavior.
6. Expand focused tests to prove the datums match, required landing pieces
   exist, both ends expose a clear route, and the castle stays stationary.
7. Update the existing castle capture utility only as needed to show the
   player-height gate, spiral handoff, causeway handoff, and a wide architectural
   composition.

## Allowed files

- `scripts/hub_castle_stairs.gd`
- `scripts/hub_castle_entrance.gd`
- `scripts/test_castle_entrance.gd`
- `scripts/test_castle_professional_pass.gd`
- `scripts/capture_castle_universe.gd`
- `docs/CASTLE_ENTRANCE_REENGINEERING.md` (new implementation notes)

Do not edit scenes, imported models, player scripts, project settings, API
configuration, HUD code, journey code, or unrelated dirty files.

## Verification

Use `/Applications/Godot_mono.app/Contents/MacOS/Godot` and a writable
`--log-file` under `.godot/`.

- `res://scripts/test_castle_entrance.gd`
- `res://scripts/test_castle_professional_pass.gd`
- `res://scripts/test_castle_universe.gd`
- `res://scripts/capture_castle_universe.gd` using the normal Metal renderer

Do not accept a test merely because it prints a pass marker after script or
assertion errors. Report every modified file, test result, remaining warning,
and exact capture path.
