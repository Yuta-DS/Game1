#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/../.." && pwd)"
output_dir="${project_dir}/builds/web"
# Check deployment configuration before running a potentially long export.
public_api_url="${ARTEA_PUBLIC_API_BASE_URL:-}"
if [[ -z "${public_api_url}" ]]; then
    echo "Set ARTEA_PUBLIC_API_BASE_URL to the deployed HTTPS Artéa API." >&2
    exit 1
fi
python_bin=""
for name in "${PYTHON_BIN:-}" python3 python python.exe; do
    [[ -n "${name}" ]] || continue
    if command -v "${name}" >/dev/null 2>&1; then
        python_bin="$(command -v "${name}")"
        break
    fi
done
[[ -n "${python_bin}" ]] || { echo "Python 3 is required for Web export." >&2; exit 1; }
if [[ -n "${GODOT_BIN:-}" ]]; then
	if command -v "${GODOT_BIN}" >/dev/null 2>&1; then
		godot_bin="$(command -v "${GODOT_BIN}")"
	else
		godot_bin="${GODOT_BIN}"
	fi
else
	godot_bin=""
	for name in godot godot4 godot.exe godot4.exe; do
		if command -v "${name}" >/dev/null 2>&1; then
			godot_bin="$(command -v "${name}")"
			break
		fi
	done
	[[ -n "${godot_bin}" ]] || godot_bin="/Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot"
fi

if [[ ! -x "${godot_bin}" ]]; then
	echo "Set GODOT_BIN to a non-Mono Godot 4 executable." >&2
	exit 1
fi

if "${godot_bin}" --version | grep -qi mono; then
	echo "Web export requires the standard non-Mono Godot executable." >&2
	exit 1
fi

mkdir -p "${output_dir}"

# Core plus one .pck per area Pack (issue #35), with the Web-only export
# plugins (texture slimming, issue #39) on.
"${project_dir}/tools/export-web-packs.sh" "${godot_bin}" "${output_dir}/index.html"

cp "${script_dir}/pck-loader.js" "${output_dir}/pck-loader.js"

# Public browser builds must point at the hosted account API. Local ./web uses
# its own loopback backend and does not call this deployment export script.
"${python_bin}" - "${output_dir}/index.html" "${public_api_url}" <<'PYAPI'
import json
from pathlib import Path
import sys
from urllib.parse import urlparse

index = Path(sys.argv[1])
api_url = sys.argv[2].rstrip("/")
parsed = urlparse(api_url)
if parsed.scheme != "https" or not parsed.hostname or parsed.path or parsed.query or parsed.fragment:
    raise SystemExit("ARTEA_PUBLIC_API_BASE_URL must be an HTTPS origin")
html = index.read_text(encoding="utf-8")
marker = '<script src="pck-loader.js"></script>'
if marker not in html:
    raise SystemExit("Cannot find the Godot pack loader in index.html")
config = f'<script>window.ARTEA_API_BASE_URL = {json.dumps(api_url)};</script>'
html = html.replace(marker, config + "\n" + marker, 1)
index.write_text(html, encoding="utf-8")
PYAPI

# Content-hashed parts and manifests, the same layout local ./web and the
# Cloudflare deploy use (see split-pack.sh). index.side.wasm is split too: the
# loader rejoins it, and one code path for both keeps the layouts identical.
for big in "${output_dir}"/*.pck "${output_dir}/index.side.wasm"; do
	[[ -f "${big}" ]] && "${project_dir}/tools/split-pack.sh" "${big}"
done

# vercel.json serves parts/ immutable and everything else no-cache (ADR-0002).
# .vercelignore keeps the unsplit originals out of the upload instead of
# deleting them, so the same build directory still serves locally.
cp "${script_dir}/vercel.json" "${output_dir}/vercel.json"
cp "${script_dir}/.vercelignore" "${output_dir}/.vercelignore"

echo "Web build ready in ${output_dir}"
