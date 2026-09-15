# Mind Spark World One — Luxury Aether-Steam Component Catalogue

Status: Blender production specification for the reusable World One kit.

Scope: visual components only. The six-island layout, route, collisions, quest
order, save IDs, combat contracts, World Gates, and station unlock policy stay
unchanged until a later integration pass.

## Art direction

World One is a warm, modern city of invention: ivory civic stone, champagne
brass, rose copper, walnut, curved glass, planted terraces, still water, and
quiet kinetic machinery. Steam power is visible but curated like museum-quality
kinetic art. Cyan identifies a functioning or interactable system; amber means
heat and hospitality; violet is reserved for Thought Storm corruption.

## Reuse contract

Every component follows the same contract:

- metres, Blender Z-up, with the ground contact at `Z = 0`;
- root named `MSLS_<component_id>` at the local origin;
- visible meshes prefixed `VIS_` and collision proxies prefixed `UCX_`;
- shared `MSLS_` material names across the whole kit;
- named `SOCKET_` empties for pipes, spans, power, or quest assembly;
- no camera or light exported in an individual GLB;
- no text, logos, characters, or franchise-specific symbols;
- broad, uncluttered player-facing silhouettes and Web-conscious geometry;
- individual GLB export plus one editable master `.blend` library.

## Shared materials

| Material | Use |
| --- | --- |
| `MSLS_IvoryStone` | primary civic floors, plinths, arches |
| `MSLS_CreamStone` | secondary stone and edge bands |
| `MSLS_ChampagneBrass` | premium frames, ribs, controls |
| `MSLS_RoseCopper` | pipes, heat systems, mechanical accents |
| `MSLS_Gunmetal` | concealed load-bearing machinery |
| `MSLS_Walnut` | benches, handles, hospitality details |
| `MSLS_Terracotta` | planters, warm inlays, station details |
| `MSLS_Sage` | planting and restorative elements |
| `MSLS_DeepTeal` | enamel machinery housings |
| `MSLS_Sapphire` | navigation and civic instrument faces |
| `MSLS_AetherCyan` | operational energy and primary interaction |
| `MSLS_HoneyAmber` | heat, lanterns, welcoming secondary light |
| `MSLS_StormViolet` | boss corruption only |
| `MSLS_WarmGlass` | canopies, conservatories, gauges |
| `MSLS_Water` | condenser pools and reflecting basins |

## A. Architectural modules

1. `arch_01_ivory_column` — 0.85 × 0.85 × 5.2 m. Fluted structural column with
   brass capital. Reuse in gates, conservatories, observatory and station.
2. `arch_02_brass_railing_straight` — 4 × 0.18 × 1.15 m. Repeatable safety edge
   with square posts and diamond infill.
3. `arch_03_brass_railing_curve` — 30-degree, 4 m-radius curved safety edge for
   island rims and rotundas.
4. `arch_04_glass_canopy_bay` — 6 × 4 × 4.2 m iron-and-glass barrel-vault bay.
   Bays snap end-to-end for conservatories and station platforms.
5. `arch_05_luxury_floor_square` — 4 × 4 × 0.22 m ivory floor bay with brass
   square grid and warm inset border.
6. `arch_06_luxury_floor_diamond` — 4 × 4 × 0.22 m navigation bay with a brass
   diamond motif and cyan focus stud.
7. `arch_07_rotunda_arch` — 6 × 1 × 5.5 m grand civic arch with circular focus
   crown. Reuse at zone entries and the turbine rotunda.
8. `arch_08_glass_balustrade` — 4 × 0.14 × 1.2 m warm-glass safety panel with
   champagne-brass posts.

## B. Traversal modules

9. `route_01_bridge_truss_segment` — 8 × 5 × 1.4 m walkable bridge module with
   truthful structural depth, brass edge rails, and underside iron trusses.
10. `route_02_bridge_landing` — 7 × 7 × 0.7 m transition deck that overlaps an
    island rim and accepts two bridge modules.
11. `route_03_wayfinding_pylon` — 1.1 × 1.1 × 3.6 m direction instrument with
    rotating diamond indicator and cyan objective lens.
12. `route_04_station_platform_bay` — 10 × 5 × 0.55 m boutique railway platform
    with tactile brass edge and canopy sockets.

## C. Steam and aether machinery

13. `mech_01_boiler_vertical` — 2.6 × 2.6 × 5.4 m polished vertical boiler with
    firebox, rivet bands, gauge, relief valve, and pipe sockets.
14. `mech_02_piston_engine` — 5 × 2.4 × 3.2 m double-acting horizontal piston,
    crosshead, connecting rod, and crank output.
15. `mech_03_flywheel` — 3.8 m-diameter spoked flywheel with guarded axle and
    rotation origin at its shaft.
16. `mech_04_centrifugal_governor` — 1.8 × 1.8 × 3.4 m working-speed governor
    silhouette with two brass weights and vertical control shaft.
17. `mech_05_pressure_gauge` — 0.75 m circular enamel gauge with needle, brass
    bezel, and pipe input.
18. `mech_06_relief_valve` — 0.8 × 0.8 × 1.7 m handwheel relief valve with input
    and output sockets.
19. `mech_07_pipe_straight` — 4 m copper pipe with flange sockets at both ends.
20. `mech_08_pipe_elbow` — reusable quarter-turn copper pipe with flange sockets.
21. `mech_09_pipe_t_junction` — three-way copper distribution fitting.
22. `mech_10_condenser_tank` — 4 × 3 × 2.4 m warm-glass and brass condenser
    reservoir with visible waterline.
23. `mech_11_aether_dynamo` — 3 × 3 × 3.2 m circular generator converting shaft
    motion to restrained cyan energy.
24. `mech_12_energy_conduit` — 4 m glass-and-brass power conduit with cyan inner
    core and end sockets.

## D. Luxury landscape and hospitality

25. `civic_01_lantern` — 0.65 × 0.65 × 3.2 m warm civic lamp with amber glass.
26. `civic_02_bench` — 2.4 × 0.75 × 1 m walnut-and-brass garden bench.
27. `civic_03_planter` — 2 × 2 × 0.85 m terracotta and brass planter with modular
    sage planting.
28. `civic_04_reflecting_basin` — 4 × 4 × 0.45 m shallow ivory reflecting pool.
29. `civic_05_mechanical_flower` — 1.4 × 1.4 × 1.8 m reusable kinetic flower with
    brass petals, sage leaves, and cyan centre.
30. `civic_06_clock_kiosk` — 1.8 × 1.2 × 3.8 m station/arrival clock and map kiosk
    with sapphire enamel face.

## E. Quest relic mechanisms

31. `quest_01_compass_ring` — Zone 01 destination puzzle. Three concentric brass
    rings, landmark studs, rotating diamond pointer, and bridge-power socket.
32. `quest_02_balance_valve` — Zone 02 steam/water/light routing puzzle. Three
    visible meters, three handwheels, and a central equilibrium indicator.
33. `quest_03_clarity_lens` — Zone 03 evidence puzzle. Dual optical lenses compare
    observation with prediction; the accepted signal converges in cyan.
34. `quest_04_perspective_prism` — Zone 04 viewpoint puzzle. Three rotating optical
    arms align through a warm-glass prism to project the bridge solution.
35. `quest_05_courage_flywheel` — Zone 05 restoration reward. Compact flywheel,
    governor, and open relief ring that visually remembers the calmed storm.
36. `quest_06_wisdom_engine` — Zone 06 finale. Concentric sockets accept the five
    earlier relics around a player-chosen core; completion powers the tree.

## Zone reuse matrix

| Zone | Primary modules |
| --- | --- |
| 01 Arrival Salon | columns, floor bays, railings, arch, pylon, lantern, bench, clock kiosk, Compass Ring |
| 02 Living Conservatory | columns, canopy bays, glass balustrades, boiler, pipes, condenser, planters, flowers, Balance Valve |
| 03 Observatory Library | floor bays, rotunda arches, gauges, conduits, lanterns, benches, Clarity Lens |
| 04 Reflection Promenade | bridge segments, landings, glass balustrades, pylons, conduits, Perspective Prism |
| 05 Turbine Rotunda | arches, flywheels, piston engines, governors, valves, dynamo, basin, Courage Flywheel |
| 06 Wisdom Garden | canopy bays, columns, planters, flowers, basin, conduits, lanterns, Wisdom Engine |
| Station spur | platform bays, canopy bays, columns, railings, lanterns, bench, clock kiosk |

## Quest assembly sockets

The five collected relics use consistent finale sockets:

1. `SOCKET_RELIC_COMPASS`
2. `SOCKET_RELIC_BALANCE`
3. `SOCKET_RELIC_CLARITY`
4. `SOCKET_RELIC_PERSPECTIVE`
5. `SOCKET_RELIC_COURAGE`
6. `SOCKET_PLAYER_CORE`

The names are intentionally semantic rather than numbered so Godot integration
can bind components without relying on Blender hierarchy order.

## Produced library

- Editable master: `assets3D/mind_spark/luxury_steam_kit/source/mind_spark_luxury_steam_kit.blend`
- Individual modules: `assets3D/mind_spark/luxury_steam_kit/glb/<component_id>.glb`
- Machine-readable catalogue: `assets3D/mind_spark/luxury_steam_kit/component_manifest.json`
- Validation result: `assets3D/mind_spark/luxury_steam_kit/validation_report.json`
- Family sheets: `assets3D/mind_spark/luxury_steam_kit/previews/01_*.png` through `05_*.png`
- One-by-one renders: `assets3D/mind_spark/luxury_steam_kit/previews/components/<component_id>.png`

Rebuild the whole library with:

```sh
blender --background --python tools/blender/build_mind_spark_luxury_steam_kit.py
```

Validate every exported module in a clean Blender scene with:

```sh
blender --background --python tools/blender/validate_mind_spark_luxury_steam_kit.py
```

This kit is deliberately isolated from the current World One scene. A later
integration pass can place instances zone by zone without replacing the map,
quest IDs, or existing traversal topology.
