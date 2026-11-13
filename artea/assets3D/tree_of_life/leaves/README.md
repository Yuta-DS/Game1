# Artéa reference leaf library

This leaf-only library recreates the four objects in the supplied Tree of Life
reference. It does not contain or modify tree geometry.

## Inspected designs and component breakdown

- **Living Leaf Fan** — seven independent, separately named serrated forest blades; one gold
  perimeter module; cyan midrib and side-vein network; seven energy petioles;
  crystal power node; black contact; brass core and connector bands. The large
  energized fan in the lower reference uses this same geometry with stronger
  cyan emission.
- **Magic Rune Leaf** — violet faceted blade; gold perimeter; cyan midrib and
  asymmetrical side veins; three editable glyph strokes; black/brass base.
- **Solar-Glass Science Leaf** — translucent cyan cellular blade; gold frame;
  diagonal structural midrib; irregular stained-glass cell network;
  black/brass base.
- **Emerald Sensor Leaf** — compact emerald blade; gold perimeter; cyan circuit
  traces; circular sensor rune and three signal marks; black/brass base.

Every leaf root is reusable and collision-free. The dense blade grids provide
at least 10,000 directly editable vertices per object, while veins, outlines,
connectors, nodes, and glyphs remain separate named mesh modules.

## Files

- `source/artea_leaf_library.blend` — editable Blender source containing all
  four leaf roots.
- `glb/artea_leaf_library.glb` — combined Godot-ready library.
- `glb/individual/*.glb` — four centered, independently reusable leaf objects.
- `textures/living_leaf_olive_albedo.png` — generated seamless olive, moss,
  waxy and weathered base-color texture used by all seven Living leaflets.
- `textures/living_branch_teal_albedo.png` — generated seamless blue-green,
  fibrous living-stem texture used by the trunk, branches, midribs and veins.
- `leaf_library_manifest.json` — component counts, budgets, and export paths.

Regenerate with Blender using `tools/blender/build_artea_leaf_library.py` and
validate with `tools/blender/validate_artea_leaf_library.py`.
