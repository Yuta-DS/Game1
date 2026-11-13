# Tree of Life — Original Big-Root Style Integration v4

## Architecture ownership

The production Tree of Life is the original authored asset, not the later
`simple_trunk_core` replacement. Its Blender/GLB systems remain authoritative:

| Original system | Authored content | Runtime rule |
|---|---:|---|
| Roots | 144 named modules | Keep visible, full scale, and structurally continuous |
| Trunk | 122 named modules | Keep visible as the braided load-bearing core |
| Foundation | Original deep foundation | Preserve alignment and scale |
| South passage | 9.5 m clear gothic opening | Preserve gameplay route and two-pillar collision |

Source: `assets3D/tree_of_life/source/artea_tree_of_life.blend`  
Runtime: `assets3D/tree_of_life/glb/artea_tree_of_life.glb`

The standalone `simple_trunk_core.blend` remains an editable visual reference
and validation asset only. It must not be instantiated inside the production
Tree of Life.

## Redesign applied to the original geometry

The newer design contributes a surface and detail language without changing the
old tree's silhouette:

1. Pale exposed sapwood bands alternate with recessed dark cambium across the
   original trunk and root surfaces.
2. Eighteen cyan energy paths are sampled from the original bark hull, so they
   follow the authored trunk fibers and ease naturally into the broad root flare.
3. The separate detailed heart shrine replaces only the old joined crystal
   system. No trunk or root mesh is hidden to make room for it.
4. The expanded century canopy, semantic blue/violet/green leaves, and restrained
   gold engineering collars remain visual-only and do not replace the trunk.
5. The original big-root collision remains twelve radial root proxies plus two
   trunk pillars; no collision is taken from the reference trunk asset.

## Acceptance contract

- `SimpleTrunkCore` is absent from the production scene tree.
- Original `Trunk` and `Roots` render systems are visible and restyled.
- Original root and trunk module counts remain recorded as 144 and 122.
- The 9.5 m southern player passage remains unobstructed.
- Cyan veins are pinned to the sampled original bark surface.
- The rotating heart, larger century canopy, and technology/magic/nature leaf
  palette remain compatible with Godot Web rendering.

