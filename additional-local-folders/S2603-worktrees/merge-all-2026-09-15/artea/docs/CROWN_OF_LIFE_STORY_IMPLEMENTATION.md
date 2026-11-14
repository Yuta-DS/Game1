# Crown of Life Story — implementation and handoff

This is the canonical handoff for the short, first-person ARTÉA story inspired
by Viewfinder's spatial capture-and-placement loop. It must remain useful if a
Claude Code session stops early: update the status and evidence sections after
every material change.

## Paste this into a new Claude Code session

> Continue the ARTÉA Crown of Life story in `/Users/davidsovann/GAME`.
> Read `artea/docs/CROWN_OF_LIFE_STORY_IMPLEMENTATION.md` completely before
> changing anything. Preserve unrelated dirty-worktree changes; do not stash,
> reset, checkout, commit, or push. The playable implementation and acceptance
> tests are complete, so do not replace the existing Lens/cutter or rewrite the
> architecture. Start from **Status**, **Evidence**, and **Optional future
> polish**, inspect the current files, make only the requested next improvement,
> and rerun the documented tests. Keep this handoff updated before token limits.

## Product outcome

Create one playable 10–15 minute chapter inside the existing Godot project.
The player uses the existing Lens of Seeing to cross three symbolic worlds in
sequence, then reaches the Crown of Life celebration. The mechanic follows the
TNTC/Viewfinder reference, but every object, line, reward, and transition serves
ARTÉA's own story.

This scene supplements the existing standalone mini-games. It does not delete
or duplicate their internals.

## Final-product completion standard

The earlier vertical slice is not the finish line. The short game is a final
product only when all of the following are true:

- **Complete journey:** title/prologue, three clearly different chapter
  experiences, earned treasure transitions, finale, credits/return/replay.
- **Unskippable but recoverable puzzles:** each chapter requires a real Lens
  capture/place at its own goal; the player cannot walk, jump, or fall past it;
  falling respawns safely; restart chapter and restart journey are available.
- **Production UX:** current chapter, objective, Lens controls, feedback, pause,
  resume, settings, return-to-castle confirmation, and completion state are
  understandable without reading source code or this document.
- **Accessible presentation:** subtitles are always available; text-size and
  reduce-motion options exist; keyboard/mouse operation is complete; faith and
  universal registers retain identical gameplay and rewards.
- **Audio and atmosphere:** licensed/in-project ambience and interaction cues
  are used with independent music/SFX volume and mute controls. The game also
  remains fully understandable muted.
- **Story fidelity:** Mind Spark transforms a limiting thought, Heart Melody
  expresses multiple named emotions through sound/colour, Creator's Light
  celebrates a player-made choice without judging artistic quality, and the
  finale explicitly communicates identity, value, gifts, story, and purpose.
- **Privacy:** no personal reflection is uploaded; no generative system judges
  or diagnoses a child; authenticated name use is optional and local to the
  presentation.
- **Release readiness:** clean scene loading, deterministic save migration,
  repeatable acceptance tests, rendered evidence for prologue/each chapter/
  finale, configured desktop export metadata, and a packaged-build smoke test.

### Final-product status

- [x] Distinct Mind Spark interaction and transformation feedback (`E` near
  the thought sphere changes "I cannot do this" into "I am learning and
  growing" before that sphere becomes Cuttable; dedicated anticipation cue)
- [x] Distinct Heart Melody emotion/music interaction (`E` discovers Joy,
  Sadness, Frustration, Fear, Peace, and Hope as six named colours/sounds;
  only the completed melody torus becomes Cuttable)
- [x] Distinct Creator's Light creative-choice interaction (`1`/`2`/`3`, or
  `E` for the default, chooses Courage Sun, Kindness Star, or Wonder Portal;
  every choice is celebrated without grading and unlocks the canvas source)
- [x] Objective/progress HUD and contextual tutorial (top-centre "Objective:
  …" line naming the next concrete action; top-right "Treasures: n / 3"
  counter; both update live as chapters complete)
- [x] Pause, restart, return confirmation, and fall recovery (`P` or `Esc`
  opens a pause menu: Resume, Restart Current Chapter, Restart Whole
  Journey, Audio & Accessibility, Return to Castle; every progress-affecting
  action routes through a shared Yes/No confirmation; falling below the
  world respawns at the last checkpoint instead of leaving the player
  stuck)
- [x] Audio, volume controls, subtitles, text size, and reduce motion
  (ambient music + per-chapter SFX cues from existing project assets;
  independent music/SFX volume sliders and mute toggles; subtitles-off hides
  captions but the scene stays fully controllable; large-text toggle scales
  all HUD/caption labels; reduce-motion toggle swaps the bridge-opening
  tween for an instant brightness change; all settings persist to
  `user://crown_story_settings.cfg`, independent of `JourneyState`)
- [x] Earned treasure transition presentation for all three chapters (each
  valid placement pulses the bridge's emissive material and plays the
  "open chest" SFX cue; reduce-motion replaces the pulse with one instant
  brightness change)
- [x] Finale celebration, replay/return, and short credits (Replay Journey
  clears story chapters/treasures — preserving the facilitator's chosen
  audience mode — and reloads the scene; Credits shows a short named-roles
  panel; Return to Castle remains available)
- [x] Full visual capture set (prologue, all three chapters, pause/settings,
  and finale) — see Evidence below.
- [x] Desktop release package and smoke test: universal macOS 1.0.0 app,
  ad-hoc signed for local use, archived as
  `builds/Artea-Crown-of-Life-macOS.zip`; archive extraction, strict signature
  verification, and ARM64 binary startup all pass without startup/script/
  dependency errors. A matching `builds/CrownOfLifeStory.pck` also passes a
  source-independent launch.

The three discovery interactions are deliberately different, while the Lens
of Seeing's capture/place gesture remains the common spatial-puzzle language.
The existing `lens_controller.gd` and cutter stack are authoritative; no
second world-cutting implementation was introduced.

## Story flow

1. **Prologue — ARTÉA Castle Galaxy**
   - Milo explains that the player is discovering treasures already within
     them, not collecting broken pieces.
   - Controls teach `WASD`, mouse look, `Space`, `Q`, click, `T`, and `Esc`.
2. **Mind Spark Kingdom — Star of Wisdom**
   - The framed object begins as the thought “I cannot do this.”
   - The player carries it across a missing path with the Lens.
   - It becomes “I am learning and growing.”
   - Faith guardian: Everlasting Father. Universal guardian: Keeper of Wisdom.
3. **Heart Melody Kingdom — Harmony Jewel**
   - Joy, sadness, frustration, fear, peace, and hope appear as colours/notes.
   - The player carries a resonant piece into a silent gap.
   - Faith guardian: Archangel Raphael. Universal: Keeper of Healing.
4. **Creator's Light Kingdom — Creator's Light**
   - The player carries a canvas/light fragment to complete a doorway.
   - The game reflects creativity without judging artistic quality.
   - Faith guardian: Uriel. Universal: Keeper of Creativity.
5. **Finale — Crown of Life**
   - The three treasures combine into the Light of Identity.
   - The castle/galaxy wakes, a rainbow train appears, a crown is formed, and a
     star uses the authenticated player's name when available.
   - Faith close names the Maker/Prince of Peace. Universal close preserves the
     same message of being known, valued, gifted, and purposeful.

## Playable structure

- New scene: `res://scenes/viewfinder/crown_of_life_story.tscn`.
- Runtime-built implementation:
  `res://scripts/viewfinder/crown_of_life_story.gd`.
- First-person `CharacterBody3D`; walking and gravity prevent free-flight puzzle
  bypasses.
- One sequential zone per chapter. Each contains:
  - a low-poly opt-in Cuttable source;
  - a missing bridge/door location;
  - an `Area3D` listening only for Cuttable fragment bodies;
  - a permanent safe bridge opened after a valid placement;
  - guardian and treasure feedback.
- Existing `lens_controller.gd` and cutter stack remain authoritative. Do not
  create a second cutting implementation.
- `F1` releases the mouse. A visible Return to Castle action must exist.

## Journey persistence

Extend `JourneyState.gd` with story-chapter evidence rather than inventing
thought, emotion, or artwork data the player did not create.

Suggested state:

```gdscript
var story_chapters := {
    "mind_spark": false,
    "heart_melody": false,
    "creators_light": false,
}
```

`record_story_chapter(id)` awards the corresponding existing treasure and a
truthful strength. It must save locally, migrate old saves safely, and clear in
`clear_journey()`. It must never upload personal text. The Lens remains optional
for the original journey's Crown gate; this new short story may naturally use
the Lens for its own three puzzles.

## Hub entry

- New runtime portal script:
  `res://scripts/viewfinder/crown_story_portal.gd`.
- Add one small `Node3D` to `New_Hub_World.tscn` near a safe player-accessible
  location.
- The portal must be visibly labelled “Crown of Life Adventure” and enter the
  new scene only when a `CharacterBody3D` enters.

## Safety and scope rules

- Preserve all unrelated dirty-worktree changes.
- Never make Terrain3D, ProtonScatter/MultiMesh, trains, rails, or the hub castle
  Cuttable.
- Use only simple low-poly story props on physics layer 4.
- Capture and cancellation remain reversible; `restore_world()` remains the
  exact authored-world recovery path.
- Do not upload thoughts or story answers.
- Do not use generative AI to diagnose, judge, or flatter a child.
- Faith mode is default; universal mode changes naming/register only, never
  progression or rewards.
- Do not commit, stash, reset, checkout, or push.

## Acceptance tests

Add `res://scripts/test_crown_story.gd`. It must use a scratch save path and
must not modify a real player's journey. Assert at minimum:

- new scene and hub portal target paths exist;
- scene creates a first-person player and exactly one Lens controller;
- three named chapter zones, Cuttable sources, and fragment goal areas exist;
- completing chapters in order records three story chapters and three existing
  treasures without fabricated mini-game entries;
- faith and universal guardian/finale text resolve appropriately while rewards
  stay identical;
- finale creates Crown, named Identity Star, Rainbow Galaxy Train, and the final
  message;
- return action points to `res://scenes/New_Hub_World.tscn`;
- `test_scene_paths.gd`, `test_journey_state.gd`, `test_crown_finale.gd`,
  `test_audience_mode.gd`, and all Lens suites continue to pass.

## Status

- [x] Existing ARTÉA journey, Lens implementation, reference video, and source
  studied.
- [x] Missing product gap identified: no single playable Lens-driven story
  chapter.
- [x] Architecture and acceptance criteria documented.
- [x] Claude implementation pass complete (Claude then reached its session
  limit; Codex continued from this document without losing scope).
- [x] Codex supervisor review complete.
- [x] Headless tests complete.
- [x] Visual playthrough/capture complete.
- [x] Second Claude pass: production UX (HUD, pause/restart/confirm/fall
  recovery, audio/accessibility settings, treasure transitions, finale
  replay/credits) implemented, tested headless, and re-captured. See the
  Final-product status checklist above and Evidence below.
- [x] Standalone `.pck` export and source-independent smoke test complete.
- [x] Universal macOS `.app`/`.zip` export, ad-hoc signing, archive round-trip,
  strict signature verification, and native ARM64 startup smoke test complete.

## Evidence and remaining work

### Files changed

- `artea/scripts/viewfinder/crown_of_life_story.gd` — new. Runtime-built
  scene: first-person `CharacterBody3D` player (own `Camera3D`, WASD + mouse
  look + jump), the existing `LensController`/`ViewfinderLens` attached to the
  camera (no second cutter), three sequential zones (`Zone_mind_spark`,
  `Zone_heart_melody`, `Zone_creators_light`) each with a Cuttable source prop,
  a fragment-only `Area3D` gap, and a bridge that appears on completion. Four
  physical floor islands create three real chasms; solid energy gates prevent
  jump/walk bypass and become non-solid only after the matching Lens placement.
  Raw Lens geometry replay is disabled in this scene because the existing
  placement file is shared across worlds; verified chapter and bridging state
  persists through `JourneyState` and safely rebuilds completed bridges.
  The world now has a dark procedural galaxy sky, emissive stars, a distant
  Artéa castle silhouette, Milo's model, and distinct Father/Knight/Mage
  guardian models. Mind Spark requires a thought reframe, Heart Melody requires
  six named emotions, and Creator's Light requires one ungraded creative
  choice before the shared Lens puzzle begins. It also includes fall recovery,
  checkpoint restart, objective/progress HUD, pause/confirm/settings panels,
  persistent audio/accessibility preferences, ambient/SFX playback, captions,
  large text, reduced motion, replay, credits, and a standalone-aware Exit
  Game action. Finale builds Crown, Identity Star, Rainbow Galaxy Train, and
  the faith/universal closing line.
- `artea/scenes/viewfinder/crown_of_life_story.tscn` — new. Single-node scene
  pointing at the script above (same convention as `lens_demo.tscn`).
- `artea/scripts/viewfinder/crown_story_portal.gd` — new. Runtime-built portal
  (glowing ring + `Label3D` "Crown of Life Adventure") near the castle plaza;
  `Area3D` triggers `change_scene_to_file` on any `CharacterBody3D` entry.
- `artea/scenes/New_Hub_World.tscn` — added one `ext_resource` and one bare
  `Node3D` (`CrownStoryPortal`) carrying the portal script, matching the
  existing `HubLens`/`CastleEntrance` pattern. No other scene edits.
- `artea/scripts/JourneyState.gd` — added `story_chapters` dict (`mind_spark`,
  `heart_melody`, `creators_light`), `STORY_CHAPTER_REWARDS` mapping each
  chapter to its existing treasure/strength, `record_story_chapter()`,
  `has_story_chapter()`, `story_chapters_complete()`. Wired into `save()`,
  `load_journey()` (migration-safe: missing field = not completed, not
  fabricated), and `clear_journey()`.
- `artea/scripts/test_crown_story.gd` — new acceptance suite, scratch save
  path `res://.godot/test_crown_story.json`.
- `artea/scripts/capture_crown_story.gd` — new visual-proof driver. It uses a
  scratch journey, disables LensPersistence, completes all three real Lens
  capture/place cycles, and writes the nine screenshots below. The final driver
  explicitly settles its gameplay frustum after detached beauty cameras so the
  complete Forward Mobile proof run is repeatable.
- `artea/export_presets.cfg` — added the selected-scene `Crown Story Pack`
  preset, macOS bundle ID `org.artea.crownoflife`, version 1.0.0, universal
  architecture, explicit Lens/model/audio dependencies, and release paths.
- `artea/project.godot` — added the `crown_story` main-scene feature override,
  replaced stale main-scene/API-manager UIDs with stable resource paths, and
  removed an invalid boot-splash UID.
- `artea/builds/Artea-Crown-of-Life-macOS.zip` — final 240 MB universal macOS
  distribution archive; contains the locally ad-hoc-signed `Artea.app`.
- `artea/builds/Artea.app` — extracted runnable local app used for the final
  native smoke test.
- `artea/builds/CrownOfLifeStory.pck` — 125 MB standalone Godot content pack.
- `artea/builds/SHA256SUMS.txt` — release checksums for the zip and content
  pack.
- `artea/artifacts/crown_story_01_prologue.png`
- `artea/artifacts/crown_story_02_mind_spark.png`
- `artea/artifacts/crown_story_03_pause_settings.png`
- `artea/artifacts/crown_story_04_heart_melody.png`
- `artea/artifacts/crown_story_05_creators_light.png`
- `artea/artifacts/crown_story_06_finale.png`
- `artea/artifacts/crown_story_00_world_overview.png`
- `artea/artifacts/crown_story_07_castle_destination.png`
- `artea/artifacts/crown_story_08_finale_hero.png`

### Professional visual polish (10 August 2026)

The same tested three-chapter world received a supervised professional art pass
without new mechanics or Cuttable categories. Islands now have textured rock
tops, narrow emissive edge rails, tapered textured undersides, and corner
crystals. Gates read as framed energy curtains; chasms and bridges have authored
trim. Mind, Heart, and Creator retain their mechanics but now have distinct
crystalline, musical, and studio-floor motifs. Sources and characters are staged
on pedestals/sigils with controlled local light. The existing castle gained a
textured facade, front-facing windows and door trim, battlements, and localized
lighting. The finale crown, identity star, detailed train, luminous path,
settings card, labels, post-processing, and capture compositions were refined.

Full implementation/validation/release details and the exact new checksums are
in `artea/docs/CROWN_OF_LIFE_PROFESSIONAL_POLISH_HANDOFF.txt`.

### Controls / entry

- Hub: walk to the glowing ring portal near the castle plaza
  (`Vector3(-30, 25.2, 20)` in hub-local space) labelled "Crown of Life
  Adventure" to enter.
- In the story scene: `WASD` move, mouse look, `Shift` run, `Space` jump,
  `E` perform the current discovery interaction, `1`/`2`/`3` select a creative
  light, `Q` raise/lower the Lens, click to take/place, `T` turn a held seeing,
  and `Esc` cancel a held seeing. `P` or `Esc` opens Pause when the Lens is not
  handling the key; `F1` frees the mouse. The integrated scene shows Return to
  Castle; the standalone build shows Exit Game.

### Tests / evidence

Run on 10 August 2026 with Godot 4.7.1 Mono:

```
Godot --headless --path artea --script res://scripts/test_crown_story.gd
# crown story: all checks passed

Godot --headless --path artea --script res://scripts/test_scene_paths.gd
# scene paths: all checks passed (171 scripts scanned)

Godot --headless --path artea --script res://scripts/test_journey_state.gd
# JourneyState: all checks passed

Godot --headless --path artea --script res://scripts/test_crown_finale.gd
# CROWN_FINALE_TEST: PASS

Godot --headless --path artea --script res://scripts/test_audience_mode.gd
# audience mode: all checks passed

bash artea/scripts/run_viewfinder_tests.sh
# all viewfinder tests passed (11 suites)

Godot --path artea --resolution 1280x720 \
  --script res://scripts/capture_crown_story.gd
# wrote nine images: complete world overview, prologue, Mind Spark,
# pause/settings, Heart Melody, Creator's Light, finale, castle destination,
# and finale hero composition

Godot --headless --main-pack artea/builds/CrownOfLifeStory.pck \
  --quit-after 180
# exit 0; no startup, script, or dependency errors

codesign --verify --deep --strict --verbose=4 artea/builds/Artea.app
# valid on disk; satisfies its Designated Requirement

artea/builds/Artea.app/Contents/MacOS/Artea --headless --quit-after 180
# exit 0; no startup, script, or dependency errors
```

Expected Firebase configuration notices and Godot shutdown ObjectDB/resource
warnings remain in several pre-existing headless suites. The native smoke test
also reports the existing forced-quit shutdown leak after 180 frames; there are
no startup, assertion, parser, dependency, or test failures. `git stash list`
is empty; neither Claude nor Codex created a stash, commit, branch, or push.

### Release-build note

The full ARTÉA project has nine application-shell autoloads. The Crown release
was exported from a temporary minimal-autoload snapshot containing only
`Global` and `JourneyState`, then the normal project autoload block was restored
before validation. This is required because the short game intentionally does
not ship Firebase, dialogue, login, loading-screen, or Creation World shell
systems. When rebuilding, repeat that isolation, export preset `Crown Story
Pack`, restore the normal autoloads, extract the app, and run:

```
codesign --force --deep --sign - Artea.app
```

Godot's hardened ad-hoc signature was structurally valid but macOS rejected it
at execution on this machine. Re-signing without hardened runtime produced the
verified local build. Public distribution outside local testing still requires
the project owner's Apple Developer identity and notarization; no credential
was available or assumed.

### Optional future polish (not required for the playable chapter)

- Replace runtime low-poly symbols with final commissioned ARTÉA environment
  art and animation while preserving node names, Cuttable layer isolation, and
  the tested progression contract.
- Add recorded voice acting and music for Milo and the three guardians.
- Do a child/facilitator playtest to tune the portal's exact plaza placement,
  text dwell time, contrast, motion comfort, and the 10–15 minute target.
