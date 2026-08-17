# Vercel pack splitting

The Web export preset injects `pck-loader.js` into
`res://web_export_shell.html`, and `export_web.sh` copies the loader beside the
split pack before deployment.

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

## Configuration

Use `export_web.sh` instead of a plain `--export-release Web`. It exports from
the project root, copies the colocated loader into the build directory, and
does the splitting.

The loader and the current shell do not conflict — the loader only intercepts
`index.pck` and is inert for every other request. Keeping the shell as-is and
restoring only the loader plus the export script is the smaller change.

The current `web_export_shell.html` remains the single maintained shell; the
head include adds only the bounded fetch shim needed by Vercel's file limit.
