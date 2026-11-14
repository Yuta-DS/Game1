# ARTÉA world, sky, and audio inventory

Audited 23 August 2026 from the live Godot scenes and the runtime builders that
assemble the exterior hub, Art Gallery, Art Castle Galaxy, Crown Line, and the
three extended kingdoms.

For the concrete object-by-object and sound-coverage breakdown, including both
rail systems and every major construction family, see
[`world_object_sound_matrix.md`](world_object_sound_matrix.md).

## Exterior world: village to the Art Castle

- **Natural world:** Terrain3D island, moss/grass/sand/tiled-ground surfaces,
  surrounding water, mountain and rock perimeter, dense grass/bush scatter,
  multiple families of scattered trees and rocks, daylight/night environment,
  wind mesh, and Web-specific baked terrain/collision.
- **Art Castle exterior:** the imported castle, weathered blue-grey masonry,
  slate/red roofs, gothic keep and lancet details, turret roofs and finials,
  timber hoardings, oak drawbridge/causeway, barbican, grand castle ascent,
  front gatehouse, oak gate leaves, iron bands and handle.
- **Castle arrival architecture:** lower plaza, upper court, arrival terrace,
  galaxy-bridge receiving court, grand stair and door ascent, raised threshold,
  structural undercroft, levitation anchors/rings, balustrades, colonnade,
  courtyard, fire beacon/fountain, gatehouse arch, lamps, banners, and threshold
  rune seal.
- **Castle atmosphere:** Crown Rig and conduits, chimney smoke, aether motes,
  stage-responsive castle lighting, landmark glows, and the outdoor minimap.
- **Dormant hub skyrail implementation:** the Grand Station, station deck, realm
  shrines, rail lines, safety structure, levitation arrays, floating crystals,
  aether anchors, and three rideable shuttles are fully implemented in scripts,
  but their scripts are only declared as unused external resources in the live
  `New_Hub_World.tscn`; the required nodes are not currently instantiated.
- **Dormant hub Sky Isles implementation:** Mind Spark, Heart Melody, and Creator's Light islands; walkable
  floors, Mind crystal cliffs, Heart soft hills and Melody Pool, Creator canvas
  hill, landmarks, campaign plaques/status, and realm portals.
- **Village districts:** Mind Spark, Creator's Light, and Heart Melody housing
  clusters containing homes A/B, church, markets, tavern, well, windmill,
  watermill, lumbermill, mine, barracks, blacksmith, archery range, castle/tower
  variants, gates, fences, benches, mailboxes, foliage, and large/small trees.
- **Harbour and town life:** pier, boat, four market stalls, ten villagers, Milo,
  Everlasting Father, Knight, Rogue, Barbarian, Mage, signpost, narrative spawn,
  apples and clams, inventory, and the drawing/music/Pop Thoughts/gallery entry
  points.

## Art Castle interior and the connected galaxy

- **Art Gallery:** walkable gallery floor, player artwork frames, artwork inspect
  camera, rating/interaction UI, return doorway, gallery minimap, and the
  embedded galaxy threshold.
- **Castle-to-Galaxy Passage (175 m):** continuous collision-safe walkway,
  reference paving slabs and cyan route inlay, under-bridge arches and fascia,
  bronze/iron balustrades, lantern newels, guard glass, anti-slip deck plates,
  piers, threshold ramps, fall recovery, and the Blender-authored twin-tower
  pointed front gate.
- **Arrival Island:** floating foundation, stone promenade, aqua mosaic/runes,
  ART CASTLE GALAXY frame, cypress trees, and South Arrival Bridge.
- **Central Sanctuary:** floating island foundation, outer flower garden ring,
  Tree Court, inner energy ring, radial arches, Black Cat guide, South/Mind/
  Heart/Creator bridges, and the Tree of Life.
- **Tree of Life:** authored trunk and root silhouette, collision-safe root
  passage, bark-pinned energy veins, brass mechanics, powered living bough
  canopy, coloured crystal foliage families, canopy ornaments, crown energy,
  Wisdom Heart Shrine, living-wood cradle, gears/astrolabe/runes, heart crystal,
  and the Crown of Life alignment.
- **Mind Spark District:** floating island, circuit rune court, Mind frame,
  ruined wall, thought towers and living vines, Fear/Proof/Truth gates, Thought
  Storm becoming Gentle Rain, Oldest Tree Sanctuary, Star of Wisdom, World Gate,
  and a walkable causeway via rest islands to the six-island World One quest.
- **Heart Melody Temple:** floating island, Melody Stage, emotion pads, arches,
  Heart frame, emotion instruments, Personal Song amphitheatre, Harmony Jewel,
  and Raphael story landmarks.
- **Creator's Light Studio:** floating island, studio floor/back wall, easels,
  artist materials table, sun rune, Creator frame, glass seeds, silver pipes,
  Perfect Blank sanctuary, Creator's Light, and Uriel story landmarks.
- **Outer galaxy:** four boundary observatories with compass rings/towers,
  additional twin-island bridges, distant cloud towers, the Cloud Sea, world
  labels, and safe respawn/return gates.
- **Three extended 3 km × 3 km kingdoms:** each has a 5×5 floating shelf
  landmass, shelf bridges and guards, 16 boundary beacons, a continuous story
  path, a Crown Line station, and eight ordered checkpoints:
  - **Mind:** landing, Computer-Tower Forest, Thought Spark Constellation, Fear
    Gate, Proof Gate, What Else Is True, Thought Storm/Gentle Rain, Oldest Tree/
    Star of Wisdom.
  - **Heart:** landing, Joy Garden, Frustration Drum Terraces, Sadness Rain Boat,
    Fear Warning Bells, Peace Flower Meadow, Hope Morning Stage, Personal Song/
    Harmony Jewel.
  - **Creator:** landing, Glass Seed Laboratory, Drawing Studio, Dream Door
    Workshop, Resting Place Canvas, Art-Becomes-Real Garden, Perfect Blank,
    Uriel/Creator's Light.
- **Crown Line:** roughly 21.7 km of continuous track, four climbable stations,
  boarding promenades/ramps/stairs, floating dock structures, bio-magitech
  pavilions, crystal planters/reactors, the Godot Engine train, player driving
  and riding, and the story route linking Castle, Mind, Heart, and Creator.

## Interaction and navigation systems

- Third-person walking, running, jumping, stair stepping, combat, boarding and
  driving; indoor/outdoor galaxy minimaps; local fall recovery; artwork entry
  and return; Q-key story discoveries; kingdom/campaign gates; collectibles;
  inventory; and Milo's child-safe local reflection/activity panel.

## Sky audit

- Desktop uses the authored procedural day/night sky shader.
- Web previously discarded that sky and drew a flat blue sphere. That was the
  visible defect in the deployed build.
- Web now uses a lightweight spatial dome shader with a four-band atmospheric
  gradient, moving multi-scale cloud banks, sun disc/glow, and a below-horizon
  colour. It avoids the WebGL2-incompatible Sky shader path while restoring an
  intentional sky rather than a flat fallback.

## Spatial audio audit and implementation

- **Recorded footsteps:** six to ten distinct field-recorded takes for each of
  eight physical families: compressed grass, compacted earth, fine sand, loose
  gravel, dry brick/tile, solid stone, timber/bridge and metal. A downward
  physics ray selects the actual collider/painted terrain material; cadence
  follows player speed. Grass, earth, brick and stone never fall through to the
  formerly metal-like profile.
- **Painted terrain:** native builds read Terrain3D's base/overlay texture IDs.
  The Web bake carries a matching 513×513 surface lookup, so moss/grass, beach
  sand and village ground tiles retain different footsteps after Terrain3D is
  replaced by the Web collision mesh.
- **Passing vegetation:** this is separate from stepping on vegetation. Grass
  under the foot produces a short compressed-blade impact. Walking on a
  non-grass surface beside a painted grass edge, bush, shrub, foliage cluster
  or district tree produces a softer lateral swish with its own cooldown. The
  lateral swish is suppressed when grass is already underfoot.
- **Exterior sources:** directional harbour water/birds, castle courtyard fire,
  western tree wind, and eastern tree wind.
- **Galaxy sources:** Cloud Sea, Tree of Life canopy wind/leaves, Mind Spark
  high wind, Heart Melody water garden, and Creator's Light canvas/tree wind.
- **Named object sources:** real recordings cover moving windmill sails,
  operating watermills and sawmills, forge fire, cave air and powered aether
  machinery. Motion-gated objects remain silent when their animation is not
  operating. Imported child meshes are collapsed into one physical source;
  decorative lantern labels and player-worn objects are explicitly excluded.
  Empty stations are silent and receive their context from a present train.
- **Train sources:** all three hub skyrail shuttles and the Rainbow Galaxy Crown
  Line train receive recorded rail movement, recorded traction/aether machinery
  and a recorded departure horn. Travel airflow and the magitech brake use
  restrained synthesis where no physically matching clean recording is
  available. Pitch stays within a narrow natural range; loudness follows
  measured speed. The entire sound rig moves with each train.
- Every environmental source uses `AudioStreamPlayer3D`, inverse-distance
  attenuation, a finite maximum distance, distant low-pass filtering, and full
  panning strength. Godot routes those azimuth cues through SPCAP when the
  detected device is 5.1/7.1; Web browsers receive positional stereo panning.
- **Complete surround policy:** every authored or runtime-created
  `AudioStreamPlayer3D` is scanned automatically. Physical sources receive full
  panning, SFX-bus routing, reverb-area participation, bounded audible range and
  distance filtering. Moving trains additionally use physics-step Doppler;
  stationary sources do not. The active camera remains the listener, so front,
  side and rear placement follows the player's view. UI feedback and score
  music deliberately remain non-positional and centred.
- Godot reports the actual output layout at runtime. A device configured by the
  operating system as 7.1 is decoded through all eight channels; 5.1, stereo,
  headphones and Web builds receive their correct automatic fallback. The game
  cannot turn a physically stereo device into real rear speakers.
- Milo's complete authored panel text now goes to Godot platform TTS on Web,
  macOS, Windows, Android, and iOS. It prefers an `en_AU` voice, falls back to
  another English voice, uses a warm lower pitch/rate, interrupts stale lines,
  and reduces voice level as the player moves away.

## Deployment path

- Main scene: `res://scenes/start_screen.tscn`.
- Web preset: standard non-Mono Godot Web export, custom HTML shell and PCK
  loader, WebGL2 Compatibility renderer.
- Maintained build command: `scripts/export_web.sh`.
- Production directory/project: `builds/web`, linked to the existing Vercel
  production alias `https://artea-web.vercel.app/`.
- No Git commit or GitHub push is part of this delivery.
