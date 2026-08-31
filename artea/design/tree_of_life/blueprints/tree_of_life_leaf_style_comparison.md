# Tree of Life — Independent Leaf Style Comparison

Both leaf styles consume the same immutable 28,800 leaf-cluster transforms.
They do not create or modify trunk, root, primary-bough, child-bough, twig,
energy, heart, doorway, or crown geometry.

## Style A — Faceted Pod

- Source: `scripts/tree_of_life/leaf_style_faceted_pod.gd`
- One closed low-poly oval surface
- 24 triangles per cluster
- Clean crystalline silhouette with no blossom decorations
- Selected with `ARTEA_TREE_LEAF_STYLE=faceted_pod`

## Style B — Blossom Bud Cluster

- Source: `scripts/tree_of_life/leaf_style_blossom_bud_cluster.gd`
- One 48-triangle faceted oval foliage mass
- Five pale crystal-bud meshes
- Six narrow, double-sided accent blades
- Three independent material surfaces
- Uses every twelfth immutable leaf socket and enlarges the local cluster 1.65x,
  producing 2,400 readable foliage masses instead of 28,800 tiny repeated pods
- Selected with `ARTEA_TREE_LEAF_STYLE=blossom_bud_cluster`
- This is the production default when no selector is provided

## Isolation contract

The production tree selects exactly one leaf script before creating its four
leaf-family MultiMeshes. Both styles receive only the shared family material
and return a new mesh. Neither style has access to the production tree node or
the other style implementation.

Changing a style therefore cannot move or regenerate the shared tree systems.
Identical comparison captures are produced by changing only the environment
selector and output directory.
