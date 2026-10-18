#!/usr/bin/env bash
# Fixture tests for scripts/sync-plan.sh — the scope arithmetic behind
# `/stack-scan:suggest --sync`. Picked up by the shared CI step globbing
# plugins/*/scripts/__tests__/*.test.sh.
#
# Every case builds its own user config dir (CLAUDE_CONFIG_DIR) and project root from
# literal settings files, so the precedence under test is the one the case states, not
# whatever the developer's own ~/.claude holds. The script runs no `claude`, so no shim.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SYNC="$ROOT/scripts/sync-plan.sh"
[ -f "$SYNC" ] || { echo "FAIL: sync-plan.sh not found at $SYNC"; exit 2; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n      %s\n' "$1" "$2"; rc=1; }

CAT="$TMP/catalog.md"
{ printf '# Marketplace plugin catalog\n\n'
  for n in stack-scan code-review laravel candor taskmaster all-plugins; do
    printf '%s — [tooling] — %s description\n' "$n" "$n"
  done; } > "$CAT"

M=cc-plugins-marketplace
# fresh <case>: empty user config dir + project root; sets CFG and PROJ
fresh() { CFG="$TMP/$1/cfg"; PROJ="$TMP/$1/proj"; mkdir -p "$CFG" "$PROJ/.claude"; }
# enable <file> name=bool ... — writes an enabledPlugins map for this marketplace
enable() {
  local f="$1"; shift
  local obj='{}' kv
  for kv in "$@"; do obj=$(jq -c --arg k "${kv%%=*}@$M" --argjson v "${kv#*=}" '. + {($k): $v}' <<<"$obj"); done
  jq -n --argjson e "$obj" '{enabledPlugins: $e}' > "$f"
}
U() { enable "$CFG/settings.json" "$@"; }
P() { enable "$PROJ/.claude/settings.json" "$@"; }
L() { enable "$PROJ/.claude/settings.local.json" "$@"; }
plan() { CLAUDE_CONFIG_DIR="$CFG" bash "$SYNC" --root "$PROJ" --catalog "$CAT" "$@"; }

# has <label> <output> <row> — the exact TSV row is present
has() { if printf '%s\n' "$2" | grep -qxF -- "$3"; then pass "$1"; else fail "$1" "missing row: $3 | got: $(printf '%s' "$2" | tr '\n' '|')"; fi; }
lacks() { if printf '%s\n' "$2" | grep -q -- "$3"; then fail "$1" "unexpected match '$3' | got: $(printf '%s' "$2" | tr '\n' '|')"; else pass "$1"; fi; }
T=$'\t'
inst() { printf 'claude plugin install %s@%s --scope %s' "$1" "$M" "$2"; }
unin() { printf 'claude plugin uninstall %s@%s --scope %s' "$1" "$M" "$2"; }

# ---- 1. nothing enabled: recommended → add at local; stack-scan always joins --------------
fresh c1
out=$(plan code-review)
has "add at local for a recommended plugin enabled nowhere" "$out" "add${T}code-review${T}local${T}$(inst code-review local)"
has "stack-scan joins the set without being named" "$out" "add${T}stack-scan${T}local${T}$(inst stack-scan local)"
lacks "no offramp while user scope enables nothing" "$out" "^offramp"

# ---- 2. --persist targets project ---------------------------------------------------------
out=$(plan --persist code-review)
has "--persist installs at project scope" "$out" "add${T}code-review${T}project${T}$(inst code-review project)"

# ---- 3. user-scope only → move, and the offramp counts user-enabled plugins ---------------
fresh c3; U code-review=true laravel=true candor=false
out=$(plan code-review)
has "recommended + user-only → move to local" "$out" "move${T}code-review${T}local${T}$(inst code-review local)"
has "unrecommended + user-only → machine-wide, no command" "$out" "machine-wide${T}laravel${T}user${T}-"
has "offramp names the count of user-scope trues and the all-plugins removal" "$out" \
  "offramp${T}2${T}user${T}bash \"$CFG/plugins/marketplaces/$M/plugins/all-plugins/scripts/all-plugins.sh\" uninstall --scope user --self"

# ---- 4. a false in a nearer file holds the plugin, whatever the user scope says -----------
fresh c4; U code-review=true candor=false; L code-review=false
out=$(plan code-review candor)
has "local false beats user true → held at local" "$out" "held${T}code-review${T}local${T}-"
has "user-scope false on a recommended plugin → held at user" "$out" "held${T}candor${T}user${T}-"
lacks "a held plugin is never offered for install" "$out" "install code-review"

# ---- 5. project false beats user true; local true beats project false ---------------------
fresh c5; U code-review=true laravel=true; P code-review=false laravel=false; L laravel=true
out=$(plan code-review)
has "project false beats user true → held at project" "$out" "held${T}code-review${T}project${T}-"
has "local true beats project false → effective, unrecommended → extra at local" "$out" "extra${T}laravel${T}local${T}$(unin laravel local)"

# ---- 6. already covered at local or project → ok ------------------------------------------
fresh c6; P code-review=true; L stack-scan=true
out=$(plan code-review)
has "project-scope entry covers a local target" "$out" "ok${T}code-review${T}project${T}-"
has "local entry covers a local target" "$out" "ok${T}stack-scan${T}local${T}-"
lacks "nothing to add when everything is covered" "$out" "^add"

# ---- 7. --persist promotes a local-only entry and flags the local copy --------------------
out=$(plan --persist code-review)
has "--persist: local-only recommended → add at project" "$out" "add${T}stack-scan${T}project${T}$(inst stack-scan project)"
has "--persist: the local copy becomes a duplicate" "$out" "duplicate${T}stack-scan${T}local${T}$(unin stack-scan local)"

# ---- 8. both local and project → ok + duplicate, recommended or not -----------------------
fresh c8; P code-review=true taskmaster=true; L code-review=true taskmaster=true
out=$(plan code-review)
has "recommended in both files → ok at project" "$out" "ok${T}code-review${T}project${T}-"
has "recommended in both files → local copy is a duplicate" "$out" "duplicate${T}code-review${T}local${T}$(unin code-review local)"
has "unrecommended in both files → local copy is a duplicate, not an extra" "$out" "duplicate${T}taskmaster${T}local${T}$(unin taskmaster local)"
has "unrecommended project entry, local target → extra with no command (the team's file)" "$out" "extra${T}taskmaster${T}project${T}-"

# ---- 9. project-scope extra gets its command only under --persist -------------------------
out=$(plan --persist code-review)
has "--persist: project-scope extra → uninstall at project" "$out" "extra${T}taskmaster${T}project${T}$(unin taskmaster project)"

# ---- 10. foreign marketplaces and non-boolean values are ignored; unknown names flagged ---
fresh c10
jq -n --arg m "$M" '{enabledPlugins: {"playwright@anthropic-plugin-directory": true, ("laravel@" + $m): "yes", ("gone@" + $m): true}}' > "$PROJ/.claude/settings.local.json"
out=$(plan code-review)
lacks "another marketplace's plugin never appears" "$out" "playwright"
lacks "a non-boolean value is not an enable" "$out" "laravel"
has "an enabled plugin missing from the catalog → unknown" "$out" "unknown${T}gone${T}local${T}-"

# ---- 11. rows are sorted by class, then name ----------------------------------------------
fresh c11; U candor=true; L taskmaster=true
classes=$(plan code-review laravel | cut -f1 | tr '\n' ' ')
if [ "$classes" = "add add add extra machine-wide offramp " ]; then pass "rows sort add → move → … → offramp"
else fail "rows sort add → move → … → offramp" "got: $classes"; fi

# ---- 12. linked worktree under a local target gets the note; --persist does not -----------
if command -v git >/dev/null 2>&1; then
  fresh c12; G="$TMP/c12/repo"
  git init -q "$G" && git -C "$G" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init \
    && git -C "$G" worktree add -q "$TMP/c12/wt" -b wt 2>/dev/null
  out=$(CLAUDE_CONFIG_DIR="$CFG" bash "$SYNC" --root "$TMP/c12/wt" --catalog "$CAT" code-review)
  has "linked worktree + local target → worktree note" "$out" "note${T}worktree${T}local${T}-"
  out=$(CLAUDE_CONFIG_DIR="$CFG" bash "$SYNC" --root "$G" --catalog "$CAT" code-review)
  lacks "the main checkout gets no worktree note" "$out" "^note"
  out=$(CLAUDE_CONFIG_DIR="$CFG" bash "$SYNC" --persist --root "$TMP/c12/wt" --catalog "$CAT" code-review)
  lacks "--persist in a worktree gets no note" "$out" "^note"
else
  echo "SKIP  worktree cases: git not on PATH"
fi

# ---- 13. refusals: exit 2, nothing on stdout ----------------------------------------------
refuses() { # label expected-stderr-fragment cmd...
  local label="$1" frag="$2"; shift 2
  local o e c
  o=$("$@" 2>"$TMP/err"); c=$?; e=$(cat "$TMP/err")
  if [ "$c" -eq 2 ] && [ -z "$o" ] && printf '%s' "$e" | grep -qF -- "$frag"; then pass "$label"
  else fail "$label" "exit $c, stdout '$o', stderr '$e'"; fi
}
fresh c13; printf '{"enabledPlugins": {' > "$PROJ/.claude/settings.json"
refuses "invalid JSON in a settings file → exit 2 naming it" "$PROJ/.claude/settings.json" plan code-review
fresh c13b; printf '[]' > "$CFG/settings.json"
refuses "a settings file that is not an object → exit 2" "not a JSON object" plan code-review
fresh c13c
refuses "a recommended name missing from the catalog → exit 2" "'nope' is not a plugin" plan code-review nope
refuses "an unknown flag → exit 2" "unknown flag" plan --global code-review
refuses "a missing root → exit 2" "no such project root" env CLAUDE_CONFIG_DIR="$CFG" bash "$SYNC" --root "$TMP/absent" --catalog "$CAT"

# ---- 14. no .claude dir at all is a valid, bare project -----------------------------------
mkdir -p "$TMP/c14/proj" "$TMP/c14/cfg"
out=$(CLAUDE_CONFIG_DIR="$TMP/c14/cfg" bash "$SYNC" --root "$TMP/c14/proj" --catalog "$CAT" laravel); c=$?
if [ "$c" -eq 0 ]; then pass "a project with no .claude dir exits 0"; else fail "a project with no .claude dir exits 0" "exit $c"; fi
has "…and plans the recommended set as adds" "$out" "add${T}laravel${T}local${T}$(inst laravel local)"

# ---- 15. the default catalog is this plugin's generated one -------------------------------
mkdir -p "$TMP/c15/proj" "$TMP/c15/cfg"
out=$(CLAUDE_CONFIG_DIR="$TMP/c15/cfg" bash "$SYNC" --root "$TMP/c15/proj" code-review); c=$?
if [ "$c" -eq 0 ] && printf '%s' "$out" | grep -q "^add${T}code-review${T}"; then pass "default --catalog resolves to references/catalog.md"
else fail "default --catalog resolves to references/catalog.md" "exit $c, got: $out"; fi

exit "$rc"
