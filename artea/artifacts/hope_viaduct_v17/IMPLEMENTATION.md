# Hope Path Ridge — Dawn Wing Viaduct v17

The fourth Mind Spark island keeps its original 120 m walkable map footprint, both bridge approaches, four-block Hope Path jump course, and flat accessible lane. Its visual shell is now a distinct warm, heavenly industrial silhouette: one large oval load ring on each flank, twin arched machine sanctums, teal recessed pressure halls, radiant central lift turbines, ivory bearing piers, copper service pipes, split lower keels, two lift-engine houses, buoyancy drums, and four moving 20:12 gear assemblies. The rejected exposed feather/spike motif and the later stacked pressure-hull panel treatment are both removed.

## Above-ground district v18

The formerly open upper deck is organized as a celestial-industrial civic garden. Its primary landmark is the eight-column Aether Lift Pavilion, crowned by 24 individually modelled sunrise-canopy panels, a brass oculus, radial support ribs, opal lantern, luminous lift core, and vertical turbine halo. Three walk-through truth portals establish the quest destination. Two monumental arched condenser houses connect visibly to the pavilion through crown and deck-feed pipes. Twelve curved ivory-and-gold garden terraces frame the quiet edge of the island, while the original Hope Path slabs receive ivory plinths and gilt reveals without changing their collision or progression.

All new upper-district architecture is assembled from reusable named Godot components. It intentionally adds no collision to the established bridge corridors, four-block jump course, or accessible side lane.

## Asset evidence

- Editable Blender source: `assets3D/mind_spark/celestial_dawn_v17/source/island_04_3000.blend`
- Runtime GLB: `assets3D/mind_spark/celestial_dawn_v17/island_04.glb`
- Component BOM: `assets3D/mind_spark/celestial_dawn_v17/bom/island_04_parts.csv`
- Exactly 3,000 non-empty editable triangle-mesh components
- 396,382 runtime architecture triangles in nine GLB mesh groups
- 16,631,184-byte runtime GLB; 9,872,312-byte editable Blender source
- 842 perimeter guard samples, with zero uncovered samples outside the two bridge openings

## Validation

`validation_report.json` independently verifies finite vertices, triangular positive-area faces, no mesh repairs, exact source/export coverage, four separate motion assemblies, player-scale guards, guard placement inside the floor edge, and clear bridge approaches.

The complete 15-test Godot regression suite passes. The focused production checks prove that a real player capsule is stopped at four guarded edges, the lift gears animate at the designed 20:12 ratio, the full v18 upper-district component inventory exists, and the existing Hope Path course and accessible lane remain present.

## Honest scope

The 3,000 parts are editable Blender components, not 3,000 Godot draw calls. Related small fittings are grouped where necessary for the exact source count, and runtime geometry is batched into nine mesh groups for practical rendering. The lift system is a designed kinematic fantasy mechanism, not a physical steam-pressure simulation.
