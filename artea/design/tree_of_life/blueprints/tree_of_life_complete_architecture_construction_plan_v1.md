# Tree of Life — Complete Architecture Construction Plan v1

Status: implementation plan only. This document does not authorize a commit,
push, deployment, or replacement of the current production tree.

Visual authority:
`tree_of_life_complete_architecture_xmas_v1.png`

## 1. Required outcome

Construct one continuous Tree of Life whose visible and technical hierarchy is:

`24 rootlet intakes -> 12 primary roots -> 6 buttress collectors -> 2 heart
feeders -> 18 trunk veins -> 72 trunk bough sockets -> 144 child branches ->
864 twig fans -> 28,800 leaf cards -> gold crown star`.

The finished silhouette must read as both:

- a massive, thousand-year-old living tree at root and trunk level; and
- a Christmas tree at canopy level, with the longest, lowest branches forming
  the broad base and each higher whorl becoming shorter and more upright.

No root, trunk rib, branch, twig, leaf, energy fiber, collar, heart component,
or crown element may float. Every child transform must be derived from a named
socket on its parent geometry.

## 2. Blueprint contract

| Parameter | Required value |
|---|---:|
| Total tree height | 64 m |
| Trunk/root body height | 48 m |
| Root spread | 36 m |
| Maximum canopy width | 52 m |
| Walk-through doorway | 6 m wide x 8 m high |
| Heart center | 14 m |
| Gold star diameter | 4 m |
| Primary roots | 12 |
| Secondary rootlets | 24, exactly 2 per root |
| Buttress energy collectors | 6 |
| Heart feeders | 2 |
| Trunk veins | 18 |
| Canopy tiers | 9 |
| Primary boughs | 72 |
| Child branches | 144, exactly 2 per primary bough |
| Twig fans | 864, exactly 6 per child branch |
| Lightweight leaf cards | 28,800 |

### Canopy schedule

| Tier | Height | Primary boughs | Reach | Pitch |
|---:|---:|---:|---:|---:|
| 1 | 14 m | 12 | 26 m | -12 degrees |
| 2 | 19 m | 12 | 24 m | -9 degrees |
| 3 | 24 m | 10 | 21 m | -5 degrees |
| 4 | 29 m | 10 | 18 m | 0 degrees |
| 5 | 34 m | 8 | 15 m | +5 degrees |
| 6 | 39 m | 8 | 12 m | +10 degrees |
| 7 | 44 m | 6 | 9 m | +16 degrees |
| 8 | 49 m | 4 | 6 m | +24 degrees |
| 9 | 54 m | 2 | 3.5 m | +32 degrees |

The counts sum to exactly 72. Tier phase offsets must alternate so that no two
successive whorls form one vertical fence.

## 3. Current implementation delta

The current `LaptopGravityBoughCanopy` is a useful prototype, not the target:

| System | Current | Blueprint target | Required action |
|---|---:|---:|---|
| Canopy tiers | 9 | 9 | retain tier concept |
| Primary boughs | 46 | 72 | replace tier schedule |
| Child branches | 92 | 144 | retain exactly 2 per primary |
| Repeated full bough modules | 138 | 0 | split into purpose-built modules |
| Primary modules | 0 dedicated | 72 | create runtime primary-bough asset |
| Child modules | 0 dedicated | 144 | create runtime child-branch asset |
| Twig fan modules | embedded | 864 | create runtime twig-fan asset |
| Leaf card allocation | stride approximation | exactly 28,800 | replace with deterministic allocator |
| Trunk energy reach | root to crown | root to crown | retain, remap to final geometry |

The existing full gravity-bough mesh is too expensive and semantically wrong to
repeat for every parent and child. It contains one main bough, 27 laterals, 162
twigs, and 1,296 compound leaf sockets. The final construction must derive three
lighter modules from it instead of repeating all of that geometry 216 times.

## 4. Coordinate system and scale

1. Author all new Blender source modules in blueprint meters, Y-up.
2. Establish `TreeArchitectureRoot` as the only blueprint-to-game scaling node.
3. Define one constant conversion from the 48 m blueprint body to the approved
   in-game body height. Do not apply independent scale factors to roots, trunk,
   canopy, heart, and star.
4. Keep the south entrance on local `-Z` and the trunk center at local origin.
5. Store these anchors on `TreeArchitectureRoot`:
   - `DoorwayAxis`: `(0, 0, -1)`;
   - `HeartAnchor`: `(0, 14, south_bark_surface)`;
   - `CrownSocket`: `(0, 60, 0)`;
   - `StarAnchor`: `(0, 62, 0)`.
6. Apply noise only after the exact architectural transform is known. Noise may
   alter yaw by at most 3 degrees, height by at most 0.35 m, and reach by at most
   4 percent. It may never change counts or detach sockets.

## 5. Final scene hierarchy

```text
TreeOfImagination
└── TreeArchitectureRoot
    ├── TrunkRootBody
    │   ├── RootSystem
    │   │   ├── PrimaryRootBatch (12)
    │   │   └── SecondaryRootletBatch (24)
    │   ├── DoorwayButtresses (2)
    │   ├── CentralLeader
    │   ├── CoDominantStemBatch (3)
    │   ├── BarkRidgeBatch
    │   └── BarkKnotBatch
    ├── EnergyCirculation
    │   ├── RootletIntakeBatch (24)
    │   ├── RootChannelBatch (12)
    │   ├── ButtressCollectorBatch (6)
    │   ├── HeartFeederBatch (2)
    │   ├── TrunkVeinBatch (18)
    │   ├── BoughEnergyBatch (72)
    │   ├── ChildEnergyBatch (144)
    │   └── TwigEnergyBatch (864)
    ├── WisdomHeartShrine
    ├── Canopy
    │   ├── PrimaryBoughBatch (72)
    │   ├── ChildBranchBatch (144)
    │   ├── TwigFanBatch (864)
    │   ├── BranchCollarBatch (216)
    │   ├── LeafBatchNature
    │   ├── LeafBatchMagic
    │   ├── LeafBatchTechnology
    │   └── LeafBatchSolarGlass
    ├── CrownLeader
    ├── WisdomStar
    └── CollisionProxies
```

Static geometry must use `MultiMeshInstance3D` batches. Only the heart crystal,
heart orbits, gears, and material pulses animate. There must be no per-leaf,
per-twig, or per-branch `_process()` method.

## 6. Asset construction

### 6.1 Trunk and root body

Build or retain one editable Blender source collection with these named systems:

- `TOL_Root_Primary_01` through `TOL_Root_Primary_12`;
- `TOL_Rootlet_01_L/R` through `TOL_Rootlet_12_L/R`;
- `TOL_Buttress_Left` and `TOL_Buttress_Right`;
- `TOL_CentralLeader`;
- `TOL_CoDominantStem_01` through `_03`;
- `TOL_BarkRidge_*`, `TOL_BarkGroove_*`, and `TOL_KnotScar_*`.

Construction rules:

1. Start the left and right buttresses outside the 6 m doorway width.
2. Maintain an 8 m unobstructed doorway height.
3. Merge both buttresses into the central leader above the doorway; overlap the
   meshes by at least one local bark thickness so lighting cannot expose a seam.
4. Create 12 root directions around the base, excluding a centered root on the
   south doorway axis.
5. Fork every primary root into exactly two rootlets at 45-60 percent of its
   length. The rootlet origin must be a vertex/socket on the primary root.
6. Keep every root above or touching the foundation surface. No tip may dip below
   the floating court before reaching the outer root radius.
7. Use gentle asymmetry in control points, never mirrored duplicates.
8. Use smooth curves with 8-12 radial sides for runtime meshes and higher source
   resolution only in the editable Blender file.

### 6.2 Primary bough module

Create `tol_primary_bough_runtime.glb` from the existing gravity-bough source.

Required sockets:

- `RootSocket` at the trunk graft;
- `ChildSocket_L` at 43 percent of bough length;
- `ChildSocket_R` at 61 percent of bough length;
- `EnergyIn` coincident with `RootSocket`;
- `EnergyOut_L/R` coincident with the two child sockets.

The module owns only the load-bearing major branch and its two graft collars.
It must not contain the complete 1,296-leaf source hierarchy.

Target runtime cost: at most 2,500 triangles per primary bough LOD0 and at most
900 triangles for the laptop LOD.

### 6.3 Child branch module

Create `tol_child_branch_runtime.glb` with:

- one root socket coincident with a primary child socket;
- six named twig sockets distributed from 25 to 88 percent of branch length;
- alternating left/right/up placement;
- a tapered, upward-turning distal end;
- one continuous energy conduit from root to all six twig sockets.

Target runtime cost: at most 1,200 triangles LOD0 and at most 420 triangles for
the laptop LOD.

### 6.4 Twig fan module

Create `tol_twig_fan_runtime.glb` with:

- one branch attachment socket;
- a short central twig and 3-5 small divisions;
- 34 stable leaf sockets maximum;
- one energy filament reaching every socket cluster.

The final scene instances exactly 864 twig fans: 6 on each of 144 child branches.

Target runtime cost: at most 160 triangles per twig fan before leaf cards.

## 7. Socket and attachment contract

All sockets are `Marker3D` nodes in Godot and empties in Blender. Their transforms
are exported with stable names.

For every hierarchy level:

```text
child_global = parent_global * parent_socket_local * child_root_socket_inverse
```

Required numerical checks:

- primary root to trunk gap: <= 0.01 m;
- rootlet to root gap: <= 0.005 m;
- primary bough to trunk gap: <= 0.01 m;
- child branch to primary bough gap: <= 0.005 m;
- twig fan to child branch gap: <= 0.003 m;
- leaf card to twig socket gap: <= 0.001 m.

Do not approve attachment by metadata alone. Tests must calculate the world-space
distance between each paired socket and fail above the stated tolerance.

## 8. Canopy construction algorithm

For each tier in the canonical schedule:

1. Calculate the trunk center and bark radius at the tier height.
2. Apply the tier phase offset.
3. Distribute the required primary bough count evenly through 360 degrees.
4. Reserve a south-facing projection corridor around the heart. Move a conflicting
   root socket sideways along the bark; never leave a gap and never delete the
   tier count.
5. Aim the primary local X axis radially outward.
6. Apply the required tier pitch.
7. Scale branch length to the exact reach while preserving branch thickness.
8. Attach two child modules through `ChildSocket_L/R`.
9. Attach six twig fans to every child through named twig sockets.
10. Apply bounded variation only to yaw, distal roll, and reach.

Recommended phase offsets in degrees:

`0, 15, 3, 21, 8, 28, 12, 35, 5`.

These offsets prevent the nine tiers from reading as vertical ladders while
retaining the blueprint cone.

## 9. Exact leaf allocation

The leaf count must be exactly 28,800 and remain stable across runs.

There are 864 twig fans. Allocate 33 leaf cards to every fan, then add one extra
nature leaf to every third fan:

```text
864 x 33 = 28,512
288 extra cards = 28,800 total
```

Base allocation per twig fan:

| Family | Cards per fan | Total before extras |
|---|---:|---:|
| Nature | 12 | 10,368 |
| Magic | 8 | 6,912 |
| Technology | 8 | 6,912 |
| Solar glass | 5 | 4,320 |

Add one extra nature card when `twig_fan_index % 3 == 0`, producing 10,656
nature cards and exactly 28,800 total cards.

Leaf rules:

- cards use a tapered leaf silhouette, two triangles, two-sided material;
- card origin equals the named twig leaf socket;
- only the card basis may receive a small orientation variation;
- scale variation is limited to 0.85-1.15;
- lower leaves droop slightly; upper leaves lift with their tier;
- zero-basis culling is allowed only inside the heart projection-clear volume;
- culled cards do not count as visible cards, so the allocator must refill the
  same family elsewhere on the same tier to preserve 28,800 visible cards.

## 10. Energy circulation

Construct one continuous semantic path, not separate decorative glows.

1. Each rootlet begins with one intake filament.
2. Two rootlet filaments merge into their primary root channel.
3. Twelve root channels merge into six buttress collectors in paired order.
4. Two collector groups feed the heart from left and right.
5. Eighteen trunk veins begin above the doorway merge and continue to the crown.
6. At every tier, a trunk vein terminates at or feeds a real bough socket.
7. Every primary bough conduit reaches both child sockets.
8. Every child conduit reaches its six twig sockets.
9. Every twig conduit reaches the leaf socket region.
10. The final crown veins converge under the gold star mount.

Use one scrolling cyan shader family with shared speed and phase direction.
Root pulses travel inward, trunk pulses travel upward, and branch pulses travel
outward. Geometry stays static; only UV/emission phase changes.

Energy tubes must sit 2-6 percent above the bark radius. They may be partially
recessed but may never span open air between unrelated hull samples.

## 11. Heart, doorway, and viewing corridor

- Preserve the 6 m x 8 m walk-through passage.
- Keep the violet heart center at 14 m.
- Keep all branches and leaves out of a projected south-facing heart corridor.
- The clear volume must include the complete gold cradle plus a calm bark margin.
- Energy fibers split around the heart aperture and reconnect above it.
- Gold appears only on the heart mechanism, branch graft collars, and crown star.
- Collision uses the structural shell and doorway only. Heart mechanics remain
  visual and non-colliding.

## 12. Crown and star

1. Continue the central leader beyond tier 9.
2. Add a named `CrownSocket` at 60 m.
3. Mount the 4 m gold star through a matching root socket.
4. Keep the star independent for replacement and subtle animation.
5. The trunk-to-star energy filament must terminate inside the star mount.
6. No branch or leaf may extend above the star center.

## 13. Materials

| Role | Material rule |
|---|---|
| Deep bark grooves | charcoal-brown, high roughness |
| Structural bark | warm dark walnut |
| Exposed growth ridges | medium golden brown |
| Energy | cyan/blue emissive scrolling pulse |
| Heart | violet crystal with brighter internal core |
| Engineering | restrained antique gold |
| Nature leaves | dark and mid green |
| Magic leaves | violet |
| Technology leaves | cyan-blue, slightly metallic |
| Solar-glass leaves | blue glass impression without transparency sorting |

Laptop materials must avoid real-time transparency, subsurface scattering,
screen-space refraction, and per-leaf shadows.

## 14. Collision and traversal

- Retain low-cost trunk/root collision proxies.
- Canopy, leaves, energy fibers, heart ornaments, and star are visual-only.
- Doorway collision must provide at least 0.5 m clearance around the production
  player capsule on both sides and above the head.
- Root collision is restricted to large roots that visibly rise above the court.
- Test approach, entry, passage through the center, and exit on the north side.
- The player must not catch on decorative rootlets or energy fibers.

## 15. Laptop and Web performance budgets

| Budget | Maximum |
|---|---:|
| Visible tree triangles, laptop profile | 1.25 million |
| Visible tree triangles, Web profile | 900,000 |
| Leaf cards | 28,800 |
| MultiMesh instances | 31,000 including collars/energy |
| Tree draw batches | 16 |
| Shadow-casting tree batches | 4 |
| Dynamic lights owned by tree | 2 |
| Per-frame scripts for static canopy | 0 |

LOD policy:

- LOD0: review/native high quality near the tree;
- LOD1: laptop gameplay, simplified primary/child modules and two-triangle leaves;
- LOD2: Web/distant, reduced twig stems and grouped leaf silhouettes;
- never change the nine-tier silhouette or architectural counts between LODs;
- switch mesh detail, not parent transforms.

## 16. Implementation phases and gates

### Phase A — Freeze contracts

- Record blueprint dimensions and tier schedule as constants/data.
- Add socket naming and count schema.
- Add failing structural tests before changing production construction.

Gate: tests fail only for the expected current-vs-blueprint differences.

### Phase B — Build trunk/root source

- Finish 48 m body, 12 roots, 24 rootlets, doorway, bark hierarchy, and sockets.
- Export a trunk/root-only GLB and manifest.

Gate: front, side, and top renders match the blueprint and all root gaps pass.

### Phase C — Build circulation

- Author root, collector, heart, trunk, and crown paths.
- Verify direction and continuity with canopy hidden.

Gate: one screenshot shows an unbroken root-to-crown flow without floating lines.

### Phase D — Build branch module library

- Derive primary, child, and twig modules from the gravity-bough source.
- Add stable sockets and lightweight LOD meshes.

Gate: standalone socket-closeup test proves every attachment tolerance.

### Phase E — Assemble nine-tier canopy

- Generate 72 primary transforms from the exact schedule.
- Attach 144 children and 864 twig fans through sockets.

Gate: branch-only front, side, top, and three-quarter renders show a complete
Christmas-tree cone with no foliage hiding attachment defects.

### Phase F — Allocate leaves

- Generate exactly 28,800 deterministic leaf transforms.
- Apply four semantic materials and heart-corridor refill logic.

Gate: visible count equals 28,800 and every leaf socket gap passes.

### Phase G — Integrate heart and star

- Seat the existing heart assembly at 14 m.
- Add crown socket, 4 m star, and final energy connection.

Gate: heart and star remain centered from front and side views.

### Phase H — Collision and gameplay

- Rebuild only the necessary collision proxies.
- Run the production player through the south doorway and around raised roots.

Gate: traversal, jumping clearance, and camera views pass.

### Phase I — Optimize and verify

- Measure triangles, instances, batches, lights, memory, and frame time.
- Produce native and Web LOD captures.
- Run Castle Galaxy regression tests.

Gate: every performance and visual acceptance item below passes.

## 17. Required automated tests

1. `tier_count == 9`.
2. Tier bough counts equal `[12, 12, 10, 10, 8, 8, 6, 4, 2]`.
3. `primary_boughs == 72`.
4. `child_branches == 144`.
5. Every primary has exactly two child sockets occupied.
6. `twig_fans == 864`.
7. Every child has exactly six twig sockets occupied.
8. Visible leaf cards equal exactly 28,800.
9. Leaf family totals equal the allocator contract.
10. Root count is 12 and rootlet count is 24.
11. Root, branch, twig, and leaf socket gaps stay under tolerance.
12. The heart projection corridor contains no leaf-card bounds.
13. Energy system counts match every blueprint stage.
14. Energy endpoints coincide across every merge/socket.
15. Gold star is visible, centered, and connected to `CrownSocket`.
16. Tree triangle, instance, batch, light, and shadow budgets pass.
17. Production player crosses the doorway south-to-north and north-to-south.
18. Existing gallery, minimap, station, train, and Crown Line regressions pass.

## 18. Required review captures

- complete tree front elevation;
- complete tree side elevation;
- complete tree three-quarter hero view;
- top-down radial whorl review;
- trunk/root-only front and three-quarter views;
- branch-only front/side/top views;
- child-socket close-up;
- twig-and-leaf socket close-up;
- heart clear-zone view;
- root-to-heart energy view;
- heart-to-crown energy view;
- laptop LOD comparison;
- Web LOD comparison;
- actual in-game arrival-bridge screenshot.

All structural inspection captures must be made by toggling production nodes,
not by substituting mock geometry.

## 19. Acceptance checklist

- [ ] Silhouette matches the blueprint's broad Christmas-tree cone.
- [ ] Lowest branches are longest and crown branches are shortest.
- [ ] The ancient trunk remains visible through controlled foliage gaps.
- [ ] Twelve roots and twenty-four rootlets remain grounded.
- [ ] The doorway and heart are readable from the south approach.
- [ ] Seventy-two primary boughs attach directly to trunk bark.
- [ ] Every primary bough owns exactly two attached child branches.
- [ ] Every child branch owns exactly six attached twig fans.
- [ ] Every visible leaf touches a twig socket.
- [ ] Exactly 28,800 visible leaf cards are present.
- [ ] Energy routing is continuous from rootlet to leaf and star.
- [ ] No cyan fiber spans open air.
- [ ] No branch, twig, leaf, collar, heart part, or star floats.
- [ ] The player crosses the doorway without collision catches.
- [ ] Laptop and Web budgets pass.
- [ ] Final screenshots come from the actual production game scene.

## 20. Expected implementation files

Existing files likely to change:

- `scripts/art_castle_floating_world.gd`;
- `scripts/test_tree_of_life_asset.gd`;
- `tools/measure_tree_of_life_cost.gd`;
- `tools/capture_tree_of_life_ingame.gd`;
- `assets3D/tree_of_life/tree_of_life_manifest.json`.

New source/runtime assets likely required:

- `assets3D/tree_of_life/complete_architecture/source/`;
- `assets3D/tree_of_life/complete_architecture/glb/`;
- `assets3D/tree_of_life/branch_modules/source/`;
- `assets3D/tree_of_life/branch_modules/glb/`;
- one manifest recording socket names, transforms, counts, LOD costs, and hashes;
- Blender build, validation, and render scripts for repeatable regeneration.

No implementation phase should delete the current production tree until the new
architecture passes every structural, traversal, performance, and visual gate.
