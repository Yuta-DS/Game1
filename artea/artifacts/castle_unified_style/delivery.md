# Castle route — reference-tower style pass

Implemented locally on 28 August 2026. Production has not been updated.

## Audit and changes

- Compared the original imported castle colour atlas with the generated stair tower, roof, bridge, courtyard and upper entry. The generated stone was too blue/pale, with dense brick grids and inconsistent pointed window overlays.
- Introduced one shared finish: wall `9198a2`, raised stone `818c91`, structural trim `687379`, dressed floor `919fa7`. These colours come from the original atlas, which remains untouched.
- Replaced continuous wall brickwork with 129 shallow, batched masonry patches. Retained the red roofs, royal planting, central fire, animated fountain and oak door.
- Added 20 rounded tower windows aligned between the actual structural bands; matched the barbican windows and ground-entry arches. Removed extra pointed frames covering the imported castle windows. Door and frame now share one rounded arch profile.
- Matched bridge, roof barriers, coping, flowerbed stone and upper stair finishes. Retained floor flower inlays as colour-only shaders, with no extra floor layer or displacement.
- Fixed the outer soffit/parapet joint to share the same lower edge, and removed its duplicate underside face.
- Diagnosed reversed helix normals using an isolated geometry probe and colour-separated in-game render. Corrected normals and triangle orientation on visual-only bands. The bright underside sliver is absent in the final close-up.
- Added regression checks for the shared lower edge, outward-facing normals, window/band clearance, material palette, botanical preservation and batched decorative geometry. The material pass leaves all 416 route collision shapes/transforms unchanged.

## Verification

Passed 19 test executions (18 scripts; the material-render test ran in two renderers):

- Castle reference style and geometry; castle redesign.
- Spiral route: three lanes and the crown circuit.
- Royal entry: 54 tread/floor probes, 18 underside probes, three ascent/descent lanes, four wall impacts/escapes, jumping and live gallery entry.
- Royal courtyard: 28 floor probes, four gate lanes in both directions, fire circuit, stairs, six wall impacts/escapes and jumping.
- Entrance and complete packed-player castle route.
- Masonry bridge: three lanes both ways, 72 floor/feet probes, six sprint impacts and escapes.
- Rooftop garden and rooftop barrier safety.
- Fountain deformation, droplets, water animation, rim collisions and garden access.
- Gallery flow, minimap, embedded world, station jumping and Crown Line.
- Web environment compatibility policy.
- Mobile and OpenGL Compatibility renderer material tests: the dressed-floor shader and reference StandardMaterial rendered with zero sampled colour difference in both renderers.

The final screenshots are actual native Godot Mobile-renderer captures, not concept renders. No public-browser or other-operating-system gameplay verification is claimed.

## Delivery limitation

Web export preflight still finds two existing preview scenes whose source models are absent:

- `textures/grass_common_short_2.tscn` → `assets3D/stylizedNature/Grass_Common_Short.gltf`
- `textures/common_tree_12.tscn` → `assets3D/stylizedNature/CommonTree_1.gltf`

The Web preset exports all resources and does not exclude these scenes. Their source files and the export configuration were left unchanged. No export, production deployment or production-browser verification was performed in this delivery cycle; there is no new deployment ID. Existing production remains https://artea-web.vercel.app/.

Disk space also became critically low during verification (under 400 MiB available at the last check). No user assets, existing builds, or unrelated work were deleted to free space.

Unrelated startup diagnostics: an existing music UID falls back to its valid file path; one parallel hub run collected an item before inventory initialization and logged an inventory warning. Castle traversal assertions still passed; no inventory code was changed.

Concurrent-work recheck: one intermediate run encountered a new parse error in `scripts/curling_surf.gd` from unrelated ocean work. That source was corrected externally while this task was running; this task did not edit it. Its isolated parser check then passed, and the final full-hub spiral test passed with no script errors (`/tmp/castle-style-spiral-final.log`). The remaining delivery blockers are the missing preview assets and available build storage, not that transient ocean error.

## Screenshots

- `01_full_castle_route.png`: entire route and original castle.
- `02_spiral_and_rooftop.png`: reference-style stair tower and roof.
- `03_rooftop_bridge_court.png`: garden, fountain, bridge and front courtyard.
- `04_royal_entrance.png`: upper stair and door/frame.
- `05_door_and_reference_tower.png`: original and generated architecture together.
- `06_stair_underside.png`: exterior stair detail.
- `07_ground_arrival.png`: terrain entrance and retaining foundation.
- `08_soffit_from_below.png`: final clean underside.
- `audit_soffit_parts.png`: diagnostic colour separation, not the final finish.

No commit or push was made in this turn. Unrelated workspace edits were preserved.
