# MineSpark terrain — art-direction correction 02

Status: proposed visual target, not a rebuilt Blender kit. The previous 50-part
library remains available as a construction prototype; its appearance is not
the accepted art direction. No map placement, gameplay, branch, commit, push,
or deployment is part of this concept pass.

## What missed the brief

The delivered kit answered modularity and triangle topology but not the requested
visual identity. Flat slabs, shallow trim, repetitive triangular floor lines and
generic support blocks made it read as a construction prototype. Ivory and brass
alone do not establish the architecture of a wealthy city of invention.

The correction is **sculptural civic architecture with integrated steam
engineering**, not simply a higher polygon count or more ornamental gears.
Modern means precision, clarity and comfortable public space here—not minimalism.
Warm means inviting stone, amber light and human-scale details—not a sepia filter.

## Reference basis and interpretation

- In [Arnaud-Loris Baudry's production-design interview](https://80.lv/articles/riot-games-on-designing-arcane-s-piltover-zaun),
  Piltover's design evolves toward Art Deco influence, geometric order,
  mechanical beauty and visible history. For this project, interpret those ideas
  as symmetrical bays, tapered piers, stepped profiles and geometric metalwork.
  Do not treat all Victorian ornament as Piltover; the interview also associates
  Victorian/industrial assemblage and asymmetrical ornament with Zaun.
- The [Science Museum's 1788 Boulton and Watt engine](https://collection.sciencemuseumgroup.org.uk/objects/co50948/rotative-steam-engine-by-boulton-and-watt-1788-beam-engine-steam-engine)
  is a reference for connected shafts, supports and working mechanical parts.
  Our compact terrain machinery is a fantasy adaptation, not a historical replica.
- The [V&A's account of the Great Exhibition](https://www.vam.ac.uk/articles/the-great-exhibition-of-1851)
  provides a precedent for repeated prefabricated structural parts. Use this
  modular construction principle without reducing each assembled object to a box.

These are deliberately mixed historical and fictional references, not a claim
that Art Deco and the early Industrial Revolution were the same period.

## Shape and material rules

1. **Large forms first:** substantial arched foundations, tapering piers, strong
   stone courses, organic rock strata. Recognizable even in a flat silhouette.
2. **Medium forms next:** recessed panels, stepped cornices, cast-iron ribs,
   bearing housings, fluted pilasters, removable machinery covers.
3. **Small details last:** fan-pattern brass inserts, engraved plates, flange
   joints, grouped rivets, dial bezels and edge wear. Not evenly spread noise.
4. **Connected machinery:** visible supply line → valve → cylinder; connecting
   rod → crank/flywheel → shaft bearing; return line → condenser. The pipes and
   rotating parts need intentional endpoints. Static concept detail does not
   establish a working simulation.
5. **Quiet circulation:** ornamental richness belongs to edges, supports and
   focal bays. Walking floors stay flat, navigable and comparatively calm.
6. **Editable triangular meshes, not triangular wallpaper:** triangulate final
   geometry; show broad fractured planes in rock. Do not draw every mesh edge
   across finished stone or use faceting to disguise generic forms.

Suggested palette, not measured material coverage:

| Role | Direction |
| --- | --- |
| Main mass | Warm limestone `#DBCDB3`, ivory `#F1E5CE` |
| Refined metal | Champagne brass `#B79254`, dark bronze `#554334` |
| Steamwork | Rose copper `#AE6E49` |
| Deep accents | Petrol enamel `#244E53`, warm slate `#454647` |
| Hospitality | Honey amber `#E7B467`, sage `#7B8969` |

Use satin highlights, painted tonal variation, small contact wear and darker
recesses. Avoid uniform plastic roughness, blanket rust, gold on every edge,
neon-blue outlines and random cogs. Luxury comes from proportion and craftsmanship.

## Changes to the eight terrain families

| Family | Revised appearance | Reusable pieces to author |
| --- | --- | --- |
| Floating rock base | Asymmetrical stratified masses with deep fractures; engineered supports disappear into rock | Crown mass, shoulder strata, hanging keel, fracture wedge, iron saddle, anchor socket, service recess |
| Civic deck | Calm stone field framed by fan/compass inlay and a thick molded edge | Field stone, border stone, radial wedge, brass inlay, joint, substrate, stepped fascia, undercut molding |
| Retaining band | Repeated monumental arch bays with tapered piers and shadowed panels | Plinth, pier core, fluted face, arch springer, voussoir, keystone, cornice courses, recessed panel, fan grille, anchor cover |
| Bridge landing | A weight-bearing civic abutment with elegant mechanical bearings | Spread footing, pier, capital, curved iron rib, flange, gusset, bearing seat, axle collar, inspection plate, deck-edge course |
| Ramp and stairs | A ceremonial route integrated with the terrace, not an isolated wedge | Ramp core, stone skin, curved cheek, step, nosing, landing border, curb, end plinth; rail system as a separate later attachment |
| Maintenance shelf | A refined service balcony with a believable support and maintenance access | Frame rail, grate cassette, curved bracket, diagonal tie, mounting saddle, bolts, pipe clip, removable inspection cover |
| Planter bed | A civic stone planter with recessed warm-metal panels | Molded foot, wall core, recessed panel, corner pier, coping, removable soil tray, separator, drainage layer, irrigation entry |
| Basin shell | A shallow condenser/reflection basin, tied to the district's engineering | Liner, wall, corner, stepped coping, overflow slot, drain bezel, grille, copper inlet, service cover |

The concept sheet may use restrained planting, lights or water to communicate
atmosphere. Those do not change this terrain asset scope or establish implemented
vegetation, lighting, water or machinery systems.

## First Blender proof: one retaining/landing bay

Before repeating the design across all eight families, build one representative
bay that contains stone, iron, brass, copper, rock and a calm walkable surface.
This is a proposed production step, not work completed in this document.

```text
          QUIET CIVIC WALKING SURFACE
      stone field + selected brass inlay
   ====================================
        stepped coping / shadow reveal
   tapered pier   segmented arch   tapered pier
      |         recessed fan panel        |
      |      iron rib + shaft bearing     |
      |   copper pipe + service opening   |
   ____footing_____________________footing____
           embedded anchors / rock strata
```

Break the hero bay down into independently reusable stone courses, arch blocks,
metal ribs, grilles, bearing covers, flanges and fasteners. Use linked instances
for repeated pieces. Do not scale small hardware together with a whole island.
Existing island footprints, bridge endpoints, route widths and heights remain
the integration constraints; a concept composition is not an authoritative map.

### Review gate before mass production

- The silhouette and depth must read as designed architecture without materials.
- A player-distance view must show piers, arches and recesses, not just micro-detail.
- A close-up must show purposeful joints and crafted material transitions.
- Use the same neutral lighting for an old/new comparison; attractive lighting
  alone cannot pass this review.
- Provide beauty, clay, wireframe and exploded views of the *actual Blender bay*.
- Keep source geometry editable; triangulate the export and verify it separately.
- Test modular joins, walking clearances and actual engine cost before making
  production or Web-performance claims.

## Concept deliverable

![Terrain direction 02 concept](/Users/davidsovann/S2603/artea/docs/concepts/mind_spark_terrain_direction_v2.png)

The accompanying image is AI-generated concept art made with the built-in image
generation tool. It communicates the desired appearance, not a Blender render,
dimensioned engineering drawing, fitted map replacement or verified mechanism.
The exact prompt is preserved in `MIND_SPARK_TERRAIN_ART_DIRECTION_V2_PROMPT.txt`.
