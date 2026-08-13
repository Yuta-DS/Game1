# Vercel pack splitting (not currently wired up)

Kept for reference. Nothing in the project references these files — the Web
export preset points at `res://web_export_shell.html` and `html/head_include`
is empty.

## What this was for

Vercel rejects individual deployment files over 100 MB. The web export emits a
single `index.pck` well past that (441.9 MB as of the last export), so it could
not be deployed as-is. These three files worked around it:

- `export_web.sh` — runs the Godot web export, then splits `index.pck` into
  ~90 MB `index.pck.partNN` files. Splits from the end and truncates the source
  after each part, so peak disk use stays near one pack rather than two.
- `pck-loader.js` — a `fetch` shim, injected through `html/head_include`, that
  intercepts the request for `index.pck`, fetches the parts, and rejoins them in
  browser memory before the engine starts.
- `artea_shell.html.unused` — the shell this project used before adopting
  `web_export_shell.html`. Hand-rolled WebGL2 probing and a branded error screen
  with a retry button. Superseded: `Engine.getMissingFeatures()` in the current
  shell covers the same detection more correctly, including WebAssembly.

## Restoring it

If web deployment moves back to Vercel, or to any host with a per-file size cap:

1. Move `pck-loader.js` back to `artea/web/pck-loader.js`.
2. Set `html/head_include="<script src=\"pck-loader.js\"></script>"` in the Web
   preset in `export_presets.cfg`.
3. Use `export_web.sh` instead of a plain `--export-release Web`. It copies the
   loader into the build directory and does the splitting.

The loader and the current shell do not conflict — the loader only intercepts
`index.pck` and is inert for every other request. Keeping the shell as-is and
restoring only the loader plus the export script is the smaller change.

## Why it is parked

The project moved to `web_export_shell.html` to stay aligned with the
`web-compatibility` branch and avoid maintaining two shells. That shell has no
pack splitting, so a Vercel deploy would fail on the 100 MB cap until the loader
is restored. Local serving and hosts without a per-file cap need none of this.
