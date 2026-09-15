# Quest station layout audit — 13 September 2026

Reference: the approved ivory/gold/teal Memory Board. Scope: the eleven related
core quest-object types, their immediate placement, and player-facing feedback.
Do not rebuild islands, change quest order, reset player saves, or modify AGENTS.md.

## Audit findings

The palette and low-poly bases broadly match, but the implementation is not yet
consistent. Headers have excessive vertical gaps and duplicate progress lines;
the bell hint intersects its housing; optional controls have unexplained three-pip
indicators. The projector overlaps a tree and the arrival checkpoint intersects
another instrument. The lens's etched lines do not move with its glass. Legacy
feedback is only skipped by the hide pass, leaving transparency/label alpha at
zero. The rain exception names `Rain`, but the actual node is `GentleRain`.

## Acceptance checklist

- [x] Match the reference atlas, gold/enamel finish and layered base proportions.
- [x] Add readable ivory action plates; distinguish controls by function.
- [x] Keep headers compact above each actual silhouette; no duplicate progress.
- [x] Preserve wrong-answer feedback, hints, route markers and gentle rain visibly.
- [x] Keep lens engravings attached to its moving glass; show the bell suspension.
- [x] Give binary/helper stations one state light, not a misleading three-step meter.
- [x] Clear projector/tree and checkpoint/instrument intersections.
- [x] Inspect bell/scenery overlap, with instanced geometry included in the audit.
- [x] Verify saved state, gate motion, interactions, story and route regressions.
- [x] Capture revised in-game views and inspect them at player height.
- [x] Export standard Web, deploy existing site and verify WebGL2/Offline Guest startup.
- [ ] Clean full browser quest walkthrough — existing startup errors remain; see below.

Large joined island mesh bounding boxes are only broad-phase warnings, not proof
of a surface collision. Check visible geometry before removing or moving scenery.

## Implemented corrections

The arrival checkpoint is now at (-75, 2, 60), the projector at (75, 2, 60),
and the focus bell at (12, 4, -48), in their existing district coordinates.
The bell previously shared the decorative MemoryNode ring at z=-62. No tree,
railing or functional instrument was deleted to create room. The revised arrival
station aprons pass a small-prop AABB clearance check; the photographs additionally
show the projector canopy and checkpoint control intersections removed.

The reference metalness/roughness values are reused exactly. Eight upright models
have ivory action plates (gate, floor tile and basin keep their functional
silhouettes). Binary tools have one physical light; the evidence gate has two,
and the three-stage socket, scanner and lens have three.
The lighting profile now extends locally around later quest stations and restores
the original environment outside its influence. The later islands keep their
own scenery and atmosphere outside that station vicinity.

Evidence: `test_memory_style_quest_family.gd` now covers labels, caption plates,
single-light models, hint alpha, route transparency, rain visibility/emission,
arrival aprons and close-up camera exposure alongside previous state/reload tests.
Full story, Island Two interaction, lighting restoration and Zone 02 clearance
assertions passed. Some tests retain ObjectDB shutdown leak warnings; one headless
route run also reported a dummy-renderer shader RID shutdown leak. These are not
reported as a completely clean full-suite run.

Latest screenshots: `artifacts/memory_style_family/REVIEW.md`.

## Web verification

Deployment `dpl_8EYxihtj5jBhc9E6u49ZBS6vhjpy` is READY at
`https://artea-g49hjhjvi-dsovann80-2407s-projects.vercel.app`, serving the existing
`https://artea-web.vercel.app/` alias. The standard Web export has 144 parts and
no export/script errors. The temporary editor update-check preference is restored.
The cache-busting public URL loaded the start screen, confirmed WebGL2
Compatibility, and entered the coloured Offline Guest world.

The browser still logs the existing missing Firebase `.env` and
`refresh_slots called but inventory_data is null` at guest entry. These are not
fixed by the layout pass. No full public-browser quest walkthrough or clean
whole-game verification is claimed. Original AGENT/AGENTS files are unchanged;
no commit, push or merge was performed.
