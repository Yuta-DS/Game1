#!/usr/bin/env python3
"""Replace a full Web PCK with a small hub PCK plus its remaining content.

Run this immediately after the normal Web export. The source export stays the
authority: every omitted or differing file is copied byte-for-byte into the
second pack, and the combined file catalogue is checked before replacement.
"""

from __future__ import annotations

import argparse
import os
import re
import struct
import subprocess
from pathlib import Path


CORE_SCENES = (
    "res://scenes/start_screen.tscn",
    "res://scenes/New_Hub_World.tscn",
    "res://scenes/loading_scene.tscn",
)

# The hub creates some resources from script paths at runtime. Godot's scene
# dependency collector cannot see those; keep them in the first pack too.
CORE_INCLUDES = (
    "scripts/**", "data/**", "dialogue/**", "resources/**", "shaders/**",
    "addons/godot-firebase/**", "addons/dialogue_manager/**",
    "addons/proton_scatter/src/**", "addons/terrain_3d/terrain.gdextension",
    "addons/terrain_3d/bin/libterrain.web.release.wasm32.wasm",
    "assets3D/curling_surf/**", "default_bus_layout.tres",
    "choices_buttons.tres", "assets/Fonts/Cloud_finish_BOLD.ttf",
    "assets/Fonts/NewFont-Artea.otf",
    "assets/audio/**", "assets/SFX/**", "scenes/dialogue_ui.tscn",
    "scenes/mind_spark/cast/guardian_angel.tscn",
    "scenes/mind_spark/combat/enemy_base.tscn",
    "scenes/mind_spark/combat/thought_storm_warden.tscn",
    "scenes/mind_spark/quest_objects/quest_object_base.tscn",
    "scenes/mind_spark/quest_objects/thought_spark_collectible.tscn",
    "scenes/mind_spark/world_gate.tscn", "scenes/vegetation/**",
    "assets3D/trees/**", "assets3D/houses/red/**",
    "assets3D/castle_rooftop_parapet/**",
    "assets3D/mind_spark/aether_analysis_console/**",
    "assets3D/mind_spark/echo_garden_benchmark/**",
    "assets3D/mind_spark/heavenly_star_gate/**",
    "assets3D/mind_spark/puzzle_control_kit/**",
    "assets3D/kkNatureForest/**", "textures/dialogue_box.png",
    "assets3D/royal_garden/glb/MasonryBridge.glb",
    "assets3D/royal_garden/glb/FountainStone.glb",
    "assets3D/royal_garden/glb/WaterMotion.glb",
    "assets3D/grass/GrassShader.tres",
    "icon_milo.png",
)


def make_core_preset(source: str, export_path: str) -> str:
    blocks = list(re.finditer(
        r"(?ms)^\[preset\.(\d+)\]\n.*?(?=^\[preset\.\d+\]\n|\Z)", source))
    web = next((block for block in blocks if re.search(
        r'(?m)^name="Web"$', block.group())), None)
    if web is None:
        raise ValueError('Web export preset not found')
    number = max(int(block.group(1)) for block in blocks) + 1
    old_number = web.group(1)
    core = web.group().replace(f"[preset.{old_number}]", f"[preset.{number}]")
    core = core.replace(f"[preset.{old_number}.options]", f"[preset.{number}.options]")
    core = core.replace('name="Web"', 'name="WebCore"', 1)
    replacements = {
        "export_filter": '"scenes"',
        "export_files": 'PackedStringArray(' + ', '.join(
            '"' + item + '"' for item in CORE_SCENES) + ')',
        "include_filter": '"' + ','.join(CORE_INCLUDES) + '"',
        "export_path": '"' + export_path + '"',
    }
    for key, value in replacements.items():
        core, count = re.subn(rf'(?m)^{key}=.*$', f'{key}={value}', core, count=1)
        if count != 1:
            raise ValueError(f'Web preset has no {key}')
    return source.rstrip() + '\n\n' + core


def read_catalog(path: Path):
    with path.open('rb') as source:
        header = source.read(112)
        if len(header) != 112 or header[:4] != b'GDPC':
            raise ValueError(f'Not a Godot PCK: {path}')
        base = struct.unpack_from('<Q', header, 24)[0]
        directory = struct.unpack_from('<Q', header, 32)[0]
        source.seek(directory)
        count = struct.unpack('<I', source.read(4))[0]
        entries = {}
        for _ in range(count):
            length = struct.unpack('<I', source.read(4))[0]
            raw = source.read(length)
            name = raw.rstrip(b'\0').decode('utf-8')
            offset, size = struct.unpack('<QQ', source.read(16))
            digest = source.read(16)
            flags = source.read(4)
            if name in entries:
                raise ValueError(f'Duplicate PCK path: {name}')
            entries[name] = (raw, base + offset, size, digest, flags)
    return header, entries


def fingerprint(entry):
    return entry[2], entry[3]


def write_content_pack(full_path: Path, core_path: Path, output: Path):
    header, full = read_catalog(full_path)
    _, core = read_catalog(core_path)
    if 'project.binary' not in core or fingerprint(core['project.binary']) != fingerprint(full['project.binary']):
        raise ValueError('Core export changed project.binary; cannot safely start it')
    remaining = {name: entry for name, entry in full.items()
                 if name not in core or fingerprint(core[name]) != fingerprint(entry)}
    temporary = output.with_suffix('.pck.tmp')
    with full_path.open('rb') as source, temporary.open('wb') as dest:
        dest.write(header)
        written = []
        for name, (raw, offset, size, digest, flags) in remaining.items():
            dest.write(b'\0' * (-dest.tell() % 16))
            new_offset = dest.tell() - 112
            source.seek(offset)
            left = size
            while left:
                data = source.read(min(left, 1024 * 1024))
                if not data:
                    raise EOFError(f'Truncated PCK entry: {name}')
                dest.write(data)
                left -= len(data)
            written.append((raw, new_offset, size, digest, flags))
        directory = dest.tell()
        dest.write(struct.pack('<I', len(written)))
        for raw, offset, size, digest, flags in written:
            dest.write(struct.pack('<I', len(raw)))
            dest.write(raw)
            dest.write(struct.pack('<QQ', offset, size))
            dest.write(digest)
            dest.write(flags)
        updated_header = bytearray(header)
        struct.pack_into('<Q', updated_header, 32, directory)
        dest.seek(0)
        dest.write(updated_header)
    _, content = read_catalog(temporary)
    if set(content) != set(remaining) or any(
        fingerprint(content[name]) != fingerprint(entry)
        for name, entry in remaining.items()
    ):
        temporary.unlink(missing_ok=True)
        raise ValueError('Content PCK catalogue differs from the full export')
    for name, entry in full.items():
        restored = content.get(name, core.get(name))
        if restored is None or fingerprint(restored) != fingerprint(entry):
            temporary.unlink(missing_ok=True)
            raise ValueError(f'Split lost or changed {name}')
    os.replace(temporary, output)
    return len(core), len(content), len(full)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    project = args.project.resolve()
    build = project / 'builds/web'
    full = build / 'index.pck'
    core = build / 'index.core.pck'
    content = build / 'content.pck'
    presets = project / 'export_presets.cfg'
    if not full.is_file():
        parser.error(f'Full Web export missing: {full}')
    original = presets.read_bytes()
    modified = make_core_preset(original.decode('utf-8'), 'builds/web/index.core.pck')
    try:
        presets.write_text(modified, encoding='utf-8')
        subprocess.run([
            str(project / 'tools/with-web-export-plugins.sh'), str(args.godot),
            '--headless', '--path', str(project), '--export-pack', 'WebCore', str(core),
        ], check=True)
    finally:
        presets.write_bytes(original)
    core_count, content_count, full_count = write_content_pack(full, core, content)
    backup = build / 'index.full.pck'
    os.replace(full, backup)
    try:
        os.replace(core, full)
    except BaseException:
        os.replace(backup, full)
        raise
    backup.unlink()
    print(f'Web split complete: core={full.stat().st_size} bytes / {core_count} files, '
          f'content={content.stat().st_size} bytes / {content_count} files; '
          f'all {full_count} full-export files accounted for')


if __name__ == '__main__':
    main()
