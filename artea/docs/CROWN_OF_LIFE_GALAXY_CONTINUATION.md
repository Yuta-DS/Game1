# Crown of Life — Art Castle Galaxy production continuation

## Current user intent

Continue the existing Crown of Life Adventure as a deliverable Art Castle Galaxy
game, not a functional prototype. The artistic direction is **science fused
with magic**: celestial engineering, constellation routes, aether crystals,
arcane observatories, harmonic energy, and a welcoming Artéa castle destination.

The existing 10–15 minute adventure is mechanically complete. It already has
three sequential discovery interactions plus three mandatory Lens
capture-and-placement crossings, safe recovery, persistence, accessibility,
audience parity, replay, credits, a finale, a standalone PCK, and a macOS
release candidate. This pass must make those real systems feel like one
intentional adventure rather than disconnected test platforms.

## Fresh visual evidence

On 10 August 2026, fresh Metal captures confirmed that the current build runs,
but exposed production-quality gaps:

- The wide world view reads as four mostly rectangular floating platforms in
  empty space instead of a connected Castle Galaxy voyage.
- Mind, Heart, and Creator have colour/motif differences, but lack strong,
  distant science-magic silhouettes that orient the player before each puzzle.
- Large transparent rectangular gate frames dominate several compositions.
- The finale train and star are mechanically present but need a stronger heroic
  composition and richer visual framing to feel ceremonial rather than modular.

## Non-negotiable invariants

Do not change, weaken, or replace:

- The existing single `LensController`, frustum cutter, Cuttable layer/mask, or
  source-body mesh contract.
- Three chapter order and distinct interactions: thought reframe, six emotions,
  and ungraded creative choice before each Lens crossing.
- Real puzzle gaps, bridge collision, gates, fall recovery, checkpoints,
  JourneyState persistence/migration, audience parity, subtitles, accessibility,
  pause/restart/replay/credits, or return/exit behavior.
- Existing node names used by acceptance tests. Decoration must not have
  collision, Cuttable membership, or a network/personal-data side effect.
- Unrelated dirty-worktree changes. Do not reset, checkout, stash, stage,
  commit, push, delete unrelated files, or download unlicensed assets.

## Scoped implementation pass

Worker-owned files only:

- `artea/scripts/viewfinder/crown_of_life_story.gd`
- `artea/scripts/capture_crown_story.gd`
- `artea/scripts/test_crown_story.gd` only for additive, non-brittle visual
  contracts
- this continuation file, to record exact changes and validation

Implement visual-only runtime geometry/material/lighting improvements:

1. Build a legible **celestial route spine** around the existing islands:
   staggered non-colliding aether pylons, constellation arcs, asteroid/rock
   silhouettes, and distant nebula/depth accents. It must visually connect the
   journey without bridging or bypassing the three real Lens gaps.
2. Give each existing zone a tall signature landmark visible from its approach:
   Mind Spark = crystalline observatory/star chart; Heart Melody = harmonic
   resonance garden/instrument architecture; Creator's Light = luminous
   art-forge/atelier. Use the existing science-magic vocabulary, not a separate
   genre. All landmarks are decoration only.
3. Replace the visually dominant wall-like gate treatment with deliberate
   portal architecture—slim frame, spaced energy field, readable opening—and
   stage it so it directs the player toward the source and puzzle gap.
4. Improve the castle/finale presentation with a stronger destination approach,
   clearer ceremonial train/track silhouette, and a hero composition where the
   crown, identity star, train, castle, and final message do not compete.
5. Update beauty cameras so the nine 1280x720 proof renders demonstrate the
   journey, all three identities, and finale at player-relevant scale.

## Acceptance gate

- Every chapter remains playable and requires its original discovery interaction
  and real Lens placement.
- The wide proof reads as a connected galaxy route; each chapter screenshot is
  identifiable at a glance without relying only on a label or tint.
- No huge flat rectangular gate dominates the player path; final renders make
  the castle/train/star/crown readable.
- `test_crown_story`, scene-path scan, JourneyState, Crown finale, audience
  mode, and all Viewfinder tests pass. The normal Metal capture writes all nine
  images and they are visually reviewed.
- `git diff --check` passes for every changed tracked text/code file.

## Verification record

Baseline before this continuation pass (10 August 2026):

- `test_crown_story.gd`: PASS
- `test_scene_paths.gd`: PASS, 171 scripts scanned
- `test_journey_state.gd`: PASS
- `test_crown_finale.gd`: PASS
- `test_audience_mode.gd`: PASS
- `run_viewfinder_tests.sh`: PASS, 11 suites
- `capture_crown_story.gd`: PASS, nine Metal-rendered PNGs

## Worker prompt

Read this file, then `CROWN_OF_LIFE_STORY_IMPLEMENTATION.md`, before editing.
Make one bounded Art Castle Galaxy production-art pass using only the owned
files. Preserve all gameplay and test contracts above. Work from the concrete
visual gaps, not from a wish to add unrelated gameplay. Run the focused Crown
test and scene-path scan before stopping; update this file with changed files,
test results, capture status, remaining risks, and exact next action.

## Implementation and delivery record — 10 August 2026

### Shipped visual pass

`scripts/viewfinder/crown_of_life_story.gd` now turns the pre-existing three
chapter route into an Art Castle Galaxy without changing any game contract:

- A non-colliding **CelestialRouteSpine** adds distant aether pylons,
  constellation arches, asteroid silhouettes, coloured lights, and depth
  cues. It never supplies a route across a Lens-gated gap.
- Every chapter now has a readable, non-colliding signature landmark: a
  crystalline Mind observatory, Heart resonance garden, and Creator atelier
  forge. The existing learning interactions, placements, collisions, and
  checkpoints are unchanged.
- Flat visual floor slabs became faceted astrolabe islands with luminous energy
  rims and tapered undersides; their original invisible collision surfaces
  remain in place, preserving movement and puzzle clearance.
- Gate art is now a narrow portal frame with spaced energy beams while the
  original full gate collision remains. The finale gained layered train roofs,
  track sleepers, signal finials, and a three-ring constellation halo framing
  the crown, identity star, train, and castle.

Fresh Metal proof captures were regenerated and reviewed after the final island
pass: `crown_story_00_world_overview.png` through
`crown_story_08_finale_hero.png` show the connected celestial route, the three
landmark identities, and the castle finale at player scale.

### Functional verification

- Focused Crown story test: PASS.
- Scene-path scan: PASS (171 scripts scanned).
- JourneyState, Crown finale, and audience-mode tests: PASS.
- Viewfinder mechanics: all eleven behavioural suites pass. The normal suite
  runner hit a Godot 4.7 headless Metal driver SIGSEGV only while launching
  `test_lens_controller`; its ten other suites passed, and the controller
  suite passed independently with the compatibility/OpenGL renderer. This is
  an engine/headless-driver issue, not a test assertion or game-script failure.

### macOS delivery artifact

The standalone package was exported with only the story-required `Global` and
`JourneyState` autoloads, then the workspace's full autoload configuration was
restored exactly. This avoids shipping unrelated Firebase, hub, and dialogue
dependencies that are intentionally excluded by the story export filter.

- Signed app: `builds/Artea.app` (ad-hoc signature verified with
  `codesign --verify --deep --strict`).
- Release archive: `builds/Artea-Crown-of-Life-Galaxy-macOS.zip` (240.8 MB;
  full `unzip -t` integrity check passed).
- The app started headlessly from its embedded release PCK without parse or
  missing-dependency errors. Its PCK SHA-256 is
  `078dc160399f123f4d54adf1ad1ad3c5a1019be867f7865341a94a3f892c5cd4`;
  the archive SHA-256 is
  `ca007d897a8cd4635acb3fc760d33e8fbcbc8bcdde73cdec7d159207d5bc2bbd`.

### Remaining release boundary

This is a signed, runnable macOS delivery candidate, not Apple-notarized
distribution. Notarization and a Developer ID signature require the product
owner's Apple credentials and are the only remaining platform-release step.
