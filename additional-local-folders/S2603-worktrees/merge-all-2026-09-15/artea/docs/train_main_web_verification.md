# Train banner / main / Web verification — 2026-08-29

## Outcome

**The standalone banner passes Web verification. Full-game compatibility with
latest main is blocked, not passed.** No product code, conflict resolution,
branch commit, push or production deployment was made during this test run.

## Git state and merge check

- Current branch: `David/train-linkage-design`, committed tip `0c1ce1a0`.
- Successfully fetched GitLab main: `07ae0c3aa95df679b4f9836706f3a3927dec8765`.
- Divergence: 30 branch-only commits and 28 main-only commits.
- Ran `rtk git merge-tree --write-tree --name-only HEAD origin/main`.
- Exit 1: five conflicted files. This checks committed tips without changing
  the working checkout or index; it does **not** integrate the many local
  uncommitted/untracked edits, which may have additional conflicts.

Conflicts:

1. `artea/assets3D/houses/red/hexagons_medieval.png.import` — deleted in branch,
   modified in main.
2. `artea/scenes/New_Hub_World.tscn` — content conflict.
3. `artea/scenes/stylizedsky.gdshader` — content conflict.
4. `artea/scripts/Water.tscn` — modified in branch, deleted in main.
5. `artea/scripts/web_terrain_compat.gd` — content conflict.

Evidence: `artifacts/train_main_merge_check.txt`. The merge-check tree is not a
usable combined game build. The current checkout and its uncommitted edits were
left intact. Resolving these conflicts is a separate implementation step.

## Banner compatibility evidence

`git diff origin/main` is empty for the banner's existing shared dependencies:
`artea/scripts/ui/artea_hud_theme.gd`, `NewFont-Artea.otf` and
`Cloud_finish_BOLD.ttf`. The new banner itself is untracked locally and is not
present in main. Its arrival/passenger controller integration remains missing.

- Current isolated headless UI suite: **43 passed, 0 failed**.
- Export: **PASS**, standard non-Mono Godot 4.7.1, Web release, single-threaded,
  Compatibility renderer, no GDExtension dependency. No export errors/warnings.
- Browser: **PASS for the standalone UI**, real Chromium WebGL2 renderer.
- Checked visible pearl/gold frame and bundled game fonts, arrival layout,
  mouse Next station → travel strip, locked station disabled/no signal,
  Get off → closed banner, and Tab then Enter → continue signal.
- Final browser error/warning log was empty. The optional browser favicon
  request received a 404; no game asset or runtime failure resulted.

The harness uses main's 1710×1112 design viewport, `canvas_items` stretch,
`expand` aspect, and `gl_compatibility` renderer. Its mode-switch buttons do not
take focus away from the banner under test. The game component was not changed.

Commands from `artea`:

```sh
rtk /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --headless --path artifacts/celestial_banner_preview --script res://scripts/test_train_celestial_banner.gd
rtk /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --headless --path artifacts/celestial_banner_preview --export-release Web web/index.html
rtk python3 -m http.server 8774 --bind 127.0.0.1 --directory /Users/davidsovann/S2603/artea/artifacts/celestial_banner_preview/web
```

Local preview: <http://127.0.0.1:8774/>. This serves only the isolated exported
preview directory, not the repository or existing production build directory.

Evidence logs:

- `artifacts/test_train_banner_main_web_headless.log`
- `artifacts/test_train_banner_web_export.log`
- `artifacts/train_banner_web_browser_logs.txt`

## Not verified / blocked

No merged full-game build exists for this test. Therefore full-game train,
gallery, minimap, seating, driving and station regressions against main, the
maintained full-game Web export, and production browser verification were not
run or claimed. The full-game build would also need the missing passenger
controller restored/integrated. Existing `builds/web` outputs were not touched.
