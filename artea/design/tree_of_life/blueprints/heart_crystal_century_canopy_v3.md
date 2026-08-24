# Tree of Life — Heart Crystal and Century Canopy v3

This sheet defines the heart and canopy style layer. In production it extends
the **original** `artea_tree_of_life` architecture described by
`original_tree_big_root_style_integration_v4.md`: the original 144-module big
root system, 122-module braided trunk, and 9.5 m south passage remain the
structural source. The later 18 m simple trunk is a standalone reference asset
only and is not instantiated in the production tree.

## Design meaning

The tree is one living machine, not separate fantasy and technology props:

| System | Meaning | Visual rule |
|---|---|---|
| Cyan diamond | technology and scientific knowledge | crisp eight-sided bipyramid, bright inner core |
| Violet leaves/runes | magic | saturated aether violet, never painted onto the wood |
| Blue leaves | technology/science | electric blue with a harder, glassier surface |
| Green leaves | nature | two-value living green with a soft rough surface |
| Gold mechanics | engineering | only at frames, grafts, spokes, gears and joints |
| Pale wood fibers | life and age | continuous root-to-crown load paths over dark cambium |

## Heart assembly

The heart is centered in the existing niche and remains readable from the
South Arrival Bridge.

1. `HeartCrystalSpin` owns the outer cyan diamond and rotates once every 14 s.
2. `HeartShrineCrystalCore` counter-rotates to prevent the gem reading as a
   flat icon.
3. `HeartGearMain` is the structural gold ring with 20 teeth.
4. Three `HeartAstrolabeOrbit` pivots cross at different tilts and speeds.
5. Eight `HeartFrameRune` sockets alternate cyan and violet jewels.
6. Eight gold radial spokes visually transfer load and energy into the bark.
7. Two nine-tooth idler gears mesh into the main ring and counter-rotate.
8. The dark backing plate keeps the crystal silhouette legible against cyan
   energy veins.

All moving pieces are independent nodes in Godot. Blender retains the crystal
spin pivot, three orbit objects, eight rune sockets and eight spokes as
separate editable components.

## Century-old canopy

The existing Christmas-tree whorl logic is retained, but each bough is extended
18–22 percent and the foliage scale increases from 1.18 to 1.34. Lower whorls
droop farther than the old version, while crown whorls lift progressively.
This creates an ancient, load-bearing silhouette rather than a young conical
ornamental tree.

Every runtime bough root receives one instanced gold mechanical collar. Gold is
excluded from leaf materials. The heart projection-clear volume remains active
at every depth, so longer branches and larger leaves cannot cover the crystal.

## Implementation contract

- Blender: separate named components for every major shape and a looping crystal
  spin animation.
- Godot: procedural astrolabe and semantic leaf materials; Web-safe MultiMesh
  batches for branch collars and leaf families.
- Runtime animation: looping tweens, no skeletons and no per-frame crystal code.
- Collision: unchanged; canopy and shrine remain visual-only.
- Performance: no extra leaf draw families, one extra instanced collar draw,
  and low-poly procedural heart parts.
