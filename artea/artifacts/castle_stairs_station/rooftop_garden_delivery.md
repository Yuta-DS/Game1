# Rooftop garden and rounded joints — 28 August 2026

## Implemented locally

- Rounded solid stone joints at the curved stair guard ends and outer parapet
  corners, with matching pale coping.
- Corrected the two arrival wings' perpendicular orientation and widened their
  oblique opening to preserve all three walking lanes.
- Four low chamfered stone flowerbeds, using the existing violet, yellow and
  blue wildflowers, with ferns and trailing ivy. Plants have no snagging colliders.
- Raised the outer parapet consistently to 1.60 m; the 0.32 m beds no longer
  create a walkable step sequence over the wall.
- Kept the centre, bridge and stair route clear. Soil and solid planter support
  remain aligned, with a 4 mm visual offset preventing coplanar flicker.

The surgical-patch and lean-build skills kept the work focused on the rooftop
and reused the game's existing flower assets instead of introducing another
asset pack or changing the rest of the world.

## Passed checks

- Rooftop garden: wall alignment, rounded solid joints, planting inventory,
  retained foliage colours, sprint impacts, walking around corners, landing on
  every planter and stepping off without getting stuck.
- Rooftop safety: six perimeter sprint-impact/escape cases.
- Spiral route: all three upper-flight lanes and the crown circuit.
- Inner roof guard: 50 edge probes and seven impact/escape cases.
- Full stair dynamics: terrain-to-crown ascent/descent and jump transitions.
- Castle professional regression and Web environment compatibility checks.
- Whitespace check restricted to modified castle source files.
- Final native screenshots: 15, 16, 17 and 18 in this directory.

## Publication blocked

Both standard non-Mono Web export attempts failed with `ERR_FILE_CANT_WRITE`
on the nearly full disk. No deployment was made and no new production
deployment ID exists for this update. Browser verification of this update
has therefore not been performed.

The export also reports missing `Grass_Common_Short.gltf` and
`CommonTree_1.gltf` source files referenced by two legacy scenes. No references
to those scenes were found in the project's scene/script/resource files; they
are separate from the new garden, which uses existing working wildflowers.

Only this task's incomplete `index.pck` and `index.pck-JooKfh` export files
were removed. They can be regenerated. Source files, user assets and final
screenshots were preserved. No commit or push was performed.

Free at least 3 GB of disk space before resuming export, deployment to the
existing `artea-web` project and public WebGL2/Offline Guest verification.

## Scope

This is a compact rooftop garden, not a replacement of the whole castle.
Native tests do not establish identical behavior on every OS/browser or
prevent deliberate jumping over walls. Existing unrelated Firebase,
inventory-initialization and shutdown warnings remain outside this patch.
