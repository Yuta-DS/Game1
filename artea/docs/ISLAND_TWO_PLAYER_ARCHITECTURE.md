# Island Two — player architecture and production checklist

## Perimeter junction correction

The full two-lobe post audit found six close pairs among 44 posts, including a
three-post junction with only 3.75 units between two centers. Endpoint identity
alone did not account for physical footprints. Spatially connected clusters now
share one centered pier. Five redundant instances are hidden non-destructively;
39 posts remain, with zero pairs closer than 14 units. Rail panels and collision
coverage are preserved. `test_island_two_lantern_spacing.gd`, architecture
coverage/player-capsule checks and the Unfinished Light story test pass locally.
Native detail: `artifacts/island_two_overview/shared_lantern_pier.png`.
Web release remains blocked by approximately 466 MiB available storage.

Date: 2026-09-14. Extends ISLAND_TWO_UNFINISHED_LIGHT_PLAN.md; does not
replace the three-island map or five-quest save contract.

## Comparison with Island One

| Element | Island One reference | Island Two action/status |
|---|---|---|
| Exposed island edge | Ivory lantern piers and curved brass scrollwork | Reused the same GLB bay/post kit on both lobes; suppressed old rail meshes instead of stacking |
| Fused interior | Continuous promenade, no redundant sky bridge | Kept the internal Memory Promenade; no barrier across the overlap |
| Inter-island bridge | Existing solid deck and landing geometry | Retained the two external links and slopes; ivory finish, teal solid infill, brass cap, regular pier/lantern fittings; removed cyan seam visuals |
| Departure control | Physical hinged gate linked to quest progress | Moved QuestGate_3 from mid-span onto Island Two, 22 units inside the rim; reused collision-aware two-leaf gate |
| Arrival | Landmark identifying the route | Existing aligned arrival portico stays open; no new puzzle lock after Island One completion |
| Player feedback | Instruments change when solved | Investigation and optical controls retain saved feedback; no duplicate stations added |
| Planting | Green foliage, grouped pockets | Green palette retained; further canopy/foreground clearance and richer grouped planting still needed |
| Landmark quality | Strong central tree and authored gateway | Conservatory and living projector remain less developed; need visual refinement, not extra unrelated machines |

## Route and threshold ownership

Island One completion opens the existing first external connection. The player
crosses the incoming bridge and enters Island Two through its arrival portico.

Echo Seed receiver → evidence scanner → mechanical recorder → causal model →
internal archive gate → perspective workshop → living projector → Ari reflection
→ departure gate on Island Two → bridge to Island Three.

There are two different Island Two gates: the archive gate separates quest
chapters on the fused island; the departure gate controls the external bridge.
Never relocate the archive gate onto the external bridge or put an Island Two
quest instrument beyond the departure lock. Both keep existing save IDs.

## Geometry contract

- Existing floor centers/radii are authoritative; do not replace the foundations.
- Outer rail bays follow radius × 0.985. Omit arcs inside the paired lobe and
  reserve a 36-unit-wide opening around the actual external bridge bearing.
- Preserve the original 28-unit bridge decks and floor-height transitions.
  Side infill is placed at ±13.3 units from the centerline.
- Departure gate center is 100 units from Hope district center, on the bearing
  toward the Storm district. Its parent is stationary; only leaves animate.
- Gate side walls span to the island edge. Leaves remain solid while open and
  sweep-test before each motion increment. Decor must stay outside the sweep.
- Reuse Island One barrier meshes rather than generating thousands of ornamental
  nodes. Short arc bays use the existing curvature-remapping function.
- These are current game-world units, not a claimed real-world accessibility
  certification. The base player capsule is approximately 2 units tall and its
  default speed is 10 units/second; final scale must be assessed from that view.

## Production quality sequence

1. **Safe circulation:** continuous floor, rails, correct bridge-side threshold,
   no locked objective beyond its gate. Implemented locally; focused tests added.
2. **Player readability:** test every approach with real camera/controls, reduce
   oversized framing, keep instrument fronts visible, add concise directional
   signs before decision points. Full traversal still required.
3. **Environmental composition:** group planting around benches and instruments;
   keep central route open; develop conservatory glazing and projector mechanical
   detail; remove competing old visual markers after checking gameplay ownership.
4. **Story staging:** finish Ari's representation, refine reflection scene and
   audio feedback; make restoration understandable without relying on text alone.
5. **Performance and release:** profile draw calls/frame pacing on Web, reconcile
   old puzzle tests, full non-Mono export, production deployment, browser playthrough.

## Verification record

- [x] Imported-foundation gate and station tests pass.
- [x] Departure placement persists across physics ticks; open/close succeeds.
- [x] 217 exposed perimeter ray samples hit protection.
- [x] Four external bridge halves have collidable side infill.
- [x] Real player capsule collides with both bridge sides and clears the tested
  centerline sections after unlocking the preceding gate.
- [x] Story regression: three solutions, partial reload, migration and reflection.
- [x] Native overview and departure captures inspected.
- [ ] Full input-driven walk/jump/camera test through every station and seam.
- [ ] Final environment art, character and material/lighting review.
- [ ] Web performance and production browser verification.

Disk remains approximately 467 MiB free. The full export requires imports and
packaging of a multi-gigabyte asset set. No safe writable alternate volume has
been established. Do not remove user data or strip gameplay to force a release.
Production is blocked until sufficient build storage is available; no production
deployment or deployment ID is claimed for this change.

The broader Island One safety regression was also attempted. It fails at the
west-regulator approach because `Landing/CampusSolidCabinet` blocks the test
route. That area was not modified in this pass; its baseline cause still needs
investigation. Do not report the overall suite as passing. The focused test
project also reports an unresolved player script UID and successfully falls back
to its text resource path; full-project import validation remains required.
