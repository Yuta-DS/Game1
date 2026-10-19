# Vercel pack splitting

The Web export preset injects `pck-loader.js` into
`res://web_export_shell.html`, and `export_web.sh` copies the loader beside the
split pack before deployment.

## What this is for

Vercel rejects individual deployment files over 100 MB (Cloudflare Pages: 25 MB).
The web export emits a single `index.pck` far past that, so it cannot be
deployed as-is. These files work around it:

- `export_web.sh` - runs the Godot web export, then splits `index.pck` and
  `index.side.wasm` with `../split-pack.sh` into 8 MB content-hashed parts
  (`parts/index.pck.<hash>.partNN`) plus a manifest (`index.pck.parts.json`)
  listing them. It also copies in `vercel.json` and `.vercelignore`.
- `pck-loader.js` - a `fetch` shim, injected through `html/head_include`, that
  intercepts the requests for `index.pck` and `index.side.wasm`, reads the
  manifest (never cached), and streams the listed parts into the engine in
  order. Up to 4 parts download at once (`?parts=N` overrides it for
  measuring). A failed part is retried after 0.5, 1.5 and 4 s; after that a
  Retry overlay pauses the download until the player presses it, and it
  carries on from the failed part without refetching the rest (issue #34).
- `vercel.json` - serves `parts/` as `immutable` and everything else
  `no-cache` (ADR-0002, issue #33).
- `.vercelignore` - keeps the unsplit originals out of the upload, so the build
  directory is left intact for local serving.
- `artea_shell.html.unused` - the shell this project used before adopting
  `web_export_shell.html`. Superseded: `Engine.getMissingFeatures()` in the
  current shell covers the same detection more correctly, including WebAssembly.

## Caching (ADR-0002)

Part names carry the SHA-256 of the whole file they were cut from, so a new
export always produces new names. That makes them safe to cache forever: a
repeat visit to an unchanged build downloads only the two part manifests and
~130-byte revalidations of the HTML, js and wasm (measured: 7.4 KB, against
755 MB for the first visit). Files with fixed names stay `no-cache`, so a new
export can never be paired with old engine modules. Local `./web` keeps
`no-store`.

## Configuration

Use `export_web.sh` instead of a plain `--export-release Web`. Local `./web`
and `../deploy-cloudflare.sh` split through the same `../split-pack.sh`, so all
three ship the same layout.
