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
#     * index.pck (750 MB) - split into 8 MB content-hashed parts under parts/
#       by split-pack.sh, and rejoined in the browser by pck-loader.js. The
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

if [[ "${rebuild}" == 1 || ! -f "${build_dir}/index.html" || ! -f "${build_dir}/content.pck" ]]; then
	echo "==> Building web export"
	"${project_dir}/tools/web.sh" --rebuild --export-only
fi

if [[ ! -f "${build_dir}/index.html" ]]; then
	echo "No build at ${build_dir}. Run ./artea/tools/web.sh --rebuild first." >&2
	exit 1
fi

echo "==> Staging deployment in ${stage_dir}"
rm -rf "${stage_dir}"
mkdir -p "${stage_dir}"

# Content-hashed parts and manifests, the same layout local ./web and the
# Vercel export use (see split-pack.sh). Splitting from the pack that was
# actually exported, with the hash in every part name, is what keeps the
# manifest honest: it can only ever list parts cut from its own export.
for big in "${build_dir}/index.pck" "${build_dir}/content.pck" "${build_dir}/index.side.wasm"; do
	[[ -f "${big}" ]] && "${project_dir}/tools/split-pack.sh" "${big}"
done

# Copy everything except what must not be uploaded: the unsplit originals
# (the parts replace them, and both exceed the 25 MB limit), editor import
# sidecars, and Vercel's local files.
for path in "${build_dir}"/*; do
	name="$(basename "${path}")"
	case "${name}" in
		index.pck|content.pck|index.side.wasm|*.import|*.tmp) continue ;;
		.env.local|.vercel|vercel.json) continue ;;   # Vercel CLI token/config, never deploy
	esac
	cp -R "${path}" "${stage_dir}/"
done

# ADR-0002: parts are named by content hash, so they can be cached forever.
# Everything else - the HTML, the part manifests, the engine js/wasm whose
# names never change - is no-cache: revalidated on every visit (a ~130 byte 304
# when unchanged), so a new export can never pair old modules with a new pack
# (web.txt Problem 3). Cloudflare joins a header set by two matching rules with
# a comma, so /parts/* detaches the catch-all value before setting its own.
# Cloudflare also needs the right MIME type for .wasm or the browser refuses to
# stream-compile it.
cat > "${stage_dir}/_headers" <<'HEADERS'
/*
  Cache-Control: no-cache

/parts/*
  ! Cache-Control
  Cache-Control: public, max-age=31536000, immutable

/*.wasm
  Content-Type: application/wasm
HEADERS

echo "==> Verifying Cloudflare limits"
oversize=0
while IFS= read -r f; do
	# -c before -f: GNU stat -f means "filesystem status" and succeeds with
	# text instead of a size (see web.sh).
	size=$(stat -c '%s' "${f}" 2>/dev/null || stat -f '%z' "${f}")
	if (( size > max_bytes )); then
		echo "    TOO LARGE: $(basename "${f}") ($(( size / 1024 / 1024 )) MB)"
		oversize=$((oversize + 1))
	fi
done < <(find "${stage_dir}" -type f)
file_count=$(find "${stage_dir}" -type f | wc -l | tr -d ' ')
total_mb=$(find "${stage_dir}" -type f -exec sh -c 'stat -c %s "$1" 2>/dev/null || stat -f %z "$1"' _ {} \; \
	| awk '{ total += $1 } END { printf "%d", total / 1048576 }')
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
