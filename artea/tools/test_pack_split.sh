#!/usr/bin/env bash
# Checks tools/pack_split.gd (issues #35-#37): the project splits cleanly, each
# area's content is in its own Pack and not Core, no file is in two Packs,
# small Shared packs merge, tools/packs.cfg can pin a file to Core, and a scene
# that references a file in no Pack fails the build with a message naming both.
#
#   GODOT_BIN=... ./artea/tools/test_pack_split.sh
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
out="$(mktemp)"
broken="${project_dir}/scenes/zz_pack_split_broken.tscn"
config="${project_dir}/tools/packs.cfg"
config_backup="$(mktemp)"
cp "${config}" "${config_backup}"
trap 'rm -f "${out}" "${broken}"; mv -f "${config_backup}" "${config}"' EXIT

split() {
	"${godot_bin}" --headless --path "${project_dir}" --script res://tools/pack_split.gd -- "${out}" 2>&1
}
fail() { echo "FAIL: $*" >&2; exit 1; }

log="$(split)" || fail "the project does not split cleanly:"$'\n'"$(grep '^PACK' <<<"${log}")"
grep -q '"res://scripts/art_castle_floating_world.gd"' "${out}" || fail "galaxy script not in the Art Castle Pack"
python3 - "${out}" <<'PY' || fail "an area's content is in the wrong place (see above)"
import json, sys
split = json.load(open(sys.argv[1]))
core, packs = split["core"], split["packs"]
problems = []
left = [p for p in core if p.startswith(("res://assets3D/tree_of_life/", "res://assets3D/crown_line_train/"))]
if left:
    problems.append(f"Art Castle content left in Core: {left[:3]}")
# Issue #36: each Kingdom and the Crown of Life story in its own Pack.
for pack, scene in {
    "mind_spark": "res://scenes/popThoughtsMenu.tscn",
    "heart_melody": "res://scenes/music_minigame.tscn",
    "creators_light": "res://scenes/drawing_tool.tscn",
    "crown_of_life_story": "res://scenes/viewfinder/crown_of_life_story.tscn",
}.items():
    if scene not in packs.get(pack, {}).get("files", []):
        problems.append(f"{scene} is not in the {pack} Pack")
# web.txt Problem 5: the story's stone texture ships, with the story.
if "res://assets/textures/stone/rock023_alb_ht.png" not in packs["crown_of_life_story"]["files"]:
    problems.append("the story's stone texture is not in its Pack")
# No file in two Packs: a Pack's export leaves out every other Pack's files.
seen = {}
for pack, info in packs.items():
    for path in info["files"]:
        if path in seen:
            problems.append(f"{path} is in both {seen[path]} and {pack}")
        seen[path] = pack
print("\n".join(problems))
sys.exit(1 if problems else 0)
PY
grep -q "^CORE + HUB: .* budget" <<<"${log}" || fail "no Core + Hub size against the budget in the report"

# Issue #37: a Shared pack under the floor joins the nearest larger one. The
# Art Castle + Mind Spark + story textures (about 9.5 MB) join Art Castle +
# Mind Spark, the set one area away, not Heart Melody + story.
printf '[core]\npin=[]\nbudget_mb=100\n[shared]\nmerge_below_mb=12.0\n' > "${config}"
split >/dev/null || fail "the project does not split with a 12 MB merge floor"
python3 - "${out}" <<'PY' || fail "the small Shared pack was not merged into its nearest larger one"
import json, sys
packs = json.load(open(sys.argv[1]))["packs"]
merged = packs.get("shared_art_castle_mind_spark_crown_of_life_story", {"files": []})
ok = ("shared_art_castle_mind_spark" not in packs
      and "res://assets3D/mind_spark/quest_objects/glb/warden_anchor.glb" in merged["files"]
      and "shared_art_castle_mind_spark_crown_of_life_story" in packs["mind_spark"]["requires"]
      and "shared_heart_melody_crown_of_life_story" in packs)
sys.exit(0 if ok else 1)
PY

# A pin in tools/packs.cfg keeps a file in Core even though only areas use it.
printf '[core]\npin=["res://assets/audio/minigame/*.ogg"]\nbudget_mb=100\n[shared]\nmerge_below_mb=5.0\n' > "${config}"
split >/dev/null || fail "the project does not split with a pin"
python3 - "${out}" <<'PY' || fail "the pinned files did not stay in Core"
import json, sys
split = json.load(open(sys.argv[1]))
ok = ("res://assets/audio/minigame/happy.ogg" in split["core"]
      and all("res://assets/audio/minigame/happy.ogg" not in p["files"] for p in split["packs"].values()))
sys.exit(0 if ok else 1)
PY
cp "${config_backup}" "${config}"

cat > "${broken}" <<'TSCN'
[gd_scene format=3]

[ext_resource type="Texture2D" path="res://assets/zz_not_in_any_pack.png" id="1"]

[node name="Broken" type="Sprite2D"]
texture = ExtResource("1")
TSCN
if log="$(split)"; then
	fail "a scene referencing a missing file did not fail the build"
fi
grep -q "zz_pack_split_broken.tscn depends on res://assets/zz_not_in_any_pack.png" <<<"${log}" \
	|| fail "the failure does not name the scene and the missing file:"$'\n'"${log}"

echo "PACK_SPLIT: PASS"
