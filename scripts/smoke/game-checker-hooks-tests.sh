#!/usr/bin/env bash
# Smoke tests for the four game-art checker hooks: unity-traps meta-check, meshy glb-check, blender bpy-check, pixel-art sheet-check.
# Each fires on a broken fixture and stays silent on its nearest neighbour; every case asserts rc 0 (warn-only) and the event envelope.
# Why, limits, history: rationale/derivations/plugin-unity-traps.md § scripts/smoke/game-checker-hooks-tests.sh
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
U_HOOK="$ROOT/plugins/unity-traps/hooks/meta-check.sh"
M_HOOK="$ROOT/plugins/meshy/hooks/glb-check.sh"
B_HOOK="$ROOT/plugins/blender/hooks/bpy-check.sh"
P_HOOK="$ROOT/plugins/pixel-art/hooks/sheet-check.sh"

for t in jq python3 git; do
  command -v "$t" >/dev/null 2>&1 || { echo "SKIP: $t not available (the hooks fail open without it)"; exit 0; }
done
for h in "$U_HOOK" "$M_HOOK" "$B_HOOK" "$P_HOOK"; do
  [ -x "$h" ] || { echo "FAIL: hook missing or not executable: $h"; exit 1; }
done

pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
export CLAUDE_PLUGIN_DATA="$WS/data"
unset CC_UNITY_META_CHECK CC_GLB_CHECK CC_BPY_CHECK CC_PIXEL_CHECK
mkdir -p "$WS/bin" "$WS/nobin"
printf '#!/bin/sh\necho "Blender 5.2.3 LTS"\n' > "$WS/bin/blender"; chmod +x "$WS/bin/blender"
BASE_PATH="$(dirname "$(command -v jq)"):$(dirname "$(command -v python3)"):$(dirname "$(command -v git)"):/usr/bin:/bin"

# payload <event> <tool> <cwd> <transcript> <tool_use_id> <command> <file_path> [<tool_input json>]
payload() {
  jq -cn --arg e "$1" --arg t "$2" --arg cwd "$3" --arg tp "$4" --arg id "$5" --arg c "$6" --arg f "$7" --argjson ti "${8:-null}" \
    '{hook_event_name:$e, tool_name:$t, cwd:$cwd, transcript_path:$tp, session_id:"s1", tool_use_id:$id,
      tool_input:($ti // ({} + (if $c != "" then {command:$c} else {} end) + (if $f != "" then {file_path:$f} else {} end)))}'
}

# check <desc> <expect: fire|silent> <grep-pattern-or-empty> <hook> <payload> [env assignments...]
check() {
  local desc="$1" expect="$2" pat="$3" hook="$4" pl="$5" out rc ok=1 ev ctx
  shift 5
  out=$(printf '%s' "$pl" | env PATH="$BASE_PATH" "$@" bash "$hook" 2>/dev/null); rc=$?
  [ "$rc" -eq 0 ] || ok=0
  ev=$(printf '%s' "$pl" | jq -r '.hook_event_name')
  case "$expect" in
    fire)
      ctx=$(printf '%s' "$out" | jq -r --arg e "$ev" 'select(.hookSpecificOutput.hookEventName == $e) | .hookSpecificOutput.additionalContext' 2>/dev/null)
      [ -n "$ctx" ] || ok=0
      [ -z "$pat" ] || printf '%s' "$ctx" | grep -qE "$pat" || ok=0 ;;
    silent) [ -z "$out" ] || ok=0 ;;
  esac
  if [ "$ok" -eq 1 ]; then pass=$((pass + 1)); printf 'PASS  %s\n' "$desc"
  else fail=$((fail + 1)); printf 'FAIL  %s (rc=%s out=%s)\n' "$desc" "$rc" "$out"; fi
}

meta() { printf 'fileFormatVersion: 2\nguid: %s\n%s' "$1" "${2:-}"; }
cs() { printf 'using UnityEngine;\npublic class %s : MonoBehaviour {}\n' "$1"; }

# ---------- unity-traps: meta-check.sh ----------
U="$WS/unity"; mkdir -p "$U/Game/Assets/Scripts" "$U/Game/Assets/Gameplay" "$U/Game/ProjectSettings" "$U/Plain/Assets"
(cd "$U" && git init -q)
echo 'm_EditorVersion: 6000.3.1f1' > "$U/Game/ProjectSettings/ProjectVersion.txt"
meta 22222222222222222222222222222222 'folderAsset: yes\n' > "$U/Game/Assets/Scripts.meta"
meta 33333333333333333333333333333333 'folderAsset: yes\n' > "$U/Game/Assets/Gameplay.meta"
cs Player > "$U/Game/Assets/Scripts/Player.cs"; meta 1234567890abcdef1234567890abcdef > "$U/Game/Assets/Scripts/Player.cs.meta"
cs Enemy > "$U/Game/Assets/Scripts/Enemy.cs"; meta abcdefabcdefabcdefabcdefabcdefab > "$U/Game/Assets/Scripts/Enemy.cs.meta"
TU="$WS/u.jsonl"

mv "$U/Game/Assets/Scripts/Player.cs" "$U/Game/Assets/Gameplay/Player.cs"
MV='mv Game/Assets/Scripts/Player.cs Game/Assets/Gameplay/Player.cs'
check "unity: mv without its .meta fires moved-without-meta" fire 'moved-without-meta' "$U_HOOK" "$(payload PostToolUse Bash "$U" "$TU" u1 "$MV" "")"
check "unity: the same finding is silent the second time in one context" silent '' "$U_HOOK" "$(payload PostToolUse Bash "$U" "$TU" u2 "$MV" "")"
check "unity: a new context hears it again" fire 'moved-without-meta' "$U_HOOK" "$(payload PostToolUse Bash "$U" "$WS/u-other.jsonl" u3 "$MV" "")"
check "unity: PostToolUseFailure answers in its own envelope" fire 'moved-without-meta' "$U_HOOK" "$(payload PostToolUseFailure Bash "$U" "$WS/u-fail.jsonl" u4 "$MV" "")"
check "unity: CC_UNITY_META_CHECK=off is silent" silent '' "$U_HOOK" "$(payload PostToolUse Bash "$U" "$WS/u-off.jsonl" u5 "$MV" "")" CC_UNITY_META_CHECK=off
mv "$U/Game/Assets/Gameplay/Player.cs" "$U/Game/Assets/Scripts/Player.cs"

check "unity: ls of Assets (no move verb) is silent" silent '' "$U_HOOK" "$(payload PostToolUse Bash "$U" "$WS/u5.jsonl" u6 'ls -la Game/Assets && git status' "")"
check "unity: grep naming Assets is silent" silent '' "$U_HOOK" "$(payload PostToolUse Bash "$U" "$WS/u5.jsonl" u7 'grep -rn Player Game/Assets' "")"
mv "$U/Game/Assets/Scripts/Enemy.cs" "$U/Game/Assets/Gameplay/Enemy.cs"; mv "$U/Game/Assets/Scripts/Enemy.cs.meta" "$U/Game/Assets/Gameplay/Enemy.cs.meta"
check "unity: git mv of the asset and its .meta together is silent" silent '' "$U_HOOK" "$(payload PostToolUse Bash "$U" "$WS/u5.jsonl" u8 'git mv Game/Assets/Scripts/Enemy.cs Game/Assets/Gameplay/Enemy.cs && git mv Game/Assets/Scripts/Enemy.cs.meta Game/Assets/Gameplay/Enemy.cs.meta' "")"
cs Loot > "$U/Plain/Assets/Loot.cs"
check "unity: a move outside any Unity project is silent" silent '' "$U_HOOK" "$(payload PostToolUse Bash "$U" "$WS/u5.jsonl" u9 'mv Plain/Assets/Old.cs Plain/Assets/Loot.cs' "")"
cs Boss > "$U/Game/Assets/Scripts/Boss.cs"; meta 1234567890abcdef1234567890abcdef > "$U/Game/Assets/Scripts/Boss.cs.meta"
check "unity: a written .meta that duplicates a GUID fires" fire 'duplicate-guid' "$U_HOOK" "$(payload PostToolUse Write "$U" "$WS/u6.jsonl" u10 "" "$U/Game/Assets/Scripts/Boss.cs.meta")"
check "unity: a written .cs (not a .meta) is silent" silent '' "$U_HOOK" "$(payload PostToolUse Write "$U" "$WS/u7.jsonl" u11 "" "$U/Game/Assets/Scripts/Boss.cs")"
rm -f "$U/Game/Assets/Scripts/Boss.cs.meta" "$U/Game/Assets/Scripts/Boss.cs"
cs Coin > "$U/Game/Assets/Gameplay/Coin.cs"
check "unity: cp of a new asset into Assets (no .meta yet) is silent" silent '' "$U_HOOK" "$(payload PostToolUse Bash "$U" "$WS/u6b.jsonl" u10b "cp ../shared/Coin.cs Game/Assets/Gameplay/Coin.cs" "")"
rm -f "$U/Game/Assets/Gameplay/Coin.cs"
mv "$U/Game/Assets/Gameplay/Enemy.cs" "$U/Game/Assets/Gameplay/Foe.cs"; rm -f "$U/Game/Assets/Gameplay/Enemy.cs.meta"
check "unity: mv that also deleted the old .meta fires missing-meta" fire 'missing-meta Assets/Gameplay/Foe.cs' "$U_HOOK" "$(payload PostToolUse Bash "$U" "$WS/u6c.jsonl" u10c "mv Game/Assets/Gameplay/Enemy.cs Game/Assets/Gameplay/Foe.cs && rm Game/Assets/Gameplay/Enemy.cs.meta" "")"
rm -f "$U/Game/Assets/Gameplay/Foe.cs"
cs Shield > "$U/Game/Assets/Shield.cs"; meta 44444444444444444444444444444444 > "$U/Game/Assets/Shield.cs.meta"
mv "$U/Game/Assets/Shield.cs" "$U/Game/Assets/Gameplay/Shield.cs"
check "unity: a python shutil.move fires" fire 'moved-without-meta' "$U_HOOK" "$(payload PostToolUse Bash "$U" "$WS/u8.jsonl" u12 "python3 -c \"import shutil; shutil.move('Game/Assets/Shield.cs', 'Game/Assets/Gameplay/Shield.cs')\"" "")"
check "unity: without CLAUDE_PLUGIN_DATA the repo state dir ignores itself" fire 'moved-without-meta' "$U_HOOK" "$(payload PostToolUse Bash "$U" "$WS/u9.jsonl" u13 "mv Game/Assets/Shield.cs Game/Assets/Gameplay/Shield.cs" "")" CLAUDE_PLUGIN_DATA=
if [ -f "$U/.claude/unity-traps/.gitignore" ] && [ -z "$(git -C "$U" status --porcelain .claude 2>/dev/null)" ]; then
  pass=$((pass + 1)); echo "PASS  unity: repo-fallback state dir is invisible to git"
else
  fail=$((fail + 1)); echo "FAIL  unity: repo-fallback state dir is invisible to git"
fi

# ---------- meshy: glb-check.sh ----------
M="$WS/meshy"; mkdir -p "$M/assets"; (cd "$M" && git init -q)
mkglb() { python3 -I - "$1" "$2" "${3:-}" <<'PY'
import json, struct, sys
path, tris, ext = sys.argv[1], int(sys.argv[2]), sys.argv[3]
doc = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0}],
       "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "indices": 1}]}],
       "accessors": [{"count": 3, "componentType": 5126, "type": "VEC3", "min": [0, 0, 0], "max": [1, 1, 1]},
                     {"count": tris * 3, "componentType": 5125, "type": "SCALAR"}]}
if ext:
    doc["extensionsUsed"] = [ext]; doc["extensionsRequired"] = [ext]
text = json.dumps(doc).encode()
if path.endswith(".gltf"):
    open(path, "wb").write(text)
else:
    text += b" " * (-len(text) % 4)
    chunk = struct.pack("<II", len(text), 0x4E4F534A) + text
    open(path, "wb").write(struct.pack("<4sII", b"glTF", 2, 12 + len(chunk)) + chunk)
PY
}
TM="$WS/m.jsonl"
CURL='curl -fsSL -o assets/hero.glb https://example.invalid/hero.glb'
check "meshy: PreToolUse prints nothing" silent '' "$M_HOOK" "$(payload PreToolUse Bash "$M" "$TM" m1 "$CURL" "")"
mkglb "$M/assets/hero.glb" 60000
check "meshy: a 60k-triangle download fires the 15k budget" fire 'triangles 60,000 > --max-tris 15,000' "$M_HOOK" "$(payload PostToolUse Bash "$M" "$TM" m1 "$CURL" "")"
check "meshy: PreToolUse for a second call" silent '' "$M_HOOK" "$(payload PreToolUse Bash "$M" "$TM" m2 'curl -o assets/ok.glb https://example.invalid/ok.glb' "")"
mkglb "$M/assets/ok.glb" 100
check "meshy: a model within budget is silent" silent '' "$M_HOOK" "$(payload PostToolUse Bash "$M" "$TM" m2 'curl -o assets/ok.glb https://example.invalid/ok.glb' "")"
check "meshy: PreToolUse on a command naming no model" silent '' "$M_HOOK" "$(payload PreToolUse Bash "$M" "$TM" m3 'ls -la && git status' "")"
mkglb "$M/assets/stray.glb" 90000
check "meshy: a call naming no glb/gltf/meshy is not bracketed" silent '' "$M_HOOK" "$(payload PostToolUse Bash "$M" "$TM" m3 'ls -la && git status' "")"
check "meshy: PostToolUse with no PreToolUse marker is silent" silent '' "$M_HOOK" "$(payload PostToolUse Bash "$M" "$TM" m4 "curl -o assets/stray.glb https://example.invalid/x" "")"
mkglb "$M/assets/draco.gltf" 10 KHR_draco_mesh_compression
check "meshy: a written .gltf requiring an extension fires" fire 'requires extension KHR_draco_mesh_compression' "$M_HOOK" "$(payload PostToolUse Write "$M" "$TM" m5 "" "$M/assets/draco.gltf")"
MCP='mcp__meshy__meshy_download_model'
check "meshy: PreToolUse on a Meshy MCP download" silent '' "$M_HOOK" "$(payload PreToolUse "$MCP" "$M" "$TM" m6 "" "" '{"task_id":"t-1","format":"glb"}')"
mkdir -p "$M/meshy_output/run1"; printf 'not a model' > "$M/meshy_output/run1/model.glb"
check "meshy: an unreadable MCP download fires" fire 'unreadable as glTF 2.0' "$M_HOOK" "$(payload PostToolUse "$MCP" "$M" "$TM" m6 "" "" '{"task_id":"t-1","format":"glb"}')"
check "meshy: the same models are silent on the next call" silent '' "$M_HOOK" "$(payload PostToolUse Write "$M" "$TM" m7 "" "$M/assets/draco.gltf")"
check "meshy: CC_GLB_CHECK=off is silent" silent '' "$M_HOOK" "$(payload PostToolUse Write "$M" "$WS/m-off.jsonl" m8 "" "$M/assets/draco.gltf")" CC_GLB_CHECK=off

# ---------- blender: bpy-check.sh ----------
B="$WS/blender"; mkdir -p "$B/tools" "$B/old"; (cd "$B" && git init -q)
removed='import bpy\nact = bpy.context.object.animation_data.action\nfor fc in act.fcurves:\n    pass\n'
TB="$WS/b.jsonl"
printf "$removed" > "$B/tools/anim.py"
check "blender: a written bpy script with a 5.0 removal fires (target from PATH)" fire 'action-fcurves.*' "$B_HOOK" "$(payload PostToolUse Write "$B" "$TB" b1 "" "$B/tools/anim.py")" PATH="$WS/bin:$BASE_PATH"
check "blender: the target names its source" fire 'blender --version on PATH' "$B_HOOK" "$(payload PostToolUse Write "$B" "$WS/b-src.jsonl" b1s "" "$B/tools/anim.py")" PATH="$WS/bin:$BASE_PATH"
printf "$removed" > "$B/tools/heredoc.py"
check "blender: a heredoc write fires" fire 'tools/heredoc.py:3 ERROR' "$B_HOOK" "$(payload PostToolUse Bash "$B" "$TB" b2 "cat > tools/heredoc.py <<'EOF'
import bpy
EOF" "")" PATH="$WS/bin:$BASE_PATH"
printf "$removed" > "$B/tools/append.py"
check "blender: a >> write fires" fire 'tools/append.py:3 ERROR' "$B_HOOK" "$(payload PostToolUse Bash "$B" "$TB" b3 "echo 'x = 1' >> tools/append.py" "")" PATH="$WS/bin:$BASE_PATH"
check "blender: a non-write command is silent" silent '' "$B_HOOK" "$(payload PostToolUse Bash "$B" "$TB" b4 'ls -la && git status' "")" PATH="$WS/bin:$BASE_PATH"
printf "$removed" > "$B/tools/inbody.py"
check "blender: a .py named only inside a heredoc body is silent" silent '' "$B_HOOK" "$(payload PostToolUse Bash "$B" "$TB" b5 "cat > notes.md <<'EOF'
edit tools/inbody.py > tools/inbody.py
EOF" "")" PATH="$WS/bin:$BASE_PATH"
printf 'import os\nprint(os.getcwd())\n' > "$B/tools/plain.py"
check "blender: a .py that does not import bpy is silent" silent '' "$B_HOOK" "$(payload PostToolUse Write "$B" "$TB" b6 "" "$B/tools/plain.py")" PATH="$WS/bin:$BASE_PATH"
printf "$removed" > "$B/tools/nover.py"
check "blender: no .blend and no blender on PATH is silent" silent '' "$B_HOOK" "$(payload PostToolUse Write "$B" "$TB" b7 "" "$B/tools/nover.py")" PATH="$WS/nobin:$BASE_PATH"
printf 'BLENDER-v402\0\0\0\0\0' > "$B/old/scene.blend"
printf "$removed" > "$B/tools/legacy.py"
check "blender: a project .blend (4.2) wins over PATH (5.2), so a 5.0 removal is silent" silent '' "$B_HOOK" "$(payload PostToolUse Write "$B" "$TB" b8 "" "$B/tools/legacy.py")" PATH="$WS/bin:$BASE_PATH"
rm -f "$B/old/scene.blend"
O="$WS/outside"; mkdir -p "$O"; printf "$removed" > "$O/out.py"
check "blender: a .py outside the project root is silent" silent '' "$B_HOOK" "$(payload PostToolUse Write "$B" "$TB" b9 "" "$O/out.py")" PATH="$WS/bin:$BASE_PATH"
check "blender: CC_BPY_CHECK=off is silent" silent '' "$B_HOOK" "$(payload PostToolUse Write "$B" "$WS/b-off.jsonl" b10 "" "$B/tools/anim.py")" PATH="$WS/bin:$BASE_PATH" CC_BPY_CHECK=off

# ---------- pixel-art: sheet-check.sh ----------
P="$WS/pixel"; mkdir -p "$P/art" "$P/maps"; (cd "$P" && git init -q)
png() { python3 -I -c 'import struct,sys;open(sys.argv[1],"wb").write(b"\x89PNG\r\n\x1a\n"+struct.pack(">I",13)+b"IHDR"+struct.pack(">IIBBBBB",int(sys.argv[2]),int(sys.argv[2]),8,6,0,0,0)+b"\0"*4)' "$1" "$2"; }
sheet() { printf '{"frames":{"f0":{"frame":{"x":0,"y":0,"w":%s,"h":%s},"duration":100}},"meta":{"image":"%s","size":{"w":32,"h":32}}}' "$2" "$2" "$3" > "$1"; }
TP="$WS/p.jsonl"
EXPORT='aseprite -b hero.aseprite --sheet art/hero.png --data art/hero.json'
check "pixel: PreToolUse prints nothing" silent '' "$P_HOOK" "$(payload PreToolUse Bash "$P" "$TP" p1 "$EXPORT" "")"
png "$P/art/hero.png" 32; sheet "$P/art/hero.json" 64 hero.png
check "pixel: an aseprite export with a frame outside the sheet fires" fire 'reaches outside the 32x32 sheet' "$P_HOOK" "$(payload PostToolUse Bash "$P" "$TP" p1 "$EXPORT" "")"
echo '{"name":"x","version":"1.0.0"}' > "$P/package.json"
check "pixel: a written package.json is silent" silent '' "$P_HOOK" "$(payload PostToolUse Write "$P" "$TP" p2 "" "$P/package.json")"
check "pixel: PreToolUse on cat package.json" silent '' "$P_HOOK" "$(payload PreToolUse Bash "$P" "$TP" p3 'cat package.json' "")"
check "pixel: a bracketed call that changed no sheet is silent" silent '' "$P_HOOK" "$(payload PostToolUse Bash "$P" "$TP" p3 'cat package.json' "")"
printf '{"height":2,"width":2,"infinite":false,"layers":[{"data":[1,2,3],"height":2,"width":2,"type":"tilelayer","name":"g","opacity":1,"visible":true,"x":0,"y":0,"id":1}],"orientation":"orthogonal","renderorder":"right-down","tileheight":16,"tilewidth":16,"tilesets":[{"firstgid":1,"source":"missing.tsj"}],"type":"map","version":"1.10","nextlayerid":2,"nextobjectid":1}' > "$P/maps/l1.tmj"
check "pixel: a written .tmj with a missing tileset fires" fire "external tileset 'missing.tsj' not found" "$P_HOOK" "$(payload PostToolUse Write "$P" "$TP" p4 "" "$P/maps/l1.tmj")"
png "$P/art/slime.png" 16; sheet "$P/art/slime.json" 16 slime.png
check "pixel: a .png beside a sheet that no longer matches it fires" fire 'slime' "$P_HOOK" "$(payload PostToolUse Write "$P" "$TP" p5 "" "$P/art/slime.png")"
check "pixel: PostToolUse with no PreToolUse marker is silent" silent '' "$P_HOOK" "$(payload PostToolUse Bash "$P" "$TP" p6 "$EXPORT" "")"
check "pixel: CC_PIXEL_CHECK=off is silent" silent '' "$P_HOOK" "$(payload PostToolUse Write "$P" "$WS/p-off.jsonl" p7 "" "$P/maps/l1.tmj")" CC_PIXEL_CHECK=off

echo "game-checker-hooks: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
