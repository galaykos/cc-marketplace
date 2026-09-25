#!/usr/bin/env bash
# Author-time tests for hooks/subagent-skills.sh — the SubagentStart hook that hands a
# plugin subagent the Read paths of its declared `bestpractices-skill:` list, filtered to
# this project's stack by prime.sh's evidence rows — and for prime.sh reading manifests
# at the project root rather than the payload cwd (0.20.0).
#
# Runs the REAL hooks against a FAKE installed marketplace: the versioned cache layout a
# real install uses (`<cache>/<marketplace>/<plugin>/<version>/`), holding the real agent
# files of web-dev, laravel, ui-ux and code-review (their frontmatter is what is under
# test) and a stub SKILL.md for every skill those plugins ship. CLAUDE_PLUGIN_ROOT points
# into that cache, which is all hooks/plugins-dir.sh reads to find the siblings.
# Payload shape per the hooks docs § SubagentStart (session_id, transcript_path, cwd,
# hook_event_name, agent_id, agent_type), agent_type plugin-scoped (`web-dev:frontend-reviewer`).
#
# Asserts: a Laravel/Inertia repo gives frontend-reviewer inertia (plus vite when
# package.json declares it) and never react-native or nextjs; a Next.js repo gives it
# nextjs; a declared skill whose plugin is absent is dropped; a skill the agent preloads
# via `skills:` is dropped; an agent without the field, a built-in or unknown agent type,
# and both off switches are silent; a subdirectory cwd gives the same output as the root;
# the output is one SubagentStart envelope under the byte cap, paths whole; and prime.sh
# primes the same line from a subdirectory as from the root.
set -u
# This session exports it, pointing at the marketplace repo; cc_state_root honours it
# outside git, so a stray value would make a fixture look like part of this repo.
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

# --- fake installed marketplace ------------------------------------------------------
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
# A synthetic agent that preloads one of its declared skills through `skills:`.
mkdir -p "$MKT/fixture/1.0.0/agents"
printf -- '---\nname: dual\ndescription: x\nskills:\n  - ui-ux:tailwind-best-practices\nbestpractices-skill: tailwind-best-practices,shadcn-best-practices\n---\nbody\n' \
  > "$MKT/fixture/1.0.0/agents/dual.md"
printf -- '---\nname: dual-inline\ndescription: x\nskills: [ui-ux:tailwind-best-practices]\nbestpractices-skill: tailwind-best-practices, shadcn-best-practices\n---\nbody\n' \
  > "$MKT/fixture/1.0.0/agents/dual-inline.md"
PR_ROOT="$MKT/skill-router/0.20.0"

# --- fixture repos -------------------------------------------------------------------
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

# --- drivers ---------------------------------------------------------------------------
spawn() { # cwd agent_type [env...] — prints hook stdout; a non-zero exit is a failure
  local c="$1" a="$2"; shift 2
  local out rc
  out=$(jq -cn --arg c "$c" --arg a "$a" --arg tp "$WS/t-parent.jsonl" \
    '{session_id:"sess",transcript_path:$tp,cwd:$c,hook_event_name:"SubagentStart",agent_id:"agent-1",agent_type:$a}' \
    | env CLAUDE_PLUGIN_ROOT="$PR_ROOT" "$@" bash "$HOOK" 2>/dev/null); rc=$?
  [ "$rc" -eq 0 ] || echo "EXIT $rc" >> "$WS/nonzero"
  printf '%s' "$out"
}
ctx()    { jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null <<<"$1"; }
skills() { ctx "$1" | grep -oE 'skills/[a-z0-9-]+/SKILL\.md' | sed 's|^skills/||; s|/SKILL\.md$||' | tr '\n' ' ' | sed 's/ $//'; }
has()    { case " $(skills "$1") " in *" $2 "*) return 0 ;; esac; return 1; }

# 1. Laravel/Inertia + vite: frontend-reviewer gets inertia and vite, never RN or Next.
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
o=$(spawn "$LN" web-dev:frontend-reviewer)
[ "$(skills "$o")" = "inertia-best-practices" ] && ok || bad "laravel no-vite: expected [inertia] alone; got [$(skills "$o")]"

# 1c. web-developer in the Laravel repo: laravel + vite, never RN or Next
o=$(spawn "$L" web-dev:web-developer)
[ "$(skills "$o")" = "laravel-best-practices vite-best-practices" ] && ok || bad "web-developer laravel: expected [laravel vite]; got [$(skills "$o")]"

# 2. Next.js repo: frontend-reviewer gets nextjs, and nothing Laravel-side.
o=$(spawn "$N" web-dev:frontend-reviewer)
[ "$(skills "$o")" = "nextjs-best-practices" ] && ok || bad "next: expected [nextjs] alone; got [$(skills "$o")]"

# 3. an owning plugin that is not installed drops its skill — inertia lives in laravel
mv "$MKT/laravel" "$WS/laravel-away"
o=$(spawn "$L" web-dev:frontend-reviewer)
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

[ -e "$WS/nonzero" ] && bad "a hook exited non-zero: $(tr '\n' ' ' < "$WS/nonzero")" || ok

echo "subagent-skills: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
