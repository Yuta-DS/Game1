# Art Castle — Magitech Research and Build Brief

## Design conclusion

The Art Castle should become a **High Aether Citadel**: a lifted observatory,
gallery, and civic sanctuary. Its magic is not an unrelated neon layer. The
same elements that make it stand, carry visitors, and measure the sky also
carry its aether energy.

This gives the player one readable sequence:

```text
ground spiral → Lumen Conduit → arrival terrace → civic court
→ grand stair → raised observatory threshold → Art Castle
```

## Research distilled into game rules

1. **Gothic height must have a visible load path.** The V&A explains that rib
   vaults and flying buttresses let Gothic buildings reach upward by moving
   thrust to external supports; pointed arches both signal height and carry
   heavier loads. For Artéa, dark stone buttress fins and brass tension bands
   should visibly connect the elevated castle to its floating foundation.
   Source: https://www.vam.ac.uk/articles/the-gothic-style-an-introduction

2. **Technology should be light, exposed, and integrated.** The Science Museum
   records Victorian engineering becoming lighter and more open rather than
   slab-heavy, with Gothic tracery integrated into machines. The Art Castle
   should therefore use thin brass frames, glazed/rune apertures, calibration
   rings, and readable conduits—not piles of gears or opaque machinery.
   Source: https://blog.sciencemuseum.org.uk/steampunk-in-the-science-museum/

3. **The structural system can be beautiful and lightweight.** The V&A's Elytra
   pavilion describes a strong, light filament structure informed by nature
   and robotic fabrication. For the game, repeat a small number of light
   aether ribs / halo frames to make the castle's hovering mass feel
   deliberately engineered.
   Source: https://www.vam.ac.uk/articles/about-the-elytra-filament-pavilion

4. **Detail should be a total environment, not loose decoration.** The V&A's
   Art Nouveau research describes exposed iron extending the same language from
   framework to stairs, lamps, and tiles. Artéa should repeat one grammar:
   slate stone contains brass; brass contains cyan aether; violet appears only
   at runes, readings, and keystones.
   Source: https://www.vam.ac.uk/articles/the-whiplash/

## Implementation brief

### 1. Raise the citadel

- Raise the imported `building_castle_red2` root from Y 68.69 to Y 71.49.
- Raise the playable castle threshold from Y 72.53 to Y 75.33.
- Preserve the bridge, arrival terrace, and lower civic court at their current
  levels. Increase `CASTLE_RISE` from 3.2 m to 6.0 m across twelve treads
  (0.5 m each, below the 0.65 m reliable player step height).
- The gate must remain a lower, welcoming civic threshold; the castle now
  visibly floats and rises behind it.

### 2. Add a deliberate floating engineering system

- Deepen the visible foundation hierarchy below the higher castle: broad rock
  shelf, tapered keel, then a small number of aether stabiliser anchors.
- Add paired, outboard **aether buttress fins** and a restrained **observatory
  instrument band**. These must never enter the arrival stair, front-door
  capsule, bridge mouth, or player camera corridor.
- Use visual-only runes/conduits for non-walkable ornament. Collision remains
  only on actual floor, stair, and guard architecture.

### 3. Improve the castle's own silhouette and layout

- Treat the entry as an observatory gate: pointed arch, paired buttress
  frames, cyan stained-glass / conduit readings, brass keystones.
- Build a crown observatory vocabulary: four calibrated light fins/rings and a
  single aether beacon, all small enough to complement rather than conceal the
  imported roofline.
- Keep the three-level approach readable: lower arrival terrace, social court
  with fountain, then a narrower final ascent to the much higher castle door.

## Non-negotiable engineering constraints

- Stair rise is at most 0.65 m; `6.0 / 12 = 0.5 m`.
- Castle root, castle threshold, scene transform, entrance constants, capture
  poses, and regression expectations must move as one datum set.
- Do not move the existing crown deck (Y 67.73), bridge, or front-gate court
  (Y 69.33). The previously repaired route must remain continuous.
- No visual object may obstruct the 4.8 m bridge deck, the 3.0 m portal mouths,
  the final stair, or 2.4 m headroom.
- Verify with the entrance, approach, and professional tests plus native
  renderer capture. Review gate-height, procession-wide, and side/foundation
  captures before acceptance.

## Implementation record — 2026-08-10

The build brief above is implemented.

- `scenes/New_Hub_World.tscn` raises `building_castle_red2` to Y 71.49.
- `scripts/hub_castle_entrance.gd` raises the real threshold to Y 75.33 via a
  6.0 m ascent over twelve collision-backed 0.5 m treads.
- `scripts/hub_castle_stairs.gd` carries the same root and threshold datums,
  so its protected-clearance rules do not treat the elevated castle as a
  removable environmental prop.
- `scripts/hub_lumen_citadel.gd` adds the visual-only High Aether Facade:
  paired dark-stone/brass/cyan buttresses, a dual-ring observatory aperture,
  and a six-node calibration band. The floating foundation collision is split
  into rear and side support decks, preserving a 12 m open entry sector for
  the final ascent.
- The final architectural refinement adds `AstralObservatoryCrown`: four tall
  brass-and-cyan telescope yokes physically stitch an orbital halo and enlarged
  Lumen lens to the castle's real roofline. This makes the science layer part
  of the skyline, rather than another detail around the gate.
- `scripts/test_castle_entrance.gd` and
  `scripts/test_castle_professional_pass.gd` now lock the new height datums,
  safe step rise, and required facade system against regressions.

Verified after implementation:

- `CASTLE_ENTRANCE_TEST: PASS` — threshold Y 75.33 and 77 collision bodies.
- `APPROACH_TEST: PASS` — continuous approach and 28 causeway colliders.
- `CASTLE_POLISH_TEST: PASS` — continuous route, elevated citadel, and facade.
- `CASTLE_CAPTURE: PASS` — native Metal render wrote nineteen review views.

Review outputs:

- `artifacts/castle_aether_citadel.png` — high silhouette and foundation.
- `artifacts/castle_aether_facade.png` — observatory gate / science-magic layer.
- `artifacts/castle_observatory_crown.png` — roof-integrated aether telescope.
- `artifacts/castle_gate_player_height.png` — player-facing final ascent.

## Height and two-flight approach addendum — 2026-08-10

The citadel is now deliberately higher than the public front gate without
moving the repaired bridge, lower court, or arrival terrace.

- Imported `building_castle_red2` root: Y 74.49.
- Real castle threshold: Y 78.33; lower civic court remains Y 69.33.
- The final ascent is two nine-tread flights with a 1.6 m-wide,
  collision-backed `AetherAscentLanding` at the midpoint. Each of the eighteen
  treads rises 0.5 m, safely below the player's 0.65 m step limit.
- The landing carries a cyan aether conduit and restrained brass edge rails:
  it reads as an observatory calibration pause, not a generic flat platform.
- All scene datums, stair-clearance protection, regression expectations, and
  native review cameras move with the new height set.

## Aether Lens Bridge design addendum — 2026-08-10

The latest player-eye screenshot shows that the bridge-to-gate sequence is
structurally legible but spatially blunt and visually generic. More
importantly, duplicated gateway piers at Z +/-2.4 are each 1.15 m wide, so
their geometry intrudes into the nominal 4.8 m road and leaves about 3.65 m of
usable width. Solid 6 m lintels occlude the player camera. Center-only route
tests did not detect the intrusion because they ignored full AABB extents.

The approved architectural response is an **Aether Lens Bridge**: an open
processional instrument whose magic is presented as calibrated technology.
Two lens gates establish rhythm without becoming boxes. Four outboard slender
pylons carry split pointed yokes, allowing the eye and player to pass through
the center. Two apex lenses, one internal resonance arch, and three rune seals
create an optical/calibration narrative. Below the deck, one keel, three
tension ribs, and two levitation coils make the floating bridge read as an
engineered system rather than an undecorated slab.

Acceptance criteria:

- preserve a level, collision-backed 4.8 m road between the stair and front
  gate, with no pier, yoke, lens, rune, or coil entering its clearance volume;
- keep all non-walkable ornament visual-only and use collision only for the
  road and authentic outboard guard/support elements;
- replace solid lintels with split pointed yokes and preserve player headroom
  plus a clear forward view in both travel directions;
- test geometry by AABB extents, including child meshes, rather than node
  centers alone;
- require player-eye captures from stair-to-gate and gate-to-stair before the
  composition is accepted.

Implementation and supervisor verification are complete. The accepted build
has two open gates, four pylons, eight split yokes, two apex lenses, one
resonance arch, three rune seals, one keel, three tension ribs, and two
levitation coils. All ceremonial pieces are visual-only; the continuous road
and real guards remain collision-backed.

Evidence:

- `CASTLE_ENTRANCE_TEST: PASS` — threshold Y 78.33.
- `CASTLE_POLISH_TEST: PASS` — exact inventory, extent-based gate clearance,
  no wide lintel, and no ornamental collision.
- `APPROACH_TEST: PASS` — level stair/bridge/terrace connection with 24
  causeway colliders.
- `CASTLE_CAPTURE: PASS` — 23 native Metal views, including both player-eye
  directions and the engineered underside.
- Independent Claude Code review returned `CLAUDE_REVIEW_PASS` with no
  blocking defect.

## Aether Safety Balustrade

The bridge now uses a full-length protective edge system that treats safety as
part of the castle's magical-scientific language. The former approximately
0.92 m edge guard was too low at player scale and ended 2.4 m before the
landings. Its replacement combines transparent force-field planes with
recognizable engineered load and control elements.

Each side has a 1.35 m-high collision-backed cyan Aether field extending to
within 0.65 m of the landing. Dark-stone plinths establish structural weight;
brass cap rails and ten calibrated posts imply a maintained apparatus; cyan
conduits and alternating prism nodes suggest energy distribution and field
tuning. The field opacity is restrained so the coastline, castle, and open
Lens Gate remain readable through it.

The inner face of every guard remains beyond the bridge's 2.4 m half-width,
preserving the full 4.8 m processional road. Only the transparent safety field
has collision; the posts, prisms, rails, and conduits are visual components.
Professional geometry tests now assert height, length, material transparency,
collision presence, component inventory, and the unobstructed road envelope.

Verification: `CASTLE_POLISH_TEST: PASS`, `APPROACH_TEST: PASS` (24 causeway
colliders), and `CASTLE_CAPTURE: PASS` (24 native Metal views). The accepted
side elevation is `artifacts/castle_bridge_safety_balustrade.png`.

## Reference-image Aether Observatory Bridge — final pass (2026-08-10)

Visual reference:
`/var/folders/j8/tctb8gfs2_72jd0t0t7hzq9h0000gn/T/TemporaryItems/NSIRD_screencaptureui_aT4LwH/Screenshot 2026-08-10 at 3.09.07 pm.png`.

The final redesign develops the safe Lens Bridge into an observatory-like
processional instrument. Three tall pointed brass/cyan frames establish the
major rhythm. Six rune-glass bays and twelve tracery chords create a layered
scientific-gothic enclosure without restoring the old solid lintels. Two rune
fascias carry six runes, while two low-poly gears and six underbraces expose
the bridge's mechanical logic. Four astrolabe rings with two luminous cores
make astronomical calibration the focal idea; violet frame tips provide a
controlled magical accent rather than competing with the cyan energy system.

The art pass is deliberately non-invasive. It preserves the full 4.8 m clear
corridor, the 1.35 m collision-backed safety field, and the existing roadbed,
launch, landing, and height datums. All newly added observatory ornament is
visual-only, so the reference-driven silhouette cannot create a new gameplay
obstruction.

Accepted verification:

- `CASTLE_POLISH_TEST: PASS` — 170 meshes, 3 lights, exact component counts,
  and transformed-AABB prism clearance;
- `CASTLE_ENTRANCE_TEST: PASS` — 326 meshes, 96 bodies, threshold Y 78.33,
  terrace Y 67.73;
- `APPROACH_TEST: PASS` — deck Y 67.90 versus terrace Y 67.73 with 24
  causeway colliders;
- `CASTLE_CAPTURE: PASS` — 26 native Metal review angles;
- independent Claude Code review: `CLAUDE_REVIEW_PASS`.

Accepted artifacts are `artifacts/castle_bridge_reference_hero.png`,
`artifacts/castle_bridge_reference_side.png`,
`artifacts/castle_bridge_player_to_gate.png`,
`artifacts/castle_bridge_player_to_stair.png`,
`artifacts/castle_bridge_safety_balustrade.png`, and
`artifacts/castle_bridge_underside.png`.

Remaining limitation: procedural glyph bars provide readable emissive rune
rhythm, but they are less dense than custom-authored glyph textures. A future
texture-only refinement can increase symbolic richness while preserving every
verified structural and gameplay invariant.

## Persistent movement-freeze resolution — 2026-08-10

Latest evidence screenshot (19:59:58):
`/var/folders/j8/tctb8gfs2_72jd0t0t7hzq9h0000gn/T/TemporaryItems/NSIRD_screencaptureui_djR2nR/Screenshot 2026-08-10 at 7.59.58 pm.png`.

A capsule map through the crown mouth found no blocking `StaticBody3D`, so the
accepted bridge architecture was not the cause of the persistent freeze. The
root cause was control state: `player.interacting` could remain true after its
interaction owner became orphaned or dialogue startup failed, and that flag
intentionally suppresses movement.

The production fix spans `scenes/entities/new_player.gd` and
`scripts/GameManager.gd`. The player now recovers an orphaned interaction
lock, while failed dialogue startup releases its lock deterministically.
`scripts/test_player_control_recovery.gd` provides the regression coverage.

Verification:

- `PLAYER_CONTROL_RECOVERY_TEST: PASS — orphan locks release and invalid dialogue cleans up`;
- `CASTLE_POLISH_TEST: PASS — reference bridge 170 meshes/3 lights, clear 4.8 m camera prism, continuous route`;
- `APPROACH_TEST: PASS — deck 67.90 vs terrace 67.73, causeway reaches -17.90 (edge -15.80), rise 2.32, 24 causeway colliders`.

This is a control-recovery change only. The Aether Observatory Bridge's visual
geometry, 4.8 m corridor, safety collision, roadbed, launch, landing, and
elevation datums remain unchanged.

## Crown Landing Floor Continuity Repair

The apparent obstruction beside the observatory rune circle was a missing
floor sector rather than decorative collision. The procedural crown mesh
started its walkable ring at radius 3.6 m, while the tower collision ended at
radius 3.0 m. Because the promised centre-disc faces were never generated, a
0.6 m annular slot remained—wide enough for the 1.0 m-diameter player capsule
to fall partway into and become wedged.

The centre is now closed with a double-sided triangle fan at the crown's
finished surface. This does not cover the designed stairwell opening, which is
outside the centre-disc radius. The professional regression now probes the
former trap ring at 16 evenly spaced angles and requires the CrownDeck body to
be the first supporting collision. Professional construction and complete
approach-continuity tests pass after the repair.

## Inner Stair Service-Slot Repair

The circular entrance apron extended behind the inner spiral guard. Because
the tower uses a deliberately narrow 3.0 m collision cylinder while the inner
guard starts near radius 4.38 m, that hidden side of the apron formed a narrow
service slot. It was not part of the intended route, but the player could jump
the rail, land there, and become wedged between the two collision boundaries.

A continuous collision-backed `InnerSafetyPlinth` now occupies the slot below
the inner brass cap. It follows the stair helix rather than adding scattered
blocks, so the architectural silhouette remains clean and the playable tread
keeps its original width. Regression coverage tests twelve positions with the
real 0.5 m-radius, 2.0 m-high player capsule and rejects any recurrence of an
empty pocket. Professional, approach-continuity, and native visual-capture
checks pass after the change.

## Pre-revision whole-castle Astral Machine draft — 2026-08-11

Reference image:
`/Users/davidsovann/.codex/attachments/d31fb9a2-f647-4333-b8f2-509097521694/image-1.png`.

Claude Code supplied architecture assistance by translating the reference into
one legible castle-scale instrument: a monumental measuring spire, integrated
celestial core, paired articulated skyline arms, floating archive, and a
mechanical script facade. Hermes implemented and iterated that bounded design
in `scripts/hub_lumen_citadel.gd`; supervisor review retained only the version
that passed the gameplay, construction, budget, and visual gates.

Pre-revision inventory was 97 meshes and one
`OmniLight3D`:

- 13 spire meshes: one 28 m `AetherMeasureMonolith`, one layered face, four
  brass rails, three cyan channels, one foot, one crown, and the two-mesh
  `SpireTerminal`;
- five celestial-core meshes: one 6 m sphere, one heart, and three crossed
  instrument rings, plus the machine's single light;
- 26 Lumen-arm meshes: two arms, each with four outer/paired structural beams,
  two cyan/violet conductors, one truss chord, and three two-mesh joint
  terminals;
- seven archive meshes: one `FloatingArchiveCube` body and six luminous inset
  faces;
- 38 script-facade meshes: four panels, four cyan insets, one rune belt, five
  rune marks, and three eight-mesh gears (hub, wheel, and six teeth each);
- eight distributed joint-terminal meshes: four two-mesh crystal terminals.

Locked gameplay and engineering contract:

- real Art Castle threshold Y 78.33; arrival terrace Y 67.73; the established
  bridge/court/stair datums and axis remain unchanged;
- the final door/ascent route retains its full 4.8 m clear prism;
- `ReferenceAstralMachine` is visual-only, contains no `StaticBody3D`, and owns
  no gameplay collision; authored floors, stairs, landing, guards, and
  foundation supports remain the sole collision authorities;
- the castle and machine architecture remain stationary; only the archive cube
  participates in the slow visual rotor system;
- machine budgets are at most 100 meshes and two lights; measured use is 97
  meshes and one light.

Pre-revision supervisor evidence:

- `CASTLE_POLISH_TEST: PASS — reference bridge 170 meshes/3 lights; astral machine 97 meshes/1 lights; clear approach prisms`;
- `CASTLE_ENTRANCE_TEST: PASS` — castle threshold Y 78.33 and terrace Y 67.73;
- `APPROACH_TEST: PASS` — rise 2.32 with 24 causeway colliders;
- `PLAYER_CONTROL_RECOVERY_TEST: PASS — orphan locks release and invalid dialogue cleans up`.

Accepted 1280×720 Metal artifacts:

- `artifacts/castle_reference_hero.png`;
- `artifacts/castle_reference_side.png`;
- `artifacts/castle_reference_silhouette.png`.

Honest remaining fidelity gap: the procedural low-poly primitives do not yet
carry the reference image's dense etched rune and circuit textures, and bright
daylight can wash out some cyan highlights. Future texture/material refinement
must preserve the locked collision policy, route datums, and budgets above.

## Final accepted Astral Machine re-layout — 2026-08-11

Claude-guided review found that the first 97-mesh draft had the right systems
but read as separate props rather than one castle-scale apparatus. Hermes
re-laid out the machine, and an independent Hermes fidelity pass scored the
result 87/100, above the required 85/100 acceptance gate.

The accepted `ReferenceAstralMachine` inventory is 98 meshes and one light:
the preceding 97-mesh inventory plus one brass `CelestialCoreStalk`. The final
breakdown is 13 spire meshes, six celestial-core meshes, 26 Lumen-arm meshes,
seven archive-cube meshes, 38 script-facade meshes, and eight distributed
terminal meshes.

Accepted architectural corrections:

- the spire is now a dimensional blue-grey masonry mass with a 4.6×26×4.2 m
  monolith, broader cyan channels, four horizontal brass measuring bands, and
  a wider foot seated visibly into the castle;
- both articulated arm roots now meet the castle masonry instead of beginning
  as disconnected skyline props;
- the caged celestial core is separated above the crown and connected back to
  the architecture by the new brass stalk;
- the archive cube is 5.4 m across, with larger luminous insets, and is placed
  where its full rotating silhouette remains visible;
- the script facade is pulled toward the castle and rotated flush to its side,
  so panels, rune belt, and gear train read as an integrated machine wall;
- cyan and violet machine materials are stable rather than stage-overwritten,
  while reduced imported-castle emission lowers daylight wash and restores
  dimensional shadow contrast.

All previously locked gameplay datums, the 4.8 m approach prism, visual-only
collision policy, stationary architecture, and 100-mesh/two-light budgets
remain unchanged.

Final verification:

- `CASTLE_POLISH_TEST: PASS — reference bridge 170 meshes/3 lights; astral machine 98 meshes/1 lights; clear approach prisms`;
- `APPROACH_TEST: PASS` — rise 2.32 and 24 causeway colliders;
- `CASTLE_CAPTURE: PASS — wrote twenty-nine visual-check angles` using the
  native Metal renderer;
- independent Hermes fidelity score: 87/100, passing the 85/100 gate.

The final accepted artifacts remain `artifacts/castle_reference_hero.png`,
`artifacts/castle_reference_side.png`, and
`artifacts/castle_reference_silhouette.png`.

Remaining nonblocking gaps: procedural primitives still cannot reproduce the
reference's dense etched rune/circuit texture language or its finest ornamental
truss detail. Strong daylight can still compress subtle emissive gradations,
although the cyan/violet hierarchy and castle shadowing are now stable and
readable. These are texture/material refinements, not layout, collision, or
route blockers.
