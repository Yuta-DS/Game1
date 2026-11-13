# Sea, gallery piano and garden controls — 22 October 2026

- Extended the sea to 8192m across, beyond the 4096m terrain shelf, removing
  the exposed noisy offshore strip. Retained animated water on both renderers.
- Gallery piano now uses the existing real bench and seated fox pose. Q starts
  in the close keyboard camera; Tab still offers a seat view. Esc visibly
  steps the player down over 0.35 seconds before restoring movement/physics.
- Maze fountain gain increased from -12 to -4 dB, with a -2 dB nearby cap,
  24m unit distance and 110m maximum distance. It fades on retreat. The smaller
  meadow fountain retains its previous quiet settings; no garden score added.
- Enter now activates the focused instrument button rather than submitting the
  composition globally. Added an always-visible Exit menu button below the
  scrolling content, centered fitted cards and flexible tuning rows.
- Moved the Warning Bell gate from x=278 to x=294, beyond all three chimes at
  x=262, 274 and 286. Completion requirements and saved progress are unchanged.

## Verification

14 distinct native checks passed: hub sea/sky, Web environment compatibility,
gallery piano, new gallery piano bench, maze, journey presentation, complete
chapter, gallery flow, minimap, embedded floating world, station traversal,
story railway, Melody gate round trip and music circle. Tests exercise real
key activation, mouse note picking, seat/dismount state, movement restoration,
walking to every chime while the gate is locked, and full chapter completion.

Maintained non-Mono Web export completed. An editor-only Dialogue Manager
update-check callback reported missing metadata during shutdown, and an updater
TLS request failed; these did not fail export or appear as game runtime errors.

Release `e1440af1cfbb773b`: all 94 packaged and hosted files passed hash,
MIME and isolation-header checks. Chrome WebGL2 returned `RESULT: PLAYABLE`
after startup, movement, other worlds and Hub returns, all six instruments
(including the gallery piano), keyboard/mouse notes, seating and exit, maze
collision/escape, fountain playback, narration, Enter on Tighten, visible menu
exits and physical access to chime 3 before its gate opens.

Visually inspected browser screenshots of both offshore directions, the close
gallery keyboard, the centered Waterfall Organ card and the locked chime gate.
Local evidence: `work/sea-piano-browser/`, `work/sea-piano-browser-run.log`,
`work/sea-piano-final-tests.log` and `work/sea-piano-baseline-tests.log`.

Local full game: http://127.0.0.1:8911/ — open the root address to load this release.
No push, PR update, AWS deployment or Vercel deployment was performed.

Audio playback/gain/attenuation were checked automatically, not by ear.
Existing frame-rate limits remain: this run measured about 39–42 ms/frame in
the valley and 67 ms/frame in the Hub. Journey saves remain browser-local.
