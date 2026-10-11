# Web load baseline

The numbers every load-time ticket is measured against (issue #32). Re-measure
after a change and compare with the tables below.

## How to measure

```sh
./web verify                                      # local build (serves artea/builds/web)
./web verify --url https://artea-web.vercel.app/  # a deployment
node artea/tools/web-compression-report.js        # gzip/brotli savings on the local build
```

`./web verify` loads the page in headless Chrome with the cache disabled, so
every run is a cold first load. It prints, besides the usual PLAYABLE check:

```
first load (cache disabled):
  bytes transferred to hub: 755122206 (720.1 MiB, 75 requests)
  time to engine started:   5.7 s
  time to hub:              15.2 s
  bytes transferred total:  755126302 (720.1 MiB, 76 requests, 0 failed)
METRIC bytes_to_hub=755122206
METRIC time_to_engine_s=5.7
METRIC time_to_hub_s=15.2
METRIC bytes_total=755126302
```

- **Bytes transferred** is what crossed the wire (after any Content-Encoding,
  headers included). It was checked against the files on disk: the local count
  matches the requested files to within 19.5 KB of HTTP headers.
- **Time to hub** runs from navigation to the hub's `Successfully spawned` log.
  It includes the smoke test's own fixed pause of about 4.5 s between the engine
  starting and clicking Offline Guest, so treat it as a comparable number, not
  the pure loading time. **Time to engine started** has no such pause, and every
  build logs it.
- The `METRIC` lines are for scripts and CI to grep. `-1` means not reached.
- Per-request bytes go to `artea/builds/smoke/requests.log`, largest first.

## Baseline (2026-10-11)

Local build: `main` at `df299eeb`, exported with Godot 4.7.2, served by
`./web` on localhost (no network limit, so this is disk and CPU, not download
speed). Machine: AMD Ryzen 7 9800X3D, Windows 11, Chrome headless.

| Measure | Local build | Deployed (`artea-web.vercel.app`) |
|---|---:|---:|
| Bytes transferred to hub | 755,122,206 (720.1 MiB) | hub not detected¹ |
| Bytes transferred, whole run | 755,126,302 (720.1 MiB) | 357,776,755 (341.2 MiB)² |
| Requests | 76 | 68 |
| Time to engine started | 5.7 s | 9.2 s |
| Time to hub | 15.2 s | hub not detected¹ |

¹ The deployment is an older build (Godot 4.7.1, World One content, 424 MB
pack) that predates the hub's `Successfully spawned` log, so time-to-hub cannot
be read from it. It does reach gameplay (screenshot `99-failure.png`). Once
current `main` is deployed, `--url` reports time-to-hub there too.

² The deployment serves the pack compressed in transit, which is why it moves
less than its 424 MB pack.

## Compression (local build, 2026-10-11)

From `node artea/tools/web-compression-report.js` (2 m 43 s). gzip at level 6,
what servers apply on the fly. Brotli at quality 11, what you would
precompress with, except the pack, which uses quality 9 because quality 11 on
700 MB would take the better part of an hour.

| File | Raw MiB | gzip -6 MiB | saved | brotli MiB | saved |
|---|---:|---:|---:|---:|---:|
| index.pck | 671.86 | 472.85 | 30% | 456.96 (q9) | 32% |
| index.side.wasm | 42.04 | 10.12 | 76% | 6.86 (q11) | 84% |
| index.js | 2.73 | 0.34 | 87% | 0.24 (q11) | 91% |
| libterrain.web.release.wasm32.wasm | 1.95 | 0.37 | 81% | 0.23 (q11) | 88% |
| index.wasm | 1.44 | 0.56 | 61% | 0.45 (q11) | 68% |
| index.html | 0.01 | 0.00 | 60% | 0.00 (q11) | 68% |
| index.audio.worklet.js | 0.01 | 0.00 | 70% | 0.00 (q11) | 75% |
| pck-loader.js | 0.01 | 0.00 | 57% | 0.00 (q11) | 64% |
| index.audio.position.worklet.js | 0.00 | 0.00 | 61% | 0.00 (q11) | 70% |
| **Total** | **720.04** | **484.25** | **33%** | **464.75** | **35%** |

What this says:

- The pack is 93% of the download, and it only compresses by about a third:
  most of it is already-compressed textures and audio. Shrinking what goes into
  the pack, or not loading all of it before the hub, will matter more than
  transfer compression.
- The engine files compress very well. `index.side.wasm` alone drops from 42 MiB
  to under 7 MiB with brotli, so serving it compressed is an easy win wherever
  the host allows it (`pck-loader.js` notes Cloudflare strips a manually set
  Content-Encoding).

## Web-only texture re-encoding (issue #39)

`addons/web_asset_slimmer` is an `EditorExportPlugin` that only acts when the
export platform is Web. It re-stores large textures as lossy WebP
(`PortableCompressedTexture2D`, quality 0.85), capped at 2048 px. A texture
qualifies if it is a standalone file stored lossless or lossy (not
VRAM-compressed) and is either a 3D texture (has mipmaps) or larger than
1024 px. Small UI icons and pixel art are left alone. Nothing is dropped.

The export scripts (`./web rebuild`, `artea/tools/web.sh`,
`vercel-pack-split/export_web.sh`) enable it for the length of the export
through `artea/tools/with-web-export-plugins.sh`. It is not enabled in
`project.godot`, because every project setting is baked into the exported pack
as `project.binary`, and enabling it there changes the desktop pack by 48
bytes.

Pack contents by asset type, from `python artea/tools/pck-contents.py`
(same project, before and after the plugin):

| Asset type | Before MiB | After MiB | Change |
|---|---:|---:|---:|
| texture | 359.0 | 220.7 | -138.3 (-39%) |
| 3D scene (glb/fbx) | 192.5 | 192.5 | 0 |
| audio | 78.2 | 78.2 | 0 |
| scene/resource | 17.7 | 17.7 | 0 |
| other | 12.4 | 12.4 | 0 |
| mesh | 5.3 | 5.3 | 0 |
| font | 3.9 | 3.9 | 0 |
| script | 2.3 | 2.3 | 0 |
| shader | 0.1 | 0.1 | 0 |
| **Total** | **671.5** | **533.1** | **-138.4 (-21%)** |

129 of the 589 non-VRAM textures were re-encoded, and 10 of those were
downscaled. Cold first load (`./web verify`): 755.1 MB → 610.1 MB, still
PLAYABLE.

Desktop output is unaffected. `pck-contents.py A.pck --compare B.pck` compares
packs by file and MD5, ignoring storage order, which Godot does not keep
stable. With a warm export cache, the Windows Desktop pack before and after
this change has identical content (4,701 files). From an empty cache, Godot's
`.tscn` → `.scn` conversion is not deterministic: two exports of the *same*
code differ in the same 212 converted scenes as an export with and without
this change, and in nothing else.

Not done yet:

- **Audio** (78 MiB) is unchanged. Godot cannot encode Ogg Vorbis, so
  re-encoding at a lower bitrate needs an external encoder such as ffmpeg at
  export time.
- **VRAM formats for mobile browsers** (ETC2/ASTC) would change project-wide
  import settings, and so desktop imports too. Left out to keep desktop
  unchanged.
- **Visual check** in the Hub, Art Castle and each Kingdom (issue #39 acceptance).
