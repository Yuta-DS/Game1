# Island One: both-part quality audit

13 September 2026. Original audit followed by an implementation and verification pass.
The findings below preserve the original audit; implementation status follows here.

## Implemented locally after the audit

- Corrected a newly reproduced grounding defect: 16 instrument bases floated above
  the physical deck. Grounded them and four helper stations, plus fixtures and signs.
  Four helpers previously exposed interaction Areas without cabinet collision;
  they now have static plinth/cabinet bodies. Added specimen and sign silhouette bodies.
- Added physics-tick paired gate motion with sampled collision queries. Both leaves
  pause when obstructed and resume when clear. A real player capsule blocked a
  future point in the left leaf's arc during opening and closing in the regression.
- Added a garden six-channel receiving manifold, anchored station service ports,
  solid short service drops and intentionally non-solid floor light traces.
  Grounded guidance markers; retained the existing pulse/state connections.
- Included campus furniture in the shared finish pass. Preserved functional state
  colours rather than globally recolouring every emissive component.
- Replaced the large modal layout with a scrolling side panel and lighter shade;
  added readable station names, contextual actions, MSDF text and focus preservation.
  Verified a 480×640 panel visually and by bounds/focus assertions.
- Corrected Echo completion guidance to checkpoint/relay progression. Added optional
  predicted-notch feedback through the real panel controls; it is not a new reward
  requirement and does not prevent repeated-turn trial and error.

Fresh passing tests: quality safety (16 instruments + 4 helper approaches and occupied
gate opening/closing), research-campus layout/quest progression and optional prediction,
warm surroundings, Q2 interactions, Island Two shared-panel regression, world-one story
and internal gate route clearance. Current rendered screenshots are in the campus review.
Existing ObjectDB shutdown warnings remain.

Remaining work: all-sided/jumping/continuous-route collision coverage; right-leaf-specific
obstruction and save-restoration occupancy tests; remaining bright legacy markers and
label overlap; department-specific exhibit silhouettes; public WebGL2 validation.
This is not a certificate that every mesh in the world is non-interpenetrating.
Stationary props have collision, not artificial rigid-body mass.

Delivery blocker: approximately 704 MiB free at final preflight, below the space needed
by the previously failed export. No new web export/deployment is claimed. The existing
54.83-second video predates these fixes; it is not evidence of the current revision.

## Verdict

The two-part story works and the visual direction is recognizable. It is not yet
ready to call a physically verified, final-quality environment. Clear operating
positions are not proof of complete walkability, solid props or safe gate motion.

## Findings and priorities

| Priority | Finding | Required improvement / acceptance |
|---|---|---|
| P1 | Solid-looking Echo conduits are mesh-only cylinders. Some appear as brass pipes across the working area, yet `_add_cable_between` creates no physics body. | Route solid services under the floor, along protected edges or on supported overhead racks. Add simple collision only where reachable. If they are light beams, make that visually unmistakable and non-solid intentionally. |
| P1 | Gate leaves have real hinge pivots and box collision, but the opening/closing tween has no explicit obstruction sweep or occupancy check. Existing tests inspect final pose, not an actor in the swept space. | Physics-tick motion, swept-volume checks and stop/reverse or defer motion when occupied. Test both leaves, opening and closing, including replay, a standing player and jumping player. Never teleport a player through a closed leaf. |
| P1 | Collision coverage is incomplete as a certification: the layout test checks one standing capsule and a floor ray per station. It does not move the real player along all routes or around every side of every object. Sign boards/supports and specimen frames are visual-only outside their limited base/post colliders. | Classify every reachable prop as solid, walkable, movable or intentionally intangible. Match simplified colliders to the useful silhouette; verify all-sided approach, corners, jumping and continuous routes using the actual player collider. Do not add collision to every screw or leaf. |
| P1 | Echo service endpoints remain hard-coded while stations are rotated. The Echo support assembly moves, but the original shared root-light well is in the unmoved Part 1 atelier. There is no new receiving well created at the relocated conduit centre. | Build a visible garden receiving manifold, give stations explicit service-port anchors, and derive all conduit endpoints from those anchors. Inspect attachments and crossings, not only bounding boxes. |
| P1 | Some quest messages no longer match the new gate sequence: Echo completion still says the heavenly gate is awakening after Quest 1 has already opened it. The common close button says “Return to the garden” even in the Signal Laboratory. | Use area-aware language and distinct names for the internal garden entrance and external Island Two exit. On Echo completion, explain the remaining checkpoint/relay explicitly. Preserve the thoughts/hope story foundation. |
| P2 | UI colours match broadly, but the panel hides most of the instrument behind a 78%-opaque shade. “Operate instrument”, generated control-ID titles and “Phase Mismatch” are generic, rather than contextual instructions. | Keep the machine visible beside a compact panel, use explicit action names, clear current/target state, useful error guidance and one progress hierarchy. Keep keyboard operation, untimed play and revision. |
| P2 | Responsive UI is not proven: panel minimum width is 660, text minimum is 610, with no scrolling container. Every refresh recreates buttons and focuses Close. | Test narrow windows and large text; use adaptive width/scrolling, preserve keyboard focus on the active control and distinguish disabled, selected and completed states. This is a source-identified risk, not a measured mobile failure. |
| P2 | Material families are only partly unified. The new campus is a sibling of the zones, while the refinement pass traverses the zones and selected island assemblies. New fixture brass/ivory therefore bypass those adjustments; cabinet imports use their separate authored materials. | Reuse a single role-based finish library: matte ivory, brushed brass, teal enamel, glass and restrained emissive indicators. Make the result consistent through material assignment, not additional global brightening. |
| P2 | In the current captures, ivory floor, pillars and pale foliage compete at similar brightness. Bright cyan/purple remnants and floating world labels compete with the softer lab palette. | Improve floor/object contrast and contact shadows; reserve the strongest colour and light for actionable items. Fade irrelevant labels, retain readable mounted plaques and preserve distinct portal/state semantics. Verify in native Compatibility and WebGL2. |
| P2 | Part 1 has a strong laboratory landmark but dense layered lines; Part 2 remains mostly a repeated grove with a small work court. Sample cabinets resemble functional checkpoint furniture. | Give each department a legible work-zone floor treatment and purpose-specific specimen silhouettes. Preserve open walking space; do not fill every gap. Distinguish exhibits from operable machines at a glance. |
| P2 | Receiver tuning can be solved using only repeated +3 presses: +3 visits all eight positions. The recorded solution demonstrates this. | For greater optional depth, ask the player to predict or explain a relationship, or introduce meaningful coupled effects. Do not add arbitrary timers or punishment merely to increase difficulty. |

## Physical-design rules

- Stationary architecture: static collision, not thousands of rigid bodies.
- Moving doors/machines: collision moves with the visible assembly; test its full sweep.
- Movable props: rigid-body mass only where the gameplay actually permits movement.
- Light, mist and holograms: intentionally non-solid and visually identified as such.
- Structural connections may deliberately intersect at joints; unrelated solid volumes
  must not interpenetrate. Decorative mesh count or triangulation does not create collision.
- Ground every plinth; support overhead equipment visibly. Keep service lines away from
  operator space. Match player collision dimensions and camera clearance to the real game.

## Verified evidence

Fresh headless runs passed:

- `test_island_one_research_campus.gd`: 16 directions, nearest-control selection,
  floor support, clear standing capsules, optical beam origins, relocated Echo assembly,
  Quest 1-to-Quest 2 proximity actions and external gate remaining locked.
- `test_island_one_warm_surroundings.gd`: local finishes, shared palette, elevated lights,
  16 bounded purpose labels and locked beacon prerequisite. This headless invocation
  does not run the optional rendered camera-restoration section.

Still-current prior-turn evidence: Q1/Q2 save/reload, wrong-answer/revision, full-story
and internal gate end-pose tests passed. The recording exercises both local puzzles
through public proximity inputs and panel button signals. It uses an isolated save
and camera cuts, not continuous walking or a full public-browser campaign.

Existing ObjectDB shutdown warnings remain. No all-object intersection certificate,
frame-rate benchmark, audio audit or new web verification is claimed. Disk space
still blocks export of this local revision; the public site serves the older build.

## Improvement checklist, in order

- [x] Resolve solid service routing and the missing garden receiving manifold.
- [x] Add gate obstruction handling and test occupied opening/closing sweeps (left-leaf obstruction; broader coverage remains).
- [ ] Audit all reachable solids with actual player motion and boundary walking.
- [x] Correct area/gate terminology and next-step instructions.
- [x] Include campus furniture in the existing finish assignment; preserve functional instrument state materials.
- [x] Improve UI focus, responsive layout, contextual labels and scene visibility.
- [ ] Tune light/value separation and hide irrelevant labels.
- [ ] Strengthen department identity and optional puzzle reasoning.
- [ ] Record continuous player-controlled traversal, then repeat in the deployed browser.

Visual evidence: `artifacts/island_one_research_campus/REVIEW.md` and
`artifacts/research_campus_quest_video/REVIEW.md`.
