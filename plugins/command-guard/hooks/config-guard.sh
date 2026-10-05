#!/bin/bash
# config-guard.sh (PreToolUse on file writes and Bash; payload on stdin) — asks, never denies, before a write to an existing settings, hooks,
#   hook-script, plugin-manifest or lint/test config file (config_kind); on Bash, the first such target of the first eight. Silent in a marketplace repository.
# Off: CC_CONFIG_GUARD=off, or CLAUDE_DESTRUCTIVE_GUARD=off or deny-only (this hook is the plugin's other ask tier). Fails open on every error path.
# CC_CONFIG_GUARD / CLAUDE_DESTRUCTIVE_GUARD unset: the /config options cc_config_guard / claude_destructive_guard decide.
# Misses: a file config_kind does not name; whether an edit weakens anything (it reads the path, not the diff); a file that does not exist yet;
#   an MCP apply_patch (no single path); on Bash, writes the bash-write-targets block below does not report, targets past the eighth, a relative
#   target after an in-command cd (resolved against the payload cwd instead), and `rm` of a config (destructive-guard judges only `rm -r` and `.env`, so a plain `rm` passes both).
# Why, limits, history: rationale/derivations/plugin-command-guard.md § plugins/command-guard/hooks/config-guard.sh

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
  case "/$1" in
    */hooks/*.sh|*/hooks/*.py|*/hooks/*.mjs|*/hooks/*.js) echo "a hook script — the code a guard runs" ;;
  esac
}

MAX_BASH_TARGETS=8

{
  [ "$(cc_option CC_CONFIG_GUARD on)" = "off" ] && exit 0
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
    targets=$(cc_bash_write_targets "$cmd" | head -n "$MAX_BASH_TARGETS")
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
    [ -f "$file" ] || exit 0
  fi

  # Exempt: a marketplace repository (manifest at its git root) edits these files as its product.
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
