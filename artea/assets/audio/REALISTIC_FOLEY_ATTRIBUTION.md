# Realistic field-recorded foley

## Active professional Foley upgrade

The active grass, brick/stone masonry, gravel, and metal footsteps under
`pro_footsteps/` use high-resolution masters selected from Sonniss's
**#GameAudioGDC** bundles. The sources are licensed worldwide, non-exclusively,
and royalty-free for games and other synchronized media. Attribution is not
required, but the provenance is retained here for auditability.

- `pro_footsteps/grass`: 192 kHz/24-bit **STEPS Dry Grass & Shrubs** recordings
  by PMSFX (GDC 2020), supplemented with 96 kHz/24-bit grass gait takes from
  Tovusound's **Edward – Foleyart Collection Add-On Extended Footsteps**
  (GDC 2017).
- `pro_footsteps/brick` and `pro_footsteps/stone`: separate impact selections
  from Tovusound's 96 kHz/24-bit close asphalt-boot session. The brick set has
  a restrained upper transient while the stone set retains more low impact;
  neither set contains a metal recording.
- `pro_footsteps/gravel` and `pro_footsteps/metal`: distinct 96 kHz/24-bit
  performances from Studio 23's **Ultimate Footstep Collection** (GDC 2019).
- `pro_vegetation`: separate passes through the PMSFX dry-grass skid/drag
  master, kept independent from underfoot grass impacts.
- `pro_train`: a 48 kHz/24-bit Royal Hudson steam-train ride and whistle by
  Airborne Sound (GDC 2019). The ride is crossfaded into one seamless master,
  then split into complementary engine/steam and rail-clatter frequency bands
  so the two spatial layers do not duplicate or phase against one another.

Source archive: https://sonniss.com/gameaudiogdc/

Bundle license: https://sonniss.com/gdc-bundle-license/

Game-ready footsteps are peak-safe, loudness matched, and encoded at 48 kHz
Vorbis quality 8. Positional train layers are 48 kHz mono PCM so Godot, rather
than a baked stereo image, controls listener-relative azimuth and distance.

## Retained legacy recordings

The earlier surface footsteps in `footsteps/grass`, `footsteps/earth`,
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
