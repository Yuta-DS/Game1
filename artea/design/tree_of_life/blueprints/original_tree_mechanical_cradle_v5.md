# Tree of Life — Original Canopy and Living Mechanical Cradle v5

## Production ownership

The original `artea_tree_of_life.blend` systems own the complete production
tree. Replacement trunk and canopy assets are retained only as references.

| Original system | Modules | Production treatment |
|---|---:|---|
| Roots | 144 | 1.14x radial envelope, pale layered living wood |
| Trunk | 122 | 1.18x radial envelope around embedded machinery |
| Branches | 480 | restored as the structural support for brass fittings |
| Leaf modules | 4,928 | original foliage restored and widened into a fir silhouette |
| Brass engineering | 225 | visible only with its matching authored branch supports |

The trunk and roots expand only radially. Their height, centreline, foundation,
and south-facing 9.5 m passage remain unchanged.

## Heart mechanism framing

The heart remains fully visible. Living wood frames it rather than covering it:

1. Six individually editable tapered wood ribs form an open oval cradle behind
   and around the astrolabe.
2. Eight short wooden mounts grow inward from the cradle and terminate at the
   main gear rim.
3. The mounts stop outside the gear teeth, leaving the crystal, spokes, runes,
   orbit rings, main cog, and idler gears readable.
4. The cradle is placed behind the gear plane and joins the enlarged trunk
   envelope, so the mechanism has an obvious structural load path into the tree.

## Original Christmas-tree canopy

The replacement `ReferenceFaithfulCrystalCanopy` and
`PoweredLivingBoughCanopy` are not instantiated. The original combined Blender
systems are used instead:

- `Branches`: the original vertices are deformed from 1.28x radial width at the
  lowest crown to 0.34x at the tip, while the crown height becomes 1.62x.
- `FoliageNature`: living green.
- `FoliageMagic`: aether violet.
- `FoliageSolarGlass`: electric technology blue.
- `WisdomStar`: retained at the crown.

The exact same deformation is applied to each original foliage system, so every
leaf remains on its authored branch. This restores the branch-to-brass alignment
from the old code and produces the requested broad-bottom, tapered Christmas-tree
silhouette. Two lower whorls copy the same original branch and three foliage
meshes at progressively wider scales, producing three visible fir tiers without
duplicating millions of replacement leaf instances.

## Acceptance contract

- Original trunk, roots, branches, three foliage systems, brass engineering,
  and crown star are visible.
- Three aligned old-code canopy tiers form a broad-bottom fir silhouette.
- Replacement trunk and canopy nodes are absent from the production tree.
- No brass engineering system is shown without its authored branch system.
- The heart has six wood cradle ribs and eight rim mounts.
- Gears remain visible and every rim mount terminates on living wood.
- Original traversal collision and Web compatibility remain unchanged.
