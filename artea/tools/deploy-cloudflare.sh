#!/usr/bin/env bash
# Build Artéa for the web and deploy it to Cloudflare Pages.
#
#   ./artea/tools/deploy-cloudflare.sh              # build if needed, then deploy
#   ./artea/tools/deploy-cloudflare.sh --rebuild    # force a fresh export first
#   ./artea/tools/deploy-cloudflare.sh --dry-run    # stage and check, do not upload
#
# Why Cloudflare rather than Vercel:
#
#   Vercel's free tier caps bandwidth at 100 GB/month, which a ~750 MB first
#   load exhausts in ~130 plays. Cloudflare Pages does not meter bandwidth on
#   its free plan, which is the property that actually matters for shipping a
#   large game build to a class or a marker.
#
# What this has to work around:
#
#   Cloudflare rejects any single file over 25 MB - stricter than Vercel's
#   100 MB. Two files in a Godot web export break that:
#
#     * index.pck (750 MB) - already split into 8 MB index.pck.partNN files by
#       the export script, and rejoined in the browser by pck-loader.js. The
#       whole .pck must NOT be uploaded; only the parts.
#     * index.side.wasm (42 MB) - the GDExtension side module (terrain_3d).
#       Serving it pre-gzipped does NOT work: Cloudflare strips a manually set
#       Content-Encoding header, so the browser receives gzip bytes where it
#       expects a wasm module (verified: the deployed file began 1f8b instead of
#       \0asm). It is split like the pack instead, and pck-loader.js rejoins it.
#
#   A deployment also may not exceed 20,000 files; this build is ~150, so that
#   limit is not a concern.
set -euo pipefail

mode=deploy
rebuild=0
while [[ $# -gt 0 ]]; do
	case "$1" in
		--rebuild)  rebuild=1; shift ;;
		--dry-run)  mode=dry;  shift ;;
		-h|--help)  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
	esac
done

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${project_dir}/builds/web"
stage_dir="${project_dir}/builds/cloudflare"
max_bytes=$((25 * 1024 * 1024))

if [[ "${rebuild}" == 1 || ! -f "${build_dir}/index.html" ]]; then
	echo "==> Building web export"
	"${project_dir}/tools/web.sh" --rebuild --port 0 >/dev/null 2>&1 &
	build_pid=$!
	# web.sh serves after exporting; wait for the artefact, then stop it.
	while [[ ! -f "${build_dir}/index.pck" && ! -f "${build_dir}/index.pck.part00" ]]; do
		sleep 5
		kill -0 "${build_pid}" 2>/dev/null || break
	done
	sleep 5
	kill "${build_pid}" 2>/dev/null || true
fi

if [[ ! -f "${build_dir}/index.html" ]]; then
	echo "No build at ${build_dir}. Run ./artea/tools/web.sh --rebuild first." >&2
	exit 1
fi

echo "==> Staging deployment in ${stage_dir}"
rm -rf "${stage_dir}"
mkdir -p "${stage_dir}"

# web.sh exports a whole index.pck and does not split it, so any part files and
# manifest still sitting in builds/web are left over from an earlier, differently
# sized export. Copying those stages a manifest that disagrees with the pack:
# the browser reads the stale count, fetches too few parts, and assembles a
# truncated pack - which loads without an obvious error and then behaves as if
# half the game is missing. Drop them so the split below is always authoritative.
find "${build_dir}" -maxdepth 1 -name 'index.pck.part*' -delete
rm -f "${build_dir}/index.pck.parts.json"
find "${build_dir}" -maxdepth 1 -name 'index.side.wasm.part*' -delete
rm -f "${build_dir}/index.side.wasm.parts.json"

# Copy everything except the unsplit pack, which is what the parts replace.
for path in "${build_dir}"/*; do
	name="$(basename "${path}")"
	[[ "${name}" == "index.pck" ]] && continue
	[[ "${name}" == ".env.local" ]] && continue   # Vercel CLI token, never deploy
	[[ "${name}" == ".vercel" ]] && continue
	cp -R "${path}" "${stage_dir}/"
done

# Split any remaining oversized file the same way the pack is split, so the
# loader's existing part-fetching logic can rejoin it.
split_oversized() {
	local file="$1"
	local base
	base="$(basename "${file}")"
	local size
	size=$(stat -f '%z' "${file}" 2>/dev/null || stat -c '%s' "${file}")
	(( size <= max_bytes )) && return 0
	echo "    splitting ${base} ($(( size / 1024 / 1024 )) MB)"
	split -b 8m "${file}" "${file}.part"
	# split(1) uses aa/ab suffixes; rename to the numeric form the loader wants.
	local index=0
	for part in "${file}".part??; do
		mv "${part}" "$(printf '%s.part%02d' "${file}" "${index}")"
		index=$((index + 1))
	done
	rm -f "${file}"
	printf '{"count":%d,"bytes":%d,"partBytes":%d}\n' \
		"${index}" "${size}" $((8 * 1024 * 1024)) \
		> "${file}.parts.json"
}

# Only the pack may be split - the loader rejoins nothing else. Anything else
# that is oversized has to be shrunk in place instead.
# Copy the pack in and split it here. Splitting at deploy time, from the pack
# that was actually exported, is what keeps the part count and the manifest
# honest - a mismatch silently truncates the game in the browser.
if [[ -f "${build_dir}/index.pck" ]]; then
	cp "${build_dir}/index.pck" "${stage_dir}/index.pck"
fi

for candidate in "${stage_dir}"/*; do
	[[ -f "${candidate}" ]] || continue
	name="$(basename "${candidate}")"
	[[ "${name}" == *.part[0-9][0-9] ]] && continue
	split_oversized "${candidate}"
done

# Cloudflare needs the right MIME type for .wasm or the browser refuses to
# stream-compile it, and long-lived caching on the immutable pack parts keeps
# repeat loads cheap.
cat > "${stage_dir}/_headers" <<'HEADERS'
/*.wasm
  Content-Type: application/wasm
  Cache-Control: public, max-age=31536000, immutable

/index.pck.part*
  Cache-Control: public, max-age=31536000, immutable
HEADERS

echo "==> Verifying Cloudflare limits"
oversize=0
while IFS= read -r f; do
	size=$(stat -f '%z' "${f}" 2>/dev/null || stat -c '%s' "${f}")
	if (( size > max_bytes )); then
		echo "    TOO LARGE: $(basename "${f}") ($(( size / 1024 / 1024 )) MB)"
		oversize=$((oversize + 1))
	fi
done < <(find "${stage_dir}" -type f)
file_count=$(find "${stage_dir}" -type f | wc -l | tr -d ' ')
total_mb=$(( $(find "${stage_dir}" -type f -exec stat -f '%z' {} \; 2>/dev/null | paste -sd+ - | bc) / 1024 / 1024 ))
echo "    ${file_count} files, ${total_mb} MB total, ${oversize} over the 25 MB limit"

if (( oversize > 0 )); then
	echo "Refusing to deploy: files above Cloudflare's 25 MB limit remain." >&2
	exit 1
fi

if [[ "${mode}" == dry ]]; then
	echo "==> Dry run complete. Staged at ${stage_dir}"
	exit 0
fi

if ! command -v wrangler >/dev/null 2>&1; then
	echo
	echo "wrangler (the Cloudflare CLI) is not installed. To deploy:"
	echo "  npm install -g wrangler"
	echo "  wrangler login"
	echo "  wrangler pages deploy \"${stage_dir}\" --project-name=artea"
	exit 1
fi

echo "==> Deploying to Cloudflare Pages"
wrangler pages deploy "${stage_dir}" --project-name=artea
