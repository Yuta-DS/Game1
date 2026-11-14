# Island One — Aether Compass Station v20

Island One is now a functional arrival and navigation station rather than an ornamental court.

## Gameplay purpose

1. Balance the west and east levitation-pressure regulators.
2. Align the origin, forest-destination, and energy compass rings.
3. Pull the route lever to power the bridge toward Island Two.
4. Earn the persistent Bearing Sigil.
5. Save at both Checkpoint Server Roots to finish the opening quest task.

The puzzle is untimed, gives partial alignment feedback, supports replay, and never removes an earned relic or powered bridge. Checkpoint save and heal remain independent.

## Authored construction

The audited runtime retains **721 live authored nodes after safe static batching**. Repeated non-interactive details are GPU-batched for the browser; the moving rings, controls, gauges, canopy triangles, reward, and feedback pieces remain independent nodes.

- Three separately rotating compass rings
- 84 editable rune plaques plus ivory gear teeth and brass ring bodies
- Six separately named operator stations
- Twin handwheel regulators with instrument faces
- Two eleven-tick pressure gauges with teal target brackets
- Two animated four-arm governors
- Tower-to-compass and compass-to-bridge aether conduits
- Ten moving bridge-energy packets
- Fifteen solved-route lights
- Persistent Bearing Sigil reward
- Existing 144 independent triangular canopy panes retained

## Evidence

- `01_island_one_aether_station.png` — complete island composition
- `02_three_ring_aether_compass.png` — canopy-hidden design inspection of the machine
- `03_twin_pressure_regulators.png` — pressure tower, governor and control detail
- `04_solved_bridge_power_and_sigil.png` — solved route-power state
- `tests/results.json` — 15 passing regression checks

Focused behavior and persistence are covered by `res://scripts/test_island_one_compass_v20.gd`.
