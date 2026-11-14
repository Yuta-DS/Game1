# Simple Tree of Life architecture v2

This is the implementation contract for `simple_tree_architecture_v2.png`.
It intentionally reduces the existing dense canopy to a small modular kit that
can be authored in Blender, exported through glTF/GLB, and assembled efficiently
in Godot 4, including Web builds.

## Dimensions

| Zone | Size |
| --- | --- |
| Overall | 27 m high |
| Foundation | 22 m diameter x 1 m high |
| Trunk core and doorway | 6 m high |
| Lower bough zone | 8 m high |
| Heart clear zone | 4 m high |
| Upper bough zone | 6 m high |
| Crown | 2 m high |

The heart clear zone is a protected front-and-side projection volume. No bough,
leaf, ornament, or energy-vein instance may enter it.

## Blender module kit

Use eight unique render modules:

1. `TOL_Foundation` — circular platform and root seat.
2. `TOL_TrunkCore` — braided hollow trunk with the south doorway built in.
3. `TOL_HeartNiche` — recessed backing, gold halo, and separate crystal pivot.
4. `TOL_Bough` — one reusable branch with four named leaf sockets.
5. `TOL_Leaf` — one low-poly leaf-card cluster.
6. `TOL_EnergyVeins` — bevelled curves converted to an export mesh.
7. `TOL_Crown` — one small upper branch cluster.
8. `TOL_Star` — separate crown ornament.

Keep collision geometry in a non-rendering `COLLISION` collection: one platform
ring, one trunk shell, and simple root/doorway boxes. Apply transforms before GLB
export, keep origins on module sockets, and use no more than four material
families: bark, leaf, cyan emissive, and gold.

## Godot assembly

```text
TreeOfLife (Node3D)
├── Foundation (MeshInstance3D)
├── TrunkCore (MeshInstance3D)
├── HeartNiche (Node3D)
│   ├── BackingAndHalo (MeshInstance3D)
│   └── CrystalPivot (Node3D)
│       └── Crystal (MeshInstance3D)
├── BoughInstances (MultiMeshInstance3D: 8 transforms)
├── LeafInstances (MultiMeshInstance3D)
├── EnergyVeins (MeshInstance3D, emissive material)
├── Crown (MeshInstance3D)
├── Star (MeshInstance3D)
└── CollisionProxies (StaticBody3D children)
```

- Place four bough instances in the lower tier and four in the upper tier.
- Attach leaves only to exported bough sockets.
- Reject bough and leaf transforms whose projected bounds overlap the heart
  clear-zone AABB.
- Rotate the crystal pivot in Godot; the rest of the tree remains static.
- Use leaf cards in the Web preset and optional fuller clusters on desktop.
- Keep canopy collision-free; only the foundation, trunk, roots, and doorway use
  simplified collision proxies.

## Performance contract

| Budget | Target |
| --- | --- |
| Unique render modules | 8 |
| Bough instances | 8 total |
| Leaf instances | 128 Web / up to 512 desktop |
| Materials | 4 families maximum |
| Web visible triangles | under 120,000 |
| Desktop visible triangles | under 250,000 |
| Animated nodes | crystal pivot only |

These limits are conservative for Godot 4 MultiMesh rendering and avoid the
large unculled foliage batches used by the current tree.

## Build order

1. Blender greybox at the blueprint dimensions.
2. Export the eight-module GLB kit and collision proxies.
3. Assemble the Godot scene and enforce the heart clear zone.
4. Add materials and emissive energy veins.
5. Add Web leaf cards, then validate front and side captures.

