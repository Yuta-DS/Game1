# TNTC World-Cutting Video Study for Artéa

Source video: [Real-Time World Cutting in Unity](https://youtu.be/rdExK08zYBI)
Source project: [ToughNutToCrack/ViewFinder](https://github.com/ToughNutToCrack/ViewFinder)
Studio page: [World cutting — Viewfinder](https://toughnuttocrack.it/projects/world-cutting-viewfinder/)

This study combines visual inspection of 60 frames from the 8:30 video, a
Whisper transcript of its narration, and the published Unity source.

## The two subtitle files

They are different documents and must not be confused:

| File | What it is |
|---|---|
| `TNTC_WORLD_CUTTING_STUDY_SUBTITLES.srt` | **Paraphrase.** A concise 12-cue study guide keyed to the sections below. Deliberately not the spoken words. |
| `TNTC_WORLD_CUTTING_VIDEO_SUBTITLES.srt` | **Actual speech.** 92 timestamped cues of the creator's narration, transcribed from the video. Obvious speech-recognition errors were corrected to the video's own terminology (frustum, Plane class, parallelepipeds, culling masks, Blender, render texture); nothing was added or invented. |

Everything in the table below is this document's own reading of the video, not
a quotation. Where the narration says something exactly, it is quoted and
attributed to a timestamp.

## Timecoded visual reading

| Time | What the video shows | What Artéa needs |
|---|---|---|
| 00:00–00:23 | Viewfinder gameplay: raise a camera, frame scenery, carry and place the framed world. | A clear two-step player loop: take a seeing, then place it as physical world. |
| 00:23–00:56 | Diagrams of polygon faces, edges and vertices; simple yellow meshes are cut. | Keep cuttable art low-poly and opt-in. Never feed streamed terrain or MultiMesh scatter into the CPU cutter. |
| 00:56–01:29 | A plane divides a mesh; triangles crossing the plane are split and the opening is filled. | Transform each world plane into mesh-local space, interpolate positions/normals/UVs, and cap each closed seam. |
| 01:29–02:16 | Two separate collider roles, stated at 01:47–01:58: **four parallelepipeds** on the frame edges "to detect objects at the edges", and **a large trapezoid to cover the entire frustum** for everything in view. The thin edge colliders do double duty — "these thin colliders also define the cutting position, so we use their transform to generate slicing planes." | Build four inward side planes and use a synchronous convex physics query for broad phase. Artéa derives the planes from the camera directly instead of from collider transforms, and needs no trigger-settling delay. |
| 02:16–02:53 | Blender level work: simple walls, floors, camera and portal pieces. | Design puzzles around the mechanic, with readable silhouettes and controlled triangle budgets. |
| 02:53–04:21 | Distant scenery is real geometry for parallax and cutting. Lighting is baked into textures and shown with unlit materials. | Preserve genuine 3D parallax in artwork worlds. Avoid relying on effects that cannot travel with captured geometry. |
| 04:21–05:08 | Player controller, carried camera animation, second-camera render texture, then freezing the image. | The Lens keeps the real geometry as the authoritative seeing and freezes the framed framebuffer as presentation feedback. |
| 05:08–05:26 | The second camera can use different visibility masks and post-processing. | Keep photo presentation independent and failure-safe; gameplay must still work if a framebuffer is unavailable. |
| 05:26–06:19 | Order matters and is explicit at 05:41: "before performing the cut, we duplicate the game objects so that they appear untouched", then the cut objects are parented to a transform representing the camera's point of view. Placement (06:02) cuts the environment, deletes the objects inside the frustum, and "re-enabled the previously cut objects". The photo can rotate. | Parent fragments to the capture point, suppress sources reversibly, cut destination geometry, reparent fragments into the world, restore the source, and rotate all fragments around one pivot. Artéa additionally **tracks** the props deleted at the destination (`_displaced`), so `restore_world()` can return the level to its authored state — the upstream deletes them outright, which is acceptable for a case study but not for a reversible child-safe mechanic. |
| 06:19–06:46 | Performance warning and acknowledgement that this is a case study. | Enforce triangle and overlap limits, refuse unsupported geometry early, and guard transactions from repeated input. |
| 07:12–08:00 | Final gameplay: camera/photo state changes, multiple placements and perspective puzzles. | Provide visible states, safe cancellation, exact collision, and puzzle-ready replay/persistence. |

## Resulting Godot architecture

1. `mesh_cutter.gd` performs local-space single-plane clipping and reconstructs
   disconnected closed seam loops separately.
2. `frustum_cutter.gd` performs the convex broad-phase query, resolves both
   authored and imported GLB hierarchies, applies four plane cuts, classifies
   fragments, and builds exact static collision.
3. `viewfinder_lens.gd` owns the capture/place/release transaction and the real
   carried geometry.
4. `lens_photo_card.gd` freezes and displays the framed image without becoming
   a gameplay dependency.
5. `lens_controller.gd` owns Q/click/T/Escape input, state, DOF, card animation,
   and persistence hooks.

The full developer and authoring guide is in
`docs/VIEWFINDER_WORLD_CUTTING.md`.
