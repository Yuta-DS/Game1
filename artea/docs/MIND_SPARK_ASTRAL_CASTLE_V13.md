# Astral Observatory — third-island citadel / v13

Only island three changes. Sun Gate remains v11 and Verdant Engine Gardens
remains v12; islands four through six retain v11. No branch, commit or push.

## Architecture

- Two outboard observation turrets: recessed teal drums, ivory pilasters,
  curved window reveals, cornices, pearlescent-blue domes and fine brass seams.
- Four sweeping rectangular ivory ribs meet longitudinal turret-bearing beams
  and the lower crystal collar. Secondary ribs tie into the deck crown.
- A narrow, faceted hanging keel replaces the old single broad cone.
- A suspended three-cylinder power skid adds cooling fins, headers, return
  pipes, mounting straps and a load-bearing sill beneath the reference bays.
- The original ivory arches, flywheel enginehouses, condensers, balustrades,
  lanterns and shared paving remain intact.

These are fictional static steam-magitech structures, not a levitation or
structural-engineering simulation. Smooth curved shading is applied to the
domes and vessels; their exported surfaces are triangulated.

The lean-build skill kept the redesign at the existing foundation loader and
reused the previous geometry kit, part grouping, export and verification tools.
It did not redesign quests or add a second gameplay system.

## Gameplay boundaries

The original zone position, radius, walking disc, collision, quests, gates and
bridge endpoints remain unchanged. Turrets are inaccessible scenery outside
the court. Unlike the older below-deck foundations, they rise above the deck;
every elevated non-railing vertex is therefore explicitly checked to lie
outside radius 1.03, outside the two bridge approach corridors, and below the
0.55 normalized-height ceiling. Existing railing clearance rules remain.

The part count remains exactly 3,000 nonempty editable meshes. Related fittings
are transparently grouped in the inventory, with no filler objects. Runtime
still uses five role batches plus the shared paving; runtime role-node names
remain stable for existing tools.

## Sources and reproduction

- Builder: `tools/blender/build_astral_castle_v13.py` (Blender background).
- Independent audit: `tools/blender/validate_astral_castle_v13.py`.
- Assets, Blender source, inventory, manifest and audit:
  `assets3D/mind_spark/celestial_astral_v13/`.
- Native suite: `tools/blender/verify_celestial_v11_game.mjs` with
  `--out=artifacts/astral_castle_v13/tests`.
- New production-capsule test: `scripts/test_astral_castle_traversal.gd`,
  exercising both bridge approaches to the third court.
- Captures: `scripts/capture_astral_castle_v13.gd`, saved under
  `artifacts/astral_castle_v13/` using neutral review lighting.

## Delivery status

The local source/export geometry audit passes: original architecture and
balustrades retained, shared paving unchanged, 3,000 nonempty inventoried
meshes, positive-area triangles, finite coordinates, matched source/runtime
coverage, two clear outboard turrets, and four rib heads meeting their beams.
The baseline v11 source and the completed Verdant v12 asset match their saved
checksums.

Runtime geometry is 527,430 triangles before shared paving, or 588,094 with
it. The six-island family totals 3,308,682 visible triangles, below the existing
3.5-million ceiling. This does not certify Web performance.

The dedicated Astral traversal test verifies that the existing locked quest
gate still blocks the production capsule, then uses the public gate API to
prepare an open-gate fixture and walks both bridge approaches into the court.
It does not claim to test quest completion; that remains the separate story
test. Native suite evidence is retained in `artifacts/astral_castle_v13/tests`.
The final run passes eleven native checks, including this new traversal test,
the six-island geometry audit, existing route/jump/transit checks, live entry,
minimap, gallery integration, station traversal and Crown railway. Two existing
gameplay checks still fail; the diagnostic baseline probe also completed.

The existing combat freed-core failure and Bio-Data Tree service-component
failure remain release blockers. A legacy/current-land baseline probe
reproduces them independently of this art revision. Existing UID, JSON and
resource-at-exit diagnostics remain in logs; no warning-free claim is made.

No Web export, production deployment, deployment ID or browser verification
was produced in this revision. The public game is unchanged by this task.
