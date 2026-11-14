# Artéa HUD visual supervision brief

## Subject and job

Artéa is a third-person art adventure for young creators exploring a castle
galaxy and worlds reconstructed from their own paintings. The HUD has one job:
keep the fantasy unobstructed while making the next creative action obvious.

## Evidence from the supplied screenshots

- The persistent `Need help / My journey / Setup` strip occupies the same
  bottom-right space in every scene, competes with navigation, and looks like a
  desktop settings bar rather than part of Artéa. Remove the autoload that
  creates this feature; do not merely hide it behind another permanent button.
- The strongest views are the fox silhouetted against the castle, the cyan-lit
  stairs, and the floating-island vistas. UI should frame those views, not cover
  them.
- Creation-world UI currently uses unrelated default buttons and unbacked pale
  text. It loses contrast against both the pink artwork world and the bright
  castle.
- The long bottom instruction sentence is hard to scan during play. Controls
  should be concise, contextual, and separated from generation/error status.
- `ISLAND STATES ...` is developer information visible in ordinary debug play.
  It should be opt-in rather than part of the player presentation.

## Design system: Artist's field journal

### Palette

- **Ink glass** `#171A2B` — translucent plaque/button backing.
- **Parchment light** `#FFF2C7` — primary type and warm borders.
- **Lens cyan** `#67E8F9` — interaction and focus accent.
- **Creator coral** `#FF8066` — creative actions.
- **Castle blue** `#7698FF` — secondary focus and gallery action.
- **Quiet mist** `#D9E2FF` — secondary copy.

The current artwork palette may tint accents, but text contrast must remain
stable. Avoid solid black bars and grey default Godot buttons.

### Type

- Display/world title: `res://assets/Fonts/NewFont-Artea.otf`.
- Controls and compact utility copy: `res://assets/Fonts/Cloud_finish_BOLD.ttf`.
- No system-style settings typography in the gameplay view.

### Layout

```text
┌─ artwork plaque ───────────────┐               ┌ creative actions ┐
│ WORLD TITLE                    │               │ Add  Draw  Gallery│
│ a world made from your art     │               └──────────────────┘
└────────────────────────────────┘

                            subtle reticle

                   ┌ contextual status / prompt ┐
                   └──────────────────────────────┘
```

- Safe margins: 20–24 px at desktop resolution.
- Minimum action target: 44 px high.
- Bottom prompt is centred and never competes with a bottom-right utility row.
- Panels use 12–16 px corners, a restrained 1–2 px warm border, and translucent
  ink-glass fill. One coherent family, not a mix of default controls.
- Idea/sketch modals use the same visual family and readable internal padding.

### Signature

The memorable element is a slim artwork-colour accent along the title plaque
and creative-action group: the HUD feels cut from the current painting while
the ink-glass body keeps it legible in every world.

## Required implementation scope

1. Remove the `JourneySafeguards` autoload so `Need help`, `My journey`, and
   `Setup` are not created in gameplay.
2. Redesign only the creation-world HUD and its idea/sketch panels using the
   system above. Preserve all actions and shortcuts.
3. Make island-state debug UI opt-in through a false-by-default project setting.
4. Add a focused headless test proving the removed strip stays absent, the new
   HUD has named/styled components and accessible target sizes, and debug UI is
   absent by default.
5. Do not modify world geometry, controls, AI generation, persistence, API
   configuration, or unrelated dirty files.

## Acceptance criteria

- No `Need help`, `My journey`, or `Setup` buttons exist at runtime.
- Artwork title, actions, reticle, status, and interaction prompt remain usable.
- HUD works at the project's 1710×1112 viewport and under canvas stretch.
- Buttons are at least 44 px high; pale text always has a dark translucent
  backing where it carries gameplay meaning.
- Keyboard actions `M`, `D`, `E`, and `Q` remain unchanged.
- Existing creation-world and castle/viewfinder tests still pass.

## Implementation notes

Claude Code implemented the bounded HUD pass in `project.godot`,
`scripts/hub_sky_isles.gd`, `scripts/creation_world/creation_world.gd`,
`scripts/ui/artea_hud_theme.gd`, and `scripts/test_hud_presentation.gd` under
the supervisor's file restrictions. Its first test version preloaded
`creation_world.gd` as a top-level `const`, forcing Godot to compile it before
autoloads exist under `--script` headless runs and tripping on the bare
`CreationWorldState` identifier. Claude changed that test to a lazy `load()`
inside `_test_creation_hud()`, matching the established project test pattern.
The supervisor then reviewed the actual files and reran validation independently.

Headless run: `godot --headless --script res://scripts/test_hud_presentation.gd`
→ `HUD presentation: all checks passed`. Also reran `test_creation_world.gd`,
`test_viewfinder_lens.gd`, and `test_hub_lens.gd` — all pass. Left
`scripts/JourneySafeguards.gd` on disk per scope (autoload entry already
absent from `project.godot`; nothing instantiates the script).

The supervisor's live Metal-rendered Frame 09 capture exposed one issue that
the structural test could not: the lens controller's idle `Q` reminder sat
behind the new controls plaque. `LensController` now exposes
`show_idle_hint`; the creation world disables only that duplicate idle line
while retaining the contextual raised/holding instructions. A regression
assertion was added to `test_hud_presentation.gd`. The final player-view
reference is `res://artifacts/frame09_creation_hud.png`, produced with
`capture_frame09_world.gd -- --hud`.

Final validation: focused HUD test, lens-controller test, creation-world test,
journey UI test, and the complete `run_viewfinder_tests.sh` suite all pass.
