# Island Two Implementation Checklist

## Scope

Island Two is the combined **Evidence Constellation Court + Hope Path Ridge** chapter of World 1: The Mind Spark Kingdom. Its current layout revision is `observatory_of_understanding_05_heavenly_hierarchy`.

Player story flow:

1. Read evidence rather than react to the first thought.
2. Weave the evidence into a coherent memory.
3. Optionally use the focus bell to slow down and listen.
4. Verify the conclusion at the archive logic gate.
5. Reframe the thought through the perspective lens.
6. Materialise the hopeful conclusion at the truth bridge.
7. Enter the guardian court after the chapter route is complete.

## Architecture and layout

- [x] Preserve the existing fused Island Two foundations and their navigable surfaces.
- [x] Place all six quest stations from one canonical layout table.
- [x] Give the five required stations an explicit story order from 1 through 5.
- [x] Face every station toward its intended player approach point.
- [x] Give each station at least a four-metre interaction apron.
- [x] Separate the Evidence chapter, transition gate, Hope chapter, and guardian encounter into readable zones.
- [x] Keep the existing island-to-island connection; do not add a redundant bridge.
- [x] Repurpose the original chapter gate as the Island Two entrance marker.
- [x] Disable and hide the duplicate prototype logic gate, including its collision.
- [x] Preserve the detailed hinged Memory Gate as the only progression gate.

## Quest object quality

- [x] Give every station its own court rather than scattering duplicated props on open ground.
- [x] Use a shared ivory, teal, and restrained gold material language.
- [x] Add a distinct low-poly verb emblem to each court: READ, WEAVE, LISTEN, VERIFY, REFRAME, and BUILD.
- [x] Keep quest stations reusable while assigning unique silhouettes and gameplay purposes.
- [x] Keep labels subordinate to the physical object and readable from the approach direction.
- [x] Remove solid coloured route lines and floating waypoint rings.
- [x] Replace them with discrete inset floor facets and chapter signage.
- [x] Apply Island One's role-based ivory, brass and teal finish to stationary structure while preserving state-driven lenses and feedback.
- [x] Give every required and optional station a simplified solid housing collision.

## Island One style alignment — revision 05 heavenly hierarchy

- [x] Add a dominant suspended Celestial Archive Orrery to the Evidence district.
- [x] Add grounded canopy buttresses and open observatory ribs without covering the sky.
- [x] Add an Evidence Aether Bus with named source, station feeds and Memory Gate destination.
- [x] Preserve the asymmetrical Lens Pavilion as the foreground puzzle laboratory.
- [x] Restore the older Aether Lift Pavilion's dais, columns, segmented canopy, lift core, canopy ribs, and opal crown as a background landmark.
- [x] Remove only the older oversized lift halo and three truth-portal rings that duplicate the new Truth Foundry.
- [x] Restore the curved sunrise garden terraces and Hope Path thought flowers.
- [x] Restore all eight older floating memory nodes as smaller archive lanterns.
- [x] Restore all mature trees from both older fourteen-tree groves.
- [x] Restore the six Hall of Hope support piers and inlays that an earlier broad ring-removal wildcard hid accidentally.
- [x] Replace circular truth portals with a supported rectilinear Truth Foundry.
- [x] Add the Hope Materialisation Conduit from perspective to truth to guardian.
- [x] Combine six new framed canopy trees with the complete mature planting layer from the older groves.
- [x] Add a live Conservatory Understanding Shrine and reward socket to clarify the chapter conclusion.
- [x] Keep collision enabled for restored heritage trees and disabled for removed halo/portal rings and the duplicate gate.
- [x] Rotate and relocate the arrival portico so its opening faces the incoming bridge.
- [x] Crown the arrival portico with a shallow sunrise arch and faceted Wisdom Beacon instead of another ring.
- [x] Redesign the functional Memory Gate leaves with teal panes, brass stiles, crossed braces, jewels, a dark crown and physical outward hinge motion.
- [x] Override Island Two foliage locally with emerald, sage and jade while preserving brown trunks, teal data fibres and restrained gold energy.
- [x] Relocate restored trees out of the arrival and Memory Gate clearance envelopes instead of deleting them.
- [x] Move the Hope Gallery directory board out of the Memory Gate sightline.
- [x] Add dark-teal research-bay recesses so ivory quest instruments remain legible against ivory paving.
- [x] Preserve the existing island footprint, quest IDs, save state, solutions and gate progression.

## Environment and movement

- [x] Replace the saturated alternating Hope path with a quieter celestial floor treatment.
- [x] Reserve strong gold for the final completed Hope stage.
- [x] Add measured inset details to make each Hope stage legible without visual clutter.
- [x] Add chapter-specific lighting: cool teal for evidence, warm light at the gate, and warm hopeful light on the ridge.
- [x] Move both ridge enemies into a bounded guardian court so they do not obstruct the learning route.
- [x] Keep decorative guidance meshes non-colliding so the player cannot snag on them.
- [x] Keep the quest aprons clear enough for player turning, interaction, and camera framing.

## Gameplay continuity

- [x] Continue the World 1 emotional arc from noticing a thought to understanding and reframing it.
- [x] Carry Island One's Echo Seed through the golden threshold as the physical and narrative input to Island Two.
- [x] Give the Echo Seed three readable layers: recorded event, fear prediction, and available choice.
- [x] Advance the environment through nine deterministic phases from `dormant` to `guardian_freed`.
- [x] Make the Evidence Aether Bus and Hope Materialisation Conduit reflect the current story phase.
- [x] Replace the Truth Foundry's generic completion click with fear, empty-fantasy, and grounded-hope choices.
- [x] Give all five required Island Two stations a focused interaction panel and story-specific completion text.
- [x] Preserve the existing station save IDs and completion state.
- [x] Preserve wrong-choice feedback, undo, reset, partial reload, and completion restore behaviour.
- [x] Keep the focus bell optional so it supports reflection without breaking the required quest sequence.
- [x] Keep the Memory Gate locked until the required reasoning sequence is complete.
- [x] Preserve the reward and progression signal after completion.

## Automated verification

| Check | Result | Evidence |
| --- | --- | --- |
| Island Two structural assertions | PASS with asset-cache warnings | Revision 04: six solid canonical stations, seven courts, Evidence Observatory, Hope Gallery, complete useful heritage layer, service flow, grouped planting, retired-collision checks, ordered route, consolidated gates, protected promenade, and contained guardian encounter. The minimal harness reports its six intentionally absent foundation imports. |
| Interactive station assertions | PASS with asset-cache warnings | Locking, evidence reasoning, wrong choices, UI, proximity, partial reload, undo, and reward preservation. The same foundation-import warnings are present. |
| Island One → Island Two story assertions | PASS with asset-cache warnings | Echo Seed invitation and arrival, evidence sorting, memory weaving, Archive Gate, three perspectives, two rejected statements, grounded hope, Guardian reward, and save/reload restoration all pass as one ordered quest. |
| Memory benchmark assertions | PASS with asset-cache warnings | Seven benchmark meshes, choice handling, poses, links, reset, completion, and restore. The same foundation-import warnings are present. |
| Three-island foundation integration test | BLOCKED | The local minimal test project is missing imported foundation GLBs; this is an asset-cache/environment failure rather than an Island Two assertion failure. |
| Full editor/web visual capture | BLOCKED | The source GLBs are present and valid, but the local `.godot/imported` cache is incomplete and the disk is effectively full, so a safe full re-import cannot currently run. |

## Final acceptance checks still required

- [ ] Free sufficient disk space without deleting user work.
- [ ] Re-import all World 1 GLBs and audio in the full Godot project.
- [ ] Run `test_mind_spark_three_island_fusion.gd` in the restored full project.
- [ ] Walk the complete route in player-camera view and inspect station facing, rail continuity, and clearance.
- [ ] Verify the Memory Gate leaves a collision-free opening through its full inward/outward animation.
- [x] Capture overview and player-perspective screenshots of Evidence Court, Memory Gate, Hope Ridge, and the Understanding Shrine.
- [ ] Run the web build and confirm background, lighting, audio, controls, and frame budget.

## Acceptance rule

Island Two is implementation-complete at source level when all checked items above remain true. It is release-verified only after every item in **Final acceptance checks still required** is checked in the restored full project.
