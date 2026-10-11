#!/usr/bin/env python3
"""List what a Godot 4 .pck contains, grouped by asset type.

    python artea/tools/pck-contents.py [artea/builds/web/index.pck] [--top N]
    python artea/tools/pck-contents.py A.pck --compare B.pck

--compare checks that two packs hold exactly the same files with exactly the
same bytes (by the MD5 Godot records for each file), ignoring the order they
are stored in. Godot does not keep that order stable between exports of an
unchanged project, so comparing whole-file hashes of two packs is meaningless;
this is how "desktop output is byte-for-byte unaffected" (issue #39) is checked.

Reads the pack's own file directory (no Godot needed) and sums sizes by the
kind of source asset each entry came from: an imported texture lives in the
pack as .godot/imported/<name>.png-<hash>.ctex, so it is counted as a texture
even though its stored extension is .ctex. Used for the before/after tables in
docs/web-baseline.md (issue #39).
"""
import struct
import sys
from collections import defaultdict

TYPES = [
    ("texture", (".ctex", ".ctexarray", ".ccube", ".ccubearray", ".ctex3d", ".dds", ".webp")),
    ("audio", (".oggvorbisstr", ".sample", ".mp3str", ".oggstr", ".qoa")),
    ("3D scene (glb/fbx)", (".scn",)),
    ("mesh", (".mesh",)),
    ("font", (".fontdata",)),
    ("script", (".gdc", ".gd", ".gde")),
    ("shader", (".gdshader", ".shader")),
    ("scene/resource", (".tscn", ".scn", ".res", ".tres")),
]
SOURCE_HINT = {
    ".png": "texture", ".jpg": "texture", ".jpeg": "texture", ".webp": "texture",
    ".svg": "texture", ".hdr": "texture", ".exr": "texture", ".tga": "texture",
    ".ogg": "audio", ".wav": "audio", ".mp3": "audio",
    ".glb": "3D scene (glb/fbx)", ".gltf": "3D scene (glb/fbx)", ".fbx": "3D scene (glb/fbx)",
    ".obj": "mesh", ".ttf": "font", ".otf": "font", ".woff2": "font",
}


def read_directory(path):
    with open(path, "rb") as f:
        magic = f.read(4)
        if magic != b"GDPC":
            sys.exit(f"{path}: not a Godot pack (magic {magic!r})")
        version, _major, _minor, _patch, flags = struct.unpack("<5I", f.read(20))
        file_base = struct.unpack("<Q", f.read(8))[0]
        if version >= 3:
            dir_offset = struct.unpack("<Q", f.read(8))[0]
            f.seek(dir_offset)
        else:
            f.read(16 * 4)  # reserved
        if flags & 1:
            sys.exit("encrypted pack directory is not supported")
        count = struct.unpack("<I", f.read(4))[0]
        entries = []
        for _ in range(count):
            length = struct.unpack("<I", f.read(4))[0]
            name = f.read(length).rstrip(b"\0").decode("utf-8", "replace")
            offset, size = struct.unpack("<QQ", f.read(16))
            md5 = f.read(16).hex()
            f.read(4)   # flags
            entries.append((name, size, md5))
            OFFSETS[name] = file_base + offset
        return entries


# Pack offsets, so an ambiguous .res can be identified by its header.
OFFSETS = {}
TEXTURE_TYPES = ("PortableCompressedTexture2D", "ImageTexture", "CompressedTexture2D")


def resource_type(path, name):
    """The class name in a binary resource's RSRC header, or '' if unreadable."""
    with open(path, "rb") as f:
        f.seek(OFFSETS[name])
        head = f.read(64)
    if head[:4] != b"RSRC":
        return ""  # RSCC (compressed) or not a binary resource
    length = struct.unpack("<I", head[24:28])[0]
    return head[28:28 + length].rstrip(bytes(1)).decode("ascii", "replace")


def classify(name):
    lower = name.lower()
    if "/.godot/imported/" in "/" + lower or lower.startswith(".godot/imported/"):
        # <source>.<srcext>-<hash>.<storedext>: the source extension says what it was.
        base = lower.rsplit("/", 1)[-1]
        source = base.rsplit("-", 1)[0]
        for ext, kind in SOURCE_HINT.items():
            if source.endswith(ext):
                return kind
    for kind, exts in TYPES:
        if lower.endswith(exts):
            return kind
    return "other"


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    top = int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 0
    path = args[0] if args else "artea/builds/web/index.pck"
    entries = read_directory(path)
    totals = defaultdict(lambda: [0, 0])
    if "--compare" in sys.argv:
        other = read_directory(sys.argv[sys.argv.index("--compare") + 1])
        mine = {name: (size, md5) for name, size, md5 in entries}
        theirs = {name: (size, md5) for name, size, md5 in other}
        differ = sorted(n for n in mine.keys() & theirs.keys() if mine[n] != theirs[n])
        only_a, only_b = sorted(mine.keys() - theirs.keys()), sorted(theirs.keys() - mine.keys())
        for label, names in (("differ", differ), ("only in first", only_a), ("only in second", only_b)):
            for n in names[:20]:
                print(f"{label}: {n}")
        same = not (differ or only_a or only_b)
        print(f"{len(mine)} vs {len(theirs)} files: {'IDENTICAL CONTENT' if same else 'DIFFERENT'}")
        sys.exit(0 if same else 1)
    for name, size, _md5 in entries:
        kind = classify(name)
        # Textures re-encoded at export (issue #39) are .res files under
        # .godot/exported/; their header says what they really are.
        if kind == "scene/resource" and name.endswith(".res")                 and resource_type(path, name) in TEXTURE_TYPES:
            kind = "texture"
        totals[kind][0] += size
        totals[kind][1] += 1
    grand = sum(t[0] for t in totals.values())
    print(f"{path}: {len(entries)} files, {grand / 1048576:.1f} MiB\n")
    print("| Asset type | Files | MiB | Share |")
    print("|---|---:|---:|---:|")
    for kind, (size, n) in sorted(totals.items(), key=lambda kv: -kv[1][0]):
        print(f"| {kind} | {n} | {size / 1048576:.1f} | {size / grand * 100:.0f}% |")
    print(f"| **Total** | **{len(entries)}** | **{grand / 1048576:.1f}** | |")
    if top:
        print(f"\nLargest {top}:")
        for name, size, _md5 in sorted(entries, key=lambda e: -e[1])[:top]:
            print(f"  {size / 1048576:8.2f} MiB  {classify(name):<20} {name}")


if __name__ == "__main__":
    main()
