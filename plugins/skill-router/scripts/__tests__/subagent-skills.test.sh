#!/usr/bin/env bash
# subagent-skills.test.sh — runs hooks/subagent-skills.sh, and prime.sh's project-root read, against a fake versioned install holding the
#   real agent files of web-dev, laravel, ui-ux and code-review with stub skills; each numbered case names what it asserts.
# Why, limits, history: rationale/derivations/plugin-skill-router.md § plugins/skill-router/scripts/__tests__/subagent-skills.test.sh
set -u
# A live session exports it; cc_state_root takes it as the root of any non-git cwd beneath it.
unset CLAUDE_PROJECT_DIR
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SR="$ROOT/plugins/skill-router"
HOOK="$SR/hooks/subagent-skills.sh"
PRIME="$SR/hooks/prime.sh"
command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not available (hook fails open without it)"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not available (the project root is the git toplevel)"; exit 0; }
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK"; exit 1; }

pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
ok()  { pass=$((pass+1)); }
bad() { echo "FAIL $1"; fail=$((fail+1)); }

fake_plugin() { # $1 cache root, $2 plugin, $3 version — real agents, stub skills
  local d="$1/$2/$3" s
  mkdir -p "$d/agents" "$d/skills"
  cp "$ROOT/plugins/$2/agents/"*.md "$d/agents/" 2>/dev/null
  for s in "$ROOT/plugins/$2/skills/"*/; do
    [ -d "$s" ] || continue
    mkdir -p "$d/skills/$(basename "$s")"
    printf '# stub\n' > "$d/skills/$(basename "$s")/SKILL.md"
  done
}
MKT="$WS/cache/mkt"
mkdir -p "$MKT/skill-router/0.20.0"
fake_plugin "$MKT" web-dev 0.9.3
fake_plugin "$MKT" laravel 0.12.0
fake_plugin "$MKT" ui-ux 0.26.3
fake_plugin "$MKT" code-review 0.23.0
fake_plugin "$MKT" database 0.11.0
# A synthetic agent that preloads one of its declared skills through `skills:`.
mkdir -p "$MKT/fixture/1.0.0/agents"
printf -- '---\nname: dual\ndescription: x\nskills:\n  - ui-ux:tailwind-best-practices\nbestpractices-skill: tailwind-best-practices,shadcn-best-practices\n---\nbody\n' \
  > "$MKT/fixture/1.0.0/agents/dual.md"
printf -- '---\nname: dual-inline\ndescription: x\nskills: [ui-ux:tailwind-best-practices]\nbestpractices-skill: tailwind-best-practices, shadcn-best-practices\n---\nbody\n' \
  > "$MKT/fixture/1.0.0/agents/dual-inline.md"
PR_ROOT="$MKT/skill-router/0.20.0"

laravel_repo() { # $1 dir, $2 with-vite (1|0)
  mkdir -p "$1/app/Enums" "$1/resources/js/pages" "$1/database/migrations"
  git -C "$1" init -q
  printf '{"require":{"php":"^8.3","laravel/framework":"^12.0","inertiajs/inertia-laravel":"^2.0"}}\n' > "$1/composer.json"
  if [ "$2" = 1 ]; then
    printf '{"devDependencies":{"@inertiajs/react":"^2.0","react":"^19.0","laravel-vite-plugin":"^1.0","vite":"^6.0","tailwindcss":"^4.0"}}\n' > "$1/package.json"
  else
    printf '{"devDependencies":{"@inertiajs/react":"^2.0","react":"^19.0","tailwindcss":"^4.0"}}\n' > "$1/package.json"
  fi
}
L="$WS/laravel";   laravel_repo "$L" 1
LN="$WS/laravel-novite"; laravel_repo "$LN" 0
N="$WS/next"; mkdir -p "$N/app/api"; git -C "$N" init -q
printf '{"dependencies":{"next":"^16.0","react":"^19.0","react-dom":"^19.0"}}\n' > "$N/package.json"

spawn() { # cwd agent_type [env...] — prints hook stdout; a non-zero exit is a failure. TP names the parent transcript.
  local c="$1" a="$2"; shift 2
  local out rc
  out=$(jq -cn --arg c "$c" --arg a "$a" --arg tp "${TP:-$WS/t-parent.jsonl}" \
    '{session_id:"sess",transcript_path:$tp,cwd:$c,hook_event_name:"SubagentStart",agent_id:"agent-1",agent_type:$a}' \
    | env CLAUDE_PLUGIN_ROOT="$PR_ROOT" "$@" bash "$HOOK" 2>/dev/null); rc=$?
  [ "$rc" -eq 0 ] || echo "EXIT $rc" >> "$WS/nonzero"
  printf '%s' "$out"
}
dispatch() { # cwd subagent_type prompt [env...] — the parent's PreToolUse on its Agent call; prints hook stdout
  local c="$1" a="$2" p="$3"; shift 3
  local out rc
  out=$(jq -cn --arg c "$c" --arg a "$a" --arg p "$p" --arg tp "${TP:-$WS/t-parent.jsonl}" \
    '{session_id:"sess",transcript_path:$tp,cwd:$c,hook_event_name:"PreToolUse",tool_name:"Agent",tool_use_id:"toolu_1",
      tool_input:{description:"d",prompt:$p,subagent_type:$a}}' \
    | env CLAUDE_PLUGIN_ROOT="$PR_ROOT" "$@" bash "$HOOK" 2>/dev/null); rc=$?
  [ "$rc" -eq 0 ] || echo "EXIT $rc" >> "$WS/nonzero"
  printf '%s' "$out"
}
ctx()    { jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null <<<"$1"; }
skills() { ctx "$1" | grep -oE 'skills/[a-z0-9-]+/SKILL\.md' | sed 's|^skills/||; s|/SKILL\.md$||' | tr '\n' ' ' | sed 's/ $//'; }
has()    { case " $(skills "$1") " in *" $2 "*) return 0 ;; esac; return 1; }

# 1. Laravel/Inertia + vite: frontend-reviewer gets inertia and vite, never RN or Next, when its dispatch names the Vite config.
TP="$WS/t-1.jsonl"
dispatch "$L" web-dev:frontend-reviewer 'Review vite.config.ts and resources/js/pages/Home.tsx' >/dev/null
o=$(spawn "$L" web-dev:frontend-reviewer)
has "$o" inertia-best-practices && ok || bad "laravel: inertia-best-practices missing; got [$(skills "$o")]"
has "$o" vite-best-practices     && ok || bad "laravel: vite-best-practices missing; got [$(skills "$o")]"
has "$o" react-native-best-practices && bad "laravel: react-native-best-practices injected" || ok
has "$o" nextjs-best-practices       && bad "laravel: nextjs-best-practices injected" || ok
# declared order is kept: the frontmatter lists inertia before vite
[ "$(skills "$o")" = "inertia-best-practices vite-best-practices" ] && ok || bad "laravel: expected [inertia vite] in declared order; got [$(skills "$o")]"
# each path is absolute, under the fake cache, owned by the RIGHT plugin, and exists
paths=$(ctx "$o" | grep '^/')
printf '%s\n' "$paths" | grep -qxF "$MKT/laravel/0.12.0/skills/inertia-best-practices/SKILL.md" && ok || bad "laravel: inertia path not under the laravel plugin: $paths"
printf '%s\n' "$paths" | grep -qxF "$MKT/web-dev/0.9.3/skills/vite-best-practices/SKILL.md"     && ok || bad "laravel: vite path not under web-dev: $paths"
ctx "$o" | grep -qF 'Read these before working; a path the dispatcher already gave you needs no second Read' && ok || bad "laravel: instruction line missing: $(ctx "$o" | head -1)"

# 1b. same repo without vite in package.json → inertia alone
TP="$WS/t-1b.jsonl"; dispatch "$LN" web-dev:frontend-reviewer 'Review vite.config.ts' >/dev/null
o=$(spawn "$LN" web-dev:frontend-reviewer)
[ "$(skills "$o")" = "inertia-best-practices" ] && ok || bad "laravel no-vite: expected [inertia] alone; got [$(skills "$o")]"

# 1c. web-developer in the Laravel repo: inertia + laravel + vite, never RN or Next
TP="$WS/t-1c.jsonl"; dispatch "$L" web-dev:web-developer 'Wire the new entry in vite.config.ts' >/dev/null
o=$(spawn "$L" web-dev:web-developer)
[ "$(skills "$o")" = "inertia-best-practices laravel-best-practices vite-best-practices" ] && ok || bad "web-developer laravel: expected [inertia laravel vite]; got [$(skills "$o")]"

# 1d. a surface skill rides only a dispatch naming its file kind: no Vite config named, no vite path (it was handed out on every
#     spawn and read 2 times in 20); no migration or .sql named, no sql path for backend-engineer; a record of ANOTHER agent type
#     or one older than DISPATCH_TTL does not count; database-engineer, whose list is all SQL, keeps it with no record at all.
TP="$WS/t-1d.jsonl"; dispatch "$L" web-dev:frontend-reviewer 'Review resources/js/pages/Home.tsx' >/dev/null
o=$(spawn "$L" web-dev:frontend-reviewer)
[ "$(skills "$o")" = "inertia-best-practices" ] && ok || bad "vite gate: no vite.config named, expected [inertia]; got [$(skills "$o")]"
o=$(spawn "$L" laravel:backend-engineer)
[ "$(skills "$o")" = "laravel-best-practices" ] && ok || bad "sql gate: no migration named, expected [laravel]; got [$(skills "$o")]"
TP="$WS/t-1d2.jsonl"; dispatch "$L" laravel:backend-engineer 'Add database/migrations/2026_01_01_000000_add_total.php and app/Models/Order.php' >/dev/null
o=$(spawn "$L" laravel:backend-engineer)
[ "$(skills "$o")" = "laravel-best-practices sql-best-practices" ] && ok || bad "sql gate: migration named, expected [laravel sql]; got [$(skills "$o")]"
o=$(spawn "$L" web-dev:frontend-reviewer)
[ "$(skills "$o")" = "inertia-best-practices" ] && ok || bad "vite gate: another agent type's record leaked; got [$(skills "$o")]"
TP="$WS/t-1d3.jsonl"; mkdir -p "$L/.claude/skill-router"
printf '%s\tweb-dev:frontend-reviewer\tsrc vite \n' "$(( $(date +%s) - 600 ))" > "$L/.claude/skill-router/dispatch-$(printf '%s' "$TP" | cksum | cut -d' ' -f1).tsv"
o=$(spawn "$L" web-dev:frontend-reviewer)
[ "$(skills "$o")" = "inertia-best-practices" ] && ok || bad "vite gate: a record older than the TTL counted; got [$(skills "$o")]"
rm -rf "$L/.claude"
TP="$WS/t-1d4.jsonl"
o=$(spawn "$L" database:database-engineer)
[ "$(skills "$o")" = "sql-best-practices" ] && ok || bad "all-surface agent: database-engineer lost sql with no record; got [$(skills "$o")]"

# 1e. general-purpose and claude dispatches naming a repo file get the primed skills as Read paths, surface skills gated the same way;
#     one naming no repo file (research, a product name, a taskmaster-docs brief, a path outside the root) gets nothing.
TP="$WS/t-1e.jsonl"
out=$(dispatch "$L" general-purpose 'Build the invoice export: app/Http/Controllers/InvoiceExportController.php and resources/js/pages/invoices.tsx')
[ -z "$out" ] && ok || bad "PreToolUse: printed output: ${out:0:160}"
o=$(spawn "$L" general-purpose)
[ "$(skills "$o")" = "laravel-best-practices inertia-best-practices tailwind-best-practices" ] && ok || bad "general-purpose: expected [laravel inertia tailwind]; got [$(skills "$o")]"
ctx "$o" | grep -qF "$MKT/laravel/0.12.0/skills/laravel-best-practices/SKILL.md" && ok || bad "general-purpose: laravel path not under the laravel plugin: $(ctx "$o")"
ctx "$o" | grep -qF 'Read these before working' && ok || bad "general-purpose: instruction line missing: $(ctx "$o" | head -1)"
TP="$WS/t-1e2.jsonl"; dispatch "$L" claude 'Add database/migrations/2026_02_01_000000_add_tier.php and the Pest test' >/dev/null
o=$(spawn "$L" claude)
[ "$(skills "$o")" = "sql-best-practices laravel-best-practices inertia-best-practices tailwind-best-practices" ] && ok || bad "claude agent + migration: expected [sql laravel inertia tailwind]; got [$(skills "$o")]"
for p in 'Research how Node.js streams handle backpressure and report back' 'Summarise taskmaster-docs/retro/notes.py for me' \
         "Read $WS/elsewhere/tool.py and reply" 'Reply with PONG'; do
  TP=$(mktemp "$WS/t-gp-XXXXXX"); dispatch "$L" general-purpose "$p" >/dev/null
  o=$(spawn "$L" general-purpose)
  [ -z "$o" ] && ok || bad "general-purpose naming no repo file [${p:0:40}]: expected silence, got [$(skills "$o")]"
done
TP="$WS/t-1e3.jsonl"; dispatch "$L" general-purpose 'Fix app/Models/Order.php' CC_SUBAGENT_SKILLS=off >/dev/null
o=$(spawn "$L" general-purpose)
[ -z "$o" ] && ok || bad "PreToolUse under CC_SUBAGENT_SKILLS=off recorded a dispatch; got [$(skills "$o")]"
rm -rf "$L/.claude"
TP="$WS/t-1e4.jsonl"; dispatch "$L" Explore 'Find app/Models/Order.php' >/dev/null
[ ! -e "$L/.claude" ] && ok || bad "PreToolUse: a built-in agent type's dispatch wrote state"
rm -rf "$L/.claude"
unset TP

# 1f. the hooks.json matchers reach the dispatches above: SubagentStart matches plugin agents, general-purpose and claude, not
#     Explore; PreToolUse matches the Agent tool (and its old name, Task) and nothing else.
HJ="$SR/hooks/hooks.json"
sm=$(jq -r '.hooks.SubagentStart[] | select(.hooks[].command | test("subagent-skills")) | .matcher' "$HJ")
pm=$(jq -r '.hooks.PreToolUse[]? | select(.hooks[].command | test("subagent-skills")) | .matcher' "$HJ")
for a in web-dev:frontend-reviewer general-purpose claude; do
  printf '%s' "$a" | grep -qE "$sm" && ok || bad "SubagentStart matcher [$sm] misses $a"
done
for a in Explore Plan claude-code-guide general-purpose-x; do
  printf '%s' "$a" | grep -qE "$sm" && bad "SubagentStart matcher [$sm] matches $a" || ok
done
for t in Agent Task; do printf '%s' "$t" | grep -qE "$pm" && ok || bad "PreToolUse matcher [$pm] misses $t"; done
for t in Bash Edit AgentX; do printf '%s' "$t" | grep -qE "$pm" && bad "PreToolUse matcher [$pm] matches $t" || ok; done

# 2. Next.js repo: frontend-reviewer gets nextjs, and nothing Laravel-side.
o=$(spawn "$N" web-dev:frontend-reviewer)
[ "$(skills "$o")" = "nextjs-best-practices" ] && ok || bad "next: expected [nextjs] alone; got [$(skills "$o")]"

# 3. an owning plugin that is not installed drops its skill — inertia lives in laravel
mv "$MKT/laravel" "$WS/laravel-away"
TP="$WS/t-3.jsonl"; dispatch "$L" web-dev:frontend-reviewer 'Review vite.config.ts' >/dev/null
o=$(spawn "$L" web-dev:frontend-reviewer)
unset TP; rm -rf "$L/.claude"
[ "$(skills "$o")" = "vite-best-practices" ] && ok || bad "laravel plugin absent: expected [vite] alone; got [$(skills "$o")]"
mv "$WS/laravel-away" "$MKT/laravel"

# 4. a skill the agent preloads through `skills:` is not handed out again
printf '{"devDependencies":{"tailwindcss":"^4.0"}}\n' > "$WS/tw.json"
TW="$WS/tw"; mkdir -p "$TW"; git -C "$TW" init -q; cp "$WS/tw.json" "$TW/package.json"; printf '{}\n' > "$TW/components.json"
o=$(spawn "$TW" fixture:dual)
[ "$(skills "$o")" = "shadcn-best-practices" ] && ok || bad "preloaded skill (block list): expected [shadcn] alone; got [$(skills "$o")]"
o=$(spawn "$TW" fixture:dual-inline)
[ "$(skills "$o")" = "shadcn-best-practices" ] && ok || bad "preloaded skill (inline list): expected [shadcn] alone; got [$(skills "$o")]"
# ...and the real ui-ux-reviewer, whose preload (a11y-audit) is not in its list, gets tailwind
o=$(spawn "$TW" ui-ux:ui-ux-reviewer)
has "$o" tailwind-best-practices && ok || bad "ui-ux-reviewer: tailwind missing; got [$(skills "$o")]"
has "$o" motion-best-practices && bad "ui-ux-reviewer: motion injected with no evidence row" || ok

# 5. silent cases — every one must print nothing and exit 0
silent() { [ -z "$2" ] && ok || bad "$1: expected silence, got: ${2:0:160}"; }
silent "agent without bestpractices-skill" "$(spawn "$L" code-review:code-reviewer)"
silent "built-in agent type"               "$(spawn "$L" Explore)"
silent "unknown plugin"                    "$(spawn "$L" other-marketplace:frontend-reviewer)"
silent "unknown agent in a known plugin"   "$(spawn "$L" web-dev:no-such-agent)"
silent "path-shaped agent name"            "$(spawn "$L" 'web-dev:../../laravel/0.12.0/agents/backend-engineer')"
silent "nothing declared matches (empty repo)" "$(mkdir -p "$WS/empty" && git -C "$WS/empty" init -q && spawn "$WS/empty" web-dev:frontend-reviewer)"
silent "CC_REMIND=off"                     "$(spawn "$L" web-dev:frontend-reviewer CC_REMIND=off)"
silent "CC_SUBAGENT_SKILLS=off"            "$(spawn "$L" web-dev:frontend-reviewer CC_SUBAGENT_SKILLS=off)"
silent "cwd that no longer exists"         "$(spawn "$WS/gone" web-dev:frontend-reviewer)"
silent "no CLAUDE_PLUGIN_ROOT"             "$(jq -cn --arg c "$L" '{cwd:$c,hook_event_name:"SubagentStart",agent_type:"web-dev:frontend-reviewer"}' | env -u CLAUDE_PLUGIN_ROOT bash "$HOOK" 2>/dev/null)"
silent "empty payload"                     "$(printf '{}' | CLAUDE_PLUGIN_ROOT="$PR_ROOT" bash "$HOOK" 2>/dev/null)"

# 6. a subdirectory cwd (the model `cd`-ed) resolves the same root and the same output,
#    and writes nothing anywhere in the repo
root_out=$(spawn "$L" web-dev:frontend-reviewer)
sub_out=$(spawn "$L/app/Enums" web-dev:frontend-reviewer)
[ -n "$root_out" ] && [ "$sub_out" = "$root_out" ] && ok || bad "subdir cwd: output differs from the root's: [$(skills "$sub_out")] vs [$(skills "$root_out")]"
[ ! -e "$L/.claude" ] && [ ! -e "$L/app/Enums/.claude" ] && ok || bad "subdir cwd: the hook wrote a .claude/ dir"

# 7. envelope shape and the byte cap: exactly one line, one SubagentStart envelope, the
#    context ≤ 700 chars — including a layout deep enough that four paths overflow it
o=$(spawn "$L" web-dev:frontend-reviewer)
[ "$(printf '%s\n' "$o" | grep -c .)" = 1 ] && jq -e '.hookSpecificOutput.hookEventName == "SubagentStart" and (.hookSpecificOutput | keys == ["additionalContext","hookEventName"])' <<<"$o" >/dev/null 2>&1 \
  && ok || bad "envelope: not exactly one SubagentStart envelope: ${o:0:200}"
[ "$(ctx "$o" | wc -c | tr -d ' ')" -le 700 ] && ok || bad "cap: context over 700 chars"
DEEP="$WS/$(printf 'd%.0s' $(seq 1 90))/cache/$(printf 'm%.0s' $(seq 1 60))"
mkdir -p "$DEEP/skill-router/0.20.0"
fake_plugin "$DEEP" web-dev 0.9.3; fake_plugin "$DEEP" laravel 0.12.0
ALL="$WS/all"; mkdir -p "$ALL"; git -C "$ALL" init -q
printf '{"require":{"laravel/framework":"^12.0"}}\n' > "$ALL/composer.json"
printf '{"dependencies":{"next":"^16.0","react-native":"^0.81.0","vite":"^6.0"}}\n' > "$ALL/package.json"
o=$(jq -cn --arg c "$ALL" '{cwd:$c,hook_event_name:"SubagentStart",agent_type:"web-dev:web-developer"}' \
  | CLAUDE_PLUGIN_ROOT="$DEEP/skill-router/0.20.0" bash "$HOOK" 2>/dev/null)
n=$(ctx "$o" | grep -c '^/')
[ "$(ctx "$o" | wc -c | tr -d ' ')" -le 700 ] && [ "$n" -ge 1 ] && [ "$n" -lt 4 ] && ok \
  || bad "cap: deep layout should keep 1-3 of 4 paths within 700 chars; kept $n, $(ctx "$o" | wc -c | tr -d ' ') chars"
ctx "$o" | grep '^/' | while IFS= read -r p; do [ -f "$p" ] || echo "cut path: $p"; done | grep -q . \
  && bad "cap: a kept path is not a whole existing file" || ok

# 8. prime.sh reads manifests at the project root: a subdirectory cwd primes the same line
prime() { jq -cn --arg c "$1" '{hook_event_name:"SessionStart",source:"compact",cwd:$c,session_id:"s"}' \
  | CLAUDE_PLUGIN_ROOT="$PR_ROOT" bash "$PRIME" 2>/dev/null; }
p_root=$(prime "$L"); p_sub=$(prime "$L/app/Enums")
case "$p_root" in *laravel-best-practices*inertia-best-practices*) ok ;; *) bad "prime root: laravel+inertia not primed: $p_root" ;; esac
[ "$p_sub" = "$p_root" ] && ok || bad "prime subdir cwd: differs from the root's — root [$p_root] sub [$p_sub]"
[ ! -e "$L/app/Enums/.claude" ] && ok || bad "prime subdir cwd: stray .claude/"

# 9. prime.sh names each skill as plugin:skill (a bare name loaded a project's own .claude/skills copy of the same name), and adds
#    ONE line naming every primed skill the project shadows; a repo shadowing nothing gets no second line.
case "$p_root" in *'laravel:laravel-best-practices'*'laravel:inertia-best-practices'*) ok ;; *) bad "prime: names not qualified: $p_root" ;; esac
printf '%s\n' "$p_root" | grep -qE '(^|[ ,])(laravel|inertia)-best-practices' && bad "prime: a bare name survived: $p_root" || ok
[ "$(printf '%s\n' "$p_root" | grep -c .)" = 1 ] && ok || bad "prime: a second line with no shadowing skill: $p_root"
mkdir -p "$L/.claude/skills/laravel-best-practices" "$L/.claude/skills/inertia-best-practices" "$L/.claude/skills/pest-testing"
for d in laravel-best-practices inertia-best-practices pest-testing; do printf '# project copy\n' > "$L/.claude/skills/$d/SKILL.md"; done
p_sh=$(prime "$L")
[ "$(printf '%s\n' "$p_sh" | grep -c .)" = 2 ] && ok || bad "prime shadow: expected exactly two lines; got: $p_sh"
printf '%s\n' "$p_sh" | sed -n 2p | grep -qF 'This project ships its own laravel-best-practices, inertia-best-practices in .claude/skills: a bare name loads that copy' \
  && ok || bad "prime shadow: collision line wrong: $(printf '%s\n' "$p_sh" | sed -n 2p)"
printf '%s\n' "$p_sh" | grep -qF 'pest-testing' && bad "prime shadow: named a project skill no row primes" || ok
rm -rf "$L/.claude"

# 10. SessionEnd removes the dispatch record with the context's other state
TP="$WS/t-10.jsonl"; dispatch "$L" general-purpose 'Fix app/Models/Order.php' >/dev/null
df="$L/.claude/skill-router/dispatch-$(printf '%s' "$TP" | cksum | cut -d' ' -f1).tsv"
[ -s "$df" ] && ok || bad "dispatch record not written at $df"
jq -cn --arg c "$L" --arg tp "$TP" '{hook_event_name:"SessionEnd",session_id:"sess",transcript_path:$tp,cwd:$c}' \
  | CLAUDE_PLUGIN_ROOT="$PR_ROOT" HOME="$WS/home" bash "$SR/hooks/summary.sh" >/dev/null 2>&1
[ ! -e "$df" ] && ok || bad "SessionEnd left the dispatch record"
unset TP; rm -rf "$L/.claude"

# 11. a dispatch of a type this hook does not handle exits after one jq read: no git call, no record; a handled type still records
SH="$WS/shim"; mkdir -p "$SH"
for b in jq git; do printf '#!/bin/bash\nprintf "%s\\n" >> "$SHIM_LOG"\nexec %s "$@"\n' "$b" "$(command -v "$b")" > "$SH/$b"; chmod +x "$SH/$b"; done
TP="$WS/t-11.jsonl"
dispatch "$L" Explore 'Find app/Models/Order.php' PATH="$SH:$PATH" SHIM_LOG="$WS/shim.log" >/dev/null
[ "$(grep -cx jq "$WS/shim.log")" = 1 ] && [ "$(grep -cx git "$WS/shim.log")" = 0 ] && ok \
  || bad "unhandled dispatch: expected 1 jq and 0 git calls; got [$(sort "$WS/shim.log" | uniq -c | tr -s ' \n' ' ')]"
[ ! -e "$L/.claude" ] && ok || bad "unhandled dispatch: wrote state"
dispatch "$L" general-purpose 'Fix app/Models/Order.php' PATH="$SH:$PATH" SHIM_LOG="$WS/shim.log" >/dev/null
[ -s "$L/.claude/skill-router/dispatch-$(printf '%s' "$TP" | cksum | cut -d' ' -f1).tsv" ] && ok || bad "handled dispatch: no record after the early type read"
unset TP; rm -rf "$L/.claude"

[ -e "$WS/nonzero" ] && bad "a hook exited non-zero: $(tr '\n' ' ' < "$WS/nonzero")" || ok

echo "subagent-skills: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
