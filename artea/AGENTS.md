# Artéa AI Agent Delivery Contract

This file applies to every AI agent working anywhere in this repository.

## Required outcome

For every requested implementation or bug fix, do not stop after changing the
Godot project locally. Complete the entire delivery loop automatically:

1. Implement the requested feature or fix.
2. Preserve all existing gameplay and user-authored features.
3. Make the result compatible with the Godot Web platform.
4. Test the changed mechanic and relevant regression paths.
5. Export a playable non-Mono Web build.
6. Deploy it to the existing Vercel production project.
7. Open the public URL and verify that the game starts in a real WebGL2 browser.

The task is not complete merely because native Godot tests pass, an export is
created, or Vercel reports a successful upload. Completion requires a playable
production build at <https://artea-web.vercel.app/>.

## Web compatibility rules

- The project may contain C#/.NET source for native builds, but Godot 4 Web
  exports must use the standard non-Mono Godot executable.
- Do not export Web with `Godot_mono`, .NET, Mono, or CoreCLR.
- Do not remove gameplay to make the export succeed. Port Web-incompatible
  runtime behavior to GDScript or provide a Web-compatible implementation that
  preserves the same player-facing feature.
- Preserve the `Web` preset's script, scene, asset, GDExtension, and PCK loader
  configuration. When adding runtime-loaded resources, ensure the export preset
  includes them.
- Never call a task finished while the browser shows a WebGL2 error, blank
  canvas, frozen loader, missing assets, broken controls, or script exception.
- The first download is large. Allow enough time for every split PCK part to
  download and for Godot to reach the start screen before judging startup.

## Required testing

Before exporting, run focused headless tests for every modified system. Add or
update a regression test when fixing a defect. Use the configured standard
Godot binary, for example:

```bash
rtk /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . --script res://scripts/test_<system>.gd
```

For changes affecting the Art Castle Gallery, Castle Galaxy, minimap, station,
or train, the applicable baseline tests include:

```bash
rtk /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/test_art_castle_gallery_flow.gd
rtk /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/test_world_minimap.gd
rtk /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/test_gallery_embedded_floating_world.gd
rtk /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/test_train_station_jump_traversal.gd
rtk /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/test_story_crown_railway.gd
```

Tests must exercise real player behavior where practical. A node-existence
check alone is insufficient for walking, jumping, boarding, driving, artwork
entry, direction tracking, or interaction defects.

## Required Web export

Use the maintained export script. It rejects Mono builds, exports the complete
Web preset, installs the custom PCK loader, and splits the large PCK for Vercel:

```bash
rtk bash scripts/export_web.sh
```

Treat export errors as blockers. Review warnings that could affect runtime
assets or scripts; do not ignore missing-resource or parse warnings.

## Required production deployment

The Vercel project is already linked from `builds/web`. After a successful
export, deploy that directory to production:

```bash
cd builds/web
rtk npx vercel --prod --yes
```

If the installed Vercel command is elsewhere, locate and use it rather than
asking the user to deploy manually. Do not create a different Vercel project or
change the production alias. Confirm the deployment reaches `READY` and that
<https://artea-web.vercel.app/> points to the new deployment.

## Required browser verification

Use an available browser automation tool to load a cache-busting production URL,
for example:

```text
https://artea-web.vercel.app/?build=<deployment-id>
```

Wait through the full initial asset download and verify:

- the page is served successfully;
- WebGL2 is available and no Godot feature error appears;
- the Godot loader advances;
- the Artéa start screen renders;
- for gameplay changes, enter through Offline Guest when automation permits and
  verify the changed path in the deployed build;
- browser console errors relevant to startup or the changed feature are resolved.

## Handoff requirements

In the final response, report:

- what was implemented;
- which focused and regression tests passed;
- the production deployment URL and deployment ID;
- what was verified in the browser;
- any genuine remaining limitation.

Do not instruct the user to rebuild, export, upload, or deploy work that the
agent can complete. Do not claim production completion without performing the
export, production deployment, and browser verification in the same delivery
cycle.

