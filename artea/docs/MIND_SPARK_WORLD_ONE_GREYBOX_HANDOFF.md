# Mind Spark World One — Bird's-eye Greybox Handoff

Date: 2026-08-15

Status: implemented and verified locally. No commit, push, pull request, deployment, or GitHub action was performed.

The full six-island blueprint is now also the live World One reached from the Art Castle gallery. The former compact Mind Spark district remains as the collision-backed gate forecourt; it is no longer the quest world.

## Blueprint contract

The standalone World One scene now follows this required construction order:

1. Build all six collision-backed zone floors.
2. Build the single required walking route: `01 → 02 → 03 → 04 → 05 → 06`.
3. Add the Zone 01 World Gate, route checkpoints, Zone 05 boss arena, and Zone 06 final sanctuary.
4. Add the optional completed-world station spur last.

The station branches from Zone 05 toward the lower-right of the bird's-eye composition. It is not part of the required route, starts hidden, and all of its `StaticBody3D` collision layers remain disabled until completion unlocks it.

## Standalone zone datums

| Zone | Local position | Radius |
| --- | --- | ---: |
| 01 World Gate Landing | `(-960, 2, 420)` | 125 m |
| 02 Living Network Forest | `(-800, 12, 100)` | 190 m |
| 03 Constellation Court | `(-300, 24, -220)` | 175 m |
| 04 Hope Path Ridge | `(170, 40, 120)` | 120 m |
| 05 Thought Storm Arena | `(620, 58, 20)` | 210 m |
| 06 Oldest Tree Sanctuary | `(940, 84, -420)` | 180 m |
| Optional station island | `(930, 46, 500)` | 72 m |

## Changed files

- `scripts/mind_spark/mind_spark_world_one.gd`
  - separates floor, route, landmark and station construction phases;
  - retunes the six-zone footprint to the supplied bird's-eye silhouette;
  - adds a functional `EntryWorldGate` and four visible route checkpoint pads;
  - retains the boss retry checkpoint and final sanctuary;
  - moves the station branch from Zone 01 to Zone 05 and builds it last.
- `scripts/test_mind_spark_world_one.gd`
  - makes new greybox failures return a non-zero result;
  - verifies phase order, exact story order, checkpoint inventory, station ownership, route clearance, hidden station collision, and final geometry ordering.
- `scripts/capture_mind_spark_world_one_render.gd`
  - retunes the overhead camera to the blueprint composition;
  - shows the completed station branch only in the design capture.
- `scripts/art_castle_floating_world.gd`
  - mounts the blueprint at local origin `(-2200, 0, 1640)`, roughly 2 km closer than the first live placement while retaining a 300 m void buffer from the western Art Castle district edge;
  - places `MindSparkWorldGate` at the existing Mind Spark portal frame;
  - sends the player to the Zone 01 landing and returns them to the separate safe forecourt point `(-650, 7, 1575)` so the source gate cannot immediately retrigger.
- `scripts/art_castle_minimap.gd`
  - derives the six island discs, required route, bounds, and unlocked station spur from the live World One node.
- Live integration tests
  - replace the obsolete compressed-world/no-gate assumptions;
  - verify source, abort, locked final return, unlocked final return, all six floors, all ten physical story legs, hidden station policy, and a real player jump after gate travel.
- `artifacts/.gdignore`
  - prevents generated capture output from entering Godot's source-asset import scan.

## Verification evidence

- `MindSparkWorldOne: all checks passed`
- `MindSparkWorldOneStory: all checks passed`
- `MIND_SPARK_LIVE_GATE_BLUEPRINT: PASS — source, abort, completion return, floors, route, and station policy verified`
- `LIVE_MIND_SPARK_ENTRY_TEST: PASS — Art Castle gate enters full six-island World One and returns`
- `MindSparkGalaxyIntegration: PASS — complete six-island World One is gate-mounted outside the district`
- `MindSparkGalaxyTraversal: PASS — solid forecourt reaches gate; six-island route enters and returns`
- `MIND_SPARK_ARCHITECTURE_PHYSICS: PASS — bridge, six islands, story decks, textures, and real remote jump verified`
- `WORLD_MINIMAP_TEST: PASS — outside/inside atlases, live tracking, and full map toggle`
- `MindSparkCompletedTrainPolicy: all checks passed`
- `ALL_WORLD_PLAYER_TRAVERSAL_TEST: PASS — 4-way movement, braking, grounding, jumping, camera safety, walls, input locks, and fall recovery work in all worlds`
- `MIND_SPARK_WORLD_ONE_RENDER: PASS`

Primary visual artifact:

`artifacts/mind_spark_world_one_render/01_six_zone_birdseye.png`

## Scope boundary

World One is fully gate-mounted and playable in the live gallery. The optional station remains a completed-world side spur and cannot block the `01 → 06` story route. The existing Crown Railway station is intentionally unchanged in this bounded pass; train travel remains a completed-world revisit feature. No repository history or remote state was changed.
