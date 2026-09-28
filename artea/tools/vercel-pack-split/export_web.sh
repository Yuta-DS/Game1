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

# Duplicate resource identities can resolve to the wrong scene or script after
# import. Catch them before Godot builds a production pack.
python3 "${project_dir}/scripts/check_unique_resource_uids.py"

# Keep player-facing resources in the Web pack. This runs before any existing
# build is removed, so an accidental export exclusion cannot replace a known
# playable production build.
"${godot_bin}" --headless --path "${project_dir}" \
	--script res://scripts/test_web_feature_parity.gd

# Fail before replacing any existing build if the public client config is absent.
# The source .env may contain OAuth secrets and must never be packed wholesale.
"${godot_bin}" --headless --path "${project_dir}" \
	--script res://tools/export_firebase_client_config.gd

mkdir -p "${output_dir}"
# Part indices become three digits once the pack exceeds 800 MiB. Remove every
# generated numeric part from the prior export so stale part100+ files cannot
# fill the disk or leak into the next deployment.
find "${output_dir}" -maxdepth 1 -type f -name 'index.pck.part*' -delete
rm -f "${output_dir}/index.pck"
rm -f "${output_dir}/index.pck.parts.json"

export_log="$(mktemp -t artea-web-export.XXXXXX)"
if ! "${godot_bin}" --headless --path "${project_dir}" \
		--export-release Web "${output_dir}/index.html" 2>&1 | tee "${export_log}"; then
	rm -f "${export_log}"
	exit 1
fi
if grep -Eq '^(SCRIPT ERROR:|ERROR:)' "${export_log}"; then
	echo "Web export emitted runtime resource or script errors." >&2
	rm -f "${export_log}"
	exit 1
fi
rm -f "${export_log}"

python3 "${script_dir}/../patch_web_release_loader.py" \
	"${output_dir}/index.html"

cp "${script_dir}/pck-loader.js" "${output_dir}/pck-loader.js"

# Split from the end and shrink the source after every part. This keeps peak
# disk use near one PCK instead of requiring a second full copy of the build.
pck_path="${output_dir}/index.pck"
# Small parts keep each upload below Vercel's connection timeout and avoid the
# CLI buffering several large requests on constrained build machines.
part_size=$((8 * 1024 * 1024))
if stat -f '%z' "${pck_path}" >/dev/null 2>&1; then
	pck_size=$(stat -f '%z' "${pck_path}")
else
	pck_size=$(stat -c '%s' "${pck_path}")
fi
part_index=$(((pck_size - 1) / part_size))
part_count=$((part_index + 1))
while (( part_index >= 0 )); do
	offset=$((part_index * part_size))
	part_suffix=$(printf '%02d' "${part_index}")
	dd if="${pck_path}" of="${pck_path}.part${part_suffix}" bs=1048576 \
		skip=$((offset / 1024 / 1024)) status=none
	truncate -s "${offset}" "${pck_path}"
	part_index=$((part_index - 1))
done
rm "${pck_path}"

printf '{"count":%d,"bytes":%d,"partBytes":%d}\n' \
	"${part_count}" "${pck_size}" "${part_size}" \
	> "${output_dir}/index.pck.parts.json"

echo "Web build ready in ${output_dir} (${part_count} pack parts)"
