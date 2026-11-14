# v16 Web delivery

Date: 29 August 2026 (Australia/Sydney).

- Standard non-Mono Godot 4.7.1 Web export succeeded.
- Full native suite: 14/14 pass; independent Blender geometry audit passes.
- Web package: 1,137,428,644 bytes in 136 streamed parts.
- Exported package contains the v16 island GLB, barrier JSON and compiled
  machinery controller (checked across all pack parts).
- Vercel project: existing `artea-web`, `prj_qPPpOnkYg3Bww3uUFWjegD7TqAFR`.
- Deployment: `dpl_DrQ6medAyqKNNmfDYa2xb69jvE1s`, state `READY`, production.
- Immutable URL: https://artea-66ero94q6-dsovann80-2407s-projects.vercel.app
- Public URL: https://artea-web.vercel.app/
- Initial implicit-scope deployment was rejected. Explicit scope
  `dsovann80-2407s-projects` succeeded without changing authentication.
- The existing short alias initially pointed at the previous deployment;
  reassigned that same alias to this release and verified with Vercel inspect.

## Browser result

Loaded the cache-busting public URL in the Codex Chromium browser. The loader
advanced through the complete 1,086 MiB download, reported `engine started`,
and rendered the Artéa start screen. Offline Guest entered the 3D hub. Movement
input changed the view/player position; M opened and closed the full map.
No WebGL2 feature error, missing v16 resource error, or script exception was
observed during that flow.

One pre-existing nonfatal console error remains: Firebase cannot read its
`res://addons/godot-firebase/.env` configuration. Guest startup works; this is
not evidence that online account services are configured or tested.

Browser coverage is startup, guest hub and map controls. The Astral island was
not manually reached through the browser's short keypress controls. Its real
capsule traversal, barriers and animation are verified by native tests, its
visuals by actual Godot compatibility renders, and its resources by the final
exported-pack check. No browser/mobile frame-rate certification is claimed.

No branch, commit or push was made.
