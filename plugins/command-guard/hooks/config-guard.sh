#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
#
# PreToolUse guard on the agent's OWN guardrails. Returns `ask` — never a bare deny —
# on a write that would weaken the configuration deciding what the agent may do:
#
#   settings           .claude/settings.json, settings.local.json, ~/.claude/settings.json
#   hooks              any hooks.json, any plugins/*/hooks/*.sh
#   plugin manifests   .claude-plugin/plugin.json, marketplace.json
#   lint/test config   .eslintrc*, eslint.config.*, .rubocop.yml, ruff.toml, pyproject.toml,
#                      phpstan.neon[.dist], psalm.xml[.dist], .php-cs-fixer[.dist].php,
#                      tsconfig.json, .golangci.y[a]ml, pytest.ini, setup.cfg, .flake8,
#                      biome.json, clippy.toml
#
# The list above is the `case` below, spelled out: the two must be read together, because
# a file named here and absent there is a promise nothing keeps. pyproject.toml was in
# the code and missing from this list for its first four releases.
#
# WHY. Given a gate it cannot satisfy, the cheapest path out is to edit the gate — turn
# off the rule, lower `strict`, add the file to an ignore list, delete the hook. It is
# not malice, it is gradient descent, and it is invisible in a diff summary that reads
# "updated config". Prose cannot reach it: the model is not violating an instruction it
# remembers, it is solving the problem in front of it. A guard that fires at the moment
# of the write is the only thing that turns the move into a decision the user makes.
# (`karanb192/claude-code-hooks`'s `config-guard` is prior art and cites CVE-2026-25725;
# this one is narrower — ask, not deny — because a legitimate config edit is common.)
#
# WHY `ask` AND NOT `deny`. Editing these files is often exactly the task ("add a
# permission", "wire a hook", "bump the plugin version"). A deny would be wrong most of
# the time it fired. An ask costs one keystroke on a legitimate edit and is the whole
# mechanism on an illegitimate one, because the illegitimate case is precisely the one
# the user would not have approved had they been asked.
#
# BASH WRITES (0.7.3). On Bash the guard reads the command's write targets through
# cc_bash_write_targets (the block below): a `>`/`>>` redirect, `tee`, `sed -i`, `perl -i`.
# At most 8 targets per call; a relative one resolves against the payload cwd, and the
# first that classifies AND exists gets the same ask as a Write; a `~/` target expands to
# $HOME. NOT caught on Bash: interpreter writes (python open(), php file_put_contents),
# cp/mv/install destinations, `{ …; } > f` groups, a path held in a variable, a globbed
# target, a dot-named config right after a bare `sed -i` with another file after it (read
# as BSD's backup suffix), sed/perl behind another command word (`gsed`, `/usr/bin/sed`,
# `env`, `xargs`, `command`, `find … -exec sed -i`), a digit- or `&`-led redirect onto a
# config (`2> tsconfig.json`, `&> .eslintrc.json`) and `>&` onto one (`cmd >& tsconfig.json`),
# a `\` continuation, a relative target after an in-command `cd` (it resolves against the
# payload cwd), the 9th target on, and `rm` of a config or hook — a deletion, which stays
# destructive-guard.sh's.
# Both hooks now run on Bash, and each emits its own verdict.
#
# WHAT IT DOES NOT CATCH, stated because the README tiers this:
#   - A weakening in a file this list does not name. The list is literal, not clever.
#   - Any judgment about WHETHER the edit weakens anything: it does not parse the file,
#     it asks about the path. Adding a rule and deleting one look identical here.
#     That half is agent-graded and the ask text says so.
#   - The first write that CREATES one of these files (there is nothing to weaken yet),
#     which is why a missing target is allowed through.
#
# Off with CC_CONFIG_GUARD=off. Fail-open on every error path.
# CC_CONFIG_GUARD / CLAUDE_DESTRUCTIVE_GUARD unset: their /config options (lower-cased) decide.

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# A non-empty variable beats the option: the environment is shared, so one export before launch
# switches every plugin that reads it.
# Misses: a malformed name, which yields <default>; a variable passed instead of a literal name; a value outside the vocabulary.
cc_option() {
  local v="" opt
  case "${1:-}" in '' | [0-9]* | *[!A-Za-z0-9_]*) printf '%s\n' "${2:-}"; return 0 ;; esac
  v="${!1:-}"
  if [ -z "$v" ] && [ -n "${3:-}" ] && [ -f "$3" ] && [ -r "$3" ]; then
    read -r v _ 2>/dev/null < "$3" || :
  fi
  if [ -z "$v" ]; then
    opt="CLAUDE_PLUGIN_OPTION_$1"; v="${!opt:-}"
    case "$v" in true) v=on ;; false) v=off ;; esac
  fi
  [ -n "$v" ] || v="${2:-}"
  printf '%s\n' "$v"
  return 0
}

# Shared block templates/blocks/bash-write-targets.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/bash-write-targets.md
# cc_bash_write_targets <command> prints each path the command writes through `>`/`>>`, `[sudo] tee` or `sed -i`/`perl -i`,
# one per line as spelled; heredoc bodies and quoted text never match. A path guard keeps existing files under its root.
# BSD sed's -I always takes the next word as its backup suffix, so that word is never a target; after a bare sed -i,
# a `''` or `.`-led word is read as one too, unless it would be the only file.
# Misses: interpreter writes, cp/mv/install, a path in a variable, a glob, a `\` line continuation, a digit- or &-led
# redirect and `>&`, sed/perl/tee behind another command word (gsed, /usr/bin/sed, env, xargs, sudo -u), a `-`-led
# operand with no `/` or `.`, operands cut short by a `&` inside `$(( ))`/`${ }`, every line after a `<<\EOF` opener.
cc_bash_write_targets() {
  printf '%s\n' "$1" | awk '
    function emit(p) {
      gsub(/^["\047]|["\047]$/, "", p)
      if (p == "" || p ~ /^\/dev\// || p ~ /[$`*?]/ || p ~ /^[&0-9-]/ && p !~ /[\/.]/) return
      print p
    }
    function mask(s,   i, c, q, out, esc) {
      q = ""; out = ""; esc = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (esc) { out = out "_"; esc = 0; continue }
        if (q == "") {
          if (c == "\\") { esc = 1; out = out "_"; continue }
          if (c == "\047" || c == "\"") q = c
          out = out c
        } else if (c == q) { q = ""; out = out c }
        else { if (q == "\"" && c == "\\") esc = 1; out = out "_" }
      }
      return out
    }
    function segment(ms, os,   rest, off, tok, w, k, j, st, en, word, n, ws, we, x, c, a, inp, scr, eo, sfx, nf, f) {
      rest = ms; off = 0
      while (match(rest, /(^|[^0-9&=<>-])>>?[ \t]*("[^"]*"|\047[^\047]*\047|[^ \t&|;<>()"\047]+)/)) {
        tok = substr(os, off + RSTART, RLENGTH)
        off += RSTART + RLENGTH - 1; rest = substr(ms, off + 1)
        sub(/^[^>]*>>?[ \t]*/, "", tok)
        emit(tok)
      }
      n = 0; j = 1
      while (j <= length(ms)) {
        while (j <= length(ms) && substr(ms, j, 1) ~ /[ \t]/) j++
        if (j > length(ms)) break
        st = j; while (j <= length(ms) && substr(ms, j, 1) !~ /[ \t]/) j++
        n++; ws[n] = st; we[n] = j - 1
      }
      if (n == 0) return
      k = 1; word = substr(os, ws[1], we[1] - ws[1] + 1)
      if (word == "sudo" && n > 1) { k = 2; word = substr(os, ws[2], we[2] - ws[2] + 1) }
      if (word == "tee") {
        for (k = k + 1; k <= n; k++) {
          w = substr(os, ws[k], we[k] - ws[k] + 1)
          if (w == "<" || w == "<<<") { k++; continue }
          if (w !~ /^-/ && w !~ /^[<>0-9]/) emit(w)
        }
      } else if (word == "sed" || word == "perl") {
        inp = 0; scr = 0; eo = 0; sfx = ""; nf = 0
        for (k = k + 1; k <= n; k++) {
          w = substr(os, ws[k], we[k] - ws[k] + 1); x = substr(ms, ws[k], we[k] - ws[k] + 1)
          if (x ~ /[<>]/) {
            a = substr(w, 1, match(x, /[<>]/) - 1)
            if (a !~ /^[0-9&]*$/) f[++nf] = a
            if (x ~ /[<>][&|]?$/) k++
            continue
          }
          if (eo || x !~ /^-./) { f[++nf] = w; if (word == "perl") eo = 1; continue }
          if (x == "--") { eo = 1; continue }
          if (x ~ /^--/) {
            if (word == "sed" && x ~ /^--in-place(=|$)/) inp = 1
            if (word == "sed" && x ~ /^--(expression|file)(=|$)/) { scr = 1; if (x !~ /=/) k++ }
            continue
          }
          for (j = 2; j <= length(x); j++) {
            c = substr(x, j, 1)
            if (c == "i" || word == "sed" && c == "I") {
              inp = 1
              if (word == "sed" && j == length(x) && k < n) {
                a = substr(os, ws[k + 1], we[k + 1] - ws[k + 1] + 1); gsub(/^["\047]|["\047]$/, "", a)
                if (c == "I") k++
                else if (a == "" || a ~ /^\.[^\/<>]*$/) { k++; sfx = a }
              }
              break
            }
            if (c == "e" || c == (word == "sed" ? "f" : "E")) { scr = 1; if (j == length(x)) k++; break }
            if (c == (word == "sed" ? "l" : "I")) { if (j == length(x)) k++; break }
            if (word == "perl" && c ~ /[MmFxdDVC]/) break
            if (word == "perl" && c ~ /[l0]/) while (substr(x, j + 1, 1) ~ /[0-7]/) j++
          }
        }
        if (!inp) return
        for (j = scr ? 1 : 2; j <= nf; j++) if (f[j] !~ /^-/ || eo) { emit(f[j]); sfx = "" }
        if (sfx != "") emit(sfx)
      }
    }
    skip { t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t); if (t == term) skip = 0; next }
    {
      line = $0; m = mask(line)
      if (match(m, /(^|[^<])<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*/)) {
        if (substr(m, RSTART, 1) != "<") { RSTART++; RLENGTH-- }
        term = substr(line, RSTART, RLENGTH + 1)
        sub(/^<<-?[ \t]*["\047]?/, "", term); sub(/[^A-Za-z0-9_].*$/, "", term)
        skip = 1
      }
      st = 1
      for (i = 1; i <= length(m) + 1; i++) {
        c = substr(m, i, 1); c2 = substr(m, i, 2)
        if (i > length(m) || c == ";" || c == "|" || c == "&" && c2 != "&>" && substr(m, i - 1, 1) !~ /[<>]/) {
          if (i > st) segment(substr(m, st, i - st), substr(line, st, i - st))
          if (c2 == "&&" || c2 == "||" || c2 == "|&") i++
          st = i + 1
        }
      }
    }' | awk '!seen[$0]++'
}

config_kind() {
  local b
  b=$(basename "$1")
  case "/$1" in
    */.claude/settings.json|*/.claude/settings.local.json|*/.claude/settings.*.json) echo "the settings file that decides which tools and permissions this session has"; return ;;
    */.claude/hooks/*|*/hooks/hooks.json)                                            echo "a hooks configuration — the file that decides which guards run at all"; return ;;
  esac
  case "$b" in
    hooks.json)            echo "a hooks configuration — the file that decides which guards run at all"; return ;;
    plugin.json|marketplace.json)
                           echo "a plugin manifest — it declares the hooks, matchers and dependencies an install gets"; return ;;
    .eslintrc|.eslintrc.*|eslint.config.*|biome.json|.rubocop.yml|ruff.toml|.flake8|setup.cfg|pytest.ini|pyproject.toml|phpstan.neon|phpstan.neon.dist|psalm.xml|psalm.xml.dist|.php-cs-fixer.php|.php-cs-fixer.dist.php|.golangci.yml|.golangci.yaml|clippy.toml|tsconfig.json)
                           echo "a lint, type-check or test configuration — the rules a build fails on"; return ;;
  esac
  # A hook SCRIPT, not just its manifest.
  case "/$1" in
    */hooks/*.sh|*/hooks/*.py|*/hooks/*.mjs|*/hooks/*.js) echo "a hook script — the code a guard runs" ;;
  esac
}

{
  [ "$(cc_option CC_CONFIG_GUARD on)" = "off" ] && exit 0
  # HONOUR THE SIBLING'S SWITCH. The core-suite README (the suites were retired
  # 2026-09-26) told an installer that
  # CLAUDE_DESTRUCTIVE_GUARD=deny-only buys "the free half" — no clicks — but this
  # guard is the plugin's OTHER ask tier and read only its own variable, so the
  # documented setting did not deliver what it promised. Both values that mean
  # "no ask tier" now silence this hook too. Measured 2026-09-15.
  case "$(printf '%s' "$(cc_option CLAUDE_DESTRUCTIVE_GUARD deny)" | tr '[:upper:]' '[:lower:]')" in
    off | deny-only) exit 0 ;;
  esac
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit) ;;
    *apply_patch|*create_new_file) ;;
    Bash) ;;
    *) exit 0 ;;
  esac

  if [ "$tool" = Bash ]; then
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
    targets=$(cc_bash_write_targets "$cmd" | head -n 8)
    [ -n "$targets" ] || exit 0
    cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
    file=""
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      # Without a cwd a relative target would resolve against `/`.
      case "$p" in
        /*) ;;
        "~/"*) [ -n "${HOME:-}" ] || continue; p="$HOME/${p#??}" ;;
        *) [ -n "$cwd" ] || continue; p="$cwd/$p" ;;
      esac
      kind=$(config_kind "$p")
      [ -n "$kind" ] && [ -f "$p" ] && { file=$p; break; }
    done <<EOF_T
$targets
EOF_T
    [ -n "$file" ] || exit 0
    base=$(basename "$file")
  else
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.pathInProject // empty' 2>/dev/null)
    [ -n "$file" ] || exit 0
    base=$(basename "$file")
    kind=$(config_kind "$file")
    [ -n "$kind" ] || exit 0

    # Nothing to weaken if it does not exist yet: creating a config is not relaxing one.
    # (A brand-new hooks.json is how a guard gets INSTALLED.)
    [ -f "$file" ] || exit 0
  fi

  # Self-exemption: this marketplace's own repository edits these files as its product.
  # Keyed on the marketplace manifest at the repo root, not on a plugin name, so a
  # consumer repo that happens to vendor a plugin is still guarded.
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  if [ -n "$cwd" ]; then
    root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root="$cwd"
    [ -f "$root/.claude-plugin/marketplace.json" ] && exit 0
  fi

  reason="command-guard: this writes to $kind (\`$base\`). Editing it is often the task — and it is also the cheapest way past a gate that just refused something, which is why you are being asked rather than told. Confirm you intend a configuration change here, not a way around a check. If a rule is wrong, say so in the change; if a check is in the way, the check is the thing to argue with. This guard reads the PATH, not the diff: it cannot tell adding a rule from deleting one. CC_CONFIG_GUARD=off disables it for the session; so does CLAUDE_DESTRUCTIVE_GUARD=deny-only."

  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
