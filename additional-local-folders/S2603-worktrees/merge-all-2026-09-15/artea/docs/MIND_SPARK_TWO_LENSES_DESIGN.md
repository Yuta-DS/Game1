# Mind Spark Kingdom — The Two Lenses of Wisdom

Status: original ARTÉA first-world story, mechanic, architecture, and clean-room
reference record. This document is not a recreation of Split Fiction content.

## Crown of Life connection

The Crown of Life journey begins in the ARTÉA Castle Observatory. Three roads
are quiet, not broken. The first road listens for a person willing to notice a
thought without letting that thought define them. Milo calls the player the
Lightbearer and opens the route to Mind Spark Kingdom.

The kingdom contains the first Crown treasure, the **Star of Wisdom**. It can
only be discovered when two ways of seeing work together:

- the **Alarm Lens**, an advanced celestial-technology world that detects risk,
  patterns, uncertainty, and the effects of a difficult thought;
- the **Hope Lens**, a living nature-magic world that listens, grows grounded
  choices, connects support, and reveals a helpful next action.

Fear is not the villain. Hope does not silence it. Wisdom is the ability to hear
the alarm, check what it means, and choose what to do next.

## Reference research

Official EA material describes Split Fiction as a two-player split-screen game
where players coordinate actions and timing, receive changing abilities, and
move between science-fiction and fantasy settings. Its story follows two
contrasting writers who must cooperate inside their stories. ARTÉA borrows only
the high-level principles of complementary roles, readable simultaneous views,
mechanic-story cohesion, variety, and forgiving accessibility.

Official accessibility material documents per-player remapping and camera
settings, subtitles on both halves, camera-shake removal, focus dots,
alternatives to rapid/stick inputs, pause, and confirmed checkpoint skipping.
Those are product-quality reference principles, not proprietary game content.

The supplied PlayStation Planet walkthrough is 11:55:48, contains no uploaded
or automatic captions, and has no chapter metadata. A bounded visual sample was
therefore used instead of downloading or reproducing the full video:

- 00:12:10–00:13:50: simultaneous science-fiction traversal; each player has a
  complete camera and repeated subtitles while sharing the same broad route.
- 03:00:10–03:01:50: a nature/fantasy passage temporarily converges into a
  shared composition and uses a small contextual verb prompt.
- 06:00:10–06:01:50: two viewpoints show different immediate information and
  actions inside one encounter, including distinct interactable panels and a
  protective ability on one side.
- 10:00:10–10:01:50: a two-view encounter converges into a shared cinematic,
  then returns to split play when player agency resumes.

These observations support four original rules: each half must remain legible;
roles need different information and verbs; consequences must cross the seam;
and the presentation may briefly converge for a shared emotional payoff.

## Clean-room boundary

ARTÉA must not copy Split Fiction characters, plot, dialogue, simulation premise,
level order, environments, bosses, abilities, puzzles, UI, icons, camera
choreography, animation, music, footage, screenshots, or assets. No shipped
sequence may map directly to a reference-game sequence.

The Two Lenses uses original characters, emotional purpose, state machine,
puzzles, language, geometry, visual materials, and completion rules.

## Complete first-world story

### Arrival — The Divided Observatory

The Rainbow Galaxy Train stops at a crystal observatory suspended inside a
thought constellation. A deep signal passes through the building:

> “Something might go wrong.”

The observatory separates along a vertical seam. On the left, brass instruments
and luminous circuits accelerate as they calculate every possible danger. On
the right, roots, water, fireflies, and rune flowers close protectively around
their light.

Everlasting Father in the faith presentation—or the Keeper of Wisdom in the
universal presentation—explains:

> “An alarm can tell us to look. It does not have to decide the whole story.”

Two Lens avatars awaken. In local co-op, each player receives one. In solo mode,
the player chooses a Lens and explicitly pings the companion for the other role;
the companion never acts unpredictably or pretends to understand the player.

### Quest 1 — Hear the Alarm

The Alarm Lens scans a curated difficult Thought Echo. The player may select an
effect such as **louder**, **rushed**, **unclear**, or **not sure**. No choice is
marked wrong and no choice is treated as a diagnosis.

The scan reveals a circuit frequency across the seam. On the Hope side, the
same frequency becomes a dormant root pattern. This establishes the causal
rule: one Lens can reveal information that only the other can use.

Purpose: notice a difficult thought and describe its effect without calling it
true, false, good, bad, or part of the player's identity.

### Quest 2 — Grow a Grounded Next Step

The Hope Lens listens to the revealed root and chooses one believable response:

- “I can take one step.”
- “I can ask for help.”
- “I can pause and check.”
- “I do not have to know yet.”

A rune seed grows, but excess energy makes it unstable. The Alarm Lens uses its
scanner to stabilise the correct circuit band; the Hope Lens connects the seed
to the living path. Either player may act first. There is no countdown or
precision requirement.

Purpose: show that hope is not forced positivity. It is a truthful option that
can coexist with caution.

### Quest 3 — Build the First Star Bridge

Each Lens activates an anchor. Technology projects a constellation circuit;
nature-magic grows a vine around it. Only their combined structure can span the
gap. If one player is absent, an explicit companion ping completes the other
anchor after showing what the companion did.

Crossing the bridge transforms the original sentence:

> “Something might go wrong, **and I can pause, check, and take one step.**”

The alarm clause remains visible. It is integrated, not destroyed.

### Quest 4 — The Thought Storm

A second authored Echo appears:

> “I might not be able to do this.”

The roles exchange responsibilities. The former Hope player now operates the
Alarm Lens; the former Alarm player grows the Hope path. Role exchange ensures
both perspectives are understood rather than assigned to a fixed personality.

The second loop adds one remix: the Alarm Lens sees several possible signal
routes, while the Hope Lens can see which route reaches a support tree. Players
must communicate the overlap, activate both anchors, and integrate the second
thought. The puzzle is untimed and includes a progressive hint ladder.

Purpose: practise the full Notice → Check → Choose → Connect sequence with a
new thought and from the opposite role.

### Quest 5 — The Wisdom Constellation

The central border becomes a translucent constellation seam. Each side sees
three identical symbols expressed differently:

- Notice: scanner eye / opening flower
- Check: measuring prism / listening pool
- Choose: route switch / growing branch

Players activate the symbols in any order. Their two visual languages merge
into the Star of Wisdom. The camera briefly becomes one shared composition,
then returns control with the two halves still visible as equal parts of the
completed observatory.

The guardian says:

> “Wisdom did not erase the difficult thought. You listened, checked, and chose
> a way forward.”

The Star is awarded exactly once. It lights the Castle Observatory and opens
the route to Heart Melody Kingdom.

## Player roles and verbs

| Lens | Visual world | Knows | Can do | Cannot do alone |
| --- | --- | --- | --- | --- |
| Alarm | celestial technology, brass instruments, cyan circuits | signal pattern, uncertainty, possible effects | scan, classify, stabilise, route energy | choose a grounded response or grow a bridge |
| Hope | forest observatory, water, roots, gold-violet runes | support destination, living connection, response options | listen, choose, grow, connect | reveal hidden signal bands or stabilise energy |

Both roles receive complete visual feedback and meaningful agency. Neither is a
helper, villain, “negative person,” or “positive person.”

## Core state machine

```text
INTRO
  → PAIR_SELECTED
  → EFFECT_SCANNED
  → RESPONSE_CHOSEN
  → LEFT_ANCHOR_ACTIVE + RIGHT_ANCHOR_ACTIVE (either order)
  → BRIDGE_INTEGRATED
  → repeat for round two
  → CONSTELLATION_READY
  → CONSTELLATION_COMPLETE
  → STAR_REQUESTED
```

Unknown events, premature actions, duplicate actions, and invented IDs are
rejected without punishment. Completion requires exactly two fully integrated
authored rounds plus the constellation ritual.

## Split-screen presentation

- Two independent 3D SubViewports inside one adjustable vertical split.
- A central constellation seam displays shared progress with icons and words.
- Alarm side: deep navy, cyan, amber, brass, grid light and waveform animation.
- Hope side: forest teal, leaf green, violet, gold, roots, water and fireflies.
- Cross-screen actions use matched shape and sound motifs; colour is never the
  only communication channel.
- Internal render resolution is capped for mobile performance.
- One-side-at-a-time focus mode is available without changing puzzle state.

## Co-op and solo

Local co-op uses separate action maps for each Lens. Solo mode never simulates a
free-running second intelligence. The player presses Companion Ping after
completing their role; the other Lens demonstrates and performs its next valid
authored action. Role Swap is available at checkpoints and required once in the
story, with automatic control reminders.

## Safety and accessibility

- Authored thought/response cards only; no free text, LLM, classifier, camera,
  microphone, network request, diagnosis, or art analysis.
- Difficult thoughts are fictional encounter text. No forced disclosure.
- Neutral **A thought is here** and **Not sure** choices are always available.
- No combat, death, fall loss, score, shame language, countdown, rapid press,
  forced simultaneous input, or negative-answer sound.
- Unlimited retry; checkpoint after every integrated pair; confirmed skip back
  to the Castle without a treasure; companion assist; progressive hints.
- Per-half captions, text plus icons, high contrast, large text, reduced motion,
  camera-shake off, focus dots, independent audio, remappable inputs, and
  toggle/hold alternatives.

## Implementation acceptance

- The Castle Mind portal reaches the new split scene through the existing menu.
- Two independent perspectives render and accept distinct input policies.
- Every shared-state transition has a deterministic test.
- Solo companion and role swap cannot bypass prerequisites.
- JourneyState records only stable authored pair IDs/helpful text needed for the
  existing local completion contract.
- Star of Wisdom is impossible before both rounds and the final constellation.
- Skip, quit, replay, and scene entry never fabricate progress.
- The old cloud game remains a labelled legacy fallback during validation, then
  can be retired only after visual/performance QA.
- No source file or shipped asset contains copied reference-game expression.

## Primary sources

- EA, Split Fiction product features: https://www.ea.com/games/split-fiction/split-fiction
- EA, Split Fiction availability and story overview: https://www.ea.com/en/games/split-fiction/split-fiction/news/split-fiction-is-available-now
- EA accessibility guide: https://www.ea.com/able/resources/split-fiction/split-fiction
- PlayStation product and accessibility page: https://www.playstation.com/en-us/games/split-fiction/
- EA Side Stories overview: https://www.ea.com/games/split-fiction/split-fiction/news/an-introduction-to-side-stories
- Supplied walkthrough used for bounded orientation only: https://youtu.be/Bg4dUn-GtqQ
