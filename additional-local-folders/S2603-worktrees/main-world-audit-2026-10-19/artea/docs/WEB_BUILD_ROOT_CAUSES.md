# Web build — root cause register

Traced 2026-08-19 while chasing "Offline Guest hangs forever in the browser".
Symptoms overlapped, so the list below separates each independent root cause,
what proved it, and where it stands.

Verification harness: headless Chrome over CDP (no npm deps — Node's global
`WebSocket` talks to `--remote-debugging-port`), navigating the local build,
clicking the canvas at the Offline Guest button, and capturing console plus
screenshots. Scripts live in the session scratchpad; they are worth keeping in
`tools/` if this needs to be repeatable.

---

## 1. Hub scene missing two dependencies on web — FIXED

**Symptom.** Start screen renders, Offline Guest does nothing, forever. No
error on screen, no crash, no console output visible to a player.

**Root cause.** The Web export preset excluded `meshy*/**`, which dropped the
whole `meshy ai/` folder from the pack. `scenes/New_Hub_World.tscn` depends on
`meshy ai/Milo_Animations.glb`, and `assets3D/house scenes/artéa_signpost.tscn`
depends on `meshy ai/Artéa_Signpost_1027230400_texture.glb`. With the `.import`
remaps gone, the UIDs no longer resolved:

```
WARNING: 'res://scenes/New_Hub_World.tscn': In external resource #63,
  invalid UID: 'uid://ch7f1gvh71svv' - using text path instead
ERROR: No loader found for resource: res://meshy ai/Milo_Animations.glb
ERROR: Failed to load scene dependency: "res://assets3D/house scenes/artéa_signpost.tscn"
ERROR: Parameter "new_scene" is null.
   at: change_scene_to_packed (scene/main/scene_tree.cpp:1717)
```

Desktop presets carry no such filter, so this was web-only.

**Fix.** `export_presets.cfg:86` — `meshy*/**` narrowed to
`meshy ai/Milo_output*`. Only `Milo_output.glb` and its texture in that folder
are unreferenced; everything else the hub needs now ships. Pack grew 730 MB →
762 MB.

**Verified.** Rebuilt, replayed the click headlessly: hub loads, collectibles
spawn, inventory populates, minimap and Gabriel scroll render.

---

## 2. Stale pack parts served after any re-export — FIXED

**Symptom.** Loading bar reaches ~100% and never completes, or the build
behaves like an older revision.

**Root cause.** `tools/web.sh`'s `split_for_local()` skipped splitting whenever
`index.pck.parts.json` existed, regardless of whether the pack had changed
since. After a re-export the loader kept streaming the *previous* export's
parts — observed as a 742,174,116-byte 89-part set against a 730,059,656-byte
pack, while `GODOT_CONFIG.fileSizes` named the new size. `pck-loader.js` sets
`Content-Length` from the manifest, so the numbers disagreed and the load never
settled.

**Fix.** `tools/web.sh:94` — compare the manifest's `bytes` against the file on
disk and re-split on mismatch, clearing old parts first. The duplicated inline
pck-splitting block was removed in favor of one `split_for_local` call.

**Verified.** The rebuild printed `index.pck: stale parts, re-splitting` and
produced 91 parts matching the new 761,759,876-byte pack.

---

## 3. Browser cache mixes module sets across exports — OPEN (mitigation known)

**Root cause.** `python3 -m http.server` sends no `Cache-Control` and no
`ETag`, so browsers apply heuristic freshness to `index.js`, `index.wasm`,
`pck-loader.js` and `libterrain.*.wasm`. After a re-export a tab can pair a
cached module set with a fresh pack. `Cmd+Shift+R` only revalidates the
top-level document, not resources the engine fetches later.

**Impact.** Wasted debugging time — looks identical to a broken build.

**Next step.** Serve with `Cache-Control: no-store` (a ~10-line
`SimpleHTTPRequestHandler` subclass in place of `python3 -m http.server`), or
keep using a fresh port per build as a cache-key workaround.

---

## 4. Silent failure at the scene switch — OPEN

**Root cause.** `scripts/authentication.gd:72` (and `:100`) call
`get_tree().change_scene_to_file(HUB_SCENE)` without checking the return value.
`change_scene_to_file` returns `Error`; when the packed scene fails to
instantiate it logs to stdout and returns non-`OK`, and the game simply stays
where it is.

**Impact.** This is why problem 1 presented as "stuck forever" instead of an
error. Any future missing dependency will fail exactly as silently.

**Next step.** Check the return value and surface a visible failure, e.g.

```gdscript
var err := get_tree().change_scene_to_file(HUB_SCENE)
if err != OK:
    push_error("Hub scene failed to load: %d" % err)
    # show something on screen — the player cannot read stdout
```

---

## 5. Crown of Life story loads a texture excluded from the web pack — OPEN

**Root cause.** `scripts/viewfinder/crown_of_life_story.gd:35` points
`STONE_ALBEDO` at `res://demo/assets/textures/rock023_alb_ht.png`, and line 505
does `material.albedo_texture = load(STONE_ALBEDO)`. The Web preset excludes
`demo/**`, so on web that `load()` returns null.

**Impact.** Cosmetic and web-only — untextured stone plus error spam, not a
crash. The story scene is reachable in game via
`scripts/viewfinder/crown_story_portal.gd` and `scripts/journey_campaign.gd`.

**Next step.** Move the texture out of `demo/` into a shipped assets folder
(preferred — nothing else should depend on a plugin demo folder), or add the
single file to the Web preset's `include_filter`.

---

## 6. Terrain3D material exceeds the WebGL2 uniform buffer limit — OPEN

**Root cause.** Once per hub load:

```
ERROR: Condition "p_ubo_size > uint32_t(Config::get_singleton()->max_uniform_buffer_size)" is true.
   at: update_parameters_internal (drivers/gles3/storage/material_storage.cpp:1109)
```

The Compatibility (GLES3) renderer is the only option on web, and its uniform
buffer ceiling is smaller than the desktop backends'. The oversized uniform
block comes from Terrain3D's shader — its texture arrays live inside the
GDExtension binary (`addons/terrain_3d/bin/libterrain.web.release.wasm32.wasm`),
not in project shader source.

**Impact.** That one material does not receive its parameters correctly on web.
Not fatal; the hub renders.

**Next step.** Reduce Terrain3D's enabled texture slots, or accept it. Worth
confirming against a Terrain3D release note before spending time — this is an
upstream constraint, not project code.

---

## 7. Benign noise — no action

- `[Firebase Error] >> Unable to read .env file at path 'res://addons/godot-firebase/.env'`
  — the addon looks for optional config that is deliberately absent. Offline
  Guest bypasses auth anyway (`SESSION LOCKED: API Database completely bypassed`).
- `WARNING: instance_reset_physics_interpolation() is deprecated` — a Godot 4.7
  compat shim called from an addon; harmless until it is removed upstream.
- `The AudioContext was not allowed to start` — standard browser autoplay
  policy, resolves on first user gesture.

---

## Audit performed

Every `res://` reference in shipped `.tscn` / `.gd` / `.tres` files was matched
against the Web preset's 33 exclude patterns. 155 raw hits, but all except
seven are excluded files referencing other excluded files (proton_scatter demos,
`artifacts/` capture outputs, `scripts/test_*.gd`). Of the seven referenced by
files that actually ship:

| Reference | Verdict |
| --- | --- |
| `crown_of_life_story.gd` → `demo/assets/textures/rock023_alb_ht.png` | Real — problem 5 |
| `art_castle_story_railway.gd:1904` → `crown_line_lego_train.blend` | Safe — `set_meta("source_blend", …)` provenance string, never loaded |
| `art_castle_floating_world.gd:837` → `artea_tree_of_life.blend` | Safe — same provenance pattern |
| `proton_scatter/tests/unit_testing.tscn` → demo `grid.png` | Dead — addon test scene, never loaded at runtime |
| 3 × `scripts/tree_of_life/capture_*.gd` → `artifacts/…` | Dead — editor capture tools writing output paths; they ship only because the `scripts/capture_*.gd` exclude does not match the `scripts/tree_of_life/` subfolder |

The last row is worth tidying: broaden that exclude to `scripts/**/capture_*.gd`
so tooling stops riding along in the player build.
