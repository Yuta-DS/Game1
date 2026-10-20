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

# Settle new scripts/import UIDs before analyzing the resource graph.
echo "Importing project before generating Pack presets"
"${godot_bin}" --headless --editor --path "${project_dir}" --import --quit \
	> "${build_dir}/import.log" 2>&1

echo "Preparing castle tree geometry"
"${godot_bin}" --headless --path "${project_dir}" --script res://tools/bake_castle_tree.gd \
	> "${build_dir}/castle-tree-bake.log" 2>&1
grep -q "CASTLE TREE BAKE: PASS" "${build_dir}/castle-tree-bake.log" || {
	cat "${build_dir}/castle-tree-bake.log" >&2
	exit 1
}

# Same guard as with-web-export-plugins.sh: a leftover backup means a run was
# killed mid-export, and copying over it would lose the real presets.
if [[ -e "${backup}" ]]; then
	echo "${backup} exists: an earlier Web export did not restore export_presets.cfg." >&2
	echo "Check export_presets.cfg, then delete the backup (or move it back over it)." >&2
	exit 1
fi
cp "${presets}" "${backup}"
trap 'mv -f "${backup}" "${presets}"; rm -f "${manifest}" "${project_dir}/export_presets.generated.cfg"' EXIT

echo "Working out the Packs"
split_log="$("${godot_bin}" --headless --path "${project_dir}" \
	--script res://tools/pack_split.gd -- --write 2>&1)" || {
	grep -E "^PACK" <<<"${split_log}" >&2
	echo "Web export stopped: fix the references above (tools/pack_split.gd)." >&2
	exit 1
}
grep -E "^PACK" <<<"${split_log}"
mv -f "${project_dir}/export_presets.generated.cfg" "${presets}"
cp "${manifest}" "${build_dir}/web-packs.json"
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
done

# Refuse a Pack that would delete Core files when mounted, or an asset shipped
# twice, rather than ship a build that falls apart on entry; then the real
# sizes, Core against the budget in tools/packs.cfg.
budget_mb=$(sed -n 's/^budget_mb=\([0-9.]*\).*/\1/p' "${project_dir}/tools/packs.cfg")
python3 "${project_dir}/tools/check_packs.py" "${build_dir}" "${budget_mb:-100}"
