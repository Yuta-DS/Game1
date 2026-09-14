# Island Two — Garden of Unfinished Light

## Combined implementation contract

Retain the three combined foundations and existing authored asset families. Five
world chapters: Notice the Signal; Listen to the Echo; Understand the Moment;
Build a Possible Tomorrow; Calm the Thought Storm. Preserve legacy task IDs and
completed progress during migration. Never award migration XP twice.

Everlasting Father accompanies the player. Ari is the apprentice whose first
garden projection stopped. The intact Echo Seed reveals evidence rather than
breaking. Evidence: beam drift precedes Ari's action; the recorder places cooling
loss before protective shutdown; operating the valve explains the shutter.
Feelings are respected; predictions are investigated, never treated as faults.

## Spatial contract

Incoming bridge -> portico -> receiver -> three investigation instruments ->
causal reconstruction -> archive gate -> perspective conservatory -> garden
projector -> Ari's reflection -> departure bridge. Reuse named station IDs for
saves and interaction targeting. Each instrument faces its operator apron. Retain
clear central circulation and locate planting outside door and operator areas.

## Puzzle contract

Scanner: inspect three evidence channels using distinct adjustments; retain
observations. Recorder: reorder three event strips, replay, revise locally.
Archive: test a causal model against all observations. Perspective: associate
each view with the information it uniquely contributes. Projector: choose small
test, collaboration or cooling-first; tune coupled mirror/shutter/plate controls
to a visible target. Preview, undo and reset are untimed. All three approaches
are valid and alter the target/constraints. Confirm restoration with Ari before
opening Island Three. No mandatory Island Two enemy kills.

## Art contract

Matte ivory structure, brushed brass mechanisms, deep teal instrument housings,
sage/emerald planting, pale glass. Crescent investigation bays and conservatory
ribs establish different silhouettes. The living projector is the second court's
landmark: grounded basin, mechanical stems, leaves, optical assembly. Saved
puzzle state controls beam, leaf and light feedback. Details stay attached to
moving objects and do not enter static world batches.

## Validation / delivery checklist

- [x] Tested migrated quest saves preserve achievements and XP.
- [x] Wrong evidence/model/view choices cannot complete tasks.
- [x] Three restoration approaches, undo and partial reload work.
- [ ] Exhaustive reset and fresh-start end-to-end player traversal.
- [ ] Player can operate every station from its approach, keyboard or pointer.
- [x] Gate leaf motion and obstruction stop/resume tested with imported foundations.
- [ ] Walk/jump-test every side boundary with the actual player controller.
- [x] Native overview, gate and puzzle-panel captures reviewed.
- [x] Six foundation GLBs imported into the focused test project.
- [ ] Full-project Web export verified.
- [ ] Production deployment and browser gameplay verified under AGENTS.md.

Passing isolated tests does not satisfy the full-world or browser items.

## Local verification — 2026-09-14

Passed `test_unfinished_light_story.gd`, `test_island_two_memory_campus.gd`,
`test_mind_spark_island_one_quest_1_signal_observatory.gd`, and
`test_mind_spark_island_one_quest_2_echo_garden.gd` in the focused native project.
Story tests exercise station actions, not mouse-driven full-world traversal.
Panel checks verify construction, including legacy text restoration results.
`git diff --check` passes. Previous Island Two tests targeting retired mechanics
have not been reconciled; these results are not a full-suite pass.

Screenshots are under `artifacts/island_two_overview/`: `overview.png`,
`memory_gate_closed.png`, `memory_gate.png`, `garden_puzzle_controls.png`, and
`restored_conservatory.png`. These are native captures, not deployed Web evidence.

## Remaining quality and delivery work

- Ari is a simple memory-projection representation, not a finished character.
- Refine sparsely furnished court areas and legacy visual clutter; complete
  conservatory glazing, material balancing and more legible instrument details.
- Verify all station approaches at actual player height, collision clearance,
  keyboard focus and full continuous play through both Island Two quests.
- Reconcile old Island Two regression tests with the new puzzle contract.
- Web export/deployment not attempted: available disk was approximately 470 MiB,
  versus 2.3 GiB of source assets and unbuilt full-project imports. The maintained
  exporter also removes previous generated pack files before exporting; avoid
  starting an unsafe export with insufficient space. No user files were deleted.
  Production deployment ID and browser verification are therefore unavailable.

This is a locally tested implementation pass, not completed production delivery.
