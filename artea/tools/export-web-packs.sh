#!/usr/bin/env bash
# Export the Web build as Core plus one file per area Pack (ADR-0001, #35).
#
#   ./artea/tools/export-web-packs.sh GODOT_BIN BUILD_DIR/index.html
#
# Writes index.html/.pck/... (Core) and <pack>.pck next to it, unsplit; the
# callers cut every .pck into parts with split-pack.sh as before.
#
# 1. tools/pack_split.gd works out each Pack's files. It fails the build when a
#    shipped dependency is in no Pack, before anything is exported.
# 2. It also writes res://packs.json (which scenes need which Pack) and two
#    presets derived from the hand-maintained "Web" one: "Web Core" (Web minus
#    every Pack's files) and "Web Pack <name>". They exist only for this
#    export: export_presets.cfg is put back and packs.json deleted afterwards.
# 3. Core exports exactly as the Web build always has. Each Pack exports as a
#    patch against it, so a file Core already holds is never shipped twice.
set -euo pipefail

godot_bin="${1:?usage: export-web-packs.sh GODOT_BIN BUILD_DIR/index.html}"
index="${2:?usage: export-web-packs.sh GODOT_BIN BUILD_DIR/index.html}"
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$(cd "$(dirname "${index}")" && pwd)"
presets="${project_dir}/export_presets.cfg"
backup="${presets}.packs-backup"
manifest="${project_dir}/packs.json"

# Same guard as with-web-export-plugins.sh: a leftover backup means a run was
# killed mid-export, and copying over it would lose the real presets.
if [[ -e "${backup}" ]]; then
	echo "${backup} exists: an earlier Web export did not restore export_presets.cfg." >&2
	echo "Check export_presets.cfg, then delete the backup (or move it back over it)." >&2
	exit 1
fi
cp "${presets}" "${backup}"
trap 'mv -f "${backup}" "${presets}"; rm -f "${manifest}"' EXIT

echo "Working out the Packs"
split_log="$("${godot_bin}" --headless --path "${project_dir}" \
	--script res://tools/pack_split.gd -- --write 2>&1)" || {
	grep -E "^PACK" <<<"${split_log}" >&2
	echo "Web export stopped: fix the references above (tools/pack_split.gd)." >&2
	exit 1
}
grep -E "^PACK" <<<"${split_log}"
packs=$(sed -n 's/^PACK \([a-z_0-9]*\): .*/\1/p' <<<"${split_log}")

# Old Packs from a previous export would otherwise be served with this Core.
rm -f "${build_dir}"/*.pck

echo "Exporting Core"
"${project_dir}/tools/with-web-export-plugins.sh" \
	"${godot_bin}" --headless --path "${project_dir}" \
	--export-release "Web Core" "${index}"

for pack in ${packs}; do
	echo "Exporting the ${pack} Pack"
	"${project_dir}/tools/with-web-export-plugins.sh" \
		"${godot_bin}" --headless --path "${project_dir}" \
		--export-patch "Web Pack ${pack}" "${build_dir}/${pack}.pck" \
		--patches "${build_dir}/index.pck"
	# A patch marks each Core file its preset left out as removed (directory
	# flag 2), and mounting it deletes those files from the running game.
	# Refuse such a Pack rather than ship a build that falls apart on entry.
	python3 - "${build_dir}/${pack}.pck" <<'PY' || exit 1
# PCK v3+: header to byte 32, then the directory offset; per file a path,
# offset + size + md5 (32 bytes), then flags.
import struct, sys
f = open(sys.argv[1], "rb")
assert f.read(4) == b"GDPC", "not a pck"
f.seek(32)
f.seek(struct.unpack("<Q", f.read(8))[0])
removed = []
for _ in range(struct.unpack("<I", f.read(4))[0]):
    name = f.read(struct.unpack("<I", f.read(4))[0]).rstrip(b"\0").decode("utf-8", "replace")
    f.read(32)
    if struct.unpack("<I", f.read(4))[0] & 2:
        removed.append(name)
if removed:
    sys.exit(f"{sys.argv[1]} would delete {len(removed)} Core files when mounted, e.g. {removed[0]}")
PY
done
