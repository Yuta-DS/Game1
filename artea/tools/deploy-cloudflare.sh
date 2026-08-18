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
#       This one CANNOT be split: pck-loader.js only intercepts /index.pck, and
#       the browser loads the side module directly, so a split copy would simply
#       404. It is served gzipped instead, which Cloudflare decompresses
#       transparently and which brings it under the limit.
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
for candidate in "${stage_dir}"/*; do
	[[ -f "${candidate}" ]] || continue
	name="$(basename "${candidate}")"
	[[ "${name}" == index.pck.part* ]] && continue
	size=$(stat -f '%z' "${candidate}" 2>/dev/null || stat -c '%s' "${candidate}")
	(( size <= max_bytes )) || {
		if [[ "${name}" == *.wasm ]]; then
			echo "    compressing ${name} ($(( size / 1024 / 1024 )) MB)"
			gzip -9 -f "${candidate}"
			mv "${candidate}.gz" "${candidate}"
		else
			echo "    WARNING: ${name} is $(( size / 1024 / 1024 )) MB and cannot be split"
		fi
	}
done

# Cloudflare needs the right MIME type for .wasm or the browser refuses to
# stream-compile it, and long-lived caching on the immutable pack parts keeps
# repeat loads cheap.
# A gzipped file served without Content-Encoding: gzip arrives as gzip bytes
# and fails to instantiate, so that header is required, not cosmetic.
cat > "${stage_dir}/_headers" <<'HEADERS'
/index.side.wasm
  Content-Type: application/wasm
  Content-Encoding: gzip
  Cache-Control: public, max-age=31536000, immutable

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
