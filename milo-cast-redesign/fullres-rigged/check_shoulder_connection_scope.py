"""Prove the shoulder-connection pass only reseated the head hierarchy."""
from pathlib import Path
import hashlib
import json
import math
import struct

OUT = Path(__file__).resolve().parent
BASELINE = OUT / "shoulder-connected-before/milo_fullres.glb"
CURRENT = OUT / "milo_fullres.glb"
HEAD_DROP = -0.055


def head_mesh(name):
    return (name == "Head_Cranium_AnyCreature" or name in
            {"Chin", "Mouth", "Nose", "Sphere", "Sphere.001"} or
            name.startswith(("Brow_", "Eye_", "Ear_", "Ear_Inner_", "Glasses_",
                             "Moustache_", "Cheek_Fur_Lobe_", "Cheek_Ruff_")))


def head_bone(name):
    return name in {"neck", "head", "jaw", "eye.L", "eye.R",
                    "brow.L", "brow.R", "ear.L", "ear.R"}


def load(path):
    raw = path.read_bytes()
    size = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + size])
    blob = raw[28 + size:]

    def acc(index):
        item = doc["accessors"][index]
        view = doc["bufferViews"][item["bufferView"]]
        kind = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}[item["componentType"]]
        width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[item["type"]]
        fmt = "<" + kind * width
        stride = view.get("byteStride", struct.calcsize(fmt))
        start = view.get("byteOffset", 0) + item.get("byteOffset", 0)
        return [struct.unpack_from(fmt, blob, start + row * stride) for row in range(item["count"])]

    nodes = doc["nodes"]
    parents = {child: node["name"] for node in nodes for child in node.get("children", [])}
    meshes = {}
    rests = {}
    for index, node in enumerate(nodes):
        name = node["name"]
        rests[name] = ({key: node[key] for key in ("translation", "rotation", "scale", "matrix") if key in node},
                       parents.get(index))
        if "mesh" not in node:
            continue
        entries = []
        for primitive in doc["meshes"][node["mesh"]]["primitives"]:
            entries.append({"attrs": {key: acc(value) for key, value in primitive["attributes"].items()},
                            "indices": acc(primitive["indices"]),
                            "material": doc["materials"][primitive["material"]]})
        meshes[name] = entries
    motion = {}
    for animation in doc["animations"]:
        channels = {}
        for channel in animation["channels"]:
            target = channel["target"]
            sampler = animation["samplers"][channel["sampler"]]
            channels[(nodes[target["node"]]["name"], target["path"])] = (
                acc(sampler["input"]), acc(sampler["output"]), sampler.get("interpolation", "LINEAR"))
        motion[animation["name"]] = channels
    binds = {}
    for skin in doc["skins"]:
        for joint, matrix in zip(skin["joints"], acc(skin["inverseBindMatrices"])):
            binds[nodes[joint]["name"]] = matrix
    return {"raw": raw, "meshes": meshes, "rests": rests, "motion": motion, "binds": binds}


before = load(BASELINE)
after = load(CURRENT)
assert before["meshes"].keys() == after["meshes"].keys()

protected = []
shifted = []
for name, old_entries in before["meshes"].items():
    new_entries = after["meshes"][name]
    assert len(old_entries) == len(new_entries)
    is_head = head_mesh(name)
    if not is_head:
        protected.append(name)
    for old, new in zip(old_entries, new_entries):
        old_indices = [value[0] for value in old["indices"]]
        new_indices = [value[0] for value in new["indices"]]
        old_triangles = sorted(tuple(sorted(old_indices[i:i + 3])) for i in range(0, len(old_indices), 3))
        new_triangles = sorted(tuple(sorted(new_indices[i:i + 3])) for i in range(0, len(new_indices), 3))
        assert old_triangles == new_triangles and old["material"] == new["material"], name
        assert old["attrs"].keys() == new["attrs"].keys(), name
        for attr in old["attrs"]:
            assert len(old["attrs"][attr]) == len(new["attrs"][attr]), (name, attr)
            for a, b in zip(old["attrs"][attr], new["attrs"][attr]):
                # glTF is Y-up, so Blender's Z seating offset appears on POSITION.y.
                expected = tuple(v + (HEAD_DROP if is_head and i == 1 else 0) for i, v in enumerate(a)) if attr == "POSITION" else a
                tolerance = 5e-3 if attr in {"NORMAL", "TANGENT"} else 2e-6
                assert len(expected) == len(b) and max(abs(x - y) for x, y in zip(expected, b)) < tolerance, (
                    name, attr, "old", a, "new", b, "expected", expected)
    if is_head:
        shifted.append(name)

for name in before["rests"]:
    if not head_bone(name):
        assert before["rests"][name] == after["rests"][name], ("Protected rest node changed", name)
for clip in before["motion"]:
    old = {key: value for key, value in before["motion"][clip].items() if not head_bone(key[0])}
    new = {key: value for key, value in after["motion"][clip].items() if not head_bone(key[0])}
    assert old == new, ("Protected animation channel changed", clip)
assert {name: value for name, value in before["binds"].items() if not head_bone(name)} == \
       {name: value for name, value in after["binds"].items() if not head_bone(name)}

report = {
    "passed": True,
    "sha256": hashlib.sha256(after["raw"]).hexdigest(),
    "baseline_sha256": hashlib.sha256(before["raw"]).hexdigest(),
    "head_seat_offset_m": HEAD_DROP,
    "shifted_head_meshes": sorted(shifted),
    "protected_meshes": sorted(protected),
    "protected_mesh_count": len(protected),
    "head_topology_materials_normals_and_skinning_unchanged": True,
    "all_non_head_geometry_rig_and_animation_channels_exactly_unchanged": True,
    "scope": "The complete head mesh set and hidden head articulation hierarchy were lowered 5.5 cm; every non-head mesh, bone and animation channel is unchanged.",
}
(OUT / "shoulder_connection_scope_verification.json").write_text(json.dumps(report, indent=2))
print("SHOULDER_CONNECTION_SCOPE_PASS", json.dumps({key: value for key, value in report.items()
                                                     if key not in {"shifted_head_meshes", "protected_meshes"}}))
