# Artéa exterior coastal set

Style reference: the playable `scenes/New_Hub_World.tscn` exterior village, not
the Art Castle Galaxy. The harbour office reuses
`assets3D/houses/red/building_home_A_red.gltf` and its original atlas. Broad red
and cream cloth, warm timber, blue-grey fittings and chunky beveled geometry
carry the village style through the dock and boat. No crystal decorations.

Regenerate the three GLBs, editable Blender scene and model preview:

```sh
rtk /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/build_coastal_harbour.py
```

Then import changed resources through Godot's editor. The runtime entry points
are `scripts/Pier.tscn`, `scripts/coastal_sea_life.gd` and `scenes/boat.tscn`.
The new pier intentionally has no legacy UID: `Pier.tscn` at the project root
is a different old asset and must not replace it.

There are 38 tagged animal roots: 23 fish, 3 crabs, 3 shells, 2 oysters,
2 sea mushroom clusters, 2 jellyfish, 2 starfish and 1 turtle. glTF custom
properties arrive in Godot's `extras` metadata. Only these roots animate;
component meshes and stationary shell beds do not drift independently.

Walk from the shore apron through the jetty to the side berth to board.
The harbour is beside the southern sea watchtower (`building_tower_B_red2`),
at world position `(38, 0.9, 184)` with its jetty pointing south. The boat is
moored at `(26.9, 0.92, 193)`. Sea life and clear-water placement follow the
harbour transform, and harbour ambience follows the Port node.
WASD sails and steers; Space disembarks beside safe ground or the dock.
Disembarking in open water is refused, leaving the player in control of the boat.

Verification scripts:

- `scripts/test_coastal_harbour.gd`: exact creature counts, intact geometry,
  village asset reuse, collision traversal, automatic boarding, real input
  sailing/steering, rider attachment and safe disembarking.
- `scripts/test_coastal_hub_integration.gd`: actual hub scene resolution,
  shoreline alignment, boat orientation and localized clear-water binding.
- `scripts/capture_coastal_style.gd`: actual exterior and player-on-boat captures;
  run with a graphical renderer, not `--headless`.

No commit, push or deployment is part of this local revision. The local Web
export is generated but still reports existing missing legacy vegetation/cloud
resources elsewhere in the project; it is not a clean production verification.
