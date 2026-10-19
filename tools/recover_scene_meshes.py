"""Recover missing visual meshes from the authored triangle geometry in scenes.

The checkout contains collision triangles but not the three referenced model
sources. Keep those triangles, scene transforms and existing colliders intact.
Generated assets have flat normals and a restrained material; they are recovered
geometry, not a claim to reproduce missing texture/material source files.
"""
import json
import math
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "artea"
SOURCES = [
    ("assets3D/worlds/popthought.tscn", "assets3D/worlds/low_poly_cloud.glb", [0.85, 0.90, 0.94, 1]),
    ("textures/grass_common_short_2.tscn", "assets3D/stylizedNature/Grass_Common_Short.gltf", [0.35, 0.52, 0.30, 1]),
    ("textures/common_tree_12.tscn", "assets3D/stylizedNature/CommonTree_1.gltf", [0.42, 0.55, 0.34, 1]),
]

def recover(scene, target, colour):
    target = ROOT / target
    if target.exists():
        print(f"Already present: {target.name}")
        return
    text = (ROOT / scene).read_text(encoding="utf-8")
    match = re.search(r"data = PackedVector3Array\(([^)]+)\)", text)
    if not match and target.stem != "Grass_Common_Short":
        raise ValueError(f"No authored triangle geometry in {scene}")
    if match:
        coords = [float(v.strip()) for v in match.group(1).split(",")]
    else:
        # The grass wrapper has no triangle source. Supply a small eight-blade
        # low-poly tuft at the same model scale instead of a missing scene.
        coords = []
        for i in range(8):
            angle = i * math.tau / 8
            x, z = math.cos(angle), math.sin(angle)
            coords.extend([x-0.2, 0, z, x+0.2, 0, z, x*1.3, 1.7+(i%3)*0.3, z*1.3])
    if len(coords) % 9:
        raise ValueError("Incomplete triangle")
    vertices = [coords[i:i+3] for i in range(0, len(coords), 3)]
    normals = []
    for i in range(0, len(vertices), 3):
        a, b, c = vertices[i:i+3]
        ab = [b[j] - a[j] for j in range(3)]
        ac = [c[j] - a[j] for j in range(3)]
        n = [ab[1]*ac[2]-ab[2]*ac[1], ab[2]*ac[0]-ab[0]*ac[2], ab[0]*ac[1]-ab[1]*ac[0]]
        length = math.sqrt(sum(v*v for v in n)) or 1
        normals.extend([v / length for v in n] * 3)
    positions = struct.pack(f"<{len(coords)}f", *coords)
    binary = positions + struct.pack(f"<{len(normals)}f", *normals)
    doc = {
        "asset": {"version": "2.0", "generator": "Artea authored scene triangle recovery"},
        "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0, "name": target.stem}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1}, "material": 0}]}],
        "materials": [{"doubleSided": True, "pbrMetallicRoughness": {"baseColorFactor": colour, "metallicFactor": 0, "roughnessFactor": 0.95}}],
        "buffers": [{"byteLength": len(binary)}],
        "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": len(positions), "target": 34962}, {"buffer": 0, "byteOffset": len(positions), "byteLength": len(binary)-len(positions), "target": 34962}],
        "accessors": [{"bufferView": 0, "componentType": 5126, "count": len(vertices), "type": "VEC3", "min": [min(v[j] for v in vertices) for j in range(3)], "max": [max(v[j] for v in vertices) for j in range(3)]}, {"bufferView": 1, "componentType": 5126, "count": len(vertices), "type": "VEC3"}],
    }
    if target.suffix == ".glb":
        data = json.dumps(doc).encode()
        data += b" " * (-len(data) % 4)
        binary += b"\0" * (-len(binary) % 4)
        target.write_bytes(struct.pack("<III", 0x46546C67, 2, 28 + len(data) + len(binary)) + struct.pack("<II", len(data), 0x4E4F534A) + data + struct.pack("<II", len(binary), 0x004E4942) + binary)
    else:
        buffer = target.with_suffix(".recovered.bin")
        buffer.write_bytes(binary)
        doc["buffers"][0]["uri"] = buffer.name
        target.write_text(json.dumps(doc), encoding="utf-8")
    print(f"Recovered {target.name}: {len(vertices)//3} authored triangles")

if __name__ == "__main__":
    for spec in SOURCES:
        recover(*spec)
