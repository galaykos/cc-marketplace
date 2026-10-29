#!/usr/bin/env bash
# route.test.sh — runs hooks/route.sh, and the route-prompt.sh flush and summary.sh ledger that share its state root, on host-shaped
#   payloads in temp git repos; each numbered case names the behaviour it asserts.
# Why, limits, history: rationale/derivations/plugin-skill-router.md § plugins/skill-router/scripts/__tests__/route.test.sh
set -u
# A live session exports it; cc_state_root takes it as the root of any non-git cwd beneath it.
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
# Bare names, the plugin prefix dropped: case 19 pins the qualified spelling itself.
skills()  { jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null | grep -oE 'Load the `[^`]+`' | sed 's/^Load the `//; s/`$//; s/^[a-z0-9._-]*://' | sort -u; }
ctxof()   { printf '%s' "$1" | cksum | cut -d' ' -f1; }
statef()  { printf '%s/.claude/skill-router/fired-%s.json' "$1" "$(ctxof "$2")"; }
has_skill() { skills <<<"$1" | grep -qxF "$2"; }
# Every call in a git repo leaves the effects marker; nothing else may land, and the state dir must stay invisible to git.
nostate() { ! ls "$1"/.claude/skill-router/fired-*.json >/dev/null 2>&1 && [ -z "$(git -C "$1" status --porcelain --untracked-files=all -- .claude 2>/dev/null)" ]; }

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
nostate "$B" && ok || bad "no target: state written at $B/.claude"

# 3. a target missing afterwards, or outside the root → silent, no state
for cmd in 'echo x > app/Gone.php && rm app/Gone.php' \
           'echo x > nodir/deep/x.php' \
           "echo '<?php' > ../outside-rel.php" \
           "echo '<?php' > $WS/outside-abs.php"; do
  out=$(bashw "$B" "$cmd" "$WS/t-b.jsonl")
  [ -z "$out" ] && ok || bad "missing/outside [$cmd]: expected silence, got: ${out:0:120}"
done
[ -f "$WS/outside-rel.php" ] && [ -f "$WS/outside-abs.php" ] && ok || bad "fixture: outside-root files were not written, so the outside cases proved nothing"
nostate "$B" && ok || bad "missing/outside: state written at $B/.claude"

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
grep -qF 'Your recent edits may need these skills' <<<"$fl" && grep -qF 'Status.php' <<<"$fl" && ok \
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

# 6. one command, three files → ONE envelope of at most two nudges: the file-shape rows (laravel, sql) beat the language-wide
#    low-cognitive-load, which is not spent and rides the next edit of that language
F="$WS/f"; mkrepo "$F"; TF="$WS/t-f.jsonl"
out=$(bashw "$F" "cat > app/Models/Order.php <<'A'
<?php
A
printf 'select 1;\\n' > app/orders.sql; echo 'package f' > app/f.go" "$TF")
[ "$(printf '%s\n' "$out" | grep -c .)" = 1 ] && ok || bad "multi-file: expected one envelope line, got $(printf '%s\n' "$out" | grep -c .)"
[ "$(skills <<<"$out" | grep -c .)" = 2 ] && ok || bad "cap: expected 2 nudges on one call, got [$(echo $(skills <<<"$out"))]"
for s in laravel-best-practices sql-best-practices; do
  has_skill "$out" "$s" && ok || bad "multi-file: $s missing from the envelope"
done
has_skill "$out" low-cognitive-load && bad "cap: the language-wide low-cognitive-load took a slot from a file-shape row" || ok
jq -e '.fired | index("low-cognitive-load") | not' "$(statef "$F" "$TF")" >/dev/null 2>&1 && ok || bad "cap: a skill over the cap was marked fired"
out=$(edit "$F" "$F/app/f.go" "$TF")
has_skill "$out" low-cognitive-load && ok || bad "cap: the skill over the cap did not ride the next edit; got: ${out:0:200}"
last=$(sed -n 's/^# nudge-last:[[:space:]]*//p' "$SR/rules.tsv")
[ -n "$last" ] && ok || bad "cap: rules.tsv carries no '# nudge-last:' line"
for s in $last; do
  awk -F'\t' -v s="$s" '$1 == "glob" && $3 == s {f = 1} END {exit !f}' "$SR/rules.tsv" && ok || bad "cap: nudge-last names $s, which no glob row routes"
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

# Each case from here uses its own transcript unless it tests the one-shot, so an earlier case's fired skill cannot mask it.
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
grep -qF 'skill for OrdersGrid.tsx' <<<"$out" && ok || bad "content+high: file-row subject text changed: ${out:0:200}"
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
TM=$(fresh); printf '%s\n' "import LocomotiveScroll from 'locomotive-scroll'" > "$M/src/scroll/Loco.tsx"; out=$(edit "$M" "$M/src/scroll/Loco.tsx" "$TM")
has_skill "$out" scroll-orchestration && ok || bad "locomotive-scroll import routes scroll-orchestration; got: ${out:0:200}"
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
TM=$(fresh); mkdir -p "$M/src/gov"; printf '%s\n' "import { initAll } from 'govuk-frontend'" 'initAll()' > "$M/src/gov/boot.js"; out=$(edit "$M" "$M/src/gov/boot.js" "$TM")
has_skill "$out" component-libraries && ok || bad "govuk-frontend import routes component-libraries; got: ${out:0:200}"
TM=$(fresh); printf '%s\n' "import { DataTable } from '@carbon/react'" > "$M/src/ui/Grid.tsx"; out=$(edit "$M" "$M/src/ui/Grid.tsx" "$TM")
has_skill "$out" component-libraries && ok || bad "carbon import routes component-libraries; got: ${out:0:200}"
TM=$(fresh); printf '%s\n' "import Button from '@atlaskit/button/new'" > "$M/src/ui/Action.tsx"; out=$(edit "$M" "$M/src/ui/Action.tsx" "$TM")
has_skill "$out" component-libraries && ok || bad "atlaskit import routes component-libraries; got: ${out:0:200}"
for imp in "@uswds/uswds" "uswds" "@shopify/polaris" "@shopify/polaris-types" "@atlaskit/primitives" "@atlaskit/page-header"; do
  routes "$M" "src/org/${imp//[^a-z]/}.tsx" "import '$imp'" component-libraries
done
TM=$(fresh); printf '%s\n' "import { draggable } from '@atlaskit/pragmatic-drag-and-drop/element/adapter'" \
  "import { attachClosestEdge } from '@atlaskit/pragmatic-drag-and-drop-hitbox/closest-edge'" > "$M/src/ui/Board.tsx"; out=$(edit "$M" "$M/src/ui/Board.tsx" "$TM")
has_skill "$out" component-libraries && bad "pragmatic-drag-and-drop does not route component-libraries; got: ${out:0:200}" || ok
TM=$(fresh); printf '%s\n' '// Spacing follows the GOV.UK Design System (`govuk-frontend`), not USWDS.' 'export const gap = 4' > "$M/src/ui/spacing.ts"; out=$(edit "$M" "$M/src/ui/spacing.ts" "$TM")
has_skill "$out" component-libraries && bad "govuk text in prose does not route: a backticked name in a comment drew component-libraries" || ok
TM=$(fresh); mkdir -p "$M/docs"; printf '%s\n' '# Forms' 'We compared `govuk-frontend`, `@carbon/react` and USWDS before building our own.' > "$M/docs/forms.md"; edit "$M" "$M/docs/forms.md" "$TM" >/dev/null
pend "$(statef "$M" "$TM")" component-libraries && bad "govuk text in prose does not route: a backticked name in markdown queued component-libraries" || ok
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
has_skill "$out" aceternity-best-practices && ok || bad "magicui install routes aceternity-best-practices; got: ${out:0:200}"
[ "$(printf '%s\n' "$out" | grep -c .)" = 1 ] && printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null 2>&1 \
  && ok || bad "command row: not exactly one PostToolUse envelope: ${out:0:200}"
grep -qF 'skill for `shadcn@latest add`' <<<"$out" && ok || bad "command row: subject does not quote the matched command: ${out:0:200}"
jq -e '.fired | index("shadcn-best-practices")' "$(statef "$S" "$TS")" >/dev/null 2>&1 && ok || bad "command row: not recorded in fired"
out=$(bashc "$S" 'pnpm dlx shadcn@latest add button' "$TS")
[ -z "$out" ] && ok || bad "command row: re-nudged in the same context: ${out:0:160}"
for cmd in 'cd web && bunx --bun shadcn@latest add dialog' 'npx shadcn-ui@latest add card' 'npx shadcn add table'; do
  out=$(bashc "$S" "$cmd" "$(fresh)")
  has_skill "$out" shadcn-best-practices && ok || bad "command row [$cmd]: did not route; got: ${out:0:160}"
done
for cmd in 'npx shadcn@latest add @react-bits/BlurText-TS-TW' 'npx jsrepo@latest add https://reactbits.dev/r/BlurText-TS-TW'; do
  out=$(bashc "$S" "$cmd" "$(fresh)")
  has_skill "$out" aceternity-best-practices && ok || bad "react-bits install routes aceternity-best-practices [$cmd]; got: ${out:0:160}"
done
out=$(bashc "$S" 'pnpm dlx jsrepo@latest add github/ieedan/std/utils/math' "$(fresh)")
has_skill "$out" shadcn-best-practices && ok || bad "jsrepo add routes shadcn-best-practices; got: ${out:0:160}"
has_skill "$out" aceternity-best-practices && bad "jsrepo add of a non-effect registry routed aceternity-best-practices" || ok
S2="$WS/s2"; mkui "$S2" '{}'
for cmd in 'npm view shadcn version' 'npx shadcn@latest init' 'npx jsrepo@latest init' 'echo add shadcn later'; do
  out=$(bashc "$S2" "$cmd" "$(fresh)")
  [ -z "$out" ] && ok || bad "command row [$cmd]: expected silence, got: ${out:0:160}"
done
nostate "$S2" && ok || bad "command row: a non-matching command wrote state at $S2/.claude"
out=$(bashc "$S2" 'npx shadcn@latest add button' "$(fresh)" CC_REMIND=off)
[ -z "$out" ] && nostate "$S2" && ok || bad "CC_REMIND=off: the command row still routed: ${out:0:120}"
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
nostate "$S3" && ok || bad "command row: a mention spent the one-shot (state written at $S3/.claude)"
out=$(bashc "$S3" 'npx shadcn@latest add "@magicui/marquee"' "$TS3")
has_skill "$out" shadcn-best-practices && ok || bad "command row: a quoted install argument did not route after the mentions; got: ${out:0:160}"
has_skill "$out" aceternity-best-practices && bad "quoted magicui install is a stated miss, yet aceternity-best-practices routed" || ok
out=$(bashc "$S3" 'echo "$(npx shadcn@latest add button)"' "$(fresh)")
has_skill "$out" shadcn-best-practices && ok || bad "command row: \$(…) inside double quotes is live code and did not route; got: ${out:0:160}"

# 15. content+high fires inline only on code and style files; any other file keeps its
#     match in the digest (a doc file queues nothing, case 18) and does not spend the one-shot
N="$WS/n"; mkui "$N" '{"dependencies":{"react":"19.0.0"}}'; TN="$WS/t-n.jsonl"
printf 'Hero timeline: port it to gsap next sprint.\n' > "$N/NOTES.md"
out=$(edit "$N" "$N/NOTES.md" "$TN")
has_skill "$out" motion-best-practices && bad "content+high: NOTES.md mentioning gsap fired inline" || ok
mkdir -p "$N/tools"; printf 'SNIPPET = "const r = new THREE.WebGLRenderer()"\n' > "$N/tools/gen.py"
out=$(edit "$N" "$N/tools/gen.py" "$TN")
has_skill "$out" threejs-best-practices && bad "content+high: a .py containing 'new THREE.' fired inline" || ok
pend "$(statef "$N" "$TN")" threejs-best-practices && ok || bad "content+high: gen.py's match did not fall through to the digest"
pend "$(statef "$N" "$TN")" motion-best-practices && bad "doc file: NOTES.md's gsap match reached the digest" || ok
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

# 17. low-cognitive-load on .php/.tsx/.jsx/.vue; a negative also asserts a skill that proves the edit routed
K="$WS/k"; mkrepo "$K"
routes "$K" app/Models/Invoice.php '<?php class Invoice {}' low-cognitive-load
routes "$K" resources/js/Card.tsx 'export const Card = () => <div />' low-cognitive-load
routes "$K" resources/js/Row.jsx 'export const Row = () => <tr />' low-cognitive-load
routes "$K" resources/js/Panel.vue '<template><section /></template>' low-cognitive-load
routes "$K" resources/js/.scratch.tsx 'export const x = <div />' a11y-audit low-cognitive-load
routes "$K" resources/views/invoice.blade.php '<div>{{ $total }}</div>' laravel-best-practices low-cognitive-load
routes "$K" resources/js/.scratch.jsx 'export const y = <div />' a11y-audit low-cognitive-load
routes "$K" resources/js/.scratch.vue '<template><i /></template>' a11y-audit low-cognitive-load
routes "$K" .php-cs-fixer.php '<?php return [];' laravel-best-practices low-cognitive-load
routes "$K" config/app.php '<?php return [];' low-cognitive-load

# 18. doc and style files queue nothing; a harness frame does not flush the digest, a human prompt does
D="$WS/d"; mkrepo "$D"; TD="$WS/t-d.jsonl"
mkdir -p "$D/docs" "$D/resources/css" "$D/taskmaster-docs/mockups"
printf 'Rotate the api token before the release.\n' > "$D/docs/runbook.md"
printf '.badge { color: var(--token-fg); }\n' > "$D/resources/css/badge.css"
printf '<form><input type="password" name="password"></form>\n' > "$D/taskmaster-docs/mockups/login.html"
printf 'Rotate the secret quarterly.\n' > "$D/docs/notes.txt"
for f in docs/runbook.md resources/css/badge.css taskmaster-docs/mockups/login.html docs/notes.txt; do
  edit "$D" "$D/$f" "$TD" >/dev/null
  pend "$(statef "$D" "$TD")" security-review && bad "doc/style file: $f queued security-review" || ok
done
printf '<?php\nclass ApiTokenController { public function show() { return $this->token; } }\n' > "$D/app/Http/Controllers/ApiTokenController.php"
edit "$D" "$D/app/Http/Controllers/ApiTokenController.php" "$TD" >/dev/null
pend "$(statef "$D" "$TD")" security-review && ok || bad "code file: a .php edit with token no longer queues security-review"
prompt_d() { # prompt transcript
  jq -cn --arg c "$D" --arg tp "$2" --arg p "$1" '{hook_event_name:"UserPromptSubmit",prompt:$p,session_id:"sess",transcript_path:$tp,cwd:$c}' \
    | hook "$SR/hooks/route-prompt.sh" TMPDIR="$WS"; }
for p in '<task-notification><task-id>t1</task-id><status>completed</status></task-notification>' \
         'Stop hook feedback: run the suite first' '<system-reminder>a file changed</system-reminder>' \
         $'Another Claude session sent a message:\n<agent-message from="a1">done</agent-message>' \
         $'note above the frame\n[Subagent hand-back] all green' \
         $'# Autonomous loop tick (dynamic pacing)\n\nRun the autonomous check; fix the failing build.'; do
  t=$(fresh); edit "$D" "$D/app/Http/Controllers/ApiTokenController.php" "$t" >/dev/null
  fl=$(prompt_d "$p" "$t")
  grep -qF 'Your recent edits may need these skills' <<<"$fl" && bad "harness frame flushed the digest [${p:0:30}]" || ok
  jq -e '.pending_low | any(.flushed != true)' "$(statef "$D" "$t")" >/dev/null 2>&1 && ok || bad "harness frame marked pending_low flushed [${p:0:30}]"
done
fl=$(prompt_d 'what does a <task-notification> prompt carry?' "$TD")
grep -qF 'Your recent edits may need these skills' <<<"$fl" && grep -qF 'ApiTokenController.php' <<<"$fl" && ok \
  || bad "human prompt quoting a frame marker did not flush; got: ${fl:0:200}"
grep -qE 'runbook\.md|badge\.css|login\.html|notes\.txt' <<<"$fl" && bad "digest named a doc/style file: ${fl:0:200}" || ok

# 19. names are qualified plugin:skill in the nudge, the digest and the SessionEnd line: a bare name loaded a project's own
#     .claude/skills copy of the same name (Laravel Boost ships several) instead of the plugin's file
Q="$WS/q"; mkrepo "$Q"; TQ="$WS/t-q.jsonl"
printf '<?php\nclass Token { public function show() { return $this->token; } }\n' > "$Q/app/Models/Token.php"
out=$(edit "$Q" "$Q/app/Models/Token.php" "$TQ")
jq -r '.hookSpecificOutput.additionalContext' <<<"$out" 2>/dev/null | grep -qF 'Load the `laravel:laravel-best-practices` skill for Token.php' \
  && grep -qF 'and check your change against it.' <<<"$out" && ok || bad "qualified: nudge does not name laravel:laravel-best-practices; got: ${out:0:200}"
grep -qF 'plugin)' <<<"$out" && bad "qualified: the old '(X plugin)' tail survived" || ok
fl=$(jq -cn --arg c "$Q" --arg tp "$TQ" '{hook_event_name:"UserPromptSubmit",prompt:"next",session_id:"sess",transcript_path:$tp,cwd:$c}' \
  | hook "$SR/hooks/route-prompt.sh" TMPDIR="$WS")
grep -qF 'security:security-review (Token.php)' <<<"$fl" && ok || bad "qualified: digest does not name security:security-review; got: ${fl:0:200}"
printf '<?php\n$secret = 1;\n' > "$Q/app/Models/Key.php"; edit "$Q" "$Q/app/Models/Key.php" "$TQ" >/dev/null
sl=$(jq -cn --arg c "$Q" --arg tp "$TQ" '{hook_event_name:"SessionEnd",session_id:"sess",transcript_path:$tp,cwd:$c}' \
  | hook "$SR/hooks/summary.sh" HOME="$WS/home19")
grep -qF 'security:security-review (1 file)' <<<"$sl" && ok || bad "qualified: SessionEnd line does not name security:security-review; got: ${sl:0:200}"

# 20. no rubric for a file nobody reviews: gitignored scratch, anything under taskmaster-docs/ or .claude/, and a target outside
#     the project root stay silent and queue nothing; the same file shape tracked in the repo still routes
X="$WS/x"; mkrepo "$X"; printf 'scratch/\n' > "$X/.gitignore"
mkdir -p "$X/scratch" "$X/taskmaster-docs/retro" "$X/.claude/skills/probe" "$WS/outside-x"
for f in scratch/probe.py taskmaster-docs/retro/quant.py .claude/skills/probe/run.ts; do
  printf 'import os\ntoken = os.environ["TOKEN"]\n' > "$X/$f"
  t=$(fresh); out=$(edit "$X" "$X/$f" "$t")
  [ -z "$out" ] && ok || bad "excluded target [$f]: expected silence, got: ${out:0:160}"
  [ ! -e "$(statef "$X" "$t")" ] && ok || bad "excluded target [$f]: state written"
done
printf 'x = 1\n' > "$WS/outside-x/tool.py"
for f in "$WS/outside-x/tool.py" "../outside-x/tool.py"; do
  out=$(edit "$X" "$f" "$(fresh)")
  [ -z "$out" ] && ok || bad "outside-root Edit [$f]: expected silence, got: ${out:0:160}"
done
out=$(bashw "$X" "printf 'select 1;\\n' > scratch/q.sql" "$(fresh)")
[ -z "$out" ] && ok || bad "gitignored Bash target: expected silence, got: ${out:0:160}"
printf 'x = 1\n' > "$X/tool.py"
out=$(edit "$X" "$X/tool.py" "$(fresh)")
has_skill "$out" low-cognitive-load && ok || bad "tracked .py beside the excluded ones did not route; got: ${out:0:200}"

# 21. a skill this context already loaded is not nudged: its "Base directory for this skill" line, a Read of its SKILL.md, or a
#     qualified Skill call in the transcript. The PROJECT's copy of the same bare name loaded, read or called bare does not count.
Y="$WS/y"; mkrepo "$Y"; mkdir -p "$Y/database/migrations"
sdir() { printf '%s/plugins/%s/skills/%s' "$ROOT" "$1" "$2"; }
tline_base() { jq -cn --arg t "$(printf 'Base directory for this skill: %s\n\n# Skill' "$1")" '{type:"user",message:{role:"user",content:[{type:"text",text:$t}]}}'; }
tline_read() { jq -cn --arg f "$1" '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",id:"toolu_r",name:"Read",input:{file_path:$f}}]}}'; }
tline_skill() { jq -cn --arg s "$1" '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",id:"toolu_s",name:"Skill",input:{skill:$s}}]}}'; }
printf '<?php\n' > "$Y/app/Models/Plan.php"; : > "$Y/database/migrations/2026_01_01_000000_create_plans.php"
TY="$WS/t-y-loaded.jsonl"; tline_base "$(sdir laravel laravel-best-practices)" > "$TY"
out=$(edit "$Y" "$Y/app/Models/Plan.php" "$TY")
has_skill "$out" laravel-best-practices && bad "loaded (Skill base dir): laravel re-nudged; got: ${out:0:200}" || ok
has_skill "$out" low-cognitive-load && ok || bad "loaded: an unloaded skill on the same edit stopped firing; got: ${out:0:200}"
TY="$WS/t-y-read.jsonl"; tline_read "$(sdir database sql-best-practices)/SKILL.md" > "$TY"
out=$(edit "$Y" "$Y/database/migrations/2026_01_01_000000_create_plans.php" "$TY")
has_skill "$out" sql-best-practices && bad "loaded (SKILL.md Read): sql re-nudged; got: ${out:0:200}" || ok
TY="$WS/t-y-skill.jsonl"; tline_skill laravel:laravel-best-practices > "$TY"
out=$(edit "$Y" "$Y/app/Models/Plan.php" "$TY")
has_skill "$out" laravel-best-practices && bad "loaded (qualified Skill call): laravel re-nudged; got: ${out:0:200}" || ok
TY="$WS/t-y-shadow.jsonl"
{ tline_base "$Y/.claude/skills/laravel-best-practices"; tline_read "$Y/.claude/skills/laravel-best-practices/SKILL.md"; tline_skill laravel-best-practices; } > "$TY"
out=$(edit "$Y" "$Y/app/Models/Plan.php" "$TY")
has_skill "$out" laravel-best-practices && ok || bad "project copy loaded: the plugin's laravel skill was taken as loaded; got: ${out:0:200}"

# 22. a skill matched by a file row and then an import or command row takes rank 0 and that match's subject: a components/ stylesheet
#     importing tailwindcss, written after two rank-1 files, keeps tailwind inside the cap; components.json plus `shadcn add` quotes the command
Z="$WS/z"; mkrepo "$Z"; printf '{"devDependencies":{"tailwindcss":"^4.0.0"}}\n' > "$Z/package.json"; mkdir -p "$Z/resources/js/components"
out=$(bashw "$Z" "cat > app/Models/Order.php <<'A'
<?php
A
printf 'select 1;\\n' > app/orders.sql; printf '@import \"tailwindcss\";\\n' > resources/js/components/Card.css" "$(fresh)")
has_skill "$out" tailwind-best-practices && ok || bad "min rank: the @import row did not lift tailwind over two rank-1 rows; got [$(echo $(skills <<<"$out"))]"
[ "$(skills <<<"$out" | grep -c .)" = 2 ] && ok || bad "min rank: expected 2 nudges, got [$(echo $(skills <<<"$out"))]"
printf '{"style":"new-york"}\n' > "$Z/components.json"
out=$(bashc "$Z" 'printf x > components.json; npx shadcn@latest add button' "$(fresh)")
grep -qF 'skill for `shadcn@latest add`' <<<"$out" && ok || bad "min rank: the rank-0 command match did not carry its subject; got: ${out:0:200}"

# 23. a skill found loaded is recorded as loaded (not fired, which the ledger reports as surfaced), so the next edit routing it does not grep the transcript again
TY="$WS/t-y-once.jsonl"; tline_base "$(sdir laravel laravel-best-practices)" > "$TY"
edit "$Y" "$Y/app/Models/Plan.php" "$TY" >/dev/null
jq -e '(.loaded | index("laravel-best-practices")) and ((.fired // []) | index("laravel-best-practices") | not)' "$(statef "$Y" "$TY")" >/dev/null 2>&1 && ok || bad "loaded once: laravel-best-practices not recorded in loaded (or also in fired)"
printf '#!/bin/bash\nprintf "%%s\\n" "$*" >> "$GREP_LOG"\nexec %s "$@"\n' "$(command -v grep)" > "$HS/grep"; chmod +x "$HS/grep"
edit "$Y" "$Y/app/Models/Plan.php" "$TY" PATH="$HS:$PATH" GREP_LOG="$WS/grep.log" >/dev/null
rm -f "$HS/grep"
scans=$(grep -cF -- "$TY" "$WS/grep.log" 2>/dev/null)
[ -s "$WS/grep.log" ] && [ "$scans" = 0 ] && ok || bad "loaded once: the second edit grepped the transcript ${scans:-?} time(s)"

# 24. interpreter writes (bash-write-effects): a file an interpreter run changed in git since this hook's previous call routes as an
#     Edit of it would; the first call in a repo only sets the marker; a run that wrote nothing, and a file an Edit changed between
#     two Bash calls, stay silent.
if command -v python3 >/dev/null 2>&1; then
  K="$WS/fx"; mkrepo "$K"; MK="$K/.claude/skill-router/bash-effects.mark"
  out=$(bashw "$K" "python3 - <<'PY'
open('app/Models/First.php', 'w').write('<?php\n')
PY" "$(fresh)")
  [ -f "$K/app/Models/First.php" ] || bad "fixture: the first python heredoc did not write First.php"
  [ -z "$out" ] && [ -f "$MK" ] && ok || bad "effects: no marker yet must be silent and leave the marker; got: ${out:0:160}"
  for cmd in "python3 -c 'print(1)'" 'ls -la app'; do
    out=$(bashw "$K" "$cmd" "$(fresh)")
    [ -z "$out" ] && ok || bad "effects: a run that wrote nothing routed [$cmd]: ${out:0:160}"
  done
  AUTH='app/Http/Controllers/AuthController.php'; TK="$(fresh)"
  out_b=$(bashw "$K" "python3 - <<'PY'
open('$AUTH', 'w').write('<?php\nclass AuthController { public function login() { return \$this->authenticate(\$password); } }\n')
PY" "$TK")
  out_e=$(edit "$K" "$K/$AUTH" "$(fresh)")
  has_skill "$out_b" laravel-best-practices && ok || bad "effects: a python heredoc write did not route laravel-best-practices; got: ${out_b:0:200}"
  sb=$(skills <<<"$out_b"); se=$(skills <<<"$out_e")
  [ -n "$se" ] && [ "$sb" = "$se" ] && ok || bad "effects vs edit: skill sets differ — python [$(echo $sb)] edit [$(echo $se)]"
  jq -e --arg f "$K/$AUTH" '.pending_low | any(.skill == "security-review" and .file == $f)' "$(statef "$K" "$TK")" >/dev/null 2>&1 \
    && ok || bad "effects: the auth file written through python queued no security-review signal"
  mkdir -p "$K/database"; printf 'select 1;\n' > "$K/database/report.sql"
  edit "$K" "$K/database/report.sql" "$(fresh)" >/dev/null
  out=$(bashw "$K" "python3 - <<'PY'
open('app/svc.go', 'w').write('package app\n')
PY" "$(fresh)")
  has_skill "$out" low-cognitive-load && ok || bad "effects: the go file python wrote did not route; got: ${out:0:200}"
  has_skill "$out" sql-best-practices && bad "effects: the file an Edit changed before this run was read again as its write" || ok
else
  echo "SKIP 24: python3 not available"
fi

# 25. bash-write-effects, second round: a failed command (PostToolUseFailure) is read and answered in that event's envelope;
#     an interpreter at the end of a pipe counts; a marker another session dated, a root that is $HOME and a repo with
#     status.showUntrackedFiles=no read nothing; a state dir that exists without a .gitignore gets one; a 1 MB
#     separator-free token costs no quadratic regex.
bashx() { # cwd command transcript session event [env...] — runs the command, then the hook, as bashw does
  local c="$1" cmd="$2" t="$3" s="$4" e="$5"; shift 5
  (cd "$c" && bash -c "$cmd") >/dev/null 2>&1
  jq -cn --arg c "$c" --arg cmd "$cmd" --arg tp "$t" --arg s "$s" --arg e "$e" \
    '{hook_event_name:$e,tool_name:"Bash",session_id:$s,transcript_path:$tp,cwd:$c,tool_input:{command:$cmd}}' | hook "$HOOK" "$@"
}
if command -v python3 >/dev/null 2>&1; then
  jq -e '.hooks.PostToolUseFailure[] | select(.matcher == "Bash") | .hooks[] | select(.command | test("hooks/route.sh"))' \
    "$SR/hooks/hooks.json" >/dev/null 2>&1 && ok || bad "effects: route.sh is not registered on PostToolUseFailure for Bash"
  K="$WS/fx2"; mkrepo "$K"; edit "$K" "$K/composer.json" "$(fresh)" >/dev/null
  out=$(bashx "$K" "python3 -c \"open('app/Models/Failed.php', 'w').write('<?php')\"; false" "$(fresh)" sess PostToolUseFailure)
  has_skill "$out" laravel-best-practices && printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUseFailure"' >/dev/null 2>&1 \
    && ok || bad "effects: a failed python run did not route in a PostToolUseFailure envelope; got: ${out:0:200}"
  printf '<?php\n' > "$K/app/Models/Piped.php"
  out=$(bashx "$K" "cat gen.py | python3" "$(fresh)" sess PostToolUse)
  has_skill "$out" laravel-best-practices && ok || bad "effects: a python at the end of a pipe was not read; got: ${out:0:200}"
  printf '<?php\n' > "$K/app/Models/Other.php"
  out=$(bashx "$K" "python3 gen.py" "$(fresh)" sess-2 PostToolUse)
  [ -z "$out" ] && ok || bad "effects: a marker another session dated was read; got: ${out:0:200}"
  printf '<?php\n' > "$K/app/Models/Home.php"
  out=$(bashx "$K" "python3 gen.py" "$(fresh)" sess-2 PostToolUse HOME="$K")
  [ -z "$out" ] && ok || bad "effects: a root that is \$HOME was read; got: ${out:0:200}"
  git -C "$K" config status.showUntrackedFiles no; printf '<?php\n' > "$K/app/Models/Hidden.php"
  out=$(bashx "$K" "python3 gen.py" "$(fresh)" sess-2 PostToolUse)
  [ -z "$out" ] && ok || bad "effects: a repo with status.showUntrackedFiles=no was read; got: ${out:0:200}"
  K3="$WS/fx3"; mkrepo "$K3"; mkdir -p "$K3/.claude/skill-router"
  bashx "$K3" "ls" "$(fresh)" sess PostToolUse >/dev/null
  [ -f "$K3/.claude/skill-router/.gitignore" ] && [ -z "$(git -C "$K3" status --porcelain --untracked-files=all -- .claude)" ] \
    && ok || bad "effects: a state dir that existed without a .gitignore left the marker visible to git"
  head -c 1000000 /dev/zero | tr '\0' 'A' | { printf "echo '"; cat; printf "' | base64 -d | wc -c"; } > "$WS/long-cmd"
  t0=$(date +%s)
  jq -cn --arg c "$K3" --rawfile cmd "$WS/long-cmd" --arg tp "$(fresh)" \
    '{hook_event_name:"PostToolUse",tool_name:"Bash",session_id:"sess",transcript_path:$tp,cwd:$c,tool_input:{command:$cmd}}' | hook "$HOOK" >/dev/null
  took=$(( $(date +%s) - t0 ))
  [ "$took" -le 3 ] && ok || bad "effects: a 1 MB separator-free token took $took s (quadratic regex)"
else
  echo "SKIP 25: python3 not available"
fi

# 26. command rows with no file to route (2026-10-15): a dependency update rewrites only the lockfile, and a ReUI or Metronic copy
#     lands owned code that never imports @reui/. Neighbours stay silent: install, a script named update, a plain copy, a quoted mention.
P="$WS/p"; mkui "$P" '{"dependencies":{"react":"19.0.0"}}'
for cmd in 'composer update --with-all-dependencies' 'npm update' 'cd web && npm upgrade' 'composer upgrade laravel/framework'; do
  out=$(bashc "$P" "$cmd" "$(fresh)")
  has_skill "$out" package-hygiene && ok || bad "command row [$cmd]: did not route package-hygiene; got: ${out:0:160}"
done
for cmd in 'cp -r ~/Downloads/metronic-v9/src/components/ui/. resources/js/components/ui/' 'rsync -a ../reui-blocks/ src/components/blocks/'; do
  out=$(bashc "$P" "$cmd" "$(fresh)")
  has_skill "$out" reui-best-practices && ok || bad "command row [$cmd]: did not route reui-best-practices; got: ${out:0:160}"
done
for cmd in 'composer install' 'npm run update-snapshots' 'cp src/a.tsx src/b.tsx' 'git log --grep metronic' 'git commit -m "npm update and cp the reui kit"'; do
  out=$(bashc "$P" "$cmd" "$(fresh)")
  [ -z "$out" ] && ok || bad "command row [$cmd]: expected silence, got: ${out:0:160}"
done

# 9. every hook call exited 0 (fail-open contract)
[ ! -s "$NONZERO" ] && ok || { bad "non-zero hook exit(s):"; cat "$NONZERO"; }

echo "route: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
