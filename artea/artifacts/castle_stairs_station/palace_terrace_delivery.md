# Palace-garden rooftop and barriers — 28 August 2026

## Implemented locally

- Coordinated palace-style blind arches in blue-grey and cream stone on the
  outer rooftop walls, split arrival wings, outer stair guard, both short
  stairwell returns, and curved inner guard. The arches have solid stone behind
  them, not open gaps. Small muted-gold accents match the royal planters.
- Flower-filled stone urns on the existing rounded corner posts. Each urn and
  bouquet is combined into one mesh; no additional lights were introduced.
- Diagonal limestone paving and a restrained four-petal central mosaic applied
  to the existing roof surfaces. No raised floor, displacement or extra collision
  layer was added. The stair opening and plain underside remain intact.
- Retained the formal flowerbeds, paired topiary, hedge borders, ivy, ballista
  display, bridge and stair access. No player physics or collision shapes changed.

The lean-build skill guided reuse of the existing solid walls, floor, plant
geometry and garden palette. The procedural presentation follows the original
Blender panels' transforms while leaving their authoritative collision intact.

## Verification in this delivery cycle

- Rooftop garden/palace test: PASS. Wall/return alignment, bounded carved details,
  matching curved treatment, batched urns, persistent paving material, central
  court traversal and floor height, planter impacts/corners/landings/exits.
- Inner guard test: PASS. 50 edge probes, seven sprint/oblique impacts and escapes.
- Rooftop barrier test: PASS. Six perimeter impact/escape cases.
- Spiral route: PASS. All three stair lanes and the full crown circuit.
- Castle professional regression: PASS. The initial 216-mesh bridge-volume
  budget failure was corrected by batching the new urns; final count 182 meshes,
  below the existing 190 limit, and two lights.
- Web environment policy: PASS.
- Restricted source whitespace check: PASS.
- Native Compatibility-renderer screenshots 15–19 captured. Overview, arrival
  and garden details were visually inspected, including the final batched urns.
  The paving shader compiled and rendered in the Compatibility renderer.

## Web delivery limitation

Only 170 MiB of disk space remained at final preflight. Two earlier exports had
already failed on this same disk-full condition. No large export was retried,
no unrelated files were deleted, and no new deployment was made in this cycle.
There is therefore no new production deployment ID or browser verification for
this palace-garden update. The existing destination remains
https://artea-web.vercel.app/; it is not claimed to contain these local changes.

Free at least 3 GB to resume the maintained non-Mono export, existing-project
production deployment and real WebGL2 startup/gameplay verification. Review
the legacy missing-source warnings reported in the earlier export as well.
Native checks do not establish behavior on every OS/browser. No commit or push.
