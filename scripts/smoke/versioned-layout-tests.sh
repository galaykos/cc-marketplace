#!/usr/bin/env bash
# Smoke tests for skill-router's plugins-root resolution across BOTH install layouts.
#
# WHY THIS FILE EXISTS. Every other router harness builds a FLAT scratch layout
# (`$TMP/proot/skill-router`, `$TMP/proot/vue3`, …). A real install is VERSIONED
# (`<marketplace>/<plugin>/<version>`), and the hooks resolved the plugins root as
# `dirname "$CLAUDE_PLUGIN_ROOT"` — one level short. The installed-filter then
# reported every sibling plugin missing, so every glob rule was suppressed and
# route-prompt.sh's catalog glob matched nothing: the router was inert on every
# real install while 73 flat-layout assertions stayed green. A harness that only
# ever builds the layout the code already handles cannot fail.
#
# So the same behaviours are asserted TWICE — once flat, once versioned — and the
# suppression cases are asserted alongside the firing ones. A resolution bug that
# is "fixed" by making the filter always fire would pass the firing tests and fail
# the suppression ones.
#
# HONEST LIMIT: this pins the two layouts that exist today. A third layout would
# be as invisible to this harness as the versioned one was to the others.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/plugins/skill-router"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0

expect() { # $1 label, $2 output, $3 must-contain ('' = skip), $4 must-not-contain ('' = skip)
  local label="$1" out="$2" yes="$3" no="$4" ok=1
  if [ -n "$yes" ]; then case "$out" in *"$yes"*) ;; *) ok=0 ;; esac; fi
  if [ -n "$no"  ]; then case "$out" in *"$no"*)  ok=0 ;; esac; fi
  if [ "$ok" -eq 1 ]; then echo "PASS: $label"; else echo "FAIL: $label — got: ${out:-<empty>}"; rc=1; fi
}
expect_eq() { # $1 label, $2 actual, $3 expected
  if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 — expected '$3', got '$2'"; rc=1; fi
}

# Scratch rules: one row per owning plugin, so "installed" and "absent" are
# distinguishable by which nudge appears. Never the live rules.tsv.
write_rules() { # $1 destination file
  {
    printf 'glob\t*.tsx\tvl-present-canary\tvlpresent\thigh\n'
    printf 'glob\t*.tsx\tvl-absent-canary\tvlabsent\thigh\n'
  } > "$1"
}

# ---- fixture builders -------------------------------------------------------
# Both build the SAME logical install: skill-router plus one present sibling
# (`vlpresent`, carrying the skill and a command) and no `vlabsent` at all.

build_flat() { # $1 marketplace dir → echoes CLAUDE_PLUGIN_ROOT
  local mp="$1"
  mkdir -p "$mp/skill-router/hooks"
  cp "$SRC"/hooks/*.sh "$mp/skill-router/hooks/"
  write_rules "$mp/skill-router/rules.tsv"
  mkdir -p "$mp/vlpresent/skills/vl-present-canary" "$mp/vlpresent/commands"
  echo '# canary skill' > "$mp/vlpresent/skills/vl-present-canary/SKILL.md"
  printf -- '---\ndescription: Canary command for the layout harness.\n---\nbody\n' \
    > "$mp/vlpresent/commands/vlcmd.md"
  printf '%s\n' "$mp/skill-router"
}

build_versioned() { # $1 marketplace dir → echoes CLAUDE_PLUGIN_ROOT (newest version)
  local mp="$1" v
  # TWO cached releases of each plugin: the cache never prunes, and 0.10.0 must
  # win over 0.9.0 — a lexical sort picks the wrong one, which is why the resolver
  # tries `sort -V` first.
  for v in 0.9.0 0.10.0; do
    mkdir -p "$mp/skill-router/$v/hooks"
    cp "$SRC"/hooks/*.sh "$mp/skill-router/$v/hooks/"
    write_rules "$mp/skill-router/$v/rules.tsv"
  done
  for v in 0.9.0 0.10.0; do
    mkdir -p "$mp/vlpresent/$v/skills/vl-present-canary" "$mp/vlpresent/$v/commands"
    echo '# canary skill' > "$mp/vlpresent/$v/skills/vl-present-canary/SKILL.md"
    printf -- '---\ndescription: Canary command for the layout harness.\n---\nbody\n' \
      > "$mp/vlpresent/$v/commands/vlcmd.md"
  done
  printf '%s\n' "$mp/skill-router/0.10.0"
}

route() { # $1 plugin_root, $2 cwd, $3 file
  printf '{"hook_event_name":"PostToolUse","tool_name":"Write","session_id":"s%s","cwd":"%s","tool_input":{"file_path":"%s","content":"x"}}' \
    "$RANDOM$RANDOM" "$2" "$3" | CLAUDE_PLUGIN_ROOT="$1" bash "$1/hooks/route.sh"
  rm -rf "$2/.claude"
}

# ---- the same assertions against each layout --------------------------------
for layout in flat versioned; do
  mp="$TMP/$layout"; mkdir -p "$mp"
  pr=$(build_"$layout" "$mp")
  cwd="$TMP/cwd-$layout"; mkdir -p "$cwd"

  out=$(route "$pr" "$cwd" "$cwd/app.tsx")
  expect "[$layout] installed plugin's rule fires"      "$out" 'vl-present-canary' ''
  expect "[$layout] absent plugin's rule is suppressed" "$out" '' 'vl-absent-canary'
  expect "[$layout] nudge names the resolvable SKILL.md" "$out" 'skills/vl-present-canary/SKILL.md' ''

  # Catalog: exactly one line per plugin, whatever the cache holds.
  # Fresh session id per invocation: route-prompt.sh injects its catalog ONCE per
  # session and records that in a TMPDIR marker that outlives the process, so a
  # fixed id would make every run after the first silently assert nothing.
  cat_cwd="$TMP/catcwd-$layout"; mkdir -p "$cat_cwd"
  cout=$(jq -n --arg cwd "$cat_cwd" --arg sid "cat-$layout-$RANDOM$RANDOM" \
      '{hook_event_name:"UserPromptSubmit",session_id:$sid,cwd:$cwd,prompt:"implement a dashboard component"}' \
    | CLAUDE_PLUGIN_ROOT="$pr" bash "$pr/hooks/route-prompt.sh" 2>/dev/null || true)
  expect "[$layout] catalog lists the installed command" "$cout" '/vlpresent:vlcmd' ''
  expect_eq "[$layout] catalog lists it exactly once" \
    "$(printf '%s\n' "$cout" | grep -c -- '- /vlpresent:vlcmd' || true)" "1"

  # prime.sh: a .tsx repo asks for a11y-audit, owned by the `a11y` plugin, which
  # this fixture does NOT install — the include-filter must still say no.
  mkdir -p "$cwd/src"; : > "$cwd/src/x.tsx"
  pout=$(jq -n --arg cwd "$cwd" '{hook_event_name:"SessionStart",session_id:"p1",cwd:$cwd}' \
    | CLAUDE_PLUGIN_ROOT="$pr" bash "$pr/hooks/prime.sh" 2>/dev/null || true)
  expect "[$layout] prime.sh omits a skill whose plugin is absent" "$pout" '' 'a11y-audit'
done

# ---- version selection ------------------------------------------------------
# The hint path must name the NEWEST cached release. 0.10.0 > 0.9.0 only under a
# version-aware sort; a plain lexical sort inverts it.
vpr="$TMP/versioned/skill-router/0.10.0"
vcwd="$TMP/vsel"; mkdir -p "$vcwd"
out=$(route "$vpr" "$vcwd" "$vcwd/app.tsx")
expect "versioned: newest cached release wins (0.10.0 over 0.9.0)" "$out" '/vlpresent/0.10.0/skills/' ''

# ---- a plugin whose name merely STARTS like a version stays flat -------------
# `2fa-helper` must not be mistaken for a version segment.
oddmp="$TMP/odd"; mkdir -p "$oddmp/2fa-helper/hooks"
cp "$SRC"/hooks/*.sh "$oddmp/2fa-helper/hooks/"
write_rules "$oddmp/2fa-helper/rules.tsv"
mkdir -p "$oddmp/vlpresent/skills/vl-present-canary"
echo '# canary' > "$oddmp/vlpresent/skills/vl-present-canary/SKILL.md"
oddcwd="$TMP/oddcwd"; mkdir -p "$oddcwd"
out=$(route "$oddmp/2fa-helper" "$oddcwd" "$oddcwd/app.tsx")
expect "version-prefixed plugin NAME is treated as flat" "$out" 'vl-present-canary' ''

# ---- fail-open: the resolver library missing must not silence the router ----
# An install that somehow ships route.sh without plugins-dir.sh falls back to
# fire-if-uncertain, the bias the router declares — never to silence.
nolib="$TMP/nolib"; mkdir -p "$nolib/skill-router/hooks"
cp "$SRC/hooks/route.sh" "$nolib/skill-router/hooks/"
write_rules "$nolib/skill-router/rules.tsv"
nlcwd="$TMP/nolibcwd"; mkdir -p "$nlcwd"
out=$(route "$nolib/skill-router" "$nlcwd" "$nlcwd/app.tsx")
expect "missing plugins-dir.sh fires anyway (fail-open, both rows)" "$out" 'vl-absent-canary' ''

# ---- unset CLAUDE_PLUGIN_ROOT -----------------------------------------------
# No root at all is the original fire-if-uncertain path and must be unchanged.
ucwd="$TMP/unset"; mkdir -p "$ucwd"
out=$(printf '{"hook_event_name":"PostToolUse","tool_name":"Write","session_id":"u1","cwd":"%s","tool_input":{"file_path":"%s","content":"x"}}' \
  "$ucwd" "$ucwd/app.tsx" | env -u CLAUDE_PLUGIN_ROOT bash "$TMP/flat/skill-router/hooks/route.sh" 2>/dev/null || true)
expect "unset CLAUDE_PLUGIN_ROOT stays silent (no rules.tsv to read)" "$out" '' 'vl-present-canary'

if [ "$rc" -eq 0 ]; then echo "versioned-layout-tests: all assertions passed"; fi
exit "$rc"
