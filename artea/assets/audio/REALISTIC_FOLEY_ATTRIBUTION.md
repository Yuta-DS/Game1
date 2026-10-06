# Realistic field-recorded foley

The surface footsteps in `footsteps/grass`, `footsteps/earth`,
`footsteps/gravel`, `footsteps/brick`, `footsteps/wood`, and
`footsteps/metal` are selected and renamed excerpts from **Footsteps on
Different Surfaces** by congusbongus:

- Source: https://opengameart.org/content/footsteps-on-different-surfaces
- Grass/dirt and wood recordings: swuing
- Tile/concrete recordings: swuing and ceberation
- Gravel recordings: Ali_6868
- Metal recordings: Eelke
- License: Creative Commons Attribution 3.0
  (https://creativecommons.org/licenses/by/3.0/)

The sand and stone recordings are from **Fantozzi's Footsteps (Grass/Sand &
Stone)** by Fantozzi:

- Source: https://opengameart.org/content/fantozzis-footsteps-grasssand-stone
- License: CC0 1.0 Universal
  (https://creativecommons.org/publicdomain/zero/1.0/)

The lateral leaf/vegetation brush recordings are from **Different steps on
wood, stone, leaves, gravel and mud** by TinyWorlds:

- Source: https://opengameart.org/content/different-steps-on-wood-stone-leaves-gravel-and-mud
- License: CC0 1.0 Universal
  (https://creativecommons.org/publicdomain/zero/1.0/)

All recordings remain non-looping one-shots. Artéa uses the original distinct
takes rather than pitch-shifting one sample into artificial variants.

The recorded railway texture in `train/real_train_rail.wav` is an edited
excerpt from **Passage of a train #1**, sound 900, recorded by Joseph SARDIN:

- Source: https://bigsoundbank.com/train-passes-s0900.html
- License: CC0 / public-domain equivalent
- Edit: eleven-second movement section, filtered to remove sub-bass rumble and
  leave room for Artéa's quieter magitech traction layer.

The following object recordings are by Joseph SARDIN / BigSoundBank and are
provided under CC0 / public-domain-equivalent terms:

- `world_objects/tree_wind_loop.wav`: **Forest, Wind in the Trees**, sound 904 —
  https://bigsoundbank.com/forest-wind-in-the-trees-s0904.html
- `world_objects/watermill_loop.wav`: **Mill, Wheel (Bladed)**, sound 2768 —
  https://bigsoundbank.com/mill-wheel-bladed-s2768.html
- `world_objects/sawmill_loop.wav`: **Sawmill #1**, sound 1536 —
  https://bigsoundbank.com/sawmill-1-s1536.html
- `world_objects/aether_power_loop.wav`: **Electric Transformer #4**, sound
  2437 — https://bigsoundbank.com/electric-transformer-4-s2437.html
- `world_objects/cave_air_loop.wav`: **Cave #1**, sound 2135 —
  https://bigsoundbank.com/cave-1-s2135.html
- `world_objects/train_departure_horn.wav`: **Train Horn #1**, sound 277 —
  https://bigsoundbank.com/train-horn-s0277.html

The long recordings were converted to mono 32 kHz PCM and given a
cross-faded loop boundary. Mono is deliberate: Godot's positional player then
owns the azimuth and distance response instead of baking a conflicting stereo
image into every object.

`world_objects/blacksmith_hammer.wav` is **Blacksmith's Hammer** by
Tobiasz “unfa” Karoń, CC0, from
https://opengameart.org/content/blacksmiths-hammer. It is reserved for a future
hammer animation event; the current static forge does not loop hammer strikes.
