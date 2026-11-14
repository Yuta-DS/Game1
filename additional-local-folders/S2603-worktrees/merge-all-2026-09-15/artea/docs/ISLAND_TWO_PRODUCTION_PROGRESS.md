# Island Two production progress — 2026-09-14

The full acceptance scope remains in ISLAND_TWO_FINAL_PRODUCT_RESEARCH_PLAN.md.
This is a progress record, not a production-completion certificate.

## Implemented and locally exercised

- Editable Blender inspection bay: 144 source meshes, 11 runtime meshes,
  27,976 triangles and four atlas-backed material families. Source and GLB are
  under assets3D/mind_spark/unfinished_light/inspection_bay.
- Cabinet, controls, recorder drum, focus carriage, bypass valve, open-front
  pavilion and static collision replace the old scanner assembly visually.
  Existing logical station/save identity remains intact.
- Shared UI/world evidence curves, focus clarity, distinct recorder windows,
  event markers and bypass shutter response reflect saved puzzle settings.
- Warmer task lighting, larger physical channel captions, keyboard focus
  restoration, local reset cleanup and evidence-scoped causal language.
- Inspection trace regression and five-quest Unfinished Light story tests pass.
  Story test covers wrong answers, partial reload, three approaches, undo and
  peaceful handoff. Campus regression passed before the final signage change.
- Native Compatibility captures: artifacts/inspection_bay/{front,player,controls}.png.
  These are rendered test-camera captures, not a recorded player playthrough
  and not deployed browser verification.

## Still required before production acceptance

- Refine the benchmark's actual shutter housings, sightlines and distant labels;
  current shutter plates remain schematic. Verify real-player reach/collision,
  completion/save migration presentation, keyboard-only flow and narrow layout.
- Finish recorder, causal model, perspective and projector asset/presentation
  passes; do not represent the remaining inherited assemblies as final assets.
- Complete pavilion/conservatory/environment staging and whole-island scale,
  accessibility, barrier, gate-sweep and route audits against Island One.
- Reconcile retired tests and investigate the previously observed Island One
  CampusSolidCabinet obstruction on the west-regulator approach.
- Measure full-scene performance, test real player quest traversal and provide
  video evidence. Native tests do not establish Web performance.
- Full non-Mono Web export, existing production deployment and live browser
  verification remain outstanding. Latest disk check: only 401 MiB available
  on the workspace volume. Do not delete user assets or the prior build to
  force an export. Establish sufficient safe export storage first.

No commits, pushes or AGENTS.md changes were made for this pass.

## Mechanical recorder continuation

- Added a distinct Blender recorder bay using the inspection bay's authored
  cabinet/pavilion shell and packed materials: 146 editable meshes, eight runtime
  meshes, 25,160 triangles. Drum, pointer, replay lever and three event tiles are
  separate moving nodes. Replaced the old MemoryWeavingCourt presentation while
  preserving the memory_board save identifier and quest role.
- The player's actual strip order drives a sampled replay shared by the world
  instrument and panel. Beam drift, flow level and shutter status appear in order;
  an incorrect order visibly closes the shutter before flow falls. This is a
  reconstruction display, not a claim that the wrong order was the historical event.
- A regression caught intersecting event plates. Transfer now lifts them into
  separate lanes before horizontal motion and settling. Sampled transfer
  clearance passes; rapid-input and full solid-environment sweeps remain to test.
- Added presentation-only replay for completed records without changing rewards.
- Passed recorder replay, recorder geometry/transfer/signage and campus tests.
  Full story assertions passed; one earlier headless run emitted a dummy-renderer
  shader RID leak on exit, so that run is not an entirely clean console result.
- Native Compatibility front/player/control captures are under
  artifacts/recorder_bay. Readable strip labels were verified in the player view.
  These remain test-camera stills, not browser/video or real movement evidence.

Still required: stronger physical output mechanisms, unified station mounting and
layout ownership, route-scale validation, next instrument/environment stages, and
the full release checks above. Available storage remains about 401 MiB.

## Physical integration continuation

- Consolidated both bays' scale, approach metadata, sensor, collision, task light
  and source-preservation policy in research_bay_mount.gd. Added missing solid
  shapes for the authored side shelves.
- Actual player-capsule testing found both mounts were based on the island deck,
  ignoring the higher solid ConstellationDais. Mounting now reads the existing
  dais mesh's top height when the bay is fully within that surface. The floor is
  retained; no authored dais is deleted or hidden to make the test pass.
- Passed test_research_bay_player_clearance: both front approaches are clear for
  the real player capsule, both benches block passage, both pairs of shelves
  have collision. This is a local approach test, not the whole island route.
- Extended recorder transfer test with rapid swaps/replay. Plates remain separated
  and settle to the latest saved order. Full Unfinished Light story test passes.
- Regenerated native Compatibility recorder captures after the height correction.

The next design stage remains the explanation-testing instrument and its visible
valve/flow/shutter experiment, followed by the remaining production plan. These
physical fixes do not constitute approval of all art, traversal or Web release.

## Explanation-testing instrument continuation

- Built and integrated tester_bay.blend/GLB: 143 editable source meshes,
  six runtime meshes and 29,800 triangles. Reuses the shared bay shell with a
  cooling reservoir, graduated sight gauge, connected bypass, handwheel,
  compression couplings, selector and guided shutter. The old ArchiveLogicCourt
  and InvestigationBackdrop_2 presentation is retired, not its save identity.
- Restricted-line and open-bypass trials are now required before the explanation
  can complete. The interface compares predicted and observed shutter states.
  Permanently-closed/always-open models fail against the two measurements.
  The accepted model explains this rig's protection, not the earlier beam drift.
- Physical gauge, valve, selector and shutter reflect saved state. Reset clears
  trial state and restores the initial instruction. Pipe/header depth was moved
  behind the shutter sweep; authored generator checks its separation.
- Passed causal experiment tests (both trials required, wrong models rejected,
  prediction consistency, animated gauge and shutter endpoints), all three bay
  player-capsule approach checks, full story assertions and campus regression.
- Native Compatibility captures are in artifacts/tester_bay, including player.png
  (restricted/closed) and bypass_open.png (restored/open). Visually inspected both.
  These do not establish live Web rendering, frame budget or full quest traversal.

Remaining production scope is unchanged: refine mechanical supports/signage and
whole-court composition, build perspective/projector/conservatory stages, complete
accessibility and save/re-entry checks, then full Web release and real browser
verification. Target age/hardware and safe export working space remain unresolved.

## Perspective workshop continuation

- Added a Blender evidence carousel with three distinct relief plates: Ari's
  account, the mechanism record and an offer of practical help. 150 editable
  meshes export to four runtime meshes (30,068 triangles). The rotating plates
  and selector share the selected view; explanatory text remains accessible in
  the panel. This is an evidence viewer, not a simulation that can measure feelings.
- Preserved the perspective_lens quest/save ID and interpretation progress.
  Centralized plate titles, accounts and contributions in perspective_evidence.gd.
- The old placement failed actual player access: the bridge rail blocked it.
  Further inward placement exposed the other lobe's perimeter boundary. The
  final canonical position is Hope-lobe local (-24,3,6), mounted to floor height,
  with its front facing the arrival side. The working boundary rails are retained.
- Sampled nearby physical floor heights and reviewed player-view renders to move
  the base away from intersecting path decoration. Current player capture shows
  the full base and unobstructed evidence plate.
- Passed three-view rotation/caption/interpretation/completion assertions and
  the real-player capsule approach test for all four detailed bays. The viewer
  test emitted two ObjectDB cleanup warnings; this is not a clean release-console
  result. Full story assertions passed, with an intermittent dummy shader cleanup
  warning in that run. Campus regression passed before the last local relocation.
- Native Compatibility captures: artifacts/perspective_bay/player.png,
  view_1.png and view_2.png. No deployed Web/video evidence is claimed.

Next remains the living projector and its three visibly different repair
approaches, followed by conservatory/court composition, full traversal and
release verification. Current progress does not meet the whole production plan.

## Living projector continuation

- Added the editable Blender projector asset (95 source parts, 18 runtime meshes,
  17,300 triangles), sharing the cabinet kit. Three controls drive the mirror,
  pattern plate, protected light head and botanical receivers. The reference
  clamp and cooling indicator distinguish the three repair approaches.
- Raised the planting platform after reviewing the actual operator-height render.
  Added a mounted ivory live/target fascia: numerical readings complement colour
  and the small targets behind the machine. This does not establish complete
  accessibility; full input, text-size and hardware testing remains outstanding.
- Preserved the quest/save identity. Retired the old projector presentation, not
  its quest. Described the linked instrument as a fictional pattern puzzle, not
  an accurate optics simulation.
- Native tests passed for all five operator approaches, campus gate clearance,
  cooling interlock, three approach presentations, undo/reset and legacy completed
  saves. Extended the projector test to solve using public tune/project actions,
  verify leaves unfold and verify ray endpoints meet their targets. That run
  completed without the earlier cleanup warning.
- Captured artifacts/projector/restored.png through real station actions from
  operator height. This is a scripted native Compatibility capture, not a manual
  player traversal, video, Web build or deployment.

Remaining: improve the congested head/receiver sightline and surrounding
conservatory composition, complete the wider production plan and route tests,
and export/deploy/verify the full game. Disk availability measured 284 MiB;
the user agreed to alternate storage but its path is still needed. No assets
or previous builds were deleted to create space.

## Conservatory structural continuation

- Replaced the five individual ridge segments (including the unsupported final
  overrun) with seven longitudinal members terminating at the end arches.
- Added ten bevelled column feet with matching solid footprints. Added two
  restrained side glazing ribbons, batched into one mesh (32 triangles), bounded
  by the existing ribs and new longitudinal frames. The centre remains open for
  ventilation; this is not a weather-tight complete greenhouse.
- Roof geometry checks passed for arch endpoints, panel bounds and clear central
  opening. Actual-player tests still pass for all five station aprons after the
  added foot collisions. These tests do not establish the whole walking route.
- Reviewed native Compatibility architectural capture at
  artifacts/projector/conservatory.png. It exposes remaining composition issues:
  the old oversized framing, cyan plates and sparse planting still compete with
  the working garden. Their ownership/dependency audit is not complete, so this
  turn did not blindly delete those assets or call the conservatory finished.
- Latest free space was 242 MiB. Full export/deployment/browser verification is
  still pending alternate storage; no production completion is claimed.

## Retired-geometry batching defect

- Traced the cyan plate chain to the world static-batching pass: it collected
  meshes regardless of direct or inherited visibility, then created visible
  root-level MultiMeshes. Previously retired geometry therefore reappeared even
  though its source assembly was hidden.
- Reproduced with 24 equal meshes: eight beneath a hidden parent, eight directly
  hidden and eight visible. Before the fix all 24 entered the batch. After the
  visibility guard only eight enter it; hidden source nodes remain recoverable.
- Regenerated and inspected the conservatory Compatibility capture. The cyan
  plate chain crossing the floor is absent. No authored source assets were
  deleted; the fix respects their existing retirement state.
- Passed test_static_batch_visibility, test_unfinished_light_story (including
  save/reload and all three approaches), and all five operator-apron clearance
  tests. Full scene visibility transitions and production Web verification
  remain part of the broader release work.

## Island One prerequisite-route repairs

- Reproduced the previously documented west-regulator obstruction with the
  actual player capsule. Moved the landing checkpoint and east-side path helper
  from x=±24 to x=±36, retaining complete assemblies, functions and collision.
- Separated confirmation from its neighbouring control and faced the three
  Echo receivers toward the inner aisle. Their inspection positions now select
  the intended instrument instead of a nearby one.
- Updated two stale test assumptions: helper tests now sample their actual
  standing floor instead of using an absolute y=3.1; the campus test expects
  the intentional absence of the four duplicate sample benches.
- Passed all 16 approach-selection/floor-support checks, Q1-to-Q2 progression,
  beam endpoint checks, both directions of occupied gate stop/resume, physical
  collision with 16 instruments and four helpers, and narrow-panel focus tests.
  The campus test still reports two ObjectDB instances at exit; cleanup remains
  unverified. These are native focused tests, not a production playthrough.

## Quest-audio lifecycle continuation

- Verbose investigation identified the two exit instances as AudioStreamWAV and
  AudioStreamPlaybackWAV. Quest objects now stop their local sound and clear its
  stream when leaving the scene; re-entry lazily recreates the same feedback.
- Added a three-cycle play/remove/re-enter test. It checks stopped playback on
  exit, resumed playback on return and weak-reference release of all three WAVs
  after the player is destroyed and the deferred mixer cleanup has run.
- The player can cache a stopped playback while its node remains alive; an
  immediate weak-reference assertion on removal alone was not a valid leak test.
  Resources are verified released after destruction, not merely detached.
- Audio lifecycle test passed without warnings. Campus regression passed with
  the short asynchronous teardown interval and no AudioStream leak warning, but
  one dummy-renderer shader RID warning remained. This does not verify audible
  Web playback or satisfy the clean production-console requirement.

## Instrument sound-feedback continuation

- Added seven short synthesized cues: detent, recorded observation, recorder
  replay, flow, alignment adjustment, gentle revision and completion. Existing
  actions select the cue; no new quest state or reward path was introduced.
- Cues use bounded 16-bit mono PCM with deterministic samples. Per-station clips
  are reused during interaction and released on scene exit. Legacy non-research
  quest sounds retain their previous tone.
- Passed tests for all seven distinct clips, sample bounds, determinism, action
  mapping, muted scanner feedback/progress and three audio lifecycle cycles.
  Full Unfinished Light story/save/reload test passed in this run without a
  console warning. This alone does not resolve every earlier renderer warning.
- These are supplemental sounds: live traces, readings and text remain the
  evidence. Sound direction/volume, subjective mix quality and actual Web audio
  still require audible browser verification; waveform tests do not prove them.

## Full Web export resumed

- Disk recheck found 40 GiB free, clearing the earlier storage blocker. Preserved
  the previous Web directory at builds/web-backup-46Vexz/web before invoking the
  maintained export script with standard non-Mono Godot 4.7.1. The backup has
  .gdignore and is excluded by the existing builds/** export exclusion.
- Full Web export completed (exit 0): 145 PCK parts, 1,215,354,764 packed bytes.
  This is the complete existing Web preset, not the small capture project.
- The export is NOT release-approved. It reported the missing Firebase database
  listener script addons/http-sse-client/HTTPSSEClient.gd, older FBX texture/light
  import problems, invalid/duplicate UID warnings and exit cleanup warnings.
  The Firebase scene directly references that absent script and reference.gd
  calls its new_sse_event signal and connect_to_host method; the dependency
  needs resolution before claiming database functionality in the release.
- No new production deployment was made in this cycle. The existing browser tab
  still points to an older deployment. New-build WebGL2 startup, audio, gameplay
  traversal, performance and full design approval remain unverified.

## Missing Firebase listener restored

- Restored the absent http-sse-client script from GodotNuts/GodotFirebase commit
  68be88690f8afd1be505f17e16af685bf33572b9 with its MIT license and provenance.
  The installed Firebase SDK and account configuration were not replaced.
- Changed the listener's stream request from upstream POST to read-only GET and
  allowed explicitly configured HTTP emulator connections without TLS. HTTPS
  keeps certificate-verifying TLSOptions.client; no verification bypass added.
- Passed a real localhost TCP/HTTP fixture: GET /fixture.json, event-stream
  Accept header and Firebase-style put event delivery. No live database was
  contacted by this test. Browser streaming/reconnect/redirects remain unverified.
- Full maintained Web export completed again with 145 parts; the missing SSE
  script error is gone. Export still reports duplicate/invalid resource UIDs,
  an autoload TLS-handshake error and two cleanup instances. Earlier missing
  FBX textures are not proven fixed merely because cached imports are reused.
- Production deployment remains pending validation. The plant FBX is referenced
  by the semantic creation factory and gallery scene, so it cannot simply be
  removed from the build as an irrelevant demo asset.

Reference: https://firebase.google.com/docs/database/rest/retrieve-data
describes read-only GET and Realtime Database event streaming.

## Local full-Web browser startup verification

- Served the complete exported directory on loopback port 18080 (server session
  93905). In-app browser tab 8 loaded the full pack, rendered the coloured Artéa
  start screen, accepted Offline Guest, and rendered the 3D hub with Mayor Milo.
  Pressing M opened the in-game map. This is actual browser startup/input evidence,
  not a native capture or reduced test project.
- Browser console reported inability to load addons/godot-firebase/.env from the
  pack. firebase/firebase.gd expects that file and has no export-safe fallback.
  Online configuration therefore remains broken even though Offline Guest works.
- Do not solve this by blindly exporting the entire .env: its schema includes
  clientSecret and provider secrets. A reviewed allowlisted client configuration
  export is needed, without logging or packaging private credentials.
- No new production deployment and no Island Two browser playthrough yet. The
  local browser tab is preserved for continued verification. Server remains
  loopback-only; no account signup/login or live database operation was performed
  through the testing UI.

## Export-safe Firebase client configuration

- Added a shared eight-key public-client allowlist and generated JSON in data/;
  Web loads this file instead of requesting the private local .env. Native
  configuration is unchanged. The maintained export generates and validates
  configuration before removing previous generated pack parts. Generated
  identifiers are ignored by Git, not hardcoded in source.
- Passing focused test covers private OAuth/provider/service-account fixture
  exclusion, required fields, invalid types and runtime JSON filtering. Existing
  localhost SSE GET/event delivery regression also passes. No live login or
  database operation was exercised; databaseURL remains unconfigured locally.
- Full Web export completed with 145 parts. A fresh browser tab (9) loaded the
  full start screen in colour and returned an empty error/warning log. Tab 8
  retains an earlier error, so the fresh-tab result is the clean startup proof.
- Export still reports duplicate resource UIDs and native cleanup warnings;
  missing legacy FBX textures, production deployment and full Island Two Web
  traversal remain outstanding. This is not final production acceptance.

Firebase's public configuration distinction:
https://firebase.google.com/docs/web/learn-more
The allowlist excludes OAuth secrets regardless of whether currently populated.

- Fresh tab 9 also accepted Offline Guest, rendered the hub/avatar/Mayor Milo,
  and opened the map with M. The error/warning log remained empty after guest
  entry. This verifies startup and those inputs only, not Island Two traversal
  or online account operations. Tab 9 is left on the hub map for continuation.

## Botanical beds and duplicate promenade consolidation

- Replaced the nine block-and-sphere garden placeholders with one reusable
  research_planter assembly: bevelled retaining shell, recessed dark soil, five
  rooted folded-leaf rosettes, drip branches, header and service housing. Each
  bed preserves the original 15 x 9 x 2 solid envelope. Forty leaves share one
  MultiMesh per bed rather than forty separate render objects.
- Tests distinguish headless construction math from actual rendered MultiMesh
  storage: both pass. The dummy renderer returns zero instance transforms and
  must not be used as evidence of GPU-backed placements. New detail capture:
  artifacts/projector/research_planter.png (native Compatibility, not Web).
- Source-owner ray inspection identified the long apparent gold canopy spikes
  as FusedSuperIsland_03_04/RightPromenadeRail. Retired both obsolete fused rails,
  their lamps/glows and old inlay/channel. Shared saddle, foundation machinery,
  current MemoryPromenade and external bridges remain. Disabled the obsolete
  CircuitRoute_03 rail collision as well as its hidden rendering.
- Updated conservatory capture confirms these long gold rail intrusions are
  gone. No canopy removal was needed for this defect. Broader composition,
  old hovering garden ornaments and legacy optics framing still need review.
- PASS: planter construction/rendered transforms; conservatory roof + retired
  fitting checks; memory campus/gate sweep; actual player capsule at all five
  operator aprons; departure gate plus 217 perimeter samples and four bridge
  halves. These are sampled checks, not complete input-driven route proof.
- Full maintained Web export started after these edits. Production delivery and
  Island Two browser traversal remain outstanding; no Git commit or push made.
- Export subsequently completed successfully (145 pack parts). Existing UID and
  native cleanup warnings remain; no new production deployment was performed.

## Rooted planting on the legacy curved terraces

- Source search found SunriseGardenCrown/Bloom referenced only by their scenery
  builder. Retired these 24 hovering decorative meshes, preserving source nodes
  and all quest stations. Twelve existing curved terrace slabs remain in place.
- Replaced their full gold top material with dark soil, added ivory retaining
  lips/end caps, and placed nine folded-leaf rosettes in each bed. Leaves reuse
  the research planter mesh, instanced in one MultiMesh per terrace.
- Updated native Compatibility conservatory capture shows the changed garden.
  Rendered regression checks every terrace leaf vertex against radial and angular
  bed limits and checks roots below the soil surface. This is not a Web capture
  or a claim of final environment approval.
- Both headless construction tests and rendered Compatibility boundary tests
  passed. Full Web export completed with 145 parts; existing UID/cleanup warnings
  remain. No production deployment or browser verification of these new terraces
  has been performed yet.
