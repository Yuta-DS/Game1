# ARTÉA — Connected Journey: Mechanics Design

How the four-stage narrative maps onto the game that actually exists.

## The core insight

Artéa already has every asset the journey needs. What it lacks is
**one variable that remembers**. Right now every experience is a
`change_scene_to_file()` that starts from zero and ends at a "Return to
Hubworld" button. Nothing the player does in Pop Thoughts is visible in
the Art Gallery. Nothing the Drawing Tool produces changes the Hub World.

The narrative document asks for a continuous journey. Mechanically that
means exactly one thing: **a persistent journey record that every scene
writes to and every scene reads from.** Everything else in this document
is a consequence of that.

Skip building new minigames. Rewire the ones already here.

---

## What exists today

| Piece | File | Role in the journey |
|---|---|---|
| Pop Thoughts | `scenes/popThoughtsMenu.tscn`, `scripts/cloud_pop_ui.gd`, `cloud.gd` | **Stage 1 — Thoughts.** Player types thoughts, clouds spawn, player pops them. |
| Music minigame | `scenes/music_minigame.tscn`, `scripts/music_minigame.gd` | **Stage 2 — Emotions.** Already takes an emotion word as input and generates sound + colour from it. |
| Drawing tool | `scenes/drawing_tool.tscn`, `scripts/drawing_tool.gd` | **Stage 3 — Creativity.** Full paint tool, saves local + uploads to server. |
| Art gallery 3D | `scenes/art_gallery_3d.tscn`, `scripts/art_gallery.gd` | **Stage 4 — Identity.** Displays the player's own uploaded work. |
| Hub World | `scenes/New_Hub_World.tscn` | The castle. Currently static. |
| Milo | `scenes/milo.tscn`, `milo_animations.gd` | The companion. Currently just an NPC in the hub. |
| Dialogue system | `scripts/GameManager.gd` + `dialogue/artea_park_dialogues.txt` | Custom `~node` / `-choice` / `do Command()` parser. Drives all NPC talk. |
| Global state | `scripts/Global.gd` | Autoload. Holds only auth/session. **This is where the journey record goes.** |

The mapping is nearly 1:1 with the narrative. That is not a coincidence —
the narrative was written for this game. The work is connective tissue,
not new content.

---

## The one thing to build: `JourneyState`

A new autoload — `scripts/JourneyState.gd` — sitting alongside `Global`.
It holds the player's journey and saves to `user://journey.json`.

```gdscript
extends Node

const SAVE_PATH := "user://journey.json"

# 0 = not started, 1 = thoughts, 2 = emotions, 3 = creativity, 4 = identity
var stage: int = 0

var thoughts: Array = []      # [{text, popped, emotion}]
var emotions: Array = []      # [{name, colour, visited}]
var creations: Array = []     # [{path, title, prompt_answered}]
var strengths: Array = []     # ["courage", "compassion", ...]

func record_thought(text: String) -> void:
    thoughts.append({"text": text, "popped": false, "emotion": ""})
    save()

func mark_popped(text: String) -> void:
    for t in thoughts:
        if t.text == text:
            t.popped = true
    _grant("courage")
    save()

func record_emotion(name: String, colour: Color) -> void:
    emotions.append({"name": name, "colour": colour.to_html(), "visited": true})
    _grant("emotional-awareness")
    save()

func record_creation(path: String, title: String) -> void:
    creations.append({"path": path, "title": title, "prompt_answered": false})
    _grant("creativity")
    save()

func _grant(s: String) -> void:
    if not strengths.has(s):
        strengths.append(s)

func advance_to(new_stage: int) -> void:
    stage = max(stage, new_stage)
    save()

func save() -> void:
    var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    f.store_string(JSON.stringify({
        "stage": stage, "thoughts": thoughts,
        "emotions": emotions, "creations": creations,
        "strengths": strengths,
    }))

func load_journey() -> void:
    if not FileAccess.file_exists(SAVE_PATH): return
    var d = JSON.parse_string(FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text())
    if d == null: return
    stage = d.get("stage", 0)
    thoughts = d.get("thoughts", [])
    emotions = d.get("emotions", [])
    creations = d.get("creations", [])
    strengths = d.get("strengths", [])

func _ready() -> void:
    load_journey()
```

Register in `project.godot` under `[autoload]`:
`JourneyState="*res://scripts/JourneyState.gd"`

That is the entire architecture. ~60 lines. Every mechanic below is a
handful of calls into this object.

**Why a separate file and not inside `Global.gd`?** `Global` is session
auth — cleared on logout. The journey is the player's, and must survive
logout. Different lifetime, different file.

---

## Stage 1 — Thoughts (Pop Thoughts, rewired)

**What changes in `cloud_pop_ui.gd`:**

The scene already does the hard part: text in → cloud out → click → pop.
Three changes turn it from a minigame into stage one of a journey.

1. **Remember the thought.** In `spawn_cloud()`, add
   `JourneyState.record_thought(text)`. In `cloud_popped()`, call
   `mark_popped()`. One line each.

2. **Don't just pop — pause first.** Currently clicking a cloud destroys it.
   Insert a beat: first click *pauses* the cloud (stops wandering, brings it
   forward, Milo asks *"When does this thought show up?"*). Second click
   releases it. The narrative's "witness, then understand, then befriend"
   is literally two clicks instead of one.

   In `cloud.gd`, `check_click()` becomes a two-state toggle:
   ```gdscript
   func check_click() -> void:
       if not paused:
           paused = true
           stop_wandering()
           _show_milo_prompt()   # "When does this thought show up?"
       else:
           pop()
   ```

3. **Rewrite the ending.** `cloud_pop_finish.gd` currently picks a random
   message from a list of 50 — the same message whether the player wrote one
   thought or twelve. Replace with a reflection built from what actually
   happened:

   > *"You looked at {n} thoughts today. The heaviest one was '{text}'.
   > You didn't run from it. That's courage."*

   The messages array becomes fallback for an empty journey, not the
   default path.

**Castle change:** on first completion, `JourneyState.advance_to(1)`. The
Hub World reads `stage >= 1` and lights the first corridor. Mechanically
this is a `Light3D.visible = true` and a `WorldEnvironment` ambient tween
in a hub script — cheap, and it's the single strongest signal in the whole
design that the player's actions moved the world.

---

## Stage 2 — Emotions (Music minigame, reframed)

`music_minigame.gd` already takes an emotion word, generates music from it,
and drives `BackgroundVisual` colour. That is 90% of the "emotion room."

**What changes:**

1. **Seed the input from Stage 1.** Instead of an empty
   `EmotionInput` field, prefill from the thoughts the player wrote:
   Milo asks *"When you looked at '{thought}', what did you feel in your
   body?"* The player answers. Now the emotion is attached to a specific
   thought, which is exactly the causal chain the narrative asks for
   (thought → feeling), and it costs one string lookup:

   ```gdscript
   var last = JourneyState.thoughts.filter(func(t): return t.emotion == "")
   if not last.is_empty():
       prompt_label.text = "When you thought \"%s\" — what did you feel?" % last[0].text
   ```

2. **The room is the background, not new geometry.** The narrative wants
   five colour-themed emotion rooms. Do not build five rooms. The minigame
   already tints `BackgroundVisual` and shifts audio per emotion — that
   *is* the room. Sadness turns it blue and slows the tempo; anger turns
   it red and hardens the drums. Same scene, five moods, zero new scenes.

3. **Emotion's message.** After generation, Milo names what the feeling is
   for — a dictionary lookup, not AI:
   ```gdscript
   const MESSAGES := {
       "sad": "Sadness means you cared about something. That's love, not weakness.",
       "angry": "Anger means something matters and needs protecting.",
       "afraid": "Fear means something is unknown. It's asking you to go carefully.",
       "lonely": "Loneliness means you need connection. Everyone feels this.",
       "happy": "Joy means something good is happening. Let it land.",
   }
   ```
   Fuzzy-match the player's word against keys; fall back to
   *"That feeling is real, and it belongs to you."*

4. **Record it.** `JourneyState.record_emotion(name, colour)` — the colour
   carries forward into Stage 3's palette.

**Castle change:** `stage >= 2` tints the Hub World with the emotions the
player generated. The `New_Hub_World.gdshader` already exists; feed it a
colour from `JourneyState.emotions`.

---

## Stage 3 — Creativity (Drawing tool, connected)

`drawing_tool.gd` is 640 lines and already complete: brushes, stamps, undo,
local save, server upload. Do not touch the drawing code.

**What changes:**

1. **The palette comes from the player's emotions.** `create_quick_color_palette()`
   currently builds a fixed palette. Build it from
   `JourneyState.emotions` instead, each swatch labelled with the feeling it
   came from. The player paints with colours they *earned* in Stage 2. This
   is the single highest-value change in the document — it's the moment the
   journey becomes visibly one thing rather than three.

2. **Milo asks one question after saving.** Not four — one, chosen by what
   the player has done:
   - Painted after an angry emotion → *"What did you need to let out?"*
   - Painted after sadness → *"What does this hold for you?"*
   - No emotion recorded → *"What part of you is in this?"*

   Answer is optional text. Store on the creation record. Silence is a
   valid answer and must not block the save.

3. **Record it.** `JourneyState.record_creation(path, title)` in
   `save_artwork_to_gallery()`.

**Castle change:** `stage >= 3` hangs the player's actual saved PNGs on the
Hub World walls. `PaintingArea.gd` and `ArtFrame.tscn` already exist for
exactly this — point their textures at `JourneyState.creations` paths.

---

## Stage 4 — Identity (Gallery, as ceremony)

The gallery scene becomes the final chapter rather than a separate feature.

1. **Walk the record.** Gallery displays creations (already does), plus the
   thoughts faced and emotions honoured, drawn from `JourneyState`.

2. **Milo names strengths from evidence.** No AI, no generic praise —
   `JourneyState.strengths` was populated by real actions, so each line
   cites the act that earned it:
   ```gdscript
   const EVIDENCE := {
       "courage": "You have courage — you looked at %d thoughts that scared you.",
       "emotional-awareness": "You have emotional awareness — you sat with %d feelings.",
       "creativity": "You have creativity — you made %d things that didn't exist before.",
   }
   ```
   Counts come from array sizes. This is what makes it land: the game can
   only say it because the player did it.

3. **The star.** The narrative's closing image. A point light + label with
   the player's name (`Global.current_user_name`, already populated by auth)
   in the night sky. `scenes/night.tscn` and `sun.tscn` already exist.

4. **Purpose.** One open question, one free-text answer, stored. No scoring,
   no branching. It's a keepsake, not a mechanic.

---

## What holds it together: Milo

Milo is currently `Milo_Animations2` sitting in the hub. Promote to
the constant companion — the dialogue system already supports it.

Add stage-gated nodes to `artea_park_dialogues.txt`, and one dispatcher
in `GameManager.gd`:

```gdscript
func request_milo() -> void:
    start_dialogue("milo_stage_%d" % JourneyState.stage)
```

Then `~milo_stage_0` through `~milo_stage_4` are just more dialogue nodes
in the existing text format. **No new dialogue code** — the parser in
`GameManager.gd` already handles nodes, choices, and `do` commands.

Milo's rule across all stages: never dismiss, never "cheer up," never
evaluate quality. Sit with, then name what was actually done.

---

## Build order

Each step is shippable on its own and leaves the game working.

| # | Step | Touches | Why first |
|---|---|---|---|
| 1 | `JourneyState.gd` + autoload | 2 files | Everything depends on it. Nothing visible yet. |
| 2 | Pop Thoughts records + personal ending | `cloud_pop_ui.gd`, `cloud.gd`, `cloud_pop_finish.gd` | Proves the loop end to end. |
| 3 | Hub reads `stage`, lights corridor | 1 hub script | First proof the world responds. Highest impact per line. |
| 4 | Music minigame seeds from thoughts, records emotion | `music_minigame.gd` | Links stage 1 → 2. |
| 5 | Drawing palette from emotions | `drawing_tool.gd` (~1 function) | Links stage 2 → 3. The moment it feels like one journey. |
| 6 | Gallery ceremony + strengths | `art_gallery.gd` | Payoff. |
| 7 | Milo stage dialogue | `artea_park_dialogues.txt`, `GameManager.gd` | Voice over the top. Text-only, no code risk. |

Steps 1–3 alone convert Artéa from a menu of minigames into a journey. If
only three get built, build those.

---

## Deliberately not built

- **Five separate emotion rooms.** The music minigame's background *is* the
  room. Five scenes to maintain for one tint each is cost with no gain.
- **Server sync of journey state.** `user://journey.json` is local and
  enough. The artwork upload path already exists for anything that needs to
  leave the machine. Add sync when there's a second device, not before.
- **AI-generated reflections.** `nobodywho` (local LLM) is in the project
  and tempting here. Don't. Dictionary lookups are instant, predictable,
  and safe. For a wellbeing app aimed at vulnerable users, an unpredictable
  generative response about someone's stated fear is a real risk, not a
  feature. Keep Milo scripted.
- **Blocking stage gates.** Track `stage` but don't lock scenes behind it.
  A player who wanders into painting first should still be met warmly; the
  journey deepens the experience, it shouldn't police it.
- **Editing the drawing/music tools' internals.** Both work. Touch only
  their inputs and outputs.

---

## One honest caution

This design records what a person writes about their own distressing
thoughts and saves it to disk. That's the right call — memory is the whole
point — but it needs three things before shipping:

1. **The player can delete their journey.** One button, no confirmation
   maze, wipes `user://journey.json`.
2. **Nothing in `thoughts` gets uploaded.** Artwork already uploads to the
   server; thought text must not follow it.
3. **The game is not a therapist.** If the app's audience includes people in
   real distress, a static "if you need to talk to someone" card with real
   crisis resources belongs in the pause menu — independent of the journey,
   and reachable at any stage.
