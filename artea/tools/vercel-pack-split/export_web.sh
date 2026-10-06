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
find "${output_dir}" -maxdepth 1 -type f -name 'index.pck.part[0-9][0-9]' -delete
rm -f "${output_dir}/index.pck"
rm -f "${output_dir}/index.pck.parts.json"

"${godot_bin}" --headless --path "${project_dir}" \
	--export-release Web "${output_dir}/index.html" 2>&1 | tee "${output_dir}/export.log"

# Godot can return zero despite resource/customization failures. Do not split or
# publish that pack as a successful build; retain the complete diagnostic log.
if grep -Eq '(^|[[:space:]])(ERROR:|SCRIPT ERROR:|Parse Error:)' "${output_dir}/export.log"; then
	echo "Web export contains errors; see ${output_dir}/export.log" >&2
	exit 1
fi

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
