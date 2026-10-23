# Heart Melody arrival and castle stair repairs

Release `675807e09ca32af6`, 20 October 2026.

## Changes

- Added a two-tier musical fountain near the Heart Melody station landing,
  with organ-like pipes, water arcs, 28 animated skyward notes and 24 pink/green
  blossom trees. The promenade remains clear. Notes use a single MultiMesh and
  shader animation, with no downloaded model, texture or particle-system assets.
- Replaced the Heart platform's overlapping paving disks with adjacent annuli
  and a central disk sharing one solid surface at y=0.20. The garden ramp meets
  that height. Heart's access bridge uses one stone-paving family instead of
  alternating metal panels, stone rectangles and a bright conduit strip.
- Added matching box collisions to both continuous lower castle approach walls
  and their entrance posts. The visible walls can no longer be walked through.
  Their colliders stay outside the walking lane.

## Verification

Nine route/gameplay regressions passed: castle ground entry, spiral route,
gallery flow, minimap, embedded galaxy, station jumping, Crown Line railway,
Heart gate round trip and Heart main-world integration. The additional garden
test passed on its focused rerun after correcting a type annotation in the test.
Evidence is in `work/arrival-regressions-run.log` and
`work/heart-arrival-focused.log`.

The stair test sweeps the actual player capsule against both walls, then walks
three lanes and exercises jump recovery. The garden test checks the note batch,
tree count, paving height/material consistency and a real physics ray at the
station-to-garden junction.

Native Compatibility-renderer captures visually confirm the fountain, rising
notes, grove and paving. The capture positions the player with the camera so
distance streaming reveals the inspected region. Captures are under
`artea/artifacts/arrival_repairs/`, excluded from future asset imports.

The maintained complete non-Mono Web export completed, and pack dependency,
duplication and startup-budget checks passed. An editor-only Dialogue Manager
update-check callback logged a missing plugin reference during editor shutdown
after the Hub pack was saved; it did not interrupt the export or occur in the
browser. The optional native stair capture also encounters the existing native
Terrain3D/Compatibility shader limitation; exported Web uses baked terrain.

All 102 packaged files passed local SHA-256 and hosted MIME, compression,
cache and isolation-header verification. The fresh Chrome tour reported
`RESULT: PLAYABLE` and zero fatal script/resource errors, with hub/castle
movement, story, Mind Spark, Heart Melody activity and valley, Creator's Light
and every return. Castle entry measured 28.6 seconds with its assets prefetched;
this is a local headless-browser measurement, not a device/network guarantee.
The browser tour covers gameplay routes; the detailed new garden visuals were
checked using the native Compatibility captures and focused tests.

## Build

Local preview: <http://127.0.0.1:8884/>.

Package: `artea/artifacts/aws/artea-aws-675807e09ca32af6` and adjacent ZIP.
Browser evidence: `work/arrival-browser-run.log` and `work/arrival-browser/`.

Vercel still reports `Logged out`; no production deployment is claimed and the
existing project/alias was not changed. AWS has not been provisioned.
