#!/usr/bin/env bash
# Author-time tests for hooks/route.sh — the PostToolUse file router — and for the
# state-root contract it shares with route-prompt.sh (flush) and summary.sh (ledger).
#
# Drives the hooks with host-shaped payloads (tool_name, session_id, transcript_path,
# cwd, tool_input) against temp GIT repos, because both halves of 0.20.0 depend on one:
# a Bash write routes only under the project root, and the project root is the git
# toplevel (rationale/2026-09-25-session-plugin-usage-review.md, findings 1 and 2).
# Every Bash case RUNS its command first, in the payload cwd — PostToolUse fires after
# the tool, and the hook reads the file the command left on disk.
#
# Asserts: a heredoc write routes the same skills an Edit of that file does, and its
# content signal reaches pending_low; a Bash call with no write target, with a target
# that is missing afterwards, or with a target outside the root is silent and creates
# no state; a payload cwd in a subdirectory keeps state at the repo root, leaves no
# `.claude/` in the subdirectory, and still matches `**/app/**` and reads the root's
# manifest; directory globs match the ROOT-relative path; the per-signal one-shot holds
# across an Edit then a Bash write; one envelope per call; the 8-target cap; CC_REMIND.
set -u
# This session exports it, pointing at the marketplace repo; cc_state_root honours it
# outside git, so a stray value would make a fixture look like part of this repo.
unset CLAUDE_PROJECT_DIR
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SR="$ROOT/plugins/skill-router"
HOOK="$SR/hooks/route.sh"
command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not available (hook fails open without it)"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not available (the state root is the git toplevel)"; exit 0; }
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK"; exit 1; }

pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
NONZERO="$WS/nonzero"
ok()  { pass=$((pass+1)); }
bad() { echo "FAIL $1"; fail=$((fail+1)); }

mkrepo() { # $1 dir — a Laravel-shaped git repo
  mkdir -p "$1/app/Http/Controllers" "$1/app/Enums" "$1/app/Models"
  git -C "$1" init -q
  printf '{"require":{"laravel/framework":"^11.0"}}\n' > "$1/composer.json"
}
hook() { # $1 hook path, stdin payload, [env...] after — records a non-zero exit
  local h="$1"; shift
  env CLAUDE_PLUGIN_ROOT="$SR" "$@" bash "$h" 2>/dev/null
  local rc=$?; [ "$rc" -eq 0 ] || echo "$h rc=$rc" >> "$NONZERO"
}
edit() { # cwd file transcript [env...]
  local c="$1" f="$2" t="$3"; shift 3
  jq -cn --arg c "$c" --arg f "$f" --arg tp "$t" \
    '{hook_event_name:"PostToolUse",tool_name:"Edit",session_id:"sess",transcript_path:$tp,cwd:$c,
      tool_input:{file_path:$f,old_string:"a",new_string:"b"},tool_response:{filePath:$f,success:true}}' \
    | hook "$HOOK" "$@"
}
bashw() { # cwd command transcript [env...] — runs the command, then the hook
  local c="$1" cmd="$2" t="$3"; shift 3
  (cd "$c" && bash -c "$cmd") >/dev/null 2>&1
  jq -cn --arg c "$c" --arg cmd "$cmd" --arg tp "$t" \
    '{hook_event_name:"PostToolUse",tool_name:"Bash",session_id:"sess",transcript_path:$tp,cwd:$c,
      tool_input:{command:$cmd,description:"write"},tool_response:{stdout:"",stderr:"",interrupted:false}}' \
    | hook "$HOOK" "$@"
}
skills()  { jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null | grep -oE 'load the `[^`]+`' | sed 's/^load the `//; s/`$//' | sort -u; }
ctxof()   { printf '%s' "$1" | cksum | cut -d' ' -f1; }
statef()  { printf '%s/.claude/skill-router/fired-%s.json' "$1" "$(ctxof "$2")"; }
has_skill() { skills <<<"$1" | grep -qxF "$2"; }

CTRL='app/Http/Controllers/UserController.php'
HEREDOC="cat > $CTRL <<'PHP'
<?php
namespace App\\Http\\Controllers;
class UserController {
    public function show() { return \$this->user->token; }   // '->' and '=>' must not read as redirects
    private array \$map = ['a' => 1];
}
PHP"

# 1. a Bash heredoc routes exactly what an Edit of the same file routes
A="$WS/a"; mkrepo "$A"
out_b=$(bashw "$A" "$HEREDOC" "$WS/t-a-bash.jsonl")
[ -f "$A/$CTRL" ] || bad "fixture: heredoc did not create $CTRL"
out_e=$(edit "$A" "$A/$CTRL" "$WS/t-a-edit.jsonl")
has_skill "$out_b" laravel-best-practices && ok || bad "bash heredoc: laravel-best-practices not routed; got: ${out_b:0:200}"
sb=$(skills <<<"$out_b"); se=$(skills <<<"$out_e")
[ -n "$se" ] && [ "$sb" = "$se" ] && ok || bad "bash vs edit: skill sets differ — bash [$(echo $sb)] edit [$(echo $se)]"
[ "$(printf '%s\n' "$out_b" | grep -c .)" = 1 ] && printf '%s' "$out_b" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null 2>&1 \
  && ok || bad "bash heredoc: not exactly one PostToolUse envelope: ${out_b:0:200}"
sf=$(statef "$A" "$WS/t-a-bash.jsonl")
jq -e --arg f "$A/$CTRL" '.pending_low | any(.skill == "security-review" and .file == $f)' "$sf" >/dev/null 2>&1 \
  && ok || bad "bash heredoc: content signal (token → security-review) not in pending_low of $sf"

# 2. Bash with no write target → silent, no state
B="$WS/b"; mkrepo "$B"
for cmd in 'git status' 'ls app > /dev/null 2>&1' 'echo hi 2>&1' 'grep -rn foo app | head -3'; do
  out=$(bashw "$B" "$cmd" "$WS/t-b.jsonl")
  [ -z "$out" ] && ok || bad "no target [$cmd]: expected silence, got: ${out:0:120}"
done
[ ! -e "$B/.claude" ] && ok || bad "no target: state dir created at $B/.claude"

# 3. a target missing afterwards, or outside the root → silent, no state
for cmd in 'echo x > app/Gone.php && rm app/Gone.php' \
           'echo x > nodir/deep/x.php' \
           "echo '<?php' > ../outside-rel.php" \
           "echo '<?php' > $WS/outside-abs.php"; do
  out=$(bashw "$B" "$cmd" "$WS/t-b.jsonl")
  [ -z "$out" ] && ok || bad "missing/outside [$cmd]: expected silence, got: ${out:0:120}"
done
[ -f "$WS/outside-rel.php" ] && [ -f "$WS/outside-abs.php" ] && ok || bad "fixture: outside-root files were not written, so the outside cases proved nothing"
[ ! -e "$B/.claude" ] && ok || bad "missing/outside: state dir created at $B/.claude"

# 4. payload cwd = a subdirectory: state at the repo root, nothing in the subdirectory,
#    `**/app/**` still matches a relative target, and the `?package.json` marker is read
#    at the ROOT (read under app/Enums it would be absent and suppress nextjs).
C="$WS/c"; mkrepo "$C"; printf '{"dependencies":{"next":"15.0.0"}}\n' > "$C/package.json"
TC="$WS/t-c.jsonl"
out=$(bashw "$C/app/Enums" "cat > Status.php <<'PHP'
<?php
enum Status: string { case Active = 'active'; }  // password reset flow
PHP" "$TC")
[ -f "$C/app/Enums/Status.php" ] || bad "fixture: subdir heredoc did not create Status.php"
has_skill "$out" laravel-best-practices && ok || bad "subdir: laravel-best-practices not routed; got: ${out:0:200}"
has_skill "$out" nextjs-best-practices && ok || bad "subdir: **/app/** + root package.json did not route nextjs-best-practices; got: ${out:0:200}"
[ -f "$(statef "$C" "$TC")" ] && ok || bad "subdir: no state file at the repo root"
[ ! -e "$C/app/Enums/.claude" ] && ok || bad "subdir: stray .claude/ created in app/Enums"
mkdir -p "$C/database/migrations"; : > "$C/database/migrations/2026_01_01_create_orders.php"
out=$(edit "$C/app/Models" "$C/database/migrations/2026_01_01_create_orders.php" "$TC")
has_skill "$out" sql-best-practices && ok || bad "subdir edit: sql-best-practices not routed; got: ${out:0:200}"
[ ! -e "$C/app/Models/.claude" ] && ok || bad "subdir edit: stray .claude/ created in app/Models"
jq -e '(.fired | index("laravel-best-practices")) and (.fired | index("sql-best-practices"))' "$(statef "$C" "$TC")" >/dev/null 2>&1 \
  && ok || bad "subdir: one context from two directories did not land in ONE root state file"

# 4b. the three-hook contract survives the drift: route-prompt flushes, from yet another
#     directory, what route.sh wrote from app/Enums; summary.sh finds and removes it and
#     files the ledger under the ROOT's slug.
fl=$(jq -cn --arg c "$C/app/Http" --arg tp "$TC" '{hook_event_name:"UserPromptSubmit",prompt:"ok thanks",session_id:"sess",transcript_path:$tp,cwd:$c}' \
  | hook "$SR/hooks/route-prompt.sh" TMPDIR="$WS")
grep -qF 'Signals from recent edits' <<<"$fl" && grep -qF 'Status.php' <<<"$fl" && ok \
  || bad "flush from another subdir: digest missing; got: ${fl:0:200}"
jq -cn --arg c "$C/app/Enums" --arg tp "$TC" '{hook_event_name:"SessionEnd",session_id:"sess",transcript_path:$tp,cwd:$c}' \
  | hook "$SR/hooks/summary.sh" HOME="$WS/home" >/dev/null
[ ! -e "$(statef "$C" "$TC")" ] && ok || bad "summary from subdir: root state file not removed"
slug=$(printf '%s' "$C" | tr -c '[:alnum:]' '-')
[ -s "$WS/home/.claude/skill-router/$slug/surfaced.jsonl" ] && [ "$(ls "$WS/home/.claude/skill-router" | wc -l | tr -d ' ')" = 1 ] \
  && ok || bad "summary from subdir: ledger not filed under the root slug alone: $(ls "$WS/home/.claude/skill-router" 2>/dev/null)"

# 4c. directory globs match the ROOT-relative path: a checkout that merely lives under a
#     directory named `tests/` must not draw the testing row on every file it edits.
D="$WS/tests/d"; mkdir -p "$D/src"; git -C "$D" init -q; printf 'package d\n' > "$D/src/thing.go"
out=$(edit "$D" "$D/src/thing.go" "$WS/t-d.jsonl")
has_skill "$out" low-cognitive-load && ok || bad "root-relative: *.go did not route at all; got: ${out:0:200}"
has_skill "$out" testing-best-practices && bad "root-relative: **/tests/** matched a directory ABOVE the repo root" || ok

# 5. the one-shot holds across an Edit then a Bash write of the same signal
E="$WS/e"; mkrepo "$E"; TE="$WS/t-e.jsonl"
printf '<?php\n' > "$E/$CTRL"
out=$(edit "$E" "$E/$CTRL" "$TE")
has_skill "$out" laravel-best-practices && ok || bad "one-shot: the Edit did not route laravel; got: ${out:0:200}"
out=$(bashw "$E" "cat > app/Http/Controllers/PostController.php <<'PHP'
<?php
PHP" "$TE")
has_skill "$out" laravel-best-practices && bad "one-shot: the Bash write re-nudged laravel-best-practices" || ok
out=$(bashw "$E" "printf 'select 1;\\n' > app/report.sql" "$TE")
has_skill "$out" sql-best-practices && ok || bad "one-shot: a NEW signal through Bash in the same context did not route; got: ${out:0:200}"

# 6. one command, three files → ONE envelope carrying every skill
F="$WS/f"; mkrepo "$F"
out=$(bashw "$F" "cat > app/Models/Order.php <<'A'
<?php
A
printf 'select 1;\\n' > app/orders.sql; echo 'package f' > app/f.go" "$WS/t-f.jsonl")
[ "$(printf '%s\n' "$out" | grep -c .)" = 1 ] && ok || bad "multi-file: expected one envelope line, got $(printf '%s\n' "$out" | grep -c .)"
for s in laravel-best-practices sql-best-practices low-cognitive-load; do
  has_skill "$out" "$s" && ok || bad "multi-file: $s missing from the envelope"
done

# 7. the cap: the first 8 targets are examined, a 9th is not
G="$WS/g"; mkrepo "$G"
seven='echo a > t1.txt; echo a > t2.txt; echo a > t3.txt; echo a > t4.txt; echo a > t5.txt; echo a > t6.txt; echo a > t7.txt'
out=$(bashw "$G" "$seven; printf 'select 1;\\n' > eighth.sql" "$WS/t-g8.jsonl")
has_skill "$out" sql-best-practices && ok || bad "cap: the 8th target did not route; got: ${out:0:160}"
out=$(bashw "$G" "$seven; echo a > t8.txt; printf 'select 1;\\n' > ninth.sql" "$WS/t-g9.jsonl")
[ -z "$out" ] && ok || bad "cap: a 9th target routed: ${out:0:160}"

# 8. CC_REMIND=off silences the Bash path too
H="$WS/h"; mkrepo "$H"
out=$(bashw "$H" "printf 'select 1;\\n' > q.sql" "$WS/t-h.jsonl" CC_REMIND=off)
[ -z "$out" ] && [ ! -e "$H/.claude" ] && ok || bad "CC_REMIND=off: Bash write still routed: ${out:0:120}"

# ---- routing review 2026-09-26: content+high inline, wrong-route fixes, new rows, and the
#      Bash `command` signal. Every case uses its own transcript unless it tests the
#      one-shot, so a skill fired by an earlier case cannot mask a later one.
bashc() { # cwd command transcript [env...] — the hook only; the command is NOT run
  local c="$1" cmd="$2" t="$3"; shift 3
  jq -cn --arg c "$c" --arg cmd "$cmd" --arg tp "$t" \
    '{hook_event_name:"PostToolUse",tool_name:"Bash",session_id:"sess",transcript_path:$tp,cwd:$c,
      tool_input:{command:$cmd,description:"run"},tool_response:{stdout:"",stderr:"",interrupted:false}}' \
    | hook "$HOOK" "$@"
}
pend() { jq -e --arg s "$2" '.pending_low | any(.skill == $s)' "$1" >/dev/null 2>&1; }
mkui() { # $1 dir, $2 package.json body — a front-end git repo
  mkdir -p "$1/src/pages/Deals"; git -C "$1" init -q; printf '%s\n' "$2" > "$1/package.json"
}
fresh() { mktemp "$WS/t-XXXXXX"; }   # a unique transcript path; `$(…)` is a subshell, so no counter
routes() { # dir relpath content skill [not-skill] — write the file, Edit it in a fresh context
  local d="$1" f="$2" body="$3" want="$4" avoid="${5:-}" o
  mkdir -p "$(dirname "$d/$f")"; printf '%s\n' "$body" > "$d/$f"
  o=$(edit "$d" "$d/$f" "$(fresh)")
  has_skill "$o" "$want" && ok || bad "$f: $want not routed inline; got: ${o:0:200}"
  if [ -n "$avoid" ]; then has_skill "$o" "$avoid" && bad "$f: $avoid routed (wrong route)" || ok; fi
}

# 10. a content row marked `high` fires INLINE, once per context, and never enters the digest
U="$WS/u"; mkui "$U" '{"dependencies":{"react":"19.0.0","@mui/material":"7.0.0","@mui/x-data-grid":"8.0.0"}}'
TU="$WS/t-u.jsonl"; mkdir -p "$U/src/features/orders"
printf '%s\n' "import { DataGrid } from '@mui/x-data-grid'" \
  'export function OrdersGrid() { return <span className="total">{rows.length}</span> }' > "$U/src/features/orders/OrdersGrid.tsx"
out=$(edit "$U" "$U/src/features/orders/OrdersGrid.tsx" "$TU")
has_skill "$out" mui-best-practices && ok || bad "content+high: mui-best-practices not inline on first import; got: ${out:0:200}"
[ "$(printf '%s\n' "$out" | grep -c .)" = 1 ] && ok || bad "content+high: expected one envelope line"
grep -qF 'This edit touches OrdersGrid.tsx' <<<"$out" && ok || bad "content+high: file-row subject text changed: ${out:0:200}"
sf=$(statef "$U" "$TU")
jq -e '.fired | index("mui-best-practices")' "$sf" >/dev/null 2>&1 && ok || bad "content+high: mui-best-practices not recorded in fired"
pend "$sf" mui-best-practices && bad "content+high: mui-best-practices also landed in pending_low" || ok
pend "$sf" observability-design && bad "observability: a JSX <span> still draws observability-design" || ok
printf '%s\n' "import Button from '@mui/material/Button'" 'const token = session.token' > "$U/src/features/orders/OrderRow.tsx"
out=$(edit "$U" "$U/src/features/orders/OrderRow.tsx" "$TU")
has_skill "$out" mui-best-practices && bad "content+high: re-nudged mui-best-practices in the same context" || ok
pend "$sf" mui-best-practices && bad "content+high: second file put mui-best-practices in pending_low" || ok
pend "$sf" security-review && ok || bad "content+low: security-review (token) did not reach pending_low next to a high row"
has_skill "$out" security-review && bad "content+low: security-review fired inline" || ok
out=$(edit "$U" "$U/src/features/orders/OrderRow.tsx" "$WS/t-u-subagent.jsonl")
has_skill "$out" mui-best-practices && ok || bad "content+high: a second context (subagent transcript) did not get it inline"
fl=$(jq -cn --arg c "$U" --arg tp "$TU" '{hook_event_name:"UserPromptSubmit",prompt:"ok",session_id:"sess",transcript_path:$tp,cwd:$c}' \
  | hook "$SR/hooks/route-prompt.sh" TMPDIR="$WS")
grep -qF 'security-review' <<<"$fl" && ok || bad "digest: the low row did not flush; got: ${fl:0:200}"
grep -qF 'mui-best-practices' <<<"$fl" && bad "digest: a high content row was flushed in the digest" || ok
out=$(bashw "$U" "cat > src/pages/Scene.tsx <<'TSX'
import { Canvas } from '@react-three/fiber'
export const Scene = () => <Canvas />
TSX" "$(fresh)")
has_skill "$out" threejs-best-practices && ok || bad "content+high via Bash heredoc: threejs-best-practices not inline; got: ${out:0:200}"

# 11. wrong routes fixed: R3F → threejs, Lenis → scroll-orchestration, Motion ↛ aceternity,
#     observability on span API calls
M="$WS/m"; mkui "$M" '{"dependencies":{"react":"19.0.0"}}'
routes "$M" src/scene/Product.tsx "import { Canvas } from '@react-three/fiber'
import { OrbitControls } from '@react-three/drei'" threejs-best-practices motion-best-practices
routes "$M" src/scene/globe.ts "import * as THREE from 'three'" threejs-best-practices
routes "$M" src/scroll/Smooth.tsx "import { ReactLenis } from 'lenis/react'" scroll-orchestration motion-best-practices
routes "$M" src/scroll/Pinned.tsx "import { ScrollTrigger } from 'gsap/ScrollTrigger'
ScrollTrigger.create({ pin: true, scrub: 1 })" scroll-orchestration
routes "$M" src/hero/Hero.tsx "import { motion } from 'motion/react'" motion-best-practices
TM=$(fresh); printf '%s\n' "import { motion } from 'motion/react'" > "$M/src/hero/Hero2.tsx"; edit "$M" "$M/src/hero/Hero2.tsx" "$TM" >/dev/null
pend "$(statef "$M" "$TM")" aceternity-best-practices && bad "aceternity: a Motion import still draws aceternity-best-practices" || ok
TM=$(fresh); mkdir -p "$M/src/lib"; printf '%s\n' "const span = tracer.startSpan('checkout')" 'span.end()' > "$M/src/lib/trace.ts"; edit "$M" "$M/src/lib/trace.ts" "$TM" >/dev/null
pend "$(statef "$M" "$TM")" observability-design && ok || bad "observability: startSpan/span.end() no longer reach the digest"

# 12. skills that existed but were never reached
routes "$M" src/mascot/Mascot.tsx "import { useRive } from '@rive-app/react-canvas'" motion-tiers
routes "$M" src/mascot/Loader.tsx "import { DotLottieReact } from '@lottiefiles/dotlottie-react'" motion-tiers
routes "$M" src/charts/Pipeline.tsx "import { BarChart, Bar } from 'recharts'" information-design
routes "$M" src/grid/Orders.tsx "import { AgGridReact } from 'ag-grid-react'" information-design
routes "$M" src/grid/Table.tsx "import { useReactTable } from '@tanstack/react-table'" information-design
routes "$M" src/index.css '@import "tailwindcss";
@theme { --color-brand: oklch(0.6 0.2 250); }' tailwind-best-practices
routes "$M" resources/css/app.css '@import "tailwindcss";
@source "../views";' tailwind-best-practices
TM=$(fresh); printf '.card { color: red; }\n' > "$M/src/plain.css"; out=$(edit "$M" "$M/src/plain.css" "$TM")
has_skill "$out" tailwind-best-practices && bad "tailwind v4 row: a plain stylesheet drew tailwind-best-practices" || ok
TM=$(fresh); printf '%s\n' '// uses @theme tokens from index.css' 'export const x = 1' > "$M/src/tokens.ts"; out=$(edit "$M" "$M/src/tokens.ts" "$TM")
has_skill "$out" tailwind-best-practices && bad "tailwind v4 row: fired outside a .css file" || ok
routes "$M" components.json '{"style":"new-york","registries":{"@magicui":"https://magicui.design/r/{name}.json"}}' shadcn-best-practices
routes "$M" src/pages/Claims.tsx "import { DataTable } from 'primereact/datatable'" primereact-best-practices component-libraries
routes "$M" src/pages/Customers.tsx "import { Select } from '@primereact/ui/select'" primereact-best-practices component-libraries
# `@primeuix/` routes PrimeReact only when package.json names it: PrimeVue imports the same presets.
P="$WS/p"; mkui "$P" '{"dependencies":{"react":"19.1.0","@primereact/ui":"11.1.0","@primeuix/themes":"3.0.1"}}'
routes "$P" src/main.tsx "import Aura from '@primeuix/themes/aura'" primereact-best-practices
PV="$WS/pv"; mkui "$PV" '{"dependencies":{"vue":"3.5.0","primevue":"5.0.1","@primeuix/themes":"3.0.1"}}'
TM=$(fresh); printf '%s\n' "import Aura from '@primeuix/themes/aura'" > "$PV/src/main.ts"; out=$(edit "$PV" "$PV/src/main.ts" "$TM")
has_skill "$out" primereact-best-practices && bad "primereact @primeuix row: fired in a PrimeVue repo" || ok
routes "$M" src/ui/Select.tsx "import { Select } from '@base-ui-components/react/select'" component-libraries
routes "$M" src/ui/Menu.tsx "import { Menu, MenuItem } from 'react-aria-components'" component-libraries
V="$WS/v"; mkui "$V" '{"dependencies":{"vue":"3.5.0","vuetify":"3.7.0"}}'
routes "$V" src/pages/Tickets.vue '<template><v-data-table :items="tickets" /></template>' component-libraries
V2="$WS/v2"; mkui "$V2" '{"dependencies":{"vue":"3.5.0"}}'
TM=$(fresh); printf '<template><div /></template>\n' > "$V2/src/pages/Plain.vue"; out=$(edit "$V2" "$V2/src/pages/Plain.vue" "$TM")
has_skill "$out" component-libraries && bad "vue manifest row: fired in a repo whose package.json names no kit" || ok
has_skill "$out" a11y-audit && ok || bad "vue manifest row: the co-firing a11y-audit row stopped firing on *.vue"

# 13. interaction libraries route by IMPORT, outside any dashboard/ or admin/ path
for imp in "@dnd-kit/core" "@fullcalendar/react" "@schedule-x/react" "react-big-calendar" "maplibre-gl" \
           "leaflet" "mapbox-gl" "@xyflow/react" "@tiptap/react" "lexical" "@lexical/react/LexicalComposer" \
           "@tanstack/react-virtual"; do
  routes "$M" src/pages/Deals/Board.tsx "import X from '$imp'" information-design
done

# 14. the Bash `command` signal: a registry install routes shadcn, once per context
S="$WS/s"; mkui "$S" '{"dependencies":{"react":"19.0.0"}}'; TS="$WS/t-s.jsonl"
out=$(bashc "$S" 'npx shadcn@latest add @magicui/marquee' "$TS")
has_skill "$out" shadcn-best-practices && ok || bad "command row: shadcn add did not route shadcn-best-practices; got: ${out:0:200}"
[ "$(printf '%s\n' "$out" | grep -c .)" = 1 ] && printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null 2>&1 \
  && ok || bad "command row: not exactly one PostToolUse envelope: ${out:0:200}"
grep -qF 'This command runs `shadcn@latest add`' <<<"$out" && ok || bad "command row: subject does not quote the matched command: ${out:0:200}"
jq -e '.fired | index("shadcn-best-practices")' "$(statef "$S" "$TS")" >/dev/null 2>&1 && ok || bad "command row: not recorded in fired"
out=$(bashc "$S" 'pnpm dlx shadcn@latest add button' "$TS")
[ -z "$out" ] && ok || bad "command row: re-nudged in the same context: ${out:0:160}"
for cmd in 'cd web && bunx --bun shadcn@latest add dialog' 'npx shadcn-ui@latest add card' 'npx shadcn add table'; do
  out=$(bashc "$S" "$cmd" "$(fresh)")
  has_skill "$out" shadcn-best-practices && ok || bad "command row [$cmd]: did not route; got: ${out:0:160}"
done
S2="$WS/s2"; mkui "$S2" '{}'
for cmd in 'npm view shadcn version' 'npx shadcn@latest init' 'echo add shadcn later'; do
  out=$(bashc "$S2" "$cmd" "$(fresh)")
  [ -z "$out" ] && ok || bad "command row [$cmd]: expected silence, got: ${out:0:160}"
done
[ ! -e "$S2/.claude" ] && ok || bad "command row: a non-matching command created state at $S2/.claude"
out=$(bashc "$S2" 'npx shadcn@latest add button' "$(fresh)" CC_REMIND=off)
[ -z "$out" ] && [ ! -e "$S2/.claude" ] && ok || bad "CC_REMIND=off: the command row still routed: ${out:0:120}"
printf 'npx shadcn@latest add button\n' > "$S2/NOTES.txt"
out=$(edit "$S2" "$S2/NOTES.txt" "$(fresh)")
has_skill "$out" shadcn-best-practices && bad "command row: matched a FILE's contents on an Edit" || ok

# 14b. command rows match the command with quoted strings and heredoc bodies masked: a
#      commit message, a grep pattern or a doc heredoc that MENTIONS the install neither
#      routes nor spends the one-shot, and a quoted install argument still routes.
S3="$WS/s3"; mkui "$S3" '{}'; TS3="$WS/t-s3.jsonl"
for cmd in 'git commit -m "document the shadcn add flow"' 'grep -rn "shadcn add" docs/' \
           'echo "run shadcn add now"' "echo 'npx shadcn@latest add button'" \
           "cat > docs/setup.md <<'MD'
Run npx shadcn@latest add button first.
MD" \
           "git commit -m \"\$(cat <<'EOF'
Explain the \"shadcn add\" flow
EOF
)\""; do
  out=$(bashc "$S3" "$cmd" "$TS3")
  [ -z "$out" ] && ok || bad "command row: quoted or heredoc text routed [${cmd%%$'\n'*}]: ${out:0:160}"
done
[ ! -e "$S3/.claude" ] && ok || bad "command row: a mention spent the one-shot (state created at $S3/.claude)"
out=$(bashc "$S3" 'npx shadcn@latest add "@magicui/marquee"' "$TS3")
has_skill "$out" shadcn-best-practices && ok || bad "command row: a quoted install argument did not route after the mentions; got: ${out:0:160}"
out=$(bashc "$S3" 'echo "$(npx shadcn@latest add button)"' "$(fresh)")
has_skill "$out" shadcn-best-practices && ok || bad "command row: \$(…) inside double quotes is live code and did not route; got: ${out:0:160}"

# 15. content+high fires inline only on code and style files; any other file keeps its
#     match in the digest and does not spend the one-shot
N="$WS/n"; mkui "$N" '{"dependencies":{"react":"19.0.0"}}'; TN="$WS/t-n.jsonl"
printf 'Hero timeline: port it to gsap next sprint.\n' > "$N/NOTES.md"
out=$(edit "$N" "$N/NOTES.md" "$TN")
has_skill "$out" motion-best-practices && bad "content+high: NOTES.md mentioning gsap fired inline" || ok
pend "$(statef "$N" "$TN")" motion-best-practices && ok || bad "content+high: NOTES.md's match did not fall through to the digest"
mkdir -p "$N/tools"; printf 'SNIPPET = "const r = new THREE.WebGLRenderer()"\n' > "$N/tools/gen.py"
out=$(edit "$N" "$N/tools/gen.py" "$TN")
has_skill "$out" threejs-best-practices && bad "content+high: a .py containing 'new THREE.' fired inline" || ok
printf "import gsap from 'gsap'\n" > "$N/src/pages/Hero.tsx"
out=$(edit "$N" "$N/src/pages/Hero.tsx" "$TN")
has_skill "$out" motion-best-practices && ok || bad "content+high: the one-shot was spent by NOTES.md — Hero.tsx did not fire; got: ${out:0:160}"
mkdir -p "$N/resources/views"; printf '<div x-data>{{ $title }}</div>\n<script>gsap.to(".hero", { y: 0 })</script>\n' > "$N/resources/views/hero.blade.php"
out=$(edit "$N" "$N/resources/views/hero.blade.php" "$(fresh)")
has_skill "$out" motion-best-practices && ok || bad "content+high: a .blade.php template did not fire inline; got: ${out:0:160}"

# 16. each target is read once per call: the digest pass reuses the inline pass's read
HS="$WS/shim"; mkdir -p "$HS"
printf '#!/bin/bash\nprintf "%%s\\n" "$*" >> "$HEAD_LOG"\nexec %s "$@"\n' "$(command -v head)" > "$HS/head"; chmod +x "$HS/head"
printf "import gsap from 'gsap'\nconst token = session.token\n" > "$N/src/pages/Reads.tsx"
edit "$N" "$N/src/pages/Reads.tsx" "$(fresh)" PATH="$HS:$PATH" HEAD_LOG="$WS/head.log" >/dev/null
reads=$(grep -c 'Reads\.tsx' "$WS/head.log" 2>/dev/null)
[ "$reads" = 1 ] && ok || bad "one read per target: Reads.tsx was read ${reads:-0} times in one call"

# 9. every hook call exited 0 (fail-open contract)
[ ! -s "$NONZERO" ] && ok || { bad "non-zero hook exit(s):"; cat "$NONZERO"; }

echo "route: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
