# Heart Melody Island 1

Island 1 is the compact 200 × 120 metre low-poly Quiet Meadow and Feeling Garden chapter. It is mounted lazily inside `ArtCastleFloatingWorld` at `(6000, 0, 2290)` and becomes available after the Star of Wisdom. Legacy saves that already own the Harmony Jewel may revisit it.

The implementation keeps progression in `HeartGardenState`, geometry and collision in `HeartGardenLayout`, reusable interactions in `HeartQuestObjectBase`, combat behaviour in `HeartGardenEnemy`, and the local route display in `HeartGardenMap`. `HeartGardenWorld` connects those systems to the player, Castle gate, checkpoints, HUD, audio and completion signal.

Required progression contains only `heart_melody.task.plant_feeling_seeds` and `heart_melody.task.restore_garden_rhythm`. Optional lanterns, benches, reflections and map interactions do not add tasks. Completing Island 1 grants 80 quest XP and 39 enemy XP exactly once, saves `restored_garden`, opens the root crossing and leaves River Song physically blocked. It cannot grant the Harmony Jewel, Shield, Creator gate or train destination.

The scene uses twelve visual terrain sectors, two continuous full-lobe deck colliders, perimeter rails, a fall recovery volume, the seed canopy shortcut and the restored root crossing. Hero props use the editable Blender/GLB kit while repeated flower dressing is batched. The checked runtime build contains 27,034 static triangles, 478 mesh surfaces and peaks at 125 nearby mesh surfaces across the six gameplay viewpoints used by the architecture test.

The editable asset kit lives under `assets3D/heart_melody/island_one/source`; matching game-ready GLBs live beside it under `glb`. Regenerate them with:

```bash
rtk /Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot --headless --path artea --script res://tools/bake_heart_garden_kit.gd
rtk /Applications/Blender.app/Contents/MacOS/Blender --background --python artea/tools/blender/build_heart_garden_sources.py
```

Runtime visual evidence is generated under `artifacts/heart_garden` by `capture_heart_garden.gd`. Focused verification is provided by the state, migration, gate, world, traversal and architecture test scripts named `test_heart_garden_*.gd`.
