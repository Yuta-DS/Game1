#!/usr/bin/env bash
# Run a command - a Godot Web export - with the Web-only export plugins on.
#
#   ./artea/tools/with-web-export-plugins.sh godot --headless --path artea \
#       --export-release Web artea/builds/web/index.html
#
# Why the plugins are not simply enabled in project.godot: every project
# setting, [editor_plugins] included, is baked into the exported pack as
# project.binary, so enabling one there changes the DESKTOP pack too (by 48
# bytes), and issue #39 requires desktop output to stay byte-for-byte the same.
# override.cfg would avoid touching project.godot, but the editor ignores it -
# it is only read by running games - so the plugin would never load.
#
# Instead this adds the plugins to project.godot for the duration of the
# command and always puts the original back. A leftover backup means an
# earlier run was killed before it could restore; it refuses to continue
# rather than overwrite the real file with a stale copy.
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project="${project_dir}/project.godot"
backup="${project}.web-export-backup"
web_only_plugins='"res://addons/web_asset_slimmer/plugin.cfg"'

if [[ -e "${backup}" ]]; then
	echo "${backup} exists: an earlier Web export did not restore project.godot." >&2
	echo "Check project.godot, then delete the backup (or move it back over it)." >&2
	exit 1
fi

cp "${project}" "${backup}"
trap 'mv -f "${backup}" "${project}"' EXIT
# Append to the existing enabled list; \r? keeps CRLF checkouts working.
sed -i.tmp -E "s|^(enabled=PackedStringArray\\(.*)\\)(\\r?)$|\\1, ${web_only_plugins})\\2|" "${project}"
rm -f "${project}.tmp"
grep -q "web_asset_slimmer" "${project}" || {
	echo "Could not add the Web export plugins to project.godot." >&2
	exit 1
}

"$@"
