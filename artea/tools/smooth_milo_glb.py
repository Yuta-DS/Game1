#!/usr/bin/env python3
"""Create a softer Milo GLB without Blender or changing its animation rig.

The source model uses solid-colour materials, so its UVs can safely be rebuilt
while a single Loop-style subdivision pass rounds the visible character parts.
All nodes, skins, inverse bind matrices, and animation data remain untouched.
"""

from __future__ import annotations

import json
import math
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets3D/characters/milo_villager_lowpoly.glb"
OUTPUT = ROOT / "assets3D/characters/milo_villager_smooth.glb"
SMOOTH_MATERIALS = {
    "Milo Navy Mayor Coat",
    "Milo White Fur",
    "Milo Cream Fur",
    "Milo Moustache",
    "Milo Trousers",
    "Milo Brown Shoes",
}

COMPONENT_FORMAT = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}
TYPE_WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path: Path):
    raw = path.read_bytes()
    magic, version, _length = struct.unpack_from("<4sII", raw, 0)
    if magic != b"glTF" or version != 2:
        raise ValueError(f"{path} is not a GLB 2.0 file")
    offset = 12
    chunks = []
    while offset < len(raw):
        length, kind = struct.unpack_from("<II", raw, offset)
        offset += 8
        chunks.append((kind, raw[offset:offset + length]))
        offset += length
    document = json.loads(next(data for kind, data in chunks if kind == 0x4E4F534A))
    binary = bytearray(next(data for kind, data in chunks if kind == 0x004E4942))
    return document, binary


def accessor_values(document, binary, accessor_index):
    accessor = document["accessors"][accessor_index]
    view = document["bufferViews"][accessor["bufferView"]]
    component_type = accessor["componentType"]
    fmt = COMPONENT_FORMAT[component_type]
    width = TYPE_WIDTH[accessor["type"]]
    scalar_size = struct.calcsize("<" + fmt)
    stride = view.get("byteStride", scalar_size * width)
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    unpack = struct.Struct("<" + fmt * width).unpack_from
    return [unpack(binary, start + i * stride) for i in range(accessor["count"])]


def normalized(values):
    length = math.sqrt(sum(value * value for value in values))
    return tuple(value / length for value in values) if length > 1.0e-9 else (0.0, 1.0, 0.0)


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def scale(a, factor):
    return tuple(value * factor for value in a)


def blend_skin(joints_a, weights_a, joints_b, weights_b):
    combined = {}
    for joint, weight in zip(joints_a, weights_a):
        combined[int(joint)] = combined.get(int(joint), 0.0) + float(weight) * 0.5
    for joint, weight in zip(joints_b, weights_b):
        combined[int(joint)] = combined.get(int(joint), 0.0) + float(weight) * 0.5
    strongest = sorted(combined.items(), key=lambda item: item[1], reverse=True)[:4]
    total = sum(weight for _joint, weight in strongest) or 1.0
    joints = tuple([joint for joint, _weight in strongest] + [0] * (4 - len(strongest)))
    weights = tuple([weight / total for _joint, weight in strongest] + [0.0] * (4 - len(strongest)))
    return joints, weights


def subdivide(positions, source_normals, uvs, joints, weights, indices):
    # Weld the UV seam and sphere poles using position and skin influence. Milo
    # uses flat-colour materials, so this is both safe and necessary for a clean
    # continuous silhouette.
    welded = {}
    old_to_new = []
    new_positions, new_normals, new_uvs, new_joints, new_weights = [], [], [], [], []
    for position, normal, uv, joint, weight in zip(positions, source_normals, uvs, joints, weights):
        key = tuple(round(value, 6) for value in position) + tuple(joint) + tuple(round(value, 4) for value in weight)
        if key not in welded:
            welded[key] = len(new_positions)
            new_positions.append(tuple(position))
            new_normals.append(tuple(normal))
            new_uvs.append(tuple(uv))
            new_joints.append(tuple(int(value) for value in joint))
            new_weights.append(tuple(weight))
        old_to_new.append(welded[key])
    triangles = [tuple(old_to_new[index] for index in indices[i:i + 3]) for i in range(0, len(indices), 3)]
    triangles = [triangle for triangle in triangles if len(set(triangle)) == 3]

    edge_opposites = {}
    neighbors = [set() for _ in new_positions]
    for a, b, c in triangles:
        for start, end, opposite in ((a, b, c), (b, c, a), (c, a, b)):
            edge = tuple(sorted((start, end)))
            edge_opposites.setdefault(edge, []).append(opposite)
            neighbors[start].add(end)
            neighbors[end].add(start)

    component_min_height = [0.0 for _ in new_positions]
    visited = set()
    for seed in range(len(new_positions)):
        if seed in visited:
            continue
        stack = [seed]
        component = []
        visited.add(seed)
        while stack:
            vertex = stack.pop()
            component.append(vertex)
            for neighbor in neighbors[vertex]:
                if neighbor not in visited:
                    visited.add(neighbor)
                    stack.append(neighbor)
        minimum_height = min(new_positions[vertex][1] for vertex in component)
        for vertex in component:
            component_min_height[vertex] = minimum_height
        if minimum_height > 1.60 and len(component) >= 6:
            # Each ear shell is a shallow triangular prism. Its front and back
            # apexes were slightly offset, producing a blunt cap in front view.
            # Align only those two apexes in X/Z while preserving their depth.
            tips = sorted(component, key=lambda vertex: new_positions[vertex][1], reverse=True)[:2]
            tip_x = sum(new_positions[vertex][0] for vertex in tips) * 0.5
            tip_height = max(new_positions[vertex][1] for vertex in tips)
            for vertex in tips:
                position = new_positions[vertex]
                new_positions[vertex] = (tip_x, tip_height, position[2])

    edge_vertices = {}
    for edge in edge_opposites:
        a, b = edge
        midpoint = scale(add(new_positions[a], new_positions[b]), 0.5)
        edge_length = math.dist(new_positions[a], new_positions[b])
        normal_a = normalized(new_normals[a])
        normal_b = normalized(new_normals[b])
        normal_dot = max(-1.0, min(1.0, sum(x * y for x, y in zip(normal_a, normal_b))))
        sin_half = math.sqrt(max(0.0, (1.0 - normal_dot) * 0.5))
        cos_half = math.sqrt(max(0.0, (1.0 + normal_dot) * 0.5))
        sagitta = 0.0 if sin_half < 1.0e-5 else edge_length * (1.0 - cos_half) / (2.0 * sin_half)
        # A cap protects deliberately sharp details such as ears and lapels.
        sagitta = min(sagitta, edge_length * 0.22)
        # The two disconnected cream ear shells begin above the head mass.
        # Subdivide their faces for clean lighting but retain the authored
        # triangular silhouette instead of turning the tips into round knobs.
        if component_min_height[a] > 1.60:
            sagitta = 0.0
        position = add(midpoint, scale(normalized(add(normal_a, normal_b)), sagitta))
        edge_vertices[edge] = len(new_positions)
        new_positions.append(position)
        new_normals.append(normalized(add(normal_a, normal_b)))
        new_uvs.append(scale(add(new_uvs[a], new_uvs[b]), 0.5))
        blended_joints, blended_weights = blend_skin(new_joints[a], new_weights[a], new_joints[b], new_weights[b])
        new_joints.append(blended_joints)
        new_weights.append(blended_weights)

    output_indices = []
    for a, b, c in triangles:
        if component_min_height[a] > 1.60:
            output_indices.extend((a, b, c))
            continue
        ab = edge_vertices[tuple(sorted((a, b)))]
        bc = edge_vertices[tuple(sorted((b, c)))]
        ca = edge_vertices[tuple(sorted((c, a)))]
        output_indices.extend((a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca))

    normals = [(0.0, 0.0, 0.0) for _ in new_positions]
    for i in range(0, len(output_indices), 3):
        a, b, c = output_indices[i:i + 3]
        pa, pb, pc = new_positions[a], new_positions[b], new_positions[c]
        ab = tuple(pb[j] - pa[j] for j in range(3))
        ac = tuple(pc[j] - pa[j] for j in range(3))
        face = (ab[1] * ac[2] - ab[2] * ac[1], ab[2] * ac[0] - ab[0] * ac[2], ab[0] * ac[1] - ab[1] * ac[0])
        for vertex in (a, b, c):
            normals[vertex] = add(normals[vertex], face)
    normals = [normalized(normal) for normal in normals]
    for vertex in range(len(component_min_height)):
        if component_min_height[vertex] > 1.60:
            normals[vertex] = normalized(new_normals[vertex])
    return new_positions, normals, new_uvs, new_joints, new_weights, output_indices


def append_accessor(document, binary, values, component_type, accessor_type, target=None, include_bounds=False):
    while len(binary) % 4:
        binary.append(0)
    offset = len(binary)
    fmt = COMPONENT_FORMAT[component_type]
    width = TYPE_WIDTH[accessor_type]
    pack = struct.Struct("<" + fmt * width).pack
    for value in values:
        row = value if isinstance(value, (tuple, list)) else (value,)
        binary.extend(pack(*row))
    view = {"buffer": 0, "byteOffset": offset, "byteLength": len(binary) - offset}
    if target is not None:
        view["target"] = target
    document.setdefault("bufferViews", []).append(view)
    accessor = {
        "bufferView": len(document["bufferViews"]) - 1,
        "componentType": component_type,
        "count": len(values),
        "type": accessor_type,
    }
    if include_bounds:
        accessor["min"] = [min(value[i] for value in values) for i in range(width)]
        accessor["max"] = [max(value[i] for value in values) for i in range(width)]
    document.setdefault("accessors", []).append(accessor)
    return len(document["accessors"]) - 1


def write_glb(path, document, binary):
    document["buffers"][0]["byteLength"] = len(binary)
    json_bytes = json.dumps(document, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    binary += b"\0" * ((4 - len(binary) % 4) % 4)
    total = 12 + 8 + len(json_bytes) + 8 + len(binary)
    payload = bytearray(struct.pack("<4sII", b"glTF", 2, total))
    payload.extend(struct.pack("<II", len(json_bytes), 0x4E4F534A))
    payload.extend(json_bytes)
    payload.extend(struct.pack("<II", len(binary), 0x004E4942))
    payload.extend(binary)
    path.write_bytes(payload)


def main():
    document, binary = read_glb(SOURCE)
    material_names = [material.get("name", "") for material in document.get("materials", [])]
    for material in document.get("materials", []):
        if material.get("name") == "Milo Pink Nose":
            # The inner ears are intentionally thin inset triangles; rendering
            # both sides keeps them visible after Godot's GLTF axis conversion.
            material["doubleSided"] = True
    smoothed_surfaces = 0
    for mesh in document["meshes"]:
        for primitive in mesh["primitives"]:
            material_name = material_names[primitive.get("material", 0)]
            if material_name == "Milo Pink Nose":
                attributes = primitive["attributes"]
                positions = accessor_values(document, binary, attributes["POSITION"])
                positions = [
                    (position[0], position[1], position[2] + 0.045)
                    if position[1] > 1.65 else position
                    for position in positions
                ]
                attributes["POSITION"] = append_accessor(
                    document, binary, positions, 5126, "VEC3", 34962, True)
                continue
            if material_name not in SMOOTH_MATERIALS:
                continue
            attributes = primitive["attributes"]
            positions = accessor_values(document, binary, attributes["POSITION"])
            source_normals = accessor_values(document, binary, attributes["NORMAL"])
            uvs = accessor_values(document, binary, attributes["TEXCOORD_0"])
            joints = accessor_values(document, binary, attributes["JOINTS_0"])
            weights = accessor_values(document, binary, attributes["WEIGHTS_0"])
            indices = [value[0] for value in accessor_values(document, binary, primitive["indices"])]
            positions, normals, uvs, joints, weights, indices = subdivide(
                positions, source_normals, uvs, joints, weights, indices)
            attributes["POSITION"] = append_accessor(document, binary, positions, 5126, "VEC3", 34962, True)
            attributes["NORMAL"] = append_accessor(document, binary, normals, 5126, "VEC3", 34962)
            attributes["TEXCOORD_0"] = append_accessor(document, binary, uvs, 5126, "VEC2", 34962)
            attributes["JOINTS_0"] = append_accessor(document, binary, joints, 5123, "VEC4", 34962)
            attributes["WEIGHTS_0"] = append_accessor(document, binary, weights, 5126, "VEC4", 34962)
            primitive["indices"] = append_accessor(document, binary, indices, 5125, "SCALAR", 34963)
            smoothed_surfaces += 1
    write_glb(OUTPUT, document, binary)
    print(f"MILO_SMOOTH: {smoothed_surfaces} rounded material surfaces -> {OUTPUT}")


if __name__ == "__main__":
    main()
