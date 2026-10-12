#!/usr/bin/env bash
# Split a large web build file into content-hashed parts plus a manifest.
#
#   ./artea/tools/split-pack.sh BUILD_DIR/index.pck
#   ./artea/tools/split-pack.sh BUILD_DIR/index.side.wasm
#
# Writes, next to the file:
#
#   parts/index.pck.<hash>.part00, part01, ...   8 MB slices, named by content
#   index.pck.parts.json                          {"count","bytes","partBytes",
#                                                  "hash","parts":[{name,size}]}
#
# pck-loader.js fetches the manifest uncached, then the parts it lists. Because
# a part's name carries the hash of the whole file it came from, a new export
# always produces new part names: hosts can serve parts/ as immutable, and a
# manifest can never point at parts cut from a different export (web.txt
# Problem 2). Every deploy path (local ./web, Vercel, Cloudflare) splits here so
# they all ship the same layout. The source file is left in place.
#
# Idempotent: when the manifest already matches the file's hash and its parts
# exist, nothing is rewritten.
set -euo pipefail

file="${1:?usage: split-pack.sh FILE}"
[[ -f "${file}" ]] || { echo "split-pack: no such file ${file}" >&2; exit 1; }

dir="$(cd "$(dirname "${file}")" && pwd)"
name="$(basename "${file}")"
manifest="${dir}/${name}.parts.json"
part_bytes=$((8 * 1024 * 1024))

# sha256sum on Linux and Git Bash, shasum on macOS. 16 hex chars is plenty to
# tell exports apart and keeps the names readable.
if command -v sha256sum >/dev/null 2>&1; then
	hash=$(sha256sum "${file}" | cut -c1-16)
else
	hash=$(shasum -a 256 "${file}" | cut -c1-16)
fi
# GNU stat first would be wrong on macOS, BSD stat first wrong on Linux; see
# web.sh for why -c must come before -f.
size=$(stat -c '%s' "${file}" 2>/dev/null || stat -f '%z' "${file}")

# Always drop the old unhashed layout and parts of every other export of this
# file, even when this export is already split - a leftover stages and uploads
# as dead weight. Older exports reached three-digit part numbers, hence [0-9]*.
mkdir -p "${dir}/parts"
rm -f "${dir}/${name}".part[0-9]*
for stale in "${dir}/parts/${name}".*.part[0-9]*; do
	[[ -e "${stale}" && "${stale}" != "${dir}/parts/${name}.${hash}."* ]] && rm -f "${stale}"
done

if [[ -f "${manifest}" ]] && grep -q "\"hash\":\"${hash}\"" "${manifest}" \
		&& [[ -f "${dir}/parts/${name}.${hash}.part00" ]]; then
	echo "  ${name}: parts up to date (${hash})"
	exit 0
fi

rm -f "${dir}/parts/${name}.${hash}".part[0-9]* "${manifest}"

split -b "${part_bytes}" "${file}" "${dir}/parts/${name}.${hash}.tmp"
# split(1) names its output aa, ab, ...; rename to the numeric parts the loader
# and the manifest use.
index=0
entries=""
for tmp in "${dir}/parts/${name}.${hash}.tmp"??; do
	part="$(printf '%s.%s.part%02d' "${name}" "${hash}" "${index}")"
	mv "${tmp}" "${dir}/parts/${part}"
	part_size=$(stat -c '%s' "${dir}/parts/${part}" 2>/dev/null || stat -f '%z' "${dir}/parts/${part}")
	entries+="${entries:+,}{\"name\":\"parts/${part}\",\"size\":${part_size}}"
	index=$((index + 1))
done

# "bytes" stays the first key: web.sh status reads it with a simple sed.
printf '{"bytes":%d,"count":%d,"partBytes":%d,"hash":"%s","parts":[%s]}\n' \
	"${size}" "${index}" "${part_bytes}" "${hash}" "${entries}" > "${manifest}"
echo "  ${name}: ${index} parts (${hash})"
