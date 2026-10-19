#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/../.." && pwd)"
output_dir="${project_dir}/builds/web"
if [[ -n "${GODOT_BIN:-}" ]]; then
	if command -v "${GODOT_BIN}" >/dev/null 2>&1; then
		godot_bin="$(command -v "${GODOT_BIN}")"
	else
		godot_bin="${GODOT_BIN}"
	fi
elif command -v godot >/dev/null 2>&1; then
	godot_bin="$(command -v godot)"
else
	godot_bin="/Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot"
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

# The wrapper turns on the Web-only export plugins (texture slimming, issue
# #39) without enabling them for desktop exports.
"${project_dir}/tools/with-web-export-plugins.sh" \
	"${godot_bin}" --headless --path "${project_dir}" \
	--export-release Web "${output_dir}/index.html"
python3 "${project_dir}/tools/build_fast_web_pack.py" --godot "${godot_bin}"
python3 "${project_dir}/tools/patch_web_release_loader.py" "${output_dir}/index.html"

cp "${script_dir}/pck-loader.js" "${output_dir}/pck-loader.js"

# Content-hashed parts and manifests, the same layout local ./web and the
# Cloudflare deploy use (see split-pack.sh). index.side.wasm is split too: the
# loader rejoins it, and one code path for both keeps the layouts identical.
for big in "${output_dir}/index.pck" "${output_dir}/content.pck" "${output_dir}/index.side.wasm"; do
	[[ -f "${big}" ]] && "${project_dir}/tools/split-pack.sh" "${big}"
done

# vercel.json serves parts/ immutable and everything else no-cache (ADR-0002).
# .vercelignore keeps the unsplit originals out of the upload instead of
# deleting them, so the same build directory still serves locally.
cp "${script_dir}/vercel.json" "${output_dir}/vercel.json"
cp "${script_dir}/.vercelignore" "${output_dir}/.vercelignore"

echo "Web build ready in ${output_dir}"
