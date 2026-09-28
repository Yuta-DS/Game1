#!/usr/bin/env bash
# Regenerate the textures Godot extracts from GLBs, on a clone that lost them.
#
#   ./artea/tools/regen_extracted_textures.sh            # repair, then import
#   ./artea/tools/regen_extracted_textures.sh --dry-run  # only report
#
# Why this exists:
#
# * GLBs imported with gltf/embedded_image_handling=1 write their embedded
#   images next to themselves as <glb stem>_<image>.png/.jpg.  Those files are
#   importer output, so they are gitignored rather than tracked.
# * A fresh clone is fine: the first import extracts them.  An existing clone
#   is not.  Switching from a branch that tracked them deletes the images, and
#   Godot never re-extracts because the .glb and its .import are unchanged, so
#   the cached import still looks current.
# * Worse, the image's own .import file is usually left behind.  While it
#   exists, the glTF importer assumes the image is already on disk, skips
#   writing it, and embeds the texture uncompressed instead - or fails, which
#   breaks any script that preloads the GLB (art_castle_floating_world.gd).
#
# The repair: delete those orphaned .import files (their source is gone, so
# they are dead), clear the cached import of each affected GLB so Godot
# re-imports it, then run one headless import.
set -euo pipefail

dry_run=0
while [[ $# -gt 0 ]]; do
	case "$1" in
		--dry-run) dry_run=1; shift ;;
		-h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
	esac
done

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
imported_dir="${project_dir}/.godot/imported"

find_godot() {
	# Prefer an explicit GODOT_BIN, then anything on PATH, then the usual
	# install locations.  Importing works from Mono builds too.
	local candidates=()
	[[ -n "${GODOT_BIN:-}" ]] && candidates+=("${GODOT_BIN}")
	command -v godot >/dev/null 2>&1 && candidates+=("$(command -v godot)")
	candidates+=(
		"${HOME}/Downloads/Godot.app/Contents/MacOS/Godot"
		"${HOME}/Applications/Godot.app/Contents/MacOS/Godot"
		"/Applications/Godot.app/Contents/MacOS/Godot"
	)
	shopt -s nullglob
	candidates+=("${HOME}"/Downloads/Godot_v4*_win64_console.exe "${HOME}"/Downloads/Godot_v4*_win64.exe)
	shopt -u nullglob
	for candidate in "${candidates[@]}"; do
		[[ -x "${candidate}" ]] || continue
		printf '%s' "${candidate}"
		return 0
	done
	return 1
}

# Succeeds when an image the GLB embeds is missing on disk or not yet
# imported.  Godot names each one <stem>_<image name>.<png|jpg> - or
# <stem>_<index> when the image is unnamed - dropping any extension already in
# the name.  Only binary .glb: a .gltf points at external image files and
# extracts nothing.
extract_incomplete() {
	local model="$1" dir stem image name ext index=0
	[[ "${model,,}" == *.glb ]] || return 1
	dir="$(dirname "${model}")"
	stem="$(basename "${model%.*}")"
	while IFS= read -r image; do
		name="$(grep -o '"name" *: *"[^"]*"' <<<"${image}" | cut -d'"' -f4 || true)"
		[[ -n "${name}" ]] || name="${index}"
		index=$((index + 1))
		ext=png
		grep -q '"mimeType" *: *"image/jpeg"' <<<"${image}" && ext=jpg
		name="${name%.png}"; name="${name%.jpg}"; name="${name%.jpeg}"
		[[ -e "${dir}/${stem}_${name}.${ext}.import" ]] || return 0
	# The JSON chunk leads the file and may be pretty-printed over many lines,
	# so flatten it before matching.
	done < <(head -c 4194304 "${model}" | tr '\n\r\t' '   ' \
		| grep -ao '"images" *: *\[[^]]*\]' | head -n 1 | grep -o '{[^{}]*}' || true)
	return 1
}

orphans=0
glbs=()
while IFS= read -r -d '' model; do
	[[ -f "${model}.import" ]] || continue
	grep -q '^gltf/embedded_image_handling=1' "${model}.import" || continue
	dir="$(dirname "${model}")"
	stem="$(basename "${model%.*}")"
	needs_reimport=0

	# Orphaned sidecars: an extracted image's .import whose image is gone.
	while IFS= read -r -d '' sidecar; do
		[[ -e "${sidecar%.import}" ]] && continue
		orphans=$((orphans + 1))
		needs_reimport=1
		echo "orphan: ${sidecar#"${project_dir}/"}"
		(( dry_run )) || rm -f -- "${sidecar}"
	done < <(find "${dir}" -maxdepth 1 -name "${stem}_*.import" \
		\( -iname '*.png.import' -o -iname '*.jpg.import' -o -iname '*.jpeg.import' \) -print0)

	(( needs_reimport )) || ! extract_incomplete "${model}" || needs_reimport=1
	(( needs_reimport )) && glbs+=("${model}")
done < <(find "${project_dir}" -path "${project_dir}/.godot" -prune -o \
	\( -iname '*.glb' -o -iname '*.gltf' \) -print0)

echo "${orphans} orphaned .import file(s), ${#glbs[@]} GLB(s) to re-import"
(( ${#glbs[@]} == 0 )) && exit 0
for model in "${glbs[@]}"; do
	echo "reimport: ${model#"${project_dir}/"}"
done
(( dry_run )) && exit 0

godot_bin="$(find_godot)" || {
	echo "No Godot 4 found.  Set GODOT_BIN to it and re-run." >&2
	exit 1
}
echo "Importing with ${godot_bin}"

reimport() {
	# Deleting the cached import makes Godot treat the GLB as changed.
	local model
	for model in "$@"; do
		rm -f -- "${imported_dir}/$(basename "${model}")"-*.md5 \
			"${imported_dir}/$(basename "${model}")"-*.scn
	done
	"${godot_bin}" --headless --path "${project_dir}" --import >/dev/null 2>&1 || true
}

# An image extracted late in a pass is only imported on the next one, and its
# GLB meanwhile falls back to an uncompressed embedded copy.  So re-import
# whatever is still incomplete until every image is imported, then import
# those GLBs once more so they pick the now-imported images up.
late=()
for pass in 1 2 3; do
	reimport "${glbs[@]}"
	remaining=()
	for model in "${glbs[@]}"; do
		extract_incomplete "${model}" && remaining+=("${model}")
	done
	(( ${#remaining[@]} == 0 )) && break
	echo "pass ${pass}: ${#remaining[@]} GLB(s) still incomplete, importing again"
	late+=("${remaining[@]}")
	glbs=("${remaining[@]}")
done
if (( ${#remaining[@]} )); then
	echo "Still incomplete after 3 passes:" >&2
	printf '  %s\n' "${remaining[@]#"${project_dir}/"}" >&2
	exit 1
fi
if (( ${#late[@]} )); then
	echo "re-importing ${#late[@]} GLB(s) whose images landed late"
	reimport "${late[@]}"
fi
echo "Done.  Open the project as usual."
