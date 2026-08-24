# Tree of Life — Doubled Canopy Tier Plan

This plan translates the supplied 64 m front elevation into a 128 m Tree of
Life while preserving the approved 48 m trunk/root module and doorway.

## Fixed dimensions

- Total height: 128 m / 496 Godot units
- Crown socket: 120 m / 465 Godot units
- Gold star: 8 m high, centred at 124 m, top at 128 m
- Maximum canopy width: 104 m / 403 Godot units
- Existing trunk/root body, heart height, doorway, and root spread: unchanged

## Nine connected canopy tiers

| Tier | Height | Radius | Primary boughs | Purpose |
|---:|---:|---:|---:|---|
| 1 | 14 m | 52 m | 24 | Lowest skirt; masks the trunk around the heart and doorway clear zone |
| 2 | 27 m | 48 m | 24 | Dense lower-body overlap |
| 3 | 40 m | 42 m | 20 | Upper trunk coverage |
| 4 | 53 m | 36 m | 20 | Transition from body to cone |
| 5 | 66 m | 30 m | 16 | Broad middle canopy |
| 6 | 79 m | 24 m | 16 | Upper-middle taper |
| 7 | 92 m | 18 m | 12 | Narrow upper cone |
| 8 | 105 m | 12 m | 8 | Crown approach |
| 9 | 118 m | 7 m | 4 | Star socket closure |

## Exact hierarchy and coverage

- 144 primary boughs
- 288 child boughs, exactly two per primary
- 1,728 twig fans, exactly six per child
- 57,600 visible leaf cards across four semantic families
- Inner child sockets begin at 24% of each primary bough
- Twig sockets begin at 10% of each child bough
- Leaf sockets begin at 6–7% of each twig stem
- Crossed leaf pairs add volume and hide branches from multiple viewpoints

## Laptop rendering contract

- Branch wood and energy veins share the same MultiMesh transform as separate
  material surfaces.
- Each leaf instance contains two connected crossed cards.
- Visible module totals remain exact while repeated instances stay at or below
  31,000.
- Tree collision remains limited to the existing trunk/root proxy system.

## Completion gates

1. The front and side silhouettes fit inside a 128 m tall Christmas cone.
2. The lower three tiers overlap the trunk body without blocking the doorway.
3. All primary, child, twig, and leaf-cluster socket gaps are zero.
4. The star top is exactly 496 Godot units and the roots remain grounded at Y=0.
5. Bidirectional player traversal through the doorway passes.
6. Repeated instances remain at or below 31,000 and the new captures show no
   bare central column or disconnected branch shelves.
