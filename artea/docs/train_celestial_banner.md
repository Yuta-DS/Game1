# Crown Line celestial banner

> Historical first design, superseded by [the Artéa game-style pass](train_banner_game_style_v2.md).
> The current component uses Artéa's shared HUD fonts and crystal/gold frame,
> not the cream palette and added fonts described below. The old assets remain
> untouched; the current component no longer references them.

## Design plan

Subject: the Crown Line's passenger arrival choice. Its only job is to show
where the player has arrived and let them get off or keep riding.

Palette: pearl `#FFF9EB`, ice `#E9F0EE`, champagne `#E8CA80`, burnished gold
`#92651E`, ink `#243C50`, twilight `#101E38`.
Typography: Cormorant Garamond semibold for station names; Nunito Sans for
instructions, controls and captions. Fonts are bundled locally with their OFL
licenses, with no runtime font download or system-font dependency.

Layout: a compact central arrival plaque with a crest, station name, journey
instruction, next-stop inset, two explicit choices and a quiet waiting note.
Buttons stack on narrow screens; short windows scroll and follow keyboard focus.

Signature: the train's six-point roof snowflake becomes a raised pearl-and-gold
seal, connected to the frame by two fine sweeping inlays. Chamfered, double-inlaid
gold edges give the panel a crafted jewellery finish. Decorative geometry never
intercepts pointer input. No pulsing/flashing animation is necessary.

Critique: a plain cream rounded card and serif headline would be generic. The
snowflake seal, connected gold scrollwork and bevelled plaque make this specific
to the user's snowflake-roof train. Avoid extra crowns, flowers or busy ornaments
inside the reading area. Preserve clear labels, dark text and keyboard focus.

## Integration status

This is a reusable, previewable Godot UI component, NOT a restored train build.
The former `/private/tmp/S2603-train-rainbow` worktree and its passenger journey
implementation are no longer present. The current saved checkout has older,
independently modified train code. It was deliberately not overwritten.

`scripts/train_passenger_journey_ui.gd` keeps the previous component interface:

- Signals: `get_off_requested`, `continue_requested`.
- Methods: `show_arrival(station, next_station, locked_reason)`,
  `show_travel(destination, zero_based_coach)`, `close_journey()`.

The railway must still own seating, travel, locks, safe disembarking and temporary
camera-input release. Restoring that missing implementation is required before
connecting this banner to actual gameplay. No commits, pushes or production
deployment are part of this preview.

Font sources:

- [Cormorant Garamond](https://github.com/google/fonts/tree/main/ofl/cormorantgaramond)
- [Nunito Sans](https://github.com/google/fonts/tree/main/ofl/nunitosans)

## Verification — 2026-08-29

- Standalone headless UI test: **40 checks passed, 0 failed**.
- Native OpenGL Compatibility UI test/capture: **43 checks passed, 0 failed**.
- Desktop, narrow, locked-route and travelling states rendered and inspected.
- The tests exercise mouse clicks, Tab/Enter, exact emitted signals, disabled
  actions, genuine font-weight coordinates, responsive bounds, short-window
  focus scrolling and hidden-state cleanup. No gameplay claims are inferred
  from these UI tests.
- No script errors or runtime warnings in the isolated preview runs.

The native preview project is `artifacts/celestial_banner_preview`. It references
the new component and fonts directly, without loading or modifying existing
gameplay/autoloads. Preview command after its import:

```sh
rtk /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --path artifacts/celestial_banner_preview --script res://scripts/test_train_celestial_banner.gd -- --capture
```

Evidence: `artifacts/test_train_celestial_banner.log`,
`artifacts/test_train_celestial_banner.native.log`, and PNGs in the preview
directory. During integration/export, include both accompanying font OFL text
files in the packaged font licenses. Integer OpenType tags follow the
[Godot FontVariation API](https://docs.godotengine.org/en/stable/classes/class_fontvariation.html)
and are checked against the actual rendered font coordinates.

There is no production deployment ID or Web verification for this preview.
The missing passenger controller must be restored/selected before wiring the UI,
running full gameplay regressions, exporting the complete game or deploying it.
