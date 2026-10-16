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

## Repeat visit (issue #33)

`./web verify --repeat` serves the local build with the deployed cache headers
(content-hashed `parts/` immutable, everything else `no-cache`), loads it once
cold, then loads it again with the cache on.

| Measure | Before #33 (`no-store`) | After #33 |
|---|---:|---:|
| First visit | 755 MB | 755 MB |
| Second visit, unchanged build | 755 MB | 7,367 bytes |
| Second visit, parts from cache | 0 of 90 | 90 of 90 |

The 7.4 KB is the two part manifests (never cached) plus ~130-byte `304`
revalidations of the HTML, js and wasm.

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

## Parallel part fetching (issue #34)

`pck-loader.js` used to fetch the pack's 8 MB parts one at a time, leaving the
connection idle for a round trip between parts. It now keeps a bounded number
in flight and hands them to the engine strictly in order, so the engine still
sees one in-order stream. Parts that arrive ahead of their turn wait in memory,
so the bound is also the memory cost: 4 parts is a 32 MB peak.

Time from navigation to "engine started" (the whole pack downloaded), one run
each, local build (757 MB first load), `?parts=N` to set the concurrency:

| Loader | Local, no shaping | 100 ms latency, 200 Mbit/s |
|---|---:|---:|
| Before (one at a time) | 7.2 s | 46.3 s |
| 1 in flight | 8.0 s | 47.5 s |
| 2 in flight | 6.7 s | 41.2 s |
| **4 in flight (default)** | **6.4 s** | **36.6 s (-21%)** |
| 6 in flight | 6.3 s | 36.2 s |
| 8 in flight | 6.3 s | 36.0 s |

```sh
node artea/tools/web-smoke.js "http://localhost:8801/index.html?parts=4" --latency 100 --mbps 200
```

On the shaped network, 4 is the knee. It is within 2 s of the 30 s that
200 Mbit/s needs for 757 MB, and more parts in flight only add memory. Time to
hub fell from 57.6 s to 47.4 s. Unshaped, localhost has no round trip to hide,
so the gain is small (7.2 s to 6.4 s).

Failure handling, checked with `web-smoke.js --fail-part 05 --fail-times K`
(part 05 of the pack and of `index.side.wasm` answer 404 for the first K
requests between them):

- **K = 2:** each part is retried once after 0.5 s and the load carries on.
  Only the two failing parts were requested again, and it was still PLAYABLE
  with the same time to engine start.
- **K = 10:** after four attempts the loader shows a "Part of the game couldn't
  be downloaded" overlay with a Retry button and holds the download. The
  engine is still waiting on its stream, so nothing half-loads. Pressing Retry
  carried on from the failed parts, with no other part fetched twice, and
  reached the hub.

All of these ran with the Flask server down (Offline Guest).

## Web-only texture re-encoding (issue #39)

`addons/web_asset_slimmer` is an `EditorExportPlugin` that only acts when the
export platform is Web. Every texture it touches is capped at 2048 px, and
nothing is dropped:

- **Lossless or lossy (WebP/PNG) textures** are re-stored as lossy WebP
  (`PortableCompressedTexture2D`, quality 0.85) when they are a 3D texture (have
  mipmaps) or larger than 1024 px. Small UI icons and pixel art are left alone:
  lossy WebP smudges hard pixel edges.
- **VRAM-compressed textures** (S3TC/BPTC) are re-stored as Basis Universal.
  Basis stays GPU-compressed and the browser transcodes it to whatever it
  supports: S3TC/BPTC on desktop, ETC2/ASTC on mobile, which the S3TC-only
  imports never reached. Flat 2D art imported as VRAM is where it pays off
  (`joyring.png` 3.6 MB → 36 KB, `trophy.png` 3.1 MB → 98 KB). Detailed 3D
  textures stay about the same size and quality (Milo's skin 2.73 → 2.78 MB,
  PSNR against the source within 0.2 dB of the shipped DXT1). Lossy WebP would
  be smaller for those, but decodes to RGBA8, four to eight times the GPU memory
  of the DXT it replaces. HDR and RGTC normal-map imports are left as they are.

The export scripts (`./web rebuild`, `artea/tools/web.sh`,
`vercel-pack-split/export_web.sh`) enable it for the length of the export
through `artea/tools/with-web-export-plugins.sh`. It is not enabled in
`project.godot`, because every project setting is baked into the exported pack
as `project.binary`, and enabling it there changes the desktop pack by 48
bytes.

Pack contents by asset type, from `python artea/tools/pck-contents.py`
(same project, Web export without and with the plugin):

| Asset type | Before MiB | After MiB | Change |
|---|---:|---:|---:|
| texture | 359.1 | 142.1 | -217.0 (-60%) |
| 3D scene (glb/fbx) | 192.5 | 192.5 | 0 |
| audio | 79.7 | 79.7 | 0 |
| scene/resource | 17.7 | 17.7 | 0 |
| other | 12.4 | 12.4 | 0 |
| mesh | 5.3 | 5.3 | 0 |
| font | 4.2 | 4.2 | 0 |
| script | 2.3 | 2.3 | 0 |
| shader | 0.1 | 0.1 | 0 |
| **Total** | **673.3** | **456.3** | **-217.0 (-32%)** |

129 of the 589 non-VRAM textures went to lossy WebP and all 221 VRAM textures
to Basis Universal; 13 were downscaled. The VRAM textures were 106.9 MiB of the
texture total (DXT5 73.5, DXT1 33.4). With WebP alone the texture row was
220.7 MiB. Cold first load (`./web verify`): 755.1 MB → 529.6 MB to the hub,
time to hub 18.0 s, still PLAYABLE, with no texture or Basis errors in the
browser console.

The 3D scene row is mesh and animation data: every `.glb` import extracts its
textures to separate files (`gltf/embedded_image_handling=1`), so those are
already counted, and shrunk, under texture.

Desktop output is unaffected. `pck-contents.py A.pck --compare B.pck` compares
packs by file and MD5, ignoring storage order, which Godot does not keep
stable. Desktop exports never run the wrapper, and the plugin declines every
platform but Web. To check the second half, the Windows Desktop pack was
exported with the plugin forcibly enabled (through the wrapper) and without:
all 4,813 files are byte-identical except `project.binary`, which differs only
because the wrapper adds the plugin to `project.godot` for the length of the
export, the 48 bytes that are the reason it is not enabled there.

Not done yet:

- **Audio** (79.7 MiB) is unchanged. Godot cannot encode Ogg Vorbis, so
  re-encoding at a lower bitrate needs an external encoder such as ffmpeg at
  export time.
- **Visual check** in the Hub, Art Castle and each Kingdom (issue #39
  acceptance). The headless `./web verify` screenshots are taken under the
  loading overlay (software rendering), so this needs a person in a browser.
