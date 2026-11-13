# MineSpark — Celestial Enginehouse / 06

An architectural redesign, not another wall-detail repair. The previous model
is retained in `../celestial_terrace_3000/`; this proposal is a separate Blender
source and export. All images in this folder are actual Blender renders.

## The idea

A calm ivory garden terrace sits above a jewel-like municipal enginehouse.
The underside is a place with a purpose: a workshop, a sun-shaped regulator,
service lighting, and an explicit supply/return circuit. Three dressed-stone
buttresses curve back into the island instead of ending as unsupported posts.

The two bays deliberately differ. The left is warm copper, radiator fins,
gauges and the existing engine. The right is a luminous blue-green sun iris,
with swept brass vanes, nested annular braces, a recessed pressure case and
individual opal sectors. Deep shadow behind the mechanisms makes their depth
read against the pale stone. The arch is an enclosing canopy, not a second
ornamental arch pasted over unrelated rock.

The fictional premise is that steam drives the controls of an aether system;
ordinary steam is not being presented as a real way to levitate an island.

## Architectural relationships

- Deck → broad capital → continuous stone buttress → embedded rock socket.
- Carved canopy → lined, sealed service bay → sill bearing between buttresses.
- Existing boiler neck → coupled supply header → regulator upper port.
- Regulator lower port → coupled return line → existing condenser body.
- Recessed workshop is reached from the existing service balcony; the regulator
  bay is a sealed equipment alcove, not a promised walk-through passage.

The modeled pipe sections carry their start/end coordinates as editable object
properties. Their matching endpoints are tested. This does not model fluid flow,
thermodynamic feasibility, pipe supports, valve internals, or an operating engine.
The return line comes forward of the sill before dropping, then rises outside
the balcony edge. Sampled pipe-center clearance checks include the sill stones,
balcony structural floor and carved keystones; these are targeted checks, not a
complete collision certification for every fixture.

## Palette and shapes

Ivory remains the dominant surface; champagne gold marks edges, unions and
mechanical trim. Muted teal is reserved for the regulator and instrumentation.
Warm opal service lamps tie the industrial recesses to the garden lighting.
Broad curved supports, deep canopies, swept vanes and layered rings introduce
depth and hierarchy; smaller details serve those larger forms.

## Reusable façade assemblies

| Assembly | Independently editable parts |
| --- | ---: |
| Three sculpted buttresses | 90 |
| Two carved arch canopies | 112 |
| Two sealed service bays | 60 |
| Sun regulator | 80 |
| Workshop heat exchanger and instrumentation | 48 |
| Supply/return network | 40 |
| Deck-bearing lintels and returns | 24 |
| Integrated service lighting | 16 |
| Redesigned façade total | 470 |

The full asset remains 3,000 independent mesh objects. The other 2,530 objects
retain their geometry and transforms, including paving, stairs, garden, basin,
railings, cliff and existing engine/balcony. This is checked against the saved
previous model. IDs are retained; new façade names start with `CE6_` and have
an `assembly` property. Other names remain `CT3_`.

The CSV and manifest list every component. All saved faces are triangles;
smooth curves also rely on sampled profiles, bevels and shading. Select a mesh
and press Tab to edit its vertices, edges and faces.

## Optional World 1 puzzle concept — not implemented

Balance the two service valves, align the regulator's three rings with the sun
mark on the plaza, and restore the light circuit. The reward would be the first
world's sun-seal fragment. This makes the large mechanical object a potential
gameplay landmark, not merely a decorative clock. The current asset is static;
interactions, animation and world-to-world progression are future integration.

## Evidence and boundaries

`validation_report.json` records checks actually run on the source and a fresh
GLB re-import, plus preservation and modeled connection checks. Bounding-box
contact and nearest-surface tests are not stress analysis, proof of full-face
bearing, real-world engineering certification, or a complete collision audit.
The visual review is manual and does not establish pixel-exact reference matching.

No gameplay, map integration, collision/navigation, performance optimization,
branch operation, commit, push, or deployment is included. The lean-build
workflow kept the redesign to one separate asset proposal and its evidence.

## Files

- `source/celestial_enginehouse_v06.blend` — editable authoring source.
- `celestial_enginehouse_v06.glb` — self-contained, high-detail static export.
- `previews/01_hero.png` — full composition.
- `previews/02_enginehouse.png` — architecture and machinery detail.
- `design_board.html` — presentation and direct links.
- `parts_manifest.json`, `parts_catalogue.csv` — measured component inventory.
- `design_connections.json` — intended pipe route endpoint data.
- `validation_report.json` — measured source/export and relationship checks.

Build with `tools/blender/build_celestial_enginehouse_v06.py`; validate with
`tools/blender/validate_celestial_enginehouse_v06.py`. Rebuilding reads the
previous source and replaces only files in this new revision's output folder.
