# Mind Spark Island One — Gate Architecture Kit

## Scope

This pass builds only the World Gate arrival architecture on top of the existing
Island One foundation. It does not replace the island deck, retaining shell,
undercroft machinery, Wisdom Tree, or main garden.

The current production revision treats this as Island One's Thought
Constellation sanctum gate—not a portal or bridge to another island. Its visual
hierarchy is deliberately limited to one pointed arch, two bearing pylons,
three panel tiers per leaf, two recessed drive engines, and one Wisdom-flower
crown.

## Revision 2 clarity rules

- No clock face, astrolabe dial, or freestanding circular machine crowns the gate.
- Power conduits run behind the masonry instead of drawing lines over the facade.
- Each side machine exposes one causal chain: vessel → connecting rod → flywheel → lock bar.
- Gold marks load paths, hinges, controls, and powered feedback only.
- Teal panels are grouped into three large fields per leaf; scattered shards are removed.
- The closed leaves form one Wisdom seal, while the open leaves preserve a twelve-metre route.

## Player-facing purpose

The gate must read in this order from the bridge:

1. a clear illuminated approach;
2. a sheltered glass threshold;
3. six readable operator stations around a central compass;
4. a powered route toward the living-network district.

The processional corridor remains 40 metres clear. Static decoration stays
outside the operator and bridge paths.

## Reusable assembly hierarchy

| Assembly | Families | Variants | Main contents |
| --- | ---: | ---: | --- |
| `01_CivicTerraceKit` | 3 | 8 | radial court, concentric inlays, processional axis |
| `02_AetherConservatoryKit` | 6 | 9 | ribs, triangular panes, mullions, columns, capitals |
| `03_ThresholdStructureKit` | 5 | 9 | portal piers, curved voussoirs, reveals, keystone |
| `04_BeaconTowerKit` | 3 | 5 | plinth, pressure drum, glass beacon crown |
| `05_LandscapeTrimKit` | 5 | 8 | planters, soil beds, blooms, route markers |
| **Total** | **22** | **39** | one shared gate kit |

The complete portal core is the only gate-specific landmark. Every other family
can be reused as a smaller bridge pavilion, garden shelter, observatory frame,
balcony, terminal court, or machine gallery.

## Geometry rules

- Roof: six longitudinal bays, twelve curved bays, two triangles per cell —
  exactly 144 editable glass panes.
- Structure: seven transverse vault ribs, thirteen longitudinal mullions, ten
  columns, twenty spring braces, and seven ridge keystones.
- Threshold: two structural piers and an eighteen-segment smooth curved arch.
- Controls: six stations, three compass rings, two pressure gauges and two
  governor rotors remain independent gameplay nodes.
- Repetition uses named components and mirrored instances. No decoration is
  baked into a texture when it affects silhouette or player readability.

## Materials

- warm heavenly ivory: primary structural mass;
- champagne brass: edges, compression bands and interaction hierarchy;
- teal aether glass: roof, lenses and powered-state feedback;
- restrained lavender/green: thought and hope landscaping only.

## Runtime strategy

The source hierarchy remains inspectable and reusable. Static architecture may
be safely batched by the existing World One optimisation pass, while Compass
controls, gauges, rotors, reward projection and bridge socket retain authored
nodes for interaction and animation.

## Acceptance checks

- Existing Island One foundation and undercroft remain present.
- All five kit assemblies exist beneath `GateArchitectureKit`.
- Family count is 22 and reusable variant count is 39.
- The roof retains 144 triangle panes, 13 longitudinal mullions, 20 braces and
  seven ridge keystones.
- Six puzzle controls and all Compass save/replay behaviour still pass.
- Tree and main garden geometry are unchanged.
