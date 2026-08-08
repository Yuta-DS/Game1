# Artéa Castle Universe implementation

The Castle Universe is implemented directly in the existing Godot 4 hub scene,
not as a separate React/Three.js application. This keeps the work inside the
game's player, camera, progress, portal, terrain, and scene systems.

## Runtime systems

- `hub_lumen_citadel.gd`: floating castle foundation, supports, gallery anchor,
  living brass/crystal machinery, and castle dormant/vibrant state.
- `hub_sky_isles.gd`: Mind Spark, Heart Melody, and Creator's Light islands,
  walkable floors, distinct terrain/landmarks, idle bob, and independent states.
- `hub_skyrail.gd`: Grand Station, three curved supported rails, and three
  color-coded detailed magitech trains.
- `hub_train_rider.gd`: visible six-pad two-way boarding system and scenic rides.
- `hub_atmosphere.gd`: one low-count additive aether-mote particle field.
- `teleport_Art_Gallery.gd`: castle-following Gallery door trigger and lit frame.

## Debug controls

In a debug build:

- `F5`: toggle Castle
- `F6`: toggle Mind Spark
- `F7`: toggle Heart Melody
- `F8`: toggle Creator's Light
- `F9`: toggle all three kingdoms

The existing number keys still preview the journey-wide stage progression.

## Verification

Run the full integration test:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot \
  --headless --path artea --script res://scripts/test_castle_universe.gd
```

Generate the two visual inspection captures:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot \
  --path artea --script res://scripts/capture_castle_universe.gd
```

The focused world-layer budget measured in the integration test is:

- 694 low-poly mesh instances
- 20,472 triangles
- 16 local lights (all traversal/detail lights are unshadowed)
- 84 ambient particle quads in one particle system

The mesh-instance count is driven mostly by individually collidable castle stair
treads and safety rails; triangle cost remains low. The existing full hub still
emits asset UID/mipmap and Proton Scatter warnings that predate this work.

## Debug log

- The Gallery trigger was measured at Y=37.2 while the castle mesh begins at
  Y=65.5. It now follows the imported door's local anchor each frame.
- The Gallery Area serialized a `body_entered` connection and connected it again
  in `_ready()`. Signal connection is now idempotent.
- Castle bridge boxes were aimed along local Z and then rotated another 90°,
  standing every plank upright. The redundant rotation and 28% endpoint gap were
  removed; the target is now the actual door face.
- Station proximity flattened only the player Y coordinate, leaving station Y in
  the distance calculation. Both positions are now compared in X/Z.
- Ambient train animation and ride tween both wrote the train transform. Each
  line now grants exclusive transform ownership to the rider while occupied.
- All rails originally started at an unrelated low village/gallery coordinate.
  They now start at three physical docks in the castle's Grand Station.
- Island materials were originally stored in global arrays, making independent
  state changes impossible. Each island now owns its material/spinner set.
- Initial distance fog flattened the castle into a pink silhouette from scenic
  angles. Density/energy were reduced and local unshadowed fill lights now keep
  the castle, station, and vibrant island faces readable against the bright sky.
