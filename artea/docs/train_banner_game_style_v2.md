# Crown Line banner — Artéa game-style pass

## Current colour revision — previous palette restored

User preference: keep the previous pearl/cream and warm-gold colours instead of
the dark/violet palette below. This is a presentation-only patch: the new frame
geometry, game display/utility fonts, layout and input behaviour are unchanged.

Palette: pearl `#FFF9EB`, pale ice `#E9F0EE`, champagne `#E8CA80`, gold
`#C89E48`, burnished gold `#92651E`, ink `#243C50`. The snowflake remains the
signature, now gold on pearl; crystals and seven equal inlays use softened
pastels. Keep dark text and a dark focus outline for contrast on light surfaces.
This explicitly follows the preferred original palette rather than adding new
decoration. The original game-style plan below is retained as design history.

Verification: **43 headless checks passed; 46 native/render checks passed;
zero failures**. Desktop and mobile locked-route screenshots inspected. Logs:
`artifacts/test_train_banner_pearl.log` and
`artifacts/test_train_banner_pearl.native.log`. Latest captures are in the same
preview directory; the previous dark desktop/context previews are preserved in
the Codex visualizations directory. No live integration, deployment, commit or
push occurred; the existing missing-passenger-implementation limitation remains.

## Before building

Subject: a passenger station-choice sign, for players already seated on the
rainbow crystal train. Keep the same two choices and station data contract.

References inspected: `artifacts/crown_line_player_riding_passenger.png`, the
saved Mind Spark passenger-arrival screenshot, and `scripts/ui/artea_hud_theme.gd`.
The game's material language is faceted crystal, broad gold structural trim,
violet roof beams, cyan glass and segmented rainbow inlays. Its HUD uses ink
glass, parchment lettering and its own bundled display/utility fonts.

Palette: shared ink glass `#171A2B`, parchment `#FFF2C7`, lens cyan `#67E8F9`,
roof violet `#AE6AF2`, highlighted gold `#FFDD78`, shaded gold `#926326`.
Seven equal-width coloured inserts form a small rainbow accent; they do not
compete with reading the station name or the two actions.

Type: use Artéa's existing `NewFont-Artea.otf` for the station name and its
`Cloud_finish_BOLD.ttf` for body/buttons, through the shared HUD kit. Do not add
another font or depend on a system font.

Layout: a suspended carriage sign with a crystal snowflake at the centre of a
violet-and-gold roof-like beam; side brackets support a dark enamel face. Station
name, short question, next-stop inset and two buttons sit inside a calm safe area.
Keep decoration outside that area. Stack controls on narrow screens and retain
focus-following scroll on short ones.

Signature: translate the train's six-point crystal snowflake and gold/roof-rail
construction into the frame itself, rather than attaching a generic medallion.
All ornament is connected to a beam or bracket. No flowers, random floating
baubles or flashing gradients.

Critique: the previous cream plaque and serif face read as stationery instead
of this colourful game. This revision uses the actual HUD fonts and ink-glass
palette, with dimensional rails, bevelled gold and faceted crystalline details
directly referenced from the train. The text area remains restrained.

## Scope

This is still the independent UI component/preview. The old passenger controller
was in the deleted temporary worktree. No current railway, camera, gameplay,
deployment settings or story behavior are changed. An in-context render uses a
saved gameplay screenshot behind actual Godot controls, labelled as a preview;
it is not a claim that the banner has been connected to live gameplay.

## Render review and verification — 2026-08-29

The native Godot render was checked on the standalone backdrop, a labelled saved
train background, a 360px-wide locked-route view, and the compact journey strip.
The gold bevels, violet lintel and cyan snowflake now repeat the train materials;
the actual Artéa display font replaces the unrelated serif. Both actions have
56px targets and visible cyan keyboard focus. Text stays separate from the
decorative geometry. All seven rainbow inserts have equal segment widths.

- Headless isolated UI suite: **42 checks passed, 0 failed**.
- Native OpenGL Compatibility UI/capture suite: **47 checks passed, 0 failed**.
- Includes mouse clicks, Tab/Enter, signal counts, disabled-route behaviour,
  shared font/palette checks, 320/360/1920px layouts, focus-following scrolling
  in a 640×320 window, and compact travel-strip bounds/input behaviour.
- No script/runtime errors or warnings in either final test log.
- No train, seating, driving, station logic, camera, or shared HUD theme changed.

Commands (from the Artéa project directory):

```sh
rtk /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --headless --path artifacts/celestial_banner_preview --script res://scripts/test_train_celestial_banner.gd
rtk /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --path artifacts/celestial_banner_preview --script res://scripts/test_train_celestial_banner.gd -- --capture --backdrop=/Users/davidsovann/S2603/artea/artifacts/crown_line_player_riding_passenger.png
```

The preview project links the three component/test scripts, shared HUD theme,
and two game fonts. It does not load game autoloads or alter world state.

Evidence: `artifacts/test_train_banner_game_style.log`,
`artifacts/test_train_banner_game_style.native.log` and
`artifacts/celestial_banner_preview/game_style_banner_{desktop,context,mobile_locked,travel}.png`.

No full-game regression, Web export, production deployment or browser gameplay
verification is claimed. That delivery loop remains blocked by the missing
passenger implementation; these checks verify the UI component only.
No commit or push was made.
