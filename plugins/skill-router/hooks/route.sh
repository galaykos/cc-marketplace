#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH, where `env bash` itself exits 127.
# PostToolUse router. Given the edited file, match rules.tsv and inject one
# directive to load the relevant skill — every `high` row fires inline once per
# signal per session (a `glob` row on the path, a `content` row on the file's
# contents, a `command` row on a Bash command string); `low` content matches
# accumulate into the session-state digest. All inline nudges for one edit are delivered as
# a SINGLE {"hookSpecificOutput":{"hookEventName":"PostToolUse",
# "additionalContext":...}} envelope — the one non-blocking channel the
# executing model actually receives; plain stdout with exit 0 never reaches it
# (same channel doctrine as task-runner/hooks/scope.sh and
# comment-discipline/hooks/scan.sh). Fail-open: any error, or a
# missing jq, exits silently and never blocks the edit.
#
# BASH WRITES ROUTE TOO (0.20.0) — the matcher carries `Bash`. Measured 2026-09-25
# (rationale/2026-09-25-session-plugin-usage-review.md, finding 1): with the host's
# `bashFirst` steering, one session wrote 233 of 238 main-thread files through
# `cat > f <<EOF`, and this hook, matched on Edit|Write only, routed ONE edit across
# ~40 items of auth, token and HTTP-client work — the "Signals from recent edits"
# digest fired zero times there. A Bash payload is now routed exactly as if each
# target the command names had been Edited: `cc_bash_write_targets` (shared block
# below) lists them, the first 8 are examined, and only one that is an EXISTING
# REGULAR FILE UNDER THE PROJECT ROOT routes — a `>` into /tmp, into a log outside the
# repo, or onto a path the command then deleted routes nothing. Same one-shot, same
# single envelope per call, however many files one command wrote.
# COST, because this now runs after EVERY Bash call: a call with no write target and no
# `command` row match exits after two jq reads, at most one awk, one grep selecting
# rules.tsv's `command` rows and one `grep -E` per such row — before plugins-dir.sh or
# any state is touched. The `case` prefilter drops `git status` before awk even starts.
# Only a raw `command` row hit pays one more awk (route_cmd_mask) and a second grep.
#
# COMMAND ROWS (routing review 2026-09-26, S8): a CLI that writes its own files —
# `npx shadcn@latest add @magicui/marquee` — names no redirect target, so no file row
# could ever see it; the installed component routed only on its first LATER edit. A
# `command` row matches its ERE against the Bash command string and fires inline, once
# per signal per context, like a `high` glob row. `high` only: a `low` command row is
# ignored (there is no file to list in the digest). The ERE runs against the command with
# single- and double-quoted text masked and heredoc bodies blanked (route_cmd_mask), so a
# commit message, a grep pattern, an echoed string or a heredoc writing a doc that MENTIONS
# the command neither routes nor spends the one-shot; `$(…)` inside double quotes is live
# code and still routes. LIMITATION: an unquoted mention (`echo run shadcn add`, `\"`
# escapes) still routes; a quoted CLI name (`npx "shadcn" add`) is masked and does not;
# backtick substitution inside double quotes is masked; a CLI invoked through a script or
# an npm `scripts` alias names nothing the row can see. `@base`/`@path` markers see an
# empty string on a command row.
# NOT CAUGHT (the block's own list): interpreter writes (python open(), php
# file_put_contents), cp/mv/install destinations, `{ …; } > f` groups, a path held in a
# variable. The
# dynamic budget probe (scripts/context-budget.sh) sends Edit payloads only, so a Bash
# call's output is unmetered there; per target it is the text an Edit of that file gets.
#
# Honest limitation: state writes are read-modify-write with no lock — two
# concurrent invocations in one session can drop a pending_low entry (tool
# calls are serialized in practice; not worth a lock).
# --- state root ----------------------------------------------------------------
# Canonical copy: templates/blocks/state-root.md. Every hook defining cc_state_root must
# carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
# The payload's `cwd` is the SHELL's cwd and follows the model's `cd` — measured
# 2026-09-25: app/Enums, then app/Models, then the repo root in one session, each leaving
# its own `.claude/` state dir and each re-firing a "once per session" nudge. State lives
# at the project root instead (pc_state_root refuses a raw `$cwd/.claude` path in a hook):
# the git toplevel reached by walking UP from cwd (`--show-cdup`, so a symlinked /tmp keeps
# the caller's spelling and path-prefix comparisons still hold); outside git,
# CLAUDE_PROJECT_DIR when cwd sits under it; else cwd. A cwd that no longer exists yields
# nothing and status 1 — the caller exits rather than resurrect a deleted project.
cc_state_root() {
  [ -n "$1" ] && [ -d "$1" ] || return 1
  local up pd="${CLAUDE_PROJECT_DIR:-}"; pd="${pd%/}"
  if up=$(git -C "$1" rev-parse --show-cdup 2>/dev/null); then
    [ -n "$up" ] || { printf '%s\n' "$1"; return 0; }
    (CDPATH= cd -- "$1/$up" 2>/dev/null && pwd) && return 0
  fi
  if [ -n "$pd" ] && [ -d "$pd" ]; then
    case "$1/" in "$pd"/*) printf '%s\n' "$pd"; return 0 ;; esac
  fi
  printf '%s\n' "$1"
}
# --- bash write targets --------------------------------------------------------
# Canonical copy: templates/blocks/bash-write-targets.md. Every hook defining
# cc_bash_write_targets must carry this block byte-for-byte (pc_shared_blocks).
# The host steers file writes through Bash (auto mode `bashFirst`); in one measured session
# 233 of 238 main-thread writes were `cat > file <<EOF`, invisible to a hook matching
# Write|Edit.
# Prints one target path per line, as spelled in the command (relative or absolute).
# Heredoc BODIES are dropped and quoted text is masked before matching, so PHP `->`/`=>`,
# HTML `>` and a sed script's `s|a|b|` never read as redirects or pipes; a here-string
# (`<<<`) is not a heredoc. Catches `>`/`>>` onto a path (cat, echo, printf, any command),
# `[sudo] tee [-a] <paths>`, and the last operand of `sed -i` / `perl -i`. Does NOT catch:
# interpreter writes (python open(), php file_put_contents), cp/mv/install destinations,
# `{ …; } > f` groups, a path held in a variable (`> "$f"` is skipped, never guessed).
# The caller filters to existing files under its root.
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
    function segment(ms, os,   rest, off, tok, w, k, j, st, en, word, n, ws, we, last) {
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
      } else if ((word == "sed" || word == "perl") && ms ~ /[ \t]-[a-zA-Z0-9]*i/) {
        last = substr(os, ws[n], we[n] - ws[n] + 1)
        if (n > 2 && last !~ /^-/ && substr(ms, ws[n], 1) !~ /["\047]/) emit(last)
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
        if (i > length(m) || c == ";" || c == "|" || c2 == "&&") {
          if (i > st) segment(substr(m, st, i - st), substr(line, st, i - st))
          if (c2 == "&&" || c2 == "||") i++
          st = i + 1
        }
      }
    }' | awk '!seen[$0]++'
}
# route_cmd_mask <command> — the command as COMMAND rows see it (header: COMMAND ROWS):
# single- and double-quoted text replaced by `_`, heredoc bodies blanked. A stack of
# U(nquoted)/S/D/C states tracks nesting, so `$(…)` inside double quotes stays live code
# and a heredoc opened there (`git commit -m "$(cat <<'EOF'`) is still recognised.
route_cmd_mask() {
  printf '%s\n' "$1" | awk '
    BEGIN { st = "U"; nq = 0; qh = 1 }
    qh <= nq {
      t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t)
      if (t == hq[qh]) qh++
      print ""; next
    }
    {
      line = $0; out = ""; n = length(line)
      for (i = 1; i <= n; i++) {
        c = substr(line, i, 1); two = substr(line, i, 2); top = substr(st, length(st), 1)
        if (top == "S") {
          if (c == "\047") { st = substr(st, 1, length(st) - 1); out = out c } else out = out "_"
          continue
        }
        if (top == "D") {
          if (c == "\\") { out = out "__"; i++ }
          else if (c == "\"") { st = substr(st, 1, length(st) - 1); out = out c }
          else if (two == "$(") { st = st "C"; out = out two; i++ }
          else out = out "_"
          continue
        }
        if (c == "\\") { out = out "__"; i++; continue }
        if (c == "\047") { st = st "S"; out = out c; continue }
        if (c == "\"") { st = st "D"; out = out c; continue }
        if (top == "C" && c == ")") { st = substr(st, 1, length(st) - 1); out = out c; continue }
        if (two == "$(") { st = st "C"; out = out two; i++; continue }
        if (substr(line, i, 3) == "<<<") { out = out "<<<"; i += 2; continue }
        if (two == "<<" && match(substr(line, i + 2), /^-?[ \t]*["\047\\]?[A-Za-z_][A-Za-z0-9_]*["\047]?/)) {
          w = substr(line, i + 2, RLENGTH); sub(/^-?[ \t]*["\047\\]?/, "", w); sub(/["\047]$/, "", w)
          hq[++nq] = w; out = out substr(line, i, RLENGTH + 2); i += RLENGTH + 1; continue
        }
        out = out c
      }
      print out
    }'
}
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  # OFF SWITCH. `CC_REMIND=off` is the marketplace-wide advisory mute, and eight
  # sibling READMEs promise it silences "every advisory nudge in this marketplace"
  # — a promise this plugin's own README repeated while this hook, its headline
  # advisory channel, never read the variable. route-prompt.sh has honoured it
  # since it shipped; the per-edit nudges did not, so a user who muted the
  # marketplace still got them on every Edit. `CC_ROUTE` is deliberately NOT read
  # here: it names the prompt-level tool-fit check only (route-prompt.sh:26), and
  # widening an existing switch silently is worse than the gap it closes. There is
  # no file-routing-only switch, and the README says so.
  case "${CC_REMIND:-on}" in off) exit 0 ;; esac

  # BASH, no-target exit first (header: COST). The `case` is a superset of every
  # shape the block can return (`>`, tee, sed/perl -i), so it is safe to skip awk on.
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  rules="${CLAUDE_PLUGIN_ROOT}/rules.tsv"
  [ -f "$rules" ] || exit 0
  bash_targets=""; cmd_hits=""
  if [ "$tool" = Bash ]; then
    bash_cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
    [ -n "$bash_cmd" ] || exit 0
    case "$bash_cmd" in
      *'>'*|*tee*|*sed*|*perl*) bash_targets=$(cc_bash_write_targets "$bash_cmd" | head -n 8) ;;
    esac
    # COMMAND rows (header). One `skill<TAB>plugin<TAB>marker<TAB>matched text` line per
    # hit; the installed, marker and one-shot filters run in the high pass below, once
    # the project root is known. An empty marker is spelled `-`: `read` with a tab IFS
    # collapses an empty field and would shift the matched text into its place.
    cmd_masked=""; masked=0
    while IFS=$'\t' read -r stype pattern skill plugin conf marker || [ -n "$stype" ]; do
      [ "${conf%$'\r'}" = high ] || continue
      printf '%s' "$bash_cmd" | grep -qE "$pattern" 2>/dev/null || continue
      [ "$masked" = 1 ] || { cmd_masked=$(route_cmd_mask "$bash_cmd"); masked=1; }
      m=$(printf '%s' "$cmd_masked" | grep -m1 -oE "$pattern" 2>/dev/null) || continue
      m="${m%%$'\n'*}"; marker="${marker%$'\r'}"; [ -n "$marker" ] || marker=-
      cmd_hits="${cmd_hits}${skill}"$'\t'"${plugin}"$'\t'"${marker}"$'\t'"${m}"$'\n'
    done < <(grep "^command"$'\t' "$rules" 2>/dev/null)
    [ -n "$bash_targets" ] || [ -n "$cmd_hits" ] || exit 0
  fi

  # CONTEXT KEY, not session key. PostToolUse is the only hook channel that reaches
  # subagents at all, and a subagent shares its parent's session_id while getting its
  # own transcript. Keying a one-shot on session_id therefore dedups the worker against
  # nudges only the PARENT ever saw, so the context where most fan-out code is written
  # is the one context this never speaks in. Pattern and rationale: code-review/hooks/conventions.sh (context-key one-shot).
  session_id=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null) || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  file_path=""
  if [ "$tool" != Bash ]; then
    # `pathInProject` is the JetBrains-MCP create_new_file key (schema read 2026-09-14);
    # an IDE-driven session writes every file through it and would otherwise route nothing.
    # apply_patch carries no single path, so it stays unrouted — stated, not hidden.
    file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.pathInProject // empty' 2>/dev/null) || exit 0
    [ -n "$file_path" ] || exit 0
  fi
  [ -n "$session_id" ] || exit 0
  [ -n "$cwd" ] || exit 0
  # `-d`, not just `-n`: the state write below is `mkdir -p` under the project root,
  # which RECREATES a project directory the session has deleted — reproduced live three
  # levels deep (2026-09-22 panel, architecture #1). A payload naming a directory that no
  # longer exists has no state worth keeping and no file worth routing. Same guard as
  # plugins/overseer/hooks/track-read.sh:30. LIMITATION: it proves the path EXISTS, not
  # that it is the project — a payload whose cwd is `/` or `$HOME` outside any git repo
  # still passes, and the state dir is created there. Nothing available to a hook can
  # tell those apart.
  [ -d "$cwd" ] || exit 0
  # STATE ROOT (finding 2 of the review named in the header). The payload cwd follows
  # the model's `cd`; state, manifests and the repo-relative path all key on the
  # project root instead, so one session keeps one state file however often it moves.
  root=$(cc_state_root "$cwd") || exit 0

  # TARGETS, as two parallel arrays: the spelling recorded in pending_low, and the file
  # on disk. An Edit is one target, spelled as its payload spelled it (unchanged). A Bash
  # target resolves against the payload `$cwd` (the Bash tool's cwd), is canonicalised
  # through its directory (so `../x` cannot slip out of the root test), and must already
  # exist as a regular file under the root (PostToolUse runs after the command, so a
  # target that is absent now was never written or was removed again). LIMITATION: a `cd`
  # INSIDE the same command (`cd app && cat > f`) moves the base the shell really used;
  # whether the host samples cwd before or after the command is unverified here, so such
  # a relative target may resolve wrong — it then usually fails the existence test and
  # stays silent, and at worst routes a same-named file.
  rec=(); abs=()
  if [ "$tool" = Bash ]; then
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      case "$t" in /*) p="$t" ;; *) p="$cwd/$t" ;; esac
      pd="${p%/*}"; [ -n "$pd" ] || pd=/
      pd=$(CDPATH= cd -- "$pd" 2>/dev/null && pwd) || continue
      p="${pd%/}/${p##*/}"
      [ -f "$p" ] || continue
      case "$p" in "$root"/*) ;; *) continue ;; esac
      rec+=("$p"); abs+=("$p")
    done <<EOF_TARGETS
$bash_targets
EOF_TARGETS
    [ "${#abs[@]}" -gt 0 ] || [ -n "$cmd_hits" ] || exit 0
  else
    p="$cwd/$file_path"
    case "$file_path" in /*) p="$file_path" ;; esac
    rec+=("$file_path"); abs+=("$p")
  fi

  # Sibling plugins directory, for the installed-plugin filter. Resolved by
  # hooks/plugins-dir.sh, which handles both the flat and the versioned-cache
  # layouts — see that file's header for why dirname alone silently disabled this
  # hook on every real install. Empty when it cannot be determined, and empty
  # means fire anyway (bias to surface). A missing lib lands on the same default.
  PLUGINS_DIR=""; PLUGIN_LAYOUT="flat"
  . "$(dirname "$0")/plugins-dir.sh" 2>/dev/null
  command -v pr_resolve_plugins_dir >/dev/null 2>&1 && pr_resolve_plugins_dir

  state_dir="$root/.claude/skill-router"
  # Hashed, not raw: the CONTEXT KEY read above takes `.transcript_path` first and that is
  # an absolute path, so `fired-$session_id.json` names a nested file whose parents are
  # never created. The write fails, `fired` is empty on every call, and the "same skill is
  # not re-nudged on later edits" property (`already_fired`) never holds — every edit
  # re-injects directives the model already has. Same idiom as
  # code-review/hooks/conventions.sh (hashed state key).
  ctx=$(printf '%s' "$session_id" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0
  state_file="$state_dir/fired-$ctx.json"
  fired=""
  [ -r "$state_file" ] && fired=$(jq -r '.fired[]? // empty' "$state_file" 2>/dev/null)

  # set_target <i> — the globals every matcher below reads, for target i.
  # `rel` is the path RELATIVE TO THE PROJECT ROOT when the file sits under it, so a
  # `**/dir/**` row and an `@path` marker see `app/Enums/Status.php` whether the write
  # came from the root, from `cd app/Enums`, or as an absolute path — and a checkout
  # that merely lives under a directory named `tests/` or `app/` no longer matches those
  # rows on every file. A file outside the root keeps the payload's spelling (the
  # pre-0.20.0 behaviour for every file).
  set_target() {
    file_path="${rec[$1]}"; target="${abs[$1]}"
    base=$(basename "$file_path")
    rel="$file_path"
    case "$target" in "$root"/*) rel="${target#"$root"/}" ;; esac
  }

  # A code or style file, the only kind a `content`+`high` row fires inline on (high pass).
  inline_ext() {
    case "$base" in
      *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.vue|*.svelte|*.astro|*.css|*.scss|*.sass|*.less|*.html|*.php|*.twig|*.erb) return 0 ;;
    esac
    return 1
  }

  plugin_installed() { # $1 owning_plugin — fire-if-uncertain
    command -v pr_plugin_installed >/dev/null 2>&1 || return 0
    pr_plugin_installed "$1"
  }
  already_fired() { printf '%s\n' "$fired" | grep -qxF "$1"; }

  match_glob() { # $1 pattern
    # DIRECTORY SEGMENTS MATCH CASE-INSENSITIVELY, on purpose. The same framework
    # directory ships under two casings depending on the scaffolder that made it:
    # Laravel's current Inertia starter kits generate `resources/js/pages/` while
    # the older convention (and rules.tsv) says `Pages`. A case-SENSITIVE test
    # meant `**/resources/js/Pages/**` — inertia's ONLY routing row — fired on
    # zero files in every lowercase project, so the plugin routed nothing there
    # and `/inertia:review` had to be typed by hand. `**/Livewire/**` had the same
    # exposure, masked only because livewire has a second row (`*.blade.php`).
    #
    # LIMITATION: case is checkable, a wrong directory NAME is not. A row naming a
    # directory the framework does not use still matches nothing, and no gate here
    # can see that.
    local pat="$1" rc=1 nocase_was_off=1
    shopt -q nocasematch && nocase_was_off=0
    shopt -s nocasematch
    case "$pat" in
      '**/'*'/**')
        local mid="${pat#**/}"; mid="${mid%/**}"
        case "/$rel" in *"/$mid/"*) rc=0 ;; esac ;;
      *)
        case "$base" in $pat) rc=0 ;; esac ;;
    esac
    [ "$nocase_was_off" -eq 1 ] && shopt -u nocasematch
    return "$rc"
  }

  marker_ok() { # $1 stack_marker — 0 = fire, 1 = suppress. `||`-separated
    # alternatives, each `[!]<manifest>~<ERE>`, tried in order: the FIRST
    # decisive alternative wins — its grep verdict (exit 0 fire / exit 1
    # suppress, after `!` inversion) is final, so an authoritative source
    # (installed node_modules version) listed first overrides a looser declared
    # range behind it. Indecisive alternatives — absent/unreadable manifest,
    # missing `~`, empty side, grep exit >= 2 — are skipped. No decisive
    # alternative at all fires: an undetectable stack keeps today's behavior.
    #
    # `@base` as the manifest name matches the ERE against the edited file's
    # BASENAME instead of a file's content, so a row can exclude a file SHAPE:
    # `!@base~\.config\.` suppresses on `vite.config.js`. Added 0.16.0 because the
    # `*.js`/`*.ts` design-principle rows fired SOLID and cognitive-load nudges on
    # `tailwind.config.js`, `eslint.config.js`, `*.d.ts` and `*.min.js` — files with
    # no classes, no design and nothing to review against those skills — and a
    # bare-extension glob has no way to say "except these". Before 0.16.0 an
    # `@base` alternative was indecisive (no such file) and skipped, so a rules.tsv
    # carrying one is safe under an older route.sh: it simply fires.
    #
    # `@path` is the same device one level up: the ERE runs against the edited
    # file's PATH (`rel`, see set_target), so a row can exclude a
    # DIRECTORY. `!@path~(^|/)dist/` keeps the markup a11y rows off built output —
    # a bundled `dist/index.html` has the same BASENAME as its source, so `@base`
    # cannot tell them apart, and match_glob's one path-aware form (`**/dir/**`)
    # can only say "inside", never "not inside". LIMITATION (honest scope): the
    # value is root-relative only for a file under the project root — outside it,
    # whatever the payload carried — so an exclusion must anchor on `(^|/)`, never
    # on `^` alone, and a build directory under a name nobody listed is still routed. Unknown to an
    # older route.sh, where `@path` is just a manifest that does not exist and the
    # alternative is skipped: the row fires, the same safe fallback as `@base`.
    # `?` PREFIX — `?package.json~"next"` — makes the alternative REQUIRE its manifest:
    # absent or unreadable is then decisive-SUPPRESS instead of skipped, so a chain of
    # `?` alternatives reads "fire only on a manifest that exists and says yes". It is
    # the general form of the `||!@base~.` default-deny tail 0.18.0 bolted onto four
    # rows; those rows now carry `?` instead, so one mechanism expresses it. Per-row and
    # opt-in — an unprefixed alternative keeps the fire-if-uncertain default. Write `?`
    # first when negating too (`?!composer.json~laravel/framework`).
    # LIMITATION: absent/unreadable manifest is the ONLY indecisiveness it converts. A
    # malformed ERE (grep exit >= 2) still skips the alternative, so a row with a broken
    # regex and a present manifest keeps firing; and marker_ok reads `$root/<manifest>`
    # only, so a monorepo whose package.json sits in a workspace subdirectory is "absent"
    # here and a `?` row suppresses there. Until 0.20.0 it read the payload cwd, which
    # followed the model's `cd` (a write after `cd app/Enums` read app/Enums/composer.json)
    # and, as a side effect, served a session STARTED inside a workspace that workspace's
    # manifest; that session now reads the repo root's. Walking up from the file to the
    # nearest manifest was rejected: a Laravel app's per-module composer.json (nwidart
    # modules, local packages/) would then suppress laravel-best-practices on the very
    # files it is for. Unknown to an older route.sh, where
    # `?package.json` is a manifest name that does not exist: the alternative is skipped
    # and the row fires — the same safe fallback `@base` and `@path` have.
    local list="$1" alt m neg req manifest regex mcontent rc
    [ -z "$list" ] || [ "$list" = "-" ] && return 0
    while [ -n "$list" ]; do
      alt="${list%%||*}"
      if [ "$alt" = "$list" ]; then list=""; else list="${list#*||}"; fi
      m="$alt"; neg=0; req=0
      case "$m" in '?'*) req=1; m="${m#'?'}" ;; esac
      case "$m" in '!'*) neg=1; m="${m#!}" ;; esac
      manifest="${m%%~*}"
      regex="${m#*~}"
      [ "$manifest" = "$m" ] && continue
      [ -n "$manifest" ] && [ -n "$regex" ] || continue
      if [ "$manifest" = "@base" ]; then
        mcontent="$base"
      elif [ "$manifest" = "@path" ]; then
        mcontent="$rel"
      elif [ -f "$root/$manifest" ] && [ -r "$root/$manifest" ] \
           && mcontent=$(head -c 65536 "$root/$manifest" 2>/dev/null); then
        :
      else
        [ "$req" -eq 1 ] && return 1
        continue
      fi
      printf '%s' "$mcontent" | grep -qE "$regex" 2>/dev/null
      rc=$?
      [ "$rc" -ge 2 ] && continue
      [ "$neg" -eq 1 ] && rc=$((1 - rc))
      return "$rc"
    done
    return 0
  }

  nudges=""
  emit_nudge() { # $1 skill, $2 owning_plugin, [$3 subject] — accumulates; delivered once below.
    # When the SKILL.md is locatable, name its path: a subagent context has no
    # Skill tool, so "load the skill" is only actionable there as a Read.
    # Under a versioned cache the SKILL.md sits one level below the plugin dir, so
    # the path comes from pr_plugin_root rather than a join onto the plugins root.
    # $3 replaces the "This edit touches <file>" subject for a command row, which has
    # no file; every file row omits it, so their text is unchanged.
    local sp="" proot="" subj="${3:-This edit touches $base}"
    command -v pr_plugin_root >/dev/null 2>&1 && proot=$(pr_plugin_root "$2")
    [ -n "$proot" ] && [ -f "$proot/skills/$1/SKILL.md" ] && sp=" — Read $proot/skills/$1/SKILL.md"
    nudges="${nudges}$(printf '[skill-router] %s — load the `%s` skill (%s plugin) and review your change against it before continuing.%s' "$subj" "$1" "$2" "$sp")"$'\n'
  }

  # ---- high-confidence pass: EVERY surviving, not-yet-fired match nudges ----
  # All relevant skills for THIS edit fire (e.g. a11y alongside ui-ux, and the
  # stack skill, on a single .tsx) — no break after the first. Session dedup via
  # `fired` still prevents re-nudging the same skill on later edits; emitted_now
  # dedups two rules — or two files of one Bash call — that map to one skill.
  #
  # CONTENT + HIGH (routing review 2026-09-26, finding 1): a `content` row marked `high`
  # fires here on a code or style file (inline_ext), from the file ON DISK, and never
  # enters the digest below. Every library row (MUI, component libraries, motion,
  # three.js …) used to be `content`+`low`, so its skill surfaced on the NEXT user prompt
  # — in a build turn, after the last file was written — and in a subagent never, because
  # UserPromptSubmit does not fire there and only the main thread's digest is flushed.
  # Inline PostToolUse context reaches both. On any other file (a NOTES.md mentioning
  # gsap, a .py holding `new THREE.`, which used to fire and spend the one-shot) the match
  # goes to the digest below, as a `low` row's does. The digest pass reuses this pass's
  # one read per target (`hcs`).
  fired_now=""
  emitted_now=""
  hcs=()
  i=0
  while [ "$i" -lt "${#abs[@]}" ]; do
    set_target "$i"; i=$((i + 1))
    hc=""; [ -r "$target" ] && hc=$(head -c 65536 "$target" 2>/dev/null)
    hcs+=("$hc")
    inline=0; inline_ext && inline=1
    while IFS=$'\t' read -r stype pattern skill plugin conf marker || [ -n "$stype" ]; do
      case "$stype" in ''|'#'*) continue ;; esac
      conf="${conf%$'\r'}"; marker="${marker%$'\r'}"
      [ "$conf" = high ] || continue
      case "$stype" in
        glob) match_glob "$pattern" || continue ;;
        content)
          [ "$inline" = 1 ] && [ -n "$hc" ] || continue
          already_fired "$skill" && continue
          printf '%s' "$hc" | grep -qE "$pattern" 2>/dev/null || continue ;;
        *) continue ;;
      esac
      plugin_installed "$plugin" || continue
      marker_ok "$marker" || continue
      already_fired "$skill" && continue
      printf '%s\n' "$emitted_now" | grep -qxF "$skill" && continue
      emit_nudge "$skill" "$plugin"
      emitted_now="${emitted_now}${skill}"$'\n'
      fired_now="${fired_now}${skill}"$'\n'
    done < "$rules"
  done
  # COMMAND rows matched in the Bash block above. No file, so `@base`/`@path` see "".
  base=""; rel=""
  while IFS=$'\t' read -r skill plugin marker frag; do
    [ -n "$skill" ] || continue
    plugin_installed "$plugin" || continue
    marker_ok "$marker" || continue
    already_fired "$skill" && continue
    printf '%s\n' "$emitted_now" | grep -qxF "$skill" && continue
    emit_nudge "$skill" "$plugin" "This command runs \`${frag}\`"
    emitted_now="${emitted_now}${skill}"$'\n'
    fired_now="${fired_now}${skill}"$'\n'
  done <<EOF_CMD
$cmd_hits
EOF_CMD

  # ---- deliver: ONE envelope per invocation, before state persistence so an
  # unwritable state dir cannot swallow a nudge the model should have seen ----
  if [ -n "$nudges" ]; then
    jq -cn --arg ctx "${nudges%$'\n'}" \
      '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
  fi

  # ---- low-confidence pass: accumulate content matches (no inline output) ----
  # Read from the file ON DISK, so a Bash heredoc's body is judged exactly as an
  # Edit's result would be. One `skill<TAB>file` line per hit. A `high` content row
  # on a code or style file was handled inline above and is skipped here, so it never
  # reaches the digest; on any other file it lands here like a `low` row.
  pending_adds=""
  i=0
  while [ "$i" -lt "${#abs[@]}" ]; do
    set_target "$i"; content="${hcs[$i]}"; i=$((i + 1))
    [ -n "$content" ] || continue
    inline=0; inline_ext && inline=1
    while IFS=$'\t' read -r stype pattern skill plugin conf marker || [ -n "$stype" ]; do
      case "$stype" in ''|'#'*) continue ;; esac
      conf="${conf%$'\r'}"; marker="${marker%$'\r'}"
      [ "$stype" = content ] || continue
      [ "$conf" = high ] && [ "$inline" = 1 ] && continue
      plugin_installed "$plugin" || continue
      marker_ok "$marker" || continue
      if printf '%s' "$content" | grep -qE "$pattern" 2>/dev/null; then
        pending_adds="${pending_adds}${skill}"$'\t'"${file_path}"$'\n'
      fi
    done < "$rules"
  done

  # ---- persist state only if something changed ----
  if [ -n "$fired_now" ] || [ -n "$pending_adds" ]; then
    mkdir -p "$state_dir" 2>/dev/null || exit 0
    # The README has said "(gitignored)" of this directory since it existed; nothing
    # made that true, and the per-session file showed up as untracked in every repo
    # without a hand-written ignore line. A directory can ignore itself.
    [ -e "$state_dir/.gitignore" ] || printf '*\n' > "$state_dir/.gitignore" 2>/dev/null
    json='{"fired":[],"pending_low":[]}'
    if [ -r "$state_file" ]; then
      existing=$(cat "$state_file" 2>/dev/null)
      printf '%s' "$existing" | jq empty 2>/dev/null && json="$existing"
    fi
    if [ -n "$fired_now" ]; then
      while IFS= read -r fskill; do
        [ -n "$fskill" ] || continue
        json=$(printf '%s' "$json" | jq --arg s "$fskill" \
          'if (.fired | index($s) | not) then .fired += [$s] else . end' 2>/dev/null) || exit 0
      done <<EOF_FIRED
$fired_now
EOF_FIRED
    fi
    if [ -n "$pending_adds" ]; then
      while IFS=$'\t' read -r pskill pfile; do
        [ -n "$pskill" ] || continue
        json=$(printf '%s' "$json" | jq --arg sk "$pskill" --arg f "$pfile" \
          'if (.pending_low | any(.skill==$sk and .file==$f)) then . else .pending_low += [{skill:$sk,file:$f}] end' 2>/dev/null) || break
      done <<EOF
$pending_adds
EOF
    fi
    printf '%s\n' "$json" > "$state_file" 2>/dev/null || exit 0
  fi
} 2>/dev/null
exit 0
