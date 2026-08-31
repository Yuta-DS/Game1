# ARTÉA object-by-object world and sound matrix

This is the detailed companion to `world_and_audio_inventory.md`. It was traced
from the authored `.tscn` nodes and the runtime builders that generate the hub,
castle approach, floating galaxy, Mind Spark World One, three 3 km kingdoms and
Crown Line. Repeated mesh pieces are grouped by construction family rather than
pretending that 13,000 editable train-model parts are 13,000 separate gameplay
objects.

## How to read the audio column

- **3D source**: sound is attached to the object and follows it.
- **3D zone**: one or more positioned sources cover a natural area containing
  many static props. Individual trees and rocks do not each play duplicate loops.
- **Surface**: downward raycast chooses footstep material while walking.
- **Interaction**: sound occurs only when the object is used.
- **Static/silent**: the object does not physically produce sound; nearby zone,
  footsteps and music provide context without an implausible permanent loop.

All new 3D sources use inverse-distance attenuation, a finite audible radius,
distance low-pass filtering and full direction panning. Native 5.1/7.1 output is
decoded through Godot SPCAP; Web receives directional stereo from WebAudio.

## 1. Exterior terrain and natural perimeter

| Implemented object/family | Concrete authored content | Sound treatment |
| --- | --- | --- |
| Terrain3D island | Grass/moss (texture 0), sand (texture 1) and tiled-ground (texture 2); native terrain and baked Web terrain/collision | **Surface:** exact painted grass, sand or dry brick/tile family in both native and Web builds |
| Grass scatter | `Grass`, `ScatterItemGrassA`, `ScatterItemGrassB`, bushes and dense grass resources | **Two scenarios:** compressed grass impact only when underfoot; a longer leaf/blade swish when passing beside it from a non-grass surface; regional wind remains separate |
| Mountain perimeter | Named medium-rock ring (`Rock_Medium_12` onward), mountain holder and additional scattered rock families | **Surface:** earth/stone; otherwise static |
| Trees and foliage | Common/large tree families, district trees, bushes, flowers, stair growth, cypress and grove vegetation | **3D zone:** west/east tree wind, canopy wind and kingdom wind; no duplicate loop per leaf |
| Water perimeter | Ocean/water mesh, harbour edge, waterfall and water-garden zones | **3D zone:** ocean, harbour birds/water and waterfall loops |
| Day/night weather | Procedural native sky, Web atmospheric dome, sun, moon/night scenes, wind mesh, cloud banks | **3D zone:** wind changes by location; sky itself is silent |

### Footstep and contact scenario rules

| Player contact | Selected sound | Why it differs |
| --- | --- | --- |
| On moss, lawn or grass terrain | Grass | Soft soil body plus crushed plant fibres; no pitched ring |
| Beside grass, a bush or low foliage while on another surface | Vegetation brush layered over the current footstep | Soft attack and long swish represent lateral leaf/blade contact, not a foot impact |
| On dirt, soil or ordinary unlabelled ground | Earth | Low damped thump and crumble |
| On painted beach terrain | Sand | Fine, extended granular scrape |
| On pebble, gravel or shingle | Gravel | Loose dry scatter and irregular pebble ticks |
| On village ground tile, brick paving, courts, promenades, mosaics or runes | Brick/tile | Short dry masonry knock; deliberately non-ringing |
| On castle stone, rock, stairs, foundations and stone walkways | Stone | Solid damped body with broad impact noise; no former 510 Hz metal-like ring |
| On timber, planks, piers and generic authored bridges | Wood | Warm bridge knock retained because it tested correctly |
| On iron, brass, rails or deck plates | Metal | Bright ring is reserved for explicitly metallic names only |

## 2. Village, districts and harbour

| Area | Implemented objects | Sound treatment |
| --- | --- | --- |
| Original village centre | Church, Home A/B variants, well, windmill, tavern, watermill, lumbermill, market, castle/tower and catapult tower | The current mill meshes have no running animation and are therefore **static/silent**. If activated later, windmill, watermill and sawmill use separate real recordings. Other buildings use district ambience. |
| Mind Spark district | Homes, tower, mine, barracks, market, well, fences, foliage, bench, small/large trees and extended housing | The actual mine mouth gets **3D recorded cave air**; grass/earth footsteps and tree wind cover the remainder. Lanterns whose labels mention a mine are excluded. |
| Creator's Light district | Homes, blacksmith, archery range, lumbermill, market, tower, gates, foliage, bench, trees, extended mine and barracks | The current forge and lumbermill have no operating animation, so they are silent. Forge fire and sawmill recordings are ready for an explicit active state. The mine mouth uses cave air. |
| Heart Melody district | Tavern, homes, tower, market, well, mailbox, fence, foliage, bench, trees, extended blacksmith and archery range | Static blacksmith remains silent; Heart/music zone carries authored musical content. |
| Harbour | Port/pier, boat, four market stalls, signpost, water edge | **3D harbour water/birds**; wood footsteps on pier/boat surfaces |
| Town population | Ten placed villagers, Knight, Knight2, Rogue, Barbarian, Mage, Everlasting Father, Milo, Black Cat guide and original cat statue | Milo has spoken TTS; other NPCs remain animation/dialogue driven rather than playing fake constant voices |
| Collectibles | Apple spawner, clam spawner, collectible items and treasure chest | Existing **interaction** sounds remain; static spawners are silent |
| Activity entrances | Art Gallery, Drawing Tool, Pop Thoughts and Music World trigger areas; artwork easels/player creations | Existing UI/minigame audio; portals and artwork frames are static until interaction |

## 3. Art Castle exterior and climb

| Construction family | Implemented objects | Sound treatment |
| --- | --- | --- |
| Imported castle | Blue-grey masonry, gothic keep, lancet openings, slate/red roofs, turrets, finials, timber hoardings | Castle exterior atmosphere; stone footsteps |
| Grounded entry | Entrance apron, grounded entry, ramp, 16 stone treads, timber edges, stone newels and entrance rune | Stone/wood **surface** footsteps; nearby rune energy source |
| Main stair tower | Masonry tower, stone courses, hundreds of stair treads, low-poly tree fibres/leaves, foundation buttresses and aether windows | Stone footsteps, tree wind zone and nearby magitech resonance |
| Crown approach | Crown Deck, handoff/landing, gateway apron, parapets, rune rings, crystals, ballista and arrival court/carpet/threshold | Stone/wood footsteps; magic source at Crown Rig; ballista stays silent until it gains an interaction |
| Lumen bridge | Launch, roadbed, surface planks, keel, levitation coils, underbraces, safety posts, conduits, tension ribs/collars and resonance frames | Wood footsteps; **3D magitech** resonance at the central machinery |
| Castle arrival architecture | Lower plaza, upper court, arrival terrace, bridge receiving court, grand stair, ascent ramp/conduit, raised threshold and undercroft | Stone footsteps and castle atmosphere |
| Terrace details | Levitation anchors/rings, balustrades, colonnade, courtyard, lamps, banners and threshold seal | Threshold/magitech source; individual lamps and banners are silent |
| Courtyard | Fire bowl/core/light and pedestal | **3D campfire** loop with distance/direction |
| Gatehouse | Arch, gate leaves, iron bands/handle, façade, towers and rune seal | Stone/wood footsteps; static until a gate animation exists |
| Castle crown/citadel | Crown Rig/conduits, chimney smoke, castle foundation, giant tree foundation, root crown/support zones, high-aether façade | **3D magic/citadel** hum plus regional wind |
| Astral machinery | Observatory aperture/crown/drum, calibration bands/nodes, reference astral machine, celestial core, archive cube, gears, Lumen engine and skyway map | Bounded **3D magitech** emitters at the major machines, not one source per gear tooth |

## 4. Hub sky isles and skyrail

**Live-scene finding:** `New_Hub_World.tscn` declares the SkyRail, SkyIsles and
rider scripts as external resources but does not currently instantiate nodes
using them. The objects below are fully implemented in those builders, but they
are dormant in the playable hub until those nodes are wired back into the scene.
The global sound manager will discover and equip their trains automatically if
they are re-enabled. They are not counted as currently audible trains.

| System | Implemented objects | Sound treatment |
| --- | --- | --- |
| Grand Station | Three docks, station deck, Mind/Heart/Creator shrines, route sigils and boarding prompts | **Dormant builder:** empty platforms remain silent; an arriving train provides the moving source when instanced |
| Three rails | Mind Spark, Heart Melody and Creator's Light curves, visible rails, levitation arrays, five anchors/crystals per line | **Dormant builder:** sound manager auto-detects them when instanced |
| Three shuttles | `Train_MindSpark`, `Train_HeartMelody`, `Train_CreatorsLight`; aether engine, body/glass/brass work, rotors, four levitation coils and route light | **Dormant builder:** four-layer train rig attaches automatically when instanced |
| Mind isle | Walkable floor, crystal cliffs, landmark, guardian plaque/status, portal and platform | **Dormant builder** |
| Heart isle | Walkable floor, soft hills, Melody Pool, landmark, plaque/status, portal and platform | **Dormant builder** |
| Creator isle | Walkable floor, Canvas Hill, landmark, plaque/status, portal and platform | **Dormant builder** |

## 5. Gallery-to-galaxy passage and arrival

| Implemented object/family | Detail | Sound treatment |
| --- | --- | --- |
| Gallery | Walkable gallery, player art frames, inspect camera, rating UI, return doorway, minimap and galaxy threshold | Interior/music bed and stone footsteps; frames use interaction audio where authored |
| 175 m passage | Continuous walkway, paving slabs, cyan route inlay, anti-slip joints/deck plates, underdeck spine, fascia and arches | Stone/metallic surface footsteps; Cloud Sea becomes audible during approach |
| Passage safety/structure | Bronze/iron balustrades, lower/top rails, lattice, guard glass/posts, lantern newels, piers, crossbeams, ramps and fall recovery | Static; covered by passage/Cloud Sea sound field |
| Front gate | Twin stepped towers, plinths, tower cores/bricks, bronze ribs, cyan windows, pointed arch/trim, portal piers, crest façade/branches/leaves/lights | Stone footsteps and threshold magic |
| Arrival Island | Floating deck/underside, stone promenade, aqua mosaic/runes, ART CASTLE GALAXY frame, cypress trees and South Arrival Bridge | Stone footsteps, tree wind and Cloud Sea |

## 6. Central Sanctuary and Tree of Life

| Implemented object/family | Detail | Sound treatment |
| --- | --- | --- |
| Sanctuary landmass | Floating foundation, flower-garden outer ring, Tree Court, inner energy ring, radial arches and four bridges | Cloud Sea/wind zones; stone footsteps |
| Tree trunk/root body | Old-growth trunk, central/co-dominant stems, buttresses, bark ridges, knots, primary roots/rootlets, root passage and collision proxies | **3D canopy/tree wind**; wood/root footsteps where named |
| Energy network | Sap seams/channels, buttress feeders/collectors, trunk veins and Crown convergence | **3D magic** source at the tree/shrine, avoiding dozens of identical loops |
| Mechanical tree layers | Bronze trunk bands, living-heart cradle, gear backing/mounts, astrolabe rings, rune sockets and radial spokes | Tree magic/mechanical ambience |
| Canopy | Original tiers, gravity boughs, powered living boughs, crystal leaf families, ornaments, gold collars, flow light and crown star | Canopy wind/rustle positioned above the player |
| Wisdom Heart Shrine | Heart crystal/core/light, elevation ring, spin pivot, wood cradle and Crown of Life alignment | **3D magic** resonance |
| Guide | Black Cat companion | Static guide presence; no fabricated animal loop |

## 7. Mind Spark, Heart Melody and Creator's Light galaxy districts

| District | Implemented objects and story landmarks | Sound treatment |
| --- | --- | --- |
| Mind Spark | Circuit rune court, ruined wall/open arches, thought towers, living vines, Fear/Proof/Truth gates, Thought Storm/Gentle Rain, Oldest Tree Sanctuary, Star of Wisdom, World Gate and rest-island causeway | High wind, Gentle Rain/network ambience where authored, magic emitters at major landmarks, stone/earth footsteps |
| Heart Melody | Melody Stage, emotion pads, frame/arches, emotion instruments, Personal Song amphitheatre, Harmony Jewel and Raphael landmarks | Water garden plus existing emotion/music audio; stone/earth footsteps |
| Creator's Light | Studio floor/back wall, painting easels, artist-material table, paint pots, sun rune, frame, Glass Seeds, silver pipes, Perfect Blank and Uriel landmarks | Canvas/tree wind plus existing creativity music and interaction audio |
| Outer galaxy | Four boundary observatories, compass rings/towers, twin-island bridges, cloud towers, Cloud Sea, labels and return gates | Large **3D Cloud Sea** source and regional high wind |

## 8. Mind Spark World One

| System/family | Implemented content | Sound treatment |
| --- | --- | --- |
| Six-zone world | Native landing, Computer-Tower/Network Forest, constellation court, evidence gates, Hope Ridge, Storm Arena and Oldest Tree sanctuary | Existing network/sanctuary ambience plus regional wind |
| Foundations | Modular floating bodies, surface networks, engraved dials, living-root lattice, data orbits, service modules and levitation crystals/facets | Zone magic bed; static sub-parts do not each loop |
| Traversal | Main story route, ring closure, transit network, station spur, access stairs, bridges and recovery volumes | Surface footsteps; the empty station spur is silent until transport is active |
| Living environment | Bio-data trees, sockets, grove trees, mushrooms, server trees and root outlayers | Tree/wind zone; no per-mushroom sources |
| Quest objects | Calm Rain Basin, Server Root checkpoint, Clear Path projector, Evidence Scanner, Focus Bell, Identity Mirror, Logic Gate, Memory Board, Perspective Lens, Thought Spark socket/collectible, Truth Bridge tile and Warden Anchor | Existing **3D interaction feedback**; environmental layer remains underneath |
| Combat | Enemy base, Thought Storm Warden and encounter director | Combat/interaction layer retained; no constant enemy loop added |

## 9. Three extended 3 km × 3 km kingdoms

Each kingdom contains a 5×5 floating shelf landmass, inter-shelf bridges and
guards, 16 boundary beacons, groves/old trees, a continuous route, Crown Line
station and eight ordered checkpoints.

| Kingdom | Eight checkpoint groups | Sound treatment |
| --- | --- | --- |
| Mind | Landing; Computer-Tower Forest; Thought Spark Constellation; Fear Gate; Proof Gate; What Else Is True; Thought Storm/Gentle Rain; Oldest Tree/Star of Wisdom | High wind, storm/rain/network ambience, tree zones and Crown station/train |
| Heart | Landing; Joy Garden; Frustration Drum Terraces; Sadness Rain Boat; Fear Warning Bells; Peace Flower Meadow; Hope Morning Stage; Personal Song/Harmony Jewel | Water/weather and existing musical-emotion sounds plus Crown station/train |
| Creator | Landing; Glass Seed Laboratory; Drawing Studio; Dream Door Workshop; Resting Place Canvas; Art-Becomes-Real Garden; Perfect Blank; Uriel/Creator's Light | Canvas/tree wind, creation music/interaction sounds and Crown station/train |

## 10. Crown Line train and stations

| Train/rail object | Implemented detail | New sound behavior |
| --- | --- | --- |
| Closed route | Gallery → Mind → Heart → Creator → Gallery, four curves, station straights, centre monorail beam and energy ribbon; approximately 21.7 km total | Moving source follows the physical train around the entire loop |
| Four stations | Gallery right-side dock, Mind park-edge station, Heart east floating station and Creator east floating station | Empty station structures are silent; train arrival/departure supplies the physical sound |
| Station architecture | Walkable platforms, destination wheels, boarding lanes/signs, guardrails, floating dock structures, arrival bridges/stairs, bio-magitech pavilions, resonance arches and crystal planters/reactors | Destination wheels retain bounded aether power; platforms use stone/bridge footsteps; signs and rails do not loop |
| Train collision/gameplay shell | Two open passenger coaches, decks, side/end guards, benches, centre aisle, gangway/rails, driver console and passenger seats | Audio stays attached whether driving, seated or riding as passenger |
| Milo engine | Engine body, roof guard, Crown chimney, guiding light and Godot engine cover | Recorded electrical machinery used as low traction/aether texture, quiet while docked and louder with speed; pitch varies only ±8% |
| Detailed Blender train | Textured optimized runtime GLB backed by the source model with about 13,000 editable pieces | Uses the parent train source; no duplicate sound for visual-only child parts |
| Running gear | Star wheels, bogie wheels/tyres/flanges, brake discs, speed bands/rotors/needle, reactor emitters and brake gauges | Recorded **rail movement** changes mainly in volume with measured world speed; pitch stays within ±10% |
| Travel airflow | Open coaches and high-speed exterior motion | Generated **wind-rush loop** fades in above low speed |
| Departure | Automatic, passenger and manual-driving movement from rest | Recorded train horn one-shot after a genuine stop, mixed lower than the moving layers |
| Arrival/braking | Speed transition back to a docked state | Generated descending brake shimmer and pneumatic release |
| Spatial response | Whole moving train | Inverse-distance loudness, directional angle, distant low-pass, 230–340 m finite radii and native surround decoding |

## Deliberate non-sound emitters

Static walls, individual bricks, every grass blade, every leaf, windows, labels,
guardrails, collision proxies and decorative mesh batches do not each receive an
audio player. Doing so would create phasey duplicated noise, consume thousands
of Web audio voices and make direction cues meaningless. They are represented by
the nearest physical zone, footsteps or parent mechanism. This is intentional
coverage, not an omitted inventory item.
