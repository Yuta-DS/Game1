# ARTÉA Crown of Life — Connected Journey Product Specification

**Product intent:** Deliver a complete, replayable adventure—not three isolated
mini-games. The Artéa Castle/Galaxy is the player's home, map, gallery, and
celebration space. Every discovery changes it visibly and culminates in the
player's own Crown of Life.

**Design promise:** Players discover strengths already within them. They never
repair something “wrong” about themselves, earn worth, or receive a judgement
of their feelings or artwork.

## 1. Canonical campaign

```text
ARTÉA Castle Galaxy (home / save / gallery)
  → Mind Spark Kingdom → Star of Wisdom
  → Heart Melody Kingdom → Harmony Jewel
  → Creator's Light Kingdom → Creator's Light
  → Castle Galaxy Awakening → Light of Identity → Crown of Life
```

- The Castle Galaxy is the single campaign home. It contains the observatory
  map, sky-isle rail, player gallery, facilitator settings, and finale hall.
- The journey is ordered **Mind → Heart → Creator**. A completed treasure
  illuminates the next portal and corresponding galaxy route; locked portals
  explain the next destination without shaming or obscuring content.
- Each kingdom returns to the Castle Galaxy, never a disconnected legacy hub.
  The short Lens-led story remains an optional guided introduction/replay, not
  a competing completion path that can award unearned mini-game records.
- A campaign router owns scene entry and return only. `JourneyState` remains
  the source of truth for real player actions, local save migration, treasure
  ownership, and completion. Route code must never fabricate thought, emotion,
  artwork, or reflection data to unlock a world.

## 2. Moment-to-moment experience

The common language is **science mixed with magic**: brass observatories,
constellation circuits, stained-light aether, friendly guardians, gallery
frames, music machinery, and an Art Castle that wakes as the player grows.
Each world follows the same dependable cadence:

1. **Arrival:** a strong landmark, an objective, and one guardian invitation.
2. **Learn one verb:** a 20–40 second safe interaction with clear visual
   feedback.
3. **Remix twice:** two authored, low-pressure challenges that combine the
   verb with traversal, rhythm, or composition.
4. **Restore:** an accessible quiet moment; retry, skip reflection, and pause
   are always available.
5. **Discover:** a treasure ceremony changes the Castle Galaxy immediately.

No world requires fast reflexes, performance quality, disclosure of personal
information, a “correct” feeling, or artistic skill. Difficulty changes puzzle
support and timing only; it never changes the story, reward, or dignity of the
player.

## 3. Kingdom mechanics

### Mind Spark Kingdom — *Thought Weave*

**Theme:** “I can notice my thoughts and choose a helpful next step.”

The crystalline observatory is filled with authored Thought Echoes: worries,
fears, self-doubt, dreams, and hopes. The player approaches an Echo, chooses a
curated response card, and uses a prism to weave a helpful Star Bridge.

- **Core verb:** Notice → explore → reframe. The player rotates a constellation
  prism to connect an Echo with one of several evidence/kindness/action cards.
  Every offered card is constructive; there is no punitive wrong answer.
- **Traversal expression:** a completed weave makes an authored star route
  visible. The existing Lens bridge language can carry a physical fragment
  across a real gap, but the journey must use Artéa's own geometry, props,
  timing, and wording.
- **Challenge progression:** one taught Echo; a two-Echo route where order
  matters; a calm observatory crossing with optional hints and unlimited undo.
- **Reward:** **Star of Wisdom**. It lights the Castle observatory, reveals the
  Heart rail on the galaxy map, and records only that the authored encounter
  was completed—not a diagnosis or claim about the player.
- **Guardian voice:** Faith register: Everlasting Father; inclusive register:
  Keeper of Wisdom. Both affirm that noticing and choosing hope are strengths.

### Heart Melody Kingdom — *Duet Garden*

**Theme:** “My feelings have a voice.”

The resonance garden turns player-selected emotion cues into colour, pulse,
and musical motifs. Feelings are invitations to express, not states the game
tries to infer.

- **Core verb:** Listen → answer → layer. The player chooses an emotion card
  (Joy, Sadness, Frustration, Fear, Peace, or Hope), listens to its short motif,
  then places or taps a complementary light-note on a visible beat grid.
- **Duet system:** in solo play, the companion/playhead takes the other role;
  in supported local co-play, players may alternate Listener and Composer.
  Role exchange is playful coordination, never a requirement for two people.
- **Challenge progression:** match one pulse; layer two contrasting emotions
  into a route; conduct a six-colour garden sequence that opens a harmonic
  bridge. Tempo assist, visual beat markers, mute-readable feedback, retry,
  and free exploration are mandatory.
- **Reward:** **Harmony Jewel**. It energises the Castle's galaxy rail and
  activates the route to Creator's Light. Completion records the selected,
  authored encounter and never asserts what the player is “really” feeling.
- **Guardian voice:** Faith register: Archangel Raphael; inclusive register:
  Keeper of Healing. Both acknowledge that feelings can be heard and held.

### Creator's Light Kingdom — *Gallery Frame Ritual*

**Theme:** “I was created to create.”

The art-forge/atelier turns a player-made mark, collage, or chosen creative
prompt into a luminous gallery tile that can awaken an authored micro-scene.

- **Core verb:** Make → frame → share (optionally). The player draws, arranges
  stamps, or selects an accessible creative composition; then places the
  resulting light tile in a known gallery frame to reveal an authored door,
  bridge, or constellation mural.
- **Spatial expression:** frames reveal prepared Artéa spaces and use
  deterministic preview/placement/undo. They do **not** copy a photograph into
  3D, recreate another game's perspective mechanic, or ask a model to analyse
  the player's art.
- **Challenge progression:** make a first light mark; choose and frame one of
  several authored scenes; arrange a small personal gallery before a final
  portal. Every composition succeeds; variation changes colour, ornament, and
  displayed gallery art, never access to the finale.
- **Reward:** **Creator's Light**. It lights the Castle gallery, preserves an
  opted-in local creation according to device policy, and begins the finale.
- **Guardian voice:** Faith register: Uriel, Keeper of Creativity; inclusive
  register: Keeper of Creativity. Both celebrate the player's chosen meaning,
  not an automated interpretation of their work.

## 4. Progression, rewards, and finale

| Beat | Player outcome | Castle/Galaxy change |
| --- | --- | --- |
| Arrival | Chooses a save-safe journey and accessibility options | Observatory map introduces three distant landmarks |
| Mind complete | Star of Wisdom; Wisdom strength marker | Star chart and Heart rail illuminate |
| Heart complete | Harmony Jewel; connection/emotional-expression marker | Harmonic rail, garden soundscape, Creator route illuminate |
| Creator complete | Creator's Light; creativity marker and optional local artwork | Gallery wakes; finale threshold opens |
| Finale | Light of Identity and Crown of Life | Castle, art gallery, galaxies, rail, named/anonymous star celebration awaken |

The finale is a five-minute, player-controlled ceremony:

1. The three treasures enter the castle observatory and become the **Light of
   Identity**.
2. The player's opted-in artwork, chosen colours, and real completion memories
   appear in the gallery; no generated personality summary is shown.
3. The **Rainbow Galaxy Train** gives a readable celebratory ride through all
   three transformed worlds, with skip and reduce-motion alternatives.
4. At the Crown hall, the Maker/Prince of Peace (faith) or a neutral Artéa
   celebrant (inclusive) shapes the Crown of Life.
5. A star appears with a locally supplied display name only when enabled;
   otherwise it is simply “Your Star.” The closing message communicates being
   known, valued, gifted, and purposeful in the selected audience register.

Replay may reset adventure progress only after confirmation. It must preserve
the chosen audience/accessibility configuration and never delete saved artwork
without a separate, explicit local deletion action.

## 5. Faith and inclusive audience parity

ARTÉA's Christian foundation is authentic in the **faith register**. An
**inclusive register** makes the same emotional-safety and purpose-oriented
experience appropriate for schools, community programmes, and private
facilitation.

- The selected register changes approved names, dialogue, symbols, and closing
  language—not route order, puzzles, difficulty, unlocks, rewards, controls,
  features, or access to artwork.
- A facilitator/adult selects the register before a new journey; it is visible
  in settings and can be changed only through a deliberate configuration flow.
- Every on-screen and spoken line is authored as a faith/inclusive pair. If an
  inclusive variant is unavailable, the product must use a reviewed neutral
  fallback, **never silently show faith-specific language**.
- Guardians must not claim divine certainty about a player's future, diagnose
  them, rank their faith, or promise an outcome. Safe language observes the
  game action: “You chose a bright light. What does it mean to you?”

## 6. Curated, offline reflection safeguards

Reflection is a prompt for self-expression, not an AI assessment feature.
The default child/school/community configuration is **curated offline
reflection**:

- Present fixed, skippable choice cards and optional non-persistent art-making;
  do not show free-text chat, a model prompt, emotion classifier, vision
  analysis, network request, or automatic art/colour/personality conclusion.
- Responses come only from a locally bundled, reviewable catalogue keyed by
  chapter, player-selected card, and audience register. They never claim to
  know the child's emotions, strengths, identity, purpose, or spiritual state.
- Progress never depends on revealing personal information, selecting a
  reflection, saving artwork, entering a name, or sharing a creation.
- Local creations and display names are off by default where policy requires;
  when enabled, they remain on the device unless a verified adult chooses an
  explicit export/share flow. Do not embed API credentials in the client.
- A quiet “pause / take a break / talk to a trusted adult” route is available
  from every reflection surface. It offers support without crisis labelling,
  surveillance, or behavioural profiling.
- Any future connected AI service is a separate, adult-mediated product scope
  with data-protection assessment, content review, opt-in consent, retention
  controls, and a release gate. It is not required for this game to ship.

## 7. Originality and intellectual-property boundary

The cited games are reference points for **high-level design lessons** only:
varied mechanics and collaborative surprise; story-mechanic cohesion; and
perception-led spatial discovery. ARTÉA must be recognisably its own game.

Never copy or closely imitate reference games' characters, names, plots,
dialogue, worlds, level layouts, puzzle solutions, UI, camera language,
animation, music, audio, screenshots, video frames, or assets. Do not train
on, distribute, or ship downloaded video/source material. The product uses
original terminology (Thought Weave, Duet Garden, Gallery Frame Ritual),
original traversal layouts, original art/audio, and an internal provenance
ledger for every external asset or commissioned contribution. Before commercial
release, an IP/content reviewer signs off on the ledger and on a captured
playthrough of all three kingdoms.

### Reference research record

- [Split Fiction — official EA page](https://www.ea.com/games/split-fiction/split-fiction): varied co-operative timing and changing verbs informed the cadence of Thought Weave, not its expression.
- [It Takes Two — official features](https://www.ea.com/en/games/it-takes-two/it-takes-two/features): distinct but connected roles informed Duet Garden's Listener/Composer structure.
- [Viewfinder — official PlayStation page](https://www.playstation.com/en-us/games/viewfinder/) and its [developer discussion of Rewind](https://blog.playstation.com/2023/06/08/create-destroy-and-rewind-in-viewfinder-out-july-18-play-the-demo-today/): experimentation with reliable undo informed Gallery Frame Ritual.
- Supplied walkthrough references: [Split Fiction](https://youtu.be/Bg4dUn-GtqQ), [It Takes Two playlist](https://youtube.com/playlist?list=PL1Z5R01i_5U_op8v22UmoeQA96DGjF0Ik), and [Viewfinder playlist](https://youtube.com/playlist?list=PLAIcZs9N4171Htq-ep2nLC-ZwqtUgibk7). They were used only as orientation; the supplied Split walkthrough did not expose usable captions in the current research environment.
- [Australian copyright basics](https://www.ag.gov.au/rights-and-protections/copyright/copyright-basics) supports the distinction between high-level ideas and protected expression. This is product guidance, not legal advice.

## 8. Release slices

### Slice A — Campaign foundation

- Establish one Castle Galaxy home, deterministic route/return ownership,
  visible portal states, migration-safe local save state, checkpoints, pause,
  and audience configuration.
- **Accept when:** Mind is reachable from a fresh save; Heart/Creator are
  visibly locked; returning from Mind preserves its real reward and unlocks
  Heart; no legacy exit bypasses the campaign.

### Slice B — Mind Spark production world

- Deliver Thought Weave, original observatory art/audio, authored response
  catalogue, supported Lens/traversal crossing, Star ceremony, and accessibility
  support.
- **Accept when:** every authored route is completable with keyboard/mouse,
  controller, captions, muted audio, reduced motion, hint, retry, and no
  reflection choice; the player cannot bypass or become trapped at the bridge.

### Slice C — Heart Melody production world

- Deliver Duet Garden, six readable emotion motifs, solo/co-play parity,
  visual rhythm support, Harmony ceremony, and safe return.
- **Accept when:** rhythm timing never blocks completion at assisted setting;
  all emotion choices are treated equally; no system infers or labels the
  player's emotional state.

### Slice D — Creator's Light production world

- Deliver Gallery Frame Ritual, creation save/export policy, authored frame
  scenes, undo, Creator ceremony, and local gallery display.
- **Accept when:** every creation route reaches the reward without a quality
  score, model inference, network access, or need to share/save an artwork.

### Slice E — Castle Galaxy finale and release candidate

- Deliver the awakened castle, gallery, train ride, Crown ceremony, credits,
  replay, settings, evidence capture, and signed platform builds.
- **Accept when:** all three real treasures are required; finale works with and
  without a display name/artwork; the faith/inclusive builds have identical
  game-state outcomes; a fresh-install and resumed-save playthrough both pass.

## 9. Ship gate

The product is ready for external delivery only when it satisfies all of the
following:

- A 45–75 minute first journey and a shorter guided replay both have complete
  beginning, three distinct worlds, return loops, finale, credits, and recovery
  from interruption/fall/quit.
- Save/load, migration, replay, chapter order, locked-portal copy, treasure
  ownership, and finale eligibility are automated-tested against scratch data.
- Every game surface passes accessibility review: readable text, remappable or
  documented controls, subtitles, mute readability, colour-independent cues,
  reduce-motion setting, pause/exit confirmation, and no forced disclosure.
- Faith/inclusive parity tests compare every chapter, guardian, reflection,
  completion, and finale path; only approved presentation text/symbols differ.
- Source review confirms child/school paths have no reachable HTTP request,
  free-text chatbot, generative analysis, secret, analytics identifier, or
  unapproved external asset. Offline reflection tests cover skip, no-save, and
  neutral fallback cases.
- Native target builds are smoke-tested from packaged artifacts, verified for
  valid licences/provenance, visual quality, performance budget, crash-free
  playthrough, local data behaviour, and platform signing/notarisation as
  applicable.

## 10. Production telemetry (local, non-identifying)

For quality assurance builds only, use aggregate local event counters such as
chapter entered/completed, hint requested, accessibility option enabled, and
crash recovery. Do not collect reflection text, artwork, names, emotion
choices, guardian dialogue, device identifiers, or behavioural profiles. Any
analytics beyond this specification requires a separate privacy review and
explicit product-owner approval.
